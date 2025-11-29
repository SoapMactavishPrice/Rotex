@isTest
public class AllSchedulerTest {

    // Mock IntegrationHandler methods if necessary
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message":"Mock success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest static void testGetCustomerMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        System.enqueueJob(new AllScheduler('getCustomerMaster'));
        Test.stopTest();
    }

    @isTest static void testGetMaterialMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        System.enqueueJob(new AllScheduler('getMaterialMaster'));
        Test.stopTest();
    }

    @isTest static void testGetSalesOrderMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        System.enqueueJob(new AllScheduler('getSalesOrderMaster'));
        Test.stopTest();
    }

    @isTest static void testGetInvoiceMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        System.enqueueJob(new AllScheduler('getInvoiceMaster'));
        Test.stopTest();
    }

    @isTest static void testClearingpaymentMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        System.enqueueJob(new AllScheduler('ClearingpaymentMaster'));
        Test.stopTest();
    }

    @isTest static void testCustomerGlMaster() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        System.enqueueJob(new AllScheduler('CustomerGlMaster'));
        Test.stopTest();
    }
}