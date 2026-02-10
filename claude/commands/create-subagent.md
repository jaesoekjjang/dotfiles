---
description: 대화형으로 커스텀 subagent를 생성합니다
allowed-tools: AskUserQuestion, Read, Write, Glob
---

# Create Subagent

이 커맨드는 대화형으로 커스텀 subagent를 생성합니다.

## Step 1: 기본 정보 수집

AskUserQuestion을 사용하여 다음 질문들을 합니다:

AskUserQuestion({
questions: [
{
header: "이름",
question: "생성할 agent의 이름을 입력하세요 (예: code-reviewer, test-generator, docs-generator)",
type: "text"
},
{
header: "역할",
question: "이 agent의 주요 역할은 무엇인가요?",
type: "single_select",
options: [
"코드 분석 및 리뷰 (코드 품질, 버그, 보안 이슈 분석)",
"탐색 및 조사 (코드베이스 탐색, 정보 수집)",
"리팩토링 (코드 개선, 최적화 제안)",
"테스트 생성 (단위 테스트, 통합 테스트 작성)",
"문서화 (README, API 문서 생성)"
]
},
{
header: "트리거",
question: "이 agent는 언제 자동으로 실행되어야 하나요?",
type: "single_select",
options: [
"코드 변경 후 (코드 작성/수정 완료 시)",
"명시적 요청 시 (사용자가 직접 요청할 때만)",
"커밋 전 (git commit 전에 자동 실행)",
"특정 파일 수정 시 (특정 패턴의 파일 변경 시)"
]
},
{
header: "주요 규칙",
question: "이 agent의 주요 규칙을 입력하세요",
type: "text"
},
{
header: "색상",
question: "UI에서 표시할 색상을 선택하세요",
type: "single_select",
options: [
"blue (분석, 리뷰용)",
"green (생성, 성공 지향 작업용)",
"yellow (검증, 주의용)",
"red (보안, 중요 분석용)",
"purple (탐색, 조사용)",
"orange (리팩토링, 최적화용)",
"pink (테스트, 검증용)",
"brown (문서화, 설명용)",
"gray (기타, 중립용)",
"cyan (파란색, 성공 지향 작업용)"
]
},
{
header: "위치",
question: "agent 파일을 어디에 저장할까요?",
type: "single_select",
options: [
"프로젝트 로컬 (.claude/agents/ - 이 프로젝트에서만 사용)",
"글로벌 (~/.claude/agents/ - 모든 프로젝트에서 사용)"
]
}
]
})

### Agent 파일 생성

수집한 정보로 다음 형식의 파일을 생성:

```markdown
---
name: [선택한 이름]
description: [트리거 조건에 따른 간결한 한 줄 설명]
model: [선택한 모델]
color: [선택한 색상]
tools: [선택한 도구 배열]
---

당신은 [역할에 따른 전문가 설명].

## 트리거 예시

<example>
Context: [상황 설명]
user: "[사용자 요청 예시]"
assistant: "[assistant 응답 방식]"
<commentary>
[이 agent가 트리거되어야 하는 이유]
</commentary>
</example>

<example>
Context: [다른 상황]
user: "[다른 요청 예시]"
assistant: "[응답 방식]"
<commentary>
[트리거 이유]
</commentary>
</example>

**핵심 책임:**
1. [주요 책임 1]
2. [주요 책임 2]

**분석 과정:**
1. [단계 1]
2. [단계 2]

**품질 기준:**
- [품질 기준 1]
- [품질 기준 2]

**출력 형식:**
[출력 형식 설명]

**엣지 케이스:**
- [엣지 케이스 1]: [처리 방법]
- [엣지 케이스 2]: [처리 방법]
```

## Step 2: 추가 질문

지금까지의 답변을 바탕으로 사용자가 추가로 필요로할 맥락을 추론하여 2~3개의 질문을 합니다.

## Step 3: 확인 및 완료

생성된 agent 파일 내용을 사용자에게 보여주고 확인:

AskUserQuestion:

**Question - 확인:**

- header: "확인"
- question: "생성된 agent 설정이 맞나요?"
- options:
  - 예 (저장하고 완료)
  - 아니오 (다시 설정)
  - 수정 (특정 부분만 수정)

"예" 선택 시:

- 파일 저장
- 성공 메시지 출력
- agent 사용 방법 안내

"아니오" 선택 시:

- Step 1부터 다시 시작

"수정" 선택 시:

- 수정할 부분 질문 후 해당 부분만 재설정

## 주의사항

- agent 이름은 소문자, 숫자, 하이픈만 사용 (3-50자)
- description은 간결한 한 줄로 작성 (YAML frontmatter 규칙 준수)
- 트리거 예시는 frontmatter 밖 본문에 포함
- system prompt는 2인칭으로 작성 ("You are...", "You will...")
- 도구 권한은 최소 권한 원칙 적용
