-- ============================================================
-- Launcher: 모든 액션을 chooser로 선택·실행
-- Hyper+Space 로 호출
-- 항목은 url_scheme.LAUNCHER_ITEMS에서 가져옴 (단일 레지스트리)
-- ============================================================
local M = {}

local chooser = nil

function M.show()
  local items = require("url_scheme").LAUNCHER_ITEMS

  if not chooser then
    chooser = hs.chooser.new(function(choice)
      if choice then items[choice.idx].fn() end
    end)
    chooser:placeholderText("액션 검색…")
    chooser:width(40)
  end

  local choices = {}
  for i, a in ipairs(items) do
    choices[#choices + 1] = { text = a.text, subText = a.subText, idx = i }
  end
  chooser:choices(choices)
  chooser:show()
end

return M
