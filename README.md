# Salesforce Process Automation Recipes

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Recipes](https://img.shields.io/badge/recipes-20+-orange.svg)](#recipe-catalog)

**Battle-tested automation patterns for Salesforce admins and developers.** Each recipe solves a real business problem with step-by-step instructions, deployable code, and documented gotchas from production experience.

This isn't a textbook. Every recipe here comes from real implementations — the patterns that actually survive contact with business users, data volumes, and governor limits.

---

## What's Inside

- **Flow Recipes** — Screen Flows, Record-Triggered Flows, Scheduled Flows with real business logic
- **Apex Patterns** — Trigger frameworks, batch processing, REST integrations, and testing strategies
- **Integration Blueprints** — Patterns for connecting Salesforce to external systems (ERP, marketing platforms, data warehouses)
- **AI-Enhanced Workflows** — Recipes that combine Salesforce automation with LLM capabilities for content generation, classification, and summarization

Each recipe includes:
- **Business Scenario** — The real-world problem this solves
- **Architecture Diagram** — How the pieces fit together
- **Deployable Code/Config** — Copy-paste ready
- **Gotchas & Limits** — What breaks at scale and how to avoid it
- **Testing Strategy** — How to validate before deploying to production

---

## Recipe Catalog

### Flow Recipes

| # | Recipe | Scenario | Complexity |
|---|--------|----------|------------|
| F-01 | [Lead Assignment with Round Robin](recipes/flows/lead-round-robin/) | Distribute leads evenly across reps with timezone awareness | Medium |
| F-02 | [Opportunity Stage Validation](recipes/flows/opp-stage-validation/) | Enforce required fields at each stage gate | Easy |
| F-03 | [Case Escalation Timer](recipes/flows/case-escalation-timer/) | Auto-escalate cases that breach SLA thresholds | Medium |
| F-04 | [Contract Renewal Automation](recipes/flows/contract-renewal/) | Create renewal opportunities 90 days before contract end | Medium |
| F-05 | [Multi-Object Approval with Delegation](recipes/flows/multi-approval/) | Complex approval chains with delegation and timeout | Hard |
| F-06 | [Account Health Score Calculator](recipes/flows/account-health-score/) | Composite score from cases, opportunities, and activities | Hard |

### Apex Patterns

| # | Recipe | Scenario | Complexity |
|---|--------|----------|------------|
| A-01 | [Trigger Handler Framework](recipes/apex/trigger-framework/) | One-trigger-per-object with recursion guard and bypass | Medium |
| A-02 | [Bulk-Safe Rollup Summary](recipes/apex/rollup-summary/) | Custom rollup for lookup relationships (not just master-detail) | Medium |
| A-03 | [Queueable Chain for Large Data](recipes/apex/queueable-chain/) | Process 100K+ records without hitting governor limits | Hard |
| A-04 | [REST Callout with Retry & Circuit Breaker](recipes/apex/rest-callout-retry/) | Resilient external API integration | Hard |
| A-05 | [Dynamic SOQL Builder](recipes/apex/dynamic-soql/) | Type-safe dynamic query construction with FLS enforcement | Medium |
| A-06 | [Platform Event Error Handler](recipes/apex/event-error-handler/) | Graceful error handling for async Platform Event subscribers | Medium |

### Integration Blueprints

| # | Recipe | Scenario | Complexity |
|---|--------|----------|------------|
| I-01 | [Salesforce ↔ ERP Order Sync](recipes/integration/erp-order-sync/) | Bidirectional order/invoice sync with conflict resolution | Hard |
| I-02 | [Marketing Cloud Journey Trigger](recipes/integration/mc-journey-trigger/) | Fire Marketing Cloud journeys from Salesforce record changes | Medium |
| I-03 | [Slack Notification Engine](recipes/integration/slack-notifications/) | Configurable Slack alerts for key Salesforce events | Easy |
| I-04 | [Data Warehouse CDC Pipeline](recipes/integration/cdc-data-warehouse/) | Stream Salesforce changes to Snowflake/BigQuery via Change Data Capture | Hard |

### AI-Enhanced Workflows

| # | Recipe | Scenario | Complexity |
|---|--------|----------|------------|
| AI-01 | [Case Auto-Classification](recipes/ai-enhanced/case-classification/) | Use LLM to categorize incoming cases by product area and urgency | Medium |
| AI-02 | [Opportunity Win/Loss Analysis](recipes/ai-enhanced/win-loss-analysis/) | Generate narrative analysis from opportunity and activity data | Medium |
| AI-03 | [Knowledge Article Generator](recipes/ai-enhanced/knowledge-generator/) | Auto-draft Knowledge articles from resolved case threads | Hard |
| AI-04 | [Email Response Suggestions](recipes/ai-enhanced/email-suggestions/) | Generate contextual reply drafts for support reps | Medium |

---

## How to Use These Recipes

### For Salesforce Admins (Flows)
1. Read the business scenario to confirm it matches your need
2. Review the architecture diagram
3. Follow the step-by-step setup guide
4. Deploy the Flow metadata (XML provided for each recipe)
5. Test with the provided test scenarios

### For Developers (Apex / Integration)
1. Clone this repo
2. Copy the relevant recipe's source into your SFDX project
3. Deploy to a sandbox: `sf project deploy start --source-dir recipes/apex/trigger-framework`
4. Run the included test classes
5. Adapt the configuration for your org

### For AI Workflows
1. Set up the required Custom Settings / Named Credentials
2. Deploy the Apex classes and Flow components
3. Configure the LLM provider credentials
4. Test with sample records in sandbox

---

## Folder Structure

```
recipes/
├── flows/
│   ├── lead-round-robin/
│   │   ├── README.md              # Business scenario + architecture
│   │   ├── flow-metadata.xml      # Deployable Flow definition
│   │   ├── custom-fields.xml      # Required custom fields
│   │   └── test-scenarios.md      # Validation test cases
│   └── .../
├── apex/
│   ├── trigger-framework/
│   │   ├── README.md
│   │   ├── src/
│   │   │   ├── TriggerHandler.cls
│   │   │   ├── TriggerHandler.cls-meta.xml
│   │   │   ├── AccountTriggerHandler.cls
│   │   │   └── AccountTrigger.trigger
│   │   └── tests/
│   │       └── TriggerHandlerTest.cls
│   └── .../
├── integration/
│   └── .../
└── ai-enhanced/
    └── .../
```

---

## Contributing

**This repo thrives on community contributions.** If you've solved a Salesforce automation problem that others would hit, share it here.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the recipe template and submission guidelines.

### Most Wanted Recipes

We're looking for contributions in these areas:
- Industry-specific patterns (Healthcare, Financial Services, Manufacturing)
- Salesforce Industries / Vlocity automation
- Einstein / Agentforce integration patterns
- Multi-org / packaging patterns for ISVs
- Performance optimization recipes for high-volume orgs (1M+ records)
- CPQ automation patterns
- Field Service Lightning workflows

---

## License

MIT License — see [LICENSE](LICENSE).

---

## Citation

```bibtex
@software{sf_recipes2026,
  title={Salesforce Process Automation Recipes},
  author={Patel, Sandip},
  year={2026},
  url={https://github.com/sandiphpatel87/salesforce-process-automation-recipes}
}
```

---

Curated from 15+ years of enterprise Salesforce implementations. Every recipe has been battle-tested in production.
