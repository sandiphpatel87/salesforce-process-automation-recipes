# A-05: Dynamic SOQL Builder

## Business Scenario

Your app needs to build SOQL queries at runtime based on user-selected filters. The naive approach is string concatenation, which opens the door to SOQL injection and ignores field-level security. You need a builder that constructs type-safe queries, enforces FLS, and prevents injection.

## Architecture

```
User selects filters in LWC
    │
    ▼
Apex Controller receives filter parameters
    │
    ▼
SOQLBuilder
    ├── .selectFields(['Name', 'Email', 'Phone'])
    ├── .fromObject('Contact')
    ├── .whereCondition('AccountId', '=', accountId)
    ├── .whereCondition('CreatedDate', '>', startDate)
    ├── .orderBy('Name', 'ASC')
    ├── .limitTo(50)
    └── .build()  ← returns sanitized SOQL string with FLS check
```

## Gotchas

- **FLS enforcement**: Before including a field in the SELECT clause, check `Schema.SObjectType.Contact.fields.Name.isAccessible()`. Strip inaccessible fields silently rather than throwing an error, unless the field is critical to the query logic.
- **SOQL injection**: Never interpolate user input directly into SOQL strings. Use bind variables (`WHERE Name = :searchTerm`) or the builder's parameterized conditions.
- **Polymorphic fields**: Fields like `WhoId` and `WhatId` on Task resolve to different objects. The builder should handle `TYPEOF` clauses for these.

## Status

> Recipe documented. Source code coming in a future update. Contributions welcome.
