-- AI Palette :: Briefing Shared
-- 데이터 수집기 (git, calendar, workmux, linear) + HTML/MD 렌더링 헬퍼

local M = {}

-- ── 프로젝트 루트 디렉토리 (git repo 스캔 시작점) ─────────
-- 각 루트에서 maxdepth 4로 .git 파일/디렉토리 탐색 → worktree도 포함
-- 사용자 환경 맞춤 필요하면 이 리스트만 편집
local HOME = os.getenv("HOME") or ""
M.PROJECT_ROOTS = {
  HOME .. "/Programming",
  HOME .. "/.codex/worktrees",
  HOME .. "/WebstormProjects",
  HOME .. "/dev",
  os.getenv("DOTFILES") or (HOME .. "/Library/Mobile Documents/com~apple~CloudDocs/Dotfiles"),
}
M.SCAN_MAXDEPTH = 4

-- ══════════════════════════════════════════════════════════
-- Collectors
-- ══════════════════════════════════════════════════════════

-- git repo 디렉토리 집합 수집
-- 소스 1: PROJECT_ROOTS 아래 maxdepth N까지 .git 스캔 (worktree .git 파일 포함)
-- 소스 2: tmux 세션 pane cwd (위 루트 바깥에 클론된 repo 보충)
-- 결과는 중복 제거 후 절대 경로 배열
-- callback(repoDirs)
function M.collectGitRepoDirs(callback)
  -- find 명령에 루트 리스트 전달 (없는 경로는 무시)
  local rootArgs = {}
  for _, root in ipairs(M.PROJECT_ROOTS) do
    rootArgs[#rootArgs + 1] = string.format('%q', root)
  end
  local rootsExpr = table.concat(rootArgs, " ")

  local cmd = string.format([[
    # 1) PROJECT_ROOTS 스캔 — 존재하는 경로만, .git 파일/디렉토리 둘 다 잡음
    for root in %s; do
      [ -d "$root" ] || continue
      find "$root" -maxdepth %d -name .git -prune 2>/dev/null
    done | while read -r gitpath; do
      # .git의 부모 디렉토리가 repo root
      dirname "$gitpath"
    done

    # 2) tmux 세션 pane cwd 보충 (루트 바깥)
    if command -v tmux >/dev/null && tmux list-sessions >/dev/null 2>&1; then
      for sid in $(tmux list-sessions -F '#{session_name}' 2>/dev/null); do
        tmux list-panes -t "$sid" -F '#{pane_current_path}' 2>/dev/null
      done | while read -r dir; do
        [ -z "$dir" ] && continue
        if [ -e "$dir/.git" ]; then
          echo "$dir"
        fi
      done
    fi
  ]], rootsExpr, M.SCAN_MAXDEPTH)

  local task = hs.task.new("/bin/zsh", function(_, stdout, _)
    local seen = {}
    local dirs = {}
    if stdout then
      for line in stdout:gmatch("[^\n]+") do
        if line ~= "" and not seen[line] then
          seen[line] = true
          dirs[#dirs + 1] = line
        end
      end
    end
    callback(dirs)
  end, { "-lc", cmd })
  task:setWorkingDirectory("/tmp")
  task:start()
end

-- 한 repo의 git stdout을 repo 테이블로 파싱
local function parseRepoOutput(stdout)
  if not stdout or stdout == "" then return nil end
  local repo = { commits_since = {}, dirty_files = {} }
  local started = false
  for line in stdout:gmatch("[^\n]+") do
    if line == "REPO_START" then
      started = true
    elseif line == "REPO_END" then
      break
    elseif started then
      local key, value = line:match("^([^:]+):(.*)$")
      if key == "PATH" then repo.path = value
      elseif key == "NAME" then repo.name = value
      elseif key == "BRANCH" then repo.branch = value
      elseif key == "DIRTY_COUNT" then repo.dirty_count = tonumber(value) or 0
      elseif key == "ACTIVE_TODAY" then repo.active_today = (value == "1")
      elseif key == "MERGED" then repo.merged_to_main = (value == "1")
      elseif key == "COMMIT" then repo.commits_since[#repo.commits_since + 1] = value
      elseif key == "DIRTY_FILE" then
        local touched, code, path = value:match("^(%d+)|(..)|(.+)$")
        if path then
          repo.dirty_files[#repo.dirty_files + 1] = {
            touched_today = (touched == "1"),
            status = code,
            path = path,
          }
        end
      end
    end
  end
  if not started then return nil end
  return repo
end

-- 단일 repo에 대해 git 정보를 수집하는 쉘 스크립트 템플릿
-- 각 repo마다 hs.task 하나씩 spawn → macOS libdispatch가 병렬 처리
local function repoShellCmd(dir, sinceEpoch)
  return string.format([[
    dir=%q
    SINCE=%s
    cd "$dir" 2>/dev/null || exit 0

    name=$(basename "$dir")
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    dirty_lines=$(git status --porcelain 2>/dev/null)
    dirty_count=$(echo "$dirty_lines" | grep -c . || true)

    active_today=0
    if [ "$dirty_count" -gt 0 ]; then
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        file="${line:3}"
        if [ -e "$dir/$file" ]; then
          mtime=$(stat -f %%m "$dir/$file" 2>/dev/null || echo 0)
          if [ "$mtime" -gt "$SINCE" ]; then
            active_today=1; break
          fi
        fi
      done <<< "$dirty_lines"
    fi

    # commits since $SINCE (epoch) — date -r로 ISO 변환 후 git log --since
    since_iso=$(date -r "$SINCE" '+%%Y-%%m-%%d %%H:%%M:%%S' 2>/dev/null)
    commits_since=$(git log --all --since="$since_iso" --oneline --no-merges 2>/dev/null | head -10)

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
    if [ -n "$commits_since" ]; then
      echo "$commits_since" | while read -r line; do echo "COMMIT:$line"; done
    fi
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
  ]], dir, tostring(sinceEpoch))
end

-- 각 repo에 대해 git 정보 수집 (Tier A/B 판정 포함)
-- sinceEpoch: 이 시각 이후 mtime을 가진 dirty 파일이 있으면 Tier A
-- 병렬: repo 하나당 hs.task 하나. 모든 task 완료 시 callback
function M.collectGitDetails(sinceEpoch, callback)
  M.collectGitRepoDirs(function(dirs)
    if #dirs == 0 then
      callback({})
      return
    end

    local repos = {}
    local pending = #dirs

    for _, dir in ipairs(dirs) do
      local cmd = repoShellCmd(dir, sinceEpoch)
      local task = hs.task.new("/bin/zsh", function(_, stdout, _)
        local repo = parseRepoOutput(stdout)
        if repo then repos[#repos + 1] = repo end
        pending = pending - 1
        if pending == 0 then callback(repos) end
      end, { "-c", cmd })
      task:setWorkingDirectory("/tmp")
      task:start()
    end
  end)
end

-- Calendar: icalBuddy 우선, 실패 시 AppleScript fallback
-- icalBuddy는 ~/Library/Calendars 직접 파싱 (FDA 필요). ~0.5초
-- AppleScript는 Calendar.app IPC 경유 (Automation 권한). ~14초
-- callback(events) — array of { time, title }

local ICALBUDDY_BIN = "/opt/homebrew/bin/icalBuddy"

-- icalBuddy 출력 파싱: "HH:MM - HH:MM | Event Title" 한 줄 per event
local function parseIcalBuddyOutput(stdout)
  local events = {}
  if not stdout or stdout == "" then return events end
  for line in stdout:gmatch("[^\n]+") do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    -- 포맷: "10:00 - 11:00 | Title"  (dash: -, en-dash –, em-dash —)
    local h1, m1, h2, m2, title = line:match("^(%d+):(%d+)%s*[%-–—]%s*(%d+):(%d+)%s*|%s*(.+)$")
    if h1 and title then
      events[#events + 1] = {
        time = string.format("%s:%s-%s:%s", h1, m1, h2, m2),
        title = title,
      }
    else
      -- fallback 파싱: "HH:MM Title" (종일/시작시각만)
      local h, m, t = line:match("^(%d+):(%d+)%s+(.+)$")
      if h and t then
        events[#events + 1] = {
          time = string.format("%s:%s", h, m),
          title = t,
        }
      end
    end
  end
  return events
end

-- AppleScript fallback
local function collectCalendarViaAppleScript(callback)
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
  end, { "-" })
  task:setInput(script)
  task:start()
end

-- icalBuddy 가용성 캐시. Hammerspoon 프로세스 생명주기 동안 유지:
--   nil   → 아직 테스트 안 함 (첫 호출 때 시도)
--   true  → 이전 호출에서 성공 (계속 사용)
--   false → 이전 호출에서 실패 (권한 없음 등) → 이후 바로 AppleScript로
-- Hammerspoon 재시작하면 다시 nil로 리셋되어 재시도
local icalBuddyUsable = nil

function M.collectCalendar(callback)
  -- 이미 실패한 적 있으면 바로 fallback (icalBuddy 프로브 5초 절약)
  if icalBuddyUsable == false then
    collectCalendarViaAppleScript(callback)
    return
  end
  -- 바이너리 없음 → 영구 fallback
  if not hs.fs.attributes(ICALBUDDY_BIN) then
    icalBuddyUsable = false
    collectCalendarViaAppleScript(callback)
    return
  end

  local task = hs.task.new(ICALBUDDY_BIN, function(ec, stdout, stderr)
    local ok = (ec == 0)
      and stdout and stdout ~= ""
      and not stdout:match("^%s*error:")
    if ok then
      icalBuddyUsable = true
      local events = parseIcalBuddyOutput(stdout)
      table.sort(events, function(a, b) return a.time < b.time end)
      callback(events)
    else
      icalBuddyUsable = false
      if stderr and stderr ~= "" then
        print("[calendar] icalBuddy unavailable (" .. stderr:sub(1, 80) .. "), using AppleScript for remainder of session")
      end
      collectCalendarViaAppleScript(callback)
    end
  end, {
    "-nc", "-npn",
    "-tf", "%H:%M",
    "-df", "",
    "-b", "",
    "-ss", " | ",
    "--includeEventProps", "datetimes,title",
    "--propertyOrder", "datetimes,title",
    "eventsToday",
  })
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

-- 저녁 전용: Calendar/workmux 제외 (workmux는 menubar로 별도 처리)
-- git + linear 2개만 병렬 수집
function M.collectForEvening(sinceEpoch, callback)
  local results = { git = nil, linear = nil }
  local pending = 2

  local function done()
    pending = pending - 1
    if pending == 0 then callback(results) end
  end

  M.collectGitDetails(sinceEpoch, function(r) results.git = r; done() end)
  M.collectLinear(function(r) results.linear = r; done() end)
end

-- 아침 전용: 오늘 input 구성 (어제 중단점 + 오늘 Calendar + Linear + 어제 git 활동)
-- sinceEpoch는 "어제 git 활동" 기준. 보통 어제 00:00
-- calendar + linear + git 3개 병렬 수집
function M.collectForMorning(sinceEpoch, callback)
  local results = { calendar = nil, linear = nil, git = nil }
  local pending = 3

  local function done()
    pending = pending - 1
    if pending == 0 then callback(results) end
  end

  M.collectCalendar(function(r) results.calendar = r; done() end)
  M.collectLinear(function(r) results.linear = r; done() end)
  M.collectGitDetails(sinceEpoch, function(r) results.git = r; done() end)
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

  local urlScheme = require("url_scheme")
  local wv = hs.webview.new(rect, { developerExtrasEnabled = true })
    :windowTitle(title)
    :windowStyle({ "titled", "closable", "resizable", "miniaturizable" })
    :allowTextEntry(true)
    :level(hs.drawing.windowLevels.floating)
    :policyCallback(urlScheme.webviewPolicy)
    :html(html)

  if onClose then
    wv:windowCallback(function(action)
      if action == "closing" and onClose then onClose() end
    end)
  end

  return wv
end

return M
