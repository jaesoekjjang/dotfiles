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

## 구조

- `internal/tuios`: 공식 CLI와 herdr socket, 표시 행, 화면 캡처, 종료 순서, client별 방문 이력.
  herdr의 workspace/tab을 사용자 관점의 session/workspace로 변환한다.
- `model.go`: 선택·검색·트리·확인창·스크롤 상태와 비동기 작업. 실제 제어와 테스트용 구현 모두 같은 `controller`를 사용한다.
- `view.go`: 반응형 목록/미리보기와 중립색 위계. 캡처의 SGR 색상만 보존하고 OSC·커서 제어는 제거한다.
- `search.go`: 이름·번호 퍼지 검색, 공백 AND, `|` OR, 스마트 대소문자 및 정확·접두·접미·제외 검색.

트리는 한 번 읽어 메모리에서 펼치고 접는다. 변경 작업 후에만 목록을 다시 읽는다.
다른 세션의 빈 workspace는 세션 트리에 넣지 않는다. TUIOS가 마지막으로 선택한 빈 슬롯이나 남아 있는 이름을 실제 workspace로 표시하지 않으며, 빈 세션 행 자체는 유지한다.
세션 검색은 부모의 표시 이름과 workspace 이름·번호를 함께 사용한다. 검색 중에는 펼침 상태에 관계없이 workspace를 찾고 소속을 표시하며, 검색을 지우면 원래 펼침 상태를 복원한다.
`Ctrl-a`는 세션·workspace 모두 이름을 입력받는다. 이름 입력 후 Enter로 생성하면 현재 세션·workspace는 그대로 두고 picker에 남아 검색어를 지운 뒤 새 항목을 선택한다. 새 항목에서 Enter를 누르면 이동한다.
미리보기는 선택 변경·재표시 때 한 번 캡처하며, 짧은 지연으로 빠른 키 반복을 합친다.
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
