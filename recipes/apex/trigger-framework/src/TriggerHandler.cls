/**
 * TriggerHandler - Abstract base class for all trigger handlers.
 *
 * Enforces one-trigger-per-object pattern with:
 * - Recursion guard (static Set<Id>)
 * - Bypass mechanism via Custom Setting
 * - Consistent virtual methods for each trigger context
 *
 * Usage:
 *   public class AccountTriggerHandler extends TriggerHandler {
 *       protected override void afterUpdate() { ... }
 *   }
 *
 * @author  Sandip Patel
 * @version 1.0
 */
public abstract class TriggerHandler {

    // ── Static recursion tracking ──────────────────────────────
    private static Map<String, Set<Id>> processedIds = new Map<String, Set<Id>>();

    // ── Instance variables ─────────────────────────────────────
    protected List<SObject> triggerNew;
    protected List<SObject> triggerOld;
    protected Map<Id, SObject> triggerNewMap;
    protected Map<Id, SObject> triggerOldMap;

    // ── Constructor ────────────────────────────────────────────

    public TriggerHandler() {
        this.triggerNew = Trigger.new;
        this.triggerOld = Trigger.old;
        this.triggerNewMap = Trigger.newMap;
        this.triggerOldMap = Trigger.oldMap;
    }

    // ── Public Entry Point ─────────────────────────────────────

    /**
     * Main dispatch method. Called from the trigger.
     * Routes to the correct virtual method based on trigger context.
     */
    public void run() {
        // Check bypass
        if (isBypassed()) {
            return;
        }

        switch on Trigger.operationType {
            when BEFORE_INSERT  { beforeInsert(); }
            when BEFORE_UPDATE  { beforeUpdate(); }
            when BEFORE_DELETE  { beforeDelete(); }
            when AFTER_INSERT   { afterInsert(); }
            when AFTER_UPDATE   { afterUpdate(); }
            when AFTER_DELETE   { afterDelete(); }
            when AFTER_UNDELETE { afterUndelete(); }
        }
    }

    // ── Virtual Methods (override in subclasses) ───────────────

    protected virtual void beforeInsert()  {}
    protected virtual void beforeUpdate()  {}
    protected virtual void beforeDelete()  {}
    protected virtual void afterInsert()   {}
    protected virtual void afterUpdate()   {}
    protected virtual void afterDelete()   {}
    protected virtual void afterUndelete() {}

    // ── Recursion Guard ────────────────────────────────────────

    /**
     * Check if a record has already been processed in this transaction.
     * Prevents infinite loops from workflow field updates, process builders,
     * and flow-triggered record updates.
     */
    protected Boolean isAlreadyProcessed(Id recordId) {
        String handlerName = getHandlerName();
        if (!processedIds.containsKey(handlerName)) {
            processedIds.put(handlerName, new Set<Id>());
        }
        return processedIds.get(handlerName).contains(recordId);
    }

    /**
     * Mark a record as processed for this transaction.
     */
    protected void markProcessed(Id recordId) {
        String handlerName = getHandlerName();
        if (!processedIds.containsKey(handlerName)) {
            processedIds.put(handlerName, new Set<Id>());
        }
        processedIds.get(handlerName).add(recordId);
    }

    /**
     * Mark multiple records as processed.
     */
    protected void markProcessed(Set<Id> recordIds) {
        for (Id recordId : recordIds) {
            markProcessed(recordId);
        }
    }

    /**
     * Clear processed records. Use when you intentionally need
     * to re-process records in the same transaction.
     */
    protected void clearProcessed() {
        processedIds.remove(getHandlerName());
    }

    /**
     * Static clear for use in test setup.
     */
    @TestVisible
    private static void clearAllProcessed() {
        processedIds.clear();
    }

    // ── Bypass Mechanism ───────────────────────────────────────

    /**
     * Check if triggers should be bypassed for the running user.
     * Uses Custom Setting: Trigger_Bypass__c (hierarchy)
     *   - Bypass_All__c (Checkbox) — bypass all triggers
     *   - Bypassed_Handlers__c (Text) — comma-separated handler names
     */
    private Boolean isBypassed() {
        Trigger_Bypass__c settings = Trigger_Bypass__c.getInstance();
        if (settings == null) {
            return false;
        }

        // Global bypass
        if (settings.Bypass_All__c) {
            return true;
        }

        // Per-handler bypass
        String bypassed = settings.Bypassed_Handlers__c;
        if (String.isNotBlank(bypassed)) {
            Set<String> bypassedSet = new Set<String>();
            for (String s : bypassed.split(',')) {
                bypassedSet.add(s.trim());
            }
            return bypassedSet.contains(getHandlerName());
        }

        return false;
    }

    // ── Utility ────────────────────────────────────────────────

    private String getHandlerName() {
        return String.valueOf(this).split(':')[0];
    }

    /**
     * Helper to get changed field values between old and new records.
     * Useful for detecting which fields actually changed in an update.
     */
    protected Set<Id> getChangedRecordIds(String fieldName) {
        Set<Id> changed = new Set<Id>();
        if (triggerNew == null || triggerOldMap == null) {
            return changed;
        }

        for (SObject record : triggerNew) {
            SObject oldRecord = triggerOldMap.get(record.Id);
            if (oldRecord != null && record.get(fieldName) != oldRecord.get(fieldName)) {
                changed.add(record.Id);
            }
        }
        return changed;
    }
}
