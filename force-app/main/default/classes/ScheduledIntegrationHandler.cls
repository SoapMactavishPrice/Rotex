global class ScheduledIntegrationHandler implements Schedulable {
    global void execute(SchedulableContext sc) {
        
        // Example response data
        String responseBody = 'Sample response body';
        Integer statusCode = 200;

        // Call the logApiCall method
        UtilityCls.logApiCall('Customer_Master_API', '', '', responseBody, '', statusCode);
    
        
        IntegrationHandler.getCustomerMaster();
        IntegrationHandler.getMaterialMaster();
        IntegrationHandler.getSalesOrderMaster();
        // Only execute this if NOT running in a test
        if(!Test.isRunningTest()) 
        {
        IntegrationHandler.getInvoiceMaster();
        IntegrationHandler.ClearingpaymentMaster();
        IntegrationHandler.CustomerGlMaster();
        }
    }
}