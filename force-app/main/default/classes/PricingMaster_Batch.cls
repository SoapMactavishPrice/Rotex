global class PricingMaster_Batch implements Database.Batchable<sObject>,Database.Stateful,Database.AllowsCallouts, Schedulable {

    global database.QueryLocator start(database.BatchableContext bc) {
        string todayDate = Datetime.now().format();

        if (Test.isRunningTest()) {
            return database.getQueryLocator([
                SELECT Id, ProductCode
                FROM Product2
                WHERE ProductCode != null
                ORDER BY ProductCode
                LIMIT 1
            ]);
            } else {
                return database.getQueryLocator([
                SELECT Id, ProductCode
                FROM Product2
                WHERE ProductCode != null
                // AND CreatedDate >2025-07-17T16:05:37.990+05:30
                ORDER BY ProductCode
                LIMIT 100
            ]);
        }
    }

    global void Execute(database.BatchableContext bc, List < Product2 > scope) {

        List<Product2> cspMappingList = new List<Product2>();
        cspMappingList.addAll(scope);

        if (!cspMappingList.isEmpty()) {
            // Start processing the first invoice using Queueable
            System.enqueueJob(new PricingMasterQableCallout(cspMappingList, 0));
        }

    }

    global void finish(Database.BatchableContext BC) {}

    // Implement Schedulable
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new PricingMaster_Batch(), 1); // Set batch size to 1
    }

}