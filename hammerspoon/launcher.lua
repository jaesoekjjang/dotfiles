-- ============================================================
-- Launcher: 모든 액션을 chooser로 선택·실행
-- Hyper+Space 로 호출
-- ============================================================
local M = {}

local chooser = nil
local actions  = nil -- 첫 show() 시 지연 초기화

local function buildActions()
  local review           = require("ai_palette.review")
  local summarize        = require("ai_palette.summarize")
  local netreport        = require("ai_palette.netreport")
  local briefing         = require("ai_palette.briefing")
  local briefingEvening  = require("ai_palette.briefing_evening")
  local workmuxMenubar   = require("workmux.menubar")
  local workmuxStartIssue = require("workmux.start_issue")

  return {
    { text = "Code Review",          subText = "PR/MR diff → Claude 리뷰",       fn = review.run },
    { text = "Page Summarize",       subText = "브라우저 페이지 요약 + 번역",      fn = summarize.run },
    { text = "Network Error Report", subText = "cURL → 네트워크 에러 리포트",      fn = netreport.run },
    { text = "Morning Briefing",     subText = "하루 시작 브리핑 수동 실행",        fn = briefing.run },
    { text = "Evening Briefing",     subText = "저녁 마무리 브리핑 수동 실행",      fn = briefingEvening.run },
    { text = "Workmux Refresh",      subText = "메뉴바 agent 현황 새로고침",        fn = workmuxMenubar.refresh },
    { text = "Workmux Start Issue",  subText = "Linear 이슈 → worktree 시작",      fn = workmuxStartIssue.run },
    { text = "Reload Config",        subText = "Hammerspoon 설정 리로드",           fn = hs.reload },
  }
end

function M.show()
  if not actions then actions = buildActions() end

  if not chooser then
    chooser = hs.chooser.new(function(choice)
      if choice then actions[choice.idx].fn() end
    end)
    chooser:placeholderText("액션 검색…")
    chooser:width(40)
  end

  local items = {}
  for i, a in ipairs(actions) do
    items[#items + 1] = { text = a.text, subText = a.subText, idx = i }
  end
  chooser:choices(items)
  chooser:show()
end

return M
