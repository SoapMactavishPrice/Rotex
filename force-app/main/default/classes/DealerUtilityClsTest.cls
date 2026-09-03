@IsTest
private class DealerUtilityClsTest {

    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"status": "success"}');
            return res;
        }
    }

    @IsTest
    static void testDoGetWithBasicAuth_Daily_Pricing() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        HttpResponse res = DealerUtilityCls.doGetWithBasicAuth(
            'Pricing_Master_API',
            'DAILY',
            Date.newInstance(2023, 1, 1),
            Date.newInstance(2023, 1, 31),
            'MAT123'
        );
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
    }
    
    @IsTest
    static void testDoGetWithBasicAuth_Daily_ARCPricing() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        HttpResponse res = DealerUtilityCls.doGetWithBasicAuth(
            'ARCPricing_Master_API',
            'DAILY',
            Date.newInstance(2023, 1, 1),
            Date.newInstance(2023, 1, 31),
            'CUST123'
        );
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testDoGetWithBasicAuth_Daily_CustomerMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        HttpResponse res = DealerUtilityCls.doGetWithBasicAuth(
            'Customer_Master_API',
            'DAILY',
            Date.newInstance(2023, 1, 1),
            Date.newInstance(2023, 1, 31),
            'CUST456'
        );
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testDoGetWithBasicAuth_Daily_MaterialMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        HttpResponse res = DealerUtilityCls.doGetWithBasicAuth(
            'Material_Master_API',
            'DAILY',
            Date.newInstance(2023, 1, 1),
            Date.newInstance(2023, 1, 31),
            'ITEM789'
        );
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testDoGetWithBasicAuth_Daily_SalesOrder() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        HttpResponse res = DealerUtilityCls.doGetWithBasicAuth(
            'Sales_Order_API',
            'DAILY',
            Date.newInstance(2023, 1, 1),
            Date.newInstance(2023, 1, 31),
            null
        );
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
    }
    
    @IsTest
    static void testDoGetWithBasicAuth_Daily_ClearingPayment() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        HttpResponse res = DealerUtilityCls.doGetWithBasicAuth(
            'Clearing_Payment_API',
            'DAILY',
            Date.newInstance(2023, 1, 1),
            Date.newInstance(2023, 1, 31),
            null
        );
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
    }
    
    @IsTest
    static void testDoGetWithBasicAuth_Daily_CustomerGL() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        HttpResponse res = DealerUtilityCls.doGetWithBasicAuth(
            'Customer_GL_API',
            'DAILY',
            Date.newInstance(2023, 1, 1),
            Date.newInstance(2023, 1, 31),
            null
        );
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
    }
    
    @IsTest
    static void testDoGetWithBasicAuth_Daily_Generic() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        HttpResponse res = DealerUtilityCls.doGetWithBasicAuth(
            'Some_Other_API',
            'DAILY',
            Date.newInstance(2023, 1, 1),
            Date.newInstance(2023, 1, 31),
            null
        );
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testDoGetWithBasicAuth_NotDaily() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        HttpResponse res = DealerUtilityCls.doGetWithBasicAuth(
            'Get_Session_API',
            'ON_DEMAND',
            Date.today(),
            Date.today(),
            null
        );
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testDoPostWithBasicAuth() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        HttpResponse res = DealerUtilityCls.doPostWithBasicAuth(
            'Create_Sales_Order_POST',
            '{"test":"data"}'
        );
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
    }

    @IsTest
    static void testLogApiCall_NoQuote() {
        Test.startTest();
        DealerUtilityCls.logApiCall(
            'Test_API',
            'https://test.com',
            'Request Body',
            'Response Body',
            'Success',
            200
        );
        Test.stopTest();
        
        List<API_Log__c> logs = [SELECT Id, Api_Name__c, Status__c, Status_Code__c FROM API_Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('Test_API', logs[0].Api_Name__c);
        System.assertEquals('Success', logs[0].Status__c);
        System.assertEquals('200', logs[0].Status_Code__c);
    }
    
    @IsTest
    static void testLogApiCall_WithQuote() {
        // Create a dummy quote to log against
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;
        Quote q = new Quote(Name = 'Test Quote', OpportunityId = opp.Id);
        insert q;
        
        Test.startTest();
        DealerUtilityCls.logApiCall(
            'Test_API_Quote',
            'https://test.com/quote',
            'Request Quote',
            'Response Quote',
            'Error',
            500,
            q.Id
        );
        Test.stopTest();
        
        List<API_Log__c> logs = [SELECT Id, Api_Name__c, Quote__c FROM API_Log__c WHERE Api_Name__c = 'Test_API_Quote'];
        System.assertEquals(1, logs.size());
        System.assertEquals(q.Id, logs[0].Quote__c);
    }
}