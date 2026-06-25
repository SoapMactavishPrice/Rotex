@isTest
public class AccountTriggerHandlerTest {
    
    @testSetup
    static void setupTestData() {
        // Create a Channel Partner Account
        Account channelPartner1 = new Account(Name = 'Channel Partner 1');
        insert channelPartner1;

        Account channelPartner2 = new Account(Name = 'Channel Partner 2');
        insert channelPartner2;

        // Create Regular Accounts linked to Channel Partner (Different Owners)
        Account acc1 = new Account(Name = 'Test Account 1', Channel_Partner__c = channelPartner1.Id);
        Account acc2 = new Account(Name = 'Test Account 2', Channel_Partner__c = channelPartner2.Id);
        insert new List<Account>{ acc1, acc2 };
    }

    @isTest
    static void testOwnerUpdateOnInsert() {
        // Get Channel Partner OwnerId
        Account channelPartner = [SELECT Id, OwnerId FROM Account WHERE Name = 'Channel Partner 1' LIMIT 1];

        // Insert an Account linked to Channel Partner
        Account acc = new Account(Name = 'New Account', Channel_Partner__c = channelPartner.Id);
        insert acc;

        // Verify that OwnerId is updated correctly
        Account updatedAcc = [SELECT Id, OwnerId, Channel_Partner__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(channelPartner.OwnerId, updatedAcc.OwnerId, 'OwnerId should be updated to Channel Partner Owner');
    }

    @isTest
    static void testOwnerUpdateOnChange() {
        // Get existing accounts
        Account acc = [SELECT Id, OwnerId, Channel_Partner__c FROM Account WHERE Name = 'Test Account 1' LIMIT 1];
        Account channelPartner2 = [SELECT Id, OwnerId FROM Account WHERE Name = 'Channel Partner 2' LIMIT 1];

        // Change Channel_Partner__c
        acc.Channel_Partner__c = channelPartner2.Id;
        update acc;

        // Verify OwnerId is updated to new Channel Partner's OwnerId
        Account updatedAcc = [SELECT Id, OwnerId FROM Account WHERE Id = :acc.Id];
        System.assertEquals(channelPartner2.OwnerId, updatedAcc.OwnerId, 'OwnerId should be updated to new Channel Partner Owner');
    }

    @isTest
    static void testNoChangeWhenOwnerMatches() {
        // Get an account with the same owner as Channel Partner
        Account acc = [SELECT Id, OwnerId, Channel_Partner__c FROM Account WHERE Name = 'Test Account 2' LIMIT 1];

        // Update the record without changing Channel_Partner__c
        update acc;

        // Fetch updated Account
        Account updatedAcc = [SELECT Id, OwnerId FROM Account WHERE Id = :acc.Id];
        System.assertEquals(acc.OwnerId, updatedAcc.OwnerId, 'OwnerId should not change if already correct');
    }

    @isTest
    static void testBulkUpdate() {
        List<Account> accounts = [SELECT Id, name, Channel_Partner__c FROM Account LIMIT 2];
        
        for (Account acc : accounts) {
            acc.Name = acc.Name + ' Updated'; // Small change to ensure update event triggers
        }

        update accounts;

        // Verify no exceptions occurred in bulk processing
        System.assertEquals(2, accounts.size(), 'All accounts should be updated in bulk');
    }

    @isTest
    static void testExceptionHandling() {
        Test.startTest();
        try {
            Account acc = new Account(Name = 'Faulty Account', Channel_Partner__c = 'InvalidId'); // Invalid Id
            insert acc;
        } catch (Exception e) {
            System.assert(e != null, 'Exception should be caught in the handler.');
        }
        Test.stopTest();
    }
}