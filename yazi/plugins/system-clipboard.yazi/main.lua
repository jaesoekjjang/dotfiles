local files = ya.sync(function()
  local paths = {}
  for _, url in pairs(cx.active.selected) do
    paths[#paths + 1] = tostring(url)
  end
  if #paths == 0 and cx.active.current.hovered then
    paths[1] = tostring(cx.active.current.hovered.url)
  end
  table.sort(paths)
  return paths, tostring(cx.active.current.cwd)
end)

return {
  entry = function(_, job)
    local mode = job.args[1] or "files"
    local paths, cwd = files()
    if #paths == 0 then
      return ya.notify { title = "Clipboard", content = "No file selected", level = "warn", timeout = 3 }
    end
    local config = os.getenv("YAZI_CONFIG_HOME")
      or ((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/yazi")
    local output, err = Command("python3")
      :arg(config .. "/scripts/clipboard.py")
      :arg(mode)
      :arg(cwd)
      :arg(paths)
      :stdout(Command.PIPED)
      :stderr(Command.PIPED)
      :output()
    if not output or not output.status.success then
      return ya.notify {
        title = "Copy failed",
        content = output and output.stderr or tostring(err),
        level = "error",
        timeout = 6,
      }
    end
    ya.notify { title = "Copied", content = output.stdout, level = "info", timeout = 3 }
  end,
}
