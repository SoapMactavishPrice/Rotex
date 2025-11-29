public with sharing class CustomDataTableController {

    @AuraEnabled(cacheable=true)
    public static List<SObject> fetchData(String searchKey, String lastRecordId, Integer pageSize, String sortBy, String sortDirection) {
        // Base SOQL Query
        String query = 'SELECT Id, Name FROM Product2 WHERE Name LIKE :searchKey ';
        // Pagination using keyset
        if (lastRecordId != null) {
            query += ' AND Id > :lastRecordId';
        }
        // Add Sorting
        if (sortBy != null && sortDirection != null) {
            query += ' ORDER BY ' + sortBy + ' ' + sortDirection;
        } else {
            query += ' ORDER BY Id ASC';  // Use Id to guarantee stable sorting
        }
        // Limit for pagination
        query += ' LIMIT :pageSize';
        system.debug('query-->'+query);
        return Database.query(query);
    }
    @AuraEnabled(cacheable=true)
    public static Integer countRecords(String searchKey) {
        return [SELECT COUNT() FROM Product2 WHERE Name LIKE :searchKey];
    }

}