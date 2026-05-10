# F-02: Opportunity Stage Validation

## Business Scenario

Sales reps keep advancing opportunities to "Negotiation" without filling in key fields like `Decision_Maker__c`, `Budget_Confirmed__c`, or `Technical_Validation_Date__c`. Your sales VP wants hard gates: you can't move to the next stage until the required fields for the current stage are complete.

Validation rules can enforce "field X is required when Stage = Y," but they fire on every save — even if the rep is just updating the description. You want validation that only fires **when the stage is changing forward**, and shows a clear error message listing exactly which fields are missing.

## Architecture

```
Opportunity Update
    │
    ▼
Record-Triggered Flow (Before Update)
    │
    ├── Check: Did StageName change?
    │   └── No → Exit (no validation needed)
    │
    ├── Check: Is this a forward stage move?
    │   └── Backward moves (e.g., Negotiation → Discovery) are always allowed
    │
    ├── Get: Stage gate requirements from Stage_Gate__mdt
    │   └── Custom Metadata maps each stage to required fields
    │
    ├── Check: Are all required fields populated?
    │   ├── Yes → Allow the save
    │   └── No → Add fault message listing missing fields
    │
    └── Display: "Cannot advance to [Stage]. Missing: Field A, Field B"
```

## Custom Metadata: `Stage_Gate__mdt`

| Label | Stage_Name | Required_Fields | Error_Message |
|-------|-----------|----------------|---------------|
| Qualification Gate | Qualification | Budget_Range__c, Timeline__c | Please confirm budget range and timeline |
| Discovery Gate | Discovery | Decision_Maker__c, Pain_Points__c | Identify the decision maker and document pain points |
| Proposal Gate | Proposal/Price Quote | Technical_Validated__c, Proposal_Sent_Date__c | Complete technical validation before sending proposal |
| Negotiation Gate | Negotiation/Review | Contract_Value__c, Legal_Review__c | Contract value and legal review are required |

## Why Custom Metadata (not Validation Rules)

- **Configurable by admins** — no deployment needed to change stage requirements
- **Stage-aware** — only fires on forward moves, not every save
- **Clear messaging** — lists exactly which fields are missing, not a generic error
- **Bulk-safe** — the Flow handles bulk updates correctly

## Gotchas

- Define your stage order explicitly (Custom Metadata or picklist position). Don't rely on picklist alphabetical order.
- This pattern blocks the save entirely. If you want a softer approach (warning but allow save), use a Screen Flow launched from a Quick Action instead.
- Test with Data Loader bulk updates — the Flow must handle 200 records in a single transaction.
