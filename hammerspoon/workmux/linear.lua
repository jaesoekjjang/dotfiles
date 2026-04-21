-- Linear GraphQL 래퍼
-- Hammerspoon GUI는 ~/.secrets.zsh를 자동 소싱 안 함 → curl을 서브쉘에서 실행하며
-- source ~/.secrets.zsh로 LINEAR_API_KEY 로드 (briefing_shared.lua와 동일 패턴)

local M = {}

-- ══════════════════════════════════════════════════════════
-- 저수준 쿼리
-- ══════════════════════════════════════════════════════════

-- callback(data, err)
function M.query(queryStr, callback)
  local jsonQuery = queryStr:gsub("\n", " "):gsub('"', '\\"'):gsub("%s+", " ")

  local cmd = string.format([[
    [ -f ~/.secrets.zsh ] && source ~/.secrets.zsh
    [ -z "$LINEAR_API_KEY" ] && exit 99
    curl -s -w '\n__HTTP_STATUS:%%{http_code}' -X POST https://api.linear.app/graphql \
      -H "Content-Type: application/json" \
      -H "Authorization: $LINEAR_API_KEY" \
      -d '{"query": "%s"}' --max-time 10
  ]], jsonQuery)

  local task = hs.task.new("/bin/zsh", function(exitCode, stdout, stderr)
    print("[linear] task exit:", exitCode, "stdout 길이:", stdout and #stdout or 0)

    if exitCode == 99 then
      callback(nil, "LINEAR_API_KEY 없음 (~/.secrets.zsh에 추가 필요)")
      return
    end

    if exitCode ~= 0 then
      callback(nil, string.format("curl 실패 (exit %d): %s", exitCode, (stderr or ""):sub(1, 200)))
      return
    end

    if not stdout or stdout == "" then
      callback(nil, "빈 응답")
      return
    end

    -- 뒷줄의 __HTTP_STATUS 분리
    local body, httpStatus = stdout:match("^(.-)\n?__HTTP_STATUS:(%d+)%s*$")
    if not body then
      body = stdout
      httpStatus = "?"
    end

    print("[linear] HTTP status:", httpStatus)

    if httpStatus ~= "200" then
      callback(nil, string.format("HTTP %s: %s", httpStatus, body:sub(1, 200)))
      return
    end

    local ok, decoded = pcall(hs.json.decode, body)
    if not ok or not decoded then
      callback(nil, "JSON 디코드 실패: " .. body:sub(1, 200))
      return
    end

    if decoded.errors then
      local msg = decoded.errors[1] and decoded.errors[1].message or "GraphQL error"
      callback(nil, msg)
      return
    end

    callback(decoded.data, nil)
  end, { "-c", cmd })

  task:setWorkingDirectory("/tmp")
  task:start()
end

-- ══════════════════════════════════════════════════════════
-- 고수준 쿼리
-- ══════════════════════════════════════════════════════════

-- 내게 할당된 active 이슈 (unstarted + started), 최근 업데이트 순
function M.getMyActiveIssues(callback)
  local q = [[
    query {
      viewer {
        assignedIssues(
          filter: { state: { type: { in: ["unstarted", "started"] } } }
          first: 30
          orderBy: updatedAt
        ) {
          nodes {
            id
            identifier
            title
            branchName
            priority
            url
            state { name type }
            team { key name }
            project { name }
          }
        }
      }
    }
  ]]

  M.query(q, function(data, err)
    if err then callback(nil, err); return end
    local nodes = data
      and data.viewer
      and data.viewer.assignedIssues
      and data.viewer.assignedIssues.nodes
    callback(nodes or {}, nil)
  end)
end

return M
