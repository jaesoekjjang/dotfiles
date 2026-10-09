local opt = vim.opt_local

opt.makeprg = "npx eslint . --format unix"

-- local function to_camel_case(str)
-- 	local res = str:gsub("[-_](%a)", function(c)
-- 		return c:upper()
-- 	end):gsub("^%l", string.upper)
--
-- 	return "export const " .. res .. " = () => {\n  return ()\n}"
-- end
--
-- vim.api.nvim_create_autocmd("User", {
-- 	pattern = "OilActionsPost",
-- 	callback = function(args)
-- 		local data = args.data
-- 		if data and data.actions then
-- 			for _, action in ipairs(data.actions) do
-- 				if action.type == "create" then
-- 					local file_path = action.url:gsub("^oil://", "")
--
-- 					-- 디스크 상의 파일 열고 문자열 작성
-- 					local fd = io.open(file_path, "a") -- "a" 모드는 파일 끝에 추가
-- 					if fd then
-- 						local basename = vim.fn.fnamemodify(file_path, ":t:r")
-- 						fd:write(to_camel_case(basename))
-- 						fd:close()
-- 						return
-- 					else
-- 						print("Failed to open file:", file_path)
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end,
-- })
