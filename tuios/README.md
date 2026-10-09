# TUIOS trial

현재 TUIOS 0.9.1을 사용한다. 기존 `w`는 tmux/workmux용이며 변경하지 않았다.

Ghostty의 tmux 밖 새 창에서 `wt`를 실행한다. 현재 Git 프로젝트의 Codex + Neovim + shell 세션을 열고,
같은 경로에서 다시 실행하면 기존 세션에 붙는다. `wt /path/to/repo`로 경로를 지정할 수 있다.
새 세션은 workspace 1 `dev`에 agent 왼쪽 / editor 오른쪽 2분할로 배치하고 agent에 포커스를 둔다.
workspace 2 `terminal`에는 shell 하나를 전체 화면으로 연다. `Ctrl-b n/v` 또는 `Ctrl-b w`로 workspace를 이동한다.
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
| `Ctrl-b p` | 프로젝트 picker 바로 열기 |
| `Ctrl-b h/j/k/l` 또는 방향키 | pane 이동 |
| `Ctrl-b Ctrl-v` 또는 `Ctrl-b \` | 좌우 분할 (오른쪽에 새 pane) |
| `Ctrl-b Ctrl-s` 또는 `Ctrl-b -` | 상하 분할 (아래에 새 pane) |
| `Ctrl-b H/J/K/L` | 왼쪽/아래/위/오른쪽 pane과 자리 교환 |
| `Ctrl-b Ctrl-l` | layout 메뉴 (`s`: 저장, `l`: 불러오기) |
| `Ctrl-b o` | split 회전 (기존 `Ctrl-b R`, BSP에서 사용) |
| `Ctrl-b Backspace` | 직전 session 왕복 (현재 client의 이동 이력) |
| `Ctrl-b z` | 현재 pane 확대 |
| `Ctrl-b Ctrl-x` | 현재 session 종료 확인창 → 다른 session으로 이동 후 종료 (마지막 session이면 TUIOS 종료) |
| `Ctrl-b &` | 현재 workspace 종료 확인창 → 모든 pane·이름 제거 후 이웃 workspace로 이동 |
| `Ctrl-b s` | Go picker로 session 검색·선택 (Ctrl-a: 새 session) |
| `Ctrl-b w` | Go picker로 workspace 검색·선택 (Ctrl-a: 새 workspace) |
| `Ctrl-b n` / `Ctrl-b v` | 다음 / 이전 workspace (빈 무명 workspace는 건너뛰고 순환) |
| `Ctrl-b Tab` / `Ctrl-b Shift-Tab` | 다음 / 이전 pane |
| `Ctrl-b c` | 빈 workspace에 현재 pane 경로의 shell을 열고 이동 |
| `Ctrl-b !` | 현재 pane을 새 workspace로 분리하고 함께 이동 |
| `Ctrl-b t n` | 현재 workspace에 새 pane |
| `Ctrl-b W` | workspace 관리 메뉴 (이동·이름 변경) |
| `Ctrl-b 1` … `9` | 현재 workspace의 1~9번째 pane 선택 |
| `Ctrl-b W` → `1` … `9` | 해당 번호의 workspace로 이동 |
| `Ctrl-b $` | 현재 session 이름 변경 (Enter: 저장, Esc: 취소) |
| `Ctrl-b S` | scrollback browser |
| `Ctrl-b ?` | 도움말 |
| `Ctrl-b .` | keybinding manager (실제 키·충돌 확인 및 편집) |
| `Ctrl-b ,` | 현재 workspace 이름 변경 |
| `Ctrl-b ~` | 설정 (Shift+백틱) |
| 창 관리 모드 / sidebar의 `n` | 현재 세션에 새 창 (sidebar에서는 `t`도 가능) |
| 창 관리 모드 / sidebar의 `N` | 새 세션 |
| `Ctrl-b b` | sidebar 표시·숨기기 |
| `Ctrl-b B` | spotlight 켜기·끄기 (창 관리 모드에서는 `B`) |
| `Ctrl-b i` | agent Inbox |
| `Ctrl-b g` | Lazygit popup (`q`로 닫기) |
| `Ctrl-b f` | 화면의 URL·경로·해시 등에 힌트 표시 → 라벨 입력으로 복사 |
| `Ctrl-b /` | 전체 session의 pane 검색 |
| `Ctrl-b y` | Yazi popup (`q`로 닫기) |
| `Ctrl-b G` | CodeDiff 변경 리뷰 popup (`gd`, 변경이 없으면 HEAD) |
| `Ctrl-b u` | TUIOS Changes view (기존 `Ctrl-b v`) |
| `Ctrl-b I` | 이미지 붙여넣기 (기존 `Ctrl-b V`) |
| `Ctrl-b Ctrl-t` | shell popup (`exit`로 닫기) |
| `Ctrl-Shift-p` | 명령 팔레트 |
| `Ctrl-b Ctrl-d` | detach; 프로그램은 계속 실행 |

`s`·`w` picker의 `Ctrl-x`도 같은 종료 동작을 사용한다. 현재 대상을 종료하면 picker는 닫히고,
다른 대상을 종료하면 목록에 남아 계속 선택할 수 있다.
삭제 작업은 독립 프로세스에서 실행해 자신의 popup이 닫혀도 끝까지 수행한다.
세션 전환이 완료되지 않으면 기존 세션은 삭제하지 않는다. 오류는
`~/.local/state/dotfiles-tuios/close.log`에 기록한다.

CodeDiff popup은 pane 영역의 100%를 채운다. 상단바·sidebar와 popup 테두리는 남는다.
현재 포커스된 pane의 디렉터리에서 열며, 종료하면 기존 화면으로 돌아온다.
미커밋 변경이 없으면 HEAD 커밋의 변경을 연다. popup 안에서 `<leader>gd`·`gv`·`gh`로
현재 변경·선택한 커밋·이력을 같은 리뷰 탭에서 전환한다. `q`로 Neovim도 종료한다.

애니메이션을 끄고, Neovim의 `Ctrl-p`를 보존한다. Option+숫자와 일부 Option+문자는 AeroSpace에 맡긴다.
`Option-Esc`의 창 관리 모드 전환은 해제했다. 빠른 `Esc Esc`와 같은 입력으로 해석될 수 있어 Codex 같은 pane 내부 앱의 Esc를 가로채기 때문이다. 창 관리 모드는 `Ctrl-b Esc`로 들어간다.
`Ctrl-b p` → 프로젝트 선택으로 세션을 준비한 뒤 `Ctrl-b s`에서 해당 세션으로 이동한다.
기존 메뉴는 `tuios-trial menu`로 열 수 있다. editor/agent/review 항목은 새 pane을 만든다.
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
`Ctrl-b Ctrl-d`로 detach한 뒤 `tuios attach <세션 이름>`으로 다시 연결하면 키 설정을 새로 읽는다.
pane과 실행 중인 프로그램은 유지된다. 실제 등록은 `Ctrl-b .` 또는
`tuios keybinds explain V`·`tuios keybinds explain u`로 확인한다.
`Ctrl-b s/w`는 Go / Bubble Tea popup을 사용하고, 현재 session/workspace를 표시하며 시작 커서를 둔다.
`s`는 현재 client의 최근 방문 순서로 session을 표시한다. 방문 이력이 없으면 데몬의 최근 활동 순서를 쓴다.
`s`에서도 `Tab`/`Ctrl-o`로 session 아래 workspace를 펼치거나 접는다. 기본은 전체 펼침이다.
`Ctrl-n/p`는 workspace 포함 한 줄씩, `Ctrl-j/k`는 session 행 단위로 이동한다.
workspace 행에서 Enter를 누르면 해당 session의 그 workspace로 이동한다. 하위 workspace에서 `Ctrl-r`은 그 workspace의 이름을 바꾸고, `Ctrl-x`는 그 workspace의 종료 확인창을 연다.
다른 session 아래에는 pane이 있는 workspace만 표시한다. 마지막 workspace를 종료한 뒤 TUIOS가 유지하는 빈 슬롯은 숨기고 session 행은 남긴다. 현재 session의 빈 workspace는 `w`에서 확인·관리할 수 있다.
`s`는 세션 표시 이름과 workspace 이름·번호를 함께 검색한다. `anchorbase terminal`, `anchorbaseterminal`, `dotfiles terminal`로 같은 이름의 workspace를 구분해 바로 이동할 수 있다.
검색 중에는 접힌 세션의 workspace도 찾으며 `anchorbase › 2 terminal`처럼 소속을 표시한다. 검색을 지우면 원래 펼침 상태로 돌아온다. 선택한 workspace의 내용만 미리 볼 수 있다.
workspace만 검색된 결과에서도 `Ctrl-j/k`로 다른 세션의 결과로 이동할 수 있다.
`w`는 현재 session의 workspace를 화면 배치 순서로 표시한다.
새 workspace는 사용 중인 가장 큰 번호 뒤의 빈 슬롯에 만든다. 뒤쪽 슬롯이 다 찼으면 앞쪽의 가장 작은 빈 번호를 재사용한다. 이름만 있는 workspace와 현재 workspace도 사용 중으로 취급한다.
pane 목록은 기본으로 모두 펼쳐져 있다. `Tab` 또는 `Ctrl-o`로 선택한 workspace의 pane 목록을 펼치거나 접는다. 하나의 UI 안에서 목록만 갱신한다. pane 행에서 `Tab` 또는 `Ctrl-o`를 누르면 부모 workspace로 접힌다.
`Ctrl-n/p`는 pane 포함 한 줄씩, `Ctrl-j/k`는 다음/이전 workspace 행으로 이동한다. 검색 중에는 검색 결과에 있는 workspace만 이동한다.
workspace에서 `Enter`는 workspace로, pane에서 `Enter`는 해당 pane으로 바로 이동한다.
pane 행에서 `Ctrl-r`은 그 pane의 이름을 바꾸고, `Ctrl-x`는 그 pane만 종료한다. 확인창에서 취소할 수 있으며 부모 workspace는 종료하지 않는다. picker 밖에서는 `Ctrl-b r`로 현재 pane 이름을 바꾼다. 검색은 펼쳐진 pane 이름도 포함한다.
`s`·`w` popup은 화면의 95% × 90% 크기를 사용한다.
Navigator처럼 왼쪽 목록 40%, 오른쪽 미리보기 60%로 나누고 검색은 위쪽, 키 안내는 두 패널 아래의 공통 footer에 둔다.
한 줄 안내가 들어가지 않는 좁은 창에서는 footer를 여러 줄로 나눈다.
`Ctrl-g`는 전체 펼치기/접기를 전환한다. 일부만 펼쳐져 있으면 전체를 펼치고, 모두 펼쳐져 있으면 전체를 접는다. 검색 여부와 관계없이 전체 목록에 적용한다.
`Ctrl-n/p` 행 이동과 `Ctrl-j/k` 그룹 이동은 마지막에서 처음으로, 처음에서 마지막으로 순환한다. 검색 중에는 검색 결과 안에서 순환한다.
pane 수는 목록과 미리보기에서 생략하고 종료 확인에서 표시한다.
`current`는 현재 session/workspace 또는 활성 pane을 뜻한다. 비활성 session 아래 workspace에는 현재 표시를 붙이지 않는다. pane 행은 들여쓰기로 구분한다. 상위 행은 밝고 굵게, 하위 행과 경로는 회색의 밝기 차이로 구분한다. 현재 위치는 초록색, 선택 커서는 청록색으로 표시한다.
검색 결과 수는 검색줄 오른쪽에 둔다. 미리보기의 줄 번호 표시는 숨겨 위치 정보와 겹치지 않게 한다.
미리보기는 실제 pane 화면을 색상과 함께 표시한다. 선택을 바꾸거나 미리보기를 다시 펼칠 때만 새로 불러오며 주기적으로 갱신하지 않는다.
`s`의 session 행은 현재 workspace의 활성 pane, 하위 workspace 행과 `w`의 workspace 행은 해당 workspace의 활성 pane을 보여 준다.
`w`의 pane 행은 선택한 pane을 보여 준다. picker popup은 미리보기 대상에서 제외한다.
미리보기 상단 두 줄에는 pane 이름·명령, 표시 이름을 사용한 session/workspace 위치, 경로·현재 상태를 배치한다. 경로는 흐리게 표시하고 긴 정보는 미리보기 너비에 맞춰 줄인다. 미리보기 위쪽과 왼쪽에는 한 칸 여백을 둔다.
상단 정보는 고정하고 화면은 줄바꿈 없이 표시한다. 처음에는 최근 출력이 있는 화면 아래쪽을 보여준다. `Ctrl-u/d`로 미리보기를 반 페이지씩 위/아래로 스크롤한다. `Shift-Up/Down`은 한 줄씩 스크롤한다.
선택 변경 시 즉시 새 대상으로 전환한다. 폭이 90칸 미만이면 미리보기가 아래로 이동하고, 높이도 부족하면 목록만 표시한다. `Ctrl-/`로 숨기거나 펼친다.
`acp`처럼 글자를 줄이거나 `anchor cp`처럼 공백으로 조건을 나눠 검색할 수 있다.
session은 표시 이름, workspace는 이름과 번호로 검색한다. 경로와 pane 수는 검색 대상에서 제외한다.
검색어를 입력하면 가장 잘 맞는 첫 결과에 커서를 둔다.
Enter는 결과로 이동만 하고, 결과가 없으면 창을 유지한다.
`Ctrl-r`은 선택한 행 자체의 이름을 변경한다. `s`에서는 session·workspace, `w`에서는 workspace·pane에 적용한다. `Ctrl-x`는 선택한 행 자체(session/workspace/pane)의 종료 확인창을 연다.
확인창은 취소가 기본값이며 `y`로 종료하고 Enter·`n`·Esc로 취소한다.
이름 변경 후 검색어와 선택 대상을 유지한다. 이름이 검색 조건에서 벗어나면 가까운 검색 결과를 선택한다.
다른 대상을 종료한 뒤에도 검색어를 유지하며 가까운 항목으로 이동한다.
session 이름 변경은 표시 이름만 바꾸므로 CLI identity와 프로젝트 UUID 연결을 유지한다.
추가는 `Ctrl-a`로 분리했다. session 추가는 표시 이름을 입력한 뒤 현재 경로에 shell 하나를 연다.
생성 후에는 picker에 남아 새 session을 선택한다. 빈 이름 또는 Esc는 취소한다. Ctrl-c는 picker 전체를 닫는다. session의 실제 이름 변경은 `Ctrl-b $`,
기존 session 관리 UI는 command palette (`Ctrl-b P`)의 session switcher에서 사용할 수 있다.
`w`에서 `Ctrl-a`도 이름을 입력받아 새 workspace를 만들고 picker에 남아 새 항목을 선택한다. 빈 입력 또는 Esc는 취소한다.
두 picker 모두 이름 입력 후 Enter는 생성만 하고, 선택된 새 항목에서 Enter를 한 번 더 누르면 이동한다. 새 항목을 보이도록 생성 후 검색어는 지운다.
`Ctrl-b c`는 이름 없는 workspace를 바로 만든다. 현재 workspace 이름 변경은 `Ctrl-b ,`를 쓴다.
picker 소스와 검증 방법은 [picker/README.md](picker/README.md)에 있다.
`bin/tuios-picker`는 최초 실행 또는 소스 변경 시 Go 바이너리를 `~/.cache/dotfiles-tuios/`에 빌드하고 재사용한다.
picker popup은 화면을 그리기 전에 TUIOS를 터미널 입력 모드로 전환한다. 창 관리 모드에서 열어도 첫 검색 입력이 picker로 전달된다.
Go는 기본 Brewfile에 포함된다. 첫 빌드에는 의존성 다운로드가 필요하며, 회사 PC에서는 pull 후 `./setup.zsh`로 링크를 연결하면 된다.
미리 빌드하려면 `tuios-picker --build`를 실행한다. 세션 방문 이력 파일과 기존 키 설정은 그대로 사용한다.
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

직전 session 이력은 `after-attach` hook으로 현재 PC에 기록한다. 설정 적용 후부터 기록하며,
이력이 없는 첫 실행에서는 이동하지 않는다. session 이름을 바꿔도 UUID로 추적하고,
삭제된 session은 건너뛴다. 같은 session에 client가 여러 개 연결되어 있으면 대상이 모호하여 이동하지 않는다.
