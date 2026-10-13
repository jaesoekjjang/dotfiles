# TUIOS 커스텀 테마

기본값은 `everforest_light_medium`이다. `setup.zsh`는 JSON 파일을 로컬 TUIOS themes 디렉터리에 연결한다. 테마 선택기에서 이름으로 검색하거나 `tuios set-config theme <이름>`으로 선택한다.

| 이름 | 구성 |
|---|---|
| `sea_shells_deep` | Sea Shells 배경과 포인트 색을 유지하고 본문만 옅은 크림색으로 조정 |
| `kanagawa_light` | Kanagawa Lotus 기반. 기본 글자와 ANSI white를 `#434350`으로 짙게 조정 |
| `noctis_lux` | 원본 Noctis Lux 터미널 팔레트. 따뜻한 크림 배경 |
| `noctis_hibernus` | 원본 Noctis Hibernus 터미널 팔레트. 옅은 청회색 배경 |
| `noctis_lilac` | 원본 Noctis Lilac 터미널 팔레트. 연보라 배경 |
| `everforest_light_hard` | 원본 Everforest light hard. 가장 밝은 배경 |
| `everforest_light_medium` | 원본 Everforest light medium. 기본 밝기 |
| `everforest_light_soft` | 원본 Everforest light soft. 셋 중 가장 어두운 배경 |

## 팔레트 출처

- [Kanagawa Lotus](https://github.com/rebelot/kanagawa.nvim): Lotus 팔레트와 terminal 색 매핑
- [Noctis](https://github.com/liviuschera/noctis/tree/4a82370b2c064e36726c23e94f27ed3782bd6ecd/themes): 공식 테마의 terminal 색
- [Everforest](https://github.com/sainnhe/everforest/blob/85a86eb62409e3ec88713bff3d1b9d7374e112e4/autoload/everforest.vim): light 팔레트. ANSI 색은 같은 커밋의 `colors/everforest.vim` 매핑을 사용

## 색 조정과 적용

본문 글자색은 JSON의 `fg`, 배경은 `bg`다. `#RRGGBB` 형식으로 수정한다.

TUIOS 0.9.2는 이미 등록된 테마를 캐시한다. JSON 수정 후에는 detach하고 다시 연결해서 새 client가 파일을 읽게 한다. RGB 색을 직접 지정하는 앱은 별도 재시작이 필요할 수 있다.

Dotfiles session/workspace picker는 현재 다크 배경용 색을 직접 지정한다. 라이트 테마만 선택해서는 목록과 안내 글자색이 자동으로 바뀌지 않는다.
