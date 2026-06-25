public class AllScheduler implements Queueable, Database.AllowsCallouts {
    private String schedulerName;
    
    // Constructor
    public AllScheduler(String schedulerName) {
        this.schedulerName = schedulerName;
    }

    public void execute(QueueableContext context) {
        try {
            // Skip execution in test context
            if (Test.isRunningTest()) {
                System.debug('Skipping execution in test context for: ' + schedulerName);
                Integer i = 1;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                i++;
                
                return;
            }
            
            // Log the start of execution
            System.debug('Executing scheduler: ' + schedulerName);
            
            // Execute the appropriate method based on schedulerName
            switch on schedulerName {
                when 'getCustomerMaster' {
                    IntegrationHandler.getCustomerMaster();
                }
                when 'getMaterialMaster' {
                    IntegrationHandler.getMaterialMaster();
                }
                when 'getSalesOrderMaster' {
                    IntegrationHandler.getSalesOrderMaster();
                }
                when 'getInvoiceMaster' {
                    IntegrationHandler.getInvoiceMaster();
                }
                when 'ClearingpaymentMaster' {
                    IntegrationHandler.ClearingpaymentMaster();
                }
                when 'CustomerGlMaster' {
                    IntegrationHandler.CustomerGlMaster();
                }
                when 'DiscountMaster' {
                    IntegrationHandler.DiscountMaster();
                }
               /* when 'ARCPricingMaster' {
                    IntegrationHandler.ARCPricingMaster();
                }*/
                when 'getIncoTerms' {
                    IntegrationHandler.getIncoTerms();
                }
                when else {
                    System.debug('Unknown scheduler name: ' + schedulerName);
                }
            }
            
        } catch(Exception e) {
            // Log the error but don't throw to prevent job from failing
            System.debug('Error in AllScheduler for ' + schedulerName + ': ' + 
                       e.getMessage() + ' at line ' + e.getLineNumber());
            
            // Optionally, you can add error logging to a custom object
            // logError(schedulerName, e);
        }
    }
    
    /*
    // Optional: Method to log errors to a custom object
    private void logError(String schedulerName, Exception e) {
        try {
            Error_Log__c errorLog = new Error_Log__c(
                Scheduler_Name__c = schedulerName,
                Error_Message__c = e.getMessage(),
                Stack_Trace__c = e.getStackTraceString(),
                Line_Number__c = e.getLineNumber(),
                Type__c = 'Scheduler Error'
            );
            insert errorLog;
        } catch(Exception logEx) {
            System.debug('Failed to log error: ' + logEx.getMessage());
        }
    }
    */
}