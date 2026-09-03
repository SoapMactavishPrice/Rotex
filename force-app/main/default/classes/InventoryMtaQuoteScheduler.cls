/**
 * Schedules daily MTA quote creation at 5:00 PM (org timezone: Asia/Kolkata).
 */
public without sharing class InventoryMtaQuoteScheduler implements Schedulable {

    public static final String JOB_NAME = 'Inventory MTA Quotes Daily 5PM';
    /** Cron: every day at 17:00:00 in the org timezone. */
    public static final String CRON_5PM = '0 0 17 * * ?';

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new InventoryMtaQuoteBatch(), 1);
    }

    /**
     * Registers (or re-registers) the daily 5:00 PM job.
     * Safe to call multiple times — removes any existing job with the same name first.
     */
    public static String scheduleDailyAt5Pm() {
        abortExistingJobs();
        return System.schedule(JOB_NAME, CRON_5PM, new InventoryMtaQuoteScheduler());
    }

    public static void abortExistingJobs() {
        Set<String> jobNames = new Set<String>{
            JOB_NAME,
            'Inventory MTA Quotes Daily 5:30PM'
        };
        for (CronTrigger ct : [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name IN :jobNames
        ]) {
            System.abortJob(ct.Id);
        }
    }
}