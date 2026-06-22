global class CustomerSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, SAP_Customer_Code__c
            FROM Account
            WHERE SAP_Customer_Code__c != null
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Account> scope) {

        for(Account acc : scope) {
            try {
                SyncSapToSf.syncCustomerThroughBatch(acc.SAP_Customer_Code__c);
            } catch(Exception e) {
                System.debug(
                    'Customer: ' + acc.SAP_Customer_Code__c +
                    ' Error: ' + e.getMessage()
                );
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('Customer Sync Completed');
    }
}