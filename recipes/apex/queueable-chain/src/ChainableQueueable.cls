/**
 * ChainableQueueable - Process large record sets via chained Queueable jobs.
 *
 * Splits work into configurable chunks, processes each in a separate
 * transaction, and chains to the next. Tracks progress in a custom object
 * for monitoring and resume capability.
 *
 * Usage:
 *   // Start processing all Accounts missing a calculated field
 *   String jobId = ChainableQueueable.start(
 *       'UPDATE_ACCOUNT_SCORES',
 *       'SELECT Id, Name, AnnualRevenue FROM Account WHERE Account_Score__c = null',
 *       200
 *   );
 *
 * @author  Sandip Patel
 * @version 1.0
 */
public class ChainableQueueable implements Queueable, Database.AllowsCallouts {

    // ── Configuration ──────────────────────────────────────────

    private String jobName;
    private String soqlQuery;
    private Integer chunkSize;
    private Integer currentOffset;
    private Id progressRecordId;

    // ── Constructor ────────────────────────────────────────────

    public ChainableQueueable(String jobName, String soqlQuery,
                               Integer chunkSize, Integer currentOffset,
                               Id progressRecordId) {
        this.jobName = jobName;
        this.soqlQuery = soqlQuery;
        this.chunkSize = chunkSize;
        this.currentOffset = currentOffset;
        this.progressRecordId = progressRecordId;
    }

    // ── Static Entry Point ─────────────────────────────────────

    /**
     * Start a new chained processing job.
     *
     * @param jobName    Unique name for tracking this job
     * @param soqlQuery  Base SOQL query (LIMIT/OFFSET will be appended)
     * @param chunkSize  Records per chunk (max 200 recommended)
     * @return           Id of the progress tracking record
     */
    public static String start(String jobName, String soqlQuery, Integer chunkSize) {
        // Count total records
        String countQuery = 'SELECT COUNT() FROM (' + soqlQuery + ')';
        // Simplified: use the query directly to get first batch
        // In production, you'd run a COUNT() query first

        // Create progress tracking record
        Job_Progress__c progress = new Job_Progress__c(
            Job_Name__c = jobName,
            Status__c = 'Running',
            Total_Records__c = 0, // Will be updated after first query
            Processed_Records__c = 0,
            Failed_Records__c = 0,
            Chunk_Size__c = chunkSize,
            Started_At__c = DateTime.now(),
            SOQL_Query__c = soqlQuery.left(255)
        );
        insert progress;

        // Queue the first chunk
        System.enqueueJob(new ChainableQueueable(
            jobName, soqlQuery, chunkSize, 0, progress.Id
        ));

        return progress.Id;
    }

    // ── Queueable Execution ────────────────────────────────────

    public void execute(QueueableContext context) {
        try {
            // Fetch this chunk of records
            String chunkQuery = soqlQuery +
                ' LIMIT ' + chunkSize +
                ' OFFSET ' + currentOffset;

            List<SObject> records = Database.query(chunkQuery);

            if (records.isEmpty()) {
                // All done
                completeJob();
                return;
            }

            // Process this chunk
            ProcessingResult result = processChunk(records);

            // Update progress
            updateProgress(result, records.size());

            // Chain to next chunk
            Integer nextOffset = currentOffset + chunkSize;
            System.enqueueJob(new ChainableQueueable(
                jobName, soqlQuery, chunkSize, nextOffset, progressRecordId
            ));

        } catch (Exception e) {
            handleError(e);
        }
    }

    // ── Processing Logic ───────────────────────────────────────

    /**
     * Process a chunk of records.
     * Override this method in subclasses for custom logic.
     */
    protected virtual ProcessingResult processChunk(List<SObject> records) {
        ProcessingResult result = new ProcessingResult();

        // Example: Route to the right processor based on job name
        if (jobName == 'UPDATE_ACCOUNT_SCORES') {
            result = processAccountScores(records);
        } else if (jobName == 'ENRICH_CONTACTS') {
            result = processContactEnrichment(records);
        } else if (jobName == 'CLEANUP_DUPLICATES') {
            result = processDeduplication(records);
        } else {
            // Default: just count records as processed
            result.successCount = records.size();
        }

        return result;
    }

    // ── Example Processors ─────────────────────────────────────

    private ProcessingResult processAccountScores(List<SObject> records) {
        ProcessingResult result = new ProcessingResult();
        List<Account> toUpdate = new List<Account>();

        for (SObject record : records) {
            Account acc = (Account) record;
            try {
                // Calculate a composite score based on revenue, employees, etc.
                Decimal score = calculateAccountScore(acc);
                acc.put('Account_Score__c', score);
                toUpdate.add(acc);
                result.successCount++;
            } catch (Exception e) {
                result.failureCount++;
                result.errors.add('Account ' + acc.Id + ': ' + e.getMessage());
            }
        }

        if (!toUpdate.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.update(toUpdate, false);
            for (Database.SaveResult sr : saveResults) {
                if (!sr.isSuccess()) {
                    result.successCount--;
                    result.failureCount++;
                    for (Database.Error err : sr.getErrors()) {
                        result.errors.add(err.getMessage());
                    }
                }
            }
        }

        return result;
    }

    private Decimal calculateAccountScore(Account acc) {
        Decimal score = 0;

        // Revenue component (0-40 points)
        Decimal revenue = acc.AnnualRevenue != null ? acc.AnnualRevenue : 0;
        if (revenue >= 10000000) score += 40;
        else if (revenue >= 1000000) score += 30;
        else if (revenue >= 100000) score += 15;
        else score += 5;

        // Additional scoring components would go here
        // (industry, engagement, geography, etc.)

        return Math.min(score, 100);
    }

    private ProcessingResult processContactEnrichment(List<SObject> records) {
        // Placeholder for contact enrichment logic
        ProcessingResult result = new ProcessingResult();
        result.successCount = records.size();
        return result;
    }

    private ProcessingResult processDeduplication(List<SObject> records) {
        // Placeholder for dedup logic
        ProcessingResult result = new ProcessingResult();
        result.successCount = records.size();
        return result;
    }

    // ── Progress Tracking ──────────────────────────────────────

    private void updateProgress(ProcessingResult result, Integer chunkRecordCount) {
        try {
            Job_Progress__c progress = [
                SELECT Processed_Records__c, Failed_Records__c
                FROM Job_Progress__c
                WHERE Id = :progressRecordId
                FOR UPDATE
            ];

            progress.Processed_Records__c =
                (progress.Processed_Records__c != null ? progress.Processed_Records__c : 0)
                + result.successCount;
            progress.Failed_Records__c =
                (progress.Failed_Records__c != null ? progress.Failed_Records__c : 0)
                + result.failureCount;
            progress.Last_Chunk_At__c = DateTime.now();
            progress.Current_Offset__c = currentOffset + chunkSize;

            if (!result.errors.isEmpty()) {
                String errorLog = String.join(result.errors, '\n').left(131072);
                progress.Error_Log__c = errorLog;
            }

            update progress;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[ChainableQueueable] Failed to update progress: ' + e.getMessage());
        }
    }

    private void completeJob() {
        try {
            Job_Progress__c progress = new Job_Progress__c(
                Id = progressRecordId,
                Status__c = 'Completed',
                Completed_At__c = DateTime.now()
            );
            update progress;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[ChainableQueueable] Failed to mark job complete: ' + e.getMessage());
        }
    }

    private void handleError(Exception e) {
        try {
            Job_Progress__c progress = new Job_Progress__c(
                Id = progressRecordId,
                Status__c = 'Failed',
                Error_Log__c = 'Fatal error at offset ' + currentOffset + ': ' +
                    e.getMessage() + '\n' + e.getStackTraceString(),
                Completed_At__c = DateTime.now()
            );
            update progress;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                '[ChainableQueueable] Failed to record error: ' + ex.getMessage());
        }
    }

    // ── Inner Classes ──────────────────────────────────────────

    public class ProcessingResult {
        public Integer successCount = 0;
        public Integer failureCount = 0;
        public List<String> errors = new List<String>();
    }
}
