-- workmux :: Menubar Status Indicator
-- ~/.local/state/workmux/agents/*.json 스캔 → macOS 메뉴바에 agent 현황 표시
-- pathwatcher + 30초 안전 타이머, waiting 5분+ 역치 시 notification

local M = {}

-- ══════════════════════════════════════════════════════════
-- 설정
-- ══════════════════════════════════════════════════════════

local STATE_DIR = os.getenv("HOME") .. "/.local/state/workmux/agents"
local POLL_INTERVAL_SEC = 30
local PATHWATCH_DEBOUNCE_SEC = 0.2
local WAITING_ALERT_SEC = 300
local ALERT_THROTTLE_SEC = 3600
local DONE_SHOW_WINDOW_SEC = 3600
local STALE_FILE_SEC = 25 * 3600
local TASK_CACHE_TTL_SEC = 60
local TITLE_HANDLE_MAX = 20
local TITLE_HANDLE_MAX_MULTI = 15
local TASK_DESC_MAX = 70

-- ══════════════════════════════════════════════════════════
-- 상태
-- ══════════════════════════════════════════════════════════

local menubar = nil
local pathWatcher = nil
local safetyTimer = nil
local refreshDebounce = nil
local lastAlertedAt = {}
local pausedUntil = nil
local taskCache = {}

-- ══════════════════════════════════════════════════════════
-- 유틸
-- ══════════════════════════════════════════════════════════

local function now()
  return os.time()
end

local function shellQuote(s)
  return "'" .. (s or ""):gsub("'", [['\'']]) .. "'"
end

local function formatElapsed(secs)
  if secs < 60 then return secs .. "s"
  elseif secs < 3600 then return math.floor(secs / 60) .. "m"
  elseif secs < 86400 then return math.floor(secs / 3600) .. "h"
  else return math.floor(secs / 86400) .. "d"
  end
end

local function statusIcon(status)
  if status == "working" then return "◉"
  elseif status == "waiting" then return "💬"
  elseif status == "done" then return "✓"
  else return "·"
  end
end

local function projectNameOf(workdir)
  if not workdir or workdir == "" then return "(unknown)" end
  local proj = workdir:match("/([^/]+)__worktrees/")
  if proj then return proj end
  return workdir:match("([^/]+)/?$") or "(unknown)"
end

-- window_name은 "<nerdfont glyph> <branch>" 형태. 첫 ASCII 식별자 문자부터 취함
local function handleOf(agent)
  local name = agent.window_name or ""
  local cut = name:find("[%w]")
  if cut then name = name:sub(cut) end
  return (name:gsub("%s+$", ""))
end

local function truncate(s, n)
  if not s or s == "" then return "" end
  local okLen, charLen = pcall(utf8.len, s)
  if not okLen or not charLen then
    if #s <= n then return s end
    return s:sub(1, n - 1) .. "…"
  end
  if charLen <= n then return s end
  local byteEnd = utf8.offset(s, n)
  if not byteEnd then return s end
  return s:sub(1, byteEnd - 1) .. "…"
end

local function isPaused()
  return pausedUntil and pausedUntil > now()
end

-- ══════════════════════════════════════════════════════════
-- 데이터 수집
-- ══════════════════════════════════════════════════════════

local function readAgents()
  local agents = {}
  local ok, iter, dirObj = pcall(hs.fs.dir, STATE_DIR)
  if not ok or not iter then return agents end

  for name in iter, dirObj do
    if name:sub(-5) == ".json" then
      local path = STATE_DIR .. "/" .. name
      local f = io.open(path, "r")
      if f then
        local content = f:read("*a")
        f:close()
        local okParse, data = pcall(hs.json.decode, content)
        if okParse and type(data) == "table" and data.status and data.workdir then
          local age = now() - (data.status_ts or 0)
          if age < STALE_FILE_SEC then
            data._pane_id = data.pane_key and data.pane_key.pane_id
            data._elapsed = age
            agents[#agents + 1] = data
          end
        end
      end
    end
  end

  return agents
end

local function groupByProject(agents)
  local groups = {}
  for _, agent in ipairs(agents) do
    local project = projectNameOf(agent.workdir)
    groups[project] = groups[project] or {}
    groups[project][#groups[project] + 1] = agent
  end
  return groups
end

-- workdir에서 태스크 설명 조회: PROMPT-<branch>.md 우선, 없으면 최근 커밋 메시지
-- 60초 캐시로 서브프로세스 비용 완화
local function readTaskDescription(workdir)
  if not workdir or workdir == "" then return "" end

  local cached = taskCache[workdir]
  if cached and (now() - cached.ts) < TASK_CACHE_TTL_SEC then
    return cached.text
  end

  local cmd = string.format([[
    cd %s 2>/dev/null || exit 0
    prompt=$(find .workmux -maxdepth 1 -name 'PROMPT-*.md' -type f 2>/dev/null | head -n 1)
    if [ -n "$prompt" ] && [ -f "$prompt" ]; then
      head -n 1 "$prompt" | sed 's/^#* *//'
    else
      git log -1 --format=%%s HEAD 2>/dev/null
    fi
  ]], shellQuote(workdir))

  local output = hs.execute(cmd, true) or ""
  local text = output:gsub("\n", ""):gsub("^%s+", ""):gsub("%s+$", "")

  -- UTF-8 aware truncation (한글 깨짐 방지)
  if utf8 and utf8.len then
    local okLen, charLen = pcall(utf8.len, text)
    if okLen and charLen and charLen > TASK_DESC_MAX then
      local byteEnd = utf8.offset(text, TASK_DESC_MAX + 1)
      if byteEnd then
        text = text:sub(1, byteEnd - 1) .. "…"
      end
    end
  end

  taskCache[workdir] = { text = text, ts = now() }
  return text
end

-- 시급도 우선순위: stale waiting > waiting > oldest working > oldest done
local URGENCY = { waiting = 1, working = 2, done = 3 }

local function urgencyScore(agent)
  if agent.status == "waiting" and agent._elapsed >= WAITING_ALERT_SEC then
    return 0
  end
  return URGENCY[agent.status] or 9
end

local function mostUrgent(agents)
  local pick = nil
  for _, agent in ipairs(agents) do
    if not pick then
      pick = agent
    else
      local sp, sa = urgencyScore(pick), urgencyScore(agent)
      if sa < sp or (sa == sp and (agent._elapsed or 0) > (pick._elapsed or 0)) then
        pick = agent
      end
    end
  end
  return pick
end

local function countByStatus(agents)
  local counts = { working = 0, waiting = 0, done = 0, staleWaiting = 0 }
  for _, agent in ipairs(agents) do
    local s = agent.status
    if s == "working" then
      counts.working = counts.working + 1
    elseif s == "waiting" then
      counts.waiting = counts.waiting + 1
      if agent._elapsed >= WAITING_ALERT_SEC then
        counts.staleWaiting = counts.staleWaiting + 1
      end
    elseif s == "done" then
      counts.done = counts.done + 1
    end
  end
  return counts
end

-- ══════════════════════════════════════════════════════════
-- 메뉴바 타이틀
-- ══════════════════════════════════════════════════════════

local function buildTitle(agents, counts)
  local total = #agents
  if total == 0 then return "wm" end

  if total == 1 then
    local a = agents[1]
    local mark = (a.status == "waiting" and a._elapsed >= WAITING_ALERT_SEC) and "⚠" or ""
    return string.format(
      "%s %s %s%s",
      statusIcon(a.status),
      truncate(handleOf(a), TITLE_HANDLE_MAX),
      formatElapsed(a._elapsed),
      mark
    )
  end

  -- 여러 agent: 모두 working만이면 count만 표시
  if counts.waiting == 0 and counts.done == 0 then
    return string.format("◉%d", counts.working)
  end

  local urgent = mostUrgent(agents)
  local parts = {}
  if counts.waiting > 0 then parts[#parts + 1] = "💬" .. counts.waiting end
  if counts.working > 0 then parts[#parts + 1] = "◉" .. counts.working end

  local mark = (urgent.status == "waiting" and urgent._elapsed >= WAITING_ALERT_SEC) and "⚠" or ""
  return string.format(
    "%s %s%s",
    table.concat(parts, ""),
    truncate(handleOf(urgent), TITLE_HANDLE_MAX_MULTI),
    mark
  )
end

-- ══════════════════════════════════════════════════════════
-- 네비게이션
-- ══════════════════════════════════════════════════════════

local function jumpToAgent(agent)
  local sess = agent.session_name
  local win = agent.window_name
  if not sess or not win then return end

  local target = sess .. ":" .. win
  local cmd = "tmux select-window -t " .. shellQuote(target)
                .. " 2>/dev/null; tmux switch-client -t " .. shellQuote(target)
                .. " 2>/dev/null"
  hs.task.new("/bin/zsh", nil, { "-lc", cmd }):start()
end

local function openDashboard()
  local cmd = "tmux new-window -S -n dashboard 'workmux dashboard' 2>/dev/null"
                .. " || tmux new-session -d -s wm-dash 'workmux dashboard'"
  hs.task.new("/bin/zsh", nil, { "-lc", cmd }):start()
end

-- ══════════════════════════════════════════════════════════
-- 알림
-- ══════════════════════════════════════════════════════════

local function maybeAlert(agents)
  if isPaused() then return end

  for _, agent in ipairs(agents) do
    if agent.status == "waiting" and agent._elapsed >= WAITING_ALERT_SEC then
      local paneId = agent._pane_id
      if paneId then
        local lastAt = lastAlertedAt[paneId] or 0
        if (now() - lastAt) >= ALERT_THROTTLE_SEC then
          lastAlertedAt[paneId] = now()
          local project = projectNameOf(agent.workdir)
          local handle = handleOf(agent)
          hs.notify.new({
            title = "workmux: 입력 대기",
            subTitle = project .. " · " .. handle,
            informativeText = formatElapsed(agent._elapsed) .. " 대기 중",
            soundName = hs.notify.defaultNotificationSound,
            autoWithdraw = false,
            hasActionButton = false,
          }):send()
        end
      end
    end
  end
end

-- ══════════════════════════════════════════════════════════
-- 드롭다운 메뉴
-- ══════════════════════════════════════════════════════════

local STATUS_PRIORITY = { waiting = 0, working = 1, done = 2 }

local function sortAgents(list)
  table.sort(list, function(a, b)
    local pa = STATUS_PRIORITY[a.status] or 9
    local pb = STATUS_PRIORITY[b.status] or 9
    if pa ~= pb then return pa < pb end
    return (a._elapsed or 0) > (b._elapsed or 0)
  end)
end

local function pauseSubmenu()
  local items = {}

  if isPaused() then
    local remaining = pausedUntil - now()
    items[#items + 1] = {
      title = "재개 (남은 " .. formatElapsed(remaining) .. ")",
      fn = function() pausedUntil = nil; M.refresh() end,
    }
    items[#items + 1] = { title = "-" }
  end

  items[#items + 1] = { title = "30분", fn = function() pausedUntil = now() + 1800 end }
  items[#items + 1] = { title = "1시간", fn = function() pausedUntil = now() + 3600 end }
  items[#items + 1] = {
    title = "내일 아침까지",
    fn = function()
      local t = os.date("*t")
      t.hour = 6; t.min = 0; t.sec = 0
      t.day = t.day + 1
      pausedUntil = os.time(t)
    end,
  }

  return items
end

local function buildMenu(agents)
  local menu = {}
  local counts = countByStatus(agents)

  local header = string.format(
    "◉ %d working · 💬 %d waiting · ✓ %d done",
    counts.working, counts.waiting, counts.done
  )
  menu[#menu + 1] = { title = header, disabled = true }

  if isPaused() then
    menu[#menu + 1] = {
      title = "🔕 알림 일시 정지 중 (" .. formatElapsed(pausedUntil - now()) .. " 남음)",
      disabled = true,
    }
  end

  menu[#menu + 1] = { title = "-" }

  if #agents == 0 then
    menu[#menu + 1] = { title = "활성 에이전트 없음", disabled = true }
  else
    local groups = groupByProject(agents)
    local projects = {}
    for p in pairs(groups) do projects[#projects + 1] = p end
    table.sort(projects)

    for i, project in ipairs(projects) do
      if i > 1 then menu[#menu + 1] = { title = "-" } end
      menu[#menu + 1] = { title = "📁 " .. project, disabled = true }

      sortAgents(groups[project])
      for _, agent in ipairs(groups[project]) do
        if not (agent.status == "done" and agent._elapsed > DONE_SHOW_WINDOW_SEC) then
          local icon = statusIcon(agent.status)
          local stale = (agent.status == "waiting" and agent._elapsed >= WAITING_ALERT_SEC) and " ⚠" or ""
          local handle = handleOf(agent)
          if handle == "" then handle = "(no name)" end
          local task = readTaskDescription(agent.workdir)

          local tooltipLines = {
            "Path: " .. (agent.workdir or ""),
            "Branch: " .. handle,
            "Status: " .. agent.status .. " · " .. formatElapsed(agent._elapsed),
          }
          if task ~= "" then
            table.insert(tooltipLines, 1, "Task: " .. task)
          end

          menu[#menu + 1] = {
            title = string.format("  %s %s  %s%s", icon, handle, formatElapsed(agent._elapsed), stale),
            fn = function() jumpToAgent(agent) end,
            tooltip = table.concat(tooltipLines, "\n"),
          }

          if task ~= "" then
            menu[#menu + 1] = {
              title = "       " .. task,
              disabled = true,
            }
          end
        end
      end
    end
  end

  menu[#menu + 1] = { title = "-" }
  menu[#menu + 1] = { title = "새로고침", fn = function() M.refresh() end, shortcut = "r" }
  menu[#menu + 1] = { title = "Dashboard 열기", fn = openDashboard }
  menu[#menu + 1] = { title = "알림 일시 정지", menu = pauseSubmenu() }

  return menu
end

-- ══════════════════════════════════════════════════════════
-- refresh
-- ══════════════════════════════════════════════════════════

function M.refresh()
  if not menubar then return end
  local agents = readAgents()
  local counts = countByStatus(agents)
  menubar:setTitle(buildTitle(agents, counts))
  menubar:setMenu(buildMenu(agents))
  maybeAlert(agents)
end

local function scheduleRefresh()
  if refreshDebounce then refreshDebounce:stop() end
  refreshDebounce = hs.timer.doAfter(PATHWATCH_DEBOUNCE_SEC, function()
    refreshDebounce = nil
    M.refresh()
  end)
end

-- ══════════════════════════════════════════════════════════
-- 라이프사이클
-- ══════════════════════════════════════════════════════════

function M.start()
  if menubar then return end

  menubar = hs.menubar.new()
  if not menubar then
    print("[workmux.menubar] 메뉴바 생성 실패")
    return
  end
  menubar:setTitle("wm")

  pathWatcher = hs.pathwatcher.new(STATE_DIR, function() scheduleRefresh() end)
  pathWatcher:start()

  safetyTimer = hs.timer.doEvery(POLL_INTERVAL_SEC, function() M.refresh() end)

  M.refresh()
end

function M.stop()
  if refreshDebounce then refreshDebounce:stop(); refreshDebounce = nil end
  if safetyTimer then safetyTimer:stop(); safetyTimer = nil end
  if pathWatcher then pathWatcher:stop(); pathWatcher = nil end
  if menubar then menubar:delete(); menubar = nil end
end

return M
