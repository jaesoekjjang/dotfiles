-- W1 Lite: Linear 이슈 → workmux worktree 시작
-- Hyper+L → 이슈 chooser → repo chooser → workmux add

local linear = require("workmux.linear")

local M = {}

-- ══════════════════════════════════════════════════════════
-- 설정
-- ══════════════════════════════════════════════════════════

local REPO_SCAN_PATHS = {
  os.getenv("HOME") .. "/work",
  os.getenv("HOME") .. "/Programming/projects",
}

-- ══════════════════════════════════════════════════════════
-- 유틸
-- ══════════════════════════════════════════════════════════

local function shellQuote(s)
  return "'" .. (s or ""):gsub("'", [['\'']]) .. "'"
end

local function notify(title, text)
  hs.notify.new({
    title = title,
    informativeText = (text or ""):sub(1, 200),
    soundName = hs.notify.defaultNotificationSound,
  }):send()
end

local function priorityIcon(p)
  if p == 1 then return "🔴"
  elseif p == 2 then return "🟠"
  elseif p == 3 then return "🟡"
  elseif p == 4 then return "⚪"
  else return " "
  end
end

-- ══════════════════════════════════════════════════════════
-- Repo 디스커버리
-- ══════════════════════════════════════════════════════════

-- callback(projects)
local function findProjects(callback)
  local quotedPaths = {}
  for _, p in ipairs(REPO_SCAN_PATHS) do
    quotedPaths[#quotedPaths + 1] = shellQuote(p)
  end

  -- grep 대신 find의 -not -path 사용해서 __worktrees 제외
  -- (파이프라인 exit code 얽힘 회피)
  local cmd = string.format([[
    for dir in %s; do
      [ -d "$dir" ] && find "$dir" -maxdepth 3 -name '.workmux.yaml' -type f \
        -not -path '*__worktrees*' 2>/dev/null
    done
  ]], table.concat(quotedPaths, " "))

  print("[start_issue] findProjects cmd:\n" .. cmd)

  hs.task.new("/bin/zsh", function(exitCode, stdout, stderr)
    print("[start_issue] task exit:", exitCode, "stdout 길이:", stdout and #stdout or 0)
    if stderr and stderr ~= "" then
      print("[start_issue] task stderr:\n" .. stderr)
    end
    print("[start_issue] task stdout:\n" .. tostring(stdout))

    local projects = {}
    for line in (stdout or ""):gmatch("[^\n]+") do
      local dir = line:gsub("/%.workmux%.yaml$", "")
      if dir ~= "" then
        projects[#projects + 1] = {
          path = dir,
          name = dir:match("([^/]+)/?$") or dir,
        }
      end
    end

    table.sort(projects, function(a, b) return a.name < b.name end)
    callback(projects)
  end, { "-c", cmd }):start()
end

-- ══════════════════════════════════════════════════════════
-- Chooser 아이템 빌더
-- ══════════════════════════════════════════════════════════

local function issueToChooserItem(issue)
  return {
    text = issue.identifier .. "  " .. (issue.title or ""),
    subText = string.format(
      "%s %s · %s · %s",
      priorityIcon(issue.priority),
      (issue.state and issue.state.name) or "?",
      (issue.team and issue.team.key) or "?",
      (issue.project and issue.project.name) or "(no project)"
    ),
    issue = issue,
  }
end

local function repoToChooserItem(repo)
  return {
    text = repo.name,
    subText = repo.path,
    path = repo.path,
  }
end

-- ══════════════════════════════════════════════════════════
-- 실행
-- ══════════════════════════════════════════════════════════

local function startWorktree(issue, repo)
  local branch = issue.branchName
  if not branch or branch == "" then
    branch = issue.identifier:lower()
  end

  notify("workmux: " .. issue.identifier, "워크트리 생성 중…")

  local cmd = string.format(
    "cd %s && workmux add %s 2>&1",
    shellQuote(repo.path),
    shellQuote(branch)
  )

  hs.task.new("/bin/zsh", function(exitCode, stdout, stderr)
    if exitCode == 0 then
      notify(
        "workmux: " .. issue.identifier .. " 시작",
        repo.name .. " · " .. branch
      )
    else
      local errText = stderr or stdout or "unknown error"
      -- 이미 worktree 있는 경우 힌트 포함
      if errText:lower():find("already exists") then
        errText = "이미 존재함. `workmux open " .. branch .. "` 시도해보세요"
      end
      notify("workmux add 실패", errText)
    end
  end, { "-lc", cmd }):start()
end

-- ══════════════════════════════════════════════════════════
-- Chooser 체인
-- ══════════════════════════════════════════════════════════

local function chooseRepo(issue)
  print("[start_issue] chooseRepo 진입, issue:", issue and issue.identifier or "nil")

  findProjects(function(projects)
    print("[start_issue] findProjects 결과:", #projects, "개")

    if #projects == 0 then
      hs.alert.show("workmux 프로젝트 없음", 3)
      notify(
        "workmux 프로젝트 없음",
        REPO_SCAN_PATHS[1] .. " 또는 " .. REPO_SCAN_PATHS[2] .. " 하위에 .workmux.yaml이 필요해요"
      )
      return
    end

    local items = {}
    for _, repo in ipairs(projects) do
      items[#items + 1] = repoToChooserItem(repo)
    end

    local chooser = hs.chooser.new(function(choice)
      print("[start_issue] repo chooser 콜백, choice:", choice and choice.text or "nil(cancelled)")
      if not choice then return end
      startWorktree(issue, { name = choice.text, path = choice.path })
    end)

    chooser:choices(items)
    chooser:placeholderText(issue.identifier .. " → 어느 repo?")
    chooser:searchSubText(true)
    chooser:show()
  end)
end

local function chooseIssue(issues)
  if #issues == 0 then
    notify("Linear 이슈 없음", "할당된 unstarted/started 이슈가 없어요")
    return
  end

  local items = {}
  for _, issue in ipairs(issues) do
    items[#items + 1] = issueToChooserItem(issue)
  end

  local chooser = hs.chooser.new(function(choice)
    print("[start_issue] issue chooser 콜백, choice:", choice and choice.text or "nil(cancelled)")
    if not choice then return end
    -- 첫 chooser 닫힘 애니메이션 끝난 뒤 다음 chooser 띄우기 (타이밍 이슈 회피)
    hs.timer.doAfter(0.05, function()
      chooseRepo(choice.issue)
    end)
  end)

  chooser:choices(items)
  chooser:placeholderText("Linear 이슈 선택 (" .. #issues .. "개)")
  chooser:searchSubText(true)
  chooser:rows(math.min(12, #issues))
  chooser:show()
end

-- ══════════════════════════════════════════════════════════
-- 엔트리포인트
-- ══════════════════════════════════════════════════════════

function M.run()
  print("[start_issue] run() 호출됨")
  hs.alert.show("Linear 이슈 로딩…", 0.8)
  linear.getMyActiveIssues(function(issues, err)
    print("[start_issue] getMyActiveIssues 콜백: err =", err, "issues =", issues and #issues or "nil")
    if err then
      hs.alert.show("Linear API 실패: " .. err, 3)
      notify("Linear API 실패", err)
      return
    end
    chooseIssue(issues)
  end)
end

return M
