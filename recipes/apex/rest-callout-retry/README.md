# A-04: REST Callout with Retry & Circuit Breaker

## Business Scenario

Your Salesforce org integrates with an external payment processor. When the external API goes down, your Apex callouts fail, transactions roll back, and users see cryptic errors. You need callouts that handle failures gracefully — retrying on transient errors and failing fast when the remote service is genuinely down.

This recipe implements the **circuit breaker pattern** in Apex: track consecutive failures, and after a threshold, stop making callouts entirely for a cooldown period. This protects both your org (governor limits) and the external service (thundering herd).

## How It Works

```
Normal State (CLOSED)
    │
    ├── Callout succeeds → reset failure count
    ├── Callout fails (transient) → retry up to N times
    └── Consecutive failures > threshold
            │
            ▼
Circuit OPEN (failing fast)
    │
    ├── All callouts return cached error immediately
    └── After cooldown period expires
            │
            ▼
HALF-OPEN (testing)
    │
    ├── Allow 1 test callout
    ├── If succeeds → back to CLOSED
    └── If fails → back to OPEN
```

## Gotchas

- Apex doesn't have persistent static state across transactions. This implementation uses a Custom Setting (`Circuit_Breaker_State__c`) to persist circuit state. The tradeoff is an extra SOQL query per callout to check state.
- The retry logic uses `HttpRequest` — it doesn't work with named credentials that auto-refresh OAuth tokens. For OAuth, use Named Credentials with the retry layer on top.
- Maximum of 100 callouts per transaction. The retry count eats into that limit.
