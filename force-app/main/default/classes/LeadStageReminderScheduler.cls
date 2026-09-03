/**
 * Schedules Lead stage owner reminder emails daily at 08:00 org time
 * (6-day WIP / 90-day Future Prospect).
 */
public without sharing class LeadStageReminderScheduler implements Schedulable {

    public static final String JOB_NAME = 'Lead Stage Owner Reminders Daily 8AM';
    public static final String CRON_8AM = '0 0 8 * * ?';

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new LeadStageReminderBatch(), 200);
    }

    public static String scheduleDailyAt8Am() {
        abortExistingJobs();
        return System.schedule(JOB_NAME, CRON_8AM, new LeadStageReminderScheduler());
    }

    public static void abortExistingJobs() {
        for (CronTrigger ct : [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
               OR CronJobDetail.Name LIKE 'Lead Stage Test Reminder %'
        ]) {
            System.abortJob(ct.Id);
        }
    }
}