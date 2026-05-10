/**
 * EventErrorHandler - Graceful error handling for Platform Event subscribers.
 *
 * Handles partial failures, tracks retry counts, uses setResumeCheckpoint()
 * to avoid reprocessing, and routes failed events to a dead letter object.
 *
 * Usage (from a Platform Event trigger):
 *   trigger OrderEventTrigger on Order_Event__e (after insert) {
 *       EventErrorHandler.process(Trigger.new, new OrderEventProcessor());
 *   }
 *
 * @author  Sandip Patel
 */
public class EventErrorHandler {

    private static final Integer MAX_RETRIES = 3;

    /**
     * Processor interface. Implement this for each event type.
     */
    public interface IEventProcessor {
        void processEvent(SObject event);
        String getEventKey(SObject event);
    }

    /**
     * Process a batch of Platform Events with error handling.
     */
    public static void process(List<SObject> events, IEventProcessor processor) {
        Integer retryCount = EventBus.TriggerContext.currentContext().retries;

        if (retryCount > MAX_RETRIES) {
            sendToDeadLetter(events, 'Max retries exceeded (' + MAX_RETRIES + ')');
            return;
        }

        List<Event_Dead_Letter__c> deadLetters = new List<Event_Dead_Letter__c>();
        String lastSuccessReplayId = null;

        for (SObject event : events) {
            try {
                processor.processEvent(event);
                lastSuccessReplayId = (String) event.get('ReplayId');
            } catch (Exception e) {
                String eventKey = processor.getEventKey(event);

                deadLetters.add(new Event_Dead_Letter__c(
                    Event_Type__c = event.getSObjectType().getDescribe().getName(),
                    Event_Key__c = eventKey,
                    Payload__c = JSON.serialize(event).left(131072),
                    Error_Message__c = e.getMessage().left(32000),
                    Stack_Trace__c = e.getStackTraceString().left(32000),
                    Retry_Count__c = retryCount,
                    Failed_At__c = DateTime.now()
                ));

                System.debug(LoggingLevel.ERROR,
                    '[EventErrorHandler] Failed to process event '
                    + eventKey + ': ' + e.getMessage());
            }
        }

        // Set checkpoint so Salesforce knows where to resume on retry
        if (lastSuccessReplayId != null) {
            EventBus.TriggerContext.currentContext()
                .setResumeCheckpoint(lastSuccessReplayId);
        }

        if (!deadLetters.isEmpty()) {
            Database.insert(deadLetters, false);
        }
    }

    /**
     * Send all events to dead letter when max retries exceeded.
     */
    private static void sendToDeadLetter(List<SObject> events, String reason) {
        List<Event_Dead_Letter__c> deadLetters = new List<Event_Dead_Letter__c>();

        for (SObject event : events) {
            deadLetters.add(new Event_Dead_Letter__c(
                Event_Type__c = event.getSObjectType().getDescribe().getName(),
                Payload__c = JSON.serialize(event).left(131072),
                Error_Message__c = reason,
                Retry_Count__c = MAX_RETRIES,
                Failed_At__c = DateTime.now(),
                Status__c = 'Dead'
            ));
        }

        if (!deadLetters.isEmpty()) {
            Database.insert(deadLetters, false);
        }
    }
}
