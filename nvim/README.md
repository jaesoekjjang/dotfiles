# PC 간 설치 상태 맞추기

`setup`은 설정을 연결한다. `~/.local/share/nvim`의 플러그인, Tree-sitter parser,
Mason 패키지는 PC별로 설치되므로 dotfiles만 동기화해도 함께 바뀌지는 않는다.
설정·lockfile을 받은 뒤 기존 Neovim 설치에서는 `:Lazy restore`를 실행하고 재시작한다.
Tree-sitter는 `main` API를 사용하며 parser는 시작 시 설치한다. 언어 서버 설치 상태는 `:Mason`에서 확인한다.

Neovim 0.12에서는 parser가 없는 파일 타입의 `get_parser()`가 `nil`을 반환한다.
이를 지원하는 rainbow-delimiters 버전을 lockfile에 고정했다. `alpha`·`noice` 같은 UI 버퍼도
parser 없이 정상 동작해야 한다. 삭제된 컴파일러 wrapper가 `CC`에 남은 경우에는
parser 설치가 시스템 컴파일러를 사용하도록 한다.

# 검색과 picker

파일명·본문 검색은 fff, 나머지 목록과 선택 UI는 Snacks를 사용한다.
fff는 네이티브 바이너리가 필요한 플러그인으로, 설치 시 해당 릴리스의 바이너리를 내려받는다.

| 키 | 동작 |
| --- | --- |
| `<leader>ff` | fff 파일명·경로 검색 |
| `<leader>fg` | fff 본문 검색; Visual 모드에서는 선택한 텍스트 검색 |
| `<leader>fG` | Snacks ripgrep 검색과 추가 옵션 |
| `<leader>fr` | 마지막 fff 검색어·검색 모드·선택 위치 복원 |
| `<leader>fb`, `fo`, `fh`, `fm` | 버퍼, 최근 파일, 도움말, marks |
| `<leader>sd`, `sw` | 문서·워크스페이스 심볼 |
| `gd`, `gvd`, `gtd`, `grr`, `gi` | 정의, 수직 분할 정의, 타입 정의, 참조, 구현 |
| `<leader>dd`, `dD` | 현재 버퍼·전체 진단 |
| `<leader>gc`, `gb`, `gs` | Git 커밋, 브랜치, stash |
| `<leader>gw`, `gW` | worktree 선택·생성 |
| `<leader>ql`, `qh` | 현재 quickfix 목록 검색, quickfix 목록 이력 선택 |
| `<leader>u`, `mp` | Undo 이력, make 프로그램 선택 |
| `<leader>ss`, `sS` | 세션 검색·저장 |

`<leader>sw`는 워크스페이스 심볼에 사용한다. 이전에 충돌하던 세션 저장은 `<leader>sS`로 옮겼다.
AI 작업은 `Space aw`에서 [workspace 메뉴](../workmux/README.md)를 연다.

FFF·Snacks picker에서 `<C-o>`는 파일 경로를 복사하고, `gc`·`gv` 등 커밋 picker에서는 선택한 커밋의 짧은 hash를 복사한다.
복사하면 짧게 "경로 복사됨" 또는 "Hash 복사됨" 알림이 표시된다. 일반 편집창의 `<C-o>` 점프 이동은 유지한다.
Undo에서는 `<C-y>`로 추가된 줄을 복사하는 Snacks 기본 동작을 사용한다.
버퍼 picker의 `<C-d>`는 미저장 변경이 있으면 저장 여부를 확인한다.

fff 본문 검색 입력 예시:

```text
*.{ts,tsx} useState
src/**/*.ts !src/**/generated/** TODO
**/main.ts needle
```

본문 검색은 fuzzy로 시작하고 `<S-Tab>`으로 fuzzy → plain → regex 순서로 전환한다.
`<Esc>`를 한 번 누르면 Normal 모드로 전환해 검색어를 Vim motion으로 편집할 수 있다.
Normal 모드의 `j`·`k`는 결과 선택을 이동한다. `i`·`a`로 입력을 재개하고, Normal 모드에서 `<Esc>`·`q`로 닫는다.
파일명 자동 필터는 껐다. `console.log value`나 `user.name =`가 파일명 필터로 오인되지 않는다.
파일을 지정할 때는 `**/main.ts needle` 또는 `src/**/main.ts needle`처럼 glob을 사용한다.
`glob:` 접두사는 없다. `fg`에서 `*user*`는 검색어이고, `**/*user* TODO`는 파일 glob과 검색어다.

fff v0.11.0의 Neovim 구현은 `git:modified`를 파일 검색에서는 지원하지만 본문 검색에서는 지원하지 않는다.
임의의 ripgrep 옵션이 필요하면 `<leader>fG`에서 검색어 뒤에 ` -- `를 붙인다:

```text
needle -- --glob=*.tsx --ignore-case
```

worktree를 선택하면 작업 디렉터리를 바꾸고, 저장된 현재 파일은 새 worktree의 같은 상대 경로로 연다.
미저장 버퍼는 그대로 유지한다. worktree 생성은 기존 브랜치 또는 새 브랜치 이름과 경로를 입력받는다.

Markdown 선택 메뉴도 Snacks를 사용한다. 브라우저 미리보기는 브라우저 확장을 사용한다.
Oil은 설정만 보관하고 비활성화 상태를 유지한다.

## 편집 단축키

| 키 | 동작 |
| --- | --- |
| `Ctrl-o` / `Ctrl-i` | 이전·다음 점프 위치로 이동 (Neovim 기본 동작) |
| `<leader>wo` | 현재 창만 남기기 |
| `<leader>bd` / `bc` | 현재 버퍼 삭제 / 삭제 후 이전 버퍼로 이동 |
| `<leader>bo` | 현재 버퍼와 수정 중인 버퍼를 보존하고 나머지 삭제 |
| `<leader>bx` / `bX` | 모든 버퍼 삭제 / 미저장 변경도 강제로 버리고 삭제 |
| `[b` / `]b` | 이전·다음 버퍼; 입력·명령 모드에서도 동작 |
| `[d` / `]d` | 이전·다음 오류 진단만 이동 |
| Visual `J` / `K` | 선택한 줄을 아래·위로 이동하고 선택 유지 |
| `ia` / `aa` | 함수 인자 / 구분 쉼표를 포함한 인자 선택 |
| `P{motion}` / `Pr` / Visual `P` | 레지스터 내용으로 대상 / 현재 줄 / 선택 영역 교체 |
| `<leader>qq` / `ql` / `qh` | quickfix 창 토글 / 현재 목록 검색 / 목록 이력 선택 |
| `[q` / `]q` | 이전·다음 quickfix 항목; `3]q`처럼 개수 지정 가능 |
| `[Q` / `]Q` | quickfix 처음·마지막 항목 |

`c`, `D`, `C`, `H`, `L`, `,` 등의 편집 매핑은 기존 사용자 설정을 유지한다.

quickfix 관리 기능은 `<leader>q` 아래에 모았다. 일반 `q`의 매크로 녹화는 유지한다.
`ql`은 현재 목록의 항목을 검색하고, `qh`는 이전 검색·빌드 등으로 만들어진 목록 자체를 선택한다.
이전 `cq`·`ch`·`cn`·`cp` 매핑은 제거했다.

IdeaVim의 argtextobj와 ReplaceWithRegister 동작은 기존 의존성인 mini.nvim으로 구성했다.
`cia`는 인자 내용을 수정하고, `daa`는 인자와 구분 쉼표를 삭제한다.
`Piw`는 단어를 교체하고, `"aPiw`는 a 레지스터를 사용한다. `.`으로 교체를 반복할 수 있다.
Normal `P`는 붙여넣기 대신 교체 연산자로 동작한다. 일반 붙여넣기는 `p`를 사용한다.

## Git

`<leader>g`는 저장소 작업, `<leader>h`는 현재 파일의 hunk 작업이다.
Neovim의 Lazygit 매핑은 제거했다. 저장소 상태는 Fugitive로 열고, 목록 검색은 Snacks를 사용한다.

| 키 | 동작 |
| --- | --- |
| `<leader>gg` | Fugitive Git 상태를 수직 분할로 열기 |
| `<leader>gc` | 커밋 검색 후 Fugitive로 내용 열기; checkout하지 않음 |
| `<leader>gv` | 커밋 선택 후 CodeDiff로 해당 커밋의 변경 파일 리뷰 |
| `<leader>gd` | CodeDiff로 미커밋 변경 열기; 변경이 없으면 HEAD 커밋의 변경 열기 |
| `<leader>gh` | 같은 리뷰 탭의 왼쪽 패널을 커밋 이력으로 전환; 이미 열려 있으면 목록에 포커스 |
| `<leader>gb` / `gs` | 브랜치 / stash 목록 검색 |
| `<leader>gw` / `gW` | worktree 선택 / 생성 |
| `<leader>gm` | Merginal 브랜치 관리창 토글 |

Gitsigns는 Git 파일의 변경 표시와 hunk 작업을 담당한다.

| 키 | 동작 |
| --- | --- |
| `[h` / `]h` | 이전·다음 hunk; 개수 지정 가능 |
| `<leader>hs` / `hr` | 현재 hunk stage / 변경 되돌리기; Visual에서는 선택한 줄만 처리 |
| `<leader>hS` / `hu` | 현재 버퍼 전체 stage / 마지막 hunk stage 취소 |
| `<leader>hp` / `hb` / `hd` | hunk 미리보기 / 현재 줄 blame / diff 분할 |
| `<leader>hD` | 현재 파일의 커밋 이력에서 비교 대상 선택; 수직 diff |
| `<leader>hq` | 현재 버퍼의 미stage 변경을 quickfix에 넣고 열기 |
| `ih` | hunk 선택; `vih`, `dih` 등에서 사용 |

`hr`는 선택한 변경을 버리므로 되돌릴 대상부터 확인한다.

`gd`는 저장소 전체, `hd`·`hD`는 현재 파일을 대상으로 한다.
`hd`는 index와 바로 비교하고, `hD`는 선택한 커밋 시점과 현재 파일을 비교한다.
`gv`는 선택한 커밋과 그 첫 번째 부모를 비교해 해당 커밋이 만든 변경만 보여준다.
최초 커밋은 빈 tree와 비교한다. checkout이나 reset을 실행하지 않는다.

`gv`·`hD` picker에서 Enter로 커밋을 선택하거나, `Ctrl-r`로 hash·브랜치·태그를 직접 입력한다.
명령으로도 사용할 수 있다:

```vim
:GitReview 4127ad2
:FileDiff HEAD
:FileDiff origin/main
```

인자를 생략하면 picker를 연다. 두 커밋이나 브랜치 사이의 범위는 원래 명령을 사용한다:

```vim
:CodeDiff origin/main...HEAD
```

CodeDiff에서는 파일 목록에서 Enter로 파일을 열고, Tab·Shift-Tab으로 다음·이전 파일을 이동한다.
`j`·`k`는 목록만 이동한다. `q`로 CodeDiff를 닫고 원래 작업 탭으로 돌아간다.
파일 목록과 history에서 `Ctrl-p`로 커서 미리보기를 켜거나 끈다 (기본 OFF).
ON이면 커서 이동만으로 diff가 바뀌며, history의 커밋 행은 변경 파일을 펼쳐 미리 본다.
직전에 보던 파일이 해당 커밋에도 있으면 유지하고, 없으면 첫 번째 변경 파일을 연다.
한 파일의 history에서는 커밋 행을 이동하면 그 파일의 diff가 바뀐다.
`:CodeDiff history %`는 현재 파일의 변경 이력을 연다.
`:CodeDiff history`는 저장소의 최근 커밋 목록을 연다. 커밋에서 Enter로 파일 목록을 펼치고,
파일에서 Enter로 diff를 열어 다른 커밋의 변경을 둘러볼 수 있다.
CodeDiff 안에서도 `<leader>gv`로 커밋을 다시 고르거나 `Ctrl-r`로 hash를 입력할 수 있다.
`gd`·`gv`·`gh`는 저장소별 리뷰 탭 하나를 재사용한다. `gh`로 이력을 펼치고 Enter로
다른 커밋의 파일을 선택하면 같은 화면의 diff가 바뀐다. 현재 커밋이 최근 목록에 있으면 유지한다.
`gh`는 최근 10개의 non-merge 커밋을 먼저 표시하고, 뒤에서 최대 100개로 확장한다.
확장은 화면이 열린 직후 시작해 전체 조회가 끝나면 반영한다. 오래된 커밋의 변경량 계산이
느린 저장소에서는 확장까지 오래 걸릴 수 있다.
merge나 더 오래된 커밋은 `gv`로 선택한다.
`:GitHistory`도 `gh`와 같다. 원래 `:CodeDiff history`는 별도 탭을 연다.
`gd`가 HEAD로 전환하면 hash와 커밋 제목을 안내한다.
`:GitDiff!`·`:GitHistory!`는 `q`로 Neovim도 종료한다. 활성 conflict view는 먼저 닫고 전환한다.

충돌 해결 키는 Space 없이 사용한다:

| 키 | 동작 |
| --- | --- |
| `[x` / `]x` | 이전 / 다음 conflict |
| `co` / `ct` / `cb` / `c0` | ours / theirs / 양쪽 모두 / 모두 제거 |

## tmux popup

tmux prefix는 `Ctrl-b` 또는 `Ctrl-k`다.
`prefix → Ctrl-y`는 Yazi, `prefix → Ctrl-t`는 shell을 현재 pane의 디렉터리에서 연다.
Yazi는 `q`, shell은 `exit`로 종료한다. 기존 `prefix → g`의 Lazygit popup도 유지한다.
tmux 3.6a의 popup 커서 조회 버그(#4942)를 피하려고 Yazi는 별도 tmux 서버의 pane에서 실행한다.
Yazi를 종료하거나 popup을 닫으면 해당 세션도 제거된다. 기존 작업 세션에는 영향을 주지 않는다.

### CodeDiff 패널 복구

- `<leader>b`: changes 목록 숨기기/표시. `<leader>e`: 목록으로 포커스.
- CodeDiff 안의 `gR` / `:GitDiffRestore`: 현재 선택한 비교 버퍼와 숨기거나 닫은 목록 창 복구.
  비교 창을 닫아 CodeDiff 세션 자체가 종료된 경우에는 현재 변경사항 리뷰를 새로 연다.
  이때 이전 커밋 선택은 유지되지 않는다 (`:GitReview <commit>`으로 다시 열기).
- `:GitDiff`도 기존 리뷰 탭을 재사용할 때 비교 버퍼를 다시 표시한다.
- 리뷰 중 일반 파일 편집은 `gf`로 이전 탭에서 열고, `gt`로 리뷰 탭에 돌아오는 흐름을 권장한다.
  비교 창 자체에서 다른 버퍼를 열었다면 `:GitDiffRestore`로 복구한다.
- 회귀 확인: 저장소 루트에서 `nvim --headless -u NONE -l tests/codediff_restore.lua`.

CodeDiff는 변경 없는 부분을 기본으로 접는다 (`compact = true`). `gc`로 접기/펼치기를 전환한다.
Changes 목록의 `Ctrl-p`는 커서 자동 미리보기 토글이다. 기본은 꺼짐이며, 켜면 `j/k` 등으로
커서를 옮길 때 해당 파일의 비교 화면이 갱신된다. History 목록에서도 동작한다. 커밋 행에서는 직전에 보던 파일이 있으면 그 파일을, 없으면 첫 파일을 미리본다. 펼쳐진 파일 행에서는 해당 파일을 미리본다.
이전에 참조하던 누락된 `utils.codediff_preview` 대신 리뷰 설정에서 이 동작을 제공한다.

변경 목록 밖의 파일은 `<leader>ff`의 미리보기에서 확인할 수 있다. 길게 보거나 편집하려면
검색창에서 `Ctrl-s` (상하) / `Ctrl-v` (좌우)로 같은 탭에 별도 창을 열고,
`Ctrl-w q`로 그 보조 창만 닫는다. 검색에서 Enter로 기존 비교 창의 버퍼를 바꿨다면 `gR`로 돌아온다.
파일 검색은 현재 작업 트리의 파일을 보여주며 과거 커밋 버전은 아니다.

CodeDiff 안의 `gP`는 목록 패널을 왼쪽 ↔ 아래로 옮긴다. 선택한 파일과 미리보기 상태는 유지한다.
플러그인의 배치 설정이 패널 종류별 공통값이므로, 같은 Neovim의 열린 Changes 목록끼리
또는 History 목록끼리 함께 이동한다. 실행 중에만 적용되며 Neovim을 다시 열면 왼쪽에서 시작한다.
