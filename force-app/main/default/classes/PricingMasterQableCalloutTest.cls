/*@isTest
private class PricingMasterQableCalloutTest {
    
    // Mock class to simulate the HTTP response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testQueueableExecutionWithChaining() {
        // Register the mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Insert test Product2 data
        List<Product2> productList = new List<Product2>();
        for (Integer i = 0; i < 3; i++) {
            productList.add(new Product2(Name = 'Test Product ' + i, ProductCode = 'P00' + i, IsActive = true));
        }
        insert productList;

        // Disable chaining during test (optional depending on what you want to test)
        Test.startTest();
        PricingMasterQableCallout.stopChainingInTest = true;

        // Run the first Queueable job
        System.enqueueJob(new PricingMasterQableCallout(productList, 0));
        Test.stopTest();

        // You can add assertions here if IntegrationHandler updates anything in the system.
        // Otherwise, just ensure code coverage and callout execution.
    }

    @isTest
    static void testQueueableWithoutCalloutExecutionDueToIndexOutOfBounds() {
        // Register mock again
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Insert one product
        Product2 prod = new Product2(Name = 'Test Product', ProductCode = 'PX001', IsActive = true);
        insert prod;

        // Try to run with index out of bounds
        Test.startTest();
        System.enqueueJob(new PricingMasterQableCallout(new List<Product2>{prod}, 2));
        Test.stopTest();

        // Should safely skip execution due to index check
    }
}*/
@isTest
private class PricingMasterQableCalloutTest {
    
    // Mock class to simulate the HTTP response
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testQueueableExecutionWithChaining() {
        // Activate Standard Pricebook
        Id standardPricebookId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(
            Id = standardPricebookId,
            Name = 'Standard Price Book',
            IsActive = true
        );
        upsert stdPb;

        // Register the mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Insert test Product2 data
        List<Product2> productList = new List<Product2>();
        for (Integer i = 0; i < 3; i++) {
            Product2 prod = new Product2(Name = 'Test Product ' + i, ProductCode = 'P00' + i, IsActive = true);
            productList.add(prod);
        }
        insert productList;

        // Create PricebookEntry for each product
        List<PricebookEntry> entries = new List<PricebookEntry>();
        for (Product2 p : productList) {
            // Check if entry exists to avoid DUPLICATE_VALUE
            List<PricebookEntry> existing = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :p.Id LIMIT 1];
            if (existing.isEmpty()) {
                entries.add(new PricebookEntry(
                    Pricebook2Id = standardPricebookId,
                    Product2Id = p.Id,
                    UnitPrice = 100,
                    IsActive = true,
                    CurrencyIsoCode = 'INR'
                ));
            }
        }
        if (!entries.isEmpty()) insert entries;

        // Disable chaining during test
        Test.startTest();
        PricingMasterQableCallout.stopChainingInTest = true;

        // Run the first Queueable job
        System.enqueueJob(new PricingMasterQableCallout(productList, 0));
        Test.stopTest();
    }

    @isTest
    static void testQueueableWithoutCalloutExecutionDueToIndexOutOfBounds() {
        // Activate Standard Pricebook
        Id standardPricebookId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(
            Id = standardPricebookId,
            Name = 'Standard Price Book',
            IsActive = true
        );
        upsert stdPb;

        // Register mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Insert one product
        Product2 prod = new Product2(Name = 'Test Product', ProductCode = 'PX001', IsActive = true);
        insert prod;

        // Create PricebookEntry
        List<PricebookEntry> existing = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :prod.Id LIMIT 1];
        if (existing.isEmpty()) {
            insert new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true,
                CurrencyIsoCode = 'INR'
            );
        }

        // Run queueable with index out of bounds
        Test.startTest();
        System.enqueueJob(new PricingMasterQableCallout(new List<Product2>{prod}, 2));
        Test.stopTest();
    }
}