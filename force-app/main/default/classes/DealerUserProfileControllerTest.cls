@IsTest
private class DealerUserProfileControllerTest {
    
    @IsTest
    static void testGetProfilePhotoNoPhoto() {
        Test.startTest();
        DealerUserProfileController.ProfilePhotoInfo info = DealerUserProfileController.getMyProfilePhoto();
        System.assertNotEquals(null, info);
        System.assertEquals(false, info.hasPhoto);
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveProfilePhotoSuccess() {
        Test.startTest();
        DealerUserProfileController.ProfilePhotoInfo info = DealerUserProfileController.saveMyProfilePhoto('test.png', 'VGVzdA==');
        System.assertNotEquals(null, info);
        System.assertEquals(true, info.hasPhoto);
        System.assertEquals('test.png', info.fileName);
        
        // Test get photo after saving
        DealerUserProfileController.ProfilePhotoInfo info2 = DealerUserProfileController.getMyProfilePhoto();
        System.assertNotEquals(null, info2);
        System.assertEquals(true, info2.hasPhoto);
        
        // Save again to test delete existing profile photos logic
        DealerUserProfileController.ProfilePhotoInfo info3 = DealerUserProfileController.saveMyProfilePhoto('test2.jpg', 'VGVzdA==');
        System.assertEquals(true, info3.hasPhoto);
        System.assertEquals('test2.jpg', info3.fileName);
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveProfilePhotoValidations() {
        Test.startTest();
        
        // 1. Blank base64
        try {
            DealerUserProfileController.saveMyProfilePhoto('test.png', '');
            System.assert(false, 'Should have thrown exception for blank data');
        } catch (Exception e) {
            System.assert(e instanceof System.AuraHandledException, 'Should throw AuraHandledException');
        }
        
        // 2. Invalid extension
        try {
            DealerUserProfileController.saveMyProfilePhoto('test.txt', 'VGVzdA==');
            System.assert(false, 'Should have thrown exception for invalid extension');
        } catch (Exception e) {
            System.assert(e instanceof System.AuraHandledException, 'Should throw AuraHandledException');
        }
        
        // 3. Untitled selection handling (no extension)
        try {
            DealerUserProfileController.ProfilePhotoInfo info = DealerUserProfileController.saveMyProfilePhoto('untitled_image', 'VGVzdA==');
            System.assertEquals(true, info.hasPhoto);
            System.assert(info.fileName.endsWith('.jpg'));
        } catch (Exception e) {
            System.assert(false, 'Should not have thrown exception for untitled image');
        }
        
        Test.stopTest();
    }
}