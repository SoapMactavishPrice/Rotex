global class GetCustomerByCode_Batch implements
    Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts, Schedulable {
    // Scheduler Entry Point
    global void execute(SchedulableContext sc) {
            Integer batchSize = Test.isRunningTest() ? 200 : 1;
            Database.executeBatch(new GetCustomerByCode_Batch(),batchSize);
        //  Database.executeBatch(new GetCustomerByCode_Batch(), 50);
    }
    // STEP 1: Query Records
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   Sales_Area_Item__c,
                   Customer__c,
                   Account__c,
                   Partner_No__c
            FROM Partner_Details__c
            WHERE Account__c != null
            AND Customer__c != null
            AND Sales_Area_Item__c != null
            AND (
                Account__r.CreatedDate = TODAY
                OR Account__r.LastModifiedDate = TODAY
            )
        ]);
    }
    // STEP 2: Process Records
    global void execute(Database.BatchableContext bc, List<Partner_Details__c> scope) {
        for (Partner_Details__c pd : scope) {
            try {
                IntegrationHandler.getCustomerDetailByNumber(pd.Id, pd.Partner_No__c);
            } catch (Exception e) {
                System.debug('Error for Customer ' + pd.Id + ': ' + e.getMessage());
            }
        }
    }
    // STEP 3: Finish
    global void finish(Database.BatchableContext bc) {
        System.debug('GetCustomerByCode_Batch completed.');
    }
}