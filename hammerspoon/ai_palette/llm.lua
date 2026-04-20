-- AI Palette :: LLM 호출 (claude -p 경유)
-- 프롬프트를 임시 파일에 쓰고 stdin으로 파이프해서 특수문자 문제 회피

local M = {}

local TMP_DIR = "/tmp/hammerspoon_ai_palette"

local function ensureTmpDir()
  hs.execute("mkdir -p " .. TMP_DIR)
end

--- prompt: 시스템 프롬프트 (string)
--- input:  사용자 입력 텍스트 (string)
--- callback(result, ok): 결과 문자열 + 성공 여부
function M.ask(prompt, input, callback)
  ensureTmpDir()

  local fullPrompt = prompt .. "\n\n---\n\n" .. input
  local tmpFile = TMP_DIR .. "/prompt_" .. tostring(os.time()) .. ".txt"

  -- 프롬프트를 파일로 쓰기
  local f = io.open(tmpFile, "w")
  if not f then
    callback("❌ 임시 파일 생성 실패", false)
    return
  end
  f:write(fullPrompt)
  f:close()

  -- claude -p < tmpFile, 끝나면 파일 삭제
  local cmd = string.format('claude -p --model sonnet < %q; rm -f %q', tmpFile, tmpFile)

  local task = hs.task.new("/bin/zsh", function(exitCode, stdout, stderr)
    if exitCode == 0 and stdout and stdout ~= "" then
      callback(stdout:gsub("^%s+", ""):gsub("%s+$", ""), true)
    else
      local err = stderr or "unknown error"
      print("[llm] FAIL exit=" .. tostring(exitCode) .. " stderr: " .. err:sub(1, 200))
      callback("❌ Claude 호출 실패: " .. err:sub(1, 100), false)
    end
  end, { "-lc", cmd })
  task:setWorkingDirectory(TMP_DIR)
  task:start()
end

return M
