-- AI Palette :: Briefing Shared
-- 데이터 수집기 (git, calendar, workmux, linear) + HTML/MD 렌더링 헬퍼

local M = {}

-- ══════════════════════════════════════════════════════════
-- Collectors
-- ══════════════════════════════════════════════════════════

-- tmux 세션 pane cwd에서 git repo 디렉토리 집합 수집
-- callback(repoDirs) — array of absolute paths, 중복 제거됨
function M.collectGitRepoDirs(callback)
  local cmd = [[
    if command -v tmux >/dev/null && tmux list-sessions >/dev/null 2>&1; then
      for sid in $(tmux list-sessions -F '#{session_name}' 2>/dev/null); do
        tmux list-panes -t "$sid" -F '#{pane_current_path}' 2>/dev/null
      done | sort -u | while read -r dir; do
        [ -z "$dir" ] && continue
        # worktree도 .git 파일(디렉토리 아님)로 존재 → -e로 체크
        if [ -e "$dir/.git" ]; then
          echo "$dir"
        fi
      done
    fi
  ]]

  local task = hs.task.new("/bin/zsh", function(_, stdout, _)
    local dirs = {}
    if stdout then
      for line in stdout:gmatch("[^\n]+") do
        dirs[#dirs + 1] = line
      end
    end
    callback(dirs)
  end, { "-lc", cmd })
  task:setWorkingDirectory("/tmp")
  task:start()
end

-- 각 repo에 대해 git 정보 수집 (Tier A/B 판정 포함)
-- sinceEpoch: 이 시각 이후 mtime을 가진 dirty 파일이 있으면 Tier A
-- callback(repos) — array:
--   { name, path, branch, dirty_count, active_today, commits_today, merged_to_main }
function M.collectGitDetails(sinceEpoch, callback)
  M.collectGitRepoDirs(function(dirs)
    if #dirs == 0 then
      callback({})
      return
    end

    -- 각 디렉토리에 대한 git 정보를 한 번의 shell 호출로 수집
    -- shell 스크립트에 dirs 목록을 stdin으로 전달 (trailing newline 필수: read가 마지막 라인 감지용)
    local dirList = table.concat(dirs, "\n") .. "\n"
    local sinceStr = tostring(sinceEpoch)

    local cmd = string.format([[
      SINCE=%s
      while IFS= read -r dir; do
        [ -z "$dir" ] && continue
        cd "$dir" 2>/dev/null || continue

        name=$(basename "$dir")
        branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

        # dirty 파일 목록 (porcelain: "XY path")
        dirty_lines=$(git status --porcelain 2>/dev/null)
        dirty_count=$(echo "$dirty_lines" | grep -c . || true)

        # active_today 1차 계산 (헤더용). 파일 목록은 REPO_START 이후에 별도 emit
        active_today=0
        if [ "$dirty_count" -gt 0 ]; then
          while IFS= read -r line; do
            [ -z "$line" ] && continue
            file="${line:3}"
            if [ -e "$dir/$file" ]; then
              mtime=$(stat -f %%m "$dir/$file" 2>/dev/null || echo 0)
              if [ "$mtime" -gt "$SINCE" ]; then
                active_today=1
                break
              fi
            fi
          done <<< "$dirty_lines"
        fi

        # 오늘 커밋
        commits_today=$(git log --all --since="$(date -v0H -v0M -v0S '+%%Y-%%m-%%d %%H:%%M:%%S')" --oneline --no-merges 2>/dev/null | head -10)

        # origin/main에 머지되었는지
        merged=0
        if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
          tip=$(git rev-parse HEAD 2>/dev/null)
          if [ -n "$tip" ]; then
            if git merge-base --is-ancestor "$tip" origin/main 2>/dev/null; then
              merged=1
            elif git merge-base --is-ancestor "$tip" origin/master 2>/dev/null; then
              merged=1
            fi
          fi
        fi

        echo "REPO_START"
        echo "PATH:$dir"
        echo "NAME:$name"
        echo "BRANCH:$branch"
        echo "DIRTY_COUNT:$dirty_count"
        echo "ACTIVE_TODAY:$active_today"
        echo "MERGED:$merged"
        if [ -n "$commits_today" ]; then
          echo "$commits_today" | while read -r line; do echo "COMMIT:$line"; done
        fi
        # 각 dirty 파일 상세 (status_code + touched_today + path)
        if [ "$dirty_count" -gt 0 ]; then
          while IFS= read -r line; do
            [ -z "$line" ] && continue
            status_code="${line:0:2}"
            file="${line:3}"
            touched_today=0
            if [ -e "$dir/$file" ]; then
              mtime=$(stat -f %%m "$dir/$file" 2>/dev/null || echo 0)
              if [ "$mtime" -gt "$SINCE" ]; then touched_today=1; fi
            fi
            echo "DIRTY_FILE:$touched_today|$status_code|$file"
          done <<< "$dirty_lines"
        fi
        echo "REPO_END"
      done
    ]], sinceStr)

    local task = hs.task.new("/bin/zsh", function(_, stdout, _)
      local repos = {}
      local current = nil

      if stdout then
        for line in stdout:gmatch("[^\n]+") do
          if line == "REPO_START" then
            current = { commits_today = {}, dirty_files = {} }
          elseif line == "REPO_END" and current then
            repos[#repos + 1] = current
            current = nil
          elseif current then
            local key, value = line:match("^([^:]+):(.*)$")
            if key == "PATH" then current.path = value
            elseif key == "NAME" then current.name = value
            elseif key == "BRANCH" then current.branch = value
            elseif key == "DIRTY_COUNT" then current.dirty_count = tonumber(value) or 0
            elseif key == "ACTIVE_TODAY" then current.active_today = (value == "1")
            elseif key == "MERGED" then current.merged_to_main = (value == "1")
            elseif key == "COMMIT" then current.commits_today[#current.commits_today + 1] = value
            elseif key == "DIRTY_FILE" then
              local touched, code, path = value:match("^(%d+)|(..)|(.+)$")
              if path then
                current.dirty_files[#current.dirty_files + 1] = {
                  touched_today = (touched == "1"),
                  status = code,
                  path = path,
                }
              end
            end
          end
        end
      end

      callback(repos)
    end, { "-lc", cmd })

    -- stdin으로 dirList 전달
    task:setInput(dirList)
    task:setWorkingDirectory("/tmp")
    task:start()
  end)
end

-- Calendar: 오늘 일정 (osascript CLI로 비동기 실행)
-- callback(events) — array of { time, title }
function M.collectCalendar(callback)
  -- osascript는 stdin으로 script 받기 가능 — 특수문자(≥) escape 불필요
  local script = [[
    set output to ""
    set today to current date
    set time of today to 0
    set tomorrow to today + (1 * days)

    tell application "Calendar"
      repeat with cal in calendars
        try
          set evts to (every event of cal whose start date ≥ today and start date < tomorrow)
          repeat with evt in evts
            set evtStart to start date of evt
            set evtEnd to end date of evt
            set evtTitle to summary of evt
            set h1 to text -2 thru -1 of ("0" & (hours of evtStart as text))
            set m1 to text -2 thru -1 of ("0" & (minutes of evtStart as text))
            set h2 to text -2 thru -1 of ("0" & (hours of evtEnd as text))
            set m2 to text -2 thru -1 of ("0" & (minutes of evtEnd as text))
            set output to output & "CAL:" & h1 & ":" & m1 & "-" & h2 & ":" & m2 & " " & evtTitle & linefeed
          end repeat
        end try
      end repeat
    end tell
    return output
  ]]

  local task = hs.task.new("/usr/bin/osascript", function(_, stdout, _)
    local events = {}
    if stdout then
      for line in stdout:gmatch("[^\n]+") do
        local time, title = line:match("^CAL:(.-)%s(.+)")
        if time and title then
          events[#events + 1] = { time = time, title = title }
        end
      end
    end
    table.sort(events, function(a, b) return a.time < b.time end)
    callback(events)
  end, { "-" }) -- "-" 는 stdin에서 스크립트 읽기
  task:setInput(script)
  task:start()
end

-- workmux list --json — repo마다 결과가 다르므로 tmux 세션 repo 전체를 순회해 집계
-- 리턴 구조 예:
--   [{ handle, branch, path, is_main, mode, has_uncommitted_changes, is_open, created_at }]
-- path 기준으로 중복 제거 (한 repo를 여러 tmux 세션에서 열었을 때 같은 worktree가 중복 수집 방지)
function M.collectWorkmux(callback)
  M.collectGitRepoDirs(function(dirs)
    if #dirs == 0 then
      callback({})
      return
    end

    -- 각 dir에서 workmux list --json 실행 후 JSON 라인별로 취합
    -- shell에서 repo마다 한 줄로 JSON array를 출력하고, Lua에서 각각 decode해 merge
    local dirList = table.concat(dirs, "\n") .. "\n"
    local cmd = [[
      while IFS= read -r dir; do
        [ -z "$dir" ] && continue
        cd "$dir" 2>/dev/null || continue
        out=$(workmux list --json 2>/dev/null)
        if [ -n "$out" ]; then
          # 각 repo의 JSON array를 한 줄로 (단일 라인 JSON 보장)
          echo "$out" | tr -d '\n'
          echo ""
        fi
      done
    ]]

    local task = hs.task.new("/bin/zsh", function(_, stdout, _)
      local merged = {}
      local seenPaths = {}
      if stdout then
        for line in stdout:gmatch("[^\n]+") do
          local ok, arr = pcall(hs.json.decode, line)
          if ok and type(arr) == "table" then
            for _, wt in ipairs(arr) do
              if wt.path and not seenPaths[wt.path] then
                seenPaths[wt.path] = true
                merged[#merged + 1] = wt
              end
            end
          end
        end
      end
      callback(merged)
    end, { "-lc", cmd })
    task:setInput(dirList)
    task:setWorkingDirectory("/tmp")
    task:start()
  end)
end

-- Linear: assigned In Progress/Unstarted 이슈
-- Hammerspoon GUI는 ~/.secrets.zsh를 자동 소싱 안 함 → 서브쉘에서 직접 source
-- callback(issues) — array (빈배열이면 {}, 키 없거나 실패면 nil)
function M.collectLinear(callback)
  local query = [[
    {
      viewer {
        assignedIssues(
          filter: { state: { type: { in: ["started", "unstarted"] } } }
          first: 20
          orderBy: updatedAt
        ) {
          nodes {
            identifier title url
            state { name type }
            dueDate priority updatedAt
          }
        }
      }
    }
  ]]
  local jsonQuery = query:gsub("\n", " "):gsub('"', '\\"'):gsub("%s+", " ")

  -- ~/.secrets.zsh에서 LINEAR_API_KEY load 후 curl
  local cmd = string.format([[
    [ -f ~/.secrets.zsh ] && source ~/.secrets.zsh
    [ -z "$LINEAR_API_KEY" ] && exit 99
    curl -s -X POST https://api.linear.app/graphql \
      -H "Content-Type: application/json" \
      -H "Authorization: $LINEAR_API_KEY" \
      -d '{"query": "%s"}' --max-time 10 2>/dev/null
  ]], jsonQuery)

  local task = hs.task.new("/bin/zsh", function(ec, stdout, _)
    if ec == 99 then
      -- API 키 미설정
      callback(nil)
      return
    end
    if not stdout or stdout == "" then callback(nil); return end
    local ok, data = pcall(hs.json.decode, stdout)
    if not ok or not data or not data.data then
      print("[linear] parse failed or error: " .. tostring(stdout):sub(1, 200))
      callback(nil)
      return
    end
    local nodes = data.data.viewer
      and data.data.viewer.assignedIssues
      and data.data.viewer.assignedIssues.nodes
    callback(nodes or {})
  end, { "-c", cmd })
  task:setWorkingDirectory("/tmp")
  task:start()
end

-- ══════════════════════════════════════════════════════════
-- 병렬 수집기 (N개 collector 결과를 하나의 callback으로)
-- ══════════════════════════════════════════════════════════

function M.collectAll(sinceEpoch, callback)
  local results = { git = nil, calendar = nil, workmux = nil, linear = nil }
  local pending = 4

  local function done()
    pending = pending - 1
    if pending == 0 then callback(results) end
  end

  M.collectGitDetails(sinceEpoch, function(r) results.git = r; done() end)
  M.collectCalendar(function(r) results.calendar = r; done() end)
  M.collectWorkmux(function(r) results.workmux = r; done() end)
  M.collectLinear(function(r) results.linear = r; done() end)
end

-- 저녁 전용: Calendar 제외 (저녁은 "하루 닫기" 관점이라 Calendar 불필요)
-- git + workmux + linear 3개만 병렬 수집 → Calendar 10초 비용 회피
function M.collectForEvening(sinceEpoch, callback)
  local results = { git = nil, workmux = nil, linear = nil }
  local pending = 3

  local function done()
    pending = pending - 1
    if pending == 0 then callback(results) end
  end

  M.collectGitDetails(sinceEpoch, function(r) results.git = r; done() end)
  M.collectWorkmux(function(r) results.workmux = r; done() end)
  M.collectLinear(function(r) results.linear = r; done() end)
end

-- ══════════════════════════════════════════════════════════
-- Tier 분류 헬퍼
-- ══════════════════════════════════════════════════════════

function M.classifyRepos(repos)
  local tierA, tierB = {}, {}
  for _, r in ipairs(repos or {}) do
    if r.dirty_count and r.dirty_count > 0 then
      if r.active_today then
        tierA[#tierA + 1] = r
      else
        tierB[#tierB + 1] = r
      end
    end
  end
  return tierA, tierB
end

-- ══════════════════════════════════════════════════════════
-- HTML 헬퍼
-- ══════════════════════════════════════════════════════════

function M.escapeHtml(s)
  if not s then return "" end
  return tostring(s)
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;")
end

function M.baseStyles()
  return [[
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      background: #1a1b1e; color: #c9ccd1;
      padding: 28px; line-height: 1.6;
    }
    .greeting { font-size: 22px; color: #e4e6ea; margin-bottom: 4px; font-weight: 600; }
    .date { font-size: 13px; color: #6b7280; margin-bottom: 24px; }
    .section { margin-bottom: 24px; }
    .section-title {
      font-size: 12px; font-weight: 600; text-transform: uppercase;
      letter-spacing: 1px; color: #9ca3af; margin-bottom: 10px;
      padding-bottom: 6px; border-bottom: 1px solid #2d2e32;
    }
    .empty { color: #4b5563; font-size: 13px; font-style: italic; }
    .item { font-size: 13px; padding: 4px 0; }
    .badge {
      display: inline-block; font-size: 10px; padding: 1px 6px;
      border-radius: 4px; margin-left: 6px; vertical-align: middle;
    }
    .badge-warn { background: #3b1c1c; color: #f87171; }
    .badge-info { background: #1e2a3b; color: #93c5fd; }
    .badge-ok   { background: #1e3a2f; color: #34d399; }
    .mono { font-family: "SF Mono", Menlo, monospace; font-size: 12px; }

    .repo-card {
      background: #1e1f23; border: 1px solid #2d2e32;
      border-radius: 8px; padding: 14px; margin-bottom: 12px;
    }
    .repo-head { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
    .repo-name { font-size: 14px; font-weight: 600; color: #e4e6ea; }
    .repo-branch {
      font-size: 11px; color: #818cf8; background: #1e1e2e;
      padding: 2px 8px; border-radius: 4px;
      font-family: "SF Mono", Menlo, monospace;
    }
    .commit-msg { font-size: 12px; color: #9ca3af; padding: 2px 0 2px 8px; }
    .commit-hash { color: #6b7280; font-family: "SF Mono", Menlo, monospace; }

    textarea.note {
      width: 100%; background: #14151a; border: 1px solid #2d2e32;
      color: #c9ccd1; border-radius: 6px; padding: 8px 10px;
      font-family: inherit; font-size: 13px; line-height: 1.5;
      resize: vertical; min-height: 56px; margin-top: 8px;
    }
    textarea.note:focus { outline: none; border-color: #818cf8; }

    button.primary {
      background: #4f46e5; color: white; border: none;
      padding: 10px 20px; border-radius: 6px; font-size: 13px;
      font-weight: 600; cursor: pointer; margin-top: 16px;
    }
    button.primary:hover { background: #6366f1; }

    a { color: #818cf8; text-decoration: none; }
    a:hover { text-decoration: underline; }
  ]]
end

function M.greeting(kind)
  -- kind: "morning" | "evening" | nil(시각 기반)
  if kind == "morning" then return "좋은 아침이에요 ☀️" end
  if kind == "evening" then return "오늘도 수고하셨어요 🌙" end
  local hour = tonumber(os.date("%H"))
  if hour < 12 then return "좋은 아침이에요 ☀️"
  elseif hour < 18 then return "좋은 오후에요 🌤"
  else return "좋은 저녁이에요 🌙"
  end
end

function M.todayLabel()
  local dayNames = { "일", "월", "화", "수", "목", "금", "토" }
  local d = os.date("%Y-%m-%d")
  local dn = dayNames[tonumber(os.date("%w")) + 1]
  return string.format("%s (%s)", d, dn)
end

-- Webview 생성 공통
function M.makeWebview(title, html, width, height, onClose)
  local screen = hs.screen.mainScreen():frame()
  local w = width or 560
  local h = height or math.min(screen.h - 100, 780)
  local rect = hs.geometry.rect(
    screen.x + (screen.w - w) / 2,
    screen.y + 60,
    w, h
  )

  local wv = hs.webview.new(rect, { developerExtrasEnabled = true })
    :windowTitle(title)
    :windowStyle({ "titled", "closable", "resizable", "miniaturizable" })
    :allowTextEntry(true)
    :level(hs.drawing.windowLevels.floating)
    :html(html)

  if onClose then
    wv:windowCallback(function(action)
      if action == "closing" and onClose then onClose() end
    end)
  end

  return wv
end

return M
