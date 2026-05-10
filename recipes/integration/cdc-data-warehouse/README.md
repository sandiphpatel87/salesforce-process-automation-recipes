# I-04: Data Warehouse CDC Pipeline

## Business Scenario

Your analytics team needs Salesforce data in Snowflake or BigQuery, refreshed in near real-time. Nightly batch exports miss intraday changes. Full daily extracts are slow and expensive. Change Data Capture (CDC) streams only the changes, but you need to handle schema evolution, deletes, and undelete events.

## Architecture

```
Salesforce Change Data Capture
    │
    ├── AccountChangeEvent
    ├── OpportunityChangeEvent
    └── ContactChangeEvent
    │
    ▼
Apex Trigger on ChangeEvent
    │
    ├── Extract: Changed fields + operation type (CREATE/UPDATE/DELETE/UNDELETE)
    ├── Format: JSON payload with record ID, changed fields, timestamps
    └── Publish: To external message queue
        ├── Option A: Platform Event → Heroku consumer → Snowflake
        ├── Option B: Apex callout → AWS EventBridge → BigQuery
        └── Option C: Kafka Connect (Salesforce CDC connector)
```

## Gotchas

- **CDC object limits**: You can enable CDC on a maximum of 5 custom objects and certain standard objects. Check your org's limits before designing around CDC for everything.
- **Gap detection**: CDC events can be lost if your subscriber is down. Build a reconciliation job that runs daily, compares record counts and last-modified timestamps between Salesforce and the warehouse, and backfills gaps.
- **Delete handling**: CDC sends delete events, but your warehouse needs to handle soft deletes vs hard deletes. Most teams use a `_is_deleted` flag rather than actually removing rows.
- **Field-level changes**: CDC sends only the fields that changed, not the full record. Your warehouse merge logic needs to handle partial updates (MERGE/UPSERT pattern).

## Status

> Architecture documented. Apex CDC trigger and sample consumer coming in a future update.
