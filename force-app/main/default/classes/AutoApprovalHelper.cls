public class AutoApprovalHelper {

    public static Boolean isRunning = false;

    public static Boolean submitApproval(Id recordId, String processName){

        try{
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(recordId);
            req.setProcessDefinitionNameOrId(processName);

            Approval.ProcessResult result = Approval.process(req);

            System.debug('Approval Attempt for: ' + processName + ' | Status: ' + result.getInstanceStatus());

            // TRUE = submitted and matched process criteria
            return (result.isSuccess() && result.getInstanceStatus() == 'Submitted');

        } catch(Exception e){
            System.debug('⚠ Approval Error: ' + e.getMessage());
            return false;
        }
    }
}