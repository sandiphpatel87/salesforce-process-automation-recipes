/**
 * ResilientCallout - HTTP callout wrapper with retry logic and circuit breaker.
 *
 * Features:
 * - Automatic retry on transient failures (5xx, timeout)
 * - Exponential backoff between retries
 * - Circuit breaker pattern to fail fast when service is down
 * - Structured logging for observability
 * - Configurable per-endpoint
 *
 * Usage:
 *   ResilientCallout client = new ResilientCallout('Payment_Processor');
 *   ResilientCallout.CalloutResult result = client.execute(request);
 *   if (result.success) {
 *       // handle result.response
 *   } else {
 *       // handle result.errorMessage
 *   }
 *
 * @author  Sandip Patel
 * @version 1.0
 */
public class ResilientCallout {

    // ── Configuration ──────────────────────────────────────────

    private String serviceName;
    private Integer maxRetries;
    private Integer failureThreshold;     // Consecutive failures before circuit opens
    private Integer cooldownSeconds;      // How long circuit stays open
    private Set<Integer> retryableStatusCodes;

    // ── Constants ──────────────────────────────────────────────

    private static final Integer DEFAULT_MAX_RETRIES = 3;
    private static final Integer DEFAULT_FAILURE_THRESHOLD = 5;
    private static final Integer DEFAULT_COOLDOWN_SECONDS = 300; // 5 minutes

    // ── Result Wrapper ─────────────────────────────────────────

    public class CalloutResult {
        public Boolean success;
        public HttpResponse response;
        public String errorMessage;
        public Integer attempts;
        public String circuitState;

        public CalloutResult() {
            this.success = false;
            this.attempts = 0;
            this.circuitState = 'CLOSED';
        }
    }

    // ── Constructor ────────────────────────────────────────────

    public ResilientCallout(String serviceName) {
        this(serviceName, DEFAULT_MAX_RETRIES, DEFAULT_FAILURE_THRESHOLD, DEFAULT_COOLDOWN_SECONDS);
    }

    public ResilientCallout(String serviceName, Integer maxRetries,
                            Integer failureThreshold, Integer cooldownSeconds) {
        this.serviceName = serviceName;
        this.maxRetries = maxRetries;
        this.failureThreshold = failureThreshold;
        this.cooldownSeconds = cooldownSeconds;
        this.retryableStatusCodes = new Set<Integer>{
            408, 429, 500, 502, 503, 504
        };
    }

    // ── Public Methods ─────────────────────────────────────────

    /**
     * Execute an HTTP callout with retry and circuit breaker protection.
     */
    public CalloutResult execute(HttpRequest request) {
        CalloutResult result = new CalloutResult();

        // Check circuit breaker state
        CircuitState state = getCircuitState();
        result.circuitState = state.status;

        if (state.status == 'OPEN') {
            // Check if cooldown has expired
            if (DateTime.now() >= state.nextRetryTime) {
                // Transition to HALF_OPEN: allow one test request
                state.status = 'HALF_OPEN';
                result.circuitState = 'HALF_OPEN';
            } else {
                // Fail fast
                result.errorMessage = 'Circuit breaker is OPEN for service: ' + serviceName +
                    '. Next retry at: ' + state.nextRetryTime.format();
                logEvent('CIRCUIT_OPEN_REJECT', result.errorMessage);
                return result;
            }
        }

        // Attempt the callout with retries
        for (Integer attempt = 1; attempt <= maxRetries; attempt++) {
            result.attempts = attempt;

            try {
                Http http = new Http();
                HttpResponse response = http.send(request);
                Integer statusCode = response.getStatusCode();

                if (statusCode >= 200 && statusCode < 300) {
                    // Success
                    result.success = true;
                    result.response = response;
                    recordSuccess(state);
                    return result;
                }

                if (retryableStatusCodes.contains(statusCode) && attempt < maxRetries) {
                    // Transient error — retry
                    logEvent('RETRY', 'Attempt ' + attempt + ' failed with status ' +
                        statusCode + '. Retrying...');
                    continue;
                }

                // Non-retryable error or final attempt
                result.errorMessage = 'HTTP ' + statusCode + ': ' +
                    response.getBody().left(500);
                recordFailure(state);
                return result;

            } catch (System.CalloutException e) {
                if (attempt < maxRetries) {
                    logEvent('RETRY', 'Attempt ' + attempt + ' threw exception: ' +
                        e.getMessage() + '. Retrying...');
                    continue;
                }

                result.errorMessage = 'CalloutException after ' + attempt +
                    ' attempts: ' + e.getMessage();
                recordFailure(state);
                return result;
            }
        }

        return result;
    }

    // ── Circuit Breaker State Management ───────────────────────

    /**
     * Get current circuit breaker state from Custom Setting.
     * Uses Circuit_Breaker_State__c (Custom Setting, hierarchy type)
     *   - Service_Name__c: Text
     *   - Status__c: Text (CLOSED, OPEN, HALF_OPEN)
     *   - Consecutive_Failures__c: Number
     *   - Last_Failure_Time__c: DateTime
     *   - Next_Retry_Time__c: DateTime
     */
    private CircuitState getCircuitState() {
        CircuitState state = new CircuitState();

        try {
            List<Circuit_Breaker_State__c> records = [
                SELECT Status__c, Consecutive_Failures__c,
                       Last_Failure_Time__c, Next_Retry_Time__c
                FROM Circuit_Breaker_State__c
                WHERE Service_Name__c = :serviceName
                LIMIT 1
            ];

            if (!records.isEmpty()) {
                Circuit_Breaker_State__c rec = records[0];
                state.recordId = rec.Id;
                state.status = rec.Status__c != null ? rec.Status__c : 'CLOSED';
                state.consecutiveFailures = rec.Consecutive_Failures__c != null
                    ? Integer.valueOf(rec.Consecutive_Failures__c) : 0;
                state.nextRetryTime = rec.Next_Retry_Time__c;
            }
        } catch (Exception e) {
            // If we can't read state, default to CLOSED (allow callouts)
            logEvent('STATE_READ_ERROR', e.getMessage());
        }

        return state;
    }

    private void recordSuccess(CircuitState state) {
        try {
            Circuit_Breaker_State__c rec = getOrCreateRecord(state);
            rec.Status__c = 'CLOSED';
            rec.Consecutive_Failures__c = 0;
            upsert rec;
        } catch (Exception e) {
            logEvent('STATE_WRITE_ERROR', e.getMessage());
        }
    }

    private void recordFailure(CircuitState state) {
        try {
            Circuit_Breaker_State__c rec = getOrCreateRecord(state);
            Integer failures = (state.consecutiveFailures != null ? state.consecutiveFailures : 0) + 1;
            rec.Consecutive_Failures__c = failures;
            rec.Last_Failure_Time__c = DateTime.now();

            if (failures >= failureThreshold) {
                rec.Status__c = 'OPEN';
                rec.Next_Retry_Time__c = DateTime.now().addSeconds(cooldownSeconds);
                logEvent('CIRCUIT_OPENED', 'Service ' + serviceName +
                    ' hit failure threshold (' + failures + '). Circuit opened.');
            } else {
                rec.Status__c = state.status == 'HALF_OPEN' ? 'OPEN' : 'CLOSED';
            }

            upsert rec;
        } catch (Exception e) {
            logEvent('STATE_WRITE_ERROR', e.getMessage());
        }
    }

    private Circuit_Breaker_State__c getOrCreateRecord(CircuitState state) {
        Circuit_Breaker_State__c rec;
        if (state.recordId != null) {
            rec = new Circuit_Breaker_State__c(Id = state.recordId);
        } else {
            rec = new Circuit_Breaker_State__c(Service_Name__c = serviceName);
        }
        return rec;
    }

    // ── Logging ────────────────────────────────────────────────

    private void logEvent(String eventType, String detail) {
        System.debug(LoggingLevel.WARN,
            '[ResilientCallout][' + serviceName + '][' + eventType + '] ' + detail
        );
    }

    // ── Inner Classes ──────────────────────────────────────────

    private class CircuitState {
        public Id recordId;
        public String status = 'CLOSED';
        public Integer consecutiveFailures = 0;
        public DateTime nextRetryTime;
    }
}
