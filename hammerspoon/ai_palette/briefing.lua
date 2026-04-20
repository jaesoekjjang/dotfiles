-- AI Palette :: Morning Briefing
-- 아침에 컴퓨터 깨우면 자동 실행 (하루 1회)
-- 데이터 소스: Git (어제 작업), Linear (할당된 이슈), Calendar (오늘 일정)

local M = {}

local LAST_SHOWN_FILE = "/tmp/hs_briefing_last_date.txt"

-- ── 하루 1회 체크 ─────────────────────────────────────────
local function alreadyShownToday()
  local f = io.open(LAST_SHOWN_FILE, "r")
  if not f then return false end
  local last = f:read("*l")
  f:close()
  return last == os.date("%Y-%m-%d")
end

local function markShown()
  local f = io.open(LAST_SHOWN_FILE, "w")
  if f then
    f:write(os.date("%Y-%m-%d"))
    f:close()
  end
end

-- ══════════════════════════════════════════════════════════
-- 데이터 수집기
-- ══════════════════════════════════════════════════════════

-- ── Git: tmux 세션 경로에서 어제 커밋 + 현재 브랜치 수집 ──
local function collectGit(callback)
  -- tmux list-sessions → 세션 이름 추출 → 각 세션의 pane cwd 추출
  local cmd = [[
    projects=""
    # tmux 세션의 첫 번째 pane cwd 가져오기
    if command -v tmux >/dev/null && tmux list-sessions >/dev/null 2>&1; then
      for sid in $(tmux list-sessions -F '#{session_name}' 2>/dev/null); do
        dir=$(tmux list-panes -t "$sid" -F '#{pane_current_path}' 2>/dev/null | head -1)
        if [ -n "$dir" ] && [ -d "$dir/.git" ]; then
          projects="$projects|$dir"
        fi
      done
    fi

    # 중복 제거
    echo "$projects" | tr '|' '\n' | sort -u | while read -r dir; do
      [ -z "$dir" ] && continue
      cd "$dir" 2>/dev/null || continue

      name=$(basename "$dir")
      branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      # 어제 커밋
      yesterday=$(date -v-1d '+%Y-%m-%d' 2>/dev/null || date -d 'yesterday' '+%Y-%m-%d')
      commits=$(git log --all --since="$yesterday 00:00" --until="today 00:00" --oneline --no-merges 2>/dev/null | head -5)
      # 오늘 커밋
      today_commits=$(git log --all --since="today 00:00" --oneline --no-merges 2>/dev/null | head -5)
      # uncommitted changes
      dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

      echo "GIT_REPO:$name"
      echo "GIT_BRANCH:$branch"
      [ "$dirty" != "0" ] && echo "GIT_DIRTY:$dirty"
      if [ -n "$commits" ]; then
        echo "$commits" | while read -r line; do echo "GIT_YESTERDAY:$line"; done
      fi
      if [ -n "$today_commits" ]; then
        echo "$today_commits" | while read -r line; do echo "GIT_TODAY:$line"; done
      fi
      echo "GIT_END"
    done
  ]]

  local task = hs.task.new("/bin/zsh", function(_, stdout, _)
    local repos = {}
    local current = nil

    if stdout then
      for line in stdout:gmatch("[^\n]+") do
        if line:match("^GIT_REPO:") then
          current = {
            name = line:match("^GIT_REPO:(.+)"),
            branch = nil,
            dirty = 0,
            yesterday = {},
            today = {},
          }
        elseif current and line:match("^GIT_BRANCH:") then
          current.branch = line:match("^GIT_BRANCH:(.+)")
        elseif current and line:match("^GIT_DIRTY:") then
          current.dirty = tonumber(line:match("^GIT_DIRTY:(%d+)")) or 0
        elseif current and line:match("^GIT_YESTERDAY:") then
          current.yesterday[#current.yesterday + 1] = line:match("^GIT_YESTERDAY:(.+)")
        elseif current and line:match("^GIT_TODAY:") then
          current.today[#current.today + 1] = line:match("^GIT_TODAY:(.+)")
        elseif current and line:match("^GIT_END") then
          -- 활동이 있는 repo만 포함
          if #current.yesterday > 0 or #current.today > 0 or current.dirty > 0 then
            repos[#repos + 1] = current
          end
          current = nil
        end
      end
    end

    callback(repos)
  end, { "-lc", cmd })
  task:setWorkingDirectory("/tmp")
  task:start()
end

-- ── Calendar: AppleScript로 오늘 일정 ─────────────────────
local function collectCalendar(callback)
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

  hs.osascript.applescript(script, function(ok, result, _)
    local events = {}
    if ok and result then
      for line in result:gmatch("[^\n]+") do
        local time, title = line:match("^CAL:(.-)%s(.+)")
        if time and title then
          events[#events + 1] = { time = time, title = title }
        end
      end
    end
    -- 시간순 정렬
    table.sort(events, function(a, b) return a.time < b.time end)
    callback(events)
  end)
end

-- ── Linear: API로 할당된 이슈 ──────────────────────────────
local function collectLinear(callback)
  -- LINEAR_API_KEY가 없으면 스킵
  local apiKey = os.getenv("LINEAR_API_KEY")
  if not apiKey or apiKey == "" then
    print("[briefing] LINEAR_API_KEY not set, skipping")
    callback(nil)
    return
  end

  local query = [[
    {
      viewer {
        assignedIssues(
          filter: { state: { type: { in: ["started", "unstarted"] } } }
          first: 15
          orderBy: updatedAt
        ) {
          nodes {
            identifier
            title
            state { name type }
            dueDate
            priority
            updatedAt
            url
          }
        }
      }
    }
  ]]

  -- JSON escape
  local jsonQuery = query:gsub("\n", " "):gsub('"', '\\"'):gsub("%s+", " ")
  local cmd = string.format(
    [[curl -s -X POST https://api.linear.app/graphql ]]
    .. [[-H "Content-Type: application/json" ]]
    .. [[-H "Authorization: %s" ]]
    .. [[-d '{"query": "%s"}' ]]
    .. [[--max-time 10 2>/dev/null]],
    apiKey, jsonQuery
  )

  local task = hs.task.new("/bin/zsh", function(_, stdout, _)
    if not stdout or stdout == "" then
      callback(nil)
      return
    end

    local ok, data = pcall(hs.json.decode, stdout)
    if not ok or not data or not data.data then
      print("[briefing] Linear API parse failed")
      callback(nil)
      return
    end

    local nodes = data.data.viewer and data.data.viewer.assignedIssues
      and data.data.viewer.assignedIssues.nodes

    if not nodes then
      callback(nil)
      return
    end

    local issues = { started = {}, unstarted = {} }
    local today = os.date("%Y-%m-%d")

    for _, node in ipairs(nodes) do
      local issue = {
        id = node.identifier,
        title = node.title,
        state = node.state and node.state.name or "unknown",
        stateType = node.state and node.state.type or "unknown",
        dueDate = node.dueDate,
        priority = node.priority,
        url = node.url,
        dueToday = node.dueDate == today,
        overdue = node.dueDate and node.dueDate < today,
      }
      if issue.stateType == "started" then
        issues.started[#issues.started + 1] = issue
      else
        issues.unstarted[#issues.unstarted + 1] = issue
      end
    end

    callback(issues)
  end, { "-lc", cmd })
  task:setWorkingDirectory("/tmp")
  task:start()
end

-- ══════════════════════════════════════════════════════════
-- HTML 렌더링
-- ══════════════════════════════════════════════════════════

local function escapeHtml(s)
  if not s then return "" end
  return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function buildHtml(gitRepos, calEvents, linearIssues)
  local parts = {}
  local function add(s) parts[#parts + 1] = s end

  local today = os.date("%Y-%m-%d")
  local dayNames = { "일", "월", "화", "수", "목", "금", "토" }
  local dayName = dayNames[tonumber(os.date("%w")) + 1]

  add([[<!DOCTYPE html><html><head><meta charset="utf-8"><style>
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
      letter-spacing: 1px; color: #6b7280; margin-bottom: 10px;
      padding-bottom: 6px; border-bottom: 1px solid #2d2e32;
    }
    .empty { color: #4b5563; font-size: 13px; font-style: italic; }

    /* Calendar */
    .cal-item { display: flex; gap: 10px; padding: 6px 0; font-size: 13px; }
    .cal-time { color: #818cf8; font-family: "SF Mono", Menlo, monospace; font-size: 12px; min-width: 100px; }
    .cal-title { color: #c9ccd1; }

    /* Linear */
    .issue { display: flex; align-items: baseline; gap: 8px; padding: 5px 0; font-size: 13px; }
    .issue-id { color: #6b7280; font-family: "SF Mono", Menlo, monospace; font-size: 11px; min-width: 70px; }
    .issue-title { color: #c9ccd1; }
    .issue-state {
      font-size: 10px; padding: 2px 6px; border-radius: 4px;
      font-weight: 600; margin-left: auto; white-space: nowrap;
    }
    .state-started { background: #1e3a2f; color: #34d399; }
    .state-unstarted { background: #2d2520; color: #fbbf24; }
    .badge-due { background: #3b1c1c; color: #f87171; font-size: 10px; padding: 1px 5px; border-radius: 3px; margin-left: 4px; }
    .badge-overdue { background: #5b1c1c; color: #fca5a5; font-size: 10px; padding: 1px 5px; border-radius: 3px; margin-left: 4px; }
    .issue-group-label { font-size: 11px; color: #9ca3af; margin: 10px 0 4px; font-weight: 600; }

    /* Git */
    .repo { margin-bottom: 14px; }
    .repo-header { display: flex; align-items: center; gap: 8px; margin-bottom: 4px; }
    .repo-name { font-size: 13px; font-weight: 600; color: #e4e6ea; }
    .repo-branch {
      font-size: 11px; color: #818cf8; background: #1e1e2e;
      padding: 1px 6px; border-radius: 4px;
      font-family: "SF Mono", Menlo, monospace;
    }
    .repo-dirty {
      font-size: 10px; color: #fbbf24; background: #2d2520;
      padding: 1px 6px; border-radius: 4px;
    }
    .commit { font-size: 12px; color: #9ca3af; padding: 2px 0 2px 12px; }
    .commit-hash { color: #6b7280; font-family: "SF Mono", Menlo, monospace; }
    .commit-label { font-size: 10px; color: #6b7280; margin-top: 6px; padding-left: 12px; }
  </style></head><body>]])

  -- Greeting
  local hour = tonumber(os.date("%H"))
  local greet = hour < 12 and "좋은 아침이에요" or hour < 18 and "좋은 오후에요" or "좋은 저녁이에요"
  add(string.format('<div class="greeting">%s ☀️</div>', greet))
  add(string.format('<div class="date">%s (%s)</div>', today, dayName))

  -- Calendar
  add('<div class="section"><div class="section-title">📅 오늘 일정</div>')
  if calEvents and #calEvents > 0 then
    for _, evt in ipairs(calEvents) do
      add(string.format(
        '<div class="cal-item"><span class="cal-time">%s</span><span class="cal-title">%s</span></div>',
        escapeHtml(evt.time), escapeHtml(evt.title)
      ))
    end
  else
    add('<div class="empty">오늘 일정 없음</div>')
  end
  add('</div>')

  -- Linear
  add('<div class="section"><div class="section-title">📋 Linear 이슈</div>')
  if linearIssues then
    local hasContent = false

    if #linearIssues.started > 0 then
      hasContent = true
      add('<div class="issue-group-label">진행 중</div>')
      for _, issue in ipairs(linearIssues.started) do
        local badges = ""
        if issue.overdue then
          badges = '<span class="badge-overdue">기한 초과</span>'
        elseif issue.dueToday then
          badges = '<span class="badge-due">오늘 마감</span>'
        end
        add(string.format(
          '<div class="issue"><span class="issue-id">%s</span><span class="issue-title">%s%s</span></div>',
          escapeHtml(issue.id), escapeHtml(issue.title), badges
        ))
      end
    end

    if #linearIssues.unstarted > 0 then
      hasContent = true
      add('<div class="issue-group-label">대기</div>')
      for _, issue in ipairs(linearIssues.unstarted) do
        local badges = ""
        if issue.overdue then
          badges = '<span class="badge-overdue">기한 초과</span>'
        elseif issue.dueToday then
          badges = '<span class="badge-due">오늘 마감</span>'
        end
        add(string.format(
          '<div class="issue"><span class="issue-id">%s</span><span class="issue-title">%s%s</span></div>',
          escapeHtml(issue.id), escapeHtml(issue.title), badges
        ))
      end
    end

    if not hasContent then
      add('<div class="empty">할당된 이슈 없음</div>')
    end
  else
    add('<div class="empty">Linear 연동 안 됨 — ~/.secrets.zsh에 LINEAR_API_KEY 추가</div>')
  end
  add('</div>')

  -- Git
  add('<div class="section"><div class="section-title">🔀 어제 작업</div>')
  if gitRepos and #gitRepos > 0 then
    for _, repo in ipairs(gitRepos) do
      add('<div class="repo">')
      local dirtyBadge = ""
      if repo.dirty > 0 then
        dirtyBadge = string.format(' <span class="repo-dirty">%d uncommitted</span>', repo.dirty)
      end
      add(string.format(
        '<div class="repo-header"><span class="repo-name">%s</span><span class="repo-branch">%s</span>%s</div>',
        escapeHtml(repo.name), escapeHtml(repo.branch or ""), dirtyBadge
      ))
      if #repo.yesterday > 0 then
        add('<div class="commit-label">어제</div>')
        for _, c in ipairs(repo.yesterday) do
          local hash, msg = c:match("^(%S+)%s(.+)")
          if hash then
            add(string.format(
              '<div class="commit"><span class="commit-hash">%s</span> %s</div>',
              escapeHtml(hash), escapeHtml(msg)
            ))
          end
        end
      end
      if #repo.today > 0 then
        add('<div class="commit-label">오늘</div>')
        for _, c in ipairs(repo.today) do
          local hash, msg = c:match("^(%S+)%s(.+)")
          if hash then
            add(string.format(
              '<div class="commit"><span class="commit-hash">%s</span> %s</div>',
              escapeHtml(hash), escapeHtml(msg)
            ))
          end
        end
      end
      add('</div>')
    end
  else
    add('<div class="empty">어제 git 활동 없음</div>')
  end
  add('</div>')

  add('</body></html>')
  return table.concat(parts, "\n")
end

-- ══════════════════════════════════════════════════════════
-- Webview
-- ══════════════════════════════════════════════════════════

local briefingWebview = nil

local function showBriefing(html)
  if briefingWebview then
    briefingWebview:delete()
    briefingWebview = nil
  end

  local screen = hs.screen.mainScreen():frame()
  local w, h = 520, math.min(screen.h - 100, 750)
  local rect = hs.geometry.rect(screen.x + (screen.w - w) / 2, screen.y + 60, w, h)

  briefingWebview = hs.webview.new(rect, { privateMode = false })
    :windowTitle("Morning Briefing")
    :windowStyle({ "titled", "closable", "resizable", "miniaturizable" })
    :html(html)
    :allowTextEntry(false)
    :level(hs.drawing.windowLevels.floating)
    :windowCallback(function(action)
      if action == "closing" then briefingWebview = nil end
    end)
    :show()
    :bringToFront(true)
end

-- ══════════════════════════════════════════════════════════
-- 메인 실행
-- ══════════════════════════════════════════════════════════

local function runBriefing()
  -- 3개 소스를 비동기로 수집 후 합치기
  local results = { git = nil, calendar = nil, linear = nil }
  local pending = 3

  local function checkDone()
    pending = pending - 1
    if pending == 0 then
      local html = buildHtml(results.git, results.calendar, results.linear)
      showBriefing(html)
    end
  end

  collectGit(function(repos)
    results.git = repos
    checkDone()
  end)

  collectCalendar(function(events)
    results.calendar = events
    checkDone()
  end)

  collectLinear(function(issues)
    results.linear = issues
    checkDone()
  end)
end

-- ── Wake 감지 (하루 1회) ──────────────────────────────────
function M.setupWatcher()
  M.watcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidUnlock
      or event == hs.caffeinate.watcher.systemDidWake then
      if not alreadyShownToday() then
        -- 잠금해제 직후 바로 띄우면 화면 전환이 어색하므로 약간 딜레이
        hs.timer.doAfter(3, function()
          if not alreadyShownToday() then
            markShown()
            runBriefing()
          end
        end)
      end
    end
  end)
  M.watcher:start()
end

-- 수동 실행용
function M.run()
  runBriefing()
end

return M
