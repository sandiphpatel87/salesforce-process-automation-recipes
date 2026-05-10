# F-05: Multi-Object Approval with Delegation

## Business Scenario

Your discount approval process involves three levels: manager (up to 15%), director (up to 30%), VP (above 30%). But VPs travel constantly and need to delegate approval authority. And when someone is on vacation, the approval shouldn't sit in a queue for two weeks.

Salesforce's built-in approval process handles simple chains, but it struggles with dynamic delegation, timeout-based re-routing, and approvals that span multiple objects (e.g., approve the Opportunity AND the related Quote).

## Architecture

```
Opportunity submitted for approval
    │
    ▼
Record-Triggered Flow (After Update: Approval_Status__c = 'Submitted')
    │
    ├── Calculate: Required approval level based on discount %
    │
    ├── Check: Is the approver on vacation?
    │   ├── Yes → Route to their configured delegate
    │   └── No → Route to original approver
    │
    ├── Create: Approval_Request__c record
    │   ├── Link to Opportunity
    │   ├── Link to related Quote
    │   └── Set deadline (48 hours)
    │
    └── Notify: Approver via email + Slack
    
Scheduled Flow (every 4 hours)
    │
    ├── Find: Approval_Request__c WHERE Deadline < NOW AND Status = 'Pending'
    └── Action: Escalate to next level or auto-approve based on rules
```

## Required Custom Objects

| Object | Purpose |
|--------|---------|
| Approval_Request__c | Tracks each approval with deadline, approver, delegate, status |
| Approval_Delegation__c | Maps approver → delegate with date ranges |
| Approval_Config__c | Threshold rules per approval type |

## Gotchas

- **Delegation chains**: What if the delegate is also on vacation? Cap the delegation depth at 2 levels. After that, route to a fallback queue.
- **Recall behavior**: If the submitter recalls and re-submits, make sure the old Approval_Request records are marked "Cancelled" so you don't have duplicate pending approvals.
- **Audit trail**: Log every routing decision (original approver, delegate used, timeout escalation) for SOX compliance.

## Status

> Recipe documented. Flow metadata XML and Apex helper classes coming in a future update.
