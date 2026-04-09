-- AI Palette :: 메인 모듈
-- Hyper+A → 텍스트 캡처 → hs.chooser로 액션 선택 → 실행

local M = {}
local clip = require("ai_palette.clip")
local llm = require("ai_palette.llm")
local review = require("ai_palette.review")

-- ── 액션 정의 ──────────────────────────────────────────────
-- 각 액션: { text, subText, id, fn(selectedText, source) }
local actions = {
  {
    text = "🌐  번역 (한↔영)",
    subText = "선택한 텍스트를 한/영 자동 감지 후 번역",
    id = "translate",
  },
  {
    text = "📝  Obsidian 클립",
    subText = "Inbox 데일리 노트에 출처와 함께 저장",
    id = "clip",
  },
  {
    text = "🔍  리서치",
    subText = "선택한 주제를 AI로 조사해서 정리",
    id = "research",
  },
  {
    text = "💬  요약",
    subText = "긴 텍스트를 핵심만 요약",
    id = "summarize",
  },
  {
    text = "🔬  코드리뷰",
    subText = "현재 브라우저의 PR/MR diff를 AI가 리뷰 (텍스트 선택 불필요)",
    id = "review",
  },
}

-- ── 액션 핸들러 ────────────────────────────────────────────
local handlers = {}

handlers.clip = function(text, src)
  clip.run(text, src)
end

handlers.translate = function(text, src)
  hs.alert.show("🌐 번역 중...")
  llm.ask(
    "You are a translator. If the input is Korean, translate to English. If English, translate to Korean. Output ONLY the translation, nothing else.",
    text,
    function(result, ok)
      if ok then
        hs.pasteboard.setContents(result)
        hs.alert.show("🌐 번역 완료 (클립보드에 복사)\n" .. result:sub(1, 80))
      else
        hs.alert.show(result)
      end
    end
  )
end

handlers.research = function(text, src)
  hs.alert.show("🔍 리서치 중... (시간이 좀 걸릴 수 있어요)")
  llm.ask(
    "You are a research assistant. Research the given topic and provide a concise, structured summary in Korean. Include key facts, context, and relevant details. Keep it under 500 words.",
    text,
    function(result, ok)
      if ok then
        hs.pasteboard.setContents(result)
        hs.alert.show("🔍 리서치 완료 (클립보드에 복사)")
      else
        hs.alert.show(result)
      end
    end
  )
end

handlers.summarize = function(text, src)
  hs.alert.show("💬 요약 중...")
  llm.ask(
    "Summarize the following text concisely in Korean. Focus on key points only. Output the summary directly, no preamble.",
    text,
    function(result, ok)
      if ok then
        hs.pasteboard.setContents(result)
        hs.alert.show("💬 요약 완료 (클립보드에 복사)\n" .. result:sub(1, 80))
      else
        hs.alert.show(result)
      end
    end
  )
end

handlers.review = function(text, src)
  review.run() -- 텍스트 선택 무시, 브라우저 URL에서 직접 동작
end

-- ── 소스 정보 캡처 ─────────────────────────────────────────
local function sourceInfo()
  local app = hs.application.frontmostApplication()
  local win = hs.window.focusedWindow()
  local info = {
    app = app and app:name() or "unknown",
    title = win and win:title() or "",
  }
  -- Chrome/Arc/Safari면 URL도 캡처
  local browsers = { ["Google Chrome"] = true, ["Arc"] = true, ["Safari"] = true }
  if browsers[info.app] then
    local ok, url = hs.osascript.applescript(string.format(
      'tell application "%s" to get URL of active tab of front window', info.app
    ))
    if ok then info.url = url end
  end
  return info
end

-- ── 텍스트 캡처 (비동기) ───────────────────────────────────
local function captureSelection(callback)
  local prev = hs.pasteboard.getContents()
  local prevCount = hs.pasteboard.changeCount()

  -- modifier 키 릴리즈 대기 후 Cmd+C
  hs.timer.doAfter(0.15, function()
    hs.eventtap.keyStroke({ "cmd" }, "c")

    hs.timer.doAfter(0.3, function()
      local selected = nil
      if hs.pasteboard.changeCount() ~= prevCount then
        selected = hs.pasteboard.getContents()
      end
      -- 원래 클립보드 복원
      if prev then hs.pasteboard.setContents(prev) end
      callback(selected)
    end)
  end)
end

-- ── 텍스트 선택 불필요 액션 ────────────────────────────────
local noTextActions = { review = true }

-- ── Chooser ────────────────────────────────────────────────
local chooser

local function showChooser(text, src)
  chooser = hs.chooser.new(function(choice)
    if not choice then return end
    if not noTextActions[choice.id] and (not text or text == "") then
      hs.alert.show("📋 이 액션은 텍스트 선택이 필요합니다")
      return
    end
    local handler = handlers[choice.id]
    if handler then handler(text, src) end
  end)

  chooser:choices(actions)
  chooser:placeholderText("액션 선택...")
  chooser:searchSubText(true)
  chooser:show()
end

-- ── 엔트리 포인트 ──────────────────────────────────────────
function M.activate()
  local src = sourceInfo()
  captureSelection(function(text)
    -- 텍스트 없어도 chooser는 띄우되, 텍스트 필요 액션은 내부에서 체크
    showChooser(text, src)
  end)
end

function M.bind(mods, key)
  hs.hotkey.bind(mods, key, M.activate)
end

return M
