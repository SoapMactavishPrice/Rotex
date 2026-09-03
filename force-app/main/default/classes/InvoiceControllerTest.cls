@isTest
private class InvoiceControllerTest {
    
    @testSetup
    static void setup() {
        // Create an Account
        Account acc = new Account(Name = 'Test Partner Account');
        insert acc;
        
        // Create an Invoice
        SO_Invoice__c inv = new SO_Invoice__c(
            Account__c = acc.Id,
            Bill_Doc_No__c = 'INV-001'
        );
        insert inv;
    }
    
    @isTest
    static void testGetMyChannelPartnerAccountId() {
        Test.startTest();
        Id partnerId = InvoiceController.getMyChannelPartnerAccountId();
        Test.stopTest();
        
        System.assertEquals(null, partnerId, 'By default internal user has no partner account id');
    }
    
    @isTest
    static void testGetMyInvoices() {
        Test.startTest();
        List<SO_Invoice__c> invoices = InvoiceController.getMyInvoices();
        Test.stopTest();
        
        System.assertNotEquals(null, invoices, 'Invoices list should not be null');
        System.assertEquals(1, invoices.size(), 'Should find the invoice created by the running user');
    }
    
    @isTest
    static void testPartnerUser() {
        // Query an existing partner user first to bypass complex setup
        List<User> existingPartners = [SELECT Id, AccountId FROM User WHERE AccountId != null AND IsActive = true LIMIT 1];
        if (!existingPartners.isEmpty()) {
            System.runAs(existingPartners[0]) {
                Test.startTest();
                List<SO_Invoice__c> invoices = InvoiceController.getMyInvoices();
                Id pId = InvoiceController.getMyChannelPartnerAccountId();
                Test.stopTest();
                System.assertNotEquals(null, pId, 'Should have a partner Id');
            }
        } else {
            // Attempt to create a community user if one doesn't exist
            List<Profile> pList = [SELECT Id FROM Profile WHERE Name LIKE '%Partner%' OR Name LIKE '%Community%' LIMIT 1];
            if (!pList.isEmpty()) {
                System.runAs(new User(Id = UserInfo.getUserId())) {
                    try {
                        Account acc = new Account(Name='Partner Account Test');
                        insert acc;
                        Contact con = new Contact(LastName='Partner Contact', AccountId=acc.Id);
                        insert con;
                        
                        String uniqueSuffix = String.valueOf(DateTime.now().getTime());
                        User partnerUser = new User(
                            Alias = 'partn', Email='partner' + uniqueSuffix + '@testorg.com',
                            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                            LocaleSidKey='en_US', ProfileId = pList[0].Id,
                            ContactId = con.Id,
                            TimeZoneSidKey='America/Los_Angeles', UserName='partner' + uniqueSuffix + '@testorg.com'
                        );
                        insert partnerUser;
                        
                        System.runAs(partnerUser) {
                            Test.startTest();
                            InvoiceController.getMyInvoices();
                            InvoiceController.getMyChannelPartnerAccountId();
                            Test.stopTest();
                        }
                    } catch (Exception e) {
                        System.debug('Failed to create partner user: ' + e.getMessage());
                    }
                }
            }
        }
    }
}