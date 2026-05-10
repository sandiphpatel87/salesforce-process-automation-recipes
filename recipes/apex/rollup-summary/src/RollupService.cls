/**
 * RollupService - Bulk-safe rollup calculations for lookup relationships.
 *
 * Handles SUM, COUNT, MIN, MAX, and AVG across lookup relationships
 * where native rollup summary fields aren't available.
 *
 * Usage (from a trigger handler):
 *   RollupService.rollup(new RollupService.RollupConfig(
 *       'Case', 'AccountId', 'Account', 'Open_Case_Count__c',
 *       RollupService.Operation.COUNT, null, 'IsClosed = false'
 *   ), Trigger.new, Trigger.old);
 *
 * @author  Sandip Patel
 */
public class RollupService {

    public enum Operation { COUNT_OP, SUM_OP, MIN_OP, MAX_OP, AVG_OP }

    public class RollupConfig {
        public String childObject;
        public String lookupField;
        public String parentObject;
        public String targetField;
        public Operation op;
        public String aggregateField;
        public String filterCondition;

        public RollupConfig(String childObject, String lookupField,
                          String parentObject, String targetField,
                          Operation op, String aggregateField,
                          String filterCondition) {
            this.childObject = childObject;
            this.lookupField = lookupField;
            this.parentObject = parentObject;
            this.targetField = targetField;
            this.op = op;
            this.aggregateField = aggregateField;
            this.filterCondition = filterCondition;
        }
    }

    /**
     * Calculate and update rollup values on parent records.
     */
    public static void rollup(RollupConfig config,
                               List<SObject> newRecords,
                               List<SObject> oldRecords) {

        Set<Id> parentIds = collectParentIds(config.lookupField, newRecords, oldRecords);

        if (parentIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> results = calculateRollup(config, parentIds);

        List<SObject> parentsToUpdate = new List<SObject>();
        for (Id parentId : parentIds) {
            SObject parent = Schema.getGlobalDescribe()
                .get(config.parentObject)
                .newSObject(parentId);

            Decimal value = results.containsKey(parentId)
                ? results.get(parentId) : 0;

            parent.put(config.targetField, value);
            parentsToUpdate.add(parent);
        }

        if (!parentsToUpdate.isEmpty()) {
            Database.update(parentsToUpdate, false);
        }
    }

    private static Set<Id> collectParentIds(String lookupField,
                                             List<SObject> newRecords,
                                             List<SObject> oldRecords) {
        Set<Id> parentIds = new Set<Id>();

        if (newRecords != null) {
            for (SObject rec : newRecords) {
                Id pid = (Id) rec.get(lookupField);
                if (pid != null) parentIds.add(pid);
            }
        }

        if (oldRecords != null) {
            for (SObject rec : oldRecords) {
                Id pid = (Id) rec.get(lookupField);
                if (pid != null) parentIds.add(pid);
            }
        }

        return parentIds;
    }

    private static Map<Id, Decimal> calculateRollup(RollupConfig config,
                                                      Set<Id> parentIds) {
        Map<Id, Decimal> results = new Map<Id, Decimal>();

        String aggFunction;
        String aggField = config.aggregateField != null
            ? config.aggregateField : 'Id';

        switch on config.op {
            when COUNT_OP { aggFunction = 'COUNT(Id) val'; }
            when SUM_OP   { aggFunction = 'SUM(' + aggField + ') val'; }
            when MIN_OP   { aggFunction = 'MIN(' + aggField + ') val'; }
            when MAX_OP   { aggFunction = 'MAX(' + aggField + ') val'; }
            when AVG_OP   { aggFunction = 'AVG(' + aggField + ') val'; }
        }

        String soql = 'SELECT ' + config.lookupField + ', ' + aggFunction
            + ' FROM ' + config.childObject
            + ' WHERE ' + config.lookupField + ' IN :parentIds';

        if (String.isNotBlank(config.filterCondition)) {
            soql += ' AND (' + config.filterCondition + ')';
        }

        soql += ' GROUP BY ' + config.lookupField;

        for (AggregateResult ar : Database.query(soql)) {
            Id parentId = (Id) ar.get(config.lookupField);
            Decimal val = ar.get('val') != null
                ? Decimal.valueOf(String.valueOf(ar.get('val'))) : 0;
            results.put(parentId, val);
        }

        return results;
    }
}
