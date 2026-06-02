global class GetCustomerByCode_Batch implements Database.Batchable<sObject>,Database.Stateful,Database.AllowsCallouts {

    // STEP 1: Create list of dates to iterate over
    global database.QueryLocator start(database.BatchableContext bc) {
        return database.getQueryLocator([
            SELECT Id, Name, Sales_Area_Item__c, Customer__c, Account__c, Partner_No__c
            FROM Partner_Details__c
            WHERE Account__c != null
            AND Customer__c != null
            AND Sales_Area_Item__c != null
            AND (Account__r.CreatedDate = TODAY OR Account__r.LastModifiedDate = TODAY)
        ]);
    }

    // STEP 2: For each batch of dates, call the API
    global void execute(Database.BatchableContext bc, List<Partner_Details__c> scope) {

        for (Partner_Details__c pd : scope) {
            try {
                IntegrationHandler.getCustomerDetailByNumber(pd.Id, pd.Partner_No__c);
            } catch (Exception e) {
                System.debug('Error for Customer ' + pd.Id + ': ' + e.getMessage());
            }
        }
    }

    // STEP 3: Optional finish logic
    global void finish(Database.BatchableContext bc) {
        // Send email or log batch completion
        System.debug('GetCustomerByCode_Batch completed.');
    }
}