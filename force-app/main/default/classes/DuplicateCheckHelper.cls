public without sharing class DuplicateCheckHelper {

    public static Account findGstPinDuplicate(String gstNo, String pinCode, Id excludeId) {
        String pinField = getPinCodeFieldApiName();

        String query =
            'SELECT Id, Name, Channel_Partner_Name__c, Channel_Partner_Name__r.Name ' +
            'FROM Account ' +
            'WHERE GST_No__c = :gstNo ' +
            'AND ' + pinField + ' = :pinCode';

        if (excludeId != null) {
            query += ' AND Id != :excludeId';
        }

        query += ' LIMIT 1';

        List<Account> duplicates = Database.query(query);
        return duplicates.isEmpty() ? null : duplicates[0];
    }

    private static String getPinCodeFieldApiName() {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();

        if (fieldMap.containsKey('Postal_Code__c')) {
            return 'Postal_Code__c';
        }

        return 'Pin_Code__c';
    }
}