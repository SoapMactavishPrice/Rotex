/**
 * Notifies portal users of the Lead.Dealer__c account when a Lead is
 * forwarded to that dealer (Forward_to_Dealer__c = true).
 * Uses DealerNotificationService so the alert appears in dealerUserMenu.
 */
public without sharing class LeadForwardToDealerHandler {

    private static final String NOTIFICATION_TITLE = 'New Lead Assigned';
    private static final String NOTIFICATION_MESSAGE_TEMPLATE =
        'A new lead "{0}" has been assigned to you. Please review the lead details and take the necessary action.';

    public static void handleAfterInsert(List<Lead> newLeads) {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }
        List<Lead> toNotify = new List<Lead>();
        for (Lead ld : newLeads) {
            if (shouldNotify(ld)) {
                toNotify.add(ld);
            }
        }
        sendDealerNotifications(toNotify);
    }

    public static void handleAfterUpdate(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }
        List<Lead> toNotify = new List<Lead>();
        for (Lead ld : newLeads) {
            Lead oldLd = oldMap.get(ld.Id);
            if (!shouldNotify(ld)) {
                continue;
            }
            Boolean forwardJustEnabled =
                ld.Forward_to_Dealer__c == true &&
                (oldLd == null || oldLd.Forward_to_Dealer__c != true);
            Boolean dealerChangedWhileForwarded =
                ld.Forward_to_Dealer__c == true &&
                oldLd != null &&
                ld.Dealer__c != oldLd.Dealer__c;
            if (forwardJustEnabled || dealerChangedWhileForwarded) {
                toNotify.add(ld);
            }
        }
        sendDealerNotifications(toNotify);
    }

    private static Boolean shouldNotify(Lead ld) {
        return ld != null &&
            ld.Forward_to_Dealer__c == true &&
            ld.Dealer__c != null;
    }

    private static void sendDealerNotifications(List<Lead> leads) {
        if (leads == null || leads.isEmpty()) {
            return;
        }

        Set<Id> dealerAccountIds = new Set<Id>();
        for (Lead ld : leads) {
            dealerAccountIds.add(ld.Dealer__c);
        }

        Map<Id, Set<Id>> userIdsByAccountId = getActivePortalUsersByAccount(dealerAccountIds);
        if (userIdsByAccountId.isEmpty()) {
            return;
        }

        for (Lead ld : leads) {
            Set<Id> recipientIds = userIdsByAccountId.get(ld.Dealer__c);
            if (recipientIds == null || recipientIds.isEmpty()) {
                continue;
            }
            String leadName = resolveLeadName(ld);
            String body = String.format(NOTIFICATION_MESSAGE_TEMPLATE, new List<String>{ leadName });
            DealerNotificationService.sendNotification(
                recipientIds,
                NOTIFICATION_TITLE,
                body,
                ld.Id
            );
        }
    }

    private static String resolveLeadName(Lead ld) {
        if (ld == null) {
            return 'Unknown';
        }
        if (String.isNotBlank(ld.Name)) {
            return ld.Name;
        }
        String composed = ((ld.FirstName == null ? '' : ld.FirstName.trim()) + ' ' +
            (ld.LastName == null ? '' : ld.LastName.trim())).trim();
        if (String.isNotBlank(composed)) {
            return composed;
        }
        if (String.isNotBlank(ld.Company)) {
            return ld.Company;
        }
        return 'Unknown';
    }

    private static Map<Id, Set<Id>> getActivePortalUsersByAccount(Set<Id> accountIds) {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();
        if (accountIds == null || accountIds.isEmpty()) {
            return result;
        }

        for (User u : [
            SELECT Id, AccountId, Contact.AccountId
            FROM User
            WHERE IsActive = true
              AND (
                  AccountId IN :accountIds
                  OR Contact.AccountId IN :accountIds
              )
              AND UserType IN (
                  'PowerPartner',
                  'PowerCustomerSuccess',
                  'CspLitePortal',
                  'CustomerSuccess'
              )
        ]) {
            Id accountId = u.AccountId != null
                ? u.AccountId
                : (u.Contact != null ? u.Contact.AccountId : null);
            if (accountId == null || !accountIds.contains(accountId)) {
                continue;
            }
            if (!result.containsKey(accountId)) {
                result.put(accountId, new Set<Id>());
            }
            result.get(accountId).add(u.Id);
        }
        return result;
    }

    // =========================================================================
    // ACCOUNT APPROVAL METHODS (Reused Handler)
    // =========================================================================
    
    private static final String ACCOUNT_APPROVED_TITLE = 'Customer Approved';
    private static final String ACCOUNT_APPROVED_MESSAGE = 'Congratulations! Your customer registration for <b>"{0}"</b> has been approved. You can now proceed with further transactions.';
    
    private static final String ACCOUNT_REJECTED_TITLE = 'Customer Registration Rejected';
    private static final String ACCOUNT_REJECTED_MESSAGE = 'The registration request for <b>"{0}"</b> has been rejected. Please review the remarks and resubmit if required.';
    
    public static void handleAccountAfterUpdate(List<Account> newAccounts, Map<Id, Account> oldMap) {
        if (newAccounts == null || newAccounts.isEmpty()) return;
        
        Set<Id> accountIdsToQuery = new Set<Id>();
        for (Account acc : newAccounts) {
            Account oldAcc = oldMap != null ? oldMap.get(acc.Id) : null;
            if (oldAcc != null && acc.Approval_Status__c != oldAcc.Approval_Status__c) {
                accountIdsToQuery.add(acc.Id);
            }
        }
        
        if (accountIdsToQuery.isEmpty()) return;
        
        Map<Id, Account> queriedAccounts = new Map<Id, Account>([SELECT Id, RecordType.Name, RecordType.DeveloperName FROM Account WHERE Id IN :accountIdsToQuery]);
        
        Set<Id> partnerAccountIds = new Set<Id>();
        for (Account acc : newAccounts) {
            if (queriedAccounts.containsKey(acc.Id)) {
                String rtName = queriedAccounts.get(acc.Id).RecordType != null ? queriedAccounts.get(acc.Id).RecordType.Name : '';
                String rtDevName = queriedAccounts.get(acc.Id).RecordType != null ? queriedAccounts.get(acc.Id).RecordType.DeveloperName : '';
                
                if (rtName.containsIgnoreCase('Customer') || rtDevName.containsIgnoreCase('Customer')) {
                    Id partnerId = acc.Channel_Partner_Name__c != null ? acc.Channel_Partner_Name__c : acc.Channel_Partner__c;
                    if (partnerId != null) {
                        partnerAccountIds.add(partnerId);
                    }
                }
            }
        }
        for (Account acc : newAccounts) {
            Account oldAcc = oldMap != null ? oldMap.get(acc.Id) : null;
            if (oldAcc != null && acc.Approval_Status__c != oldAcc.Approval_Status__c) {
                Id partnerId = acc.Channel_Partner_Name__c != null ? acc.Channel_Partner_Name__c : acc.Channel_Partner__c;
                if (partnerId != null) {
                    partnerAccountIds.add(partnerId);
                }
            }
        }
        
        Map<Id, Set<Id>> userIdsByAccountId = getActivePortalUsersByAccount(partnerAccountIds);
        
        for (Account acc : newAccounts) {
            Account oldAcc = oldMap != null ? oldMap.get(acc.Id) : null;
            
            if (oldAcc != null && acc.Approval_Status__c != oldAcc.Approval_Status__c && queriedAccounts.containsKey(acc.Id)) {
                String rtName = queriedAccounts.get(acc.Id).RecordType != null ? queriedAccounts.get(acc.Id).RecordType.Name : '';
                String rtDevName = queriedAccounts.get(acc.Id).RecordType != null ? queriedAccounts.get(acc.Id).RecordType.DeveloperName : '';
                
                if (!rtName.containsIgnoreCase('Customer') && !rtDevName.containsIgnoreCase('Customer')) {
                    continue; // Skip non-customer accounts
                }
                
                String accountName = String.isNotBlank(acc.Name) ? acc.Name : 'Unknown Customer';
                
                Set<Id> recipientIds = new Set<Id>();
                Id partnerId = acc.Channel_Partner_Name__c != null ? acc.Channel_Partner_Name__c : acc.Channel_Partner__c;
                
                if (partnerId != null && userIdsByAccountId.containsKey(partnerId)) {
                    recipientIds.addAll(userIdsByAccountId.get(partnerId));
                }
                
                // Fallback to Account Owner if no partner users found
                if (recipientIds.isEmpty() && acc.OwnerId != null && String.valueOf(acc.OwnerId).startsWith('005')) {
                    recipientIds.add(acc.OwnerId);
                }
                
                if (!recipientIds.isEmpty()) {
                    if (acc.Approval_Status__c == 'Approved') {
                        sendAccountNotification(recipientIds, ACCOUNT_APPROVED_TITLE, ACCOUNT_APPROVED_MESSAGE, accountName, acc.Id);
                    } else if (acc.Approval_Status__c == 'Rejected') {
                        sendAccountNotification(recipientIds, ACCOUNT_REJECTED_TITLE, ACCOUNT_REJECTED_MESSAGE, accountName, acc.Id);
                    }
                }
            }
        }
    }
    
    private static void sendAccountNotification(Set<Id> userIds, String title, String messageTemplate, String accountName, Id recordId) {
        if (userIds != null && !userIds.isEmpty()) {
            String body = String.format(messageTemplate, new List<String>{ accountName });
            DealerNotificationService.sendNotification(
                userIds,
                title,
                body,
                recordId
            );
        }
    }

    // =========================================================================
    // QUOTE APPROVAL METHODS
    // =========================================================================

    public static void handleQuoteAfterUpdate(List<Quote> newQuotes, Map<Id, Quote> oldMap) {
        if (newQuotes == null || newQuotes.isEmpty()) return;
        
        Set<Id> accountIds = new Set<Id>();
        for (Quote q : newQuotes) {
            Quote oldQ = oldMap != null ? oldMap.get(q.Id) : null;
            if (oldQ != null && q.Status != oldQ.Status) {
                if (q.AccountId != null) accountIds.add(q.AccountId);
            }
        }
        
        Map<Id, Account> accountMap = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accountMap = new Map<Id, Account>([SELECT Id, Channel_Partner_Name__c, Channel_Partner__c FROM Account WHERE Id IN :accountIds]);
        }
        
        Set<Id> partnerAccountIds = new Set<Id>();
        for (Account acc : accountMap.values()) {
            if (acc.Channel_Partner_Name__c != null) partnerAccountIds.add(acc.Channel_Partner_Name__c);
            else if (acc.Channel_Partner__c != null) partnerAccountIds.add(acc.Channel_Partner__c);
            else partnerAccountIds.add(acc.Id);
        }
        
        Map<Id, Set<Id>> userIdsByAccountId = getActivePortalUsersByAccount(partnerAccountIds);
        
        for (Quote q : newQuotes) {
            Quote oldQ = oldMap != null ? oldMap.get(q.Id) : null;
            
            if (oldQ != null && q.Status != oldQ.Status) {
                String quoteNumber = 'Quote';
                try {
                    // Try to use QuoteNumber if available, fallback to Name
                    quoteNumber = String.isNotBlank((String)q.get('QuoteNumber')) ? (String)q.get('QuoteNumber') : (String.isNotBlank(q.Name) ? q.Name : 'Quote');
                } catch (Exception e) {
                    quoteNumber = String.isNotBlank(q.Name) ? q.Name : 'Quote';
                }
                
                Set<Id> recipientIds = new Set<Id>();
                
                if (q.AccountId != null && accountMap.containsKey(q.AccountId)) {
                    Account acc = accountMap.get(q.AccountId);
                    Id partnerId = acc.Channel_Partner_Name__c != null ? acc.Channel_Partner_Name__c : acc.Channel_Partner__c;
                    if (partnerId != null && userIdsByAccountId.containsKey(partnerId)) {
                        recipientIds.addAll(userIdsByAccountId.get(partnerId));
                    } else if (userIdsByAccountId.containsKey(acc.Id)) {
                        // The account itself might be the channel partner
                        recipientIds.addAll(userIdsByAccountId.get(acc.Id));
                    }
                }
                
                if (recipientIds.isEmpty()) {
                    try {
                        Id cpOwnerId = (Id)q.get('CP_Owner_Name__c');
                        if (cpOwnerId != null && String.valueOf(cpOwnerId).startsWith('005')) {
                            recipientIds.add(cpOwnerId);
                        }
                    } catch (Exception e) {}
                }
                
                if (recipientIds.isEmpty() && q.OwnerId != null && String.valueOf(q.OwnerId).startsWith('005')) {
                    recipientIds.add(q.OwnerId);
                }
                
                if (!recipientIds.isEmpty()) {
                    if (q.Status == 'Accepted' || q.Status == 'Closed Won') {
                        sendQuoteNotification(recipientIds, 'Quote Closed Won', 'Congratulations! Your quote "<b>{0}</b>" has been marked as <b>Closed Won</b>. You may now proceed with order processing.', quoteNumber, q.Id);
                    } else if (q.Status == 'Closed Lost') {
                        sendQuoteNotification(recipientIds, 'Quote Closed Lost', 'Your quote "<b>{0}</b>" has been marked as <b>Closed Lost</b>. Please review the loss reason for future reference.', quoteNumber, q.Id);
                    } else if (q.Status == 'Scrap Quote' || q.Status == 'Scrapped') {
                        sendQuoteNotification(recipientIds, 'Quote Scrapped', 'Your quote "<b>{0}</b>" has been scrapped and is no longer active.', quoteNumber, q.Id);
                    }
                }
            }
        }
    }
    
    private static void sendQuoteNotification(Set<Id> userIds, String title, String messageTemplate, String quoteName, Id recordId) {
        if (userIds != null && !userIds.isEmpty()) {
            String body = String.format(messageTemplate, new List<String>{ quoteName });
            DealerNotificationService.sendNotification(userIds, title, body, recordId);
        }
    }

    // =========================================================================
    // ORDER NOTIFICATION METHODS
    // =========================================================================

    private static final String TITLE_ORDER_ACCEPTED = 'Order Accepted';
    private static final String MSG_ORDER_ACCEPTED =
        'Order "{0}" has been accepted successfully. You can now track the order through the next stages of processing.';

    private static final String TITLE_WORK_ORDER_GENERATED = 'Work Order Generated';
    private static final String MSG_WORK_ORDER_GENERATED =
        'Work Order "{0}" has been generated for Order "{1}". You can now track the work order status from the portal.';

    private static final String TITLE_PACKING_LIST_GENERATED = 'Packing List Generated';
    private static final String MSG_PACKING_LIST_GENERATED =
        'Packing List "{0}" has been generated for Order "{1}". Please review the packing details in the portal.';

    private static final String TITLE_ORDER_DISPATCHED = 'Order Dispatched';
    private static final String MSG_ORDER_DISPATCHED =
        'Order "{0}" has been dispatched successfully. Please refer to the portal for shipment and delivery details.';

    public static void handleOrderAfterInsert(List<Order> newOrders) {
        if (newOrders == null || newOrders.isEmpty()) return;

        Map<Id, Account> accountMap = queryOrderAccounts(newOrders);
        Map<Id, Set<Id>> userIdsByAccountId = getOrderPortalUsersByAccount(accountMap);

        for (Order ord : newOrders) {
            Set<Id> recipientIds = resolveOrderRecipientIds(ord, accountMap, userIdsByAccountId);
            if (!recipientIds.isEmpty()) {
                sendOrderNotification(
                    recipientIds,
                    'New Order Booked',
                    'Order "{0}" has been booked successfully. Please review the order details and track its progress.',
                    new List<String>{ resolveOrderNumber(ord) },
                    ord.Id
                );
            }
        }
    }

    /**
     * Notify CP portal users when Order.Status moves to acceptance / WO / packing / dispatched.
     */
    public static void handleOrderAfterUpdate(List<Order> newOrders, Map<Id, Order> oldMap) {
        if (newOrders == null || newOrders.isEmpty() || oldMap == null) {
            return;
        }

        List<Order> statusChanged = new List<Order>();
        for (Order ord : newOrders) {
            Order oldOrd = oldMap.get(ord.Id);
            if (oldOrd != null && ord.Status != oldOrd.Status && isOrderStatusNotificationTarget(ord.Status)) {
                statusChanged.add(ord);
            }
        }
        if (statusChanged.isEmpty()) {
            return;
        }

        Map<Id, Account> accountMap = queryOrderAccounts(statusChanged);
        Map<Id, Set<Id>> userIdsByAccountId = getOrderPortalUsersByAccount(accountMap);

        for (Order ord : statusChanged) {
            Set<Id> recipientIds = resolveOrderRecipientIds(ord, accountMap, userIdsByAccountId);
            if (recipientIds.isEmpty()) {
                continue;
            }

            String orderNumber = resolveOrderNumber(ord);
            // No dedicated WO / packing-list number fields on Order — use Rotex SO / Order Number.
            String stageNumber = resolveOrderStageNumber(ord);

            if (ord.Status == 'Order Acceptance') {
                sendOrderNotification(
                    recipientIds,
                    TITLE_ORDER_ACCEPTED,
                    MSG_ORDER_ACCEPTED,
                    new List<String>{ orderNumber },
                    ord.Id
                );
            } else if (ord.Status == 'Work Order Generated') {
                sendOrderNotification(
                    recipientIds,
                    TITLE_WORK_ORDER_GENERATED,
                    MSG_WORK_ORDER_GENERATED,
                    new List<String>{ stageNumber, orderNumber },
                    ord.Id
                );
            } else if (ord.Status == 'Packing List Generated') {
                sendOrderNotification(
                    recipientIds,
                    TITLE_PACKING_LIST_GENERATED,
                    MSG_PACKING_LIST_GENERATED,
                    new List<String>{ stageNumber, orderNumber },
                    ord.Id
                );
            } else if (ord.Status == 'Dispatched') {
                sendOrderNotification(
                    recipientIds,
                    TITLE_ORDER_DISPATCHED,
                    MSG_ORDER_DISPATCHED,
                    new List<String>{ orderNumber },
                    ord.Id
                );
            }
        }
    }

    private static Boolean isOrderStatusNotificationTarget(String status) {
        return status == 'Order Acceptance'
            || status == 'Work Order Generated'
            || status == 'Packing List Generated'
            || status == 'Dispatched';
    }

    private static Map<Id, Account> queryOrderAccounts(List<Order> orders) {
        Set<Id> accountIds = new Set<Id>();
        for (Order ord : orders) {
            if (ord.AccountId != null) {
                accountIds.add(ord.AccountId);
            }
        }
        if (accountIds.isEmpty()) {
            return new Map<Id, Account>();
        }
        return new Map<Id, Account>([
            SELECT Id, Channel_Partner_Name__c, Channel_Partner__c
            FROM Account
            WHERE Id IN :accountIds
        ]);
    }

    private static Map<Id, Set<Id>> getOrderPortalUsersByAccount(Map<Id, Account> accountMap) {
        Set<Id> partnerAccountIds = new Set<Id>();
        for (Account acc : accountMap.values()) {
            if (acc.Channel_Partner_Name__c != null) {
                partnerAccountIds.add(acc.Channel_Partner_Name__c);
            } else if (acc.Channel_Partner__c != null) {
                partnerAccountIds.add(acc.Channel_Partner__c);
            } else {
                partnerAccountIds.add(acc.Id);
            }
        }
        return getActivePortalUsersByAccount(partnerAccountIds);
    }

    private static Set<Id> resolveOrderRecipientIds(
        Order ord,
        Map<Id, Account> accountMap,
        Map<Id, Set<Id>> userIdsByAccountId
    ) {
        Set<Id> recipientIds = new Set<Id>();

        if (ord.AccountId != null && accountMap.containsKey(ord.AccountId)) {
            Account acc = accountMap.get(ord.AccountId);
            Id partnerId = acc.Channel_Partner_Name__c != null
                ? acc.Channel_Partner_Name__c
                : acc.Channel_Partner__c;
            if (partnerId != null && userIdsByAccountId.containsKey(partnerId)) {
                recipientIds.addAll(userIdsByAccountId.get(partnerId));
            } else if (userIdsByAccountId.containsKey(acc.Id)) {
                recipientIds.addAll(userIdsByAccountId.get(acc.Id));
            }
        }

        if (recipientIds.isEmpty()) {
            try {
                Id cpOwnerId = (Id) ord.get('CP_Owner_Name__c');
                if (cpOwnerId != null && String.valueOf(cpOwnerId).startsWith('005')) {
                    recipientIds.add(cpOwnerId);
                }
            } catch (Exception e) {
                // Field may not exist on Order in every org
            }
        }

        if (recipientIds.isEmpty()
            && ord.OwnerId != null
            && String.valueOf(ord.OwnerId).startsWith('005')) {
            recipientIds.add(ord.OwnerId);
        }

        return recipientIds;
    }

    private static String resolveOrderNumber(Order ord) {
        try {
            if (String.isNotBlank(ord.SO_No__c)) {
                return ord.SO_No__c;
            }
        } catch (Exception e) {
            // ignore
        }
        try {
            String orderNumber = (String) ord.get('OrderNumber');
            if (String.isNotBlank(orderNumber)) {
                return orderNumber;
            }
        } catch (Exception e) {
            // ignore
        }
        return String.isNotBlank(ord.Name) ? ord.Name : 'Order';
    }

    private static String resolveOrderStageNumber(Order ord) {
        // Prefer Rotex SO / Order Number when dedicated WO / packing numbers are not on Order.
        return resolveOrderNumber(ord);
    }

    private static void sendOrderNotification(
        Set<Id> userIds,
        String title,
        String messageTemplate,
        List<String> formatArgs,
        Id recordId
    ) {
        if (userIds != null && !userIds.isEmpty()) {
            String body = String.format(messageTemplate, formatArgs);
            DealerNotificationService.sendNotification(userIds, title, body, recordId);
        }
    }

    // =========================================================================
    // INVOICE NOTIFICATION METHODS
    // =========================================================================

    public static void handleInvoiceAfterInsert(List<SO_Invoice__c> newInvoices) {
        if (newInvoices == null || newInvoices.isEmpty()) return;
        
        Set<Id> accountIds = new Set<Id>();
        for (SO_Invoice__c inv : newInvoices) {
            if (inv.Account__c != null) {
                accountIds.add(inv.Account__c);
            }
        }
        
        Map<Id, Account> accountMap = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accountMap = new Map<Id, Account>([SELECT Id, Channel_Partner_Name__c, Channel_Partner__c FROM Account WHERE Id IN :accountIds]);
        }
        
        Set<Id> partnerAccountIds = new Set<Id>();
        for (Account acc : accountMap.values()) {
            if (acc.Channel_Partner_Name__c != null) partnerAccountIds.add(acc.Channel_Partner_Name__c);
            else if (acc.Channel_Partner__c != null) partnerAccountIds.add(acc.Channel_Partner__c);
            else partnerAccountIds.add(acc.Id); // The account itself might be a channel partner
        }
        
        Map<Id, Set<Id>> userIdsByAccountId = getActivePortalUsersByAccount(partnerAccountIds);
        
        for (SO_Invoice__c inv : newInvoices) {
            String invoiceNumber = String.isNotBlank(inv.Name) ? inv.Name : 'Invoice';
            String orderNumber = 'Order';
            try {
                if (String.isNotBlank((String)inv.get('SO_No__c'))) {
                    orderNumber = (String)inv.get('SO_No__c');
                }
            } catch (Exception e) {}
            
            Set<Id> recipientIds = new Set<Id>();
            
            if (inv.Account__c != null && accountMap.containsKey(inv.Account__c)) {
                Account acc = accountMap.get(inv.Account__c);
                Id partnerId = acc.Channel_Partner_Name__c != null ? acc.Channel_Partner_Name__c : acc.Channel_Partner__c;
                if (partnerId != null && userIdsByAccountId.containsKey(partnerId)) {
                    recipientIds.addAll(userIdsByAccountId.get(partnerId));
                } else if (userIdsByAccountId.containsKey(acc.Id)) {
                    recipientIds.addAll(userIdsByAccountId.get(acc.Id));
                }
            }
            
            if (recipientIds.isEmpty()) {
                try {
                    Id cpOwnerId = (Id)inv.get('CP_Owner_Name__c');
                    if (cpOwnerId != null && String.valueOf(cpOwnerId).startsWith('005')) {
                        recipientIds.add(cpOwnerId);
                    }
                } catch (Exception e) {}
            }
            
            if (recipientIds.isEmpty() && inv.OwnerId != null && String.valueOf(inv.OwnerId).startsWith('005')) {
                recipientIds.add(inv.OwnerId);
            }
            
            if (!recipientIds.isEmpty()) {
                sendInvoiceNotification(recipientIds, 'Invoice Generated', 'Invoice "{0}" has been generated for your order "{1}". You can now view the invoice in the portal.', invoiceNumber, orderNumber, inv.Id);
            }
        }
    }
    
    private static void sendInvoiceNotification(Set<Id> userIds, String title, String messageTemplate, String invoiceNumber, String orderNumber, Id recordId) {
        if (userIds != null && !userIds.isEmpty()) {
            String body = String.format(messageTemplate, new List<String>{ invoiceNumber, orderNumber });
            DealerNotificationService.sendNotification(userIds, title, body, recordId);
        }
    }

    // =========================================================================
    // INVENTORY / MTA NOTIFICATION METHODS (11 & 12)
    // =========================================================================

    private static final String TITLE_MIN_STOCK = 'Minimum Stock Level Reached';
    private static final String MSG_MIN_STOCK =
        'Product "<b>{0} - {1}</b>" has reached its minimum stock level. An MTA Quote will be automatically generated based on the configured <b>ARC Price</b> or <b>Fixed Discount</b> for the <b>minimum</b> order quantity.';

    private static final String TITLE_MTA_QUOTE_GENERATED = 'MTA Quote Generated';
    private static final String MSG_MTA_QUOTE_GENERATED =
        'MTA Quote "<b>{0}</b>" has been generated successfully for "<b>{1}</b>". Please review the quote and push it to SAP to initiate order processing.';

    public static void handleInventoryAfterInsert(List<Inventory__c> newRows) {
        if (newRows == null || newRows.isEmpty()) {
            return;
        }
        processInventoryLowStock(newRows, null);
    }

    public static void handleInventoryAfterUpdate(
        List<Inventory__c> newRows,
        Map<Id, Inventory__c> oldMap
    ) {
        if (newRows == null || newRows.isEmpty()) {
            return;
        }
        processInventoryLowStock(newRows, oldMap);
    }

    private static void processInventoryLowStock(
        List<Inventory__c> newRows,
        Map<Id, Inventory__c> oldMap
    ) {
        Set<Id> candidateIds = new Set<Id>();
        for (Inventory__c inv : newRows) {
            if (inv.Channel_Partner__c == null || inv.Product__c == null) {
                continue;
            }
            if (!isBelowMinimumStock(inv)) {
                continue;
            }
            Inventory__c oldInv = oldMap != null ? oldMap.get(inv.Id) : null;
            if (oldInv != null && isBelowMinimumStock(oldInv)) {
                continue;
            }
            candidateIds.add(inv.Id);
        }

        if (candidateIds.isEmpty()) {
            return;
        }

        List<Inventory__c> withProduct = [
            SELECT Id, Name, Product__c, Product__r.Name, Product__r.ProductCode, Product_Code__c,
                   Available_Quantity__c, Minimum_Stock_Level__c, Channel_Partner__c
            FROM Inventory__c
            WHERE Id IN :candidateIds
        ];

        Set<Id> partnerIds = new Set<Id>();
        for (Inventory__c inv : withProduct) {
            if (inv.Channel_Partner__c != null) {
                partnerIds.add(inv.Channel_Partner__c);
            }
        }

        Map<Id, Set<Id>> userIdsByAccountId = getActivePortalUsersByAccount(partnerIds);

        for (Inventory__c inv : withProduct) {
            if (inv.Channel_Partner__c == null || !isBelowMinimumStock(inv)) {
                continue;
            }
            Set<Id> recipientIds = userIdsByAccountId.containsKey(inv.Channel_Partner__c)
                ? new Set<Id>(userIdsByAccountId.get(inv.Channel_Partner__c))
                : new Set<Id>();
            if (recipientIds.isEmpty()) {
                continue;
            }

            // One alert per user/inventory/day
            String targetKey = String.valueOf(inv.Id);
            for (Notification__c existing : [
                SELECT User__c
                FROM Notification__c
                WHERE Title__c = :TITLE_MIN_STOCK
                  AND Target_Record_Id__c = :targetKey
                  AND CreatedDate = TODAY
                  AND User__c IN :recipientIds
            ]) {
                recipientIds.remove(existing.User__c);
            }
            if (recipientIds.isEmpty()) {
                continue;
            }

            String productName = inv.Product__r != null && String.isNotBlank(inv.Product__r.Name)
                ? inv.Product__r.Name
                : (String.isNotBlank(inv.Name) ? inv.Name : 'Product');
            String productCode = inv.Product__r != null && String.isNotBlank(inv.Product__r.ProductCode)
                ? inv.Product__r.ProductCode
                : (String.isNotBlank(inv.Product_Code__c) ? inv.Product_Code__c : '—');

            String body = String.format(
                MSG_MIN_STOCK,
                new List<String>{ productName, productCode }
            );
            DealerNotificationService.sendNotification(
                recipientIds,
                TITLE_MIN_STOCK,
                body,
                inv.Id
            );
        }
    }

    private static Boolean isBelowMinimumStock(Inventory__c inv) {
        if (inv == null || inv.Minimum_Stock_Level__c == null || inv.Available_Quantity__c == null) {
            return false;
        }
        return inv.Available_Quantity__c < inv.Minimum_Stock_Level__c;
    }

    /**
     * Notification 12 — call after an MTA quote is successfully created.
     */
    public static void notifyMtaQuoteGenerated(
        Id partnerAccountId,
        Id quoteId,
        String quoteNumber,
        String productName
    ) {
        if (partnerAccountId == null || quoteId == null) {
            return;
        }

        Map<Id, Set<Id>> userIdsByAccountId = getActivePortalUsersByAccount(
            new Set<Id>{ partnerAccountId }
        );
        Set<Id> recipientIds = userIdsByAccountId.containsKey(partnerAccountId)
            ? userIdsByAccountId.get(partnerAccountId)
            : new Set<Id>();
        if (recipientIds.isEmpty()) {
            return;
        }

        String qNum = String.isNotBlank(quoteNumber) ? quoteNumber : String.valueOf(quoteId);
        String pName = String.isNotBlank(productName) ? productName : 'Product';
        String body = String.format(
            MSG_MTA_QUOTE_GENERATED,
            new List<String>{ qNum, pName }
        );
        DealerNotificationService.sendNotification(
            recipientIds,
            TITLE_MTA_QUOTE_GENERATED,
            body,
            quoteId
        );
    }
}