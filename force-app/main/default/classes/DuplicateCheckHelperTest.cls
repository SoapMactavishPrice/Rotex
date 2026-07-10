@isTest
public class DuplicateCheckHelperTest {
    
    @isTest
    static void testFindGstPinDuplicate() {
        // Generate a random suffix to avoid standard Duplicate Rule failures on Account Name
        String uniqueSuffix = String.valueOf(Crypto.getRandomInteger());
        
        // Create an Account with specific GST and Pin Code
        Account acc = new Account(
            Name = 'Test Duplicate Account ' + uniqueSuffix,
            GST_No__c = '22AAAAA0000A1Z5'
        );
        if (Schema.SObjectType.Account.fields.getMap().containsKey('Postal_Code__c')) {
            acc.put('Postal_Code__c', '110001');
        } else {
            acc.put('Pin_Code__c', '110001');
        }
        insert acc;
        
        Test.startTest();
        
        // 1. Test finding a duplicate (should return the account we just inserted)
        // Passing null for excludeId to ensure it finds the record
        Account foundAcc = DuplicateCheckHelper.findGstPinDuplicate('22AAAAA0000A1Z5', '110001', null);
        System.assertNotEquals(null, foundAcc, 'Should find the existing duplicate account');
        System.assertEquals(acc.Id, foundAcc.Id, 'Found account ID should match the inserted account');
        
        // 2. Test excluding the account (should return null)
        // Passing the inserted Account's Id to exclude it from the search
        Account excludedAcc = DuplicateCheckHelper.findGstPinDuplicate('22AAAAA0000A1Z5', '110001', acc.Id);
        System.assertEquals(null, excludedAcc, 'Should return null because the only match is excluded');
        
        // 3. Test non-existent duplicate (should return null)
        Account notFoundAcc = DuplicateCheckHelper.findGstPinDuplicate('00XXXXX0000X0X0', '999999', null);
        System.assertEquals(null, notFoundAcc, 'Should return null for non-existent GST and PinCode');
        
        Test.stopTest();
    }
}