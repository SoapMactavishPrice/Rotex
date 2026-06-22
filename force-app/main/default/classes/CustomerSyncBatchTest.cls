@isTest
private class CustomerSyncBatchTest {

    @isTest
    static void testCustomerSyncBatch() {

        Account account = new Account(
            Name = 'Test Account ',
            SAP_Customer_Code__c = 'CUST001'
        );

        insert account;

        Test.startTest();

        Database.executeBatch(new CustomerSyncBatch(), 1);

        Test.stopTest();

    }
}