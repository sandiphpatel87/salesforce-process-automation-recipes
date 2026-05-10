# I-03: Slack Notification Engine

## Business Scenario

Your sales team lives in Slack. They want instant notifications when:
- A deal over $100K advances to "Negotiation"
- A case is escalated to "Critical"
- A new enterprise lead comes in from the website
- A contract renewal is 30 days out

Email notifications get buried. Chatter posts require switching to Salesforce. You need a configurable engine that sends rich Slack messages based on Salesforce events.

## Architecture

```
Salesforce Record Change
    │
    ▼
Platform Event: Notification_Event__e
    │
    ├── Event_Type__c: "OPP_STAGE_CHANGE"
    ├── Record_Id__c: "006xxx..."
    ├── Payload__c: JSON with relevant fields
    └── Channel__c: "#deals-pipeline"
    │
    ▼
Apex Trigger on Notification_Event__e
    │
    ├── Build Slack Block Kit message
    ├── Get webhook URL from Named Credential
    └── POST to Slack Incoming Webhook
```

## Gotchas

- **Slack rate limits**: 1 message per second per webhook. If you're sending 50 notifications from a batch update, queue them through a Queueable with delays.
- **Named Credentials**: Store the Slack webhook URL in a Named Credential, not hardcoded. This lets admins rotate webhooks without a code deployment.
- **Message formatting**: Use Slack's Block Kit for rich messages with buttons, fields, and links. Plain text messages get ignored by users.
