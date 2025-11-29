public with sharing class targetvsactualChildController {
  public targetvsactualChildController() {

    }

    @AuraEnabled
    public static string getYearly(String prodId, String fiscId, String empId, String parentTab, String prodCatVal) {
        try {

            system.debug('prodId' + prodId);
            system.debug('fiscId' + fiscId);
            system.debug('empId' + empId);
            system.debug('parentTab' + parentTab);

            if (String.isBlank(fiscId) || String.isBlank(parentTab)) {
                return '{}';
            }

            Boolean isComplete = [select is_Complete__c from Fiscal_Year__c where Id =: fiscId].is_Complete__c;

            Map < String, Object > result = new Map < String, Object > ();
            List < Map < String, Object >> parameterData = new List < Map < String, Object >> ();

            Set < String > masterRecordIds = new Set < String > ();
            Integer index = 0;

            String queryFront = '';
            String whr = '';
            String ordBy = ' ORDER BY Name ASC ';

            whr += ' WHERE Fiscal_Year__c = \'' + fiscId + '\' ';
            System.debug(whr);
            system.debug(parentTab + ' ' + masterRecordIds);
            switch on parentTab {
                when 'Employee_Wise_Target__c' {
                    queryFront = 'SELECT Id, Employee__c, Employee__r.Name, ' +
                        'Fiscal_Year__c, Fiscal_Year__r.Name, Fiscal_Year__r.isActive__c, Fiscal_Year__r.is_Complete__c, Fiscal_Year__r.Is_Planning__c, ' +
                        'Target_Amount__c, ' +
                        'Target_Amount_Monthly__c, ' +
                        'Actual_Amount__c, ' +
                        'Pending_Amount__c ' +
                        'FROM ' + parentTab + ' ';

                    whr += ' AND Employee__c IN: masterRecordIds ';

                    String userQuery = 'SELECT Id, Name, isActive FROM User WHERE isActive = TRUE AND Profile.UserLicense.Name = \'Salesforce\' ORDER BY Name ASC';

                    List < User > users = Database.query(userQuery);
                    System.debug(users.size());
                    if (users.size() == 0) {
                        return '{}';
                    }

                    for (User u: users) {
                        Map < String, Object > tempMap = new Map < String, Object > ();
                        tempMap.put('ParameterId', u.Id);
                        tempMap.put('ParameterName', u.Name);
                        tempMap.put('ParameterEdit', false);
                        tempMap.put('Target_Amount__c', null);
                        tempMap.put('Target_Amount_Monthly__c', null);
                        tempMap.put('Actual_Amount__c', null);
                        tempMap.put('Pending_Amount__c', null);
                        tempMap.put('Target_Amount_New__c', null);
                        tempMap.put('targetAmountEdit', !isComplete);

                        parameterData.add(tempMap);
                        masterRecordIds.add(u.Id);
                    }
                }

                when 'Employee_Wise_Account_Target__c' {
                    queryFront = 'SELECT Id, Name,Account__c,Account__r.Name,Employee__c,' +
                        'Fiscal_Year__c, Fiscal_Year__r.Name, Fiscal_Year__r.isActive__c, Fiscal_Year__r.is_Complete__c, Fiscal_Year__r.Is_Planning__c, ' +
                        'Target_Amount__c, ' +
                        'Monthly_Target_Amount__c, ' +
                        'Actual_Amount__c, ' +
                        'Pending_Amount__c ' +
                        'FROM ' + parentTab + ' ';

                    whr += ' AND Employee__c =: empId ';
                    

                    String ProductQuery = 'SELECT Id, Name from Account order by Name ASC';
                    List < Account > Account = Database.query(ProductQuery);
                    system.debug('Account' + Account.size());
                    system.debug('Account' + Account);

                    if (Account.size() == 0) {
                        return JSON.serialize(parameterData);

                    }

                    Schema.DescribeFieldResult fieldResult = Employee_Wise_Account_Target__c.Account__c.getDescribe();
                    List < Schema.PicklistEntry > ple = fieldResult.getPicklistValues();
                    for (Account p: Account) {
                        // if (p.Family == prodCatVal) {
                            Map < String, Object > tempMap = new Map < String, Object > ();
                            tempMap.put('ParameterId', p.Id);
                            tempMap.put('ParameterName', p.Name);
                            tempMap.put('ParameterEdit', false);
                            tempMap.put('Target_Amount__c', null);
                            tempMap.put('Target_Amount_Monthly__c', null);
                            tempMap.put('Actual_Amount__c', null);
                            tempMap.put('Pending_Amount__c', null);
                            tempMap.put('Target_Amount_New__c', null);
                            tempMap.put('targetAmountEdit', !isComplete);
                            masterRecordIds.add(p.Id);
                            parameterData.add(tempMap);
                        // }

                    }
                }

               

            }

            String query = queryFront + whr + ordBy;
            System.debug('masterRecordIds:>> ' + masterRecordIds);
            System.debug('query:>> ' + query);
           

            List<Order> ordList = [SELECT Id, Name, AccountId, TotalAmount FROM Order];
            
            
            Map<String, Object> ordMap = new Map<String, Object>();
            
            for(Order ord: ordList){
                ordMap.put(ord.AccountId, ord.TotalAmount);
                
            }
            
            for (sObject record: Database.query(query)) {
                System.debug(record);
                Map < String, Object > tempMap = new Map < String, Object > ();
                tempMap.put('Id', record.Id);
                switch on parentTab {
                    when 'Employee_Wise_Target__c' {
                        Employee_Wise_Target__c rec = (Employee_Wise_Target__c) record;
                        tempMap.put('ParameterId', rec.Employee__c);
                        tempMap.put('ParameterName', rec.Employee__r.Name);
                        tempMap.put('ParameterEdit', false);
                        tempMap.put('Target_Amount__c', rec.Target_Amount__c.setScale(2));
                        tempMap.put('Target_Amount_Monthly__c', rec.Target_Amount_Monthly__c.setScale(2));
                        tempMap.put('Actual_Amount__c', rec.Actual_Amount__c.setScale(2));
                        tempMap.put('Pending_Amount__c', rec.Pending_Amount__c.setScale(2));
                        tempMap.put('Target_Amount_New__c', rec.Target_Amount__c.setScale(2));

                       
                        tempMap.put('targetAmountEdit', false);

                        for (Integer j = 0; j < parameterData.size(); j++) {
                            Map < String, Object > empData = (Map < String, Object > ) parameterData[j];
                            if (tempMap.get('ParameterName') == empData.get('ParameterName')) {
                                parameterData[j] = tempMap;
                                break;
                            }
                        }
                    }

                    when 'Employee_Wise_Account_Target__c' {
                        Employee_Wise_Account_Target__c rec = (Employee_Wise_Account_Target__c) record;
                        tempMap.put('ParameterId', rec.Account__c);
                        tempMap.put('ParameterName', rec.Account__r.Name);
                        tempMap.put('ParameterEdit', false);
                        tempMap.put('Target_Amount__c', rec.Target_Amount__c.setScale(2));
                        tempMap.put('Target_Amount_Monthly__c', rec.Monthly_Target_Amount__c.setScale(2));
                        tempMap.put('Actual_Amount__c', ordMap.get(rec.Account__c));
                        //tempMap.put('Actual_Amount__c', rec.Actual_Amount__c.setScale(2));
                        tempMap.put('Pending_Amount__c', rec.Pending_Amount__c.setScale(2));
                        tempMap.put('Target_Amount_New__c', rec.Target_Amount__c.setScale(2));

                      
                        tempMap.put('targetAmountEdit', false);

                        for (Integer j = 0; j < parameterData.size(); j++) {
                            Map < String, Object > empData = (Map < String, Object > ) parameterData[j];
                            if (tempMap.get('ParameterName') == empData.get('ParameterName')) {
                                parameterData[j] = tempMap;
                                break;
                            }
                        }
                    }


                }

                System.debug(parameterData.size());
                System.debug('---------------------------------------------------------------------------');
                index++;
            }

            result.put('parameterData', parameterData);

            return JSON.serialize(result);

        } catch (Exception e) {
            throw new AuraHandledException(e.getLineNumber() + e.getMessage());
           
        }
    }

    @AuraEnabled
    public static string getMonthly(String fiscId, String empId, String parentTab) {
	        try {

            if (String.isBlank(fiscId) || String.isBlank(parentTab)) {
                return '{}';
            }

            Map < String, Object > result = new Map < String, Object > ();

            List < String > months = new List < String > ();
            for (sObject res: [SELECT Month_Name__c, Start_Date__c
                    FROM Employee_Wise_Target_Line_Item__c
                    WHERE Employee_Wise_Target__r.Fiscal_Year__c =: fiscId
                    GROUP BY Start_Date__c, Month_Name__c ORDER BY Start_Date__c
                ]) {
                months.add(String.valueOf(res.get('Month_Name__c')));
            }

            result.put('months', months);

            String queryFront = '';
            String whr = '';
            String ordBy = '';

            whr += ' WHERE Fiscal_Year__c = \'' + fiscId + '\' ';

            switch on parentTab {
                when 'Employee_Wise_Target__c' {
                    queryFront = 'SELECT Id, Employee__c, Employee__r.Name, Start_Date__c, ' +
                        '(SELECT Id, Start_Date__c, End_Date__c, Actual_Amount__c, Pending_Amount__c, Monthly_Target_Amount__c FROM Employee_Wise_Target_Line_Item__r ORDER BY Start_Date__c) ' +
                        ' FROM ' + parentTab + ' ';
                    ordBy = ' ORDER BY Employee__r.Name ASC ';
                }

               

                when 'Employee_Wise_Account_Target__c' {
                    queryFront = 'SELECT Id,Account__c,Account__r.Name, Start_Date__c, ' +
                        '(SELECT Id, Start_Date__c, End_Date__c, Actual_Amount__c, Pending_Amount__c, Monthly_Target_Amount__c FROM Employee_Wise_Account_Target_Line_Item__r ORDER BY Start_Date__c) ' +
                        ' FROM ' + parentTab + ' ';
                    whr += ' AND Employee__c = \'' + empId + '\' ';
                    ordBy = ' ORDER BY Account__r.Name ASC ';
                }

            }
                
                

            String query = queryFront + whr + ordBy;
            System.debug(query);
            for (sObject record: Database.query(query)) {
                Map < String, Object > tempMap = new Map < String, Object > ();
                tempMap.put('Id', record.Id);
                switch on parentTab {
                    when 'Employee_Wise_Target__c' {
                        Employee_Wise_Target__c rec = (Employee_Wise_Target__c) record;
                        tempMap.put('ParameterId', rec.Employee__c);
                        tempMap.put('ParameterName', rec.Employee__r.Name);

                        for (Employee_Wise_Target_Line_Item__c childRec: rec.Employee_Wise_Target_Line_Item__r) {
                            Map < String, Object > childMap = new Map < String, Object > ();
                            childMap.put('ParameterId', childRec.Id);
                            childMap.put('Monthly_Target_Amount__c', childRec.Monthly_Target_Amount__c.setScale(2));
                            childMap.put('Monthly_Target_Amount_New__c', childRec.Monthly_Target_Amount__c.setScale(2));
                           // childMap.put('Actual_Amount__c', childRec.Actual_Amount__c != null ? childRec.Actual_Amount__c.setScale(2) : 0);
                            childMap.put('Pending_Amount__c', childRec.Pending_Amount__c.setScale(2));
                           
                            childMap.put('targetAmountEdit', false);

                            if (tempMap.containsKey('childData')) {
                                List < Object > tempList = (List < object > ) tempMap.get('childData');
                                tempList.add(childMap);
                            } else {
                                tempMap.put('childData', new List < Object > {
                                    childMap
                                });
                            }
                        }
                    }

                    when 'Employee_Wise_Account_Target__c' {
                        Employee_Wise_Account_Target__c rec = (Employee_Wise_Account_Target__c) record;
                        tempMap.put('ParameterId', rec.Account__c);
                        tempMap.put('ParameterName', rec.Account__r.Name);

                        for (Employee_Wise_Account_Target_Line_Item__c childRec: rec.Employee_Wise_Account_Target_Line_Item__r) {
                            Map < String, Object > childMap = new Map < String, Object > ();
                            childMap.put('ParameterId', childRec.Id);
                            childMap.put('Monthly_Target_Amount__c', childRec.Monthly_Target_Amount__c.setScale(2));
                            childMap.put('Monthly_Target_Amount_New__c', childRec.Monthly_Target_Amount__c.setScale(2));
                            childMap.put('Actual_Amount__c', childRec.Actual_Amount__c != null ? childRec.Actual_Amount__c.setScale(2) : 0);
                            childMap.put('Pending_Amount__c', childRec.Pending_Amount__c.setScale(2));
                           
                            childMap.put('targetAmountEdit', false);

                            if (tempMap.containsKey('childData')) {
                                List < Object > tempList = (List < object > ) tempMap.get('childData');
                                tempList.add(childMap);
                            } else {
                                tempMap.put('childData', new List < Object > {
                                    childMap
                                });
                            }
                        }
                    }

                   
                }

                if (result.containsKey('parameterData')) {
                    List < Object > tempList = (List < Object > ) result.get('parameterData');
                    tempList.add(tempMap);
                } else {
                    result.put('parameterData', new List < Object > {
                        tempMap
                    });
                }
            }

            return JSON.serialize(result);

        } catch (Exception e) {
            throw new AuraHandledException(e.getLineNumber() + e.getMessage());
            /*
        result.put('status', 'Error');
        result.put('message', e.getMessage());
        return JSON.serialize(result);
        */
        }
    }   
}