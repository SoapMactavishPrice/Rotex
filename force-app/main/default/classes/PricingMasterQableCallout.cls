public class PricingMasterQableCallout implements Queueable, Database.AllowsCallouts {
    
    private List<Product2> cspMappingList;
    private Integer index;
    public static Boolean stopChainingInTest = false;
    
    public PricingMasterQableCallout(List<Product2> cspMappingList, Integer index){
        this.index = index;
        this.cspMappingList = cspMappingList;
    }
    
    public void execute(QueueableContext context) {
        if (index < this.cspMappingList.size()) {
            Product2 el = this.cspMappingList[index];
            
            // Perform the callout
            IntegrationHandler.PricingMaster(el.ProductCode); // Perform the callout here
            // IntegrationHandler.getMaterialMaster(el.ProductCode); // Perform the callout here
            // IntegrationHandler.PricingMaster(el.Account__c, el.Sales_Person__c, '2025-05-04', '2025-05-06'); // Perform the callout here
            
            // Chain the next job to process the next invoice
            if (!Test.isRunningTest() || !stopChainingInTest) {
                if (index + 1 < this.cspMappingList.size()) {
                    System.enqueueJob(new PricingMasterQableCallout(this.cspMappingList, index + 1));
                }
            }
        }
    }
    
}