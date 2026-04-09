-- AI Palette :: Code Review
-- Chrome에서 PR/MR 페이지를 보고 있을 때 diff를 가져와 Claude로 리뷰 후 webview에 표시

local M = {}
local llm = require("ai_palette.llm")

-- ── 상태 관리 ──────────────────────────────────────────────
local activeTask = nil   -- 현재 실행 중인 hs.task (취소용)
local escTap = nil       -- ESC 이벤트 리스너

-- ── 취소 ───────────────────────────────────────────────────
local function cancelReview()
  if activeTask then
    activeTask:terminate()
    activeTask = nil
  end
  stopSpinner()
  hs.alert.show("⛔ 리뷰 취소됨")
end

local function startEscListener()
  if escTap then escTap:stop() end
  escTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
    if e:getKeyCode() == 53 then -- 53 = ESC
      cancelReview()
      return true -- 이벤트 소비
    end
    return false
  end)
  escTap:start()
end

local function stopEscListener()
  if escTap then escTap:stop(); escTap = nil end
end

-- ── 스피너 (진행 상태 표시) ────────────────────────────────
local spinnerCanvas = nil
local spinnerTimer = nil
local spinnerFrame = 1
local spinnerPhase = ""

local function startSpinner(phase)
  spinnerPhase = phase or "처리 중"
  spinnerFrame = 1
  local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

  if spinnerCanvas then spinnerCanvas:delete() end

  local screen = hs.screen.mainScreen():frame()
  spinnerCanvas = hs.canvas.new({ x = screen.x + screen.w / 2 - 160, y = screen.y + 40, w = 320, h = 56 })
  spinnerCanvas:insertElement({
    type = "rectangle",
    action = "fill",
    roundedRectRadii = { xRadius = 10, yRadius = 10 },
    fillColor = { red = 0.05, green = 0.07, blue = 0.1, alpha = 0.92 },
  })
  spinnerCanvas:insertElement({
    type = "text",
    text = "",
    textFont = ".AppleSystemUIFont",
    textSize = 15,
    textColor = { red = 0.9, green = 0.93, blue = 0.96, alpha = 1 },
    textAlignment = "center",
    frame = { x = "0", y = "0.18", w = "1", h = "0.8" },
  })
  -- ESC 힌트 추가
  spinnerCanvas:insertElement({
    type = "text",
    text = "ESC로 취소",
    textFont = ".AppleSystemUIFont",
    textSize = 10,
    textColor = { red = 0.55, green = 0.58, blue = 0.62, alpha = 1 },
    textAlignment = "center",
    frame = { x = "0", y = "0.65", w = "1", h = "0.35" },
  })
  spinnerCanvas:level(hs.canvas.windowLevels.overlay)
  spinnerCanvas:show()

  spinnerTimer = hs.timer.doEvery(0.1, function()
    spinnerFrame = (spinnerFrame % #frames) + 1
    if spinnerCanvas and spinnerCanvas[2] then
      spinnerCanvas[2].text = frames[spinnerFrame] .. "  " .. spinnerPhase
    end
  end)

  startEscListener()
end

local function updateSpinner(phase)
  spinnerPhase = phase or spinnerPhase
end

local function stopSpinner()
  stopEscListener()
  if spinnerTimer then spinnerTimer:stop(); spinnerTimer = nil end
  if spinnerCanvas then spinnerCanvas:delete(); spinnerCanvas = nil end
end

-- ── Provider 설정 ──────────────────────────────────────────
-- GitHub / GitLab 자동 감지. GitLab self-hosted 도 URL 패턴으로 확장 가능.
local providers = {
  {
    name = "github",
    pattern = "github%.com/([^/]+)/([^/]+)/pull/(%d+)",
    bin = "gh",
    diffArgs = function(owner, repo, number)
      return { "pr", "diff", number, "-R", owner .. "/" .. repo }
    end,
  },
  {
    name = "gitlab",
    -- https://gitlab.gabia.com/gabia/services/gic.gabia.com/-/merge_requests/198/diffs
    pattern = "gitlab%.gabia%.com/(.+)/%-/merge_requests/(%d+)",
    bin = "glab",
    env = "GITLAB_HOST=gitlab.gabia.com GITLAB_TOKEN=$GITLAB_TOKEN",
    diffArgs = function(project, number)
      return { "mr", "diff", number, "-R", project }
    end,
  },
}

-- ── URL → Provider 매칭 ────────────────────────────────────
local function matchProvider(url)
  for _, p in ipairs(providers) do
    local captures = { url:match(p.pattern) }
    if #captures > 0 then
      return p, captures
    end
  end
  return nil
end

-- ── 비동기 task 실행 ───────────────────────────────────────
-- hs.task는 symlink된 바이너리를 못 열 수 있어서 bash -c 로 감싼다
local function runTask(bin, args, callback, env)
  local cmd = ""
  if env then cmd = env .. " " end
  cmd = cmd .. bin
  for _, a in ipairs(args) do
    cmd = cmd .. " " .. string.format("%q", a)
  end
  local task = hs.task.new("/bin/zsh", function(exitCode, stdout, stderr)
    activeTask = nil
    callback(exitCode, stdout, stderr)
  end, { "-lc", cmd })
  activeTask = task
  task:start()
end

-- ── Webview로 결과 표시 ────────────────────────────────────
local reviewWebview = nil

local function showReview(title, reviewMarkdown)
  if reviewWebview then
    reviewWebview:delete()
    reviewWebview = nil
  end

  local escapedReview = reviewMarkdown
    :gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

  local html = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    background: #f5f0e8; color: #3b3730;
    padding: 24px; line-height: 1.6;
  }
  .header {
    border-bottom: 1px solid #e0d9cd; padding-bottom: 16px; margin-bottom: 20px;
  }
  .header h1 { font-size: 18px; color: #8b5c2a; margin-bottom: 4px; }
  .header .meta { font-size: 12px; color: #9a9080; }
  .content {
    font-size: 14px; white-space: pre-wrap; word-wrap: break-word;
  }
</style>
</head>
<body>
  <div class="header">
    <h1>]] .. (title or "Code Review") .. [[</h1>
    <div class="meta">Reviewed by Claude · ]] .. os.date("%Y-%m-%d %H:%M") .. [[</div>
  </div>
  <div class="content">]] .. escapedReview .. [[</div>
</body>
</html>
]]

  local screen = hs.screen.mainScreen():frame()
  local w, h = 700, math.min(screen.h - 100, 900)
  local rect = hs.geometry.rect(screen.x + screen.w - w - 20, screen.y + 60, w, h)

  reviewWebview = hs.webview.new(rect, { privateMode = false })
    :windowTitle("AI Code Review")
    :windowStyle({ "titled", "closable", "resizable", "miniaturizable" })
    :html(html)
    :allowTextEntry(false)
    :level(hs.drawing.windowLevels.floating)
    :windowCallback(function(action)
      if action == "closing" then
        reviewWebview = nil
      end
    end)
    :show()
    :bringToFront(true)
end

-- ── 리뷰 프롬프트 ──────────────────────────────────────────
local REVIEW_PROMPT = [[You are a senior software engineer doing a code review.
Review the following PR diff. Be concise and actionable.

Format your review clearly with sections (Summary, Issues, Good, Verdict).
Tag issues with severity: [CRITICAL], [WARNING], or [SUGGESTION].

Rules:
- Keep the entire review under 600 words
- Use Korean
- Do NOT wrap output in markdown code fences]]

-- ── 메인 함수 ──────────────────────────────────────────────
function M.run()
  -- 1) Chrome에서 현재 URL 가져오기
  local app = hs.application.frontmostApplication()
  local appName = app and app:name() or ""
  local browsers = { ["Google Chrome"] = true, ["Arc"] = true, ["Safari"] = true }

  if not browsers[appName] then
    hs.alert.show("🔍 브라우저에서 PR/MR 페이지를 열어주세요")
    return
  end

  local ok, url = hs.osascript.applescript(string.format(
    'tell application "%s" to get URL of active tab of front window', appName
  ))
  if not ok or not url then
    hs.alert.show("❌ URL을 가져올 수 없습니다")
    return
  end

  -- 2) Provider 매칭
  print("[review] url: " .. url)
  local provider, captures = matchProvider(url)
  if not provider then
    hs.alert.show("❌ PR/MR URL이 아닙니다\n" .. url:sub(1, 60))
    return
  end

  local diffArgs = provider.diffArgs(table.unpack(captures))

  startSpinner(provider.name:upper() .. " diff 가져오는 중...")

  print("[review] cmd: " .. (provider.env or "") .. " " .. provider.bin .. " " .. table.concat(diffArgs, " "))

  runTask(provider.bin, diffArgs, function(exitCode, stdout, stderr)
    if exitCode ~= 0 or not stdout or stdout == "" then
      stopSpinner()
      local errMsg = (stderr or "no stderr")
      print("[review] FAIL exitCode=" .. tostring(exitCode))
      print("[review] stderr: " .. errMsg)
      hs.alert.show("❌ diff 가져오기 실패 (exit " .. tostring(exitCode) .. ")\n" .. errMsg:sub(1, 120))
      return
    end

    local diff = stdout
    -- diff가 너무 크면 잘라내기 (claude -p 입력 제한 고려)
    if #diff > 30000 then
      diff = diff:sub(1, 30000) .. "\n\n... (diff truncated at 30000 chars)"
    end

    updateSpinner("Claude가 리뷰 중... (diff " .. #stdout .. " chars)")

    -- 4) Claude로 리뷰
    llm.ask(REVIEW_PROMPT, diff, function(result, ok)
      stopSpinner()
      if ok then
        local prNum = captures[#captures] or "?"
        showReview(provider.name:upper() .. " MR #" .. prNum .. " Review", result)
      else
        hs.alert.show(result)
      end
    end)
  end, provider.env)
end

return M
