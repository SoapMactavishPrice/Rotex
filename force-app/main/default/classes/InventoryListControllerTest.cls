@isTest
public class InventoryListControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create an Account
        Account acc = new Account(Name = 'Test Partner Account');
        insert acc;
        
        // Create a Product
        Product2 prod = new Product2(Name = 'Test Product', ProductCode = 'TEST-001', IsActive = true);
        insert prod;
        
        // Create Inventory
        Inventory__c inv = new Inventory__c(
            Channel_Partner__c = acc.Id,
            Product__c = prod.Id,
            Minimum_Order_Quantity__c = 10,
            Minimum_Stock_Level__c = 5
        );
        insert inv;
        
        // Create Inventory Transaction
        Inventory_Transaction__c invTrans = new Inventory_Transaction__c(
            Inventory__c = inv.Id,
            Quantity__c = 100,
            Remarks__c = 'Test Transaction'
        );
        insert invTrans;
    }
    
    @isTest
    static void testGetMyInventories() {
        Test.startTest();
        // Since we are running as an internal user, it will return inventories owned by the current user.
        List<Inventory__c> inventories = InventoryListController.getMyInventories();
        Test.stopTest();
        
        System.assertNotEquals(null, inventories, 'Inventories list should not be null');
        System.assertEquals(1, inventories.size(), 'Should return 1 inventory record');
    }
    
    @isTest
    static void testGetInventoryTransactions() {
        Inventory__c inv = [SELECT Id FROM Inventory__c LIMIT 1];
        
        Test.startTest();
        List<Inventory_Transaction__c> transactions = InventoryListController.getInventoryTransactions(inv.Id);
        Test.stopTest();
        
        System.assertEquals(1, transactions.size(), 'Should return 1 transaction');
        System.assertEquals('Test Transaction', transactions[0].Remarks__c, 'Transaction remarks mismatch');
    }
    
    @isTest
    static void testUpdateInventoryLevelsSuccess() {
        Inventory__c inv = [SELECT Id, Minimum_Order_Quantity__c, Minimum_Stock_Level__c FROM Inventory__c LIMIT 1];
        
        Test.startTest();
        Inventory__c updatedInv = InventoryListController.updateInventoryLevels(inv.Id, 20, 15);
        Test.stopTest();
        
        System.assertEquals(20, updatedInv.Minimum_Order_Quantity__c, 'MOQ should be updated');
        System.assertEquals(15, updatedInv.Minimum_Stock_Level__c, 'MSL should be updated');
    }
    
    @isTest
    static void testUpdateInventoryLevelsException() {
        Test.startTest();
        try {
            InventoryListController.updateInventoryLevels(null, 20, 15);
            System.assert(false, 'Exception should have been thrown for null Inventory Id');
        } catch (Exception e) {
            System.assert(e instanceof AuraHandledException, 'Expected AuraHandledException');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateInventoryLevelsNoAccess() {
        // Create a different user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1]; 
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='standarduser_' + Math.random() + '@testorg.com');
        
        Inventory__c inv = [SELECT Id FROM Inventory__c LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            try {
                // This user is not the owner, so assertInventoryAccessible should fail
                InventoryListController.updateInventoryLevels(inv.Id, 20, 15);
                System.assert(false, 'Exception should have been thrown for lack of access');
            } catch (Exception e) {
                System.assert(e instanceof AuraHandledException, 'Expected AuraHandledException for access check');
                System.assertEquals('Script-thrown exception', e.getMessage());
            }
            Test.stopTest();
        }
    }
}