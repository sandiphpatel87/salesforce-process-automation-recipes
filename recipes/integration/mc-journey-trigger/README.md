# I-02: Marketing Cloud Journey Trigger

## Business Scenario

When a Lead hits a certain score or an Opportunity reaches a specific stage, you need to fire a Marketing Cloud journey. The native MC Connect handles basic triggers, but you need conditional logic: only fire for Enterprise accounts, only if the contact hasn't received a campaign email in the last 30 days, only for specific product lines.

## Architecture

```
Salesforce Record Update
    │
    ▼
Record-Triggered Flow (After Update)
    │
    ├── Check: Does this record meet journey criteria?
    │   ├── Lead score > 70 AND Industry = 'Technology'
    │   └── No MC email in last 30 days (check CampaignMember)
    │
    ├── Yes → Invoke Apex: MCJourneyTrigger.fireEvent()
    │   ├── Build API Event payload
    │   ├── POST to MC REST API (via Named Credential)
    │   └── Log result to Journey_Log__c
    │
    └── No → Exit
```

## Gotchas

- **MC API rate limits**: Marketing Cloud's REST API has per-minute rate limits. If a batch update qualifies 500 leads simultaneously, queue the API calls through a Queueable with throttling.
- **Duplicate journey entries**: MC allows a contact to enter the same journey multiple times by default. Set your journey to "re-entry only after exit" unless you explicitly want re-entry.
- **Contact Key alignment**: The Contact Key in MC must match your Salesforce Subscriber Key. Mismatches cause silent failures where the journey fires but the wrong contact (or no contact) receives it.

## Status

> Architecture documented. Apex callout class coming in a future update.
