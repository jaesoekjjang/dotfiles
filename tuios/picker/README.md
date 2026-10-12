# TUIOS picker

`prefix s/w`의 세션·워크스페이스 탐색기를 Go로 구현한다. [Bubble Tea v2](https://github.com/charmbracelet/bubbletea),
[Bubbles](https://github.com/charmbracelet/bubbles)의 입력·viewport, [Lip Gloss](https://github.com/charmbracelet/lipgloss)로 화면을 구성한다.
검색은 [fzf](https://github.com/junegunn/fzf)의 Go 알고리즘을 사용하며 fzf 프로세스를 띄우지 않는다.
버전은 `go.mod`·`go.sum`에 고정한다. Go 1.26 이상이 필요하다.

## 실행과 배포

기존 진입점 `bin/tuios-picker`와 `~/.local/bin/tuios-picker` 링크를 그대로 사용한다.
런처는 소스 체크섬이 달라질 때만 빌드하고 로컬 캐시의 바이너리를 실행한다.
저장소 경로에 공백이 있거나 checkout을 옮겨도 동작하며, 원래 실행 디렉터리를 보존한다.
Go는 루트 `Brewfile`에 포함되어 있다. 회사 PC에서 pull 후 `./setup.zsh`를 실행한다.

```sh
tuios-picker --build  # 최초 다운로드·컴파일을 미리 수행
tuios-picker sessions
tuios-picker workspaces
```

`close-session`, `close-workspace`, `record-session`, `last-session`, `next-workspace`, `prev-workspace`도 유지한다.
Python picker와 fzf 내부 helper는 제거했다. 프로젝트 선택 등 다른 도구는 계속 fzf를 사용한다.

## 생성

`prefix s/w` 목록에서 `Ctrl-a`로 생성창을 연다.
`Ctrl-a`는 선택한 행과 같은 레벨 생성이 기본이다. 생성창의 `Tab`/`Shift-Tab`으로
`s`에서는 Session/Workspace, `w`에서는 Workspace/Pane을 전환한다.
이름은 즉시 입력할 수 있고 종류를 바꿔도 유지된다. 생성 후 새 행이 선택되므로 다음 `Ctrl-a`로 그 형제를 추가한다.
검색 결과가 없으면 picker의 상위 종류로 시작하고, 부모가 없는 하위 생성은 막는다.
별도 연속 생성 모드나 마지막 종류 기억은 없다. 생성창 안의 `Ctrl-a`는 줄 처음 이동이다.

목록에서 `Ctrl-n/p`는 상위 그룹(session/workspace) 사이를 이동하고,
`Ctrl-j/k`와 방향키는 하위 workspace/pane을 포함해 한 행씩 이동한다. `Tab`/`Ctrl-o`는 펼침·접기다.
하위 행에서 `Ctrl-p`는 먼저 자기 부모로 올라가고, 부모 행에서 다시 누르면 이전 그룹으로 간다.
검색으로 부모가 숨겨져 있으면 검색 결과의 이전 그룹으로 이동한다.

## 구조

- `internal/tuios`: TUIOS JSON verb socket·공식 CLI와 herdr socket, 표시 행, 화면 캡처, 종료 순서, client별 방문 이력.
  herdr의 workspace/tab을 사용자 관점의 session/workspace로 변환한다.
- `model.go`: 선택·검색·트리·확인창·스크롤 상태와 비동기 작업. 실제 제어와 테스트용 구현 모두 같은 `controller`를 사용한다.
- `view.go`: 반응형 목록/미리보기와 중립색 위계. 캡처의 SGR 색상만 보존하고 OSC·커서 제어는 제거한다.
- `search.go`: 이름·번호 퍼지 검색, 공백 AND, `|` OR, 스마트 대소문자 및 정확·접두·접미·제외 검색.

트리는 한 번 읽어 메모리에서 펼치고 접는다. 변경 작업 후에만 목록을 다시 읽는다.
session/client 목록은 방문 이력과 공유해 한 번씩 조회하며, session별 workspace는 최대 4개씩 병렬 조회한다. 완료 순서와 관계없이 기존 MRU·workspace 순서를 유지한다.
목록과 미리보기는 TUIOS의 [JSON verb protocol](https://github.com/Gaurav-Gosain/tuios/blob/v0.9.2/docs/protocol.md)로 직접 읽어 매 조회마다 CLI 프로세스를 시작하지 않는다. 저장된 목록 캐시는 사용하지 않는다.
다른 세션의 빈 workspace는 세션 트리에 넣지 않는다. TUIOS가 마지막으로 선택한 빈 슬롯이나 남아 있는 이름을 실제 workspace로 표시하지 않으며, 빈 세션 행 자체는 유지한다.
세션 검색은 부모의 표시 이름과 workspace 이름·번호를 함께 사용한다. 검색 중에는 펼침 상태에 관계없이 workspace를 찾고 소속을 표시하며, 검색을 지우면 원래 펼침 상태를 복원한다.
workspace·pane 생성창은 부모 위치를 표시한다. pane은 대상 workspace의 일반 pane 경로를 우선 사용해 기본 shell을 추가하며 기존 레이아웃을 따른다. 빈 대상은 session의 다른 pane 경로, 실행 환경의 경로 순으로 대체한다. picker 자체의 경로는 상속 대상에서 제외한다.
`Enter`는 하나 생성하고 목록으로 돌아온다. 생성 후에는 검색어를 지우고 부모를 펼친 뒤 새 항목을 선택하며 실제 session/workspace 포커스는 유지한다. 목록에서 Enter를 눌렀을 때 이동한다.
`Esc` 또는 빈 이름의 Enter는 생성 취소다. 생성 오류는 입력창과 이름을 유지한다. workspace 생성 후 이름 지정만 실패하면 생성된 workspace를 선택하고 오류를 표시해 중복 생성을 방지한다.
첫 목록은 미리보기를 기다리지 않는다. 미리보기는 이미지 촬영이 아니라 선택한 pane의 터미널 텍스트를 읽으며, 선택 변경·재표시 때 한 번 캡처하고 짧은 지연으로 빠른 키 반복을 합친다.
이전 선택의 응답은 세대 번호로 버린다. 주기 갱신이나 별도 미리보기 프로세스는 없다.
초기 스크롤은 최신 출력이 있는 아래쪽이며 `Ctrl-u/d`는 오른쪽 미리보기만 반 페이지 이동한다.

`Ctrl-x`는 항상 확인창을 거친다. 다른 대상을 닫으면 검색·펼침 상태를 유지한다.
`Ctrl-r`은 계층에 관계없이 선택한 session·workspace·pane의 이름을 변경한다. 다른 세션 아래 workspace는 그 세션을 명시해 변경하고, pane은 선택한 pane ID로 변경한다. 검색어·선택·펼침 상태를 유지한다.
native picker popup은 UI를 시작하기 전에 TUIOS의 터미널 입력 모드로 전환한다. 일반 shell에서 실행한 picker는 바깥 모드를 변경하지 않는다.
자신의 session/workspace를 닫을 때는 별도 프로세스가 종료를 완료한다.
현재 session에 client가 하나라면 다른 session으로 attach 완료를 확인한 뒤 종료한다.
방문 기록 파일 형식은 이전 Python 버전과 같아 기존 이력을 이어서 쓴다.

## 검증

```sh
cd tuios/picker
go test -race ./...
go vet ./...
```

트리·검색·키·확인창·미리보기 응답·스크롤·좁은 화면과 CLI/Unix socket·종료 대상·방문 이력을 검증한다.
루트의 `python3 -m unittest discover -s tests`는 설치 링크와 런처의 빌드 캐시·공백 경로·소스 갱신을 검증한다.
