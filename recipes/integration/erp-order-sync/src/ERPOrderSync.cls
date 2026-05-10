/**
 * ERPOrderSync - Bidirectional order sync between Salesforce and ERP.
 *
 * Sends closed-won Opportunities as orders to an ERP system,
 * and receives status updates back via a REST endpoint.
 *
 * @author  Sandip Patel
 */
public class ERPOrderSync implements Queueable, Database.AllowsCallouts {

    private List<Id> opportunityIds;
    private static final String ERP_ENDPOINT = 'callout:ERP_API/orders';

    @InvocableMethod(label='Sync Order to ERP' description='Send closed-won opportunity to ERP as an order')
    public static void syncToERP(List<Id> oppIds) {
        if (oppIds == null || oppIds.isEmpty()) return;
        System.enqueueJob(new ERPOrderSync(oppIds));
    }

    public ERPOrderSync(List<Id> opportunityIds) {
        this.opportunityIds = opportunityIds;
    }

    public void execute(QueueableContext context) {
        List<Opportunity> opps = [
            SELECT Id, Name, Amount, CloseDate, AccountId,
                   Account.Name, Account.BillingStreet, Account.BillingCity,
                   Account.BillingState, Account.BillingPostalCode,
                   ERP_Order_Id__c,
                   (SELECT Id, Product2.ProductCode, Quantity,
                           UnitPrice, TotalPrice
                    FROM OpportunityLineItems)
            FROM Opportunity
            WHERE Id IN :opportunityIds
            AND StageName = 'Closed Won'
        ];

        for (Opportunity opp : opps) {
            try {
                Map<String, Object> erpOrder = buildERPPayload(opp);
                Map<String, Object> response = sendToERP(erpOrder);

                // Update Salesforce with ERP reference
                opp.ERP_Order_Id__c = (String) response.get('order_id');
                opp.ERP_Status__c = (String) response.get('status');
                opp.ERP_Synced_At__c = DateTime.now();

            } catch (Exception e) {
                opp.ERP_Status__c = 'Sync Failed';
                opp.ERP_Error__c = e.getMessage().left(255);
                System.debug(LoggingLevel.ERROR,
                    '[ERPOrderSync] Failed for ' + opp.Name + ': ' + e.getMessage());
            }
        }

        Database.update(opps, false);
    }

    private Map<String, Object> buildERPPayload(Opportunity opp) {
        Map<String, Object> order = new Map<String, Object>{
            'external_ref' => opp.Id,
            'customer_name' => opp.Account != null ? opp.Account.Name : '',
            'order_date' => String.valueOf(opp.CloseDate),
            'total_amount' => opp.Amount,
            'billing_address' => new Map<String, String>{
                'street' => opp.Account.BillingStreet,
                'city' => opp.Account.BillingCity,
                'state' => opp.Account.BillingState,
                'postal_code' => opp.Account.BillingPostalCode
            }
        };

        List<Map<String, Object>> lineItems = new List<Map<String, Object>>();
        if (opp.OpportunityLineItems != null) {
            for (OpportunityLineItem oli : opp.OpportunityLineItems) {
                lineItems.add(new Map<String, Object>{
                    'sku' => oli.Product2.ProductCode,
                    'quantity' => oli.Quantity,
                    'unit_price' => oli.UnitPrice,
                    'total' => oli.TotalPrice
                });
            }
        }
        order.put('line_items', lineItems);

        return order;
    }

    private Map<String, Object> sendToERP(Map<String, Object> payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ERP_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);
        req.setBody(JSON.serialize(payload));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('ERP returned HTTP ' + res.getStatusCode()
                + ': ' + res.getBody().left(500));
        }

        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    /**
     * REST endpoint to receive status updates from ERP.
     * Register as: /services/apexrest/erp/order-status
     */
    @RestResource(urlMapping='/erp/order-status')
    global class ERPStatusWebhook {

        @HttpPost
        global static String updateStatus() {
            RestRequest req = RestContext.request;
            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

            String salesforceId = (String) body.get('external_ref');
            String erpStatus = (String) body.get('status');
            String erpOrderId = (String) body.get('order_id');

            List<Opportunity> opps = [
                SELECT Id, ERP_Status__c FROM Opportunity
                WHERE Id = :salesforceId LIMIT 1
            ];

            if (!opps.isEmpty()) {
                opps[0].ERP_Status__c = erpStatus;
                opps[0].ERP_Order_Id__c = erpOrderId;
                update opps[0];
                return 'OK';
            }

            return 'NOT_FOUND';
        }
    }
}
