# A-01: Trigger Handler Framework

## Business Scenario

Your org has 47 triggers written by 12 different developers over 8 years. Some objects have multiple triggers, execution order is unpredictable, and recursion bugs surface every release. You need a single, consistent pattern that every trigger follows.

This framework enforces **one trigger per object** with a handler class that separates logic from trigger context. It includes recursion guards, bypass controls, and a clear extension pattern.

## Architecture

```
Account Trigger (1 per object)
    │
    ▼
TriggerHandler (abstract base)
    │
    ├── beforeInsert()
    ├── beforeUpdate()
    ├── beforeDelete()
    ├── afterInsert()
    ├── afterUpdate()
    ├── afterDelete()
    └── afterUndelete()
    │
    ▼
AccountTriggerHandler (concrete)
    │
    ├── Recursion guard (static Set<Id>)
    ├── Bypass check (Custom Permission or Custom Setting)
    └── Business logic methods
```

## Why This Pattern

- **One trigger per object** — eliminates execution order problems
- **Handler separation** — trigger file is 3 lines, all logic is testable in the handler
- **Recursion guard** — prevents infinite loops from workflow field updates and process builders
- **Bypass mechanism** — lets admins disable triggers per-user for data loads
- **Consistent interface** — every developer follows the same pattern

## Gotchas

- The recursion guard uses a static `Set<Id>` that persists for the entire transaction. If you need to re-process records in the same transaction (e.g., after a workflow field update), clear the set explicitly.
- Bypass via Custom Permission is per-profile/permission-set. For per-user bypass during data loads, use a Custom Setting (`Trigger_Bypass__c.Bypass_All__c`).
- This pattern assumes bulkified logic. Individual record processing in loops will hit governor limits.

## Deploy

```bash
sf project deploy start --source-dir recipes/apex/trigger-framework/src
```
