# A-03: Queueable Chain for Large Data Processing

## Business Scenario

You need to process 500K Account records — updating a calculated field, enriching data from an external API, or running complex business logic that can't be handled in a simple batch job. Governor limits cap you at 200 records per DML, 100 SOQL queries, and 6MB heap per execution.

This recipe uses **chained Queueables** to process records in manageable chunks, with each execution queuing the next. It includes progress tracking, error handling, and the ability to pause/resume.

## Architecture

```
Initial Trigger / Scheduled Job
    │
    ▼
ChainableQueueable (chunk 1: records 1-200)
    │  ├── Process 200 records
    │  ├── Log progress to Job_Progress__c
    │  └── System.enqueueJob(next chunk)
    ▼
ChainableQueueable (chunk 2: records 201-400)
    │  ├── Process 200 records
    │  └── System.enqueueJob(next chunk)
    ▼
    ... continues until all records processed ...
    │
    ▼
Final chunk → sends completion notification
```

## Gotchas

- Queueable depth limit: 5 in synchronous context (tests), unlimited in async. Design tests to verify a single chunk, not the full chain.
- If an exception occurs mid-chain, the remaining records won't process. This recipe logs the failure point so you can resume from where it stopped.
- Each chained Queueable is a separate transaction. You can't share state via static variables — use the Custom Object to track progress.
