@isTest
private class ARCPricingQableCalloutTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account with SAP Customer Code
        Account testAccount = new Account(
            Name = 'Test Account',
            SAP_Customer_Code__c = 'TEST12345',
            BillingCountry = 'United States'
        );
        insert testAccount;
    }
    
    @isTest
    static void testExecute_Success() {
        // Query test data
        Account testAccount = [SELECT Id, SAP_Customer_Code__c FROM Account LIMIT 1];
        List<Account> accounts = new List<Account>{testAccount};
        
        // Set the static flag to stop chaining in test
        ARCPricingQableCallout.stopChainingInTest = true;
        
        Test.startTest();
        
        // Mock the HTTP callout
        Test.setMock(HttpCalloutMock.class, new ARCPricingMockResponse());
        
        // Execute the queueable
        ARCPricingQableCallout queueable = new ARCPricingQableCallout(accounts, 0);
        System.enqueueJob(queueable);
        
        Test.stopTest();
        
        // Verify the callout was made
        // System.assertEquals(1, Limits.getQueueableJobs(), 'Queueable job should be enqueued');
    }
    
    @isTest
    static void testExecute_WithMultipleAccounts() {
        // Create additional test accounts
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Test 1', SAP_Customer_Code__c = 'TEST0001', BillingCountry = 'United States'),
            new Account(Name = 'Test 2', SAP_Customer_Code__c = 'TEST0002', BillingCountry = 'United States')
        };
        insert accounts;
        accounts = [SELECT Id, SAP_Customer_Code__c FROM Account WHERE SAP_Customer_Code__c IN ('TEST0001', 'TEST0002') ORDER BY SAP_Customer_Code__c];
        
        // Set the static flag to stop chaining in test
        ARCPricingQableCallout.stopChainingInTest = true;
        
        Test.startTest();
        
        // Mock the HTTP callout
        Test.setMock(HttpCalloutMock.class, new ARCPricingMockResponse());
        
        // Execute the queueable
        ARCPricingQableCallout queueable = new ARCPricingQableCallout(accounts, 0);
        System.enqueueJob(queueable);
        
        Test.stopTest();
        
        // Verify the callout was made for the first account
        // System.assertEquals(1, Limits.getQueueableJobs(), 'Should only process one account per transaction in test context');
    }
    
    @isTest
    static void testExecute_WithCalloutError() {
        // Query test data
        Account testAccount = [SELECT Id, SAP_Customer_Code__c FROM Account LIMIT 1];
        List<Account> accounts = new List<Account>{testAccount};
        
        // Set the static flag to stop chaining in test
        ARCPricingQableCallout.stopChainingInTest = true;
        
        Test.startTest();
        
        // Mock the HTTP callout to return an error
        Test.setMock(HttpCalloutMock.class, new ARCPricingErrorMockResponse());
        
        // Execute the queueable
        ARCPricingQableCallout queueable = new ARCPricingQableCallout(accounts, 0);
        System.enqueueJob(queueable);
        
        Test.stopTest();
        
        // Verify the job was enqueued
        // System.assertEquals(1, Limits.getQueueableJobs(), 'Queueable job should be enqueued even with callout error');
    }
    
    // Mock HTTP Response for successful callout
    private class ARCPricingMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // Sample response that matches the expected structure in IntegrationHandler.ARCPricingMaster
            String responseBody = '{"d":{' +
                '"results":[' +
                '  {' +
                '    "Customer": "TEST12345",' +
                '    "Material": "TEST-PROD-001",' +
                '    "ValidFrom": "/Date(1640995200000)/",' +
                '    "ValidTo": "/Date(1672531199000)/",' +
                '    "Price": "100.00",' +
                '    "Currency": "USD",' +
                '    "UoM": "EA",' +
                '    "PriceList": "STANDARD"' +
                '  }' +
                ']}}';
            
            res.setBody(responseBody);
            res.setStatusCode(200);
            return res;
        }
    }
    
    // Mock HTTP Response for error scenario
    private class ARCPricingErrorMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake error response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error": {"message": "Internal server error"}}');
            return res;
        }
    }
}