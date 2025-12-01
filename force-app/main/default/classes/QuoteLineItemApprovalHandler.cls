public class QuoteLineItemApprovalHandler {
    
    public static void processApprovals(List<QuoteLineItem> newList) {
        System.debug('=== INITIAL APPROVAL HANDLER START ===');
        System.debug('Input QLI List Size: ' + newList.size());
        
        if (newList.isEmpty()) {
            System.debug('APPROVAL: Empty list, exiting');
            return;
        }
        
        Set<Id> quoteIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        
        // Collect Quote IDs and Product IDs
        System.debug('APPROVAL: Collecting Quote IDs and Product IDs from QLIs');
        for (QuoteLineItem qli : newList) {
            if (qli.QuoteId != null) {
                quoteIds.add(qli.QuoteId);
                System.debug('  Added QuoteId: ' + qli.QuoteId + ' from QLI: ' + qli.Id);
            }
            if (qli.Product2Id != null) {
                productIds.add(qli.Product2Id);
                System.debug('  Added Product2Id: ' + qli.Product2Id + ' from QLI: ' + qli.Id);
            }
        }
        
        System.debug('APPROVAL: Total Quote IDs collected: ' + quoteIds.size());
        System.debug('APPROVAL: Quote IDs: ' + quoteIds);
        System.debug('APPROVAL: Total Product IDs collected: ' + productIds.size());
        System.debug('APPROVAL: Product IDs: ' + productIds);
        
        if (quoteIds.isEmpty()) {
            System.debug('APPROVAL: No Quote IDs found, exiting');
            return;
        }
        
        // Query related Quotes including Account
        System.debug('APPROVAL: Querying Quotes with Sales_Manager__c and Country_Continent_Sales_Head_LOB_Head__c');
        Map<Id, Quote> quoteMap = new Map<Id, Quote>([
            SELECT Id, Name, OwnerId, Account.Name,
            Sales_Manager__c,
            Country_Continent_Sales_Head_LOB_Head__c
            FROM Quote WHERE Id IN :quoteIds
        ]);
        
        System.debug('APPROVAL: Queried ' + quoteMap.size() + ' Quotes');
        for (Quote q : quoteMap.values()) {
            System.debug('  Quote: ' + q.Name + ' (Id: ' + q.Id + ')');
            System.debug('    OwnerId: ' + q.OwnerId);
            System.debug('    Account Name: ' + (q.Account != null ? q.Account.Name : 'NULL'));
            System.debug('    Sales_Manager__c: ' + q.Sales_Manager__c);
            System.debug('    Country_Continent_Sales_Head_LOB_Head__c: ' + q.Country_Continent_Sales_Head_LOB_Head__c);
        }
        
        // Query Quote Owners
        Set<Id> ownerIds = new Set<Id>();
        for (Quote q : quoteMap.values()) {
            ownerIds.add(q.OwnerId);
        }
        System.debug('APPROVAL: Collected ' + ownerIds.size() + ' unique Owner IDs: ' + ownerIds);
        
        System.debug('APPROVAL: Querying User details for Quote Owners');
        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Name, Email, SOA_Profile__c FROM User WHERE Id IN :ownerIds
        ]);
        
        System.debug('APPROVAL: Queried ' + userMap.size() + ' Users');
        for (User u : userMap.values()) {
            System.debug('  User: ' + u.Name + ' (Id: ' + u.Id + ')');
            System.debug('    Email: ' + u.Email);
            System.debug('    SOA_Profile__c: ' + u.SOA_Profile__c);
        }
        
        // Query Products
        Map<Id, Product2> productMap = new Map<Id, Product2>();
        if (!productIds.isEmpty()) {
            System.debug('APPROVAL: Querying Product2 records');
            productMap = new Map<Id, Product2>(
                [SELECT Id, Name FROM Product2 WHERE Id IN :productIds]
            );
            System.debug('APPROVAL: Queried ' + productMap.size() + ' Products');
            for (Product2 p : productMap.values()) {
                System.debug('  Product: ' + p.Name + ' (Id: ' + p.Id + ')');
            }
        } else {
            System.debug('APPROVAL: No Product IDs to query');
        }
        
        // Collect all approver Ids for sending emails later
        Set<Id> approverIds = new Set<Id>();
        
        System.debug('');
        System.debug('=== APPROVAL: Processing QLIs for First Approver Assignment ===');
        
        // Determine first approver and mark Submitted
        for (QuoteLineItem qli : newList) {
            System.debug('');
            System.debug('--- APPROVAL: Processing QLI ID: ' + qli.Id + ' ---');
            System.debug('QuoteId: ' + qli.QuoteId);
            System.debug('Product2Id: ' + qli.Product2Id);
            System.debug('Discount_to_be_offered__c: ' + qli.Discount_to_be_offered__c);
            System.debug('Discount_as_per_SAP__c: ' + qli.Discount_as_per_SAP__c);
            
            if (qli.Discount_to_be_offered__c == null || qli.Discount_as_per_SAP__c == null) {
                System.debug('APPROVAL: ✗ Skipping - One or both discount fields are NULL');
                continue;
            }
            
            if (qli.Discount_to_be_offered__c <= qli.Discount_as_per_SAP__c) {
                System.debug('APPROVAL: ✗ Skipping - Offered discount (' + qli.Discount_to_be_offered__c + 
                           ') is NOT greater than SAP discount (' + qli.Discount_as_per_SAP__c + ')');
                System.debug('APPROVAL: No approval needed (within standard discount)');
                continue;
            }
            
            System.debug('APPROVAL: ✓ Discount needs approval (Offered: ' + qli.Discount_to_be_offered__c + 
                       ' > SAP: ' + qli.Discount_as_per_SAP__c + ')');
            
            Quote q = quoteMap.get(qli.QuoteId);
            if (q == null) {
                System.debug('APPROVAL: ✗ ERROR - Quote not found in quoteMap for QuoteId: ' + qli.QuoteId);
                continue;
            }
            System.debug('APPROVAL: ✓ Quote found - Name: ' + q.Name + ', OwnerId: ' + q.OwnerId);
            
            User owner = userMap.get(q.OwnerId);
            if (owner == null) {
                System.debug('APPROVAL: ✗ ERROR - Owner User not found in userMap for OwnerId: ' + q.OwnerId);
                continue;
            }
            System.debug('APPROVAL: ✓ Owner found - Name: ' + owner.Name + ', Email: ' + owner.Email);
            System.debug('APPROVAL: Owner SOA_Profile__c: ' + owner.SOA_Profile__c);
            
            Id approverUserId;
            String statusField;
            
            // First approver logic
            System.debug('APPROVAL: Determining first approver based on Owner SOA Profile');
            if (owner.SOA_Profile__c == 'Sales Rep') {
                System.debug('APPROVAL: ✓ Owner is "Sales Rep" → First Approver = Sales Manager');
                approverUserId = q.Sales_Manager__c;
                statusField = 'Sales_Manager_Status__c';
                System.debug('  Sales_Manager__c (Approver User ID): ' + approverUserId);
                System.debug('  Status Field to Update: ' + statusField);
            } else if (owner.SOA_Profile__c == 'Sales Manager') {
                System.debug('APPROVAL: ✓ Owner is "Sales Manager" → First Approver = Country/Continent Sales Head');
                approverUserId = q.Country_Continent_Sales_Head_LOB_Head__c;
                statusField = 'Country_Continent_Sales_H_LOB_Status__c';
                System.debug('  Country_Continent_Sales_Head_LOB_Head__c (Approver User ID): ' + approverUserId);
                System.debug('  Status Field to Update: ' + statusField);
            } else {
                System.debug('APPROVAL: ✗ Owner SOA_Profile__c "' + owner.SOA_Profile__c + '" is not handled');
                System.debug('APPROVAL: Only "Sales Rep" and "Sales Manager" profiles are supported as Quote owners');
                continue;
            }
            
            if (approverUserId == null || statusField == null) {
                System.debug('APPROVAL: ✗ ERROR - Approver User ID or Status Field is NULL');
                System.debug('  approverUserId: ' + approverUserId);
                System.debug('  statusField: ' + statusField);
                continue;
            }
            
            // ✅ Mark Submitted (before trigger, so no update needed)
            System.debug('APPROVAL: ✓✓ Setting approval status field to "Submitted"');
            System.debug('  Field: ' + statusField + ' = "Submitted"');
            qli.put(statusField, 'Submitted');
            System.debug('APPROVAL: ✓ Status field updated successfully on QLI record');
            
            // Collect approver for email
            approverIds.add(approverUserId);
            System.debug('APPROVAL: ✓ Added approver to email list (User ID: ' + approverUserId + ')');
        }
        
        System.debug('');
        System.debug('=== APPROVAL: Email and Notification Phase ===');
        System.debug('Total unique approvers to notify: ' + approverIds.size());
        System.debug('Approver IDs: ' + approverIds);
        
        // Send emails and custom notifications (after setting Submitted status)
        if (!approverIds.isEmpty()) {
            System.debug('APPROVAL: Querying approver User details for email notification');
            Map<Id, User> approverMap = new Map<Id, User>([
                SELECT Id, Name, Email FROM User WHERE Id IN :approverIds
            ]);
            
            System.debug('APPROVAL: Queried ' + approverMap.size() + ' approver Users');
            for (User approver : approverMap.values()) {
                System.debug('  Approver: ' + approver.Name + ' (Email: ' + approver.Email + ')');
            }
            
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            List<Messaging.CustomNotification> notifications = new List<Messaging.CustomNotification>();
            
            // Get Custom Notification Type ID
            Id notificationTypeId = getCustomNotificationTypeId('Approval_Alert');
            
            if (notificationTypeId == null) {
                System.debug('APPROVAL: ✗ WARNING - Custom Notification Type "Approval_Alert" not found');
                System.debug('APPROVAL: Notifications will not be sent. Please create the Custom Notification Type.');
            } else {
                System.debug('APPROVAL: ✓ Custom Notification Type "Approval_Alert" found: ' + notificationTypeId);
            }
            
            System.debug('');
            System.debug('APPROVAL: Building email messages and notifications for each QLI');
            for (QuoteLineItem qli : newList) {
                System.debug('  → Building email and notification for QLI: ' + qli.Id);
                
                Quote q = quoteMap.get(qli.QuoteId);
                if (q == null) {
                    System.debug('    ✗ Quote not found, skipping email for this QLI');
                    continue;
                }
                
                User owner = userMap.get(q.OwnerId);
                if (owner == null) {
                    System.debug('    ✗ Owner not found, skipping email for this QLI');
                    continue;
                }
                
                Id approverId;
                if (owner.SOA_Profile__c == 'Sales Rep') {
                    approverId = q.Sales_Manager__c;
                    System.debug('    Owner is Sales Rep → Sending to Sales Manager: ' + approverId);
                } else {
                    approverId = q.Country_Continent_Sales_Head_LOB_Head__c;
                    System.debug('    Owner is Sales Manager → Sending to Country/Continent Head: ' + approverId);
                }
                
                User approverUser = approverMap.get(approverId);
                if (approverUser == null) {
                    System.debug('    ✗ WARNING - Approver User not found in approverMap: ' + approverId);
                    continue;
                }
                
                System.debug('    ✓ Approver found: ' + approverUser.Name + ' (' + approverUser.Email + ')');
                
                // Get Product Name safely
                String productName = (qli.Product2Id != null && productMap.containsKey(qli.Product2Id)) 
                    ? productMap.get(qli.Product2Id).Name 
                    : 'N/A';
                
                System.debug('    Product Name: ' + productName);
                System.debug('    Quote Name: ' + q.Name);
                System.debug('    Account Name: ' + (q.Account != null ? q.Account.Name : 'N/A'));
                System.debug('    Quote Owner: ' + owner.Name);
                System.debug('    Standard Discount (SAP): ' + qli.Discount_as_per_SAP__c + '%');
                System.debug('    Discount to be Offered: ' + qli.Discount_to_be_offered__c + '%');
                
                // Create Email Message
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { approverUser.Email });
                mail.setSubject('Discount Approval Request for Quote: ' + q.Name);
                mail.setWhatId(q.Id);
                mail.setSaveAsActivity(true);
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
                System.debug('    ✓ Email message created and added to send queue');
                
                // Create Custom Notification
                if (notificationTypeId != null) {
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setNotificationTypeId(notificationTypeId);
                    notification.setTargetId(q.Id); // Links to the Quote record
                    notification.setTitle('Discount Approval Required');
                    notification.setBody(
                        'Quote: ' + q.Name + ' | ' +
                        'Product: ' + productName + ' | ' +
                        'Discount: ' + qli.Discount_to_be_offered__c + '% (SAP: ' + qli.Discount_as_per_SAP__c + '%)'
                    );
                    
                    // Send to specific approver
                    notification.setSenderId(UserInfo.getUserId());
                    notification.send(new Set<String> { approverId });
                    
                    System.debug('    ✓ Custom notification sent to approver');
                } else {
                    System.debug('    ✗ Notification skipped (notification type not found)');
                }
            }
            
            System.debug('');
            if (!emails.isEmpty()) {
                System.debug('APPROVAL: ✓✓ Sending ' + emails.size() + ' email(s)');
                try {
                    Messaging.sendEmail(emails);
                    System.debug('APPROVAL: ✓✓ Email(s) sent successfully');
                } catch (Exception e) {
                    System.debug('APPROVAL: ✗✗ ERROR sending emails: ' + e.getMessage());
                    System.debug('APPROVAL: Stack trace: ' + e.getStackTraceString());
                }
            } else {
                System.debug('APPROVAL: No emails to send (all QLIs were skipped)');
            }
        } else {
            System.debug('APPROVAL: No approvers to notify (no valid QLIs processed)');
        }
        
        System.debug('');
        System.debug('=== INITIAL APPROVAL HANDLER END ===');
    }
    
    /**
     * Helper method to get Custom Notification Type ID by API Name
     */
    private static Id getCustomNotificationTypeId(String apiName) {
        try {
            CustomNotificationType notifType = [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType 
                WHERE DeveloperName = :apiName 
                LIMIT 1
            ];
            return notifType.Id;
        } catch (Exception e) {
            System.debug('ERROR: Could not find Custom Notification Type with API Name: ' + apiName);
            System.debug('Exception: ' + e.getMessage());
            return null;
        }
    }
}