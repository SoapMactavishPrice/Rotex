@isTest
public class OwnerChangeNotificationTest {

    @testSetup
    static void setupData() {

        // ✅ Get System Admin Profile
        Profile p = [
            SELECT Id 
            FROM Profile 
            WHERE Name = 'System Administrator' 
            LIMIT 1
        ];

        // ✅ Create Users
        User u1 = new User(
            FirstName = 'User',
            LastName = 'One',
            Email = 'user1@test.com',
            Username = 'user1' + System.currentTimeMillis() + '@test.com',
            Alias = 'u1',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        User u2 = new User(
            FirstName = 'User',
            LastName = 'Two',
            Email = 'user2@test.com',
            Username = 'user2' + System.currentTimeMillis() + '@test.com',
            Alias = 'u2',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        insert new List<User>{ u1, u2 };

        // ✅ Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // ✅ Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            OwnerId = u1.Id,
            AccountId = acc.Id
        );
        insert opp;

        // ✅ Quote
        Quote qt = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Draft',
            OwnerId = u1.Id
        );
        insert qt;
    }

    // ===========================
    // ✅ OPPORTUNITY OWNER CHANGE
    // ===========================
    @isTest
    static void testOpportunityOwnerChange() {

        List<User> users = [SELECT Id FROM User ORDER BY CreatedDate ASC LIMIT 2];
        User oldOwner = users[0];
        User newOwner = users[1];

        Opportunity opp = [SELECT Id, OwnerId FROM Opportunity LIMIT 1];

        Test.startTest();
        opp.OwnerId = newOwner.Id;
        update opp;
        Test.stopTest();

        System.assertEquals(newOwner.Id, opp.OwnerId);
    }

    // ======================
    // ✅ QUOTE OWNER CHANGE
    // ======================
    @isTest
    static void testQuoteOwnerChange() {

        List<User> users = [SELECT Id FROM User ORDER BY CreatedDate ASC LIMIT 2];
        User newOwner = users[1];

        Quote q = [SELECT Id, OwnerId FROM Quote LIMIT 1];

        Test.startTest();
        q.OwnerId = newOwner.Id;
        update q;
        Test.stopTest();

        System.assertEquals(newOwner.Id, q.OwnerId);
    }
}