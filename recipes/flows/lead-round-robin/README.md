# F-01: Lead Assignment with Round Robin

## Business Scenario

You have 8 sales reps and need to distribute inbound leads evenly. The twist: reps are in different timezones, some are on vacation, and marketing wants certain lead sources (e.g., "Partner Referral") to go to specific reps regardless of the round robin.

Built-in Salesforce lead assignment rules can't do this cleanly. You need a Flow-based solution that:
1. Checks rep availability (out-of-office, capacity limits)
2. Respects source-based routing overrides
3. Distributes remaining leads in true round robin order
4. Tracks the current position in the rotation

## Architecture

```
New Lead Created
    │
    ▼
Record-Triggered Flow (After Insert)
    │
    ├── Check: Source-based override?
    │   ├── Yes → Assign to designated rep
    │   └── No → Continue to round robin
    │
    ├── Get: Active reps from Lead_Assignment_Queue__c
    │   └── Filter: Is_Available__c = true, Active__c = true
    │
    ├── Get: Current rotation position from Round_Robin_State__c
    │
    ├── Calculate: Next rep in rotation
    │   └── (current_position + 1) MOD active_rep_count
    │
    ├── Update: Lead.OwnerId = selected rep
    │
    └── Update: Round_Robin_State__c.Current_Position
```

## Required Custom Objects

### `Lead_Assignment_Queue__c`
| Field | Type | Description |
|-------|------|-------------|
| Rep_User__c | Lookup(User) | The sales rep |
| Is_Available__c | Checkbox | Currently available for assignment |
| Active__c | Checkbox | Active in the rotation |
| Sort_Order__c | Number | Position in rotation order |
| Source_Override__c | Text | Lead sources that route directly here |
| Daily_Capacity__c | Number | Max leads per day (optional) |
| Leads_Today__c | Number | Counter reset nightly by Scheduled Flow |

### `Round_Robin_State__c`
| Field | Type | Description |
|-------|------|-------------|
| Queue_Name__c | Text | Identifier for this rotation |
| Current_Position__c | Number | Current position in the rotation |
| Last_Assigned_At__c | DateTime | Timestamp of last assignment |

## Setup Steps

1. Create the two custom objects above
2. Populate `Lead_Assignment_Queue__c` with your sales reps
3. Create one `Round_Robin_State__c` record with `Queue_Name__c = 'Default'` and `Current_Position__c = 0`
4. Import the Flow metadata XML below
5. Activate the Flow
6. Test with a new Lead

## Gotchas

- **Race condition**: If two leads are created simultaneously, they may both read the same `Current_Position` and route to the same rep. For low volume (under 100 leads/day), this is rarely an issue. For high volume, use an Apex trigger with `FOR UPDATE` locking instead.
- **Vacation coverage**: When a rep goes on vacation, set `Is_Available__c = false`. The rotation skips them automatically. When they return, they resume their position — they don't get a backlog dump.
- **New reps**: Add them to `Lead_Assignment_Queue__c` with the next `Sort_Order__c`. They'll enter the rotation naturally.

## Test Scenarios

1. Create 8 leads in sequence → each should go to a different rep
2. Mark a rep as unavailable → leads should skip them
3. Create a lead with `LeadSource = 'Partner Referral'` → should go to designated rep, not round robin
4. Create 20 leads rapidly → distribution should be roughly even (within ±1)
