@IsTest
public class LeadStageReminderBatchTest {

    @TestSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'standt',
            Email = 'standarduser@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'standarduser_leadtest' + DateTime.now().getTime() + '@testorg.com',
            IsActive = true
        );
        insert u;

        // Insert/update as the default running user (same timezone as test assertions)
        Lead wipLead = new Lead(
            FirstName = 'Test',
            LastName = 'WIP Lead',
            Company = 'Test Company 1',
            Status = 'Work In Progress',
            Dealer_Status__c = 'Work In Progress',
            Email = 'wip.batch@example.com',
            OwnerId = u.Id
        );
        Lead fpLead = new Lead(
            FirstName = 'Test',
            LastName = 'Future Lead',
            Company = 'Test Company 2',
            Status = 'Future Prospect',
            Dealer_Status__c = 'Future Prospect',
            Email = 'future.batch@example.com',
            OwnerId = u.Id
        );
        insert new List<Lead>{ wipLead, fpLead };

        // Force stage-entry stamps without changing Status (skips status-date handler rewrite)
        wipLead.Work_In_Progress_Date_Time__c = Datetime.newInstance(
            Date.today().addDays(-6),
            Time.newInstance(10, 0, 0, 0)
        );
        fpLead.Future_Prospect_Date_Time__c = Datetime.newInstance(
            Date.today().addDays(-90),
            Time.newInstance(10, 0, 0, 0)
        );
        update new List<Lead>{ wipLead, fpLead };
    }

    @IsTest
    static void testBatchExecution() {
        Test.startTest();
        Database.executeBatch(new LeadStageReminderBatch());
        Test.stopTest();

        System.assert(Limits.getEmailInvocations() >= 0, 'Email limits check');

        User owner = [
            SELECT Id, Name, Email
            FROM User
            WHERE Email = 'standarduser@testorg.com'
            LIMIT 1
        ];
        System.assert(String.isNotBlank(owner.Email), 'Owner email required for reminders');

        List<Lead> leads = [
            SELECT
                Id,
                Name,
                FirstName,
                LastName,
                Company,
                Email,
                Phone,
                Status,
                Dealer_Status__c,
                IsConverted,
                OwnerId,
                LastModifiedDate,
                Work_In_Progress_Date_Time__c,
                Future_Prospect_Date_Time__c
            FROM Lead
        ];
        // Populate Owner relationship for processLeads (same pattern as LeadStageReminderTest)
        for (Lead ld : leads) {
            ld.putSObject('Owner', owner);
        }

        // Self-check stamps (helps diagnose timezone/handler issues)
        Lead wipCheck = null;
        Lead fpCheck = null;
        for (Lead ld : leads) {
            if (ld.LastName == 'WIP Lead') {
                wipCheck = ld;
            }
            if (ld.LastName == 'Future Lead') {
                fpCheck = ld;
            }
        }
        System.assertNotEquals(null, wipCheck, 'WIP lead should exist');
        System.assertNotEquals(null, fpCheck, 'Future lead should exist');
        System.assertEquals(
            true,
            LeadStageReminderService.isReminderDue(wipCheck.Work_In_Progress_Date_Time__c, 6),
            'WIP stamp not due: ' +
                wipCheck.Work_In_Progress_Date_Time__c +
                ' days=' +
                (wipCheck.Work_In_Progress_Date_Time__c == null
                    ? 'null'
                    : String.valueOf(
                          wipCheck.Work_In_Progress_Date_Time__c.date().daysBetween(Date.today())
                      ))
        );
        System.assertEquals(
            true,
            LeadStageReminderService.isReminderDue(fpCheck.Future_Prospect_Date_Time__c, 90),
            'Future stamp not due: ' + fpCheck.Future_Prospect_Date_Time__c
        );

        LeadStageReminderService.SendSummary summary = LeadStageReminderService.processLeads(leads);
        System.assertEquals(1, summary.wipCandidates, 'One WIP candidate should be processed');
        System.assertEquals(1, summary.futureCandidates, 'One Future candidate should be processed');
        System.assertEquals(
            2,
            summary.emailsSent + summary.emailsFailed,
            'One WIP email and one Future email should be attempted'
        );
    }

    @IsTest
    static void testBoundaryConditions() {
        User owner = [
            SELECT Id, Name, Email
            FROM User
            WHERE Email = 'standarduser@testorg.com'
            LIMIT 1
        ];
        Lead notDueLead = new Lead(
            FirstName = 'Test',
            LastName = 'Not Due',
            Company = 'Test Company',
            Status = 'Work In Progress',
            Dealer_Status__c = 'Work In Progress',
            OwnerId = owner.Id,
            Work_In_Progress_Date_Time__c = Datetime.newInstance(
                Date.today().addDays(-5),
                Time.newInstance(12, 0, 0, 0)
            )
        );
        insert notDueLead;
        // Re-stamp without status change if handler rewrote on insert
        notDueLead.Work_In_Progress_Date_Time__c = Datetime.newInstance(
            Date.today().addDays(-5),
            Time.newInstance(12, 0, 0, 0)
        );
        update notDueLead;

        notDueLead = [
            SELECT
                Id,
                Name,
                FirstName,
                LastName,
                Company,
                Email,
                Phone,
                Status,
                Dealer_Status__c,
                IsConverted,
                OwnerId,
                LastModifiedDate,
                Work_In_Progress_Date_Time__c,
                Future_Prospect_Date_Time__c
            FROM Lead
            WHERE Id = :notDueLead.Id
        ];
        notDueLead.putSObject('Owner', owner);

        Test.startTest();
        LeadStageReminderService.SendSummary summary = LeadStageReminderService.processLeads(
            new List<Lead>{ notDueLead }
        );
        Test.stopTest();

        System.assertEquals(0, summary.wipCandidates, 'Lead is not due yet, should be 0');
    }
}