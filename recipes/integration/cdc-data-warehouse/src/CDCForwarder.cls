/**
 * CDCForwarder - Forwards Change Data Capture events to an external data warehouse.
 *
 * Listens to CDC events, extracts changed fields, formats as JSON,
 * and sends to an external endpoint (EventBridge, Kafka, or direct API).
 *
 * Usage: Create a trigger per CDC object:
 *   trigger AccountCDCTrigger on AccountChangeEvent (after insert) {
 *       CDCForwarder.forward(Trigger.new, 'Account');
 *   }
 *
 * @author  Sandip Patel
 */
public class CDCForwarder implements Queueable, Database.AllowsCallouts {

    private List<Map<String, Object>> events;
    private static final String WAREHOUSE_ENDPOINT = 'callout:Data_Warehouse_API/cdc-events';

    /**
     * Entry point from CDC trigger. Extracts change data and queues for delivery.
     */
    public static void forward(List<SObject> changeEvents, String objectName) {
        List<Map<String, Object>> formattedEvents = new List<Map<String, Object>>();

        for (SObject event : changeEvents) {
            EventBus.ChangeEventHeader header =
                (EventBus.ChangeEventHeader) event.get('ChangeEventHeader');

            Map<String, Object> payload = new Map<String, Object>{
                'object_type' => objectName,
                'change_type' => header.getChangeType(),
                'record_ids' => header.getRecordIds(),
                'changed_fields' => header.getChangedFields(),
                'commit_timestamp' => header.getCommitTimestamp(),
                'transaction_key' => header.getTransactionKey(),
                'sequence_number' => header.getSequenceNumber()
            };

            // Extract changed field values
            Map<String, Object> fieldValues = new Map<String, Object>();
            for (String fieldName : header.getChangedFields()) {
                if (fieldName != 'LastModifiedDate' && fieldName != 'LastModifiedById') {
                    try {
                        fieldValues.put(fieldName, event.get(fieldName));
                    } catch (Exception e) {
                        // Field not in event payload, skip
                    }
                }
            }
            payload.put('field_values', fieldValues);

            formattedEvents.add(payload);
        }

        if (!formattedEvents.isEmpty()) {
            System.enqueueJob(new CDCForwarder(formattedEvents));
        }
    }

    public CDCForwarder(List<Map<String, Object>> events) {
        this.events = events;
    }

    public void execute(QueueableContext context) {
        Map<String, Object> batch = new Map<String, Object>{
            'source' => 'salesforce_cdc',
            'sent_at' => DateTime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
            'event_count' => events.size(),
            'events' => events
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(WAREHOUSE_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);
        req.setBody(JSON.serialize(batch));

        try {
            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug('[CDCForwarder] Sent ' + events.size()
                    + ' events successfully.');
            } else {
                System.debug(LoggingLevel.ERROR,
                    '[CDCForwarder] Warehouse returned HTTP ' + res.getStatusCode()
                    + ': ' + res.getBody().left(500));

                // Store failed events for retry
                storeFailedBatch(batch, res.getStatusCode(), res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[CDCForwarder] Delivery failed: ' + e.getMessage());
            storeFailedBatch(batch, 0, e.getMessage());
        }
    }

    private void storeFailedBatch(Map<String, Object> batch,
                                   Integer statusCode, String error) {
        try {
            CDC_Failed_Batch__c failed = new CDC_Failed_Batch__c(
                Payload__c = JSON.serialize(batch).left(131072),
                Error_Code__c = String.valueOf(statusCode),
                Error_Message__c = error.left(32000),
                Event_Count__c = events.size(),
                Failed_At__c = DateTime.now(),
                Status__c = 'Pending Retry'
            );
            insert failed;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[CDCForwarder] Could not store failed batch: ' + e.getMessage());
        }
    }
}
