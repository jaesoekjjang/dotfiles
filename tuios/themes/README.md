# TUIOS 커스텀 테마

기본값은 `rose_pine_dawn_official`이다. `setup.zsh`는 JSON 파일을 로컬 TUIOS themes 디렉터리에 연결한다. 테마 선택기에서 이름으로 검색하거나 `tuios set-config theme <이름>`으로 선택한다.

## Light/Dark 분리 선택기

`prefix → Ctrl+t`로 `tuios-theme-picker`를 연다. 현재 테마와 같은 밝기 그룹으로 시작하며, 이름을 입력해 검색하고 방향키로 미리본다. Tab은 Light/Dark 그룹을 전환하고, Enter는 선택을 로컬 설정에 저장하며, Esc는 열기 전 테마를 복원한다. 목록은 이름순으로 유지하며, 열면 현재 테마 위치에 커서를 둔다. 테마를 적용한 뒤 다시 열어도 바로 다음 테마부터 탐색할 수 있다.

즐겨찾기는 `Ctrl+F`로 추가·해제하며 목록에 `★`로 표시한다. `Ctrl+G`는 현재 Light/Dark 그룹의 전체 목록과 즐겨찾기만 보기를 전환한다. 즐겨찾기 갱신과 전체/즐겨찾기 전환은 선택기를 닫지 않고 목록만 갱신한다. 목록은 이름순을 유지하며 검색어와 커서 위치를 이어간다. 즐겨찾기는 Dotfiles의 `tuios/theme-favorites.json`에 저장하므로, 같은 iCloud Dotfiles를 사용하는 기기끼리 공유한다. 각 기기의 기존 `${XDG_CONFIG_HOME:-~/.config}/tuios/theme-favorites.json`은 첫 실행 때 한 번 합치며 원본은 백업으로 남긴다 (`theme-favorites.migrated`가 재이관을 방지한다). Esc로 테마 미리보기를 취소해도 즐겨찾기 변경은 유지한다. 다른 기기의 변경은 iCloud 동기화 후 선택기를 다시 열면 반영된다. 별도 Git checkout은 이 파일도 Git으로 전달해야 하며, 여러 기기에서 동시에 수정하면 마지막 저장이 우선할 수 있다. 저장 위치는 `TUIOS_THEME_FAVORITES`로 재정의할 수 있다.

`tuios-theme-picker light` 또는 `tuios-theme-picker dark`로 그룹을 직접 지정할 수도 있다. 분류는 이름에 light/dark가 있는지 대신 TUIOS가 반환하는 실제 팔레트의 `dark` 값을 사용한다. 미리보기에는 파일을 저장하지 않는 `SetTheme` 명령을 쓰고, 확정할 때만 설정 API를 호출한다. Settings 안의 내장 선택기는 기존 동작을 유지한다. fzf가 필요하다.

| 이름 | 구성 |
|---|---|
| `sea_shells_deep` | Sea Shells 배경과 포인트 색을 유지하고 본문만 옅은 크림색으로 조정 |
| `kanagawa_light` | Kanagawa Lotus 기반. 기본 글자와 ANSI white를 `#434350`으로 짙게 조정 |
| `kanagawa_dragon` | Kanagawa Dragon 공식 터미널 팔레트. Neovim fallback과 같은 계열 |
| `noctis_lux` | 원본 Noctis Lux 터미널 팔레트. 따뜻한 크림 배경 |
| `noctis_hibernus` | 원본 Noctis Hibernus 터미널 팔레트. 옅은 청회색 배경 |
| `noctis_lilac` | 원본 Noctis Lilac 터미널 팔레트. 연보라 배경 |
| `flexoki_light` | 공식 Flexoki Light 터미널 팔레트. 옅은 종이색 배경과 짙은 글자 |
| `kami_light` | KKenny0/obsidian-kami의 라이트 CSS 색을 터미널용으로 매핑. 양피지색 배경과 잉크색 글자 |
| `monokai_pro_light` | Monokai Pro Light 터미널 포트. 옅은 분홍빛 배경과 짙은 글자 |
| `monokai_pro_light_sun` | Monokai Pro Light Sun 터미널 포트. 따뜻한 크림 배경과 짙은 글자 |
| `dawnfox` | Nightfox 라이트. 따뜻한 미색 배경과 보라빛 회색 글자 |
| `dayfox` | Nightfox 라이트. 따뜻한 회백색 배경과 짙은 보라색 글자 |
| `nightfox` | Nightfox 기본 다크. 짙은 남색 배경 |
| `duskfox` | Nightfox 다크. 보라색 배경과 Rose Pine 계열 포인트 |
| `nordfox` | Nightfox 다크. Nord 계열 청회색 |
| `terafox` | Nightfox 다크. 짙은 청록색 배경 |
| `carbonfox` | Nightfox 다크. 거의 검정인 배경과 선명한 포인트 |
| `kanso_pearl` | Kanso 공식 Pearl 터미널 팔레트. 따뜻한 회백색 배경과 짙은 글자 |
| `biscuit_mar_light` | Biscuit de Mar Light Base16 팔레트. 크림 배경과 갈색 글자 |
| `papercolor_light` | PaperColor 공식 16색 팔레트. 연회색 배경과 짙은 회색 글자 |
| `rose_pine_dawn` | TUIOS 내장 테마. 별도 JSON 없이 선택 가능 |
| `rose_pine_dawn_official` | 공식 Rose Pine Dawn 터미널 팔레트. 배경 `#faf4ed`, 글자·cursor `#575279` |
| `everforest_light_hard` | Everforest light hard. 가장 밝은 배경; 8번 색은 보조 회색 |
| `everforest_light_medium` | Everforest light medium. 기본 밝기; 8번 색은 보조 회색 |
| `everforest_light_soft` | Everforest light soft. 배경 유지, 본문·ANSI black은 `#4d5a62`, cursor는 `#3e4a51`; 8번 색은 보조 회색 |

| `gruvbox_dark_soft` | Gruvbox Dark Soft. 배경 `#32302f`, 본문 `#ebdbb2` |
| `gruvbox_light_hard` | Gruvbox Light Hard. 배경 `#f9f5d7`, 본문 `#282828` |
| `gruvbox_light_soft` | Gruvbox Light Soft. 배경 `#f2e5bc`, 본문 `#282828` |
| `gruvbox_material_dark_hard` | Gruvbox Material Dark Hard. 배경 `#1d2021`, 본문 `#d4be98` |
| `gruvbox_material_dark_medium` | Gruvbox Material Dark Medium. 배경 `#282828`, 본문 `#d4be98` |
| `gruvbox_material_dark_soft` | Gruvbox Material Dark Soft. 배경 `#32302f`, 본문 `#d4be98` |
| `gruvbox_material_light_hard` | Gruvbox Material Light Hard. 배경 `#f9f5d7`, 본문 `#654735` |
| `gruvbox_material_light_medium` | Gruvbox Material Light Medium. 배경 `#fbf1c7`, 본문 `#654735` |
| `gruvbox_material_light_soft` | Gruvbox Material Light Soft. 배경 `#f2e5bc`, 본문 `#654735` |

일반 Gruvbox의 medium은 내장 `gruvbox_light` / `gruvbox_dark`이고, Dark Hard도 내장 `gruvbox_dark_hard`를 사용한다. 두 계열 모두 Light/Dark에 hard·medium·soft 변형이 있다. Light의 hard는 가장 밝은 배경, Dark의 hard는 가장 어두운 배경으로 대비를 높인다. Material은 기본 `material` foreground 팔레트를 사용하며, 별도의 `mix` / `original` 색상 변형은 포함하지 않는다.

## 팔레트 출처

- [Gruvbox Material 공식 팔레트](https://github.com/sainnhe/gruvbox-material/blob/11d779b26a9ab2b3db8c22c6ac9fb6e8ed4fea79/autoload/gruvbox_material.vim)와 [터미널 매핑](https://github.com/sainnhe/gruvbox-material/blob/11d779b26a9ab2b3db8c22c6ac9fb6e8ed4fea79/colors/gruvbox-material.vim): Light/Dark × hard/medium/soft 6종. Normal 배경·본문과 ANSI 16색을 추출하고 cursor는 본문색을 사용한다.
- [Gruvbox 공식 대비 배경](https://github.com/morhetz/gruvbox/blob/ef8864bb42bf244f0295d1c5a403b27e3d139695/colors/gruvbox.vim): 일반 Gruvbox 추가 3종은 기존 TUIOS 내장 팔레트의 본문·ANSI 색을 유지하고 공식 hard/soft 배경과 ANSI black만 변경한다.

- [Kanagawa Lotus](https://github.com/rebelot/kanagawa.nvim): Lotus 팔레트와 terminal 색 매핑
- [Kanagawa Dragon](https://github.com/rebelot/kanagawa.nvim/blob/debe91547d7fb1eef34ce26a5106f277fbfdd109/extras/ghostty/kanagawa-dragon): 현재 설치된 플러그인의 공식 Ghostty 배경·글자·cursor·ANSI 16색
- [Noctis](https://github.com/liviuschera/noctis/tree/4a82370b2c064e36726c23e94f27ed3782bd6ecd/themes): 공식 테마의 terminal 색
- [Everforest](https://github.com/sainnhe/everforest/blob/85a86eb62409e3ec88713bff3d1b9d7374e112e4/autoload/everforest.vim): light 팔레트. ANSI 색은 같은 커밋의 `colors/everforest.vim` 매핑을 사용

- [Flexoki Light](https://github.com/kepano/flexoki/blob/8d723bac4a9ac46adfdf99d42155286977aac72a/alacritty/flexoki-light.toml): 공식 터미널 팔레트
- [Kami Reader](https://github.com/KKenny0/obsidian-kami/blob/12cd7169c45d0525858ff728e8b78b516324f399/theme.css): 실제 light CSS의 배경·본문·강조·상태·syntax 색을 ANSI 슬롯에 매핑. 원본에는 터미널 팔레트가 없으며, 서체·행간·Obsidian 레이아웃은 이식하지 않는다

- [Monokai Pro Ghostty 포트](https://github.com/kirlovon/monokai-ghostty/tree/7870015f6eb55797f3964bdcdbb3fc575bd39089): Light와 Light Sun의 ANSI 16색·기본 글자·배경·cursor 색을 그대로 사용. 선택 영역 색과 Ghostty 전용 옵션은 포함하지 않는다.

## 색 조정과 적용

추가한 테마의 출처:

- [Nightfox 공식 Alacritty 팔레트](https://github.com/EdenEast/nightfox.nvim/tree/main/extra): 7종의 기본 글자·배경·cursor·ANSI 16색을 그대로 사용한다. dim 색, 선택 영역, 확장 색은 TUIOS JSON에 포함하지 않는다.
- [Kanso 팔레트](https://github.com/webhooked/kanso.nvim/blob/main/lua/kanso/colors.lua)와 [Pearl 매핑](https://github.com/webhooked/kanso.nvim/blob/main/lua/kanso/themes.lua): 기본 foreground 모드의 UI 색과 terminal 0–15 슬롯을 사용한다.
- [Biscuit de Mar Light](https://github.com/Biscuit-Theme/biscuit/blob/main/biscuit-mar-light-base16.yaml): Base16을 ANSI 슬롯에 매핑한다. normal은 base00/08/0B/0A/0D/0E/0C/05, bright는 base03/08/0B/0A/0D/0E/0C/07이다. cursor는 본문 base05를 사용한다.
- [PaperColor 공식 팔레트](https://github.com/NLKNguyen/papercolor-theme#-colors): Light Theme의 0–15 슬롯을 그대로 사용한다. 배경은 color0, 본문과 cursor는 color7이다. 원본 슬롯의 색 이름과 실제 색조가 다를 수 있다.

Everforest 라이트 3종의 `bright_black`(ANSI 8번)은 원본의 `grey1` 색인 `#939f91`로 조정했다. zsh 자동완성의 기본 `fg=8`과 본문 색이 구분되도록 한 변경이며, hard/medium의 다른 ANSI 색과 본문 색은 유지한다. soft는 긴 글 가독성을 위해 본문과 ANSI black을 `#4d5a62`로 짙게 조정했다.

본문 글자색은 JSON의 `fg`, 배경은 `bg`다. `#RRGGBB` 형식으로 수정한다.

TUIOS 0.9.2는 이미 등록된 테마를 캐시한다. JSON 수정 후에는 detach하고 다시 연결해서 새 client가 파일을 읽게 한다. RGB 색을 직접 지정하는 앱은 별도 재시작이 필요할 수 있다.

Dotfiles session/workspace picker는 열릴 때 터미널 배경색을 조회해 라이트·다크 글자색을 자동 선택한다. 선택 행 배경도 실제 배경색에서 만든다. pane 미리보기의 원본 색은 유지한다.

- [Rose Pine Dawn 공식 Ghostty 포트](https://github.com/rose-pine/ghostty/blob/79d71a7c07f87281570a76256c6bcbc154dd202d/dist/rose-pine-dawn): 배경·글자·cursor·ANSI 16색을 그대로 사용한다. TUIOS JSON이 지원하지 않는 cursor-text와 selection 색은 포함하지 않는다.

- `zenbones_light_dim`: [Zenbones](https://github.com/zenbones-theme/zenbones.nvim/tree/8304d8df9b823ff11e103afa62f38c39f534abe6)의 공식 `lightness = "dim"`으로 생성한 Normal 배경·본문, Cursor 및 terminal 0–15 색. Neovim도 같은 dim 옵션으로 연동되며 기본 Zenbones로 전환하면 dim을 해제한다.
