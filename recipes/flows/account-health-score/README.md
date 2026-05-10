# F-06: Account Health Score Calculator

## Business Scenario

Your CSM team needs a single number that tells them which accounts are healthy and which are at risk. The score should factor in support case trends, opportunity pipeline, activity recency, contract value, and product adoption. Today they're checking five different reports and making a gut call.

## Architecture

```
Scheduled Flow (runs nightly)
    │
    ▼
Get: All active Accounts
    │
    For each Account:
    ├── Query: Open cases in last 90 days → Case Score (0-25)
    ├── Query: Open opportunities → Pipeline Score (0-25)
    ├── Query: Last activity date → Engagement Score (0-25)
    ├── Query: Active contracts → Revenue Score (0-25)
    │
    ├── Calculate: Total Health Score (0-100)
    ├── Categorize: Healthy (75+), Attention (50-74), At Risk (25-49), Critical (<25)
    │
    └── Update: Account.Health_Score__c, Account.Health_Category__c
```

## Scoring Components

| Component | Weight | Scoring Logic |
|-----------|--------|---------------|
| Case Score | 25 pts | 0 cases = 25, 1-3 = 20, 4-6 = 10, 7+ = 0. Critical cases = -5 each |
| Pipeline Score | 25 pts | Active opps in Negotiation+ = 25, Proposal = 20, Earlier = 10, None = 5 |
| Engagement Score | 25 pts | Activity in last 7 days = 25, 30 days = 20, 60 days = 10, 90+ days = 0 |
| Revenue Score | 25 pts | Based on contract value relative to account tier expectations |

## Gotchas

- **Performance**: Querying Cases, Opportunities, Tasks, and Contracts for every Account in one Flow will hit SOQL limits fast. Batch this with a Queueable chain (see recipe A-03) for orgs with 10K+ accounts.
- **Score drift**: Don't just calculate the score. Store the previous score and the delta. CSMs care more about "this account dropped 20 points this week" than the absolute number.
- **Weighting**: The 25/25/25/25 split is a starting point. Let the business adjust weights via Custom Metadata so they can tune without a deployment.

## Status

> Recipe documented. Apex batch implementation coming in a future update.
