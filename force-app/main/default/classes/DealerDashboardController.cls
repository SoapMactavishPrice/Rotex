public without sharing class DealerDashboardController {
    
    public class DashboardMetrics {
        @AuraEnabled public Decimal invoiceQty;
        @AuraEnabled public Integer approvedCustomers;
        @AuraEnabled public Integer openLeads;
        @AuraEnabled public Integer pendingQuotes;
        @AuraEnabled public Integer lowStockProducts;
        @AuraEnabled public Decimal targetAchievement;
        @AuraEnabled public Decimal totalTargetValue;
        @AuraEnabled public Decimal totalActualValue;
        @AuraEnabled public Integer totalQuotes;
        @AuraEnabled public List<String> quoteStatusLabels;
        @AuraEnabled public List<Integer> quoteStatusCounts;
        @AuraEnabled public Integer totalLeads;
        @AuraEnabled public List<String> leadStatusLabels;
        @AuraEnabled public List<Integer> leadStatusCounts;
        @AuraEnabled public Integer totalInventory;
        @AuraEnabled public List<String> inventoryStatusLabels;
        @AuraEnabled public List<Integer> inventoryStatusCounts;
        @AuraEnabled public List<Decimal> inventoryStatusQuantities;
        @AuraEnabled public List<String> chartLabels;
        @AuraEnabled public List<Decimal> chartTargets;
        @AuraEnabled public List<Decimal> chartActuals;
        @AuraEnabled public List<String> topOrderLabels;
        @AuraEnabled public List<Decimal> topOrderValues;
        
        public DashboardMetrics() {
            this.invoiceQty = 0;
            this.approvedCustomers = 0;
            this.openLeads = 0;
            this.pendingQuotes = 0;
            this.lowStockProducts = 0;
            this.targetAchievement = 0;
            this.totalTargetValue = 0;
            this.totalActualValue = 0;
            this.totalQuotes = 0;
            this.quoteStatusLabels = new List<String>();
            this.quoteStatusCounts = new List<Integer>();
            this.totalLeads = 0;
            this.leadStatusLabels = new List<String>();
            this.leadStatusCounts = new List<Integer>();
            this.totalInventory = 0;
            this.inventoryStatusLabels = new List<String>();
            this.inventoryStatusCounts = new List<Integer>();
            this.inventoryStatusQuantities = new List<Decimal>();
            this.chartLabels = new List<String>{'Q1', 'Q2', 'Q3', 'Q4'};
            this.chartTargets = new List<Decimal>{0, 0, 0, 0};
            this.chartActuals = new List<Decimal>{0, 0, 0, 0};
            this.topOrderLabels = new List<String>();
            this.topOrderValues = new List<Decimal>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static DashboardMetrics getDashboardMetrics(String yearStr, String quarter, String month) {
        DashboardMetrics metrics = new DashboardMetrics();
        Id partnerId = resolvePartnerAccountId();
        Id userId = UserInfo.getUserId();
        
        Date startDate = Date.newInstance(1900, 1, 1);
        Date endDate = Date.newInstance(3000, 12, 31);
        String dateFilter = ' AND CreatedDate >= :startDate AND CreatedDate <= :endDate ';
        
        if (String.isNotBlank(yearStr)) {
            Integer selectedYear = Integer.valueOf(yearStr);
            startDate = Date.newInstance(selectedYear, 4, 1);
            endDate = Date.newInstance(selectedYear + 1, 3, 31);
            
            if (String.isNotBlank(month)) {
                Integer m = Integer.valueOf(month);
                Integer calcYear = (m >= 4) ? startDate.year() : endDate.year();
                startDate = Date.newInstance(calcYear, m, 1);
                endDate = startDate.addMonths(1).addDays(-1);
            } else if (String.isNotBlank(quarter)) {
                if (quarter == 'Q1') {
                    startDate = Date.newInstance(startDate.year(), 4, 1);
                    endDate = Date.newInstance(startDate.year(), 6, 30);
                } else if (quarter == 'Q2') {
                    startDate = Date.newInstance(startDate.year(), 7, 1);
                    endDate = Date.newInstance(startDate.year(), 9, 30);
                } else if (quarter == 'Q3') {
                    startDate = Date.newInstance(startDate.year(), 10, 1);
                    endDate = Date.newInstance(startDate.year(), 12, 31);
                } else if (quarter == 'Q4') {
                    startDate = Date.newInstance(endDate.year(), 1, 1);
                    endDate = Date.newInstance(endDate.year(), 3, 31);
                }
            }
        } else {
            if (String.isNotBlank(month)) {
                dateFilter += ' AND CALENDAR_MONTH(CreatedDate) = ' + month + ' ';
            } else if (String.isNotBlank(quarter)) {
                if (quarter == 'Q1') dateFilter += ' AND (CALENDAR_MONTH(CreatedDate) = 4 OR CALENDAR_MONTH(CreatedDate) = 5 OR CALENDAR_MONTH(CreatedDate) = 6) ';
                else if (quarter == 'Q2') dateFilter += ' AND (CALENDAR_MONTH(CreatedDate) = 7 OR CALENDAR_MONTH(CreatedDate) = 8 OR CALENDAR_MONTH(CreatedDate) = 9) ';
                else if (quarter == 'Q3') dateFilter += ' AND (CALENDAR_MONTH(CreatedDate) = 10 OR CALENDAR_MONTH(CreatedDate) = 11 OR CALENDAR_MONTH(CreatedDate) = 12) ';
                else if (quarter == 'Q4') dateFilter += ' AND (CALENDAR_MONTH(CreatedDate) = 1 OR CALENDAR_MONTH(CreatedDate) = 2 OR CALENDAR_MONTH(CreatedDate) = 3) ';
            }
        }
        
        try {
            if (partnerId != null) {
                AggregateResult[] invResult = Database.query('SELECT SUM(Total_Qty__c) totalQty FROM SO_Invoice__c WHERE Account__c = :partnerId ' + dateFilter);
                if (!invResult.isEmpty() && invResult[0].get('totalQty') != null) metrics.invoiceQty = (Decimal)invResult[0].get('totalQty');
            } else {
                AggregateResult[] invResult = Database.query('SELECT SUM(Total_Qty__c) totalQty FROM SO_Invoice__c WHERE CreatedDate != null ' + dateFilter);
                if (!invResult.isEmpty() && invResult[0].get('totalQty') != null) metrics.invoiceQty = (Decimal)invResult[0].get('totalQty');
            }
        } catch (Exception e) { metrics.invoiceQty = 0; }
        
        try {
            if (partnerId != null) {
                metrics.approvedCustomers = Database.countQuery('SELECT COUNT() FROM Account WHERE Approval_Status__c = \'Approved\' AND (Channel_Partner__c = :partnerId OR Channel_Partner_Name__c = :partnerId) ' + dateFilter);
            } else {
                metrics.approvedCustomers = Database.countQuery('SELECT COUNT() FROM Account WHERE Approval_Status__c = \'Approved\' ' + dateFilter);
            }
        } catch (Exception e) { metrics.approvedCustomers = 0; }
        
        try {
            if (partnerId != null) {
                metrics.openLeads = Database.countQuery('SELECT COUNT() FROM Lead WHERE Status NOT IN (\'Future Prospect\', \'Qualified\', \'Regret\', \'Forward to Dealer\') AND IsConverted = false AND Dealer__c = :partnerId AND RecordType.Name = \'Channel Partner\' ' + dateFilter);
            } else {
                metrics.openLeads = Database.countQuery('SELECT COUNT() FROM Lead WHERE Status NOT IN (\'Future Prospect\', \'Qualified\', \'Regret\', \'Forward to Dealer\') AND IsConverted = false AND RecordType.Name = \'Channel Partner\' ' + dateFilter);
            }
        } catch (Exception e) { metrics.openLeads = 0; }
        
        try {
            if (partnerId != null) {
                metrics.pendingQuotes = Database.countQuery('SELECT COUNT() FROM Quote WHERE Status = \'Submit for SOA Approval\' AND (OwnerId = :userId OR AccountId = :partnerId) ' + dateFilter);
            } else {
                metrics.pendingQuotes = Database.countQuery('SELECT COUNT() FROM Quote WHERE Status = \'Submit for SOA Approval\' ' + dateFilter);
            }
        } catch (Exception e) { metrics.pendingQuotes = 0; }
        
        try {
            List<AggregateResult> results;
            if (partnerId != null) {
                results = Database.query('SELECT Status, COUNT(Id) cnt FROM Quote WHERE (OwnerId = :userId OR AccountId = :partnerId) ' + dateFilter + ' GROUP BY Status');
            } else {
                results = Database.query('SELECT Status, COUNT(Id) cnt FROM Quote WHERE CreatedDate != null ' + dateFilter + ' GROUP BY Status');
            }
            for(AggregateResult ar : results) {
                String status = (String)ar.get('Status');
                Integer cnt = (Integer)ar.get('cnt');
                if (status == null) status = 'Unknown';
                metrics.quoteStatusLabels.add(status);
                metrics.quoteStatusCounts.add(cnt);
                metrics.totalQuotes += cnt;
            }
        } catch (Exception e) {}
        
        try {
            List<AggregateResult> results;
            if (partnerId != null) {
                results = Database.query('SELECT Status, COUNT(Id) cnt FROM Lead WHERE (OwnerId = :userId OR Dealer__c = :partnerId) AND RecordType.Name = \'Channel Partner\' ' + dateFilter + ' GROUP BY Status');
            } else {
                results = Database.query('SELECT Status, COUNT(Id) cnt FROM Lead WHERE RecordType.Name = \'Channel Partner\' ' + dateFilter + ' GROUP BY Status');
            }
            for(AggregateResult ar : results) {
                String status = (String)ar.get('Status');
                Integer cnt = (Integer)ar.get('cnt');
                if (status == null) status = 'Unknown';
                metrics.leadStatusLabels.add(status);
                metrics.leadStatusCounts.add(cnt);
                metrics.totalLeads += cnt;
            }
        } catch (Exception e) {}
        
        try {
            Map<String, Integer> inventoryMap = new Map<String, Integer>();
            Map<String, Decimal> inventoryQtyMap = new Map<String, Decimal>();
            Schema.DescribeFieldResult fieldResult = Inventory__c.Status__c.getDescribe();
            for(Schema.PicklistEntry f : fieldResult.getPicklistValues()) {
                inventoryMap.put(f.getLabel(), 0);
                inventoryQtyMap.put(f.getLabel(), 0);
            }
            List<AggregateResult> results;
            if (partnerId != null) {
                results = Database.query('SELECT Status__c, COUNT(Id) cnt, SUM(Available_Quantity__c) qty FROM Inventory__c WHERE Channel_Partner__c = :partnerId ' + dateFilter + ' GROUP BY Status__c');
            } else {
                results = Database.query('SELECT Status__c, COUNT(Id) cnt, SUM(Available_Quantity__c) qty FROM Inventory__c WHERE CreatedDate != null ' + dateFilter + ' GROUP BY Status__c');
            }
            for(AggregateResult ar : results) {
                String status = (String)ar.get('Status__c');
                Integer cnt = (Integer)ar.get('cnt');
                Decimal qty = (Decimal)ar.get('qty');
                if (qty == null) qty = 0;
                if (status == null) {
                    status = 'Unknown';
                    if (!inventoryMap.containsKey(status)) {
                        inventoryMap.put(status, 0);
                        inventoryQtyMap.put(status, 0);
                    }
                }
                inventoryMap.put(status, cnt);
                inventoryQtyMap.put(status, qty);
            }
            for (String key : inventoryMap.keySet()) {
                metrics.inventoryStatusLabels.add(key);
                metrics.inventoryStatusCounts.add(inventoryMap.get(key));
                metrics.inventoryStatusQuantities.add(inventoryQtyMap.get(key));
                metrics.totalInventory += inventoryMap.get(key);
            }
        } catch (Exception e) {}
        
        try {
            if (partnerId != null) {
                metrics.lowStockProducts = Database.countQuery('SELECT COUNT() FROM Inventory__c WHERE Channel_Partner__c = :partnerId AND Status__c = \'Low Stock\' ' + dateFilter);
            } else {
                metrics.lowStockProducts = Database.countQuery('SELECT COUNT() FROM Inventory__c WHERE Status__c = \'Low Stock\' ' + dateFilter);
            }
        } catch (Exception e) { metrics.lowStockProducts = 0; }
        
        try {
            Decimal totalTarget = 0;
            Decimal totalAchieved = 0;
            if (partnerId != null) {
                List<Target__c> targets = Database.query('SELECT Total_Target__c, Total_Target_Achieved__c, Qtr_1_Target__c, Qtr_2_Target__c, Qtr_3_Target__c, Qtr_4_Target__c, Qtr_1_Actual__c, Qtr_2_Actual__c, Qtr_3_Actual__c, Qtr_4_Actual__c FROM Target__c WHERE Customer_Name__c = :partnerId ' + dateFilter + ' ORDER BY CreatedDate DESC LIMIT 1');
                if (!targets.isEmpty()) {
                    totalTarget = targets[0].Total_Target__c;
                    totalAchieved = targets[0].Total_Target_Achieved__c;
                    metrics.chartTargets[0] = targets[0].Qtr_1_Target__c != null ? targets[0].Qtr_1_Target__c : 0;
                    metrics.chartTargets[1] = targets[0].Qtr_2_Target__c != null ? targets[0].Qtr_2_Target__c : 0;
                    metrics.chartTargets[2] = targets[0].Qtr_3_Target__c != null ? targets[0].Qtr_3_Target__c : 0;
                    metrics.chartTargets[3] = targets[0].Qtr_4_Target__c != null ? targets[0].Qtr_4_Target__c : 0;
                    metrics.chartActuals[0] = targets[0].Qtr_1_Actual__c != null ? targets[0].Qtr_1_Actual__c : 0;
                    metrics.chartActuals[1] = targets[0].Qtr_2_Actual__c != null ? targets[0].Qtr_2_Actual__c : 0;
                    metrics.chartActuals[2] = targets[0].Qtr_3_Actual__c != null ? targets[0].Qtr_3_Actual__c : 0;
                    metrics.chartActuals[3] = targets[0].Qtr_4_Actual__c != null ? targets[0].Qtr_4_Actual__c : 0;
                }
            }
            if (totalTarget != null && totalTarget > 0 && totalAchieved != null) {
                metrics.targetAchievement = ((totalAchieved / totalTarget) * 100).setScale(2);
            } else {
                metrics.targetAchievement = 0;
            }
            metrics.totalTargetValue = totalTarget != null ? totalTarget : 0;
            metrics.totalActualValue = totalAchieved != null ? totalAchieved : 0;
        } catch (Exception e) { metrics.targetAchievement = 0; }
        
        try {
            List<Order> allOrders;
            if (partnerId != null) {
                allOrders = Database.query('SELECT OrderNumber, SO_No__c, Net_Value__c, Bill_To_Customer_Name__r.Name FROM Order WHERE AccountId = :partnerId ' + dateFilter + ' LIMIT 500');
            } else {
                allOrders = Database.query('SELECT OrderNumber, SO_No__c, Net_Value__c, Bill_To_Customer_Name__r.Name FROM Order WHERE CreatedDate != null ' + dateFilter + ' LIMIT 500');
            }
            List<OrderWrapper> wrappedOrders = new List<OrderWrapper>();
            for (Order ord : allOrders) {
                wrappedOrders.add(new OrderWrapper(ord));
            }
            wrappedOrders.sort();
            Integer count = 0;
            for (OrderWrapper w : wrappedOrders) {
                if (count >= 10) break;
                String label = (w.ord.Bill_To_Customer_Name__r != null && String.isNotBlank(w.ord.Bill_To_Customer_Name__r.Name)) 
                               ? w.ord.Bill_To_Customer_Name__r.Name 
                               : (w.ord.SO_No__c != null ? w.ord.SO_No__c : w.ord.OrderNumber);
                metrics.topOrderLabels.add(label);
                metrics.topOrderValues.add(w.netValue);
                count++;
            }
        } catch (Exception e) {}
        
        return metrics;
    }
    
    public class OrderWrapper implements Comparable {
        public Order ord;
        public Decimal netValue;
        
        public OrderWrapper(Order o) {
            this.ord = o;
            this.netValue = 0;
            if (o.Net_Value__c != null) {
                try {
                    this.netValue = Decimal.valueOf(o.Net_Value__c.replaceAll('[^0-9.]', ''));
                } catch(Exception e) {}
            }
        }
        
        public Integer compareTo(Object compareTo) {
            OrderWrapper other = (OrderWrapper)compareTo;
            if (this.netValue == other.netValue) return 0;
            if (this.netValue < other.netValue) return 1;
            return -1;
        }
    }
    
    private static Id resolvePartnerAccountId() {
        List<User> users = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (!users.isEmpty() && users[0].AccountId != null) {
            return users[0].AccountId;
        }
        return null;
    }
}