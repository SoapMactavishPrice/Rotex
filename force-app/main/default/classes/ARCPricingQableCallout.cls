public class ARCPricingQableCallout implements Queueable, Database.AllowsCallouts {
    
    private List<Account> arcpMappingList;
    private Integer index;
    public static Boolean stopChainingInTest = false;
    
    public ARCPricingQableCallout(List<Account> arcpMappingList, Integer index){
        this.index = index;
        this.arcpMappingList = arcpMappingList;
    }
    
    public void execute(QueueableContext context) {
        if (index < this.arcpMappingList.size()) {
            Account el = this.arcpMappingList[index];
            
            // Perform the callout
            IntegrationHandler.ARCPricingMaster(el.SAP_Customer_Code__c); // Perform the callout here
            
            // Chain the next job to process the next invoice
            if (!Test.isRunningTest() || !stopChainingInTest) {
                if (index + 1 < this.arcpMappingList.size()) {
                    System.enqueueJob(new ARCPricingQableCallout(this.arcpMappingList, index + 1));
                }
            }
        }
    }
    
}