@isTest
public class LeadSharingHandlerTest {
    
    @testSetup
    static void setupData() {
        // Create creator user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User creator = new User(
            FirstName = 'Creator',
            LastName = 'User',
            Alias = 'cruser',
            Email = 'creator@test.com',
            Username = 'creator@test.com.unit',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert creator;
        
        // Create target user
        User anotherUser = new User(
            FirstName = 'Owner',
            LastName = 'User',
            Alias = 'owuser',
            Email = 'owner@test.com',
            Username = 'owner@test.com.unit',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert anotherUser;
    }
    
    @isTest
    static void testLeadSharingOnOwnerChange() {
        
        // Get created test users
        User creator = [SELECT Id FROM User WHERE Username LIKE 'creator%@test.com.unit' LIMIT 1];
        User anotherUser = [SELECT Id FROM User WHERE Username LIKE 'owner%@test.com.unit' LIMIT 1];
        
        System.runAs(creator) {
            
            Lead testLead = new Lead(
                LastName = 'Test Lead',
                Company = 'Test Company',
                OwnerId = creator.Id,
                Lead_Type__c = 'Channel Sales'
                
            );
            insert testLead;
            
            // Transfer ownership
            testLead.OwnerId = anotherUser.Id;
            update testLead;
        }
        
        // Validate sharing created
        LeadShare[] shareRecords = [
            SELECT LeadId, UserOrGroupId, LeadAccessLevel, RowCause
            FROM LeadShare
            WHERE UserOrGroupId = :creator.Id
        ];
        
        
        
    }
}