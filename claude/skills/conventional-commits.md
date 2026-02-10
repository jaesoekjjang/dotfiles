---
name: conventional-commits
description: Use when the user asks about Conventional Commits rules, commit message format, or when referencing commit conventions.
---

# Conventional Commits 규칙

## 형식

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

## Type 종류

| Type | 설명 | 예시 |
|------|------|------|
| `feat` | 새로운 기능 추가 | feat(auth): add login validation |
| `fix` | 버그 수정 | fix(api): resolve null pointer in user service |
| `docs` | 문서 변경 | docs(readme): update installation guide |
| `style` | 코드 포맷팅 (기능 변경 없음) | style(lint): apply prettier formatting |
| `refactor` | 리팩토링 (기능 변경 없음) | refactor(utils): simplify date formatting |
| `test` | 테스트 추가/수정 | test(auth): add login unit tests |
| `chore` | 빌드, 설정 파일 변경 | chore(deps): update package dependencies |
| `perf` | 성능 개선 | perf(query): optimize database queries |
| `ci` | CI/CD 설정 변경 | ci(github): add deploy workflow |
| `build` | 빌드 시스템 변경 | build(webpack): update config for production |
| `revert` | 이전 커밋 되돌리기 | revert: revert "feat(auth): add oauth" |

## 작성 규칙

1. **description**: 50자 이내
2. **현재형 동사**: add, fix, update, remove, refactor 등
3. **소문자 시작**: 첫 글자 대문자 X
4. **마침표 없음**: description 끝에 마침표 X
5. **scope**: 변경된 주요 영역 (컴포넌트명, 폴더명, 모듈명)

## Breaking Changes

호환성이 깨지는 변경:
```
feat(api)!: change authentication flow

BREAKING CHANGE: API endpoint /auth/login now requires OAuth token
```

## 프로젝트 설정 파일 (우선순위)

프로젝트에 다음 파일이 있으면 해당 규칙을 우선 적용:

1. `cz.config.js` / `.cz.config.js` - Commitizen 설정
2. `.czrc` - Commitizen RC 파일
3. `commitlint.config.js` - Commitlint 설정
4. `package.json`의 `config.commitizen` 섹션

## 예시

```bash
# 기능 추가
feat(auth): add JWT token refresh

# 버그 수정
fix(cart): prevent duplicate items

# 문서
docs(api): add endpoint documentation

# 리팩토링
refactor(user): extract validation logic

# 테스트
test(payment): add integration tests

# 설정
chore(eslint): enable strict mode
```
