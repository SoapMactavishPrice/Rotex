public without sharing class QuoteFinalApprovalNotificationHandler {

    private static final String STATUS_APPROVED = 'Approved';
    private static final String STATUS_REJECTED = 'Rejected';
    private static final String NOTIFICATION_TYPE_API_NAME = 'Approval_Alert';

    // ─── Entry Points ────────────────────────────────────────────────────────

    public static void handleQuotesAfterUpdate(List<Quote> newQuotes, Map<Id, Quote> oldQuoteMap) {
        if (newQuotes == null || newQuotes.isEmpty() || oldQuoteMap == null) return;

        Map<Id, List<ApprovalDetail>> quoteApprovals = new Map<Id, List<ApprovalDetail>>();

        for (Quote q : newQuotes) {
            Quote oldQ = oldQuoteMap.get(q.Id);
            if (oldQ == null) continue;

            List<ApprovalDetail> approvalDetails = getFinalQuoteApprovalDetails(q, oldQ);
            if (!approvalDetails.isEmpty()) {
                quoteApprovals.put(q.Id, approvalDetails);
            }
        }

        sendOwnerNotifications(quoteApprovals);
    }

    public static void handleQuoteLineItemsAfterUpdate(List<QuoteLineItem> newQlis, Map<Id, QuoteLineItem> oldQliMap) {
        if (newQlis == null || newQlis.isEmpty() || oldQliMap == null) return;

        Map<Id, List<ApprovalDetail>> quoteApprovals = new Map<Id, List<ApprovalDetail>>();

        for (QuoteLineItem qli : newQlis) {
            QuoteLineItem oldQli = oldQliMap.get(qli.Id);
            if (oldQli == null || qli.QuoteId == null) continue;

            List<ApprovalDetail> approvalDetails = getFinalQliApprovalDetails(qli, oldQli);
            if (!approvalDetails.isEmpty()) {
                if (!quoteApprovals.containsKey(qli.QuoteId)) {
                    quoteApprovals.put(qli.QuoteId, new List<ApprovalDetail>());
                }
                quoteApprovals.get(qli.QuoteId).addAll(approvalDetails);
            }
        }

        sendOwnerNotifications(quoteApprovals);
    }

    // ─── Approval Detection: Quote ───────────────────────────────────────────

    private static List<ApprovalDetail> getFinalQuoteApprovalDetails(Quote q, Quote oldQ) {
        List<ApprovalDetail> details = new List<ApprovalDetail>();

        collectFinalQuoteApprovalDetails(q, oldQ,
            q.Effective_Final_Warranty_Approver__c == null
                ? q.Final_Warranty_Terms_Approver__c : q.Effective_Final_Warranty_Approver__c,
            new List<String>{ 'SM_Warranty_Status__c', 'CH_Warranty_Status__c', 'GS_Warranty_Status__c', 'BM_Warranty_Status__c', 'MD_Warranty_Status__c' },
            new List<String>{ 'SM_Warranty_Comments__c', 'CH_Warranty_Comments__c', 'GS_Warranty_Comments__c', 'BM_Warranty_Comments__c', 'MD_Warranty_Comments__c' },
            new List<String>{ 'Sales_Manager__c', 'Country_Continent_Sales_Head_LOB_Head__c', 'Global_Sales_Head__c', 'Rotex_Board_Member__c', 'Managing_Director_Country_Manager__c' },
            'Warranty Terms Approval',
            details
        );

        collectFinalQuoteApprovalDetails(q, oldQ,
            q.Effective_Final_Validity_Approver__c == null
                ? q.Final_Validity_Offer_Approver__c : q.Effective_Final_Validity_Approver__c,
            new List<String>{ 'SM_Validity_Offer_Status__c', 'CH_Validity_Offer_Status__c', 'GS_Validity_Offer_Status__c', 'BM_Validity_Offer_Status__c', 'MD_Validity_Offer_Status__c' },
            new List<String>{ 'SM_Validity_Offer_Comments__c', 'CH_Validity_Offer_Comments__c', 'GS_Validity_Offer_Comments__c', 'BM_Validity_Offer_Comments__c', 'MD_Validity_Offer_Comments__c' },
            new List<String>{ 'Sales_Manager__c', 'Country_Continent_Sales_Head_LOB_Head__c', 'Global_Sales_Head__c', 'Rotex_Board_Member__c', 'Managing_Director_Country_Manager__c' },
            'Validity Of Offer Approval',
            details
        );

        collectFinalQuoteApprovalDetails(q, oldQ,
            q.Effective_Final_Total_Value_Approver__c == null
                ? q.Final_Total_Value_Approver__c : q.Effective_Final_Total_Value_Approver__c,
            new List<String>{ 'SM_Value_Status__c', 'CH_Value_Status__c', 'GS_Value_Status__c', 'BM_Value_Status__c', 'MD_Value_Status__c' },
            new List<String>{ 'SM_Value_Comments__c', 'CH_Value_Comments__c', 'GS_Value_Comments__c', 'BM_Value_Comments__c', 'MD_Value_Comments__c' },
            new List<String>{ 'Sales_Manager__c', 'Country_Continent_Sales_Head_LOB_Head__c', 'Global_Sales_Head__c', 'Rotex_Board_Member__c', 'Managing_Director_Country_Manager__c' },
            'Total Value Approval',
            details
        );

        collectFinalQuoteApprovalDetails(q, oldQ, q.Final_Minimum_Offer_Value_Approver__c,
            new List<String>{ 'GS_Min_Offer_Status__c', 'BM_Min_Offer_Status__c', 'MD_Min_Offer_Status__c' },
            new List<String>{ 'GS_Min_Offer_Comments__c', 'BM_Min_Offer_Comments__c', 'MD_Min_Offer_Comments__c' },
            new List<String>{ 'Global_Sales_Head__c', 'Rotex_Board_Member__c', 'Managing_Director_Country_Manager__c' },
            'Minimum Offer Value Approval',
            details
        );

        if (statusJustDecided(q.Approval_Status__c, oldQ.Approval_Status__c))
            details.add(new ApprovalDetail('Quote Approval', q.Approval_Status__c, null, null));

        if (statusJustDecided(q.Payment_Terms_Approval_Status__c, oldQ.Payment_Terms_Approval_Status__c))
            details.add(new ApprovalDetail('Payment Terms Approval', q.Payment_Terms_Approval_Status__c, null, null));

        if (statusJustDecided(q.Warranty_Terms_Approval_Status__c, oldQ.Warranty_Terms_Approval_Status__c))
            details.add(new ApprovalDetail('Warranty Terms Approval', q.Warranty_Terms_Approval_Status__c, null, null));

        if (statusJustDecided(q.Minimum_Offer_Approval_Status__c, oldQ.Minimum_Offer_Approval_Status__c))
            details.add(new ApprovalDetail('Minimum Offer Approval', q.Minimum_Offer_Approval_Status__c, null, null));

        if (q.Is_all_approvals_e_final_approved__c == true && oldQ.Is_all_approvals_e_final_approved__c != true)
            details.add(new ApprovalDetail('All Approvals Final Approved', STATUS_APPROVED, null, null));

        return details;
    }

    private static void collectFinalQuoteApprovalDetails(
        Quote q,
        Quote oldQ,
        Id finalApproverId,
        List<String> statusFields,
        List<String> commentFields,
        List<String> approverFields,
        String approvalLabel,
        List<ApprovalDetail> details
    ) {
        if (finalApproverId == null) return;

        for (Integer i = 0; i < statusFields.size(); i++) {
            if (getIdField(q, approverFields[i]) == finalApproverId &&
                statusJustDecided(getStringField(q, statusFields[i]), getStringField(oldQ, statusFields[i]))) {
                details.add(new ApprovalDetail(
                    approvalLabel,
                    getStringField(q, statusFields[i]),
                    getStringField(q, commentFields[i]),
                    null
                ));
                return; // one match per approval type is enough
            }
        }
    }

    // ─── Approval Detection: Quote Line Item ─────────────────────────────────

    private static List<ApprovalDetail> getFinalQliApprovalDetails(QuoteLineItem qli, QuoteLineItem oldQli) {
        List<ApprovalDetail> details = new List<ApprovalDetail>();

        Id finalApproverId = qli.Effective_Final_Discount_Approver__c == null
            ? qli.Final_Discount_Approver__c : qli.Effective_Final_Discount_Approver__c;
        if (finalApproverId != null) {
            collectFinalQliDetail(qli, oldQli, finalApproverId, 'Sales_Rep__c',                         'Sales_Rep_Status__c',                       'Approval_Comments__c',                  'Discount Approval (Sales Rep)',                 details);
            collectFinalQliDetail(qli, oldQli, finalApproverId, 'Sales_Manager__c',                     'Sales_Manager_Status__c',                   'Sales_Manager_Comments__c',             'Discount Approval (Sales Manager)',             details);
            collectFinalQliDetail(qli, oldQli, finalApproverId, 'Country_Continent_Sales_Head_LOB_Head__c', 'Country_Continent_Sales_H_LOB_Status__c','Country_Continent_Sales_LOB_Comments__c','Discount Approval (Country/Continental Head)', details);
            collectFinalQliDetail(qli, oldQli, finalApproverId, 'Global_Sales_Head__c',                 'Global_Sales_Head_Status__c',               'Global_Sales_Head_Comments__c',         'Discount Approval (Global Sales Head)',         details);
            collectFinalQliDetail(qli, oldQli, finalApproverId, 'Rotex_Board_Member__c',                'Rotex_Board_Member_Status__c',              'Rotex_Board_Member_Comments__c',        'Discount Approval (Board Member)',              details);
            collectFinalQliDetail(qli, oldQli, finalApproverId, 'Managing_Director_Country_Manage__c',  'Managing_Director_Status__c',               'Managing_Director_Comments__c',         'Discount Approval (Managing Director)',         details);
        }

        if (statusJustDecided(qli.Approval_Status__c, oldQli.Approval_Status__c))
            details.add(new ApprovalDetail('Line Item Discount Approval', qli.Approval_Status__c, getStringField(qli, 'Approval_Comments__c'), qli.Id));

        return details;
    }

    private static void collectFinalQliDetail(
        QuoteLineItem qli,
        QuoteLineItem oldQli,
        Id finalApproverId,
        String approverField,
        String statusField,
        String commentField,
        String approvalLabel,
        List<ApprovalDetail> details
    ) {
        if (getIdField(qli, approverField) == finalApproverId &&
            statusJustDecided(getStringField(qli, statusField), getStringField(oldQli, statusField))) {
            details.add(new ApprovalDetail(
                approvalLabel,
                getStringField(qli, statusField),
                getStringField(qli, commentField),
                qli.Id
            ));
        }
    }

    // ─── Notification Dispatch ───────────────────────────────────────────────

    private static void sendOwnerNotifications(Map<Id, List<ApprovalDetail>> quoteApprovals) {
        if (quoteApprovals == null || quoteApprovals.isEmpty()) return;

        Map<Id, Quote> quotes = new Map<Id, Quote>([
            SELECT Id, QuoteNumber, OwnerId, Owner.Name, Owner.Email
            FROM Quote
            WHERE Id IN :quoteApprovals.keySet()
        ]);
        Map<Id, QuoteLineItem> qliById = getQuoteLineItemDetails(quoteApprovals);

        Id notificationTypeId = getNotificationTypeId();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Id quoteId : quoteApprovals.keySet()) {
            Quote q = quotes.get(quoteId);
            if (q == null || q.OwnerId == null) continue;

            List<ApprovalDetail> approvalDetails = quoteApprovals.get(quoteId);

            Messaging.SingleEmailMessage email = buildOwnerEmail(q, approvalDetails, qliById);
            if (email != null) {
                emails.add(email);
            }

            if (notificationTypeId != null) {
                sendCustomNotification(notificationTypeId, q, approvalDetails);
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    // ─── Email Builder ───────────────────────────────────────────────────────

    private static Messaging.SingleEmailMessage buildOwnerEmail(Quote q, List<ApprovalDetail> approvalDetails, Map<Id, QuoteLineItem> qliById) {
        if (q.Owner == null || String.isBlank(q.Owner.Email)) return null;

        String quoteUrl  = URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Quote/' + q.Id + '/view';
        String quoteLink = '<a href="' + quoteUrl + '">' + q.QuoteNumber + '</a>';
        Boolean hasRejected = hasStatus(approvalDetails, STATUS_REJECTED);
        Boolean hasApproved = hasStatus(approvalDetails, STATUS_APPROVED);
        String decisionSummary = hasApproved && hasRejected ? 'approved/rejected'
            : (hasRejected ? 'rejected' : 'approved');

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ q.Owner.Email });
        email.setWhatId(q.Id);
        email.setSaveAsActivity(true);
        email.setSubject('Quote Final Approval Decision - ' + q.QuoteNumber);
        email.setHtmlBody(
            'Dear ' + q.Owner.Name + ',<br/><br/>' +
            'The following approval(s) on your quote have been final ' + decisionSummary + ':<br/><br/>' +
            buildQuoteApprovalTable(approvalDetails) +
            buildLineApprovalTable(approvalDetails, qliById) +
            '<br/>Quote Link: ' + quoteLink + '<br/><br/>' +
            'Regards,<br/>Salesforce System'
        );
        return email;
    }

    private static String buildQuoteApprovalTable(List<ApprovalDetail> approvalDetails) {
        String rows = '';
        for (ApprovalDetail detail : approvalDetails) {
            if (detail.quoteLineItemId != null) continue;
            rows += '<tr>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;">' + html(detail.label) + '</td>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;text-align:center;">' + html(detail.status) + '</td>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;">' + html(detail.comments) + '</td>';
            rows += '</tr>';
        }
        if (String.isBlank(rows)) return '';
        return '<b>Quote Approval Details</b><br/>' +
            '<table style="border-collapse:collapse;width:100%;font-family:Arial,sans-serif;font-size:13px;">' +
            '<thead><tr style="background-color:#007764;color:#ffffff;">' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:left;">Approval</th>' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:center;">Status</th>' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:left;">Final Approver Comments</th>' +
            '</tr></thead>' +
            '<tbody>' + rows + '</tbody></table><br/>';
    }

    private static String buildLineApprovalTable(List<ApprovalDetail> approvalDetails, Map<Id, QuoteLineItem> qliById) {
        String rows = '';
        for (ApprovalDetail detail : approvalDetails) {
            if (detail.quoteLineItemId == null) continue;
            QuoteLineItem qli = qliById == null ? null : qliById.get(detail.quoteLineItemId);
            rows += '<tr>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;">' + html(qli != null && qli.Product2 != null ? qli.Product2.Name : '') + '</td>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;">' + html(qli != null && qli.Product2 != null ? qli.Product2.ProductCode : '') + '</td>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;text-align:center;">' + html(qli != null ? qli.Quantity : null) + '</td>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;text-align:right;">' + html(qli != null ? qli.ListPrice : null) + '</td>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;text-align:right;">' + html(qli != null ? qli.UnitPrice : null) + '</td>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;text-align:center;">' + html(qli != null ? qli.Discount_as_per_SAP__c : null) + '</td>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;text-align:center;">' + html(qli != null ? qli.Discount_to_be_offered__c : null) + '</td>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;text-align:center;">' + html(detail.status) + '</td>';
            rows += '<td style="border:1px solid #ccc;padding:6px 10px;">' + html(detail.comments) + '</td>';
            rows += '</tr>';
        }
        if (String.isBlank(rows)) return '';
        return '<b>Line Item Approval Details</b><br/>' +
            '<table style="border-collapse:collapse;width:100%;font-family:Arial,sans-serif;font-size:13px;">' +
            '<thead><tr style="background-color:#007764;color:#ffffff;">' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:left;">Product Name</th>' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:left;">Product Code</th>' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:center;">Quantity</th>' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:right;">List Price</th>' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:right;">Sales Price</th>' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:center;">Discount as per SAP %</th>' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:center;">Discount Offered %</th>' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:center;">Approval Status</th>' +
            '<th style="border:1px solid #ccc;padding:8px 10px;text-align:left;">Final Approver Comments</th>' +
            '</tr></thead>' +
            '<tbody>' + rows + '</tbody></table><br/>';
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

    private static void sendCustomNotification(Id notificationTypeId, Quote q, List<ApprovalDetail> approvalDetails) {
        try {
            String body = buildNotificationSummary(approvalDetails);

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(notificationTypeId);
            notification.setTitle('Quote Final Approval Decision - ' + q.QuoteNumber);
            notification.setBody(body);
            notification.setTargetId(q.Id);
            notification.setSenderId(UserInfo.getUserId());
            notification.send(new Set<String>{ String.valueOf(q.OwnerId) });
        } catch (Exception e) {
            System.debug('Final approval custom notification failed: ' + e.getMessage());
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Boolean statusJustDecided(String newStatus, String oldStatus) {
        return (newStatus == STATUS_APPROVED || newStatus == STATUS_REJECTED) && oldStatus != newStatus;
    }

    private static Id getIdField(SObject record, String fieldApiName) {
        Object value = record == null ? null : record.get(fieldApiName);
        return value == null ? null : (Id)value;
    }

    private static String getStringField(SObject record, String fieldApiName) {
        Object value = record == null ? null : record.get(fieldApiName);
        return value == null ? null : String.valueOf(value);
    }

    private static Map<Id, QuoteLineItem> getQuoteLineItemDetails(Map<Id, List<ApprovalDetail>> quoteApprovals) {
        Set<Id> qliIds = new Set<Id>();
        for (List<ApprovalDetail> details : quoteApprovals.values()) {
            for (ApprovalDetail detail : details) {
                if (detail.quoteLineItemId != null) qliIds.add(detail.quoteLineItemId);
            }
        }
        if (qliIds.isEmpty()) return new Map<Id, QuoteLineItem>();
        return new Map<Id, QuoteLineItem>([
            SELECT Id, Product2.Name, Product2.ProductCode, Quantity, ListPrice, UnitPrice,
                   Discount_as_per_SAP__c, Discount_to_be_offered__c
            FROM QuoteLineItem
            WHERE Id IN :qliIds
        ]);
    }

    private static Boolean hasStatus(List<ApprovalDetail> details, String status) {
        for (ApprovalDetail detail : details) {
            if (detail.status == status) return true;
        }
        return false;
    }

    private static String buildNotificationSummary(List<ApprovalDetail> details) {
        List<String> parts = new List<String>();
        for (ApprovalDetail detail : details) {
            parts.add(detail.status + ': ' + detail.label);
        }
        return String.join(parts, ', ');
    }

    private static String html(Object value) {
        return value == null ? '' : String.valueOf(value).escapeHtml4();
    }

    private class ApprovalDetail {
        String label;
        String status;
        String comments;
        Id quoteLineItemId;

        ApprovalDetail(String label, String status, String comments, Id quoteLineItemId) {
            this.label = label;
            this.status = status;
            this.comments = comments;
            this.quoteLineItemId = quoteLineItemId;
        }
    }
}
