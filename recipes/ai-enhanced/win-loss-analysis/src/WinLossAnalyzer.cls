/**
 * WinLossAnalyzer - AI-powered win/loss narrative generation.
 *
 * Gathers opportunity history, activities, and competitor data,
 * then calls an LLM to generate a structured analysis.
 *
 * @author  Sandip Patel
 */
public class WinLossAnalyzer implements Queueable, Database.AllowsCallouts {

    private List<Id> opportunityIds;
    private static final String LLM_ENDPOINT = 'callout:LLM_API/v1/messages';

    @InvocableMethod(label='Analyze Win/Loss' description='Generate AI narrative for closed opportunities')
    public static void analyze(List<Id> oppIds) {
        if (oppIds == null || oppIds.isEmpty()) return;
        System.enqueueJob(new WinLossAnalyzer(oppIds));
    }

    public WinLossAnalyzer(List<Id> opportunityIds) {
        this.opportunityIds = opportunityIds;
    }

    public void execute(QueueableContext context) {
        List<Opportunity> opps = [
            SELECT Id, Name, Amount, StageName, CloseDate, IsWon, Type,
                   LeadSource, ForecastCategory, Probability, NextStep,
                   Account.Name, Account.Industry, Owner.Name,
                   CreatedDate, LastModifiedDate,
                   (SELECT Id, StageName, CreatedDate FROM OpportunityHistories
                    ORDER BY CreatedDate ASC),
                   (SELECT Id, Subject, Status, ActivityDate FROM Tasks
                    ORDER BY ActivityDate DESC LIMIT 10),
                   (SELECT Id, Subject, StartDateTime FROM Events
                    ORDER BY StartDateTime DESC LIMIT 10)
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ];

        List<Opportunity> toUpdate = new List<Opportunity>();

        for (Opportunity opp : opps) {
            try {
                String narrative = generateNarrative(opp);
                Map<String, Object> parsed = parseNarrative(narrative);

                opp.Win_Loss_Narrative__c = (String) parsed.get('narrative');
                opp.Key_Factors__c = (String) parsed.get('key_factors');
                opp.Competitor_Impact__c = (String) parsed.get('competitor_impact');
                opp.Lessons_Learned__c = (String) parsed.get('lessons_learned');
                toUpdate.add(opp);

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    '[WinLossAnalyzer] Failed for ' + opp.Name + ': ' + e.getMessage());
                opp.Win_Loss_Narrative__c = 'Analysis failed: ' + e.getMessage();
                toUpdate.add(opp);
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
    }

    private String generateNarrative(Opportunity opp) {
        String context = buildContext(opp);

        Map<String, Object> body = new Map<String, Object>{
            'model' => 'claude-sonnet-4-20250514',
            'max_tokens' => 800,
            'temperature' => 0.2,
            'system' => 'You are a sales analyst. Analyze the opportunity data and write a concise win/loss narrative. Respond with JSON only.',
            'messages' => new List<Object>{
                new Map<String, Object>{
                    'role' => 'user',
                    'content' => 'Analyze this closed opportunity:\n\n' + context +
                        '\n\nRespond with JSON: {"narrative": "2-3 paragraph analysis", "key_factors": "comma-separated factors", "competitor_impact": "1-2 sentences", "lessons_learned": "1-2 sentences"}'
                }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(LLM_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('anthropic-version', '2023-06-01');
        req.setTimeout(30000);
        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('LLM API returned ' + res.getStatusCode());
        }

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> content = (List<Object>) response.get('content');
        Map<String, Object> textBlock = (Map<String, Object>) content[0];
        return (String) textBlock.get('text');
    }

    private String buildContext(Opportunity opp) {
        String ctx = 'Name: ' + opp.Name + '\n'
            + 'Result: ' + (opp.IsWon ? 'WON' : 'LOST') + '\n'
            + 'Amount: ' + opp.Amount + '\n'
            + 'Account: ' + (opp.Account != null ? opp.Account.Name : 'N/A') + '\n'
            + 'Industry: ' + (opp.Account != null ? opp.Account.Industry : 'N/A') + '\n'
            + 'Owner: ' + (opp.Owner != null ? opp.Owner.Name : 'N/A') + '\n'
            + 'Close Date: ' + opp.CloseDate + '\n'
            + 'Created: ' + opp.CreatedDate + '\n'
            + 'Days in Pipeline: ' + opp.CreatedDate.date().daysBetween(opp.CloseDate) + '\n'
            + 'Lead Source: ' + opp.LeadSource + '\n';

        // Stage history
        if (opp.OpportunityHistories != null && !opp.OpportunityHistories.isEmpty()) {
            ctx += '\nStage History:\n';
            for (OpportunityHistory h : opp.OpportunityHistories) {
                ctx += '  ' + h.CreatedDate.format() + ' -> ' + h.StageName + '\n';
            }
        }

        // Recent activities
        if (opp.Tasks != null && !opp.Tasks.isEmpty()) {
            ctx += '\nRecent Tasks:\n';
            for (Task t : opp.Tasks) {
                ctx += '  ' + t.ActivityDate + ': ' + t.Subject + ' (' + t.Status + ')\n';
            }
        }

        return ctx;
    }

    private Map<String, Object> parseNarrative(String jsonResponse) {
        String cleaned = jsonResponse.trim();
        if (cleaned.startsWith('```')) cleaned = cleaned.substringAfter('\n');
        if (cleaned.endsWith('```')) cleaned = cleaned.substringBeforeLast('```');
        return (Map<String, Object>) JSON.deserializeUntyped(cleaned.trim());
    }
}
