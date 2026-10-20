# Dotfiles

macOS용 zsh + Ghostty + AeroSpace + tmux/workmux + TUIOS + Neovim + Yazi 설정.

Ghostty의 새 창·탭·Quick Terminal은 `tuios attach`로 최근 세션에 연결한다. 저장된 세션이 없으면 새 세션을 열고, tuios가 설치되지 않은 환경에서는 zsh로 시작한다. 기존 Ghostty에는 `Cmd+Shift+,`로 설정을 다시 읽힌 뒤 새 창을 연다.

## 새 Mac에서 설치

1. `./install.zsh` → `./setup.zsh`를 실행한다.
2. `dotfiles-doctor`로 설치·설정 상태를 확인한다.

`install.zsh --cli-only`는 데스크톱 앱/폰트를 제외하고,
`--no-agents`는 agent CLI와 Codex TUIOS hook 설치를 제외한다.
Haskell·OCaml·C++·Rust 도구는 `--with-languages`로 추가한다.

Homebrew의 외부 tap 신뢰는 workmux·AeroSpace·JankyBorders 세 패키지에만 부여한다.

## 기존 Mac 동기화

저장소 디렉터리에서 실행한다. 로컬 변경이 있다면 먼저 커밋하거나 별도로 보관한다.

```sh
git status --short
git pull --ff-only
./install.zsh                 # 기존 설치 옵션(--cli-only 등)이 있으면 동일하게 사용
./setup.zsh --refresh-tuios   # 로컬 TUIOS 설정을 백업하고 저장소 설정으로 갱신
bin/tuios-picker --build
bin/dotfiles-doctor
```

TUIOS 설정은 로컬 복사본이므로 pull만으로 단축키와 hook이 갱신되지 않는다.
`--refresh-tuios`는 이 PC에서 따로 바꾼 TUIOS 설정도 저장소 버전으로 교체한다.
기존 설정은 `~/.local/state/dotfiles-backups/`에서 확인할 수 있다.
TUIOS pane 밖의 터미널에서 `tuios config apply` 후 `tuios attach`로 다시 연결한다.
실행 중인 daemon의 버전은 패키지 업데이트만으로 바뀌지 않으므로, 버전 변경 시에는 진행 중인 작업을 정리한 뒤 TUIOS를 재시작한다.
zsh는 새로 열어 설정을 읽힌다. Neovim에서는 `:Lazy restore`로 lockfile에 맞춰 플러그인을 복원한 뒤 재시작한다.

picker 바이너리는 각 PC에서 Go로 빌드하며 저장소에 넣지 않는다.
프로젝트/worktree 후보와 세션 방문 기록은 각 PC의 로컬 상태를 사용한다.
개인 경로·비밀정보는 아래 로컬 설정 파일에 유지한다.

## 설정과 로컬 변경

`setup.zsh`는 기존 파일을 `~/.local/state/dotfiles-backups/`에 백업하고 연결한다.
환경 override는 `~/.zshenv.local`, 비밀정보는 권한 0600의 `~/.secrets.zsh`,
Git 이름·이메일 등 개인 설정은 `~/.gitconfig.local`에 둔다.

TUIOS 설정은 `~/Library/Application Support/tuios/config.toml`의 **로컬 복사본**이다.
설정 화면에서 변경해도 저장소를 수정하지 않는다. 기존 링크는 현재 내용을 보존해 로컬 파일로 전환한다.
저장소의 TUIOS 설정을 다시 적용하려면 `setup --refresh-tuios`를 실행한다. 기존 로컬 파일은 백업한다.
로컬 변경을 저장소에 반영하려면 먼저 다음 diff를 검토하고 필요한 변경만 옮긴다.

```sh
git diff --no-index -- tuios/config.toml "$HOME/Library/Application Support/tuios/config.toml"
```

## Workflow

- `wt`: [TUIOS 프로젝트 세션](tuios/README.md)
- Neovim: [검색·편집·Git 단축키](nvim/README.md)
- Yazi: [복사·탐색·압축](yazi/README.md)
- `dotfiles-doctor --json`: 읽기 전용 진단 결과. CLI/agent 제외 옵션은 installer와 같다.
