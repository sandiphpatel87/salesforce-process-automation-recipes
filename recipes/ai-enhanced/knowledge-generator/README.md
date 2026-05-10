# AI-03: Knowledge Article Generator

## Business Scenario

Your support team resolves 200+ cases per week. The best solutions live in case comments and internal notes, but nobody has time to turn them into Knowledge articles. Six months later, a new agent hits the same problem and starts from scratch. You need an automated pipeline that drafts Knowledge articles from resolved case data.

## Architecture

```
Case closed with Resolution = 'Documented Solution'
    │
    ▼
Record-Triggered Flow (After Update)
    │
    ▼
Apex Invocable: KnowledgeGenerator.generate()
    │
    ├── Gather: Case subject, description, comments, internal notes
    ├── Gather: Related cases with similar Subject (SOSL search)
    ├── Deduplicate: Check existing Knowledge articles for overlap
    │
    ├── Call: LLM to draft article
    │   ├── Title (clear, searchable)
    │   ├── Problem statement
    │   ├── Solution steps
    │   └── Related keywords
    │
    └── Create: Knowledge__kav record (Draft status)
        ├── Link to source Case
        └── Assign to Knowledge Manager for review
```

## Gotchas

- **Duplicate articles**: Before creating a new article, search existing Knowledge articles for similar titles and content. The LLM can help with fuzzy matching, but a simple SOSL search catches the obvious duplicates.
- **Quality gate**: Never auto-publish. Always create articles in Draft status and route to a Knowledge Manager for review. The LLM draft is a starting point, not a finished article.
- **Case comment noise**: Case comments contain back-and-forth with the customer, internal debugging notes, and auto-generated text from macros. Your prompt needs to instruct the LLM to extract the solution, not summarize the conversation.

## Status

> Recipe documented. Apex invocable class coming in a future update.
