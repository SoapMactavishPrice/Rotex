global class InvoiceMasterBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    global Database.QueryLocator start(Database.BatchableContext bc) {

        System.debug('===== InvoiceMasterBatch START =====');

        return Database.getQueryLocator([
            SELECT Id, Name, Bill_Doc_No__c
            FROM SO_Invoice__c
            WHERE Bill_Doc_No__c != null
        ]);
    }

    global void execute(
        Database.BatchableContext bc,
        List<SO_Invoice__c> scope
    ) {

        System.debug('===== InvoiceMasterBatch EXECUTE =====');
        System.debug('Batch Scope Size: ' + scope.size());

        Integer successCount = 0;
        Integer failureCount = 0;

        for (SO_Invoice__c inv : scope) {

            System.debug(
                'Processing SO_Invoice__c | Id=' + inv.Id +
                ' | Name=' + inv.Name +
                ' | Bill_Doc_No__c=' + inv.Bill_Doc_No__c
            );

            if (String.isBlank(inv.Bill_Doc_No__c)) {
                System.debug(
                    'SKIPPED - Bill_Doc_No__c is blank | Id=' + inv.Id
                );
                continue;
            }

            try {

                System.debug(
                    'Calling Invoice_number.getInvoiceMasterNumber()' +
                    ' | Bill Doc No=' + inv.Bill_Doc_No__c
                );

                Invoice_number.getInvoiceMasterNumber(
                    inv.Bill_Doc_No__c
                );
                
                //IntegrationHandler.getInvoiceMaster();

                successCount++;

                System.debug(
                    'API CALL COMPLETED | Bill Doc No=' +
                    inv.Bill_Doc_No__c
                );

            } catch (Exception e) {

                failureCount++;

                System.debug(
                    'API CALL FAILED | Bill Doc No=' +
                    inv.Bill_Doc_No__c +
                    ' | Error=' + e.getMessage() +
                    ' | Line=' + e.getLineNumber()
                );
            }
        }

        System.debug(
            'Batch Execute Summary | Scope=' + scope.size() +
            ' | Success=' + successCount +
            ' | Failed=' + failureCount
        );
    }

    global void finish(Database.BatchableContext bc) {

        System.debug('===== InvoiceMasterBatch FINISH =====');
        System.debug('Job Id: ' + bc.getJobId());
        System.debug('InvoiceMasterBatch completed successfully.');
    }
}