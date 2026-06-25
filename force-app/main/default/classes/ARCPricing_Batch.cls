global class ARCPricing_Batch implements Database.Batchable<sObject>,Database.Stateful,Database.AllowsCallouts, Schedulable {

    global database.QueryLocator start(database.BatchableContext bc) {
        string todayDate = Datetime.now().format();

        if (Test.isRunningTest()) {
            return database.getQueryLocator([
                SELECT Id, SAP_Customer_Code__c
                FROM Account
                WHERE SAP_Customer_Code__c != null
                ORDER BY SAP_Customer_Code__c
                LIMIT 1
            ]);
            } else {
                return database.getQueryLocator([
                SELECT Id, SAP_Customer_Code__c
                FROM Account
                WHERE SAP_Customer_Code__c != null
                // AND Id NOT IN (SELECT Account__c FROM Sales_Area_Item__c)
                ORDER BY SAP_Customer_Code__c
                // LIMIT 10
            ]);
        }
    }

    global void Execute(database.BatchableContext bc, List < Account > scope) {

        List<Account> arcpMappingList = new List<Account>();
        arcpMappingList.addAll(scope);

        if (!arcpMappingList.isEmpty()) {
            // Start processing the first invoice using Queueable
            System.enqueueJob(new ARCPricingQableCallout(arcpMappingList, 0));
        }

    }

    global void finish(Database.BatchableContext BC) {}

    // Implement Schedulable
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new ARCPricing_Batch(), 1); // Set batch size to 1
    }

}