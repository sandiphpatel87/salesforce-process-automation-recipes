/**
 * CaseClassifier - AI-powered case classification using LLM.
 *
 * Invocable Action for use in Flows. Analyzes case subject and description,
 * then returns structured classification (product area, urgency, sentiment,
 * routing suggestion, and a draft internal note).
 *
 * Designed as a Queueable to avoid callout-from-trigger limitations.
 *
 * Usage (from Flow):
 *   Invoke CaseClassifier.classify with Case Ids
 *   → Updates Case fields asynchronously (1-2 second delay)
 *
 * @author  Sandip Patel
 * @version 1.0
 */
public class CaseClassifier implements Queueable, Database.AllowsCallouts {

    private List<Id> caseIds;

    // ── Named Credential for LLM API ───────────────────────────
    private static final String LLM_ENDPOINT = 'callout:LLM_API/v1/messages';

    // ── Invocable Entry Point (called from Flow) ───────────────

    @InvocableMethod(
        label='Classify Cases with AI'
        description='Uses LLM to classify case product area, urgency, and sentiment'
    )
    public static void classify(List<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) return;
        System.enqueueJob(new CaseClassifier(caseIds));
    }

    public CaseClassifier(List<Id> caseIds) {
        this.caseIds = caseIds;
    }

    // ── Queueable Execution ────────────────────────────────────

    public void execute(QueueableContext context) {
        List<Case> cases = [
            SELECT Id, Subject, Description, Origin, Type,
                   Contact.Name, Account.Name, Account.Industry
            FROM Case
            WHERE Id IN :caseIds
        ];

        List<Case> toUpdate = new List<Case>();

        for (Case c : cases) {
            try {
                ClassificationResult result = classifyCase(c);

                c.Product_Area__c = result.productArea;
                c.AI_Urgency__c = result.urgency;
                c.AI_Sentiment__c = result.sentiment;
                c.AI_Routing_Suggestion__c = result.routingSuggestion;
                c.AI_Internal_Note__c = result.internalNote;
                c.AI_Classified__c = true;
                c.AI_Classified_At__c = DateTime.now();

                toUpdate.add(c);

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    '[CaseClassifier] Failed to classify case ' + c.Id + ': ' + e.getMessage());

                // Set defaults on failure
                c.Product_Area__c = 'Unclassified';
                c.AI_Urgency__c = 'Medium';
                c.AI_Internal_Note__c = 'AI classification failed: ' + e.getMessage();
                c.AI_Classified__c = false;
                toUpdate.add(c);
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false); // Partial success allowed
        }
    }

    // ── Classification Logic ───────────────────────────────────

    private ClassificationResult classifyCase(Case c) {
        String prompt = buildPrompt(c);
        String llmResponse = callLLM(prompt);
        return parseResponse(llmResponse);
    }

    private String buildPrompt(Case c) {
        String caseContext = 'Subject: ' + (c.Subject != null ? c.Subject : 'N/A') + '\n' +
            'Description: ' + (c.Description != null ? c.Description.left(2000) : 'N/A') + '\n' +
            'Origin: ' + (c.Origin != null ? c.Origin : 'N/A') + '\n' +
            'Account: ' + (c.Account != null ? c.Account.Name : 'N/A') + '\n' +
            'Industry: ' + (c.Account != null && c.Account.Industry != null ? c.Account.Industry : 'N/A');

        return 'Analyze this support case and classify it.\n\n' +
            caseContext + '\n\n' +
            'Respond with JSON only:\n' +
            '{\n' +
            '  "product_area": "one of: Billing, Platform, API, Mobile, Analytics, Admin, Integration, Other",\n' +
            '  "urgency": "one of: Critical, High, Medium, Low",\n' +
            '  "sentiment": "one of: angry, frustrated, neutral, positive",\n' +
            '  "routing_suggestion": "best queue name for this case",\n' +
            '  "internal_note": "2-3 sentence summary for the assigned agent including key context and suggested approach"\n' +
            '}';
    }

    private String callLLM(String prompt) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(LLM_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('anthropic-version', '2023-06-01');
        req.setTimeout(30000); // 30 second timeout

        Map<String, Object> body = new Map<String, Object>{
            'model' => 'claude-sonnet-4-20250514',
            'max_tokens' => 500,
            'temperature' => 0.0,
            'system' => 'You are a support case triage specialist. Classify cases accurately. Respond with valid JSON only, no other text.',
            'messages' => new List<Object>{
                new Map<String, Object>{
                    'role' => 'user',
                    'content' => prompt
                }
            }
        };

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('LLM API returned HTTP ' + res.getStatusCode() +
                ': ' + res.getBody().left(500));
        }

        // Extract text from Anthropic response format
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> content = (List<Object>) response.get('content');
        if (content != null && !content.isEmpty()) {
            Map<String, Object> textBlock = (Map<String, Object>) content[0];
            return (String) textBlock.get('text');
        }

        throw new CalloutException('Empty response from LLM API');
    }

    private ClassificationResult parseResponse(String jsonResponse) {
        ClassificationResult result = new ClassificationResult();

        // Strip markdown code fences if present
        String cleaned = jsonResponse.trim();
        if (cleaned.startsWith('```')) {
            cleaned = cleaned.substringAfter('\n');
        }
        if (cleaned.endsWith('```')) {
            cleaned = cleaned.substringBeforeLast('```');
        }
        cleaned = cleaned.trim();

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(cleaned);

        result.productArea = (String) parsed.get('product_area');
        result.urgency = (String) parsed.get('urgency');
        result.sentiment = (String) parsed.get('sentiment');
        result.routingSuggestion = (String) parsed.get('routing_suggestion');
        result.internalNote = (String) parsed.get('internal_note');

        // Validate urgency values
        Set<String> validUrgencies = new Set<String>{'Critical', 'High', 'Medium', 'Low'};
        if (!validUrgencies.contains(result.urgency)) {
            result.urgency = 'Medium';
        }

        return result;
    }

    // ── Inner Classes ──────────────────────────────────────────

    private class ClassificationResult {
        public String productArea;
        public String urgency;
        public String sentiment;
        public String routingSuggestion;
        public String internalNote;
    }
}
