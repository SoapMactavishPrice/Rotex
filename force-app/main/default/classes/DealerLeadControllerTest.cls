@isTest
public class DealerLeadControllerTest {

    private static User getUserWithRole() {
        List<User> internalUsers = [
            SELECT Id
            FROM User
            WHERE UserRoleId != null
              AND IsActive = true
              AND UserType = 'Standard'
            LIMIT 1
        ];

        if (!internalUsers.isEmpty()) {
            return internalUsers[0];
        }

        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator'
              AND IsActive = true
              AND UserRoleId != null
            LIMIT 1
        ];
    }

    private static Account createDealerAccount(String name) {
        Account dealer = new Account(
            Name = name,
            OwnerId = getUserWithRole().Id
        );
        insert dealer;
        return dealer;
    }
    
    @testSetup
    static void setupData() {
        Account acc = createDealerAccount('Test Dealer Account');
        
        // Create a Lead
        Lead l = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            Dealer__c = acc.Id
        );
        insert l;
    }

    @isTest
    static void testGetMyAssignedLeads() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        l.OwnerId = UserInfo.getUserId();
        update l;

        Test.startTest();
        List<Lead> leads = DealerLeadController.getMyAssignedLeads();
        Test.stopTest();
        
        System.assertEquals(1, leads.size(), 'Should return lead owned by current user');
    }

    @isTest
    static void testGetLeadsByDealerAccount_WithDealerUser() {
        Account dealer = createDealerAccount('Dealer Lead Portal');
        Lead dealerLead = new Lead(
            LastName = 'Dealer Lead',
            Company = 'Dealer Lead Co',
            Status = 'Open - Not Contacted',
            Dealer__c = dealer.Id
        );
        insert dealerLead;

        List<Profile> partnerProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name IN ('Partner Community User', 'Partner Community Login User')
            LIMIT 1
        ];

        if (partnerProfiles.isEmpty()) {
            return;
        }

        Contact con = new Contact(LastName = 'Dealer Contact', AccountId = dealer.Id);
        insert con;

        String unique = String.valueOf(System.currentTimeMillis());
        User partnerUser = new User(
            FirstName = 'Dealer',
            LastName = 'Portal',
            Email = 'dealer' + unique + '@test.com',
            Username = 'dealer' + unique + '@test.com',
            Alias = unique.left(8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = partnerProfiles[0].Id,
            ContactId = con.Id
        );

        Test.startTest();
        insert partnerUser;
        Test.stopTest();

        System.runAs(partnerUser) {
            List<Lead> leads = DealerLeadController.getLeadsByDealerAccount();
            System.assert(leads.size() >= 1, 'Dealer user should see assigned dealer leads');
        }
    }

    @isTest
    static void testGetLeadsByDealerAccount_PortalUser() {
        // Query an existing Portal/Community User (User records are visible in tests without SeeAllData)
        List<User> portalUsers = [
            SELECT Id, AccountId 
            FROM User 
            WHERE AccountId != null AND IsActive = true 
            LIMIT 1
        ];
        
        if (!portalUsers.isEmpty()) {
            System.runAs(portalUsers[0]) {
                Test.startTest();
                List<Lead> leads = DealerLeadController.getLeadsByDealerAccount();
                Test.stopTest();
                
                System.assertNotEquals(null, leads, 'Should return leads or empty list for the dealer');
            }
        }
    }
    
    @isTest
    static void testGetLeadsByDealerAccount_StandardUser() {
        Test.startTest();
        // Running as standard user (UserInfo.getUserId() has no AccountId)
        List<Lead> leads = DealerLeadController.getLeadsByDealerAccount();
        Test.stopTest();
        
        System.assertEquals(0, leads.size(), 'Standard user should have no dealer leads');
    }

    @isTest
    static void testUpdateLeadStatus() {
        Lead l = [SELECT Id, Status FROM Lead LIMIT 1];
        
        Test.startTest();
        DealerLeadController.updateLeadStatus(l.Id, 'Closed - Converted');
        Test.stopTest();
        
        Lead updatedLead = [SELECT Status FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Closed - Converted', updatedLead.Status, 'Lead status should be updated successfully');
    }
}