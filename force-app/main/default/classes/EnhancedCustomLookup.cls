public with sharing class EnhancedCustomLookup {
    public EnhancedCustomLookup() {

    }

    @AuraEnabled(cacheable = true)
    public static List < sobject > findRecords(String searchKey, String objectName, String recdataid, string returnFields, List < String > queryFields, String displayFields, String filter, String sortColumn, String maxResults) {
        String a = '';
        if (returnFields != null && returnFields.trim() != '') {
            a = returnFields;
        }
        if (displayFields != null && displayFields.trim() != '') {
            a = (a == '' ? displayFields : a + ',' + displayFields);
        }
        Set < String > b = new Set < String > ();
        String col = '';
        if (a.trim() != '') {
            for (String t: a.split(',')) {
                b.add(t.trim());
            }
            for (String t: b) {
                col = col + ',' + t;
            }
        }

        /* if (returnFields != null && returnFields != '') {
            returnFields = ',' + returnFields;
        } else {
            returnFields = '';
        } */

        string searchText = '\'%' + String.escapeSingleQuotes(searchKey) + '%\'';

        //string vQuery = 'SELECT Id, Name '+ returnFields + ' FROM ' +objectName+ ' WHERE Name LIKE '+searchText+' LIMIT 10';

        String fields = '';
        if (objectName == 'Case') {
            fields = 'CaseNumber ';
        } if (objectName == 'Account') {
            fields = 'Name,SAP_Customer_Code__c ';
        } else {
            fields = 'Name ';
        }

        String vQuery = 'SELECT Id, ' + fields + col + ' FROM ' + objectName + ' WHERE ';

        System.debug('queryFields:>> '+ queryFields);

        if (queryFields == null || queryFields.isEmpty()) {
            if (objectName == 'Case') {
                vQuery += ' CaseNumber LIKE ' + searchText;
            } if (objectName == 'Account') {
                vQuery += ' Name LIKE ' + searchText + ' OR SAP_Customer_Code__c LIKE ' + searchText;
            } else {
                vQuery += ' Name LIKE ' + searchText;
            }
        } else {
            string likeField = '';
            for (string field: queryFields) {
                likeField += ' OR ' + field + ' LIKE ' + searchText;
            }
            vQuery += ' (' + likeField.removeStart(' OR ') + ') ';
        }

        if (filter != null && filter != '') {
            vQuery += ' AND (' + filter + ')';
        }

        if (sortColumn != null && sortColumn != '') {
            vQuery += ' ORDER BY ' + sortColumn;
        }

        if (maxResults == null || maxResults == '') {
            maxResults = '10';
        }

        vQuery += ' LIMIT ' + maxResults;

        System.debug(vQuery);

        return Database.query(vQuery);
    }

    @AuraEnabled
    public static sObject fetchDefaultRecord(string recordId, string sObjectApiName, string returnFields) {
        string sRecId = recordId;

        if (returnFields != null && returnFields != '') {
            returnFields = ',' + returnFields;
        } else {
            returnFields = '';
        }
        String fields = '';
        if (sObjectApiName == 'Case') {
            fields = 'CaseNumber ';
        } if (sObjectApiName == 'Account') {
            fields = 'Name,SAP_Customer_Code__c ';
        } else {
            fields = 'Name ';
        }
        string sQuery = 'Select Id, ' + fields + returnFields + ' From ' + sObjectApiName + ' Where Id = : sRecId LIMIT 1';
        for (sObject obj: database.query(sQuery)) {
            return obj;
        }
        return null;
    }

}