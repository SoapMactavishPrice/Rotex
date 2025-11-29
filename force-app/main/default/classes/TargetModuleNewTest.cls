@isTest
public class TargetModuleNewTest {

    @testSetup
    static void setupData() {
        // Create Fiscal Year record
        Fiscal_Year__c fy = new Fiscal_Year__c(
            Name = 'FY2025'
            //isActive__c = true
        );
        insert fy;

        // Get Standard User Profile ID
        Id profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;

        // Create unique timestamp for usernames
        String uniqueSuffix = String.valueOf(Datetime.now().getTime());

        // Create Manager User
        User managerUser = new User(
            FirstName = 'Manager',
            LastName = 'User',
            Alias = 'mgr' + uniqueSuffix.substring(8),
            Email = 'manager' + uniqueSuffix + '@example.com',
            Username = 'manager' + uniqueSuffix + '@test.com',
            CommunityNickname = 'manager' + uniqueSuffix,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profileId,
            LanguageLocaleKey = 'en_US'
        );
        insert managerUser;

        // Create Sales Rep User
        User ownerUser = new User(
            FirstName = 'Sales',
            LastName = 'Rep',
            Alias = 'srep',
            Email = 'salesrep' + uniqueSuffix + '@example.com',
            Username = 'salesrep' + uniqueSuffix + '@test.com',
            CommunityNickname = 'salesrep' + uniqueSuffix,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profileId,
            LanguageLocaleKey = 'en_US',
            ManagerId = managerUser.Id
        );
        insert ownerUser;

        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
            OwnerId = ownerUser.Id
        );
        insert acc;

        // Create Target__c record
        Target__c targetRec = new Target__c(
            Customer_Name__c = acc.Id,
            Fiscal_Year__c = fy.Id,
            Qtr_1_Target__c = 10,
            Qtr_2_Target__c = 20,
            Qtr_3_Target__c = 30,
            Qtr_4_Target__c = 40,
            //Total_Target__c = 100,
            Total_Actual__c = 90,
            Reporting_Manager__c = managerUser.Id,
            Total_Visits_Per_Year__c = 50,
            Actual_Visits_Per_Year__c = 45
        );
        insert targetRec;
    }

    /*@isTest
    static void testGetDefaultFilterValues() {
        Test.startTest();
        String result = TargetModuleNew.getDefaultFilterValues();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('Fiscal_Year__c'), 'Should contain Fiscal_Year__c');
    }*/

    @isTest
    static void testGetAccounts() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Account> accList = TargetModuleNew.getAccounts(acc.Id, 5);
        Test.stopTest();
        System.assertNotEquals(null, accList, 'List should not be null');
    }

    @isTest
    static void testSaveTargetModuleRecords() {
        Target__c newTarget = new Target__c(
            Customer_Name__c = [SELECT Id FROM Account LIMIT 1].Id,
            Fiscal_Year__c = [SELECT Id FROM Fiscal_Year__c LIMIT 1].Id,
            Qtr_1_Target__c = 15
        );
        Test.startTest();
        TargetModuleNew.saveTargetModuleRecords(new List<Target__c>{ newTarget });
        Test.stopTest();
        System.assert([SELECT COUNT() FROM Target__c] > 0, 'Target__c record should be inserted');
    }

    @isTest
    static void testGetExistingTargetModules() {
        Id fiscalId = [SELECT Id FROM Fiscal_Year__c LIMIT 1].Id;
        List<Id> accIds = new List<Id>{ [SELECT Id FROM Account LIMIT 1].Id };
        Test.startTest();
        Map<Id, Target__c> existingTargets = TargetModuleNew.getExistingTargetModules(accIds, fiscalId);
        Test.stopTest();
        System.assertNotEquals(null, existingTargets, 'Result should not be null');
        System.assert(existingTargets.size() > 0, 'Existing map should have at least one record');
    }
}