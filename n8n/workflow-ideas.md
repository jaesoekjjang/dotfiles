# n8n 워크플로우 아이디어

로컬 n8n + Execute Command + Hammerspoon 알림 기반.

## 현재 구현됨
- [x] Worktree Cleanup (gone branches) — 5분마다 polling

## 개발 워크플로우
- [ ] PR 리뷰 리마인더 — 내가 리뷰어인데 N시간 방치된 PR
- [ ] CI 실패 알림 — 내 브랜치 CI 깨지면 Hammerspoon 알림
- [ ] 의존성 업데이트 감지 — 프로젝트 outdated 주간 리포트

## Linear 연동
- [ ] 방치된 이슈 알림 — In Progress인데 N일 이상 커밋 없는 이슈
- [ ] 주간 업무 서머리

## 시스템/환경
- [ ] dotfiles 자동 커밋 — 변경사항 있을 때만
- [ ] Mac 헬스체크 — brew doctor, 디스크 용량, 좀비 프로세스
- [ ] tmux dead 세션 자동 정리

## 아침 브리핑 강화
- [ ] 기존 Hammerspoon briefing에 n8n 데이터 수집 연동

## Obsidian Vault 관리
- 별도 파일 참고: [obsidian-vault-maintenance.md](obsidian-vault-maintenance.md)

## 지식/학습
- [ ] Raindrop 기억카드 — 저장한 글 랜덤 서피싱 (매일 N개 브리핑에 노출)
- [ ] 스페이스드 리피티션 — 최근 저장은 자주, 오래된 건 간격 늘려서 반복
- [ ] 주제별 묶음 — 특정 태그/컬렉션에서 주기적으로 하나씩

## 자동화 메타
- [ ] n8n 워크플로우 실패 → Hammerspoon 알림 (n8n 내장 Error Workflow 기능 활용, 별도 워크플로우 불필요)
- [ ] 워크플로우 실행 통계 주간 리포트
