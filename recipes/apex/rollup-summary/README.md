# A-02: Bulk-Safe Rollup Summary

## Business Scenario

Salesforce's native rollup summary fields only work on master-detail relationships. But you need rollups on lookup relationships too: total open Cases per Account, sum of Line Item amounts on a custom Quote object, count of completed Tasks per Contact. And it needs to handle bulk updates without hitting governor limits.

## Architecture

```
Child record created/updated/deleted
    │
    ▼
Trigger on Child Object (after insert, update, delete, undelete)
    │
    ▼
RollupService
    ├── Collect: All affected parent IDs from the batch
    ├── Query: Child records grouped by parent
    │   └── SELECT ParentId, COUNT(Id), SUM(Amount) FROM Child GROUP BY ParentId
    ├── Calculate: Rollup values (SUM, COUNT, MIN, MAX, AVG)
    └── Update: Parent records in a single DML
```

## Supported Operations

| Operation | Example |
|-----------|---------|
| COUNT | Number of open Cases per Account |
| SUM | Total Amount of related Line Items |
| MIN | Earliest Task due date |
| MAX | Latest Activity date |
| AVG | Average deal size per Account |

## Gotchas

- **Bulk safety**: The naive approach queries children inside a loop (per parent). This hits SOQL limits at 200 records. Always use aggregate queries with GROUP BY and process all parents in a single DML statement.
- **Delete/undelete**: When a child is deleted, the rollup needs to recalculate. Use `Trigger.old` to get the parent ID on delete operations. Same for undelete.
- **Cross-object field updates**: Updating the parent from a child trigger counts against your DML limit. If the child trigger also updates other objects, you can hit the 150 DML limit in complex orgs.
- **Existing tools**: Before building this, check if DLRS (Declarative Lookup Rollup Summaries) meets your needs. It's a mature open source package. This recipe is for teams that need more control or can't install managed packages.

## Status

> Recipe documented. Source code coming in a future update.
