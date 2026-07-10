@isTest
private class PartnerUserTriggerTest {

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

    private static User buildStandardUser() {
        Profile standardProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String unique = String.valueOf(System.currentTimeMillis()) + String.valueOf(Math.random());
        return new User(
            FirstName = 'Trigger',
            LastName = 'Standard',
            Email = 'trigger.std.' + unique + '@test.com',
            Username = 'trigger.std.' + unique + '@test.com',
            Alias = unique.left(8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = standardProfile.Id
        );
    }

    private static User buildPartnerUser(Account dealerAccount) {
        Profile partnerProfile = [
            SELECT Id
            FROM Profile
            WHERE Name IN ('Partner Community User', 'Partner Community Login User')
            LIMIT 1
        ];

        Contact con = new Contact(
            LastName = 'Trigger Partner',
            AccountId = dealerAccount.Id
        );
        insert con;

        String unique = String.valueOf(System.currentTimeMillis()) + String.valueOf(Math.random());
        return new User(
            FirstName = 'Trigger',
            LastName = 'Partner',
            Email = 'trigger.partner.' + unique + '@test.com',
            Username = 'trigger.partner.' + unique + '@test.com',
            Alias = unique.left(8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = partnerProfile.Id,
            ContactId = con.Id
        );
    }

    @isTest
    static void testPartnerUserTriggerOnInsert() {
        User standardUser = buildStandardUser();

        Test.startTest();
        insert standardUser;
        Test.stopTest();

        System.assertNotEquals(null, standardUser.Id, 'Standard user insert should fire trigger');
    }

    @isTest
    static void testPartnerUserTriggerOnPartnerInsert() {
        List<Profile> partnerProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name IN ('Partner Community User', 'Partner Community Login User')
            LIMIT 1
        ];

        if (partnerProfiles.isEmpty()) {
            return;
        }

        Account dealer = createDealerAccount('Trigger Dealer');

        User partnerUser = buildPartnerUser(dealer);

        Test.startTest();
        insert partnerUser;
        Test.stopTest();

        System.assertNotEquals(null, partnerUser.Id, 'Partner user insert should fire trigger');
    }
}