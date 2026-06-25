@isTest
public class TargetTriggerTest {
    
    @testSetup
    static void setupTestData() {
        // Create Users for Sales Rep and Reporting Manager
        Profile p = [SELECT Id FROM Profile WHERE Name='Manager' LIMIT 1];
        
        User salesRep = new User(
            Alias = 'salesrep',
            Email='salesrep@example.com',
            EmailEncodingKey='UTF-8',
            LastName='SalesRep',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName='salesrep31545@testorg.com'
        );
        insert salesRep;
        
        User reportingManager = new User(
            Alias = 'manager',
            Email='manager@example.com',
            EmailEncodingKey='UTF-8',
            LastName='ReportingManager',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName='managere556234@testorg.com'
        );
        insert reportingManager;
        
        // Store IDs for tests
        //Test.setCurrentUser(salesRep.Id);
        // For accessing users in tests, use static variables or queries within test methods as needed
    }
    
    @isTest
    static void testOwnerCopyOnInsert() {
        User salesRep = [SELECT Id, User.ProfileId FROM User WHERE Alias = 'salesrep' LIMIT 1];
        
        Target__c targetRec = new Target__c(
            //Name = 'Test Target',
            Sales_Rep__c = salesRep.Id
        );
        
        Test.startTest();
        insert targetRec;
        Test.stopTest();
        
        // Verify OwnerId was set to Sales_Rep__c
        Target__c insertedTarget = [SELECT OwnerId, Sales_Rep__c FROM Target__c WHERE Id = :targetRec.Id];
        System.assertEquals(salesRep.Id, insertedTarget.OwnerId, 'OwnerId should be set to Sales_Rep__c');
    }
    
    @isTest
    static void testSharingWithReportingManagerOnInsertAndUpdate() {
        User salesRep = [SELECT Id, User.ProfileId FROM User WHERE Alias = 'salesrep' LIMIT 1];
        User reportingManager = [SELECT Id, User.ProfileId FROM User WHERE Alias = 'manager' LIMIT 1];
        
        Target__c targetRec = new Target__c(
            //Name = 'Test Target For Sharing',
            Sales_Rep__c = salesRep.Id,
            Reporting_Manager__c = reportingManager.Id
        );
        
        Test.startTest();
        insert targetRec;
        Test.stopTest();
        
        // Check if Target__Share record created for Reporting_Manager__c
        List<Target__Share> shares = [
            SELECT UserOrGroupId, ParentId, AccessLevel 
            FROM Target__Share 
            WHERE ParentId = :targetRec.Id AND UserOrGroupId = :reportingManager.Id];
        
        System.assert(shares.size() > 0, 'Sharing record should be created for Reporting Manager');
        
        // Now update Reporting_Manager__c to a new user and test sharing on update
        User newReportingManager = new User(
            Alias = 'newman',
            Email='newman@example.com',
            EmailEncodingKey='UTF-8',
            LastName='NewManager',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = reportingManager.ProfileId,
            TimeZoneSidKey='America/Los_Angeles',
            UserName='newman13436@testorg.com'
        );
        insert newReportingManager;
        
        targetRec.Reporting_Manager__c = newReportingManager.Id;
        
        //Test.startTest();
        update targetRec;
        //Test.stopTest();
        
        List<Target__Share> newShares = [
            SELECT UserOrGroupId, ParentId 
            FROM Target__Share 
            WHERE ParentId = :targetRec.Id AND UserOrGroupId = :newReportingManager.Id];
        
        System.assert(newShares.size() > 0, 'Sharing record should be created for updated Reporting Manager');
    }
}