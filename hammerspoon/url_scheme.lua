-- ============================================================
-- URL Scheme: hammerspoon:// 커스텀 스킴 핸들러
-- hammerspoon://file?path=/abs/path&line=42 → Ghostty + nvim
-- ============================================================
local M = {}

local TMUX_BIN = "/opt/homebrew/bin/tmux"
local GHOSTTY_BUNDLE = "com.mitchellh.ghostty"

local function shellQuote(s)
  return "'" .. (s or ""):gsub("'", [['\'']]) .. "'"
end

-- ── file 액션 ─────────────────────────────────────────────
-- hammerspoon://file?path=/abs/path&line=42

local function handleFile(params)
  local path = params.path
  local line = params.line

  if not path or path == "" then
    print("[url_scheme] file: path 파라미터 없음")
    hs.alert.show("file: path 파라미터 없음")
    return
  end

  if not hs.fs.attributes(path) then
    print("[url_scheme] file: 파일 없음 — " .. path)
    hs.alert.show("파일 없음:\n" .. path)
    return
  end

  local ghostty = hs.application.get(GHOSTTY_BUNDLE)
  if not ghostty then
    print("[url_scheme] file: Ghostty 안 떠있음")
    hs.alert.show("Ghostty 안 떠있음")
    return
  end

  ghostty:activate()

  hs.timer.doAfter(0.15, function()
    local nvimCmd = "nvim"
    if line then
      nvimCmd = nvimCmd .. " +" .. line
    end
    nvimCmd = nvimCmd .. " " .. shellQuote(path)

    local cmd = string.format("%s new-window %s", TMUX_BIN, shellQuote(nvimCmd))

    print("[url_scheme] file: " .. cmd)

    hs.task.new("/bin/zsh", function(exitCode, _, stderr)
      if exitCode ~= 0 then
        print("[url_scheme] file: new-window 실패 — " .. (stderr or ""))
        hs.alert.show("tmux new-window 실패")
      end
    end, { "-c", cmd }):start()
  end)
end

-- ── 액션 라우터 ───────────────────────────────────────────

local ACTIONS = {
  file = handleFile,
}

function M.start()
  for name, handler in pairs(ACTIONS) do
    hs.urlevent.bind(name, function(_, params)
      print("[url_scheme] " .. name .. " 호출됨")
      handler(params)
    end)
  end
end

return M
