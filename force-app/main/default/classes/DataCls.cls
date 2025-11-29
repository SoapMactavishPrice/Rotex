public class DataCls {
    @TestVisible
     private static List<Fiscal_Year__c> fiscalYearMasters;
    
    
    public static List<Fiscal_Year__c> getFiscalYearMaster() {
        if(fiscalYearMasters != null) {  
           System.debug('fiscalYearMasters'+fiscalYearMasters.size());
            return fiscalYearMasters;
        }
        
        else {
            return getFiscalYearMaster(null, null);
        }
    }

   public static List<Fiscal_Year__c> getFiscalYearMaster(String fieldName, Set<Id> ids) {
       if(fiscalYearMasters != null) {
            System.debug('fiscalYearMasters' + fiscalYearMasters.size());
            return fiscalYearMasters;
        }
        else {
            system.debug('data slds else');
            List<String> fields = new List<String>(Fiscal_Year__c.SObjectType.getDescribe().fields.getMap().keySet());
            String query = 'SELECT '+String.join(fields, ',')+' FROM Fiscal_Year__c';
            if(String.isNotBlank(fieldName) && (ids != null || ids.size() > 0)) {
                query += ' WHERE '+fieldName+' IN: ids';
            }
            fiscalYearMasters = Database.query(query);
            System.debug('fiscalYearMasters' + fiscalYearMasters.size());
            return fiscalYearMasters;
        }


}
}