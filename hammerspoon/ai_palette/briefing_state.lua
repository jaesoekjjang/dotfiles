-- AI Palette :: Briefing State
-- ~/.briefing 디렉토리 하위의 state.json, active.json, archive 파일 관리
--
-- 저장 구조:
--   ~/.briefing/
--   ├── state.json              { last_checkpoint_time, last_morning_shown_date }
--   ├── stopping-points/
--   │   ├── active.json         [{ id, repo, branch, linear_id, worktree_name, note, created, last_touched }]
--   │   └── archive/YYYY-MM-DD.json
--   └── YYYY-MM-DD-{morning,evening}.md

local M = {}

local HOME = os.getenv("HOME")
local BASE_DIR = HOME .. "/.briefing"
local SP_DIR = BASE_DIR .. "/stopping-points"
local ARCHIVE_DIR = SP_DIR .. "/archive"
local STATE_PATH = BASE_DIR .. "/state.json"
local ACTIVE_PATH = SP_DIR .. "/active.json"

-- ── 디렉토리 보장 ─────────────────────────────────────────
local function ensureDirs()
  hs.execute("mkdir -p " .. SP_DIR .. " " .. ARCHIVE_DIR)
end

-- ── 파일 I/O 헬퍼 ─────────────────────────────────────────
local function readJson(path, fallback)
  local f = io.open(path, "r")
  if not f then return fallback end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then return fallback end
  local ok, data = pcall(hs.json.decode, content)
  if not ok then
    print("[briefing_state] JSON parse failed: " .. path)
    return fallback
  end
  return data
end

local function writeJson(path, data)
  ensureDirs()
  local encoded = hs.json.encode(data, true)
  local f = io.open(path, "w")
  if not f then
    print("[briefing_state] write failed: " .. path)
    return false
  end
  f:write(encoded)
  f:close()
  return true
end

-- ── state.json ────────────────────────────────────────────
function M.readState()
  return readJson(STATE_PATH, {})
end

function M.writeState(state)
  return writeJson(STATE_PATH, state)
end

-- 마지막 저녁 브리핑 체크포인트 시각 (epoch seconds)
-- 없으면 현재로부터 24시간 전을 반환
function M.lastCheckpointTime()
  local state = M.readState()
  return tonumber(state.last_checkpoint_time) or (os.time() - 86400)
end

function M.markEveningCompleted()
  local state = M.readState()
  state.last_checkpoint_time = os.time()
  M.writeState(state)
end

function M.alreadyShownMorningToday()
  local state = M.readState()
  return state.last_morning_shown_date == os.date("%Y-%m-%d")
end

function M.markMorningShown()
  local state = M.readState()
  state.last_morning_shown_date = os.date("%Y-%m-%d")
  M.writeState(state)
end

-- ── active.json (중단점) ──────────────────────────────────
function M.readActive()
  return readJson(ACTIVE_PATH, {})
end

function M.writeActive(entries)
  return writeJson(ACTIVE_PATH, entries)
end

-- repo + branch 조합으로 entry 찾기 (id 규약)
function M.entryId(repo, branch)
  return string.format("repo:%s#branch:%s", repo or "", branch or "")
end

-- upsert: 같은 id면 note 갱신 + last_touched 갱신, 없으면 새로 추가
function M.upsertEntry(entry)
  local active = M.readActive()
  local now = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local found = false

  for i, existing in ipairs(active) do
    if existing.id == entry.id then
      existing.note = entry.note or existing.note
      existing.path = entry.path or existing.path
      existing.linear_id = entry.linear_id or existing.linear_id
      existing.worktree_name = entry.worktree_name or existing.worktree_name
      existing.last_touched = now
      active[i] = existing
      found = true
      break
    end
  end

  if not found then
    entry.created = entry.created or now
    entry.last_touched = now
    active[#active + 1] = entry
  end

  M.writeActive(active)
end

-- 특정 id들의 entry 제거 (머지/정리 후 호출)
-- removed entries는 오늘의 archive에 append
function M.archiveEntries(idsToRemove)
  if not idsToRemove or #idsToRemove == 0 then return end

  local active = M.readActive()
  local remaining = {}
  local archived = {}

  local idSet = {}
  for _, id in ipairs(idsToRemove) do idSet[id] = true end

  for _, entry in ipairs(active) do
    if idSet[entry.id] then
      archived[#archived + 1] = entry
    else
      remaining[#remaining + 1] = entry
    end
  end

  if #archived > 0 then
    local today = os.date("%Y-%m-%d")
    local archivePath = ARCHIVE_DIR .. "/" .. today .. ".json"
    local existing = readJson(archivePath, {})
    for _, e in ipairs(archived) do
      e.archived_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
      existing[#existing + 1] = e
    end
    writeJson(archivePath, existing)
  end

  M.writeActive(remaining)
end

-- ── 마크다운 브리핑 로그 ──────────────────────────────────
function M.saveBriefingMd(kind, content)
  ensureDirs()
  local today = os.date("%Y-%m-%d")
  local path = string.format("%s/%s-%s.md", BASE_DIR, today, kind)
  local f = io.open(path, "w")
  if not f then return false, nil end
  f:write(content)
  f:close()
  return true, path
end

-- ── 디렉토리 경로 export (다른 모듈에서 참조용) ──────────
M.paths = {
  base = BASE_DIR,
  stoppingPoints = SP_DIR,
  archive = ARCHIVE_DIR,
  state = STATE_PATH,
  active = ACTIVE_PATH,
}

return M
