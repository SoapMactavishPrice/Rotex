global class ZPR0PricingBatch implements Database.Batchable<SObject>,
                                          Database.Stateful,
                                          Database.AllowsCallouts,
                                          Schedulable {

    // Dummy query - executes only once
    global Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator([
            SELECT Id
            FROM User
            LIMIT 1
        ]);

    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {

        System.enqueueJob(new ZPR0PricingQueueable());

    }

    global void finish(Database.BatchableContext bc) {

        System.debug('ZPR0 Pricing Batch Completed.');

    }

    // For Scheduling
    global void execute(SchedulableContext sc) {

        Database.executeBatch(new ZPR0PricingBatch(), 1);

    }

}