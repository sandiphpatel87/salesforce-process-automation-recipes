# AI-04: Email Response Suggestions

## Business Scenario

Support reps spend 5-10 minutes per case drafting email responses. Most responses follow predictable patterns based on the case type, product area, and customer tier. You need an AI assistant that generates contextual reply drafts the rep can review, edit, and send, cutting response time by 60-70%.

## Architecture

```
Rep clicks "Suggest Reply" button on Case
    │
    ▼
LWC Quick Action → Apex Controller
    │
    ├── Gather: Case details (subject, description, priority)
    ├── Gather: Last 5 EmailMessage records on this Case
    ├── Gather: Account tier, Contract status
    ├── Gather: Related Knowledge articles (top 3 by relevance)
    │
    ├── Build: Prompt with conversation history + context
    ├── Call: LLM API
    │
    └── Return: 2-3 draft responses
        ├── Option A: Concise (2-3 sentences)
        ├── Option B: Detailed (with steps)
        └── Option C: Escalation acknowledgment
    │
    ▼
Rep selects, edits, and sends via standard Email action
```

## Gotchas

- **Tone matching**: Include the customer's original email in the prompt so the LLM matches formality level. A frustrated enterprise customer needs a different tone than a casual small-business user.
- **Knowledge grounding**: Always include relevant Knowledge articles in the prompt context. Without grounding, the LLM will generate plausible but potentially incorrect troubleshooting steps.
- **PII in prompts**: Customer emails contain names, account numbers, and sometimes sensitive data. Strip PII before sending to the LLM, or use an endpoint with zero data retention.
- **Approval workflow**: For certain case types (legal, security, compliance), the suggested reply should route through an approval step before sending. Don't let reps send AI-drafted responses on sensitive cases without review.

## Status

> Recipe documented. LWC component and Apex controller coming in a future update.
