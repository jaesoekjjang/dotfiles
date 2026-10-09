# Dotfiles

macOS용 zsh + Ghostty + AeroSpace + tmux/workmux + TUIOS + Neovim + Yazi 설정.

## 새 Mac에서 설치

1. `./install.zsh` → `./setup.zsh`를 실행한다.
2. `dotfiles-doctor`로 설치·설정 상태를 확인한다.

`install.zsh --cli-only`는 데스크톱 앱/폰트를 제외하고,
`--no-agents`는 agent CLI와 Codex TUIOS hook 설치를 제외한다.
Haskell·OCaml·C++·Rust 도구는 `--with-languages`로 추가한다.

Homebrew의 외부 tap 신뢰는 workmux·AeroSpace·JankyBorders 세 패키지에만 부여한다.

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

- `w`: [tmux/workmux 프로젝트·worktree·agent 메뉴](workmux/README.md)
- `wt`: [TUIOS 프로젝트 세션](tuios/README.md)
- Neovim: [검색·편집·Git 단축키](nvim/README.md)
- Yazi: [복사·탐색·압축](yazi/README.md)
- `dotfiles-doctor --json`: 읽기 전용 진단 결과. CLI/agent 제외 옵션은 installer와 같다.
