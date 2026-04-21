-- AI Palette :: Morning Briefing
-- 하루 시작 input 제공: 어제 중단점 + 오늘 캘린더 + Linear + 어제 git 활동
--
-- 트리거:
--   - wake/unlock 자동 (하루 1회)
--   - Hyper+B 수동 (가드 없음, 항상 새로 생성)
--
-- 섹션:
--   1. 어제 중단점 (active.json 최신순) — 어제 저녁 기록 또는 과거 열린 WIP
--   2. 오늘 캘린더
--   3. Linear (키 있으면 assigned 이슈)
--   4. 어제 git 활동 (어제 00:00 이후 commits)
--
-- UI: read-only webview + markdown 저장

local M = {}

local shared = require("ai_palette.briefing_shared")
local state = require("ai_palette.briefing_state")

local currentWebview = nil

-- ══════════════════════════════════════════════════════════
-- 시각/날짜 헬퍼
-- ══════════════════════════════════════════════════════════

-- 어제 00:00 epoch (local time 기준)
local function yesterdayStartEpoch()
  local now = os.date("*t")
  -- 오늘 00:00
  local todayStart = os.time({
    year = now.year, month = now.month, day = now.day,
    hour = 0, min = 0, sec = 0,
  })
  return todayStart - 86400 -- 24시간 전
end

local function daysAgoLabel(isoUtc, nowEpoch)
  if not isoUtc then return "" end
  local y, m, d = isoUtc:match("(%d+)-(%d+)-(%d+)")
  if not y then return "" end
  local t = os.time({
    year = tonumber(y), month = tonumber(m), day = tonumber(d),
    hour = 0, min = 0, sec = 0,
  })
  local diff = math.floor((nowEpoch - t) / 86400)
  if diff <= 0 then return "오늘" end
  if diff == 1 then return "어제" end
  return string.format("%d일 전", diff)
end

-- ══════════════════════════════════════════════════════════
-- 렌더링
-- ══════════════════════════════════════════════════════════

local STATUS_LABELS = {
  [" M"] = "modified", ["M "] = "modified(staged)", ["MM"] = "modified*",
  ["A "] = "added", [" A"] = "added", ["AM"] = "added*",
  ["D "] = "deleted", [" D"] = "deleted",
  ["R "] = "renamed", ["RM"] = "renamed*",
  ["??"] = "untracked", ["UU"] = "conflict",
}

local function renderStoppingPoints(entries)
  if not entries or #entries == 0 then
    return '<div class="empty">열린 중단점 없음</div>'
  end

  -- last_touched 기준 최신순
  table.sort(entries, function(a, b)
    return (a.last_touched or "") > (b.last_touched or "")
  end)

  local nowEpoch = os.time()
  local parts = {}
  for _, e in ipairs(entries) do
    local ageLabel = daysAgoLabel(e.last_touched, nowEpoch)
    parts[#parts + 1] = string.format([[
<div class="repo-card">
  <div class="repo-head">
    <span class="repo-name">%s</span>
    <span class="repo-branch">%s</span>
    <span class="badge badge-info">%s</span>
  </div>
  <div class="saved-note">%s</div>
</div>
    ]],
      shared.escapeHtml(e.repo or "?"),
      shared.escapeHtml(e.branch or ""),
      shared.escapeHtml(ageLabel),
      shared.escapeHtml(e.note or ""):gsub("\n", "<br>")
    )
  end
  return table.concat(parts, "\n")
end

local function renderCalendar(events)
  if not events or #events == 0 then
    return '<div class="empty">오늘 일정 없음</div>'
  end
  local parts = { '<ul style="list-style:none;padding:0;">' }
  for _, evt in ipairs(events) do
    parts[#parts + 1] = string.format(
      '<li class="item"><span class="mono" style="min-width:110px;display:inline-block;color:#818cf8;">%s</span>%s</li>',
      shared.escapeHtml(evt.time),
      shared.escapeHtml(evt.title)
    )
  end
  parts[#parts + 1] = '</ul>'
  return table.concat(parts, "\n")
end

local function renderLinear(issues)
  if issues == nil then
    return '<div class="empty">Linear 연결 안 됨 — ~/.secrets.zsh에 LINEAR_API_KEY 필요</div>'
  end
  if #issues == 0 then
    return '<div class="empty">할당된 이슈 없음</div>'
  end

  -- 상태별 + 마감일 순
  local started, unstarted = {}, {}
  for _, iss in ipairs(issues) do
    if iss.state and iss.state.type == "started" then
      started[#started + 1] = iss
    else
      unstarted[#unstarted + 1] = iss
    end
  end

  local today = os.date("%Y-%m-%d")
  local function renderIssue(iss)
    local badges = {}
    if iss.dueDate then
      if iss.dueDate < today then
        badges[#badges + 1] = '<span class="badge badge-warn">기한 초과</span>'
      elseif iss.dueDate == today then
        badges[#badges + 1] = '<span class="badge badge-warn">오늘 마감</span>'
      end
    end
    return string.format(
      '<li class="item"><span class="mono">%s</span> %s %s</li>',
      shared.escapeHtml(iss.identifier or "?"),
      shared.escapeHtml(iss.title or ""),
      table.concat(badges, " ")
    )
  end

  local parts = {}
  if #started > 0 then
    parts[#parts + 1] = '<div style="font-size:11px;color:#9ca3af;margin:4px 0;">진행 중</div>'
    parts[#parts + 1] = '<ul style="list-style:none;padding:0;">'
    for _, iss in ipairs(started) do parts[#parts + 1] = renderIssue(iss) end
    parts[#parts + 1] = '</ul>'
  end
  if #unstarted > 0 then
    parts[#parts + 1] = '<div style="font-size:11px;color:#9ca3af;margin:10px 0 4px;">대기</div>'
    parts[#parts + 1] = '<ul style="list-style:none;padding:0;">'
    for _, iss in ipairs(unstarted) do parts[#parts + 1] = renderIssue(iss) end
    parts[#parts + 1] = '</ul>'
  end
  return table.concat(parts, "\n")
end

-- 어제 git 활동: commits_since가 있는 repo만 표시
local function renderYesterdayGit(repos)
  local active = {}
  for _, r in ipairs(repos or {}) do
    if r.commits_since and #r.commits_since > 0 then
      active[#active + 1] = r
    end
  end

  if #active == 0 then
    return '<div class="empty">어제 커밋 없음</div>'
  end

  local parts = {}
  for _, r in ipairs(active) do
    parts[#parts + 1] = string.format(
      '<div class="repo-card"><div class="repo-head"><span class="repo-name">%s</span><span class="repo-branch">%s</span></div>',
      shared.escapeHtml(r.name), shared.escapeHtml(r.branch or "")
    )
    for _, commit in ipairs(r.commits_since) do
      local hash, msg = commit:match("^(%S+)%s(.+)")
      if hash then
        parts[#parts + 1] = string.format(
          '<div class="commit-msg"><span class="commit-hash">%s</span> %s</div>',
          shared.escapeHtml(hash), shared.escapeHtml(msg)
        )
      end
    end
    parts[#parts + 1] = '</div>'
  end
  return table.concat(parts, "\n")
end

local function buildHtml(data, activeEntries)
  local greeting = shared.greeting("morning")
  local dateLabel = shared.todayLabel()

  local extraStyles = [[
    .saved-note {
      background: #14151a; border-left: 2px solid #818cf8;
      padding: 8px 10px; margin-top: 8px;
      font-size: 12px; color: #c9ccd1; line-height: 1.5;
    }
    .footer {
      margin-top: 32px; padding-top: 16px; border-top: 1px solid #2d2e32;
      font-size: 11px; color: #6b7280; line-height: 1.8;
    }
    .footer code { background: #14151a; padding: 1px 6px; border-radius: 3px; color: #818cf8; }
  ]]

  return string.format([[
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>%s
%s</style>
</head>
<body>
  <div class="greeting">%s</div>
  <div class="date">%s · 아침 브리핑</div>

  <div class="section">
    <div class="section-title">📌 어제 중단점</div>
    %s
  </div>

  <div class="section">
    <div class="section-title">📅 오늘 일정</div>
    %s
  </div>

  <div class="section">
    <div class="section-title">📋 Linear 할당 이슈</div>
    %s
  </div>

  <div class="section">
    <div class="section-title">💻 어제 git 활동</div>
    %s
  </div>

  <div class="footer">
    저장 위치: <code>~/.briefing/%s-morning.md</code><br>
    수동 호출: <code>Hyper+B</code> (Cmd+Ctrl+Shift+B)
  </div>
</body></html>
  ]],
    shared.baseStyles(),
    extraStyles,
    greeting,
    shared.escapeHtml(dateLabel),
    renderStoppingPoints(activeEntries),
    renderCalendar(data.calendar),
    renderLinear(data.linear),
    renderYesterdayGit(data.git),
    os.date("%Y-%m-%d")
  )
end

-- ══════════════════════════════════════════════════════════
-- Markdown export
-- ══════════════════════════════════════════════════════════

local function buildMarkdown(data, activeEntries)
  local lines = {}
  local function add(s) lines[#lines + 1] = s end

  add(string.format("# 아침 브리핑 — %s", shared.todayLabel()))
  add("")

  add("## 어제 중단점")
  if not activeEntries or #activeEntries == 0 then
    add("_없음_")
  else
    local nowEpoch = os.time()
    table.sort(activeEntries, function(a, b)
      return (a.last_touched or "") > (b.last_touched or "")
    end)
    for _, e in ipairs(activeEntries) do
      add(string.format("### %s (`%s`) — %s",
        e.repo or "?", e.branch or "", daysAgoLabel(e.last_touched, nowEpoch)))
      if e.note and e.note ~= "" then
        add("> " .. e.note:gsub("\n", "\n> "))
      end
      add("")
    end
  end

  add("## 오늘 일정")
  if not data.calendar or #data.calendar == 0 then
    add("_없음_")
  else
    for _, evt in ipairs(data.calendar) do
      add(string.format("- `%s` %s", evt.time, evt.title))
    end
  end
  add("")

  add("## Linear 할당 이슈")
  if data.linear == nil then
    add("_Linear 연결 안 됨_")
  elseif #data.linear == 0 then
    add("_없음_")
  else
    for _, iss in ipairs(data.linear) do
      local s = iss.state and iss.state.name or "?"
      add(string.format("- `%s` %s — %s",
        iss.identifier or "?", iss.title or "", s))
    end
  end
  add("")

  add("## 어제 git 활동")
  local any = false
  for _, r in ipairs(data.git or {}) do
    if r.commits_since and #r.commits_since > 0 then
      any = true
      add(string.format("### %s (`%s`)", r.name, r.branch or ""))
      for _, c in ipairs(r.commits_since) do
        add("- " .. c)
      end
      add("")
    end
  end
  if not any then add("_없음_"); add("") end

  return table.concat(lines, "\n") .. "\n"
end

-- ══════════════════════════════════════════════════════════
-- Webview
-- ══════════════════════════════════════════════════════════

local function showBriefing(html)
  if currentWebview then
    currentWebview:delete()
    currentWebview = nil
  end

  local screen = hs.screen.mainScreen():frame()
  local w, h = 560, math.min(screen.h - 100, 820)
  local rect = hs.geometry.rect(
    screen.x + (screen.w - w) / 2,
    screen.y + 60,
    w, h
  )

  local urlScheme = require("url_scheme")
  currentWebview = hs.webview.new(rect)
    :windowTitle("Morning Briefing")
    :windowStyle({ "titled", "closable", "resizable", "miniaturizable" })
    :allowTextEntry(false)
    :level(hs.drawing.windowLevels.floating)
    :policyCallback(urlScheme.webviewPolicy)
    :html(html)
    :windowCallback(function(action)
      if action == "closing" then currentWebview = nil end
    end)
    :show()
    :bringToFront(true)
end

-- ══════════════════════════════════════════════════════════
-- 메인 실행
-- ══════════════════════════════════════════════════════════

local function runBriefing()
  local alertUuid = hs.alert.show(
    "☀️ 아침 브리핑 데이터 수집 중... (Calendar ~10초)",
    nil, nil, 20
  )

  local sinceEpoch = yesterdayStartEpoch()

  shared.collectForMorning(sinceEpoch, function(data)
    if alertUuid then hs.alert.closeSpecific(alertUuid) end

    local activeEntries = state.readActive()
    local html = buildHtml(data, activeEntries)
    showBriefing(html)

    -- markdown 저장
    local md = buildMarkdown(data, activeEntries)
    local ok, path = state.saveBriefingMd("morning", md)
    if ok then print("[briefing] saved: " .. path) end
  end)
end

-- ── 수동 실행용 (항상 새로 생성) ─────────────────────────
function M.run()
  runBriefing()
end

-- ── 자동 실행 (하루 1회 가드) ─────────────────────────────
function M.runAuto()
  if state.alreadyShownMorningToday() then return end
  state.markMorningShown()
  runBriefing()
end

-- ── Wake/unlock watcher ──────────────────────────────────
function M.setupWatcher()
  M.watcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidUnlock
      or event == hs.caffeinate.watcher.systemDidWake then
      if not state.alreadyShownMorningToday() then
        -- 잠금해제 직후 바로 띄우면 화면 전환이 어색하므로 약간 딜레이
        hs.timer.doAfter(3, function()
          if not state.alreadyShownMorningToday() then
            state.markMorningShown()
            runBriefing()
          end
        end)
      end
    end
  end)
  M.watcher:start()
end

return M
