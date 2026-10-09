# TUIOS trial

현재 TUIOS 0.9.1을 사용한다. 기존 `w`는 tmux/workmux용이며 변경하지 않았다.

Ghostty의 tmux 밖 새 창에서 `wt`를 실행한다. 현재 Git 프로젝트의 Codex + Neovim + shell 세션을 열고,
같은 경로에서 다시 실행하면 기존 세션에 붙는다. `wt /path/to/repo`로 경로를 지정할 수 있다.
새 세션은 workspace 1 `dev`에 agent 왼쪽 / editor 오른쪽 2분할로 배치하고 agent에 포커스를 둔다.
workspace 2 `terminal`에는 shell 하나를 전체 화면으로 연다. `Ctrl-b 1/2`로 이동한다.
배치는 `after-attach` hook이 실제 화면 연결 후 한 번만 적용한다. 미리 생성한 세션으로
`Ctrl-b s`에서 이동할 때도 적용되며, 이후 기존 세션을 재사용할 때는 배치와 포커스를 바꾸지 않는다.
Git 저장소 밖에서는 기존 프로젝트 캐시를 사용하는 picker가 열린다.
현재 shell에 alias가 없다면 `tuios-trial`을 직접 실행한다.
TUIOS 안의 Neovim은 `TERM=tmux-256color`로 실행한다. 이 terminfo는 배경색 지우기(BCE)를 광고하지 않아
Neovim이 빈 셀까지 직접 칠하며 TUIOS 0.8.5의 글자 뒤 배경색 얼룩을 피한다. Truecolor와 Kanagawa 테마는 유지한다.
메뉴의 editor/review, 새 TUIOS shell의 `nvim`, Yazi와 `open_editor`의 Neovim 실행에 적용한다.
이미 열린 Neovim은 다시 실행해야 한다.
새 pane과 popup은 `tuios-trial app`을 거쳐 데몬에서 상속된 `NO_COLOR`를 제거한다.
TUIOS의 대화형 zsh에서도 이 값을 제거한다. 기존 Codex 프로세스에는 소급 적용되지 않으므로
종료 후 `tuios-trial app codex resume`로 대화를 선택해 다시 연다. 데몬 재시작은 필요 없다.

| 키 | 동작 |
|---|---|
| `Ctrl-b p` | 프로젝트 선택 / 새 Codex / Neovim / CodeDiff pane 메뉴 |
| `Ctrl-b h/j/k/l` 또는 방향키 | pane 이동 |
| `Ctrl-b z` | 현재 pane 확대 |
| `Ctrl-b Ctrl-x` | 현재 session 종료 확인창 → 다른 session으로 이동 후 종료 (마지막 session이면 TUIOS 종료) |
| `Ctrl-b &` | 현재 workspace 종료 확인창 → 모든 pane·이름 제거 후 이웃 workspace로 이동 |
| `Ctrl-b s` | fzf로 session 검색·선택 (Ctrl-a: 새 session) |
| `Ctrl-b w` | fzf로 workspace 검색·선택 (Ctrl-a: 새 workspace) |
| `Ctrl-b c` | 빈 workspace에 현재 pane 경로의 shell을 열고 이동 |
| `Ctrl-b t n` | 현재 workspace에 새 pane |
| `Ctrl-b W` | workspace 관리 메뉴 (이동·이름 변경) |
| `Ctrl-b 1` … `9` | 해당 workspace로 이동 |
| `Ctrl-b $` | 현재 session 이름 변경 (Enter: 저장, Esc: 취소) |
| `Ctrl-b S` | scrollback browser |
| `Ctrl-b ?` | 도움말 |
| `Ctrl-b .` | keybinding manager (실제 키·충돌 확인 및 편집) |
| `Ctrl-b ,` | 설정 (일반 `,`는 창 너비 조절) |
| 창 관리 모드 / sidebar의 `n` | 현재 세션에 새 창 (sidebar에서는 `t`도 가능) |
| 창 관리 모드 / sidebar의 `N` | 새 세션 |
| `Ctrl-b b` | sidebar 표시·숨기기 |
| `Ctrl-b B` | spotlight 켜기·끄기 (창 관리 모드에서는 `B`) |
| `Ctrl-b i` | agent Inbox |
| `Ctrl-b g` | Lazygit popup (`q`로 닫기) |
| `Ctrl-b y` | Yazi popup (`q`로 닫기) |
| `Ctrl-b v` | CodeDiff 변경 리뷰 popup (`gd`, 변경이 없으면 HEAD) |
| `Ctrl-b V` | CodeDiff 커밋 이력 popup (`gh`) |
| `Ctrl-b u` | TUIOS Changes view (기존 `Ctrl-b v`) |
| `Ctrl-b I` | 이미지 붙여넣기 (기존 `Ctrl-b V`) |
| `Ctrl-b Ctrl-t` | shell popup (`exit`로 닫기) |
| `Ctrl-Shift-p` | 명령 팔레트 |
| `Ctrl-b d` | detach; 프로그램은 계속 실행 |

`s`·`w` picker의 `Ctrl-d`도 같은 종료 동작을 사용한다. 확인 후 picker는 닫힌다.
삭제 작업은 독립 프로세스에서 실행해 자신의 popup이 닫혀도 끝까지 수행한다.
세션 전환이 완료되지 않으면 기존 세션은 삭제하지 않는다. 오류는
`~/.local/state/dotfiles-tuios/close.log`에 기록한다.

CodeDiff popup은 pane 영역의 100%를 채운다. 상단바·sidebar와 popup 테두리는 남는다.
현재 포커스된 pane의 디렉터리에서 열며, 종료하면 기존 화면으로 돌아온다.
미커밋 변경이 없으면 HEAD 커밋의 변경을 연다. popup 안에서 `<leader>gd`·`gv`·`gh`로
현재 변경·선택한 커밋·이력을 같은 리뷰 탭에서 전환한다. `q`로 Neovim도 종료한다.

애니메이션을 끄고, Neovim의 `Ctrl-p`를 보존한다. Option+숫자와 일부 Option+문자는 AeroSpace에 맡긴다.
`Ctrl-b p` → `project` → 프로젝트 선택으로 세션을 준비한 뒤 `Ctrl-b s`에서 해당 세션으로 이동한다.
기존 세션이 있으면 다시 만들지 않는다. 프로젝트 목록은 `w project`와 같은 캐시를 사용한다.
본 저장소와 연결된 worktree를 `프로젝트 / 작업명 · 브랜치`로 표시하며 이름과 브랜치로 검색한다.
선택한 worktree 경로마다 독립적인 TUIOS 세션을 만들거나 재사용한다.
캐시가 있으면 즉시 선택할 수 있고, 백그라운드 갱신 결과는 다음 picker에 반영한다.
현재 picker의 목록을 갱신하려면 `Ctrl-r`을 누른다.
검색은 표시된 프로젝트/worktree 이름과 브랜치를 대상으로 한다. 공백으로 구분한 조건은 모두 만족해야 한다.
예: `ai-chat attachment`는 ai-chat 프로젝트의 attachment worktree를 좁힌다.
`^anchorbase`는 프로젝트 이름의 시작 부분을 고정하고, `'anchorbase`는 문자열을 그대로 검색한다.
`^anchorbase !docs`는 anchorbase 프로젝트에서 docs가 들어간 이름·브랜치를 제외한다.
Spotlight는 기본으로 꺼져 있다. 일반 `b`에 잘못 켜지지 않도록 대문자 `B`로 분리했다.
창 관리 모드(`Ctrl-b Esc`)에서 `,` / `.`는 왼쪽 경계를 기준으로 너비를 줄이거나 늘린다.
`<` / `>`는 오른쪽 경계 기준 너비 조절이고 `{` / `}`는 높이 조절이다. `=`로 비율을 균등하게 하고 `i`로 입력 모드에 복귀한다.
keybind manager는 `Ctrl-b .`로 옮기고 `Ctrl-b j`의 알림 이동은 해제해 hjkl 이동을 보존한다.
`Ctrl-b ?`는 도움말이고 `Ctrl-b .`는 실제 키 설정·충돌을 확인하고 편집하는 keybind manager다.
TUIOS 0.8.5의 which-key는 기본 키 표를 표시하므로 커스텀 키와 다를 수 있다.
키 바인딩 변경은 `tuios config apply`만으로 반영되지 않을 수 있다. 현재 세션에서
`Ctrl-b d`로 detach한 뒤 `tuios attach <세션 이름>`으로 다시 연결하면 키 설정을 새로 읽는다.
pane과 실행 중인 프로그램은 유지된다. 실제 등록은 `Ctrl-b .` 또는
`tuios keybinds explain V`·`tuios keybinds explain u`로 확인한다.
`Ctrl-b s/w`는 fzf popup을 사용하고, 목록 순서를 유지하면서 현재 session/workspace에 시작 커서를 둔다.
`acp`처럼 글자를 줄이거나 `anchor cp`처럼 공백으로 조건을 나눠 검색할 수 있다.
session은 표시 이름, workspace는 이름과 번호로 검색한다. 경로와 pane 수는 검색 대상에서 제외한다.
검색어를 입력하면 가장 잘 맞는 첫 결과에 커서를 둔다.
Enter는 결과로 이동만 하고, 결과가 없으면 창을 유지한다.
`Ctrl-r`은 커서가 가리키는 대상의 이름을 변경하고, `Ctrl-d`는 그 대상의 종료 확인창을 연다.
확인창은 취소가 기본값이며 `y` 또는 종료 항목 선택으로 실행한다. 종료·이름 변경 후 목록을 다시 읽는다.
session 이름 변경은 표시 이름만 바꾸므로 CLI identity와 프로젝트 UUID 연결을 유지한다.
추가는 `Ctrl-a`로 분리했다. session 추가는 표시 이름을 입력한 뒤 현재 경로에 shell 하나를 열고
새 session으로 이동한다. 빈 이름 또는 Ctrl-c는 취소한다. session의 실제 이름 변경은 `Ctrl-b $`,
기존 session 관리 UI는 command palette (`Ctrl-b P`)의 session switcher에서 사용할 수 있다.
workspace 추가는 `Ctrl-a` 또는 `Ctrl-b c`를 쓴다. workspace 이름 변경은 `Ctrl-b W`를 쓴다.
TUIOS 실행 파일은 수정하지 않는다. `tuios-picker`는 공식 CLI와 내장 herdr 호환 API를 사용한다.
picker는 종료할 때 자기 popup을 직접 정리한다. 세션 이동 직후 이전 세션의 PTY 종료 알림을
놓쳐 빈 popup이 남는 경우를 방지한다. 수동 종료는 popup에 포커스를 둔 뒤 `Ctrl-b x`를 쓴다.
session 검색은 로컬 데몬의 세션을 표시한다. 원격 세션은 기존 session switcher에서 선택한다.
`Ctrl-b c`는 현재 세션의 1–9 workspace 중 이름이 없고 비어 있는 곳을 사용한다.
기본 배치는 master-stack이라 왼쪽 master에서 split해도 새 pane이 오른쪽 stack에 들어간다.
현재 pane을 직접 나누려면 command palette (`Ctrl-b P`)에서 BSP 레이아웃으로 전환한 뒤
`Ctrl-b -` (위·아래) 또는 `Ctrl-b |` (좌·우)를 사용한다.
TUIOS 안에서 `w`를 실행하면 원래 tmux 명령을 호출하므로, 시험용 메뉴는 `Ctrl-b p`를 쓴다.
Codex 대화는 앱 자체 스크롤로 읽는다. TUIOS의 `Shift-↑/↓` 스크롤 바인딩은 해제해
Codex의 effort 조절 키를 보존한다. `scroll_lines = 1`로 앱에 전달하는 휠 이벤트의 증폭도 끈다.
TUIOS copy mode는 터미널이 보관한 화면 기록만 보여주므로 Codex 전체 대화와 다를 수 있다.
새 세션의 이름은 본 저장소 `ui-hub`, worktree `ui-hub · login`처럼 프로젝트 중심으로 만든다.
TUIOS는 `/`를 허용하지 않고 CLI에서 `:`는 원격 호스트 구분자이므로 작업명 앞에는 ` · `를 사용한다.
다른 경로의 프로젝트와 이름이 겹치면 `ui-hub-2`처럼 숫자를 붙인다.
같은 경로에서 project를 다시 실행하면 기존 세션을 재사용한다. 기존 세션 이름은 자동으로 바꾸지 않는다.
프로젝트 경로별 세션 UUID를 `~/.local/state/dotfiles-tuios/projects/`에 기록한다.
`Ctrl-b $` 또는 `tuios rename-session 이름`으로 이름을 바꿔도 `wt`와 project 메뉴는 같은 세션을 재사용한다.
세션을 삭제하면 새로 만들고 UUID를 갱신한다. ID 기록 도입 전 이름을 바꾼 worktree 세션도
해당 worktree 경로와 일치하는 세션이 하나면 재사용한다.

Codex 연동은 `tuios integration install codex`로 설치했다. 기존 hooks 파일은 설치 도구가
`~/.codex/hooks.json.tuios.bak`에 보관했다. 첫 Codex 실행의 **Hooks need review**는 직접 검토한다.
그 확인 전에는 hook 기반 상태·대화 ID 수집이 검증된 상태가 아니다.
클라이언트 detach는 프로세스를 유지하지만 daemon 종료·재부팅은 프로세스를 유지하지 않는다.

## workmux + shim 확인 결과

2026-10-07, 설치된 TUIOS 0.8.5 / workmux 0.1.178로 임시 Git 저장소에서 확인했다.

1. 원래 shim: `show-option -gqv default-shell` 미지원으로 pane 준비 실패.
2. 임시 adapter에서 default-shell 조회와 `new-window -a -t` 차이를 보완하면
   `workmux add --no-pane-cmds --background`로 worktree와 빈 pane 생성 성공.
3. 실제 pane 명령을 실행하면 `wait-for -L` 미지원으로 실패.
4. 기존 프로젝트 전환에 쓰는 `switch-client`도 공식 shim 미지원이다.

따라서 full workflow용 adapter는 설치하지 않았다. `wait-for`를 성공한 척 무시하면
준비되지 않은 shell에 명령을 보내는 문제가 생길 수 있다. shim의 원래 지원 범위 안에서만 사용한다.
workmux의 layout 비율도 shim으로 그대로 옮길 수 없다.

실제 PTY에서 세 pane 표시, workspace 메뉴, Yazi popup의 실행·종료, detach/reattach와 PTY 재사용을 확인했다.
Codex hook 신뢰 승인 후 실제 요청·완료·대화 재개와 Ghostty에서의 한글·이미지·클립보드는 추가 확인 대상이다.

TUIOS Settings는 로컬 `~/Library/Application Support/tuios/config.toml`을 수정한다.
`setup.zsh`는 기존 링크의 내용을 보존해 로컬 파일로 전환하므로 설정 변경이 저장소를 수정하지 않는다.
저장소 기본값을 다시 적용할 때는 `setup --refresh-tuios`를 실행한다. 기존 로컬 설정은 백업한다.

## Sidebar

Sidebar는 `sessions → 여백 → terminals → agents` 순서로 각각 32% / 3% / 25% / 40%를 배정한다.
여백은 일반적인 창 높이에서 약 1~3줄이며, 높이가 작은 창에서는 줄어들 수 있다.
파일 목록은 제외하며 Yazi popup을 사용한다. `terminals`는 세션의 개별 pane(window) 목록이다.
기본 폭은 36칸이고 직접 드래그한 폭이 있으면 그 값이 우선한다.
Sidebar 배경을 어둡게 구분하고 상단바에 `SESSION: 현재 세션명`을 항상 표시한다.
이름 변경은 최대 2초 안에 반영된다. 새 headless 세션에서도 sidebar 구성을 유지하도록
연결 hook이 config 파일의 섹션·배경·기본 폭을 적용한다.
Agents는 전체 세션(`all`)에서 사용자 확인이 필요한 순서(`you`)로 사용한다.
Sidebar에 포커스를 둔 뒤 `f`로 all/session 범위를, `o`로 정렬을 변경할 수 있다.
Agent 항목을 선택하면 해당 세션·pane으로 이동한다.
