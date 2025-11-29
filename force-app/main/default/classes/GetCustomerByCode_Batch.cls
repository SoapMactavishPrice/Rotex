global class GetCustomerByCode_Batch implements Database.Batchable<sObject>,Database.Stateful,Database.AllowsCallouts {

    // STEP 1: Create list of dates to iterate over
    global database.QueryLocator start(database.BatchableContext bc) {
        return database.getQueryLocator([
            SELECT Id, Name, Customer__c
            FROM Partner_Details__c
            WHERE Account__c != null
            AND Customer__c != null
            AND Sales_Area_Item__c != null
            // LIMIT 10
        ]);
    }

    // STEP 2: For each batch of dates, call the API
    global void execute(Database.BatchableContext bc, List<Partner_Details__c> scope) {

        // Set<String> uniqueCustomers = new Set<String>();

        // for (Partner_Details__c pd : scope) {
        //     if (pd.Customer__c != null) {
        //         uniqueCustomers.add(pd.Customer__c);
        //     }
        // }

        // // Now call integration once per unique customer
        // for (String customerCode : uniqueCustomers) {
        //     try {
        //         IntegrationHandler.getCustomerMaster(customerCode);
        //     } catch (Exception e) {
        //         System.debug('Error for Customer ' + customerCode + ': ' + e.getMessage());
        //         // optionally log errors
        //     }
        // }

        for (Partner_Details__c pd : scope) {
            try {
                IntegrationHandler.getCustomerDetailByNumber(pd.Id, pd.Customer__c);
            } catch (Exception e) {
                System.debug('Error for Customer ' + pd.Id + ': ' + e.getMessage());
                // optionally log errors
            }
        }

    }

    // STEP 3: Optional finish logic
    global void finish(Database.BatchableContext bc) {
        // Send email or log batch completion
        System.debug('GetCustomerByCode_Batch completed.');
    }
}