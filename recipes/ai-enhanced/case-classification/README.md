# AI-01: Case Auto-Classification

## Business Scenario

Your support org receives 500+ cases per day. Reps spend 2-3 minutes per case just reading the subject and description to figure out the product area, urgency level, and required skill set. That's 25+ hours per day of triage time that could be automated.

This recipe uses an LLM (via Salesforce-to-API callout) to analyze incoming case content and automatically:
1. Classify the product area
2. Assess urgency level
3. Detect sentiment (angry, frustrated, neutral)
4. Suggest the best routing queue
5. Draft an initial internal note for the assigned agent

## Architecture

```
New Case Created
    │
    ▼
Record-Triggered Flow (After Insert)
    │
    ▼
Apex Invocable Action: CaseClassifier.classify()
    │
    ├── Build prompt from Case subject + description
    ├── Call LLM API (via Named Credential)
    ├── Parse structured JSON response
    └── Update Case fields:
        ├── Product_Area__c
        ├── AI_Urgency__c
        ├── AI_Sentiment__c
        ├── AI_Routing_Suggestion__c
        └── AI_Internal_Note__c
```

## Gotchas

- **Callout from trigger**: You can't make HTTP callouts from a synchronous trigger. The Flow fires a Platform Event or uses a Queueable to make the callout asynchronously. The case fields update 1-2 seconds after creation.
- **Cost control**: Each classification costs one LLM API call. For high-volume orgs, consider batching cases every 5 minutes instead of real-time classification.
- **Prompt engineering**: The classification quality depends entirely on your prompt. Include your actual product areas, queue names, and escalation criteria in the system prompt. Update it as products change.
- **Fallback**: If the LLM API is down or returns garbage, the case should still be created with a default classification. Never block case creation on AI classification.
