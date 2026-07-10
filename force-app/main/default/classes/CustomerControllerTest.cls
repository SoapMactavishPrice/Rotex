@isTest
public class CustomerControllerTest {
    
    // Mock for HTTP Callouts (Pincode and GST)
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('postalpincode.in')) {
                res.setBody('[{"Status":"Success","PostOffice":[{"District":"Test District","State":"Test State"}]}]');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('gst.gov.in')) {
                res.setBody('{"bzgddtls":[{"test":"data"}]}');
                res.setStatusCode(200);
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }

    public class PincodeFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            return res;
        }
    }

    public class PincodeEmptyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[]');
            return res;
        }
    }

    public class GstErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"errorCode":"INVALID"}');
            return res;
        }
    }

    public class GstServiceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"bzsdtls":[{"service":"data"}]}');
            return res;
        }
    }

    public class GstEmptyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    private static Id getCustomerRecordTypeId() {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
              AND DeveloperName = 'Customer'
            LIMIT 1
        ].Id;
    }

    private static User getUserWithRole() {
        List<User> internalUsers = [
            SELECT Id
            FROM User
            WHERE UserRoleId != null
              AND IsActive = true
              AND UserType = 'Standard'
            LIMIT 1
        ];

        if (!internalUsers.isEmpty()) {
            return internalUsers[0];
        }

        return [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator'
              AND IsActive = true
              AND UserRoleId != null
            LIMIT 1
        ];
    }

    private static Account createDealerAccount(String name) {
        Account dealer = new Account(
            Name = name,
            OwnerId = getUserWithRole().Id
        );
        insert dealer;
        return dealer;
    }

    private static User insertPartnerUser(Account dealerAccount) {
        Profile partnerProfile = [
            SELECT Id
            FROM Profile
            WHERE Name IN ('Partner Community User', 'Partner Community Login User')
            LIMIT 1
        ];

        Contact con = new Contact(
            LastName = 'Partner Contact',
            AccountId = dealerAccount.Id
        );
        insert con;

        String unique = String.valueOf(System.currentTimeMillis());
        User partnerUser = new User(
            FirstName = 'Test',
            LastName = 'Partner',
            Email = 'partner' + unique + '@test.com',
            Username = 'partner' + unique + '@test.com',
            Alias = unique.left(8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = partnerProfile.Id,
            ContactId = con.Id
        );
        insert partnerUser;
        return partnerUser;
    }

    private static void setAccountPinCode(Account acc, String pinCode) {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();

        if (fieldMap.containsKey('Postal_Code__c')) {
            acc.put('Postal_Code__c', pinCode);
        }
        if (fieldMap.containsKey('Pin_Code__c')) {
            acc.put('Pin_Code__c', pinCode);
        }
    }

    private static CustomerController.CustomerInput buildCustomerInput(Id dealerAccountId) {
        CustomerController.CustomerInput input = new CustomerController.CustomerInput();
        input.dealerAccountId = dealerAccountId;
        input.customerName = 'New Customer';
        input.gstNo = '22AAAAA0000A1Z5';
        input.address = '123 Test Street';
        input.pinCode = '110001';
        input.contactFirstName = 'John';
        input.contactLastName = 'Doe';
        input.contactPhone = '9999999999';
        input.contactEmail = 'john@example.com';
        return input;
    }
    
    @testSetup
    static void setupData() {
        Account acc = new Account(
            Name = 'Test Baseline Account',
            OwnerId = getUserWithRole().Id
        );
        insert acc;
    }

    @isTest
    static void testGetDealerAccount_NoPortalUser() {
        // Running as standard user, should throw an exception because AccountId is null
        Test.startTest();
        try {
            CustomerController.getDealerAccount();
            System.assert(false, 'Expected an AuraHandledException to be thrown');
        } catch (Exception e) {
            System.assert(e != null, 'Exception should be caught');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetCustomersByDealer() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<Account> customers = CustomerController.getCustomersByDealer(acc.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, customers, 'Should return a list');
    }
    
    @isTest
    static void testGetCustomersByDealer_NullId() {
        Test.startTest();
        try {
            CustomerController.getCustomersByDealer(null);
            System.assert(false, 'Expected an AuraHandledException to be thrown');
        } catch (Exception e) {
            System.assert(e != null, 'Exception should be caught');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateCustomer_NoPortalUser() {
        CustomerController.CustomerInput input = new CustomerController.CustomerInput();
        input.dealerAccountId = UserInfo.getUserId(); // invalid id for account, just for test
        
        Test.startTest();
        try {
            CustomerController.createCustomer(input);
            System.assert(false, 'Expected an AuraHandledException');
        } catch (Exception e) {
            System.assert(e != null, 'Exception should be caught');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateCustomer_NoPortalUser() {
        Account dealer = createDealerAccount('Dealer Account');

        Account customer = new Account(
            Name = 'Customer Account',
            Channel_Partner_Name__c = dealer.Id
        );
        insert customer;

        CustomerController.CustomerInput input = new CustomerController.CustomerInput();
        input.customerId = customer.Id;
        input.customerName = 'Should Not Update';

        Test.startTest();
        Boolean threwException = false;
        try {
            CustomerController.updateCustomer(input);
        } catch (Exception e) {
            threwException = true;
        }
        Test.stopTest();

        System.assert(threwException, 'Expected an exception for non-portal user');

        Account unchanged = [SELECT Name FROM Account WHERE Id = :customer.Id];
        System.assertEquals(
            'Customer Account',
            unchanged.Name,
            'Customer should not be updated by non-portal user'
        );
    }
    
    @isTest
    static void testGetShowSoTreeFlag() {
        Test.startTest();
        Boolean flag = CustomerController.getShowSoTreeFlag();
        Test.stopTest();
        
        System.assertNotEquals(null, flag, 'Should return a boolean value');
    }

    @isTest
    static void testSaveAttachment_NoPortalUser() {
        Account parent = new Account(Name = 'Parent Account');
        insert parent;
        
        Account acc = new Account(Name = 'Child Account', ParentId = parent.Id);
        insert acc;
        
        Test.startTest();
        try {
            CustomerController.saveAttachment(acc.Id, 'TestFile.txt', 'VGVzdA==', 'txt');
            System.assert(false, 'Expected an AuraHandledException due to auth');
        } catch (Exception e) {
            System.assert(e != null, 'Exception should be caught');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetAttachments() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        ContentVersion insertedCV = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedCV.ContentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
        
        Test.startTest();
        List<ContentDocument> docs = CustomerController.getAttachments(acc.Id);
        Test.stopTest();
        
        System.assertEquals(1, docs.size(), 'Should return 1 attachment');
    }

    @isTest
    static void testGetStateDistrictByPincode() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        Map<String, String> result = CustomerController.getStateDistrictByPincode('110001');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Test District', result.get('district'), 'District should match mock');
        System.assertEquals('Test State', result.get('state'), 'State should match mock');
    }

    @isTest
    static void testVerifyGST() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        Boolean result = CustomerController.verifyGST('22AAAAA0000A1Z5');
        Test.stopTest();
        
        System.assertEquals(true, result, 'GST verification should be true based on mock');
    }

    @isTest
    static void testGetDealerAccount_PortalUser() {
        Account dealer = createDealerAccount('Dealer For Portal');

        User partnerUser;
        Test.startTest();
        partnerUser = insertPartnerUser(dealer);
        Test.stopTest();

        System.runAs(partnerUser) {
            Account result = CustomerController.getDealerAccount();
            System.assertEquals(dealer.Id, result.Id, 'Should return linked dealer account');
        }
    }

    @isTest
    static void testCreateCustomer_PortalUser() {
        Account dealer = createDealerAccount('Dealer For Create');

        User partnerUser;
        Test.startTest();
        partnerUser = insertPartnerUser(dealer);
        Test.stopTest();

        CustomerController.CustomerInput input = buildCustomerInput(dealer.Id);

        System.runAs(partnerUser) {
            Id customerId = CustomerController.createCustomer(input);

            Account created = [
                SELECT Name, Channel_Partner_Name__c
                FROM Account
                WHERE Id = :customerId
            ];
            System.assertEquals('New Customer', created.Name);
            System.assertEquals(dealer.Id, created.Channel_Partner_Name__c);

            List<Contact> contacts = [SELECT FirstName, LastName FROM Contact WHERE AccountId = :customerId];
            System.assertEquals(1, contacts.size(), 'Should create contact from contact person details');
            System.assertEquals('John', contacts[0].FirstName);
            System.assertEquals('Doe', contacts[0].LastName);
        }
    }

    @isTest
    static void testCreateCustomer_SingleNameContact() {
        Account dealer = createDealerAccount('Dealer Single Contact');

        User partnerUser;
        Test.startTest();
        partnerUser = insertPartnerUser(dealer);
        Test.stopTest();

        CustomerController.CustomerInput input = buildCustomerInput(dealer.Id);
        input.contactFirstName = 'Madonna';
        input.contactLastName = null;

        System.runAs(partnerUser) {
            Id customerId = CustomerController.createCustomer(input);

            Contact con = [SELECT FirstName, LastName FROM Contact WHERE AccountId = :customerId LIMIT 1];
            System.assertEquals('Madonna', con.FirstName);
            System.assertEquals('Madonna', con.LastName);
        }
    }

    @isTest
    static void testCreateCustomer_NoContactName() {
        Account dealer = createDealerAccount('Dealer No Contact');

        User partnerUser;
        Test.startTest();
        partnerUser = insertPartnerUser(dealer);
        Test.stopTest();

        CustomerController.CustomerInput input = buildCustomerInput(dealer.Id);
        input.contactFirstName = null;
        input.contactLastName = null;

        System.runAs(partnerUser) {
            Id customerId = CustomerController.createCustomer(input);
            System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE AccountId = :customerId]);
        }
    }

    @isTest
    static void testCreateCustomer_DuplicateGstPin() {
        Id customerRtId = getCustomerRecordTypeId();
        Account dealer = createDealerAccount('Dealer Dup');

        User partnerUser;
        Test.startTest();
        partnerUser = insertPartnerUser(dealer);
        Test.stopTest();

        System.runAs(partnerUser) {
            Account existing = new Account(
                Name = 'Existing Customer',
                RecordTypeId = customerRtId,
                ParentId = dealer.Id,
                GST_No__c = '22AAAAA0000A1Z5',
                Channel_Partner_Name__c = dealer.Id
            );
            setAccountPinCode(existing, '110001');
            insert existing;

            insert new Contact(LastName = 'Existing Contact', AccountId = existing.Id);

            CustomerController.CustomerInput input = buildCustomerInput(dealer.Id);

            Boolean threwException = false;
            try {
                CustomerController.createCustomer(input);
            } catch (Exception e) {
                threwException = true;
            }

            System.assert(threwException, 'Duplicate GST and pin should be rejected');
        }
    }

    @isTest
    static void testUpdateCustomer_PortalUser() {
        Id customerRtId = getCustomerRecordTypeId();
        Account dealer = createDealerAccount('Dealer Update');

        User partnerUser;
        Test.startTest();
        partnerUser = insertPartnerUser(dealer);
        Test.stopTest();

        System.runAs(partnerUser) {
            Account customer = new Account(
                Name = 'Customer To Update',
                RecordTypeId = customerRtId,
                Channel_Partner_Name__c = dealer.Id
            );
            insert customer;

            CustomerController.CustomerInput input = new CustomerController.CustomerInput();
            input.customerId = customer.Id;
            input.customerName = 'Updated Customer';
            input.gstNo = '22BBBBB0000B1Z5';
            input.pinCode = '110002';

            Id updatedId = CustomerController.updateCustomer(input);

            Account updated = [SELECT Name FROM Account WHERE Id = :updatedId];
            System.assertEquals('Updated Customer', updated.Name);
        }
    }

    @isTest
    static void testUpdateCustomer_DuplicateGstPin() {
        Id customerRtId = getCustomerRecordTypeId();
        Account dealer = createDealerAccount('Dealer Update Dup');

        User partnerUser;
        Test.startTest();
        partnerUser = insertPartnerUser(dealer);
        Test.stopTest();

        System.runAs(partnerUser) {
            Account existing = new Account(
                Name = 'Existing Dup Customer',
                RecordTypeId = customerRtId,
                ParentId = dealer.Id,
                GST_No__c = '22CCCCCC000C1Z5',
                Channel_Partner_Name__c = dealer.Id
            );
            setAccountPinCode(existing, '110003');
            insert existing;

            Account customer = new Account(
                Name = 'Customer To Update Dup',
                RecordTypeId = customerRtId,
                Channel_Partner_Name__c = dealer.Id
            );
            insert customer;

            CustomerController.CustomerInput input = new CustomerController.CustomerInput();
            input.customerId = customer.Id;
            input.gstNo = '22CCCCCC000C1Z5';
            input.pinCode = '110003';

            Boolean threwException = false;
            try {
                CustomerController.updateCustomer(input);
            } catch (Exception e) {
                threwException = true;
            }

            System.assert(threwException, 'Duplicate GST and pin should be rejected on update');
        }
    }

    @isTest
    static void testGetCustomersByDealer_WithCustomerRecord() {
        Id customerRtId = getCustomerRecordTypeId();
        Account dealer = createDealerAccount('Dealer List');

        insert new Account(
            Name = 'Listed Customer',
            RecordTypeId = customerRtId,
            Channel_Partner_Name__c = dealer.Id
        );

        List<Account> customers = CustomerController.getCustomersByDealer(dealer.Id);
        System.assertEquals(1, customers.size(), 'Should return customer under dealer');
    }

    @isTest
    static void testUpdateCustomer_NotFound() {
        Account temp = new Account(Name = 'Temp');
        insert temp;
        Id deletedId = temp.Id;
        delete temp;

        CustomerController.CustomerInput input = new CustomerController.CustomerInput();
        input.customerId = deletedId;

        Test.startTest();
        Boolean threwException = false;
        try {
            CustomerController.updateCustomer(input);
        } catch (Exception e) {
            threwException = true;
        }
        Test.stopTest();

        System.assert(threwException, 'Missing customer should throw');
    }

    @isTest
    static void testSaveAttachment_PortalUser() {
        Account dealer = createDealerAccount('Dealer Attachment');

        User partnerUser;
        Test.startTest();
        partnerUser = insertPartnerUser(dealer);
        Test.stopTest();

        System.runAs(partnerUser) {
            Account customer = new Account(
                Name = 'Customer Attachment',
                Channel_Partner_Name__c = dealer.Id
            );
            insert customer;

            Boolean threwException = false;
            try {
                CustomerController.saveAttachment(customer.Id, 'TestFile.txt', 'VGVzdA==', 'txt');
            } catch (Exception e) {
                threwException = true;
            }

            System.assert(
                threwException || CustomerController.getAttachments(customer.Id).size() == 1,
                'Should either save attachment or fail with portal permissions'
            );
        }
    }

    @isTest
    static void testGetAttachments_Empty() {
        Account acc = new Account(Name = 'No Attachments');
        insert acc;

        Test.startTest();
        List<ContentDocument> docs = CustomerController.getAttachments(acc.Id);
        Test.stopTest();

        System.assertEquals(0, docs.size(), 'Should return empty list');
    }

    @isTest
    static void testGetStateDistrictByPincode_FailureStatus() {
        Test.setMock(HttpCalloutMock.class, new PincodeFailureMock());

        Test.startTest();
        System.assertEquals(null, CustomerController.getStateDistrictByPincode('110001'));
        Test.stopTest();
    }

    @isTest
    static void testGetStateDistrictByPincode_EmptyResponse() {
        Test.setMock(HttpCalloutMock.class, new PincodeEmptyMock());

        Test.startTest();
        System.assertEquals(null, CustomerController.getStateDistrictByPincode('110001'));
        Test.stopTest();
    }

    @isTest
    static void testVerifyGST_ErrorResponse() {
        Test.setMock(HttpCalloutMock.class, new GstErrorMock());

        Test.startTest();
        System.assertEquals(false, CustomerController.verifyGST('22AAAAA0000A1Z5'));
        Test.stopTest();
    }

    @isTest
    static void testVerifyGST_ServiceResponse() {
        Test.setMock(HttpCalloutMock.class, new GstServiceMock());

        Test.startTest();
        System.assertEquals(true, CustomerController.verifyGST('22AAAAA0000A1Z5'));
        Test.stopTest();
    }

    @isTest
    static void testVerifyGST_EmptyResponse() {
        Test.setMock(HttpCalloutMock.class, new GstEmptyMock());

        Test.startTest();
        System.assertEquals(false, CustomerController.verifyGST('22AAAAA0000A1Z5'));
        Test.stopTest();
    }
}