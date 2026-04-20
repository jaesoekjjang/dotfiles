-- AI Palette :: Network Error Report
-- DevTools에서 Copy as cURL 한 뒤 단축키 → 깔끔한 마크다운이 클립보드에 복사됨
-- LLM 불필요 — cURL을 직접 파싱하고 실행해서 응답까지 포함

local M = {}

-- ── cURL 파서 ──────────────────────────────────────────────
local function parseCurl(raw)
  local r = {
    method = "GET",
    url = nil,
    headers = {},
    body = nil,
  }

  -- URL 추출: curl 'URL' 또는 curl "URL" 또는 curl URL
  r.url = raw:match("^curl%s+['\"]([^'\"]+)['\"]")
       or raw:match("^curl%s+(%S+)")

  -- -X / --request METHOD
  r.method = raw:match("%-X%s+['\"]?(%w+)['\"]?")
          or raw:match("%-%-request%s+['\"]?(%w+)['\"]?")
          or r.method

  -- -H 'Key: Value' (single-quote, double-quote 모두 처리)
  for key, val in raw:gmatch("%-H%s+'([^:]+):%s*([^']*)'") do
    r.headers[key] = val
  end
  for key, val in raw:gmatch("%-H%s+\"([^:]+):%s*([^\"]*)\"") do
    r.headers[key] = val
  end

  -- --data / --data-raw / -d
  r.body = raw:match("%-%-data%-raw%s+'([^']*)'")
        or raw:match("%-%-data%-raw%s+\"([^\"]*)\"")
        or raw:match("%-%-data%-raw%s+%$'(.-)'")
        or raw:match("%-%-data%s+'([^']*)'")
        or raw:match("%-%-data%s+\"([^\"]*)\"")
        or raw:match("%-d%s+'([^']*)'")
        or raw:match("%-d%s+\"([^\"]*)\"")

  if r.body then
    r.body = r.body:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub("\\'", "'")
  end

  return r
end

-- ── 민감 정보 마스킹 ───────────────────────────────────────
local SENSITIVE_KEYS = {
  ["authorization"] = true,
  ["cookie"] = true,
  ["set-cookie"] = true,
  ["x-api-key"] = true,
  ["x-auth-token"] = true,
}

local function maskValue(key, val)
  if SENSITIVE_KEYS[key:lower()] then
    local prefix = val:match("^(%w+)%s+")
    if prefix then
      return prefix .. " ****"
    end
    return "(존재함, 값 마스킹)"
  end
  return val
end

-- ── JSON pretty-print ─────────────────────────────────────
local function prettyJson(str)
  if not str then return nil end
  local ok, decoded = pcall(hs.json.decode, str)
  if ok and decoded then
    return hs.json.encode(decoded, true)
  end
  return str
end

-- ── URL 분리 (host, path, query) ──────────────────────────
local function parseUrl(url)
  if not url then return "/", nil, nil end
  local host = url:match("https?://([^/]+)") or ""
  local pathAndQuery = url:match("https?://[^/]+(/[^?]*)") or "/"
  local query = url:match("%?(.+)$")
  return pathAndQuery, query, host
end

-- ── 디버깅용 헤더 필터 (백엔드 전달에 유의미한 것만) ──────
local DEBUG_HEADERS = {
  ["content-type"] = true,
  ["authorization"] = true,
  ["x-request-id"] = true,
  ["x-trace-id"] = true,
  ["x-correlation-id"] = true,
}

-- ── Status 텍스트 매핑 ────────────────────────────────────
local STATUS_TEXT = {
  ["000"] = "연결 실패 (서버 응답 없음)",
  ["400"] = "Bad Request",
  ["401"] = "Unauthorized",
  ["403"] = "Forbidden",
  ["404"] = "Not Found",
  ["405"] = "Method Not Allowed",
  ["408"] = "Request Timeout",
  ["409"] = "Conflict",
  ["413"] = "Payload Too Large",
  ["422"] = "Unprocessable Entity",
  ["429"] = "Too Many Requests",
  ["500"] = "Internal Server Error",
  ["502"] = "Bad Gateway",
  ["503"] = "Service Unavailable",
  ["504"] = "Gateway Timeout",
}

-- ── 마크다운 리포트 생성 ───────────────────────────────────
local function buildReport(parsed, response)
  local lines = {}
  local function add(s) lines[#lines + 1] = s end

  local path, query, host = parseUrl(parsed.url)
  local timestamp = os.date("%Y-%m-%d %H:%M")
  local statusCode = response and response.status or nil
  local statusText = statusCode and STATUS_TEXT[statusCode] or nil

  -- 헤더
  add("# 🔴 API Error Report")
  add("")
  add(string.format("**Endpoint:** `%s %s`", parsed.method, path))

  if statusCode then
    if statusText then
      add(string.format("**Status:** `%s %s`", statusCode, statusText))
    else
      add(string.format("**Status:** `%s`", statusCode))
    end
  end

  add(string.format("**Host:** `%s`", host))
  add(string.format("**Time:** %s", timestamp))
  add("")

  -- Query Parameters
  if query then
    add("## Query Parameters")
    add("")
    for pair in query:gmatch("[^&]+") do
      local k, v = pair:match("([^=]+)=?(.*)")
      if k then
        k = k:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        v = v:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        add(string.format("- `%s`: `%s`", k, v))
      end
    end
    add("")
  end

  -- Request Body
  if parsed.body then
    add("## Request Body")
    add("")
    add("```json")
    add(prettyJson(parsed.body) or parsed.body)
    add("```")
    add("")
  end

  -- Response
  add("## Response")
  add("")
  if statusCode == "000" then
    add("> ⚠️ 서버에 연결할 수 없음 — 서버가 내려갔거나 네트워크 문제일 수 있습니다.")
    add("")
  elseif response and response.body and response.body:gsub("%s+", "") ~= "" then
    add("```json")
    add(prettyJson(response.body) or response.body)
    add("```")
    add("")
  else
    add("> 응답 본문 없음")
    add("")
  end

  -- 헤더 (디버깅에 유의미한 것만)
  local debugHeaders = {}
  for k, v in pairs(parsed.headers) do
    if DEBUG_HEADERS[k:lower()] then
      debugHeaders[#debugHeaders + 1] = { key = k, val = maskValue(k, v) }
    end
  end

  if #debugHeaders > 0 then
    add("## Headers")
    add("")
    for _, h in ipairs(debugHeaders) do
      add(string.format("- **%s:** `%s`", h.key, h.val))
    end
    add("")
  end

  return table.concat(lines, "\n")
end

-- ── 메인 함수 ──────────────────────────────────────────────
function M.run()
  local clipContent = hs.pasteboard.getContents()

  if not clipContent or clipContent == "" then
    hs.alert.show("❌ 클립보드가 비어있습니다\nDevTools에서 Copy as cURL 후 다시 시도해주세요")
    return
  end

  local trimmed = clipContent:gsub("^%s+", "")
  if not trimmed:match("^curl%s+") then
    hs.alert.show("❌ 클립보드에 cURL 명령이 없습니다\nDevTools → Copy as cURL 후 다시 시도해주세요")
    return
  end

  local parsed = parseCurl(trimmed)

  if not parsed.url then
    hs.alert.show("❌ cURL에서 URL을 파싱할 수 없습니다")
    return
  end

  local report = buildReport(parsed, nil)
  hs.pasteboard.setContents(report)
  hs.alert.show("✅ API Error Report → 클립보드 복사 완료")
end

return M
