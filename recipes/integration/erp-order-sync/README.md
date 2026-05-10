# I-01: Salesforce to ERP Order Sync

## Business Scenario

When an Opportunity closes in Salesforce, an order needs to be created in your ERP system (SAP, NetSuite, Oracle). When the ERP updates the order status or invoice, that needs to flow back to Salesforce. Bidirectional sync with conflict resolution, retry logic, and audit logging.

## Architecture

```
Salesforce (Opportunity Closed Won)
    │
    ├──► Platform Event: Order_Sync_Event__e
    │        ├── Opportunity data
    │        └── Line items
    │
    ▼
Middleware / Apex Callout
    │
    ├──► ERP REST API: Create Order
    │        ├── Map SF fields → ERP fields
    │        ├── Retry with circuit breaker (see A-04)
    │        └── Log response
    │
    ◄── ERP Webhook: Status Update
    │        ├── Order shipped / invoiced / cancelled
    │        ├── Upsert to SF via External ID
    │        └── Update Opportunity.ERP_Status__c
    │
    └── Conflict Resolution
         ├── Last-write-wins with timestamp comparison
         └── Alert on conflicts for manual review
```

## Gotchas

- **Idempotency**: ERP calls must be idempotent. Use the Salesforce Opportunity ID as the ERP external reference. If the same order is sent twice, the ERP should update, not duplicate.
- **Field mapping drift**: ERP schemas change. Version your field mappings and log the mapping version with each sync so you can debug issues from 3 months ago.
- **Partial failures**: An order with 10 line items might succeed on 8 and fail on 2. Your sync needs to handle partial success and report which items failed.

## Status

> Architecture documented. Source code coming in a future update.
