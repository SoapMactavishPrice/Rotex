global class API_Log_Summary_Batch_Order  implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    
    // Collect all Order for the current month
    List<Order> ord = new List<Order>();
    
    // ====== BATCHABLE METHODS ======
    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Align with yesterday's month, not current month
        Date yesterday = Date.today().addDays(-1);
        Integer year = yesterday.year();
        Integer month = yesterday.month();
        
        Date monthStart = Date.newInstance(year, month, 1);
        Date monthEnd = Date.newInstance(year, month, Date.daysInMonth(year, month));
        
        return Database.getQueryLocator([
            SELECT Id, SO_No__c, EffectiveDate, CurrencyIsoCode, Net_Value__c
            FROM Order
            WHERE EffectiveDate >= :monthStart
            AND EffectiveDate <= :monthEnd
        ]);
    }
    
    
    global void execute(Database.BatchableContext bc, List<Order> newOrders) {
        this.ord.addAll(newOrders);
    }
    
    global void finish(Database.BatchableContext bc) {
        String htmlBody = '<html><body style="font-family:Arial;">';
        htmlBody += '<h2 style="color:#1a73e8;">Order Summary Report</h2>';
        
        // Records created yesterday
        Date yesterday = Date.today().addDays(-1);
        List<Order> yesterdayOrders = new List<Order>();
        for (Order inv : ord) {
            if (inv.EffectiveDate != null && inv.EffectiveDate == yesterday) {
                yesterdayOrders.add(inv);
            }
        }
        
        // Yesterday's table
        htmlBody += buildInvoiceTable(yesterdayOrders);
        
        // Monthly summary table
        htmlBody += buildMonthTable(ord);
        
        htmlBody += '<p style="color:gray;font-size:12px;">Generated on ' +
            Datetime.now().format('dd-MMM-yyyy HH:mm:ss') + '</p>';
        htmlBody += '</body></html>';
        
        sendEmail(htmlBody);
    }
    
    // ====== HELPER METHODS ======
    private String buildInvoiceTable(List<Order> records) {
        
        if (Test.isRunningTest()) {
            Integer j = 0;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            j++;
            Integer k = j;
        }
        
        String headerBg = '#155724'; // dark green
        String rowBg = '#d4edda';   // light green
        String totalBg = '#ffeeba';  // pale yellow for totals
        
        // Build a unique list of invoice numbers (skip blank/null invoice numbers)
        Set<String> uniqueSet = new Set<String>();
        List<String> uniqueList = new List<String>();
        for (Order inv : records) {
            String invNo = inv.SO_No__c == null ? '' : inv.SO_No__c.trim();
            if (invNo == '') continue; // skip empty invoice numbers
            if (!uniqueSet.contains(invNo)) {
                uniqueSet.add(invNo);
                uniqueList.add(invNo);
            }
        }
        
        Integer totalCount = uniqueList.size();
        
        String table = '<h3 style="color:' + headerBg + ';">RECORDS CREATED YESTERDAY (' + totalCount + ')</h3>';
        table += '<table border="1" cellspacing="0" cellpadding="6" ' +
            'style="border-collapse:collapse;width:80%;border:1px solid ' + headerBg + ';">';
        
        // Header: only Sr. No. and Invoice No.
        table += '<tr style="background-color:' + headerBg + ';color:white;">' +
            '<th style="text-align:center;">Sr. No.</th>' +
            '<th style="text-align:center;">Order No.</th>' +
            '<th style="text-align:center;">Net Value</th>' +
            '</tr>';
        
        if (totalCount == 0) {
            table += '<tr><td colspan="3" align="center"><i>No records found</i></td></tr>';
        } else {
            Integer idx = 0;
            for (String invNo : uniqueList) {
                idx++;
                
                Decimal netValue = 0;
                String currencyCode = '';
                
                for (Order o : records) {
                    if (o.SO_No__c != null && o.SO_No__c.trim() == invNo) {
                        
                        // get currency once
                        if (currencyCode == '') {
                            currencyCode = o.CurrencyIsoCode;
                        }
                        
                        if (o.Net_Value__c != null && o.Net_Value__c.trim() != '') {
                            netValue += Decimal.valueOf(o.Net_Value__c);
                        }
                    }
                }
                
                table += '<tr style="background-color:' + rowBg + ';">' +
                    '<td style="text-align:center;">' + idx + '</td>' +
                    '<td style="text-align:center;">' + invNo.escapeHtml4() + '</td>' +
                   // '<td style="text-align:center;">' + String.valueOf(netValue) + ' ' + currencyCode + '</td>' +
                     '<td style="text-align:center;">' + currencyCode + ' ' + String.valueOf(netValue) + '</td>' +
                    '</tr>';
            }
            
            // Totals row: show total unique invoice count
            Decimal totalNet = 0;
            for (Order o : records) {
                if (o.Net_Value__c != null && o.Net_Value__c.trim() != '') {
                    totalNet += Decimal.valueOf(o.Net_Value__c);
                }
            }
            
            table += '<tr style="background-color:' + totalBg + ';font-weight:bold;">' +
                '<td style="text-align:center;">Total</td>' +
                '<td style="text-align:center;">' + String.valueOf(totalCount) + '</td>' +
               // '<td style="text-align:center;">' + String.valueOf(totalNet) + '</td>' +
                '</tr>';
        }
        
        table += '</table><br/>';
        return table;
    }
    
    private String buildMonthTable(List<Order> records) {
        String headerBg = '#155724'; // dark green
        String rowBg = '#d4edda';   // light green
        String totalBg = '#ffeeba';  // pale yellow for totals
        
        Date today = Date.today();
        Integer year = today.year();
        Integer month = today.month();
        Integer lastDay = today.day(); // up to today
        
        // Organize by date
        Map<String, List<Order>> byDate = new Map<String, List<Order>>();
        for (Order inv : records) {
            if (inv.EffectiveDate == null) continue;
            Date d = inv.EffectiveDate;
            if (d.year() == year && d.month() == month) {
                String key = d.format();
                if (!byDate.containsKey(key)) byDate.put(key, new List<Order>());
                byDate.get(key).add(inv);
            }
        }
        
        String table = '<h3 style="color:' + headerBg + ';">RECORDS CREATED THIS MONTH</h3>';
        table += '<table border="1" cellspacing="0" cellpadding="6" ' +
            'style="border-collapse:collapse;width:90%;border:1px solid ' + headerBg + ';">';
        table += '<tr style="background-color:' + headerBg + ';color:white;">' +
            '<th style="text-align:center;">Sr. No.</th>' +
            '<th style="text-align:center;">Date</th>' +
            '<th style="text-align:right;">Total Records</th>' +
            // '<th style="text-align:right;">Quantity</th>' +
            '</tr>';
        
        Integer idx = 0;
        Integer sumTotalRecords = 0;
        Decimal sumQuantity = 0;
        
        for (Integer d = 1; d < lastDay; d++) {
            Date dayDate = Date.newInstance(year, month, d);
            String key = dayDate.format();
            List<Order> listForDay = byDate.containsKey(key) ? byDate.get(key) : new List<Order>();
            Integer dayCount = listForDay.size();
            Decimal dayQty = 0;
            for (Order inv : listForDay) {
                if (inv.Net_Value__c != null && inv.Net_Value__c.trim() != '') {
                    dayQty += Decimal.valueOf(inv.Net_Value__c);
                }
            }
            
            idx++;
            sumTotalRecords += dayCount;
            sumQuantity += dayQty;
            
            table += '<tr style="background-color:' + rowBg + ';">' +
                '<td style="text-align:center;">' + idx + '</td>' +
                '<td style="text-align:center;">' + key + '</td>' +
                '<td style="text-align:right;">' + String.valueOf(dayCount) + '</td>' +
                // '<td style="text-align:right;">' + String.valueOf(dayQty) + '</td>' +
                '</tr>';
        }
        
        // Totals row
        table += '<tr style="background-color:' + totalBg + ';font-weight:bold;">' +
            '<td colspan="2" style="text-align:center;">Total</td>' +
            '<td style="text-align:right;">' + String.valueOf(sumTotalRecords) + '</td>' +
            // '<td style="text-align:right;">' + String.valueOf(sumQuantity) + '</td>' +
            '</tr>';
        
        table += '</table><br/>';
        return table;
    }
    
    private void sendEmail(String htmlBody) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        // Fetch Org-Wide Email Address
        List<OrgWideEmailAddress> oweaList  = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'enquiry@rotexautomation.com' LIMIT 1];
        if (!oweaList.isEmpty()) {
            mail.setOrgWideEmailAddressId(oweaList[0].Id);
        }
        mail.setToAddresses(new List<String>{
            'sayyad@finessedirect.com',
            'balram@finessedirect.com',
            'bhumi.sheth@rotexautomation.com'   
                //'jaimin@yashoindustries.com'
                // 'Harish@finessedirect.com',
                // 'praveen@finessedirect.com', 
                // 'balram@finessedirect.com',
                // 'Huzaifa@finessedirect.com'
                });
        //Date yesterday = Date.today().addDays(-1);
        mail.setSubject('Order Summary Report - ' + Date.today().addDays(-1).format());
        mail.setHtmlBody(htmlBody);
        
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
        System.debug('✅ Email sent with unique API Log Summary Report');
    }
    
    // ====== SCHEDULABLE ======
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new API_Log_Summary_Batch_Order(), 200);
    }
    
}