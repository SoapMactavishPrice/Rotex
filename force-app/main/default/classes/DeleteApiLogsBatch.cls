global class DeleteApiLogsBatch implements Database.Batchable<SObject>, Schedulable {
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        Date thirtyDaysAgo = Date.today().addDays(-30);
        return Database.getQueryLocator([
            SELECT Id
            FROM API_Log__c
            WHERE CreatedDate <= :thirtyDaysAgo
        ]);
    }
    
    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        try {
            Database.delete(scope, false); // ✅ safer than raw delete
        } catch (Exception e) {
            System.debug('Error deleting logs: ' + e.getMessage());
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        System.debug('DeleteApiLogsBatch completed at ' + System.now());
    }
    
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new DeleteApiLogsBatch(), 200);
    }
}