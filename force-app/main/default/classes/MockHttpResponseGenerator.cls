@isTest
public class MockHttpResponseGenerator implements HttpCalloutMock {
    
    // Implement the respond method required by the HttpCalloutMock interface
    public HTTPResponse respond(HTTPRequest req) {
        System.debug('MockHttpResponseGenerator received request to: ' + req.getEndpoint());
        
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        
        // Default response
        String responseBody = '{"d":{"results":[]}}';
        Integer statusCode = 200;
        
        try {
            // Set the mock response based on the endpoint
            if (req.getEndpoint().contains('Invoice_API')) {
                System.debug('Returning mock response for Invoice_API');
                responseBody = '{"d":{"results":[{"invoice_number":"INV001","customer_number":"CUST001","amount":100.00}]}}';
                statusCode = 200;
            } 
            else if (req.getEndpoint().contains('Customer_Master_API')) {
                System.debug('Returning mock response for Customer_Master_API');
                responseBody = '{"d":{"results":[{"customer_number":"CUST001","name":"Test Customer"}]}}';
                statusCode = 200;
            } 
            else if (req.getEndpoint().contains('Material_Master_API')) {
                System.debug('Returning mock response for Material_Master_API');
                responseBody = '{"d":{"results":[{"item_no":"ITEM001","description":"Test Item"}]}}';
                statusCode = 200;
            } 
            else if (req.getEndpoint().contains('Sales_Order_API')) {
                System.debug('Returning mock response for Sales_Order_API');
                responseBody = '{"d":{"results":[{"so_num":"SO001","customer":"CUST001"}]}}';
                statusCode = 200;
            } 
            else if (req.getEndpoint().contains('Clearing_Payment_API')) {
                System.debug('Returning mock response for Clearing_Payment_API');
                responseBody = '{"d":{"results":[{"payment_number":"PAY001","amount":100.00}]}}';
                statusCode = 200;
            } 
            else if (req.getEndpoint().contains('Customer_GL_API')) {
                System.debug('Returning mock response for Customer_GL_API');
                responseBody = '{"d":{"results":[{"gl_account":"GL001","description":"Test Account"}]}}';
                statusCode = 200;
            }
            
            System.debug('Returning status code: ' + statusCode);
            System.debug('Response body: ' + responseBody);
            
        } catch (Exception e) {
            System.debug('Error in MockHttpResponseGenerator: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            responseBody = '{"error":"Mock response generation failed: ' + e.getMessage() + '"}';
            statusCode = 500;
        }
        
        res.setBody(responseBody);
        res.setStatusCode(statusCode);
        return res;
    }
}