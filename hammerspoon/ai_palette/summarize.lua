-- AI Palette :: Page Summarize + Translate
-- 브라우저 페이지를 요약+번역해서 webview로 표시
-- 텍스트 선택 있으면 선택 부분만, 없으면 페이지 전체

local M = {}
local llm = require("ai_palette.llm")

-- ── 스피너 ─────────────────────────────────────────────────
local spinnerCanvas = nil
local spinnerTimer = nil
local spinnerFrame = 1
local spinnerPhase = ""
local escTap = nil
local cancelled = false

local function stopEscListener()
  if escTap then escTap:stop(); escTap = nil end
end

local function stopSpinner()
  stopEscListener()
  if spinnerTimer then spinnerTimer:stop(); spinnerTimer = nil end
  if spinnerCanvas then spinnerCanvas:delete(); spinnerCanvas = nil end
end

local function startSpinner(phase)
  cancelled = false
  spinnerPhase = phase or "처리 중"
  spinnerFrame = 1
  local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

  if spinnerCanvas then spinnerCanvas:delete() end

  local screen = hs.screen.mainScreen():frame()
  spinnerCanvas = hs.canvas.new({ x = screen.x + screen.w / 2 - 160, y = screen.y + 40, w = 320, h = 56 })
  spinnerCanvas:insertElement({
    type = "rectangle", action = "fill",
    roundedRectRadii = { xRadius = 10, yRadius = 10 },
    fillColor = { red = 0.05, green = 0.07, blue = 0.1, alpha = 0.92 },
  })
  spinnerCanvas:insertElement({
    type = "text", text = "",
    textFont = ".AppleSystemUIFont", textSize = 15,
    textColor = { red = 0.9, green = 0.93, blue = 0.96, alpha = 1 },
    textAlignment = "center",
    frame = { x = "0", y = "0.12", w = "1", h = "0.55" },
  })
  spinnerCanvas:insertElement({
    type = "text", text = "ESC로 취소",
    textFont = ".AppleSystemUIFont", textSize = 10,
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

  escTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
    if e:getKeyCode() == 53 then
      cancelled = true
      stopSpinner()
      hs.alert.show("⛔ 취소됨")
      return true
    end
    return false
  end)
  escTap:start()
end

local function updateSpinner(phase)
  spinnerPhase = phase or spinnerPhase
end

-- ── Webview ────────────────────────────────────────────────
local summaryWebview = nil

local function showResult(title, url, content)
  if summaryWebview then
    summaryWebview:delete()
    summaryWebview = nil
  end

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
    padding: 24px; line-height: 1.7;
  }
  .header {
    border-bottom: 1px solid #e0d9cd; padding-bottom: 16px; margin-bottom: 20px;
  }
  .header h1 { font-size: 16px; color: #8b5c2a; margin-bottom: 4px; }
  .header .meta { font-size: 11px; color: #9a9080; }
  .header .meta a { color: #8b5c2a; text-decoration: none; }
  .header .meta a:hover { text-decoration: underline; }
  .content { font-size: 14px; }
  .content h2 {
    color: #8b5c2a; font-size: 15px; margin: 24px 0 10px;
    padding-bottom: 6px; border-bottom: 1px solid #e0d9cd;
  }
  .content h2:first-child { margin-top: 0; }
  .content p { margin: 8px 0; line-height: 1.8; }
  .content ul, .content ol { margin: 8px 0 8px 20px; }
  .content li { margin-bottom: 6px; line-height: 1.7; }
  .content pre {
    background: #2b2520; color: #e8dfd4; padding: 12px;
    border-radius: 6px; overflow-x: auto; margin: 10px 0;
    font-size: 12px; line-height: 1.5;
  }
  .content code {
    font-family: "SF Mono", Menlo, monospace; font-size: 12px;
  }
  .content p code {
    background: #ece5d8; padding: 2px 6px; border-radius: 4px; color: #5a4a3a;
  }
  .content blockquote {
    border-left: 3px solid #d4c4a8; padding-left: 12px;
    margin: 8px 0; color: #6b5d4f;
  }
  .close-btn {
    position: fixed; top: 12px; right: 16px;
    background: #e0d9cd; border: none; color: #9a9080;
    width: 28px; height: 28px; border-radius: 6px;
    cursor: pointer; font-size: 16px;
  }
  .close-btn:hover { background: #d4cbbe; color: #3b3730; }
</style>
</head>
<body>
  <button class="close-btn" onclick="window.webkit.messageHandlers.close.postMessage('close')">✕</button>
  <div class="header">
    <h1>]] .. (title or "Summary"):gsub('"', '&quot;') .. [[</h1>
    <div class="meta">]] .. (url and ('<a href="' .. url .. '">' .. url:sub(1, 70) .. '</a>') or "") .. [[ · ]] .. os.date("%Y-%m-%d %H:%M") .. [[</div>
  </div>
  <div class="content">]] .. content .. [[</div>
</body>
</html>
]]

  local screen = hs.screen.mainScreen():frame()
  local w, h = 650, math.min(screen.h - 100, 850)
  local rect = hs.geometry.rect(screen.x + screen.w - w - 20, screen.y + 60, w, h)

  local uc = hs.webview.usercontent.new("close")
  uc:setCallback(function()
    if summaryWebview then
      summaryWebview:delete()
      summaryWebview = nil
    end
  end)

  summaryWebview = hs.webview.new(rect, { privateMode = false }, uc)
    :windowTitle("Summary + Translate")
    :windowStyle({ "titled", "closable", "resizable", "miniaturizable" })
    :html(html)
    :allowTextEntry(false)
    :level(hs.drawing.windowLevels.floating)
    :windowCallback(function(action)
      if action == "closing" then summaryWebview = nil end
    end)
    :show()
    :bringToFront(true)
end

-- ── 프롬프트 ───────────────────────────────────────────────
local SUMMARIZE_PROMPT = [[You are a bilingual assistant (Korean/English).
Given the following text from a web page:

1. First, write a concise summary in Korean (3-5 bullet points, focus on key takeaways).
2. Then, if the original text is in English, provide a natural Korean translation of the full content. If already Korean, provide an English translation instead.

Output MUST be valid HTML fragments (no <html>, <body>, or <head> tags). Use these exact tags:

<h2>요약</h2>
<ul>
  <li>key point 1</li>
  <li>key point 2</li>
</ul>

<h2>번역</h2>
<p>translated paragraph</p>
<p>next paragraph</p>

Rules:
- Keep the summary sharp and actionable
- The translation should be natural, not literal
- Use <p> tags for paragraphs, <ul><li> for lists, <code> for inline code, <pre><code> for code blocks
- Output raw HTML only — no markdown, no code fences]]

-- ── 텍스트 가져오기 ────────────────────────────────────────
local function getPageText(appName, callback)
  -- 먼저 선택 텍스트 시도
  local prevCount = hs.pasteboard.changeCount()
  local prev = hs.pasteboard.getContents()

  hs.timer.doAfter(0.15, function()
    hs.eventtap.keyStroke({ "cmd" }, "c")
    hs.timer.doAfter(0.3, function()
      local selected = nil
      if hs.pasteboard.changeCount() ~= prevCount then
        selected = hs.pasteboard.getContents()
      end
      if prev then hs.pasteboard.setContents(prev) end

      if selected and selected ~= "" and #selected > 20 then
        callback(selected, "selection")
        return
      end

      -- 선택 없으면 페이지 전체 텍스트 (앱별 AppleScript 분기)
      local scripts = {
        ["Google Chrome"] = 'tell application "Google Chrome" to execute active tab of front window javascript "document.body.innerText"',
        ["Arc"] = 'tell application "Arc" to execute active tab of front window javascript "document.body.innerText"',
        ["Safari"] = 'tell application "Safari" to do JavaScript "document.body.innerText" in front document',
      }
      local script = scripts[appName]
      if not script then
        callback(nil, nil)
        return
      end

      print("[summarize] running JS via: " .. appName)
      local ok, pageText = hs.osascript.applescript(script)
      print("[summarize] JS result ok=" .. tostring(ok) .. " len=" .. tostring(pageText and #pageText or 0))

      if ok and pageText and pageText ~= "" then
        if #pageText > 15000 then
          pageText = pageText:sub(1, 15000) .. "\n\n... (truncated)"
        end
        callback(pageText, "fullpage")
      else
        -- JS 실패 시 Cmd+A → Cmd+C 폴백
        print("[summarize] JS failed, falling back to select all + copy")
        hs.eventtap.keyStroke({ "cmd" }, "a")
        hs.timer.doAfter(0.2, function()
          local prevCount2 = hs.pasteboard.changeCount()
          hs.eventtap.keyStroke({ "cmd" }, "c")
          hs.timer.doAfter(0.3, function()
            local allText = nil
            if hs.pasteboard.changeCount() ~= prevCount2 then
              allText = hs.pasteboard.getContents()
            end
            if prev then hs.pasteboard.setContents(prev) end
            if allText and #allText > 15000 then
              allText = allText:sub(1, 15000) .. "\n\n... (truncated)"
            end
            if allText and allText ~= "" then
              callback(allText, "fullpage")
            else
              callback(nil, nil)
            end
          end)
        end)
      end
    end)
  end)
end

-- ── 메인 함수 ──────────────────────────────────────────────
function M.run()
  local app = hs.application.frontmostApplication()
  local appName = app and app:name() or ""
  local browsers = { ["Google Chrome"] = true, ["Arc"] = true, ["Safari"] = true }

  if not browsers[appName] then
    hs.alert.show("🔍 브라우저에서 실행해주세요")
    return
  end

  -- 페이지 제목 + URL
  local ok, pageTitle = hs.osascript.applescript(string.format(
    'tell application "%s" to get title of active tab of front window', appName
  ))
  local ok2, pageUrl = hs.osascript.applescript(string.format(
    'tell application "%s" to get URL of active tab of front window', appName
  ))
  pageTitle = ok and pageTitle or "Untitled"
  pageUrl = ok2 and pageUrl or nil

  startSpinner("텍스트 가져오는 중...")

  getPageText(appName, function(text, source)
    if cancelled then return end

    if not text then
      stopSpinner()
      hs.alert.show("❌ 페이지 텍스트를 가져올 수 없습니다")
      return
    end

    local label = source == "selection" and "선택 영역" or "전체 페이지"
    updateSpinner("Claude가 " .. label .. " 처리 중... (" .. #text .. " chars)")

    llm.ask(SUMMARIZE_PROMPT, text, function(result, ok)
      if cancelled then return end
      stopSpinner()
      if ok then
        showResult(pageTitle, pageUrl, result)
      else
        hs.alert.show(result)
      end
    end)
  end)
end

return M
