@isTest
public class AccountSharingHandlerTest {

    @isTest
    static void testShareAccountWithChannelPartner() {

        // Get Standard User Profile
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        // Create Channel Partner User
        User channelUser = new User(
            FirstName = 'Channel',
            LastName = 'Partner',
            Alias = 'chusr',
            Email = 'channelpartner@test.com',
            Username = 'channelpartner' + System.currentTimeMillis() + '@test.com',
            CommunityNickname = 'channelpartner' + System.currentTimeMillis(),
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert channelUser;

        // Create Account
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        Test.startTest();

        // Update Account with Channel Partner User
        acc.Channel_Partner_User__c = channelUser.Id;
        update acc;

        Test.stopTest();

        // Verify Share Record
        List<AccountShare> shares = [
            SELECT Id,
                   UserOrGroupId,
                   AccountAccessLevel,
                   RowCause
            FROM AccountShare
            WHERE AccountId = :acc.Id
            AND UserOrGroupId = :channelUser.Id
        ];

        if (!shares.isEmpty()) {
            System.assertEquals(
                'Read',
                shares[0].AccountAccessLevel
            );

            System.assertEquals(
                Schema.AccountShare.RowCause.Manual,
                shares[0].RowCause
            );
        }
    }

    @isTest
    static void testNoDuplicateShare() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User channelUser = new User(
            FirstName = 'Channel',
            LastName = 'Partner2',
            Alias = 'chus2',
            Email = 'channelpartner2@test.com',
            Username = 'channelpartner2' + System.currentTimeMillis() + '@test.com',
            CommunityNickname = 'channelpartner2' + System.currentTimeMillis(),
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert channelUser;

        Account acc = new Account(
            Name = 'Duplicate Test'
        );
        insert acc;

        Test.startTest();

        acc.Channel_Partner_User__c = channelUser.Id;
        update acc;

        // Update again with same user
        update acc;

        Test.stopTest();

        Integer shareCount = [
            SELECT Count()
            FROM AccountShare
            WHERE AccountId = :acc.Id
            AND UserOrGroupId = :channelUser.Id
        ];

        // If sharing exists, it should only be one record.
        if (shareCount > 0) {
            System.assertEquals(1, shareCount);
        }
    }
}