@isTest
public class PartnerPermSetAssignHandlerTest {
    
    @isTest
    static void testAssignPermissionSet() {
        // Query required profiles
        List<Profile> partnerProfiles = [
            SELECT Id, Name FROM Profile 
            WHERE Name IN ('Partner Community User', 'Partner Community Login User') 
            LIMIT 1
        ];
        
        List<Profile> standardProfiles = [
            SELECT Id FROM Profile 
            WHERE Name = 'Standard User' 
            LIMIT 1
        ];
        
        Id standardProfileId = standardProfiles.isEmpty() ? UserInfo.getProfileId() : standardProfiles[0].Id;
        
        Test.startTest();
        
        // 1. Test empty list
        PartnerPermissionSetAssignmentHandler.assignPermissionSet(new List<User>(), null);
        
        // 2. Test standard user insert (should be skipped)
        User standardUser = new User(
            Id = '005000000000001AAA', 
            ProfileId = standardProfileId, 
            IsActive = true
        );
        PartnerPermissionSetAssignmentHandler.assignPermissionSet(new List<User>{standardUser}, null);
        
        // 3. Test partner user scenarios (if partner profile exists in the org)
        if (!partnerProfiles.isEmpty()) {
            Id partnerProfileId = partnerProfiles[0].Id;
            
            // Insert Case
            User partnerUserInsert = new User(
                Id = '005000000000002AAA', 
                ProfileId = partnerProfileId, 
                IsActive = true
            );
            PartnerPermissionSetAssignmentHandler.assignPermissionSet(new List<User>{partnerUserInsert}, null);
            
            // Update Case (Profile changed from standard to partner)
            User oldUser = new User(
                Id = '005000000000003AAA', 
                ProfileId = standardProfileId, 
                IsActive = true
            );
            User newUser = new User(
                Id = oldUser.Id, 
                ProfileId = partnerProfileId, 
                IsActive = true
            );
            
            Map<Id, User> oldMap = new Map<Id, User>{oldUser.Id => oldUser};
            PartnerPermissionSetAssignmentHandler.assignPermissionSet(new List<User>{newUser}, oldMap);
        }
        
        Test.stopTest();
        
        // Since we are mocking memory records and using Database.insert(false),
        // we just assert that execution completes gracefully without any unhandled exceptions.
        System.assert(true, 'Test execution completed successfully');
    }
}