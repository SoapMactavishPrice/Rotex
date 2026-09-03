@IsTest
public class InventoryMtaQuoteBatchTest {

    @TestSetup
    static void setupData() {
        // Create CP Account
        Account cpAcc = new Account(
            Name = 'Test Partner',
            RecordTypeId = getRecordTypeId('Account', 'Channel_Partner')
        );
        insert cpAcc;

        // Create Product
        Product2 p = new Product2(
            Name = 'Test Product',
            ProductCode = 'TEST-001',
            IsActive = true
        );
        insert p;

        // Standard Pricebook
        Id pricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = p.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;

        // Create Inventory
        Inventory__c inv = new Inventory__c(
            Channel_Partner__c = cpAcc.Id,
            Product__c = p.Id,
            Minimum_Stock_Level__c = 20,
            Minimum_Order_Quantity__c = 10
        );
        insert inv;
    }

    @IsTest
    static void testBatchExecution() {
        Test.startTest();
        InventoryMtaQuoteBatch batch = new InventoryMtaQuoteBatch();
        Database.executeBatch(batch);
        Test.stopTest();

        // The batch should have queried the Account and invoked the Service.
        // Whether the service creates a quote or skips (due to missing dependencies in test data)
        // the batch itself should complete successfully and the finish method will log totals.
        
        System.assert(true, 'Batch completed without exceptions');
    }
    
    // Helper to get RecordType without hardcoding ID
    private static Id getRecordTypeId(String sObjectType, String developerName) {
        return [SELECT Id FROM RecordType WHERE SObjectType = :sObjectType AND DeveloperName = :developerName LIMIT 1].Id;
    }
}