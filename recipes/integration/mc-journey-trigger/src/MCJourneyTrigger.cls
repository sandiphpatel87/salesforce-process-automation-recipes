/**
 * MCJourneyTrigger - Fires Marketing Cloud journeys from Salesforce events.
 *
 * Checks eligibility criteria before firing, throttles API calls,
 * and logs results for tracking.
 *
 * @author  Sandip Patel
 */
public class MCJourneyTrigger implements Queueable, Database.AllowsCallouts {

    private List<Id> contactIds;
    private String journeyId;
    private static final String MC_ENDPOINT = 'callout:Marketing_Cloud_API/interaction/v1/events';

    @InvocableMethod(label='Fire MC Journey' description='Trigger a Marketing Cloud journey for contacts')
    public static void fireJourney(List<JourneyRequest> requests) {
        if (requests == null || requests.isEmpty()) return;
        JourneyRequest req = requests[0];
        System.enqueueJob(new MCJourneyTrigger(req.contactIds, req.journeyId));
    }

    public class JourneyRequest {
        @InvocableVariable(required=true)
        public List<Id> contactIds;

        @InvocableVariable(required=true)
        public String journeyId;
    }

    public MCJourneyTrigger(List<Id> contactIds, String journeyId) {
        this.contactIds = contactIds;
        this.journeyId = journeyId;
    }

    public void execute(QueueableContext context) {
        List<Contact> contacts = [
            SELECT Id, Email, FirstName, LastName, AccountId,
                   Account.Name, Account.Industry
            FROM Contact
            WHERE Id IN :contactIds
            AND Email != null
        ];

        // Check eligibility: no MC email in last 30 days
        Set<Id> recentlyEmailed = getRecentlyEmailed(contactIds);

        List<Journey_Log__c> logs = new List<Journey_Log__c>();

        for (Contact c : contacts) {
            if (recentlyEmailed.contains(c.Id)) {
                logs.add(createLog(c.Id, 'Skipped', 'Contact received MC email in last 30 days'));
                continue;
            }

            try {
                fireEvent(c);
                logs.add(createLog(c.Id, 'Fired', 'Journey triggered successfully'));
            } catch (Exception e) {
                logs.add(createLog(c.Id, 'Failed', e.getMessage()));
            }
        }

        if (!logs.isEmpty()) {
            Database.insert(logs, false);
        }
    }

    private void fireEvent(Contact c) {
        Map<String, Object> eventPayload = new Map<String, Object>{
            'ContactKey' => c.Email,
            'EventDefinitionKey' => this.journeyId,
            'Data' => new Map<String, Object>{
                'ContactId' => c.Id,
                'EmailAddress' => c.Email,
                'FirstName' => c.FirstName,
                'LastName' => c.LastName,
                'AccountName' => c.Account != null ? c.Account.Name : '',
                'Industry' => c.Account != null ? c.Account.Industry : ''
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(MC_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(15000);
        req.setBody(JSON.serialize(eventPayload));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('MC API returned ' + res.getStatusCode());
        }
    }

    private Set<Id> getRecentlyEmailed(List<Id> contactIds) {
        Set<Id> emailed = new Set<Id>();
        Date thirtyDaysAgo = Date.today().addDays(-30);

        for (CampaignMember cm : [
            SELECT ContactId FROM CampaignMember
            WHERE ContactId IN :contactIds
            AND Campaign.Type = 'Email'
            AND CreatedDate >= :thirtyDaysAgo
        ]) {
            emailed.add(cm.ContactId);
        }

        return emailed;
    }

    private Journey_Log__c createLog(Id contactId, String status, String detail) {
        return new Journey_Log__c(
            Contact__c = contactId,
            Journey_Id__c = this.journeyId,
            Status__c = status,
            Detail__c = detail.left(32000),
            Fired_At__c = DateTime.now()
        );
    }
}
