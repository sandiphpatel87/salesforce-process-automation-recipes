# AI-02: Opportunity Win/Loss Analysis

## Business Scenario

Your sales VP wants to understand why deals are won or lost. Today, reps fill in a "Close Reason" picklist (when they remember), and it's usually "Price" or "Competitor" regardless of the actual reason. You need an AI-powered analysis that reads the opportunity history, related activities, emails, and notes to generate a real narrative of what happened.

## Architecture

```
Opportunity marked Closed (Won or Lost)
    │
    ▼
Record-Triggered Flow (After Update: IsClosed = true)
    │
    ▼
Apex Invocable: WinLossAnalyzer.analyze()
    │
    ├── Gather: Opportunity field history
    ├── Gather: Related Tasks, Events, Emails
    ├── Gather: Competitor records
    ├── Gather: Stage duration analysis
    │
    ├── Build: Context prompt with all data
    ├── Call: LLM API for narrative analysis
    │
    └── Update:
        ├── Win_Loss_Narrative__c (rich text, 2-3 paragraphs)
        ├── Key_Factors__c (comma-separated)
        ├── Competitor_Impact__c (text)
        └── Lessons_Learned__c (text)
```

## Gotchas

- **Email access**: EmailMessage records are only available if Email-to-Case or Einstein Activity Capture is enabled. Without emails, the analysis loses a major signal source.
- **Privacy**: The LLM prompt will contain customer names, deal amounts, and internal notes. Make sure your LLM provider's data retention policy is compatible with your security requirements. Use a zero-data-retention endpoint if available.
- **Bias calibration**: LLMs tend to over-attribute losses to price. Include explicit instructions in your prompt to consider relationship factors, timing, product gaps, and competitive positioning equally.

## Status

> Recipe documented. Apex invocable class coming in a future update.
