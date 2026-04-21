-- ============================================================
-- URL Dispatcher: 특정 링크를 네이티브 앱으로 강제 라우팅
-- 전제: macOS 기본 웹 브라우저가 Hammerspoon으로 설정되어 있어야 함
-- ============================================================
local M = {}

local PATTERNS = {
    { "https?://[^/]*figma%.com/",      "com.figma.Desktop"  },
    { "https?://linear%.app/",          "com.linear"         },
    { "https?://[^/]*notion%.so/",      "notion.id"          },
    { "https?://open%.spotify%.com/",   "com.spotify.client" },
}

local DEFAULT = "com.google.Chrome"

function M.start()
    hs.urlevent.httpCallback = function(_, _, _, url)
        for _, rule in ipairs(PATTERNS) do
            if url:match(rule[1]) then
                hs.urlevent.openURLWithBundle(url, rule[2])
                return
            end
        end
        hs.urlevent.openURLWithBundle(url, DEFAULT)
    end
end

return M
