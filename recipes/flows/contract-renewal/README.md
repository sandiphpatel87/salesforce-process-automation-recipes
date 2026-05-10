# F-04: Contract Renewal Automation

## Business Scenario

Contracts expire. Reps forget. By the time someone notices, the customer is already talking to a competitor. You need a system that automatically creates renewal opportunities 90 days before contract end, assigns them to the account owner, and sends a Slack notification.

## Architecture

```
Scheduled Flow (runs daily at 6 AM)
    │
    ▼
Get: Contracts WHERE EndDate = NEXT_N_DAYS:90
     AND Status = 'Activated'
     AND Renewal_Opportunity_Created__c = false
    │
    ├── Create: Opportunity (Type = 'Renewal')
    │   ├── Amount = Contract.ContractTerm * monthly rate
    │   ├── CloseDate = Contract.EndDate
    │   ├── AccountId = Contract.AccountId
    │   └── OwnerId = Account.OwnerId
    │
    ├── Update: Contract.Renewal_Opportunity_Created__c = true
    │
    └── Send: Notification to Account Owner
```

## Required Custom Fields

| Object | Field | Type |
|--------|-------|------|
| Contract | Renewal_Opportunity_Created__c | Checkbox |
| Contract | Monthly_Rate__c | Currency |
| Opportunity | Source_Contract__c | Lookup(Contract) |

## Gotchas

- **Multi-year contracts**: If a contract is 3 years, you probably don't want to create the renewal opp 90 days before year 1 ends. Add a filter for contracts where `EndDate` is the actual final end date, not an anniversary.
- **Already churned accounts**: Check that the Account status isn't "Churned" or "Inactive" before creating a renewal opp. Otherwise you're creating work for reps on dead accounts.
- **Timezone matters**: The Scheduled Flow runs in the org's default timezone. If your contracts use a specific timezone for end dates, account for the offset.

## Status

> Recipe documented. Flow metadata XML coming in a future update. Contributions welcome.
