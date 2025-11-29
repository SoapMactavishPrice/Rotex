public with sharing class TargetAllInOneTriggerHandler {

    // Master - to update target amount if monthly target amount is updated
    public static void rollupTargetAmount(List < sObject > newRecords, Map < Id, sObject > oldMap, String objType) {
        for (sObject obj: newRecords) {
            if (objType == 'EmployeeWiseTarget') {
                if (obj.get('Target_Amount_Monthly__c') != oldMap.get(obj.Id).get('Target_Amount_Monthly__c')) {
                    obj.put('Target_Amount__c', obj.get('Target_Amount_Monthly__c'));
                }
            }
            if (objType == 'EmployeeWiseAccountTarget') {
                if (obj.get('Monthly_Target_Amount__c') != oldMap.get(obj.Id).get('Monthly_Target_Amount__c')) {
                    obj.put('Target_Amount__c', obj.get('Monthly_Target_Amount__c'));
                }
            }
        }
    }

    // Master - create monthly entries depending on fiscal year and master
    public static void createMonthlyTargetEntries(List < sObject > newRecords) {
        System.debug('Before' + DataCls.getFiscalYearMaster());
        Map < Id, Fiscal_Year__c > mapFiscalYears = new Map < Id, Fiscal_Year__c > (DataCls.getFiscalYearMaster());
        System.debug('After' + DataCls.getFiscalYearMaster());
        List < sObject > lineItems = new List < sObject > ();
	
        //List<EmployeeWiseProductCategoryTarget_Line__c> lineItems = new List<EmployeeWiseProductCategoryTarget_Line__c>();

        for (sObject obj: newRecords) {
            Fiscal_Year__c fy = mapFiscalYears.get((Id) obj.get('Fiscal_Year__c'));
            
            system.debug('stage1');

            //Date dt1 = fy.FY_Start_Date__c.toStartOfMonth();
             Date dt1 = Date.newInstance(fy.FY_Start_Date__c.year(), fy.FY_Start_Date__c.month(), 1);
            system.debug('dt1-->' + dt1);
            if (fy.is_Complete__c) {
                obj.addError('Can\'t create records for old/previous Fiscal Year');
            }
            Date dt2 = fy.FY_End_Date__c;
            Integer monthsInBetween = dt1.toStartOfMonth().monthsBetween(dt2.addDays(1));
            while (dt1 < dt2) {
                sObject lineItem;

                switch on String.valueOf(obj.getSObjectType()) {
                    when 'Employee_Wise_Target__c' {
                        lineItem = new Employee_Wise_Target_Line_Item__c();
                        lineItem.put('Employee_Wise_Target__c', obj.get('Id'));
                    }

                    when 'Employee_Wise_Account_Target__c' {
                        lineItem = new Employee_Wise_Account_Target_Line_Item__c();
                        lineItem.put('Employee_Wise_Account_Target__c', obj.get('Id'));
                    }
               /*     when 'Employee_Wise_Product_Category_Target__c' {
                        lineItem = new EmployeeWiseProductCategoryTarget_Line__c();
                        lineItem.put('Employee_Wise_Product_Category_Target__c', obj.get('Id'));
                    }  */
                }

                lineItem.put('Start_Date__c', dt1);
                lineItem.put('End_Date__c', dt1.addMonths(1) - 1);
                if ((Date) lineItem.get('End_Date__c') < System.today()) {
                    lineItem.put('Monthly_Target_Amount__c', 0);
                    monthsInBetween = monthsInBetween - 1;
                } else {
                    lineItem.put('Monthly_Target_Amount__c', (Decimal) obj.get('Target_Amount__c') / monthsInBetween);
                }
                lineItems.add(lineItem);
                dt1 = dt1.addMonths(1);
            }
        }
        system.debug('lineItems->' + lineItems);
        insert lineItems;
    }

    // Master - if target amount is updated in the master, then distribute it evenly for the current and future months
    public static void updateMonthlyTargetEntries(List < sObject > newRecords, Map < Id, sObject > oldMap, Map < Id, sObject > newMap, String objType) {
        System.debug('updateMonthlyTargetEntries:>>');
        Set < Id > objIds = new Set < Id > ();
        for (sObject obj: newRecords) {
            if (objType == 'EmployeeWiseTarget') {
                if (obj.get('Target_Amount__c') != oldMap.get(obj.Id).get('Target_Amount__c') &&
                    obj.get('Target_Amount__c') != obj.get('Target_Amount_Monthly__c')) {
                    objIds.add((Id) obj.get('Id'));
                }
            }
            if (objType == 'EmployeeWiseAccountTarget') {
                if (obj.get('Target_Amount__c') != oldMap.get(obj.Id).get('Target_Amount__c') &&
                    obj.get('Target_Amount__c') != obj.get('Monthly_Target_Amount__c')) {
                    objIds.add((Id) obj.get('Id'));
                }
            }
        }

        if (objIds.size() > 0) {
            Date currentDate = System.today().toStartOfMonth();

            Map < Id, sObject > objMap;

            switch on String.valueOf(newRecords[0].getSObjectType()) {
                when 'Employee_Wise_Target__c' {
                    objMap = new Map < Id, Employee_Wise_Target__c > (
                        [SELECT Id, Target_Quantity__c,Target_Amount__c,
                            (
                                SELECT Id, Monthly_Target_Amount__c, Month_Name__c FROM Employee_Wise_Target_Line_Item__r WHERE Start_Date__c >=: currentDate ORDER BY Start_Date__c
                            )
                            FROM Employee_Wise_Target__c
                            WHERE Id IN: objIds
                        ]
                    );
                }

                when 'Employee_Wise_Account_Target__c' {
                    objMap = new Map < Id, Employee_Wise_Account_Target__c > (
                        [SELECT Id, Target_Quantity__c,Target_Amount__c,
                            (
                                SELECT Id, Monthly_Target_Amount__c, Month_Name__c FROM Employee_Wise_Account_Target_Line_Item__r WHERE Start_Date__c >=: currentDate ORDER BY Start_Date__c
                            )
                            FROM Employee_Wise_Account_Target__c
                            WHERE Id IN: objIds
                        ]
                    );
                }
             /*   when 'Employee_Wise_Product_Category_Target__c' {
                    objMap = new Map < Id, Employee_Wise_Product_Category_Target__c > (
                        [SELECT Id, Target_Quantity__c,
                            (
                                SELECT Id, Monthly_Target_Quantity__c, Month_Name__c FROM EmployeeWiseProductCategoryTarget_Lines__r WHERE Start_Date__c >=: currentDate ORDER BY Start_Date__c
                            )
                            FROM Employee_Wise_Product_Category_Target__c
                            WHERE Id IN: objIds
                        ]
                    );
                }   */
            }

            List < sObject > objLineItemsForUpdate = new List < sObject > ();

            for (sObject obj: objMap.values()) {
                if (obj.get('Target_Amount__c') != oldMap.get(obj.Id).get('Target_Amount__c')) {

                    List < sObject > childList;
                    String errorString = 'No child items available to proceed with updating target Amount';
                    switch on String.valueOf(newRecords[0].getSObjectType()) {
                        when 'Employee_Wise_Target__c' {
                            System.debug(JSON.serialize(objMap.get(obj.Id)));
                            Employee_Wise_Target__c masterObj = (Employee_Wise_Target__c) objMap.get(obj.Id);
                            childList = masterObj.Employee_Wise_Target_Line_Item__r;
                            if (childList.size() == 0) {
                                ((Employee_Wise_Target__c) newMap.get(obj.Id)).Target_Amount__c.addError(errorString);
                            }
                        }

                        when 'Employee_Wise_Account_Target__c' {
                            Employee_Wise_Account_Target__c masterObj = (Employee_Wise_Account_Target__c) objMap.get(obj.Id);
                            childList = masterObj.Employee_Wise_Account_Target_Line_Item__r;
                            if (childList.size() == 0) {
                                ((Employee_Wise_Account_Target__c) newMap.get(obj.Id)).Target_Amount__c.addError(errorString);
                            }
                        }
                    /*    when 'Employee_Wise_Product_Category_Target__c' {
                            Employee_Wise_Product_Category_Target__c masterObj = (Employee_Wise_Product_Category_Target__c) objMap.get(obj.Id);
                            childList = masterObj.EmployeeWiseProductCategoryTarget_Lines__r;
                            if (childList.size() == 0) {
                                ((Employee_Wise_Product_Category_Target__c) newMap.get(obj.Id)).Target_Quantity__c.addError(errorString);
                            }
                        }  */
                    }

                /*    Decimal diff = (Decimal) obj.get('Target_Amount__c') - (Decimal) oldMap.get(obj.Id).get('Target_Amount__c');
                    Decimal diffPerMonth = diff / childList.size();

                    for (sObject childObj: childList) {
                        childObj.put('Monthly_Target_Amount__c', (Decimal) childObj.get('Monthly_Target_Amount__c') + diffPerMonth);
                        objLineItemsForUpdate.add(childObj);
                    }	*/
                    
                    		
                    // Ensure null checks for diff and diffPerMonth calculations
                        Decimal diff = 0;
                        Decimal diffPerMonth = 0;
                        
                        // Null check for Target_Amount__c in both obj and oldMap
                        if (obj.get('Target_Amount__c') != null && oldMap.get(obj.Id) != null && oldMap.get(obj.Id).get('Target_Amount__c') != null) {
                            diff = (Decimal) obj.get('Target_Amount__c') - (Decimal) oldMap.get(obj.Id).get('Target_Amount__c');
                        }
                        
                        // Null check for childList to avoid division by zero
                        if (childList.size() > 0) {
                            diffPerMonth = diff / childList.size();
                        }
                        
                        // Now updating child objects
                        for (sObject childObj : childList) {
                            // Check for null before updating 'Monthly_Target_Amount__c'
                            if (childObj.get('Monthly_Target_Amount__c') != null) {
                                childObj.put('Monthly_Target_Amount__c', (Decimal) childObj.get('Monthly_Target_Amount__c') + diffPerMonth);
                            } else {
                                // If null, initialize it to diffPerMonth (or other default value)
                                childObj.put('Monthly_Target_Amount__c', diffPerMonth);
                            }
                            objLineItemsForUpdate.add(childObj);
                        }

                    
                    
                    
                    
                    
                    
                    
                    
                }
            }

            if (objLineItemsForUpdate.size() > 0) {
                System.debug('objLineItemsForUpdate:>> ' +objLineItemsForUpdate);
                update objLineItemsForUpdate;
            }
        }
    }

    // Master - on update to target amount of employee target, update related branch
    /*public static void updateBranchTarget(List<Employee_Wise_Sales_Target__c> newRecords, Map<Id, Employee_Wise_Sales_Target__c> oldMap) {
        Set<String> branches = new Set<String>();
        Set<Id> fiscalYears = new Set<Id>();
        Set<Id> compIds = new Set<Id>();
        Set<String> keys = new Set<String>();

        Map<String, Decimal> mapTargetAmountBranchWise = new Map<String, Decimal>();

        for (Employee_Wise_Sales_Target__c emp : newRecords) {
            System.debug(emp.Branch__c + ' -> ' + emp.Fiscal_Year__c + ' -> ' + emp.Company_Master__c);
            if (oldMap == null) {
                branches.add(emp.Branch__c);
                fiscalYears.add(emp.Fiscal_Year__c);
                compIds.add(emp.Company_Master__c);

                String key = emp.Branch__c + '-' + String.valueOf(emp.Fiscal_Year__c).subString(0, 15) + '-' + String.valueOf(emp.Company_Master__c).subString(0, 15);

                mapTargetAmountBranchWise.put(key, emp.Target_Quantity__c);
            } else if (emp.Target_Quantity__c != oldMap.get(emp.Id).Target_Quantity__c) {
                branches.add(emp.Branch__c);
                fiscalYears.add(emp.Fiscal_Year__c);
                compIds.add(emp.Company_Master__c);

                String key = emp.Branch__c + '-' + String.valueOf(emp.Fiscal_Year__c).subString(0, 15) + '-' + String.valueOf(emp.Company_Master__c).subString(0, 15);

                mapTargetAmountBranchWise.put(key, emp.Target_Quantity__c);
            }
        }

        Map<String, Branch_Wise_Sales_Target__c> mapBWST = new Map<String, Branch_Wise_Sales_Target__c>();
        for (Branch_Wise_Sales_Target__c bwst : [SELECT Id, Branch__c, Fiscal_Year__c, Company_Master__c FROM Branch_Wise_Sales_Target__c WHERE Branch__c IN: branches AND Fiscal_Year__c IN: fiscalYears AND Company_Master__c IN: compIds]) {
            String key = bwst.Branch__c + '-' + String.valueOf(bwst.Fiscal_Year__c).subString(0, 15) + '-' + String.valueOf(bwst.Company_Master__c).subString(0, 15);
            mapBWST.put(key, bwst);
        }

        List<Branch_Wise_Sales_Target__c> bwstList = new List<Branch_Wise_Sales_Target__c>();

        for (String key : mapBWST.keySet()) {
            if (mapTargetAmountBranchWise.containsKey(key)) {
                Branch_Wise_Sales_Target__c bwst = new Branch_Wise_Sales_Target__c();
                bwst.Id = mapBWST.get(key).Id;
                bwstList.add(bwst);
            }
        }

        if (bwstList.size() > 0) {
            update bwstList;
        }
    }
    */

    // Master - Branch master target is the sum of all the employees working against that branch
    /*public static void updateTargetAmountFromEmployeeTarget(List<Branch_Wise_Sales_Target__c> newRecords, Map<Id, Branch_Wise_Sales_Target__c> oldMap) {
        Set<String> branchIds = new Set<String>();
        Set<Id> fiscalYearIds = new Set<Id>();

        for (Branch_Wise_Sales_Target__c bwst : newRecords) {
            branchIds.add(bwst.Branch__c);
            fiscalYearIds.add(bwst.Fiscal_Year__c);
        }

        Map<String, Decimal> mapBranchWiseSalesTarget = new Map<String, Decimal>();
        for (Employee_Wise_Sales_Target__c ewst : [SELECT Id, Branch__c, Fiscal_Year__c, Target_Quantity__c, Company_Master__r.Name
            FROM Employee_Wise_Sales_Target__c
            WHERE Branch__c IN: branchIds AND Fiscal_Year__c IN: fiscalYearIds]) {
            String key = ewst.Branch__c + '-' + String.valueOf(ewst.Fiscal_Year__c).subString(0, 15) + '-' + String.valueOf(ewst.Company_Master__r.Name);
            if (mapBranchWiseSalesTarget.containsKey(key)) {
                mapBranchWiseSalesTarget.put(key, mapBranchWiseSalesTarget.get(key) + ewst.Target_Quantity__c);
            } else {
                mapBranchWiseSalesTarget.put(key, ewst.Target_Quantity__c);
            }
        }

        for (Branch_Wise_Sales_Target__c bwst : newRecords) {
            String key = bwst.Branch__c + '-' + String.valueOf(bwst.Fiscal_Year__c).subString(0, 15) + '-' + bwst.Company_Master_Name_Formula__c;
            if (mapBranchWiseSalesTarget.containsKey(key)) {
                bwst.Target_Quantity__c = mapBranchWiseSalesTarget.get(key);
            }
        }
    }
    */

    // Master - Share records with respective parameter
    public static void shareRecordWithUser(List < sObject > newRecords, Map < Id, sObject > oldMap) {
        List < Id > compIds = new List < Id > ();
        Set < Id > itemGroupIds = new Set < Id > ();
        Set < Id > recIds = new Set < Id > ();
        Set < String > recordObjectNames = new Set < String > ();

        for (sObject rec: newRecords) {
            recordObjectNames.add(String.valueOf(rec.getSObjectType()).replace('__c', '__Share'));
            switch on String.valueOf(rec.getSObjectType()) {
                when 'Employee_Wise_Target__c', 'Employee_Wise_Account_Target__c' {
                    // Will be sharing with the User only so not collecting Ids from the records
                }
                //when 'Branch_Wise_Sales_Target__c' {
                //    compIds.add((Id) rec.get('Company_Master__c'));
                //}
                when 'Employee_Wise_Product_Category_Target__c' {
                    // itemGroupIds.add((Id) rec.get('Item_Group_Master__c')); // Need to check (Changes by HA)
                }
            }
        }

        Map < Id, Id > mapParentToCompany = new Map < Id, Id > ();
        Map < Id, Id > mapParentToItemGroup = new Map < Id, Id > ();
        //Map<Id, Id> mapParentToBranch = new Map<Id, Id>();

        if (itemGroupIds.size() > 0) {
            for (Item_Group_Master__Share rec: [SELECT ParentId, UserOrGroupId FROM Item_Group_Master__Share WHERE ParentId IN: itemGroupIds]) {
                mapParentToItemGroup.put(rec.ParentId, rec.UserOrGroupId);
            }
        }
        /*
        if (compIds.size() > 0) {
            for (Branch_Wise_Sales_Target__Share rec : [SELECT ParentId, UserOrGroupId FROM Branch_Wise_Sales_Target__Share WHERE ParentId IN: compIds]) {
                mapParentToBranch.put(rec.ParentId, rec.UserOrGroupId);
            }
        }
        */

        List < sObject > shareRecords = new List < sObject > ();
        for (sObject rec: newRecords) {
            String recObjectName = String.valueOf(rec.getSObjectType()).replace('__c', '__Share');
            Type shareType = Type.forName(recObjectName);
            if (shareType != null) {
                SObject shareRecord = (SObject) shareType.newInstance();
                shareRecord.put('ParentId', rec.Id);
                shareRecord.put('AccessLevel', 'Read');

                switch on String.valueOf(rec.getSObjectType()) {
                    when 'Employee_Wise_Target__c', 'Employee_Wise_Account_Target__c' {
                        shareRecord.put('UserOrGroupId', rec.get('Employee__c'));
                    }

                }
                shareRecords.add(shareRecord);
                System.debug(shareRecord);
                System.debug(rec);
            }
        }
        System.debug('shareRecords' + shareRecords);
        if (shareRecords.size() > 0) {
            Database.insert(shareRecords, false);
        }
    }

    // Line Item - To get the name of month depending on start and end date
    public static void evaluateValues(List < sObject > newRecords) {
        for (sObject obj: newRecords) {
            Date startDt = (Date) obj.get('Start_Date__c');
            String monthName = DateTime.newInstance(startDt.year(), startDt.month(), startDt.day()).format('MMMM');
            obj.put('Month_Name__c', monthName);
        }
    }

    // Line Item - UpdateAmountValues
    // Line Item - UpdateAmountValues
    public static void UpdateAmountValues(List < sObject > newRecords) {
        Set < String > paramTypes = new Set < String > ();
        for (sObject obj: newRecords) {
            paramTypes.add(String.valueOf(obj.getSObjectType()));
        }

        for (String param: paramTypes) {
            Map < Id, Decimal > mapSumAmount = new Map < Id, Decimal > ();
            switch on param {
                when 'Employee_Wise_Target_Line_Item__c' {
                    for (AggregateResult result: [SELECT Employee_Wise_Target_Line_Item__c, SUM(TotalAmount) sumAmt
                            FROM Order
                            WHERE Employee_Wise_Target_Line_Item__c IN: newRecords
                            GROUP BY Employee_Wise_Target_Line_Item__c
                        ]) {
                        mapSumAmount.put((Id) result.get('Employee_Wise_Target_Line_Item__c'), (Decimal) result.get('sumAmt'));
                    }
                }
               /* when 'EmployeeWiseProductCategoryTarget_Line__c' {
                    System.debug('UpdateAmountValues:>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
                }   */
            }

          /*  for (sObject emp: newRecords) {
                if (mapSumAmount.containsKey(emp.Id)) {
                    emp.put('Actual_Amount__c', mapSumAmount.get(emp.Id));
                } else {
                    emp.put('Actual_Amount__c', 0);
                } 
            }  */
        }
    }

}