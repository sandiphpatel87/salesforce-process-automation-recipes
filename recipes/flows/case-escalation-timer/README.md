# F-03: Case Escalation Timer

## Business Scenario

Your support SLA requires:
- **Priority Critical**: First response within 1 hour, resolution within 4 hours
- **Priority High**: First response within 4 hours, resolution within 8 hours
- **Priority Medium**: First response within 8 hours, resolution within 24 hours

When a case breaches its SLA, you need automatic escalation: reassign to a senior agent, notify the support manager, and update the case priority.

Salesforce Entitlements and Milestones can handle this, but they're complex to set up and maintain. This recipe uses a Scheduled Flow that runs every 15 minutes, checking for SLA breaches and taking action.

## Architecture

```
Scheduled Flow (every 15 minutes)
    │
    ▼
Get: Open Cases with SLA deadlines
    │
    ├── Filter: First_Response_Deadline__c < NOW() AND First_Response_At__c = null
    │   └── Action: Set Escalation_Level__c = 'Response Breach'
    │         ├── Reassign to Escalation Queue
    │         └── Send Slack notification to manager
    │
    ├── Filter: Resolution_Deadline__c < NOW() AND Status != 'Closed'
    │   └── Action: Set Escalation_Level__c = 'Resolution Breach'
    │         ├── Bump Priority up one level
    │         ├── Reassign to senior agent
    │         └── Send email alert to VP of Support
    │
    └── Update all modified cases
```

## Required Custom Fields on Case

| Field | Type | Description |
|-------|------|-------------|
| First_Response_Deadline__c | DateTime | Calculated: CreatedDate + SLA response time |
| Resolution_Deadline__c | DateTime | Calculated: CreatedDate + SLA resolution time |
| First_Response_At__c | DateTime | Stamp when first response is sent |
| Escalation_Level__c | Picklist | None, Warning, Response Breach, Resolution Breach |
| SLA_Breached__c | Checkbox | Formula: First_Response_Deadline < NOW && First_Response_At = null |

## Gotchas

- **Business hours**: The deadlines above use calendar time. For business-hours-only SLAs, use a formula that factors in `BusinessHours.isWithin()` or pre-calculate deadlines in an Apex trigger using the `BusinessHours` class.
- **15-minute granularity**: The scheduled flow checks every 15 minutes, so worst case a breach is detected 14 minutes late. For real-time SLA tracking, use Platform Events triggered from a time-based Flow.
- **Bulk volume**: If you have 10K+ open cases, the scheduled flow's SOQL query needs to be selective. Add an indexed formula field `SLA_At_Risk__c` and filter on it.
