@isTest
private class PricingMaster_BatchTest {
    
    @TestSetup
    static void setup() {
        // Create test data
        List<Product2> testProducts = new List<Product2>{
            new Product2(Name = 'Test Product 1', ProductCode = 'TP-001'),
            new Product2(Name = 'Test Product 2', ProductCode = 'TP-002')
        };
        insert testProducts;
    }
    
    // Mock callout class
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    // @isTest
    // static void testBatchWithSingleRecord() {
    //     // Set mock callout class
    //     Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
    //     // Get test data
    //     Product2 testProduct = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode = 'TP-001' LIMIT 1];
        
    //     Test.startTest();
    //     PricingMasterQableCallout.stopChainingInTest = true; // Prevent queuing in test context
    //     Database.executeBatch(new PricingMaster_Batch(), 1);
    //     Test.stopTest();

    //     // Add assertions based on expected behavior
    //     // System.assertNotEquals(null, testProduct.Id, 'Test product should exist');
    // }

    // @isTest
    // static void testBatchWithMultipleRecords() {
    //     // Set mock callout class
    //     Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
    //     // Get test data count
    //     Integer productCount = [SELECT count() FROM Product2];
        
    //     Test.startTest();
    //     PricingMasterQableCallout.stopChainingInTest = true; // Prevent queuing in test context
    //     Database.executeBatch(new PricingMaster_Batch(), 1); // batch size 2
    //     Test.stopTest();

    //     // Verify the number of products matches expected
    //     // System.assertEquals(2, productCount, 'Should have 2 test products');
    // }

    @isTest
    static void testSchedulableExecution() {
        // Set mock callout class
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Schedule the batch job 1 minute in the future
        Datetime dt = System.now().addMinutes(1);
        String cronExp = String.format(
            '{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(dt.second()),
                String.valueOf(dt.minute()),
                String.valueOf(dt.hour()),
                String.valueOf(dt.day()),
                String.valueOf(dt.month()),
                String.valueOf(dt.year())
            }
        );

        Test.startTest();
        PricingMasterQableCallout.stopChainingInTest = true; // Prevent queuing in test context
        String jobId = System.schedule('Test PricingMaster Scheduler', cronExp, new PricingMaster_Batch());
        Test.stopTest();
        
        // Verify the scheduled job exists
        // List<CronTrigger> scheduledJobs = [SELECT Id FROM CronTrigger WHERE Id = :jobId];
        // System.assertEquals(1, scheduledJobs.size(), 'Job should be scheduled');
    }
}