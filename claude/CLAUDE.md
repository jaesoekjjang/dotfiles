# Claude Guide

## Default Mode

- Planning mode should be enabled by default
- Focus on providing detailed analysis, patterns, trade-offs, and architectural guidance

## Permissions

- Always allowed to use `ls`, `cd`, `mkdir`, `git`, `gh`, `npm`, `pnpm` commands freely to navigate the project
- Always allowed to read all files and list all folder structure needed for task completion
- If user modifies a file between reads, assume the change is intentional
- NEVER modify files on your own initiative - only make changes when explicitly requested
- If you notice something that should be modified, ask about it and wait for explicit permission

## Code Style Guidelines

### Typescript and React
    - **Types**: Strict typing, descriptive generics, no implicit any, named prop interfaces
    - **Naming**: Function types use FunctionNameArgs, class options use ClassNameOptions, hook args use UseHookNameArgs, React component props use ComponentNameProps
    - **Error Handling**: Custom error classes, i18n error messages, meaningful error types
    - **Components**: One component per file, functional components with hooks
    - **Type organization**: Don't create `index.ts` files in `types` directories to re-export types, import directly from individual type files
    - **Comments**:
      - Use minimal comments
      - Add comments only when code clarity is insufficient or to explain non-standard solutions (like using `any`) or hard to read / understand code sections

## Communication Style

- When asking questions, always provide multiple numbered options when appropriate:

  - Format as a numbered list: `1. Option one, 2. Option two, 3. Option three`
  - Example: `1. Yes, continue with the changes, 2. Modify the approach, 3. Stop and cancel the operation`

- When analyzing code for improvement:

  - Present multiple implementation variants as numbered options
  - For each variant, provide at least 3 bullet points explaining the changes, benefits, and tradeoffs

- answer in Korean even if the question is in English

## Code Style Consistency

- ALWAYS respect how things are written in the existing project
- STRICTLY follow the existing style of tests, resolvers, functions, and arguments
- Before creating a new file, ALWAYS examine a similar file and follow its style exactly
- Use less comments and more descriptive variable names. Coment if the code is not self-explanatory.
- Follow the exact format of error handling, variable naming, and code organization used in similar files

## Code Documentation and Comments

When working with code that contains comments or documentation:

1. Carefully follow all developer instructions and notes in code comments
2. Explicitly confirm that all required steps from comments have been completed
3. Automatically execute all mandatory steps mentioned in comments without requiring additional reminders
4. Pay special attention to comments marked as "IMPORTANT", "NOTE", or with similar emphasis
5. Do not remove or alter any comments unless explicitly instructed to do so

This applies to both code-level comments and documentation in separate files. Comments within the code are binding instructions that must be followed.

## Git 
- commit after each task.
- Do not write 'claude-code' related things(like "co-authored by claude-code") in commit messages.
