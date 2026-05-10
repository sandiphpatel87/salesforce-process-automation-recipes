# Contributing Recipes

This repo thrives on community contributions. If you've solved a Salesforce automation problem that others will hit, share it here.

## Recipe Template

Every recipe should include:

### 1. `README.md` (required)
- **Business Scenario**: The real-world problem this solves. Not "how to use Flow" — the actual business pain.
- **Architecture**: How the pieces fit together (ASCII diagram preferred)
- **Required Setup**: Custom objects, fields, metadata, permissions
- **Step-by-step Instructions**: Clear enough for a senior admin to follow
- **Gotchas**: What breaks at scale? What are the governor limit concerns? What did you learn the hard way?
- **Test Scenarios**: How to validate before deploying to production

### 2. Source Code (required for Apex/LWC)
- Working Apex classes with proper formatting
- Corresponding `-meta.xml` files for SFDX deployment
- Test classes with 85%+ coverage

### 3. Flow Metadata (required for Flow recipes)
- Exportable Flow XML or step-by-step screenshots
- Custom field definitions

## Submission Process

1. Fork and clone
2. Create a branch: `git checkout -b recipe/your-recipe-name`
3. Add your recipe in the appropriate directory:
   - `recipes/flows/` for Flow recipes
   - `recipes/apex/` for Apex patterns
   - `recipes/integration/` for integration blueprints
   - `recipes/ai-enhanced/` for AI-powered workflows
4. Follow the folder naming convention: `kebab-case-descriptive-name/`
5. Submit a PR with a clear title describing the recipe

## Code Standards

- Apex: Follow Salesforce naming conventions (PascalCase for classes, camelCase for methods)
- Include error handling — no recipe should silently swallow exceptions
- Test classes are required for all Apex code
- Bulkify everything — single-record patterns won't be accepted

## What We're Looking For

Recipes that:
- Solve a common problem that many orgs face
- Include real-world gotchas from production experience
- Are documented well enough for someone to implement without guessing
- Handle edge cases and failures gracefully

Recipes that won't be accepted:
- "Hello World" examples that don't solve a real problem
- Patterns that only work for a single record
- Code without tests
- Recipes without a clear business scenario
