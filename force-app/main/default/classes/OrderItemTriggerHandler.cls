public class OrderItemTriggerHandler {
    public static void updateQuantityOnTarget(List<OrderItem> orderItemList) {
        if (orderItemList == null || orderItemList.isEmpty()) { 
            return;
        }

        Set<Id> orderItemIds = new Set<Id>();
        Set<Id> orderOwnerIds = new Set<Id>();
        Set<String> accountList = new Set<String>();
        Set<Id> productIds = new Set<Id>();
        List<Employee_Wise_Target_Line_Item__c> empList = new List<Employee_Wise_Target_Line_Item__c>();
        //   List<Employee_Wise_Account_Target_Line_Item__c> accList = new List<Employee_Wise_Account_Target_Line_Item__c>();
        List<Employee_Wise_Account_Target_Line_Item__c> prodTargetList = new List<Employee_Wise_Account_Target_Line_Item__c>();

        for (OrderItem ord : orderItemList) {
            if (ord != null) {
                orderItemIds.add(ord.Id);
                //  accountList.add(ord.Account__c);  // This is commented, you can keep if needed
            }
        }

        if (orderItemIds.isEmpty()) { 
            return;
        }

        List<OrderItem> orderItems = [
            SELECT Id, OrderId, Order.OwnerId, Order.AccountId, Product2Id, CreatedDate, UnitPrice, TotalPrice, Account__c
            FROM OrderItem
            WHERE Id IN :orderItemIds
        ];

        if (orderItems.isEmpty()) { 
            return;
        }

        Date orderDate;
        for (OrderItem ordItem : orderItems) {
            if (ordItem.Order != null) {
                orderOwnerIds.add(ordItem.Order.OwnerId);
                orderDate = ordItem.CreatedDate.date();
                productIds.add(ordItem.Order.AccountId);
            }
        }

        if (orderOwnerIds.isEmpty()) { 
            return;
        }

        List<Employee_Wise_Target_Line_Item__c> targetEmpList = [
            SELECT Id, Name, Employee_Wise_Target__r.Employee__c, Start_Date__c, Actual_Amount__c, End_Date__c
            FROM Employee_Wise_Target_Line_Item__c
            WHERE Employee_Wise_Target__r.Employee__c IN :orderOwnerIds
            AND Start_Date__c <= :orderDate
            AND End_Date__c >= :orderDate
        ];

        // Set to track processed Employee_Wise_Target_Line_Item__c IDs to avoid duplicates
        Set<Id> processedEmpIds = new Set<Id>();

        for (Employee_Wise_Target_Line_Item__c emp : targetEmpList) {
            if (emp.Employee_Wise_Target__r != null) {
                for (OrderItem ordItem : orderItems) {
                    if (ordItem.Order.OwnerId == emp.Employee_Wise_Target__r.Employee__c) {
                        if (emp.Actual_Amount__c == null) {
                            emp.Actual_Amount__c = ordItem.TotalPrice;
                        } else {
                            emp.Actual_Amount__c += ordItem.TotalPrice;
                        }

                        // Prevent duplicates by checking if emp.Id is already processed
                        if (!processedEmpIds.contains(emp.Id)) {
                            empList.add(emp);
                            processedEmpIds.add(emp.Id);  // Track the emp.Id to avoid adding it again
                        }
                    }
                }
            }
        }

        /*       List<Employee_Wise_Product_Target_Line_Item__c> accountTargetList = [
            SELECT Id, Name, Employee_Wise_Product_Target__r.Product__c, Actual_Amount__c, Start_Date__c, End_Date__c
            FROM Employee_Wise_Product_Target_Line_Item__c
            WHERE Employee_Wise_Product_Target__r.Product__c IN :accountList
            AND Start_Date__c <= :orderDate
            AND End_Date__c >= :orderDate
        ];

        for (Employee_Wise_Product_Target_Line_Item__c acc : accountTargetList) {
            if (acc.Employee_Wise_Product_Target__r != null) {
                for (OrderItem ordItem : orderItems) {
                    if (ordItem.Product2Id == acc.Employee_Wise_Product_Target__r.Product__c) {
                        if (acc.Actual_Quantity__c == null) {
                            acc.Actual_Quantity__c = ordItem.Amount__c;
                        } else {
                            acc.Actual_Quantity__c += ordItem.Amount__c;
                        }
                        if (acc.Actual_Amount__c == null) {
                            acc.Actual_Amount__c = ordItem.Line_Amount__c;
                        } else {
                            acc.Actual_Amount__c += ordItem.Line_Amount__c;
                        }
                        accList.add(acc);
                    }
                }
            }
        }	*/

        List<Employee_Wise_Account_Target_Line_Item__c> productTargetList = [
            SELECT Id, Name, Employee_Wise_Account_Target__r.Account__c, Start_Date__c, End_Date__c, Actual_Amount__c
            FROM Employee_Wise_Account_Target_Line_Item__c
            WHERE Employee_Wise_Account_Target__r.Account__c IN :productIds
            AND Start_Date__c <= :orderDate
            AND End_Date__c >= :orderDate
        ];

        // Set to track processed Employee_Wise_Account_Target_Line_Item__c IDs to avoid duplicates
        Set<Id> processedProdIds = new Set<Id>();

        for (Employee_Wise_Account_Target_Line_Item__c prod : productTargetList) {
            if (prod.Employee_Wise_Account_Target__r != null) {
                for (OrderItem ordItem : orderItems) {
                    if (ordItem.Order.AccountId == prod.Employee_Wise_Account_Target__r.Account__c) {
                        if (prod.Actual_Amount__c == null) {
                            prod.Actual_Amount__c = ordItem.TotalPrice;
                        } else {
                            prod.Actual_Amount__c += ordItem.TotalPrice;
                        }

                        // Prevent duplicates by checking if prod.Id is already processed
                        if (!processedProdIds.contains(prod.Id)) {
                            prodTargetList.add(prod);
                            processedProdIds.add(prod.Id);  // Track the prod.Id to avoid adding it again
                        }
                    }
                }
            }
        }

        /*    if (!accList.isEmpty()) {
            update accList;
        }	*/

        if (!empList.isEmpty()) { 
            update empList;
        }

        if (!prodTargetList.isEmpty()) { update prodTargetList;
        }
    }
}