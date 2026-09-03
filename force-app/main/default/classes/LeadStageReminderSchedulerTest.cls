@IsTest
public class LeadStageReminderSchedulerTest {

    @IsTest
    static void testSchedulerExecution() {
        Test.startTest();
        // Schedule the job directly
        String cronExp = '0 0 8 * * ?';
        String jobId = System.schedule('Test Lead Stage Reminders Daily 8AM', cronExp, new LeadStageReminderScheduler());
        Test.stopTest();

        // Verify the job was scheduled
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should match');
        System.assertEquals(0, ct.TimesTriggered, 'Job should not have triggered yet');
    }
    
    @IsTest
    static void testScheduleDailyAt8Am() {
        // Test the static utility method
        Test.startTest();
        String jobId = LeadStageReminderScheduler.scheduleDailyAt8Am();
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Job ID should be returned from scheduling');
        
        // Verify abort logic works by scheduling again
        String jobId2 = LeadStageReminderScheduler.scheduleDailyAt8Am();
        System.assertNotEquals(null, jobId2, 'Second schedule attempt should succeed');
        System.assertNotEquals(jobId, jobId2, 'A new job ID should be generated after aborting the old one');
    }
}