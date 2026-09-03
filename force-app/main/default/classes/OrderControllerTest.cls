@isTest
private class OrderControllerTest {
    
    @testSetup
    static void setup() {
        // Create test Account
        Account acc = new Account(Name = 'Test Partner Account');
        insert acc;
        
        // Create an Order under this Account
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Type = 'New'
        );
        insert ord;
        
        // Create Task
        Task tsk = new Task(
            Subject = 'Test Task',
            ActivityDate = Date.today().addDays(1),
            WhatId = ord.Id
        );
        insert tsk;
        
        // Create Event
        Event evt = new Event(
            Subject = 'Test Event',
            StartDateTime = Datetime.now().addDays(1),
            DurationInMinutes = 60,
            WhatId = ord.Id
        );
        insert evt;
    }
    
    @isTest
    static void testGetMyChannelPartnerAccountInfo() {
        Map<String, String> info = OrderController.getMyChannelPartnerAccountInfo();
        System.assertEquals(null, info, 'By default internal user has no partner account id');
        
        Id partnerId = OrderController.getMyChannelPartnerAccountId();
        System.assertEquals(null, partnerId, 'Should be null for internal user');
    }
    
    @isTest
    static void testGetMyOrders() {
        List<Order> orders = OrderController.getMyOrders();
        System.assertNotEquals(null, orders);
        System.assertEquals(1, orders.size(), 'Should find the order created in test setup');
    }
    
    @isTest
    static void testSaveOrder() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Map<String, Object> inputData = new Map<String, Object>{
            'accountId' => acc.Id,
            'soNo' => 'SO-12345',
            'type' => 'Renewal',
            'effectiveDate' => String.valueOf(Date.today()),
            'currencyIsoCode' => 'USD',
            'netValue' => 1000.50,
            'billTo' => acc.Id,
            'shipTo' => acc.Id,
            'billToCustomerName' => acc.Id,
            'soldTo' => acc.Id,
            'custRef' => 'REF-001',
            'termsOfPayment' => 'Net 30',
            'incoterms' => 'FOB',
            'custRefDate' => String.valueOf(Date.today()),
            'reqDelDate' => String.valueOf(Date.today().addDays(5))
        };
            
        String inputStr = JSON.serialize(inputData);
        
        Test.startTest();
        OrderController.saveOrder(inputStr);
        Test.stopTest();
        
        List<Order> orders = [SELECT Id, SO_No__c, Net_Value__c FROM Order WHERE SO_No__c = 'SO-12345'];
        System.assertEquals(1, orders.size(), 'Should have created one order');
        System.assertEquals('1000.50', orders[0].Net_Value__c, 'Net value should match');
    }
    
    @isTest
    static void testSaveOrderException() {
        Map<String, Object> inputData = new Map<String, Object>{
            // Missing accountId, should throw exception
            'soNo' => 'SO-12345'
        };
            
        String inputStr = JSON.serialize(inputData);
        
        Boolean hasException = false;
        Test.startTest();
        try {
            OrderController.saveOrder(inputStr);
        } catch (AuraHandledException e) {
            hasException = true;
        }
        Test.stopTest();
        
        System.assert(hasException, 'Expected AuraHandledException due to missing Account');
    }
    
    @isTest
    static void testActivities() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        List<OrderController.ActivityWrapper> activities = OrderController.getUpcomingActivities(ord.Id);
        Test.stopTest();
        
        System.assertEquals(2, activities.size(), 'Should retrieve task and event');
    }
    
    @isTest
    static void testNotes() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        OrderController.NoteWrapper newNote = OrderController.addOrderNote(ord.Id, 'Test Note Body');
        List<OrderController.NoteWrapper> notes = OrderController.getOrderNotes(ord.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, newNote.id);
        System.assertEquals('Test Note Body', newNote.body);
        System.assertEquals(1, notes.size(), 'Should retrieve the created note');
    }
    
    @isTest
    static void testFiles() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        OrderController.FileWrapper newFile = OrderController.saveOrderAttachment(ord.Id, 'testfile.txt', EncodingUtil.base64Encode(Blob.valueOf('File Content')));
        List<OrderController.FileWrapper> files = OrderController.getOrderFiles(ord.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, newFile.id);
        System.assertEquals('testfile.txt', newFile.title);
        System.assertEquals(1, files.size(), 'Should retrieve the uploaded file');
    }
    
    @isTest
    static void testUnauthorisedOrderAccess() {
        // Create an order owned by a different user — insert Account+Order under that user
        // so cross-reference access is valid (prod fails if Standard User uses shared Account Id).
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User u = new User(Alias = 'standt', Email='standarduser' + DateTime.now().getTime() + '@testorg.com',
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
                          LocaleSidKey='en_US', ProfileId = p.Id,
                          TimeZoneSidKey='America/Los_Angeles', UserName='standarduser' + DateTime.now().getTime() + '@testorg.com');
        insert u;
        
        Order ord;
        System.runAs(u) {
            Account otherAcc = new Account(Name = 'Other User Order Account');
            insert otherAcc;
            ord = new Order(AccountId = otherAcc.Id, EffectiveDate = Date.today(), Status = 'Draft');
            insert ord;
        }
        
        Boolean hasException = false;
        Test.startTest();
        try {
            // Running as the default user, trying to access an order created by another user
            OrderController.getUpcomingActivities(ord.Id);
        } catch (AuraHandledException e) {
            hasException = true;
        } catch (Exception e) {
            // Some orgs wrap as QueryException / generic depending on sharing
            hasException = true;
        }
        Test.stopTest();
        
        System.assert(hasException, 'Expected exception due to unauthorized access');
    }
}