/**
 * KnowledgeGenerator - Auto-drafts Knowledge articles from resolved cases.
 *
 * Gathers case data, comments, and related cases, then uses an LLM
 * to draft a structured Knowledge article in Draft status.
 *
 * @author  Sandip Patel
 */
public class KnowledgeGenerator implements Queueable, Database.AllowsCallouts {

    private List<Id> caseIds;
    private static final String LLM_ENDPOINT = 'callout:LLM_API/v1/messages';

    @InvocableMethod(label='Generate Knowledge Article' description='Draft a Knowledge article from a resolved case')
    public static void generate(List<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) return;
        System.enqueueJob(new KnowledgeGenerator(caseIds));
    }

    public KnowledgeGenerator(List<Id> caseIds) {
        this.caseIds = caseIds;
    }

    public void execute(QueueableContext context) {
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Description, Resolution__c,
                   Product_Area__c, Type, Priority,
                   Account.Name, Contact.Name,
                   (SELECT Id, CommentBody, IsPublished, CreatedDate
                    FROM CaseComments ORDER BY CreatedDate ASC)
            FROM Case
            WHERE Id IN :caseIds
        ];

        for (Case c : cases) {
            try {
                // Check for existing similar articles
                List<Knowledge__kav> existing = [
                    SELECT Id, Title FROM Knowledge__kav
                    WHERE Title LIKE :('%' + c.Subject.left(50) + '%')
                    AND PublishStatus = 'Online'
                    LIMIT 3
                ];

                if (!existing.isEmpty()) {
                    System.debug('[KnowledgeGenerator] Similar article exists for case '
                        + c.CaseNumber + '. Skipping.');
                    continue;
                }

                String articleJson = callLLM(c);
                Map<String, Object> article = parseResponse(articleJson);

                Knowledge__kav kav = new Knowledge__kav();
                kav.Title = ((String) article.get('title')).left(255);
                kav.Summary = ((String) article.get('problem')).left(1000);
                kav.Solution__c = (String) article.get('solution');
                kav.Keywords__c = (String) article.get('keywords');
                kav.Source_Case__c = c.Id;
                kav.UrlName = generateUrlName(kav.Title);

                insert kav;

                System.debug('[KnowledgeGenerator] Created draft article for case '
                    + c.CaseNumber + ': ' + kav.Id);

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    '[KnowledgeGenerator] Failed for case ' + c.CaseNumber
                    + ': ' + e.getMessage());
            }
        }
    }

    private String callLLM(Case c) {
        String caseContext = 'Case: ' + c.CaseNumber + '\n'
            + 'Subject: ' + c.Subject + '\n'
            + 'Product Area: ' + (c.Product_Area__c != null ? c.Product_Area__c : 'General') + '\n'
            + 'Description: ' + (c.Description != null ? c.Description.left(2000) : 'N/A') + '\n'
            + 'Resolution: ' + (c.Resolution__c != null ? c.Resolution__c.left(2000) : 'N/A') + '\n';

        if (c.CaseComments != null && !c.CaseComments.isEmpty()) {
            caseContext += '\nCase Comments:\n';
            for (CaseComment cc : c.CaseComments) {
                if (cc.CommentBody != null) {
                    caseContext += '  [' + cc.CreatedDate.format() + '] '
                        + cc.CommentBody.left(500) + '\n';
                }
            }
        }

        Map<String, Object> body = new Map<String, Object>{
            'model' => 'claude-sonnet-4-20250514',
            'max_tokens' => 600,
            'temperature' => 0.1,
            'system' => 'You are a technical writer creating Knowledge Base articles from resolved support cases. Write clear, searchable articles. Respond with JSON only.',
            'messages' => new List<Object>{
                new Map<String, Object>{
                    'role' => 'user',
                    'content' => 'Create a Knowledge article from this case:\n\n' + caseContext +
                        '\n\nRespond with JSON: {"title": "clear searchable title", "problem": "1-2 sentence problem statement", "solution": "step-by-step solution in HTML", "keywords": "comma-separated search keywords"}'
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

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new CalloutException('LLM API returned ' + res.getStatusCode());
        }

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> content = (List<Object>) response.get('content');
        return (String) ((Map<String, Object>) content[0]).get('text');
    }

    private Map<String, Object> parseResponse(String jsonStr) {
        String cleaned = jsonStr.trim();
        if (cleaned.startsWith('```')) cleaned = cleaned.substringAfter('\n');
        if (cleaned.endsWith('```')) cleaned = cleaned.substringBeforeLast('```');
        return (Map<String, Object>) JSON.deserializeUntyped(cleaned.trim());
    }

    private String generateUrlName(String title) {
        String urlName = title.toLowerCase()
            .replaceAll('[^a-z0-9\\s]', '')
            .replaceAll('\\s+', '-')
            .left(200);
        return urlName + '-' + String.valueOf(DateTime.now().getTime()).right(6);
    }
}
