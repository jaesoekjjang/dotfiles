hs.allowAppleScript(true)

-- Code Review (브라우저 PR/MR 페이지에서 직접 실행)
local review = require("ai_palette.review")
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "r", review.run) -- Hyper+R

-- Page Summarize + Translate (브라우저 페이지 요약+번역)
local summarize = require("ai_palette.summarize")
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "s", summarize.run) -- Hyper+S

-- Network Error Report (DevTools Copy as cURL → 마크다운 리포트)
local netreport = require("ai_palette.netreport")
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "n", netreport.run) -- Hyper+N

-- Morning Briefing (wake 시 자동 + 수동)
local briefing = require("ai_palette.briefing")
briefing.setupWatcher()
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "b", briefing.run) -- Hyper+B

-- Evening Briefing (평일 18시 자동 + 수동, 자동은 step 9에서 wiring)
local briefingEvening = require("ai_palette.briefing_evening")
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "e", briefingEvening.run) -- Hyper+E

-- cursor follows focus (지연 초기화로 zombie process 크래시 방지)
-- hs.timer.doAfter(2, function()
--   local ok, wf = pcall(function() return hs.window.filter.default end)
--   if not ok then
--     print("[init] window.filter 초기화 실패: " .. tostring(wf))
--     return
--   end
--   wf:subscribe(hs.window.filter.windowFocused, function(win)
--     if win then
--       local f = win:frame()
--       hs.mouse.absolutePosition({
--         x = f.x + f.w / 2,
--         y = f.y + f.h / 2
--       })
--     end
--   end)
-- end)
