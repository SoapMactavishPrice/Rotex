public class QuoteLineItemApprovalHandler {
    
    public static void processApprovals(List<QuoteLineItem> newList) {
        if (newList.isEmpty()) return;
        
        Set<Id> quoteIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        
        // Collect Quote IDs and Product IDs
        for (QuoteLineItem qli : newList) {
            if (qli.QuoteId != null) quoteIds.add(qli.QuoteId);
            if (qli.Product2Id != null) productIds.add(qli.Product2Id);
        }
        
        if (quoteIds.isEmpty()) return;
        
        // Query related Quotes including Account
        Map<Id, Quote> quoteMap = new Map<Id, Quote>([
            SELECT Id, Name, OwnerId, Account.Name,
            Sales_Manager__c,
            Country_Continent_Sales_Head_LOB_Head__c
            FROM Quote WHERE Id IN :quoteIds
        ]);
        
        // Query Quote Owners
        Set<Id> ownerIds = new Set<Id>();
        for (Quote q : quoteMap.values()) ownerIds.add(q.OwnerId);
        
        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Name, Email, SOA_Profile__c FROM User WHERE Id IN :ownerIds
        ]);
        
        // Query Products
        Map<Id, Product2> productMap = new Map<Id, Product2>();
        if (!productIds.isEmpty()) {
            productMap = new Map<Id, Product2>(
                [SELECT Id, Name FROM Product2 WHERE Id IN :productIds]
            );
        }
        
        // Collect all approver Ids for sending emails later
        Set<Id> approverIds = new Set<Id>();
        
        // Determine first approver and mark Submitted
        for (QuoteLineItem qli : newList) {
            if (qli.Discount_to_be_offered__c == null || qli.Discount_as_per_SAP__c == null) continue;
            if (qli.Discount_to_be_offered__c <= qli.Discount_as_per_SAP__c) continue;
            
            Quote q = quoteMap.get(qli.QuoteId);
            if (q == null) continue;
            
            User owner = userMap.get(q.OwnerId);
            if (owner == null) continue;
            
            Id approverUserId;
            String statusField;
            
            // First approver logic
            if (owner.SOA_Profile__c == 'Sales Rep') {
                approverUserId = q.Sales_Manager__c;
                statusField = 'Sales_Manager_Status__c';
            } else if (owner.SOA_Profile__c == 'Sales Manager') {
                approverUserId = q.Country_Continent_Sales_Head_LOB_Head__c;
                statusField = 'Country_Continent_Sales_H_LOB_Status__c';
            } else {
                continue; // only handle these two owner types
            }
            
            if (approverUserId == null || statusField == null) continue;
            
            // ✅ Mark Submitted (before trigger, so no update needed)
            qli.put(statusField, 'Submitted');
            
            // Collect approver for email
            approverIds.add(approverUserId);
        }
        
        // Send emails (after setting Submitted status)
        if (!approverIds.isEmpty()) {
            Map<Id, User> approverMap = new Map<Id, User>([
                SELECT Id, Name, Email FROM User WHERE Id IN :approverIds
            ]);
            
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (QuoteLineItem qli : newList) {
                Quote q = quoteMap.get(qli.QuoteId);
                if (q == null) continue;
                
                User owner = userMap.get(q.OwnerId);
                if (owner == null) continue;
                
                Id approverId;
                if (owner.SOA_Profile__c == 'Sales Rep') approverId = q.Sales_Manager__c;
                else approverId = q.Country_Continent_Sales_Head_LOB_Head__c;
                
                User approverUser = approverMap.get(approverId);
                if (approverUser == null) continue;
                
                // Get Product Name safely
                String productName = (qli.Product2Id != null && productMap.containsKey(qli.Product2Id)) 
                    ? productMap.get(qli.Product2Id).Name 
                    : 'N/A';
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { approverUser.Email });
                mail.setSubject('Discount Approval Request for Quote: ' + q.Name);
                mail.setPlainTextBody(
                    'Dear ' + approverUser.Name + ',\n\n' +
                    'A new discount approval request has been submitted.\n\n' +
                    'Quote: ' + q.Name + '\n' +
                    'Account: ' + (q.Account != null ? q.Account.Name : 'N/A') + '\n' +
                    'Quote Owner: ' + owner.Name + '\n' +
                    'Product: ' + productName + '\n' +
                    'Standard Discount (as per SAP): ' + qli.Discount_as_per_SAP__c + '%\n' +
                    'Discount to be Offered: ' + qli.Discount_to_be_offered__c + '%\n\n' +
                    'Please review and take appropriate action.\n\n' +
                    'Regards,\nSalesforce Automated Approval System'
                );
                emails.add(mail);
            }
            
            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
            }
        }
    }
}