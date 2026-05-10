/**
 * EmailSuggestionController - Generates contextual email reply drafts for support reps.
 *
 * Called from an LWC Quick Action on the Case page. Gathers case context,
 * email history, and Knowledge articles, then generates 2-3 reply options.
 *
 * @author  Sandip Patel
 */
public class EmailSuggestionController {

    private static final String LLM_ENDPOINT = 'callout:LLM_API/v1/messages';

    public class SuggestedReply {
        @AuraEnabled public String label;
        @AuraEnabled public String body;
        @AuraEnabled public String tone;
    }

    @AuraEnabled(cacheable=false)
    public static List<SuggestedReply> getSuggestions(Id caseId) {
        Case c = [
            SELECT Id, CaseNumber, Subject, Description, Priority, Status,
                   Contact.Name, Contact.Email, Account.Name,
                   Account.Support_Tier__c,
                   (SELECT Id, Subject, TextBody, FromAddress, Incoming,
                           MessageDate
                    FROM EmailMessages
                    ORDER BY MessageDate DESC LIMIT 5)
            FROM Case
            WHERE Id = :caseId
        ];

        // Find relevant Knowledge articles
        String searchTerm = c.Subject != null ? c.Subject.left(100) : '';
        List<Knowledge__kav> articles = new List<Knowledge__kav>();
        if (String.isNotBlank(searchTerm)) {
            String sosl = 'FIND {' + String.escapeSingleQuotes(searchTerm)
                + '} IN ALL FIELDS RETURNING Knowledge__kav(Title, Solution__c LIMIT 3)';
            List<List<SObject>> results = Search.query(sosl);
            if (!results.isEmpty()) {
                articles = (List<Knowledge__kav>) results[0];
            }
        }

        String prompt = buildPrompt(c, articles);
        String llmResponse = callLLM(prompt);
        return parseReplies(llmResponse);
    }

    private static String buildPrompt(Case c, List<Knowledge__kav> articles) {
        String ctx = 'Case #' + c.CaseNumber + '\n'
            + 'Subject: ' + c.Subject + '\n'
            + 'Priority: ' + c.Priority + '\n'
            + 'Customer: ' + (c.Contact != null ? c.Contact.Name : 'Unknown') + '\n'
            + 'Account: ' + (c.Account != null ? c.Account.Name : 'Unknown') + '\n'
            + 'Tier: ' + (c.Account != null && c.Account.Support_Tier__c != null
                ? c.Account.Support_Tier__c : 'Standard') + '\n';

        // Email thread
        if (c.EmailMessages != null && !c.EmailMessages.isEmpty()) {
            ctx += '\nEmail Thread (most recent first):\n';
            for (EmailMessage em : c.EmailMessages) {
                String direction = em.Incoming ? 'CUSTOMER' : 'AGENT';
                ctx += '\n[' + direction + ' - ' + em.MessageDate.format() + ']\n';
                ctx += em.TextBody != null ? em.TextBody.left(500) : '(no text)';
                ctx += '\n';
            }
        }

        // Knowledge articles
        if (!articles.isEmpty()) {
            ctx += '\nRelevant Knowledge Articles:\n';
            for (Knowledge__kav kav : articles) {
                ctx += '- ' + kav.Title + '\n';
                if (kav.Solution__c != null) {
                    ctx += '  Solution: ' + kav.Solution__c.stripHtmlTags().left(300) + '\n';
                }
            }
        }

        return 'Generate 3 email reply options for this support case. '
            + 'Match the customer\'s formality level. '
            + 'Ground answers in the Knowledge articles when available.\n\n'
            + ctx
            + '\n\nRespond with JSON only: [{"label": "Concise", "body": "email text", "tone": "professional"}, '
            + '{"label": "Detailed", "body": "email with steps", "tone": "helpful"}, '
            + '{"label": "Escalation", "body": "acknowledgment + next steps", "tone": "empathetic"}]';
    }

    private static String callLLM(String prompt) {
        Map<String, Object> body = new Map<String, Object>{
            'model' => 'claude-sonnet-4-20250514',
            'max_tokens' => 800,
            'temperature' => 0.3,
            'system' => 'You are a customer support email assistant. Write clear, helpful replies. Match the customer tone. Respond with a JSON array only.',
            'messages' => new List<Object>{
                new Map<String, Object>{ 'role' => 'user', 'content' => prompt }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(LLM_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('anthropic-version', '2023-06-01');
        req.setTimeout(30000);
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Failed to generate suggestions. Please try again.');
        }

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> content = (List<Object>) response.get('content');
        return (String) ((Map<String, Object>) content[0]).get('text');
    }

    private static List<SuggestedReply> parseReplies(String jsonStr) {
        String cleaned = jsonStr.trim();
        if (cleaned.startsWith('```')) cleaned = cleaned.substringAfter('\n');
        if (cleaned.endsWith('```')) cleaned = cleaned.substringBeforeLast('```');
        cleaned = cleaned.trim();

        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(cleaned);
        List<SuggestedReply> replies = new List<SuggestedReply>();

        for (Object obj : parsed) {
            Map<String, Object> item = (Map<String, Object>) obj;
            SuggestedReply reply = new SuggestedReply();
            reply.label = (String) item.get('label');
            reply.body = (String) item.get('body');
            reply.tone = (String) item.get('tone');
            replies.add(reply);
        }

        return replies;
    }
}
