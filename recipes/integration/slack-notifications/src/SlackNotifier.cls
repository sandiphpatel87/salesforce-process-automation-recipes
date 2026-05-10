/**
 * SlackNotifier - Sends rich Slack notifications from Salesforce events.
 *
 * Uses Slack Block Kit for rich message formatting with buttons,
 * fields, and record links. Webhook URL is stored in Named Credential
 * for security and configurability.
 *
 * Usage:
 *   SlackNotifier.send('#deals-pipeline', 'New Deal Alert',
 *       'Acme Corp opportunity moved to Negotiation — $250K',
 *       'https://your-org.my.salesforce.com/006xxx');
 *
 * @author  Sandip Patel
 * @version 1.0
 */
public class SlackNotifier {

    private static final String NAMED_CREDENTIAL = 'callout:Slack_Webhook';

    // ── Public Methods ─────────────────────────────────────────

    /**
     * Send a simple Slack notification.
     */
    public static void send(String channel, String title, String message, String recordUrl) {
        Map<String, Object> payload = buildBlockKitMessage(title, message, recordUrl);
        postToSlack(JSON.serialize(payload));
    }

    /**
     * Send a rich notification with field-value pairs.
     */
    public static void sendWithFields(String channel, String title,
                                       Map<String, String> fields, String recordUrl) {
        Map<String, Object> payload = buildBlockKitWithFields(title, fields, recordUrl);
        postToSlack(JSON.serialize(payload));
    }

    /**
     * Send an alert for opportunity stage changes.
     */
    public static void notifyDealUpdate(Opportunity opp, String oldStage, String newStage) {
        Map<String, String> fields = new Map<String, String>{
            'Deal' => opp.Name,
            'Account' => opp.Account != null ? opp.Account.Name : 'N/A',
            'Amount' => opp.Amount != null ? '$' + String.valueOf(opp.Amount.setScale(0)) : 'TBD',
            'Stage' => oldStage + ' → ' + newStage,
            'Close Date' => opp.CloseDate != null ? String.valueOf(opp.CloseDate) : 'TBD',
            'Owner' => opp.Owner != null ? opp.Owner.Name : 'Unassigned'
        };

        String title = getStageEmoji(newStage) + ' Deal Stage Update';
        String url = URL.getOrgDomainUrl().toExternalForm() + '/' + opp.Id;
        sendWithFields('#deals-pipeline', title, fields, url);
    }

    /**
     * Send an alert for case escalations.
     */
    public static void notifyCaseEscalation(Case c) {
        Map<String, String> fields = new Map<String, String>{
            'Case' => c.CaseNumber,
            'Subject' => c.Subject != null ? c.Subject.left(100) : 'N/A',
            'Priority' => c.Priority,
            'Account' => c.Account != null ? c.Account.Name : 'N/A',
            'Owner' => c.Owner != null ? c.Owner.Name : 'Unassigned'
        };

        String title = '🚨 Case Escalation';
        String url = URL.getOrgDomainUrl().toExternalForm() + '/' + c.Id;
        sendWithFields('#support-escalations', title, fields, url);
    }

    // ── Block Kit Builders ─────────────────────────────────────

    private static Map<String, Object> buildBlockKitMessage(
        String title, String message, String recordUrl
    ) {
        List<Object> blocks = new List<Object>();

        // Header
        blocks.add(new Map<String, Object>{
            'type' => 'header',
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => title
            }
        });

        // Message body
        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => message
            }
        });

        // Action button
        if (String.isNotBlank(recordUrl)) {
            blocks.add(new Map<String, Object>{
                'type' => 'actions',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'View in Salesforce'
                        },
                        'url' => recordUrl,
                        'style' => 'primary'
                    }
                }
            });
        }

        return new Map<String, Object>{ 'blocks' => blocks };
    }

    private static Map<String, Object> buildBlockKitWithFields(
        String title, Map<String, String> fields, String recordUrl
    ) {
        List<Object> blocks = new List<Object>();

        // Header
        blocks.add(new Map<String, Object>{
            'type' => 'header',
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => title
            }
        });

        // Fields as two-column layout
        List<Object> fieldElements = new List<Object>();
        for (String key : fields.keySet()) {
            fieldElements.add(new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => '*' + key + '*\n' + fields.get(key)
            });
        }

        blocks.add(new Map<String, Object>{
            'type' => 'section',
            'fields' => fieldElements
        });

        // Divider
        blocks.add(new Map<String, Object>{ 'type' => 'divider' });

        // Action button
        if (String.isNotBlank(recordUrl)) {
            blocks.add(new Map<String, Object>{
                'type' => 'actions',
                'elements' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'button',
                        'text' => new Map<String, Object>{
                            'type' => 'plain_text',
                            'text' => 'Open in Salesforce'
                        },
                        'url' => recordUrl,
                        'style' => 'primary'
                    }
                }
            });
        }

        return new Map<String, Object>{ 'blocks' => blocks };
    }

    // ── HTTP ───────────────────────────────────────────────────

    private static void postToSlack(String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                System.debug(LoggingLevel.ERROR,
                    '[SlackNotifier] Failed: HTTP ' + res.getStatusCode() +
                    ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[SlackNotifier] Exception: ' + e.getMessage());
        }
    }

    // ── Helpers ────────────────────────────────────────────────

    private static String getStageEmoji(String stage) {
        Map<String, String> emojis = new Map<String, String>{
            'Prospecting' => '🔍',
            'Qualification' => '📋',
            'Needs Analysis' => '🔬',
            'Value Proposition' => '💡',
            'Proposal/Price Quote' => '📝',
            'Negotiation/Review' => '🤝',
            'Closed Won' => '🎉',
            'Closed Lost' => '😞'
        };
        return emojis.containsKey(stage) ? emojis.get(stage) : '📊';
    }
}
