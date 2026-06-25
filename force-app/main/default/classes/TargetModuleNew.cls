public class TargetModuleNew {

    @AuraEnabled(cacheable = true)
    public static string getDefaultFilterValues() {
            Map < String, Object > result = new Map < String, Object > ();
            result.put('Fiscal_Year__c', [SELECT Id FROM Fiscal_Year__c WHERE isActive__c = true LIMIT 1].Id);
        return JSON.serialize(result);
    }
   @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts(String lastRecordId, Integer limitSize) {
        String query = 'SELECT Id, Name, Owner.Name,Owner.Manager.Name,Owner.ManagerId FROM Account ';
        if (lastRecordId != null) {
            query += 'WHERE Id > :lastRecordId ';
        }
        query += 'ORDER BY Id ASC LIMIT :limitSize';
        return Database.query(query);
    }

    @AuraEnabled
    public static void saveTargetModuleRecords(List<Target__c> records) {
        if(records != null && !records.isEmpty()) {
            upsert records; // insert or update
        }
    }

   @AuraEnabled(cacheable=true)
    public static Map<Id, Target__c> getExistingTargetModules(List<Id> accountIds,string fiscalId) {
        Map<Id, Target__c> mapExisting = new Map<Id, Target__c>();
        system.debug('fiscId--'+fiscalId);
        for(Target__c tm : [
            SELECT Id, Customer_Name__c, Qtr_1_Target__c, Qtr_2_Target__c, Qtr_3_Target__c, Qtr_4_Target__c,Total_Target__c,Total_Actual__c,
            Qtr_1_Actual__c, Qtr_2_Actual__c, Qtr_3_Actual__c, Qtr_4_Actual__c ,Reporting_Manager__c,Reporting_Manager__r.Name,Total_Visits_Per_Year__c,Actual_Visits_Per_Year__c
            FROM Target__c 
            WHERE Customer_Name__c IN :accountIds AND fiscal_year__c =:fiscalId
        ]) {
            mapExisting.put(tm.Customer_Name__c, tm);
        }
        return mapExisting;
    }
}