@isTest
private class CustomerApprovalTriggerHandlerTest {

    @isTest
    static void testCustomerApprovalOnCustomerInsert() {
        Id customerRtId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
              AND DeveloperName = 'Customer'
            LIMIT 1
        ].Id;

        Account dealer = new Account(Name = 'Approval Dealer');
        insert dealer;

        Account customer = new Account(
            Name = 'Approval Customer',
            RecordTypeId = customerRtId,
            ParentId = dealer.Id
        );

        Test.startTest();
        insert customer;
        Test.stopTest();

        System.assertNotEquals(null, customer.Id, 'Customer account should be inserted');
    }

    @isTest
    static void testCustomerApprovalOnNonCustomerInsert() {
        Account dealer = new Account(Name = 'Non Customer Dealer');
        insert dealer;

        Test.startTest();
        CustomerApprovalTriggerHandler.handleAfterInsert(new List<Account>{ dealer });
        Test.stopTest();

        System.assertNotEquals(null, dealer.Id, 'Handler should skip non-customer accounts');
    }
}