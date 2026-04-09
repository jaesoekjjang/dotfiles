-- AI Palette :: Clip to Obsidian Inbox
-- 팔레트에서 텍스트와 소스를 받아 Inbox 데일리 노트에 append

local M = {}

local VAULT = os.getenv("HOME")
  .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault"
local INBOX_DIR = VAULT .. "/Inbox"

local function ensureInbox()
  hs.execute(string.format("mkdir -p %q", INBOX_DIR))
end

function M.run(text, src)
  ensureInbox()
  local date = os.date("%Y-%m-%d")
  local time = os.date("%H:%M:%S")
  local path = INBOX_DIR .. "/" .. date .. ".md"

  local f = io.open(path, "r")
  local isNew = (f == nil)
  if f then f:close() end

  local out = io.open(path, "a")
  if not out then
    hs.alert.show("❌ Inbox 파일 열기 실패")
    return
  end

  if isNew then
    out:write("---\n")
    out:write("tags: [inbox, clip]\n")
    out:write("date: " .. date .. "\n")
    out:write("---\n\n")
    out:write("# Clips " .. date .. "\n\n")
  end

  out:write(string.format("## %s — %s\n", time, src.app or "unknown"))
  if src.title and src.title ~= "" then
    out:write("> " .. src.title:gsub("\n", " ") .. "\n\n")
  end
  if src.url then
    out:write(string.format("[source](%s)\n\n", src.url))
  end
  out:write(text)
  if not text:match("\n$") then out:write("\n") end
  out:write("\n---\n\n")
  out:close()

  local preview = text:sub(1, 40):gsub("\n", " ")
  hs.alert.show("✅ Clipped → Inbox\n" .. preview)
end

return M
