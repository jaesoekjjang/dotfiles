hs.allowAppleScript(true)

-- Code Review (브라우저 PR/MR 페이지에서 직접 실행)
local review = require("ai_palette.review")
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "r", review.run) -- Hyper+R

-- Page Summarize + Translate (브라우저 페이지 요약+번역)
local summarize = require("ai_palette.summarize")
hs.hotkey.bind({ "cmd", "ctrl", "shift" }, "s", summarize.run) -- Hyper+S

-- cursor follows focus
wf = hs.window.filter.default
wf:subscribe(hs.window.filter.windowFocused, function(win)
  if win then
    local f = win:frame()
    hs.mouse.absolutePosition({
      x = f.x + f.w / 2,
      y = f.y + f.h / 2
    })
  end
end)
