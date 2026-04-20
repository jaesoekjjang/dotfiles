-- AI Palette :: Evening Briefing
-- 저녁 하루 닫기: 오늘 한 일 + Tier A(오늘 활동 WIP) 중단점 입력 + Tier B(장기 WIP) 표시
--
-- 플로우:
--  1. collectAll(last_checkpoint_time) 로 git/calendar/workmux/linear 병렬 수집
--  2. Tier A/B 분류, 기존 active.json entry와 매칭해서 note prefill
--  3. 자동 archive: active entry 중 해당 브랜치가 이미 merged된 것 정리
--  4. Webview 렌더 (textarea input)
--  5. Save 버튼 → userContent callback → active.json upsert + MD 저장 + checkpoint mark

local M = {}

local shared = require("ai_palette.briefing_shared")
local state = require("ai_palette.briefing_state")

local STALE_WARN_DAYS = 7 -- Tier B에서 이 일수 넘으면 "정리 제안" 배지

local currentWebview = nil
local currentUserContent = nil

-- ══════════════════════════════════════════════════════════
-- 데이터 가공
-- ══════════════════════════════════════════════════════════

local function daysBetween(isoUtc, nowEpoch)
  if not isoUtc then return 0 end
  -- iso format: YYYY-MM-DDTHH:MM:SSZ
  local y, m, d, H, Min, S = isoUtc:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z")
  if not y then return 0 end
  local t = os.time({
    year = tonumber(y), month = tonumber(m), day = tonumber(d),
    hour = tonumber(H), min = tonumber(Min), sec = tonumber(S),
  })
  -- os.time은 local time 기준이라 UTC 보정 필요
  -- 대략적인 days 차이면 충분
  return math.floor((nowEpoch - t) / 86400)
end

-- 기존 active entries를 id → entry 맵으로
local function indexActive(active)
  local byId = {}
  for _, e in ipairs(active) do
    byId[e.id] = e
  end
  return byId
end

-- Tier A/B repo들을 UI용 카드 데이터로 변환
local function buildCards(tierA, tierB, activeById)
  local aCards, bCards = {}, {}
  local nowEpoch = os.time()

  for _, r in ipairs(tierA) do
    local id = state.entryId(r.name, r.branch)
    local existing = activeById[id]
    aCards[#aCards + 1] = {
      id = id,
      repo = r.name,
      branch = r.branch,
      path = r.path,
      dirty_count = r.dirty_count,
      dirty_files = r.dirty_files or {},
      merged = r.merged_to_main,
      prefill = existing and existing.note or "",
      last_touched = existing and existing.last_touched or nil,
    }
  end

  -- Tier B는 "중단점 기록된(active.json에 존재) + 오늘 활동 없음" 만 통과
  -- 이렇게 해야 dirty repo가 수십 개여도 사용자가 의도적으로 기록한 것만 남음
  for _, r in ipairs(tierB) do
    local id = state.entryId(r.name, r.branch)
    local existing = activeById[id]
    if existing then
      local staleDays = daysBetween(existing.last_touched, nowEpoch)
      bCards[#bCards + 1] = {
        id = id,
        repo = r.name,
        branch = r.branch,
        dirty_count = r.dirty_count,
        dirty_files = r.dirty_files or {},
        merged = r.merged_to_main,
        stale_days = staleDays,
        has_note = true,
        note = existing.note,
      }
    end
  end

  return aCards, bCards
end

-- porcelain status code를 짧은 레이블로
local STATUS_LABELS = {
  [" M"] = "modified", ["M "] = "modified(staged)", ["MM"] = "modified*",
  ["A "] = "added", [" A"] = "added", ["AM"] = "added*",
  ["D "] = "deleted", [" D"] = "deleted",
  ["R "] = "renamed", ["RM"] = "renamed*",
  ["C "] = "copied",
  ["??"] = "untracked",
  ["!!"] = "ignored",
  ["UU"] = "conflict",
}
local function statusLabel(code)
  return STATUS_LABELS[code] or code
end

-- 파일 목록 <ul> — expandable용
local function renderDirtyFiles(files)
  if not files or #files == 0 then return "" end
  local parts = { '<ul class="file-list">' }
  for _, f in ipairs(files) do
    local touchedMark = f.touched_today and '<span class="touched-dot" title="오늘 변경">●</span>' or ''
    parts[#parts + 1] = string.format(
      '<li><span class="file-status">%s</span>%s <span class="file-path mono">%s</span></li>',
      shared.escapeHtml(statusLabel(f.status)),
      touchedMark,
      shared.escapeHtml(f.path)
    )
  end
  parts[#parts + 1] = '</ul>'
  return table.concat(parts, "\n")
end

-- merged된 active entry들의 id 수집 (archive 대상)
-- 현재 repos에서 발견된 브랜치와 비교해서 merged flag 있으면 archive
local function findMergedToArchive(active, repos)
  local byId = {}
  for _, r in ipairs(repos or {}) do
    byId[state.entryId(r.name, r.branch)] = r
  end

  local toArchive = {}
  for _, entry in ipairs(active) do
    local r = byId[entry.id]
    if r and r.merged_to_main then
      toArchive[#toArchive + 1] = entry.id
    end
  end
  return toArchive
end

-- ══════════════════════════════════════════════════════════
-- HTML 렌더링
-- ══════════════════════════════════════════════════════════

local function renderCommitsSection(repos)
  local parts = {}
  local any = false

  for _, r in ipairs(repos or {}) do
    if r.commits_today and #r.commits_today > 0 then
      any = true
      parts[#parts + 1] = string.format(
        '<div class="repo-card"><div class="repo-head"><span class="repo-name">%s</span><span class="repo-branch">%s</span></div>',
        shared.escapeHtml(r.name), shared.escapeHtml(r.branch or "")
      )
      for _, commit in ipairs(r.commits_today) do
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
  end

  if not any then
    return '<div class="empty">오늘 커밋 없음</div>'
  end
  return table.concat(parts, "\n")
end

local function renderTierA(cards)
  if #cards == 0 then
    return '<div class="empty">오늘 건드린 미완 작업 없음 🎉</div>'
  end

  local parts = {}
  for _, c in ipairs(cards) do
    local mergeBadge = c.merged and '<span class="badge badge-ok">merged</span>' or ''
    parts[#parts + 1] = string.format([[
<div class="repo-card">
  <div class="repo-head">
    <span class="repo-name">%s</span>
    <span class="repo-branch">%s</span>
    <span class="badge badge-info">%d dirty</span>
    %s
    <button class="disclosure" data-target="files-%s" aria-expanded="false">▸ 파일</button>
  </div>
  <div class="file-list-wrap" id="files-%s" hidden>%s</div>
  <textarea class="note" data-entry-id="%s"
    placeholder="지금 뭐 하다 멈췄나 한 줄로 (내일 아침 복귀용)">%s</textarea>
</div>
    ]],
      shared.escapeHtml(c.repo),
      shared.escapeHtml(c.branch or ""),
      c.dirty_count,
      mergeBadge,
      shared.escapeHtml(c.id),
      shared.escapeHtml(c.id),
      renderDirtyFiles(c.dirty_files),
      shared.escapeHtml(c.id),
      shared.escapeHtml(c.prefill)
    )
  end
  return table.concat(parts, "\n")
end

local function renderTierB(cards)
  if #cards == 0 then
    return '<div class="empty">기록된 장기 WIP 없음 (중단점 입력된 항목 중 오늘 활동 있는 건 위쪽에 표시됨)</div>'
  end

  local parts = {}
  for _, c in ipairs(cards) do
    local staleBadge = ""
    if c.stale_days >= STALE_WARN_DAYS then
      staleBadge = string.format(
        '<span class="badge badge-warn">%d일째 정리 필요</span>', c.stale_days
      )
    elseif c.stale_days > 0 then
      staleBadge = string.format(
        '<span class="badge badge-info">%d일간 변경 없음</span>', c.stale_days
      )
    end
    local mergeBadge = c.merged and '<span class="badge badge-ok">merged</span>' or ''
    local noteBlock = ""
    if c.note and c.note ~= "" then
      noteBlock = string.format(
        '<div class="saved-note">%s</div>',
        shared.escapeHtml(c.note):gsub("\n", "<br>")
      )
    end
    parts[#parts + 1] = string.format([[
<div class="repo-card tier-b">
  <div class="repo-head">
    <span class="repo-name">%s</span>
    <span class="repo-branch">%s</span>
    <span class="badge badge-info">%d dirty</span>
    %s %s
    <button class="disclosure" data-target="filesb-%s" aria-expanded="false">▸ 파일</button>
  </div>
  %s
  <div class="file-list-wrap" id="filesb-%s" hidden>%s</div>
</div>
    ]],
      shared.escapeHtml(c.repo),
      shared.escapeHtml(c.branch or ""),
      c.dirty_count,
      staleBadge,
      mergeBadge,
      shared.escapeHtml(c.id),
      noteBlock,
      shared.escapeHtml(c.id),
      renderDirtyFiles(c.dirty_files)
    )
  end
  return table.concat(parts, "\n")
end

-- Linear: 오늘 활동이 있었던 이슈를 우선 표시, 나머지는 참고
local function renderLinear(issues)
  if issues == nil then
    return '<div class="empty">Linear 연결 안 됨 — ~/.secrets.zsh에 LINEAR_API_KEY 필요</div>'
  end
  if #issues == 0 then
    return '<div class="empty">할당된 이슈 없음</div>'
  end

  local todayPrefix = os.date("%Y-%m-%d")
  local todayActive, others = {}, {}
  for _, iss in ipairs(issues) do
    if iss.updatedAt and iss.updatedAt:sub(1, 10) == todayPrefix then
      todayActive[#todayActive + 1] = iss
    else
      others[#others + 1] = iss
    end
  end

  local function renderIssue(iss)
    local badges = {}
    if iss.state and iss.state.name then
      local cls = iss.state.type == "started" and "badge-info" or "badge-warn"
      badges[#badges + 1] = string.format('<span class="badge %s">%s</span>',
        cls, shared.escapeHtml(iss.state.name))
    end
    if iss.dueDate then
      if iss.dueDate < todayPrefix then
        badges[#badges + 1] = '<span class="badge badge-warn">기한 초과</span>'
      elseif iss.dueDate == todayPrefix then
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
  if #todayActive > 0 then
    parts[#parts + 1] = '<div style="font-size:11px;color:#9ca3af;margin:4px 0;">오늘 활동</div>'
    parts[#parts + 1] = '<ul style="list-style:none;padding:0;">'
    for _, iss in ipairs(todayActive) do parts[#parts + 1] = renderIssue(iss) end
    parts[#parts + 1] = '</ul>'
  end
  if #others > 0 then
    parts[#parts + 1] = '<div style="font-size:11px;color:#9ca3af;margin:10px 0 4px;">기타 할당됨</div>'
    parts[#parts + 1] = '<ul style="list-style:none;padding:0;">'
    for _, iss in ipairs(others) do parts[#parts + 1] = renderIssue(iss) end
    parts[#parts + 1] = '</ul>'
  end
  return table.concat(parts, "\n")
end

local function buildHtml(data, aCards, bCards, archivedCount)
  local greeting = shared.greeting("evening")
  local dateLabel = shared.todayLabel()

  local archivedBanner = ""
  if archivedCount and archivedCount > 0 then
    archivedBanner = string.format(
      '<div class="badge badge-ok" style="margin-bottom:16px; display:inline-block;">✓ 머지된 브랜치 %d건 아카이브됨</div>',
      archivedCount
    )
  end

  local extraStyles = [[
    .disclosure {
      background: transparent; border: 1px solid #2d2e32; color: #9ca3af;
      font-size: 11px; padding: 2px 8px; border-radius: 4px; cursor: pointer;
      margin-left: auto;
    }
    .disclosure:hover { background: #2d2e32; color: #e4e6ea; }
    .disclosure[aria-expanded="true"]::before { content: "▾ "; }
    .disclosure[aria-expanded="false"]::before { content: "▸ "; }
    .disclosure { overflow: visible; }
    .disclosure::before { margin-right: 2px; }
    /* 기존 텍스트 제거 ▸ 파일 대신 CSS로 */
    .file-list-wrap { margin-top: 8px; }
    ul.file-list { list-style: none; padding: 0; margin: 0; }
    ul.file-list li {
      font-size: 12px; padding: 3px 0; display: flex; gap: 8px; align-items: center;
      border-top: 1px dashed #2d2e32;
    }
    ul.file-list li:first-child { border-top: none; }
    .file-status {
      font-size: 10px; color: #9ca3af; text-transform: uppercase;
      letter-spacing: 0.5px; min-width: 90px;
    }
    .file-path { color: #c9ccd1; }
    .touched-dot { color: #34d399; font-size: 10px; }

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

  local html = string.format([[
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>%s
%s</style>
</head>
<body>
  <div class="greeting">%s</div>
  <div class="date">%s · 저녁 브리핑</div>

  %s

  <div class="section">
    <div class="section-title">💻 오늘 커밋</div>
    %s
  </div>

  <div class="section">
    <div class="section-title">📌 오늘 활동 WIP — 중단점 기록</div>
    %s
  </div>

  <div class="section">
    <div class="section-title">🗂 기록된 장기 WIP</div>
    %s
  </div>

  <div class="section">
    <div class="section-title">📋 Linear</div>
    %s
  </div>

  <button class="primary" id="save-btn">저장 & 닫기</button>

  <div class="footer">
    저장 위치: <code>~/.briefing/</code><br>
    · 저녁 마크다운: <code>~/.briefing/%s-evening.md</code><br>
    · 중단점: <code>~/.briefing/stopping-points/active.json</code><br>
    · 머지 아카이브: <code>~/.briefing/stopping-points/archive/%s.json</code>
  </div>

<script>
// "▸ 파일" 버튼은 CSS 가상요소로 표시하므로 innerText는 비우자
document.querySelectorAll('.disclosure').forEach(btn => {
  btn.innerText = '파일';
  btn.addEventListener('click', function(e) {
    e.preventDefault();
    const target = document.getElementById(this.dataset.target);
    if (!target) return;
    const open = target.hasAttribute('hidden');
    if (open) { target.removeAttribute('hidden'); } else { target.setAttribute('hidden', ''); }
    this.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
});

document.getElementById('save-btn').addEventListener('click', function() {
  const notes = {};
  document.querySelectorAll('textarea.note').forEach(t => {
    const id = t.dataset.entryId;
    const val = t.value.trim();
    if (id && val) notes[id] = val;
  });
  try {
    window.webkit.messageHandlers.briefing.postMessage({ action: 'save', notes: notes });
  } catch (e) { console.error(e); }
});

// Cmd+Enter로도 저장
document.addEventListener('keydown', function(e) {
  if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
    e.preventDefault();
    document.getElementById('save-btn').click();
  }
});
</script>
</body></html>
  ]],
    shared.baseStyles(),
    extraStyles,
    greeting,
    shared.escapeHtml(dateLabel),
    archivedBanner,
    renderCommitsSection(data.git),
    renderTierA(aCards),
    renderTierB(bCards),
    renderLinear(data.linear),
    os.date("%Y-%m-%d"),
    os.date("%Y-%m-%d")
  )

  return html
end

-- ══════════════════════════════════════════════════════════
-- Markdown export
-- ══════════════════════════════════════════════════════════

local function buildMarkdown(data, aCards, bCards, savedNotes, archivedCount)
  local lines = {}
  local function add(s) lines[#lines + 1] = s end

  add(string.format("# 저녁 브리핑 — %s", shared.todayLabel()))
  add("")

  if archivedCount and archivedCount > 0 then
    add(string.format("> 머지된 브랜치 %d건 자동 아카이브", archivedCount))
    add("")
  end

  add("## 오늘 커밋")
  local anyCommit = false
  for _, r in ipairs(data.git or {}) do
    if r.commits_today and #r.commits_today > 0 then
      anyCommit = true
      add(string.format("### %s (`%s`)", r.name, r.branch or ""))
      for _, c in ipairs(r.commits_today) do
        add("- " .. c)
      end
      add("")
    end
  end
  if not anyCommit then add("_없음_"); add("") end

  add("## 오늘 활동 WIP (중단점)")
  if #aCards == 0 then
    add("_없음_")
  else
    for _, c in ipairs(aCards) do
      local note = savedNotes[c.id]
      add(string.format("### %s (`%s`) — %d dirty", c.repo, c.branch or "", c.dirty_count))
      if note and note ~= "" then
        add("> " .. note:gsub("\n", "\n> "))
      else
        add("_(중단점 미입력)_")
      end
      add("")
    end
  end

  add("## 기록된 장기 WIP")
  if #bCards == 0 then
    add("_없음_")
  else
    for _, c in ipairs(bCards) do
      local suffix = ""
      if c.stale_days >= STALE_WARN_DAYS then
        suffix = string.format(" — **%d일째 정리 필요**", c.stale_days)
      elseif c.stale_days > 0 then
        suffix = string.format(" — %d일간 변경 없음", c.stale_days)
      end
      add(string.format("### %s (`%s`) %d dirty%s", c.repo, c.branch or "", c.dirty_count, suffix))
      if c.note and c.note ~= "" then
        add("> " .. c.note:gsub("\n", "\n> "))
      end
      add("")
    end
  end
  add("")

  add("## Linear")
  if data.linear == nil then
    add("_Linear 연결 안 됨_")
  elseif #data.linear == 0 then
    add("_할당된 이슈 없음_")
  else
    local today = os.date("%Y-%m-%d")
    for _, iss in ipairs(data.linear) do
      local marker = (iss.updatedAt and iss.updatedAt:sub(1, 10) == today) and "⚡ " or ""
      local state = iss.state and iss.state.name or "?"
      add(string.format("- %s`%s` %s — %s", marker,
        iss.identifier or "?", iss.title or "", state))
    end
  end

  return table.concat(lines, "\n") .. "\n"
end

-- ══════════════════════════════════════════════════════════
-- Submit 핸들러
-- ══════════════════════════════════════════════════════════

local function handleSubmit(msg, context)
  local body = msg and msg.body or {}
  local notes = body.notes or {}

  -- 1. active.json upsert (notes에 내용 있는 entry만)
  for _, c in ipairs(context.aCards) do
    local note = notes[c.id]
    if note and note ~= "" then
      state.upsertEntry({
        id = c.id,
        repo = c.repo,
        branch = c.branch,
        note = note,
      })
    end
  end

  -- 2. 체크포인트 갱신
  state.markEveningCompleted()

  -- 3. Markdown 저장
  local md = buildMarkdown(context.data, context.aCards, context.bCards, notes, context.archivedCount)
  local ok, path = state.saveBriefingMd("evening", md)
  if ok then
    print("[briefing_evening] saved: " .. path)
  end

  -- 4. Webview 닫기
  if currentWebview then
    currentWebview:delete()
    currentWebview = nil
  end
  currentUserContent = nil

  hs.alert.show("🌙 저녁 브리핑 저장됨")
end

-- ══════════════════════════════════════════════════════════
-- 메인 실행
-- ══════════════════════════════════════════════════════════

function M.run()
  if currentWebview then
    currentWebview:bringToFront(true)
    return
  end

  local alertUuid = hs.alert.show(
    "🌙 저녁 브리핑 데이터 수집 중...",
    nil, nil, 10
  )

  local sinceEpoch = state.lastCheckpointTime()

  shared.collectForEvening(sinceEpoch, function(data)
    if alertUuid then hs.alert.closeSpecific(alertUuid) end
    -- Tier 분류
    local tierA, tierB = shared.classifyRepos(data.git)

    -- 기존 active 로드 & merged 자동 archive
    local active = state.readActive()
    local mergedIds = findMergedToArchive(active, data.git)
    if #mergedIds > 0 then
      state.archiveEntries(mergedIds)
      active = state.readActive() -- reload
    end

    local activeById = indexActive(active)
    local aCards, bCards = buildCards(tierA, tierB, activeById)

    local context = {
      data = data,
      aCards = aCards,
      bCards = bCards,
      archivedCount = #mergedIds,
    }

    -- userContent 핸들러
    currentUserContent = hs.webview.usercontent.new("briefing")
    currentUserContent:setCallback(function(msg)
      handleSubmit(msg, context)
    end)

    local html = buildHtml(data, aCards, bCards, #mergedIds)

    -- makeWebview가 usercontent를 받지 않으므로 여기서 직접 생성
    local screen = hs.screen.mainScreen():frame()
    local w, h = 620, math.min(screen.h - 100, 820)
    local rect = hs.geometry.rect(
      screen.x + (screen.w - w) / 2,
      screen.y + 60,
      w, h
    )

    currentWebview = hs.webview.new(rect, { developerExtrasEnabled = true }, currentUserContent)
      :windowTitle("Evening Briefing")
      :windowStyle({ "titled", "closable", "resizable", "miniaturizable" })
      :allowTextEntry(true)
      :level(hs.drawing.windowLevels.floating)
      :html(html)
      :windowCallback(function(action)
        if action == "closing" then
          currentWebview = nil
          currentUserContent = nil
        end
      end)
      :show()
      :bringToFront(true)
  end)
end

return M
