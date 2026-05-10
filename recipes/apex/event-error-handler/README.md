# A-06: Platform Event Error Handler

## Business Scenario

You're using Platform Events for async processing. A subscriber trigger fails on record 47 of 200. Salesforce retries the entire batch, and now records 1-46 get processed twice. Or worse, the retry fails again and the events are lost. You need graceful error handling that processes what it can, logs what it can't, and doesn't duplicate work.

## Architecture

```
Platform Event Published
    │
    ▼
Apex Trigger on MyEvent__e
    │
    ▼
EventErrorHandler
    ├── Track: EventBus.TriggerContext.currentContext().retries
    ├── Process each event in try/catch
    │   ├── Success → mark processed
    │   └── Failure → log to Event_Error__c
    │       ├── Event payload (JSON)
    │       ├── Error message + stack trace
    │       └── Retry count
    ├── Use: EventBus.TriggerContext.currentContext().setResumeCheckpoint()
    │   └── On retry, skip already-processed events
    └── If max retries exceeded → dead letter queue
```

## Gotchas

- **setResumeCheckpoint()**: This is the key method. It tells Salesforce where to resume if the trigger fails. Without it, the entire batch gets replayed from the beginning.
- **Idempotency**: Even with checkpoints, design your subscriber to be idempotent. Check if the record was already created/updated before doing it again. Use an external ID or event replay ID as a dedup key.
- **Governor limits**: Each Platform Event trigger invocation is a separate transaction with its own limits. But if you're processing 200 events and each one does a callout, you'll hit the 100-callout limit. Batch your callouts or use Queueable chaining.

## Status

> Recipe documented. Source code coming in a future update.
