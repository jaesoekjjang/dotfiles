# Workspace workflow

셸 `w`, tmux `prefix+p`, Neovim `Space aw`에서 같은 메뉴를 연다. Prefix는 `Ctrl-b` 또는 `Ctrl-k`.

| 명령 | 동작 |
|---|---|
| `w project` | 프로젝트 선택 → 해당 tmux 세션 열기/전환 |
| `w project /path/to/repo` | 경로로 프로젝트 열기 |
| `w new` | branch 이름 입력 → Neovim에서 작업 지시 작성 → worktree 생성 |
| `w new feat/search -p '검색 추가'` | 이름·지시를 지정해 새 작업 생성 |
| `w open` | 기존 worktree 선택 → window 열기/전환 |
| `w resume` | 현재 저장소의 Codex 대화 선택·재개 |
| `w resume --last` | 현재 저장소의 마지막 대화 재개 |
| `w review` | 현재 worktree의 미커밋 변경을 CodeDiff로 검토 |
| `w status` | 전체 agent dashboard |
| `w sidebar` | agent sidebar 토글 |
| `w recover --dry-run` | 복구 가능한 agent 작업 확인 |
| `w recover` | workmux가 기록한 작업 window·agent 복구 |

프로젝트는 tmux session, 작업은 그 안의 workmux window로 구분한다.
프로젝트 목록은 `~/projects` 아래 `.git` 디렉터리와 Dotfiles에서 수집한다. zoxide 기록은 탐색하지 않는다.
캐시를 즉시 표시하고, 마지막 갱신에서 30초가 지났으면 뒤에서 갱신한다. 갱신 중에도 기존 목록을 검색·선택할 수 있다.
`Ctrl-r`는 시간에 관계없이 강제 갱신한다. 첫 실행은 빈 목록으로 열리고 탐색 결과가 채워진다.
캐시는 `${XDG_CACHE_HOME:-~/.cache}/dotfiles-workspace/projects.tsv`에 경로·표시명·브랜치로 저장하며, 동시 갱신은 lock으로 조정하고 실패하면 기존 목록을 보존한다.
탐색 위치는 `WORKSPACE_PROJECTS_DIR`로 바꿀 수 있다. 발견한 저장소마다 `git worktree list`로 연결된 worktree도 수집한다.
프로젝트 목록에서 worktree 이름과 브랜치도 검색한다. tmux의 `w project`는 선택한 worktree의 본 프로젝트 세션을 열고, 해당 작업은 `w open`에서 선택한다.
TUIOS의 프로젝트 선택기는 선택한 worktree 경로에 직접 세션을 연다. 이름이 같은 다른 프로젝트는 경로 hash로 구분한다.
프로젝트 기본 window는 Neovim + shell. 새 작업은 agent(왼쪽) + Neovim(오른쪽 위) + shell(오른쪽 아래).
기존 worktree window를 새로 열 때는 `workmux open --continue`로 대화를 재개한다. 이미 열린 agent는 재시작하지 않는다.
`w resume`는 별도 agent window를 재사용하며, workmux 작업 pane의 agent가 살아 있다면 그 pane으로 직접 이동한다.

검토 흐름은 `w status` → 해당 작업으로 이동 → `w review` → Neovim의 Git 단축키로 commit.
`Space gv`는 커밋 하나, `Space gd`는 미커밋 변경을 검토한다.
완료 후 통합·제거는 `workmux merge <handle>` 또는 `workmux remove <handle>`을 명시적으로 실행한다.
`workmux close <handle>`은 window만 닫고 worktree·branch는 남긴다. Dashboard에는 commit/merge 동작도 있으므로 통합 의도가 있을 때만 사용한다.

전역 설정은 의존성 설치, 개발 서버 실행, `.env` 복사, `node_modules` 공유를 하지 않는다.
필요한 프로젝트에서 `.workmux.yaml`을 작성한다. 예:

```yaml
post_create:
  - pnpm install --frozen-lockfile
files:
  copy:
    - .env.local
```

`post_create`는 pane 실행 전에 완료된다. 프로젝트 설정의 `panes`는 전역 layout을 대체한다.
새 작업은 현재 branch에서 시작한다. 기준을 지정하려면 `w new feat/search --base origin/main -p '검색 추가'`.
Branch 이름은 전체 경로를 slug로 변환하므로 `feat/search`와 `fix/search`를 구분한다.
Codex 모델·reasoning은 로컬 Codex 설정을 따른다. 기존 무확인 실행 옵션은 유지한다.

제거한 진입점: `tp`, `to`, `tm`/`ta`/`tn`/`tl`/`tk`/`tks`/`ts`/`tw`, `wm`, `lw`.
Claude 전용 `cl` alias와 Neovim `claudecode.nvim`·단축키도 제거했다. Claude CLI·설정·agents는 유지하며 직접 `claude`로 실행할 수 있다.
기존 tmux dashboard `prefix+d`, sidebar `prefix+b`, layout 생성 `m`/`M`/`W`/`Ctrl-l`도 제거했다.
Tmux 기본 이동·분할과 Git/Yazi/shell popup은 유지한다.
`w resume`의 picker는 현재 저장소 경로 기준이다. 다른 저장소의 대화가 필요하면 `w resume --all`.
대화 기록이 없다면 shell pane에서 `codex`로 새 대화를 시작한다.
복구는 저장된 layout·대화를 다시 여는 기능이며, 재부팅 전 프로세스를 그대로 되살리는 기능은 아니다.

`w project`의 검색 대상은 프로젝트/worktree 이름과 브랜치다. `ai-chat attachment`처럼
공백으로 조건을 추가할 수 있다. `^anchorbase`는 이름 앞부분을 고정하고,
`^anchorbase !docs`는 해당 프로젝트에서 docs가 들어간 이름·브랜치를 제외한다.
