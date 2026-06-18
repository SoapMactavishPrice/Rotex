public with sharing class QuoteFinalApprovalNotificationHandler {

    private static final String STATUS_APPROVED = 'Approved';
    private static final String NOTIFICATION_TYPE_API_NAME = 'Approval_Alert';

    // ─── Entry Points ────────────────────────────────────────────────────────

    public static void handleQuotesAfterUpdate(List<Quote> newQuotes, Map<Id, Quote> oldQuoteMap) {
        if (newQuotes == null || newQuotes.isEmpty() || oldQuoteMap == null) return;

        Map<Id, List<String>> quoteApprovals = new Map<Id, List<String>>();

        for (Quote q : newQuotes) {
            Quote oldQ = oldQuoteMap.get(q.Id);
            if (oldQ == null) continue;

            List<String> approvalLabels = getApprovedQuoteLabels(q, oldQ);
            if (!approvalLabels.isEmpty()) {
                quoteApprovals.put(q.Id, approvalLabels);
            }
        }

        sendOwnerNotifications(quoteApprovals);
    }

    public static void handleQuoteLineItemsAfterUpdate(List<QuoteLineItem> newQlis, Map<Id, QuoteLineItem> oldQliMap) {
        if (newQlis == null || newQlis.isEmpty() || oldQliMap == null) return;

        Map<Id, List<String>> quoteApprovals = new Map<Id, List<String>>();

        for (QuoteLineItem qli : newQlis) {
            QuoteLineItem oldQli = oldQliMap.get(qli.Id);
            if (oldQli == null || qli.QuoteId == null) continue;

            List<String> approvalLabels = getApprovedQliLabels(qli, oldQli);
            if (!approvalLabels.isEmpty()) {
                if (!quoteApprovals.containsKey(qli.QuoteId)) {
                    quoteApprovals.put(qli.QuoteId, new List<String>());
                }
                quoteApprovals.get(qli.QuoteId).addAll(approvalLabels);
            }
        }

        sendOwnerNotifications(quoteApprovals);
    }

    // ─── Approval Detection: Quote ───────────────────────────────────────────

    private static List<String> getApprovedQuoteLabels(Quote q, Quote oldQ) {
        List<String> labels = new List<String>();

        collectFinalQuoteApprovalLabels(q, oldQ, q.Final_Warranty_Terms_Approver__c,
            new List<String>{ 'SM_Warranty_Status__c', 'CH_Warranty_Status__c', 'GS_Warranty_Status__c', 'BM_Warranty_Status__c', 'MD_Warranty_Status__c' },
            new List<String>{ 'Sales_Manager__c', 'Country_Continent_Sales_Head_LOB_Head__c', 'Global_Sales_Head__c', 'Rotex_Board_Member__c', 'Managing_Director_Country_Manager__c' },
            'Warranty Terms Approval',
            labels
        );

        collectFinalQuoteApprovalLabels(q, oldQ, q.Final_Validity_Offer_Approver__c,
            new List<String>{ 'SM_Validity_Offer_Status__c', 'CH_Validity_Offer_Status__c', 'GS_Validity_Offer_Status__c', 'BM_Validity_Offer_Status__c', 'MD_Validity_Offer_Status__c' },
            new List<String>{ 'Sales_Manager__c', 'Country_Continent_Sales_Head_LOB_Head__c', 'Global_Sales_Head__c', 'Rotex_Board_Member__c', 'Managing_Director_Country_Manager__c' },
            'Validity Of Offer Approval',
            labels
        );

        collectFinalQuoteApprovalLabels(q, oldQ, q.Final_Total_Value_Approver__c,
            new List<String>{ 'SM_Value_Status__c', 'CH_Value_Status__c', 'GS_Value_Status__c', 'BM_Value_Status__c', 'MD_Value_Status__c' },
            new List<String>{ 'Sales_Manager__c', 'Country_Continent_Sales_Head_LOB_Head__c', 'Global_Sales_Head__c', 'Rotex_Board_Member__c', 'Managing_Director_Country_Manager__c' },
            'Total Value Approval',
            labels
        );

        collectFinalQuoteApprovalLabels(q, oldQ, q.Final_Minimum_Offer_Value_Approver__c,
            new List<String>{ 'GS_Min_Offer_Status__c', 'BM_Min_Offer_Status__c', 'MD_Min_Offer_Status__c' },
            new List<String>{ 'Global_Sales_Head__c', 'Rotex_Board_Member__c', 'Managing_Director_Country_Manager__c' },
            'Minimum Offer Value Approval',
            labels
        );

        if (statusJustApproved(q.Approval_Status__c, oldQ.Approval_Status__c))
            labels.add('Quote Approval');

        if (statusJustApproved(q.Payment_Terms_Approval_Status__c, oldQ.Payment_Terms_Approval_Status__c))
            labels.add('Payment Terms Approval');

        if (statusJustApproved(q.Warranty_Terms_Approval_Status__c, oldQ.Warranty_Terms_Approval_Status__c))
            labels.add('Warranty Terms Approval');

        if (statusJustApproved(q.Minimum_Offer_Approval_Status__c, oldQ.Minimum_Offer_Approval_Status__c))
            labels.add('Minimum Offer Approval');

        if (q.Is_all_approvals_final_approved__c == true && oldQ.Is_all_approvals_final_approved__c != true)
            labels.add('All Approvals Final Approved');

        return labels;
    }

    private static void collectFinalQuoteApprovalLabels(
        Quote q,
        Quote oldQ,
        Id finalApproverId,
        List<String> statusFields,
        List<String> approverFields,
        String approvalLabel,
        List<String> labels
    ) {
        if (finalApproverId == null) return;

        for (Integer i = 0; i < statusFields.size(); i++) {
            if (getIdField(q, approverFields[i]) == finalApproverId &&
                statusJustApproved(getStringField(q, statusFields[i]), getStringField(oldQ, statusFields[i]))) {
                labels.add(approvalLabel);
                return; // one match per approval type is enough
            }
        }
    }

    // ─── Approval Detection: Quote Line Item ─────────────────────────────────

    private static List<String> getApprovedQliLabels(QuoteLineItem qli, QuoteLineItem oldQli) {
        List<String> labels = new List<String>();

        Id finalApproverId = qli.Final_Discount_Approver__c;
        if (finalApproverId != null) {
            collectFinalQliLabel(qli, oldQli, finalApproverId, 'Sales_Rep__c',                         'Sales_Rep_Status__c',                       'Discount Approval (Sales Rep)',            labels);
            collectFinalQliLabel(qli, oldQli, finalApproverId, 'Sales_Manager__c',                     'Sales_Manager_Status__c',                   'Discount Approval (Sales Manager)',        labels);
            collectFinalQliLabel(qli, oldQli, finalApproverId, 'Country_Continent_Sales_Head_LOB_Head__c', 'Country_Continent_Sales_H_LOB_Status__c','Discount Approval (Country/Continental Head)', labels);
            collectFinalQliLabel(qli, oldQli, finalApproverId, 'Global_Sales_Head__c',                 'Global_Sales_Head_Status__c',               'Discount Approval (Global Sales Head)',    labels);
            collectFinalQliLabel(qli, oldQli, finalApproverId, 'Rotex_Board_Member__c',                'Rotex_Board_Member_Status__c',              'Discount Approval (Board Member)',         labels);
            collectFinalQliLabel(qli, oldQli, finalApproverId, 'Managing_Director_Country_Manage__c',  'Managing_Director_Status__c',               'Discount Approval (Managing Director)',    labels);
        }

        if (statusJustApproved(qli.Approval_Status__c, oldQli.Approval_Status__c))
            labels.add('Line Item Discount Approval');

        return labels;
    }

    private static void collectFinalQliLabel(
        QuoteLineItem qli,
        QuoteLineItem oldQli,
        Id finalApproverId,
        String approverField,
        String statusField,
        String approvalLabel,
        List<String> labels
    ) {
        if (getIdField(qli, approverField) == finalApproverId &&
            statusJustApproved(getStringField(qli, statusField), getStringField(oldQli, statusField))) {
            labels.add(approvalLabel);
        }
    }

    // ─── Notification Dispatch ───────────────────────────────────────────────

    private static void sendOwnerNotifications(Map<Id, List<String>> quoteApprovals) {
        if (quoteApprovals == null || quoteApprovals.isEmpty()) return;

        Map<Id, Quote> quotes = new Map<Id, Quote>([
            SELECT Id, QuoteNumber, OwnerId, Owner.Name, Owner.Email
            FROM Quote
            WHERE Id IN :quoteApprovals.keySet()
        ]);

        Id notificationTypeId = getNotificationTypeId();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Id quoteId : quoteApprovals.keySet()) {
            Quote q = quotes.get(quoteId);
            if (q == null || q.OwnerId == null) continue;

            List<String> approvalLabels = quoteApprovals.get(quoteId);

            Messaging.SingleEmailMessage email = buildOwnerEmail(q, approvalLabels);
            if (email != null) {
                emails.add(email);
            }

            if (notificationTypeId != null) {
                sendCustomNotification(notificationTypeId, q, approvalLabels);
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    // ─── Email Builder ───────────────────────────────────────────────────────

    private static Messaging.SingleEmailMessage buildOwnerEmail(Quote q, List<String> approvalLabels) {
        if (q.Owner == null || String.isBlank(q.Owner.Email)) return null;

        String quoteUrl  = URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Quote/' + q.Id + '/view';
        String quoteLink = '<a href="' + quoteUrl + '">' + q.QuoteNumber + '</a>';

        // Build approval list rows
        String approvalRows = '';
        for (String label : approvalLabels) {
            approvalRows += '<li>' + label + '</li>';
        }

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ q.Owner.Email });
        email.setWhatId(q.Id);
        email.setSaveAsActivity(true);
        email.setSubject('Quote Final Approved - ' + q.QuoteNumber);
        email.setHtmlBody(
            'Dear ' + q.Owner.Name + ',<br/><br/>' +
            'The following approval(s) on your quote have been final approved:<br/><br/>' +
            '<ul>' + approvalRows + '</ul>' +
            '<br/>Quote Link: ' + quoteLink + '<br/><br/>' +
            'Regards,<br/>Salesforce System'
        );
        return email;
    }

    // ─── Custom Notification ─────────────────────────────────────────────────

    private static Id getNotificationTypeId() {
        try {
            return [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = :NOTIFICATION_TYPE_API_NAME
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            System.debug('Final approval notification type not found: ' + e.getMessage());
            return null;
        }
    }

    private static void sendCustomNotification(Id notificationTypeId, Quote q, List<String> approvalLabels) {
        try {
            String body = String.join(approvalLabels, ', ');

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(notificationTypeId);
            notification.setTitle('Quote Final Approved - ' + q.QuoteNumber);
            notification.setBody('Approved: ' + body);
            notification.setTargetId(q.Id);
            notification.setSenderId(UserInfo.getUserId());
            notification.send(new Set<String>{ String.valueOf(q.OwnerId) });
        } catch (Exception e) {
            System.debug('Final approval custom notification failed: ' + e.getMessage());
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Boolean statusJustApproved(String newStatus, String oldStatus) {
        return newStatus == STATUS_APPROVED && oldStatus != STATUS_APPROVED;
    }

    private static Id getIdField(SObject record, String fieldApiName) {
        Object value = record == null ? null : record.get(fieldApiName);
        return value == null ? null : (Id)value;
    }

    private static String getStringField(SObject record, String fieldApiName) {
        Object value = record == null ? null : record.get(fieldApiName);
        return value == null ? null : String.valueOf(value);
    }
}