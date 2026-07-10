public class CustomerApprovalTriggerHandler {

    public static void handleAfterInsert(List<Account> newAccounts) {

        // Get Customer Record Type Id
        RecordType rt;
        try {
            rt = [
                SELECT Id FROM RecordType
                WHERE SObjectType = 'Account'
                  AND DeveloperName = 'Customer'
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('RecordType not found: ' + e.getMessage());
            return;
        }

        // Re-query accounts to get RecordTypeId reliably
        Set<Id> accIds = new Set<Id>();
        for (Account acc : newAccounts) {
            accIds.add(acc.Id);
        }

        List<Account> accounts = [
            SELECT Id, RecordTypeId
            FROM Account
            WHERE Id IN :accIds
        ];

        List<Approval.ProcessSubmitRequest> requests =
            new List<Approval.ProcessSubmitRequest>();

        for (Account acc : accounts) {

            if (acc.RecordTypeId == rt.Id) {

                Approval.ProcessSubmitRequest req =
                    new Approval.ProcessSubmitRequest();

                req.setObjectId(acc.Id);
                req.setSubmitterId(UserInfo.getUserId());
                req.setProcessDefinitionNameOrId('Customer_Approval');
                req.setSkipEntryCriteria(false);

                requests.add(req);
            }
        }

        if (!requests.isEmpty()) {
            try {
                List<Approval.ProcessResult> results =
                    Approval.process(requests);

                for (Approval.ProcessResult result : results) {
                    System.debug('Approval submitted: ' + result.isSuccess());
                    if (!result.isSuccess()) {
                        System.debug('Errors: ' + result.getErrors());
                    }
                }
            } catch (Exception e) {
                System.debug('Approval submission failed: ' + e.getMessage());
            }
        }
    }
}