/**
 * AccountTriggerHandler - Example concrete handler for the Account object.
 *
 * Demonstrates:
 * - Overriding specific trigger contexts
 * - Using recursion guard for after-update logic
 * - Bulkified query and DML patterns
 * - Field change detection
 *
 * @author  Sandip Patel
 */
public class AccountTriggerHandler extends TriggerHandler {

    protected override void beforeInsert() {
        setDefaultValues((List<Account>) triggerNew);
    }

    protected override void afterUpdate() {
        // Only process records that haven't been handled in this transaction
        List<Account> toProcess = new List<Account>();
        for (Account acc : (List<Account>) triggerNew) {
            if (!isAlreadyProcessed(acc.Id)) {
                toProcess.add(acc);
                markProcessed(acc.Id);
            }
        }

        if (!toProcess.isEmpty()) {
            syncBillingToContacts(toProcess);
            updateChildOpportunityOwners(toProcess);
        }
    }

    // ── Business Logic ─────────────────────────────────────────

    /**
     * Set default field values on new Accounts.
     */
    private void setDefaultValues(List<Account> accounts) {
        for (Account acc : accounts) {
            if (String.isBlank(acc.Type)) {
                acc.Type = 'Prospect';
            }
            if (acc.NumberOfEmployees == null) {
                acc.NumberOfEmployees = 0;
            }
        }
    }

    /**
     * When Account billing address changes, update all child Contacts'
     * mailing address to match.
     */
    private void syncBillingToContacts(List<Account> accounts) {
        // Find accounts where billing address actually changed
        Set<Id> addressChanged = getChangedRecordIds('BillingStreet');
        addressChanged.addAll(getChangedRecordIds('BillingCity'));
        addressChanged.addAll(getChangedRecordIds('BillingState'));

        if (addressChanged.isEmpty()) {
            return;
        }

        // Bulkified: query all contacts for changed accounts in one query
        List<Contact> contactsToUpdate = new List<Contact>();
        Map<Id, Account> changedAccounts = new Map<Id, Account>();

        for (Account acc : accounts) {
            if (addressChanged.contains(acc.Id)) {
                changedAccounts.put(acc.Id, acc);
            }
        }

        for (Contact c : [
            SELECT Id, AccountId FROM Contact
            WHERE AccountId IN :changedAccounts.keySet()
        ]) {
            Account acc = changedAccounts.get(c.AccountId);
            c.MailingStreet = acc.BillingStreet;
            c.MailingCity = acc.BillingCity;
            c.MailingState = acc.BillingState;
            c.MailingPostalCode = acc.BillingPostalCode;
            c.MailingCountry = acc.BillingCountry;
            contactsToUpdate.add(c);
        }

        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }

    /**
     * When Account owner changes, update all open Opportunities
     * to the new owner.
     */
    private void updateChildOpportunityOwners(List<Account> accounts) {
        Set<Id> ownerChanged = getChangedRecordIds('OwnerId');

        if (ownerChanged.isEmpty()) {
            return;
        }

        Map<Id, Id> accountToNewOwner = new Map<Id, Id>();
        for (Account acc : accounts) {
            if (ownerChanged.contains(acc.Id)) {
                accountToNewOwner.put(acc.Id, acc.OwnerId);
            }
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity opp : [
            SELECT Id, AccountId, OwnerId FROM Opportunity
            WHERE AccountId IN :accountToNewOwner.keySet()
            AND IsClosed = false
        ]) {
            opp.OwnerId = accountToNewOwner.get(opp.AccountId);
            oppsToUpdate.add(opp);
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}
