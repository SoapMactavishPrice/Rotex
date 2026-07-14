public without sharing class QuoteSapApprovalCompletionBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final String STATUS_APPROVED = 'Approved';
    private static final String STATUS_REJECTED = 'Rejected';
    private static Boolean completionRunning = false;

    private static final List<String> QUOTE_APPROVER_FIELDS = new List<String>{
        'Sales_Manager__c',
        'Country_Continent_Sales_Head_LOB_Head__c',
        'Global_Sales_Head__c',
        'Rotex_Board_Member__c',
        'Managing_Director_Country_Manager__c'
    };

    private static final List<String> QLI_APPROVER_FIELDS = new List<String>{
        'Sales_Manager__c',
        'Country_Continent_Sales_Head_LOB_Head__c',
        'Global_Sales_Head__c',
        'Rotex_Board_Member__c',
        'Managing_Director_Country_Manage__c'
    };

    private static final List<String> DISCOUNT_STATUS_FIELDS = new List<String>{
        'Sales_Manager_Status__c',
        'Country_Continent_Sales_H_LOB_Status__c',
        'Global_Sales_Head_Status__c',
        'Rotex_Board_Member_Status__c',
        'Managing_Director_Status__c'
    };

    private static final List<String> DISCOUNT_DATE_FIELDS = new List<String>{
        'Sales_Manager_Date_Time__c',
        'Country_Head_Date_Time__c',
        'Global_Sales_Head_Date_Time__c',
        'Rotex_Board_Member_Date_Time__c',
        'Managing_Director_Date_Time__c'
    };

    private static final Map<String, List<String>> QUOTE_STATUS_FIELDS_BY_STREAM =
        new Map<String, List<String>>{
            'Warranty' => new List<String>{
                'SM_Warranty_Status__c',
                'CH_Warranty_Status__c',
                'GS_Warranty_Status__c',
                'BM_Warranty_Status__c',
                'MD_Warranty_Status__c'
            },
            'Validity' => new List<String>{
                'SM_Validity_Offer_Status__c',
                'CH_Validity_Offer_Status__c',
                'GS_Validity_Offer_Status__c',
                'BM_Validity_Offer_Status__c',
                'MD_Validity_Offer_Status__c'
            },
            'Total' => new List<String>{
                'SM_Value_Status__c',
                'CH_Value_Status__c',
                'GS_Value_Status__c',
                'BM_Value_Status__c',
                'MD_Value_Status__c'
            }
        };

    private static final Map<String, List<String>> QUOTE_DATE_FIELDS_BY_STREAM =
        new Map<String, List<String>>{
            'Warranty' => new List<String>{
                'SM_Warranty_Date_Time__c',
                'CH_Warranty_Date_Time__c',
                'GS_Warranty_Date_Time__c',
                'BM_Warranty_Date_Time__c',
                'MD_Warranty_Date_Time__c'
            },
            'Validity' => new List<String>{
                'SM_Validity_Offer_Date_Time__c',
                'CH_Validity_Offer_Date_Time__c',
                'GS_Validity_Offer_Date_Time__c',
                'BM_Validity_Offer_Date_Time__c',
                'MD_Validity_Offer_Date_Time__c'
            },
            'Total' => new List<String>{
                'SM_Value_Date_Time__c',
                'CH_Value_Date_Time__c',
                'GS_Value_Date_Time__c',
                'BM_Value_Date_Time__c',
                'MD_Value_Date_Time__c'
            }
        };

    public Integer processedQuotes { get; private set; }
    public Integer processedQuoteLineItems { get; private set; }
    public Integer updatedQuotes { get; private set; }
    public Integer updatedQuoteLineItems { get; private set; }

    public QuoteSapApprovalCompletionBatch() {
        processedQuotes = 0;
        processedQuoteLineItems = 0;
        updatedQuotes = 0;
        updatedQuoteLineItems = 0;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Quote
            WHERE SAP_Quotation_Number__c != null
            ORDER BY CreatedDate DESC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Set<Id> quoteIds = new Set<Id>();
        for (SObject row : scope) {
            Id quoteId = (Id) row.get('Id');
            if (quoteId != null) quoteIds.add(quoteId);
        }
        if (quoteIds.isEmpty()) return;

        List<Quote> quotes = [
            SELECT Id, SAP_Quotation_Number__c,
                   Sales_Manager__c,
                   Country_Continent_Sales_Head_LOB_Head__c,
                   Global_Sales_Head__c,
                   Rotex_Board_Member__c,
                   Managing_Director_Country_Manager__c,
                   Final_Warranty_Terms_Approver__c,
                   Effective_Final_Warranty_Approver__c,
                   Final_Validity_Offer_Approver__c,
                   Effective_Final_Validity_Approver__c,
                   Final_Total_Value_Approver__c,
                   Effective_Final_Total_Value_Approver__c,
                   Highest_Final_Approver__c,
                   SM_Warranty_Status__c, CH_Warranty_Status__c,
                   GS_Warranty_Status__c, BM_Warranty_Status__c,
                   MD_Warranty_Status__c,
                   SM_Warranty_Date_Time__c, CH_Warranty_Date_Time__c,
                   GS_Warranty_Date_Time__c, BM_Warranty_Date_Time__c,
                   MD_Warranty_Date_Time__c,
                   SM_Validity_Offer_Status__c, CH_Validity_Offer_Status__c,
                   GS_Validity_Offer_Status__c, BM_Validity_Offer_Status__c,
                   MD_Validity_Offer_Status__c,
                   SM_Validity_Offer_Date_Time__c, CH_Validity_Offer_Date_Time__c,
                   GS_Validity_Offer_Date_Time__c, BM_Validity_Offer_Date_Time__c,
                   MD_Validity_Offer_Date_Time__c,
                   SM_Value_Status__c, CH_Value_Status__c, GS_Value_Status__c,
                   BM_Value_Status__c, MD_Value_Status__c,
                   SM_Value_Date_Time__c, CH_Value_Date_Time__c,
                   GS_Value_Date_Time__c, BM_Value_Date_Time__c,
                   MD_Value_Date_Time__c
            FROM Quote
            WHERE Id IN :quoteIds
              AND SAP_Quotation_Number__c != null
        ];

        List<QuoteLineItem> qlis = [
            SELECT Id, QuoteId,
                   Sales_Manager__c,
                   Country_Continent_Sales_Head_LOB_Head__c,
                   Global_Sales_Head__c,
                   Rotex_Board_Member__c,
                   Managing_Director_Country_Manage__c,
                   Final_Discount_Approver__c,
                   Effective_Final_Discount_Approver__c,
                   Sales_Manager_Status__c,
                   Country_Continent_Sales_H_LOB_Status__c,
                   Global_Sales_Head_Status__c,
                   Rotex_Board_Member_Status__c,
                   Managing_Director_Status__c,
                   Sales_Manager_Date_Time__c,
                   Country_Head_Date_Time__c,
                   Global_Sales_Head_Date_Time__c,
                   Rotex_Board_Member_Date_Time__c,
                   Managing_Director_Date_Time__c
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
        ];

        Map<Id, List<QuoteLineItem>> qlisByQuoteId = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem qli : qlis) {
            if (!qlisByQuoteId.containsKey(qli.QuoteId)) {
                qlisByQuoteId.put(qli.QuoteId, new List<QuoteLineItem>());
            }
            qlisByQuoteId.get(qli.QuoteId).add(qli);
        }

        List<Quote> quoteUpdates = new List<Quote>();
        List<QuoteLineItem> qliUpdates = new List<QuoteLineItem>();
        DateTime approvedAt = DateTime.now();

        for (Quote q : quotes) {
            List<QuoteLineItem> quoteQlis = qlisByQuoteId.containsKey(q.Id)
                ? qlisByQuoteId.get(q.Id)
                : new List<QuoteLineItem>();

            Integer highestRank = getHighestFinalApproverRank(q, quoteQlis);
            Id highestApproverId = getApproverAtRank(q, quoteQlis, highestRank);

            Quote quoteUpdate =
                buildQuoteCompletionUpdate(q, highestRank, highestApproverId, approvedAt);
            if (quoteUpdate != null) quoteUpdates.add(quoteUpdate);

            for (QuoteLineItem qli : quoteQlis) {
                QuoteLineItem qliUpdate =
                    buildQuoteLineItemCompletionUpdate(qli, q, highestRank, highestApproverId, approvedAt);
                if (qliUpdate != null) qliUpdates.add(qliUpdate);
            }
        }

        completionRunning = true;
        try {
            if (!quoteUpdates.isEmpty()) {
                update quoteUpdates;
                updatedQuotes += quoteUpdates.size();
            }
            if (!qliUpdates.isEmpty()) {
                update qliUpdates;
                updatedQuoteLineItems += qliUpdates.size();
            }
        } finally {
            completionRunning = false;
        }

        processedQuotes += quotes.size();
        processedQuoteLineItems += qlis.size();
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            LoggingLevel.INFO,
            'QuoteSapApprovalCompletionBatch finished. ' +
            'Processed Quotes: ' + processedQuotes +
            ', processed QuoteLineItems: ' + processedQuoteLineItems +
            ', updated Quotes: ' + updatedQuotes +
            ', updated QuoteLineItems: ' + updatedQuoteLineItems
        );
    }

    @TestVisible
    private static Quote buildQuoteCompletionUpdate(
        Quote q,
        Integer highestRank,
        Id highestApproverId,
        DateTime approvedAt
    ) {
        if (q == null || String.isBlank(q.SAP_Quotation_Number__c)) return null;

        Quote updateRow = new Quote(Id = q.Id);
        Boolean changed = false;

        if (q.Highest_Final_Approver__c != highestApproverId) {
            updateRow.Highest_Final_Approver__c = highestApproverId;
            changed = true;
        }

        changed = applyQuoteStreamCompletion(
            updateRow, q, 'Warranty',
            q.Final_Warranty_Terms_Approver__c,
            q.Effective_Final_Warranty_Approver__c,
            'Effective_Final_Warranty_Approver__c',
            highestRank, highestApproverId, approvedAt
        ) || changed;

        changed = applyQuoteStreamCompletion(
            updateRow, q, 'Validity',
            q.Final_Validity_Offer_Approver__c,
            q.Effective_Final_Validity_Approver__c,
            'Effective_Final_Validity_Approver__c',
            highestRank, highestApproverId, approvedAt
        ) || changed;

        changed = applyQuoteStreamCompletion(
            updateRow, q, 'Total',
            q.Final_Total_Value_Approver__c,
            q.Effective_Final_Total_Value_Approver__c,
            'Effective_Final_Total_Value_Approver__c',
            highestRank, highestApproverId, approvedAt
        ) || changed;

        return changed ? updateRow : null;
    }

    private static Boolean applyQuoteStreamCompletion(
        Quote updateRow,
        Quote q,
        String stream,
        Id finalApproverId,
        Id existingEffectiveApproverId,
        String effectiveApproverField,
        Integer highestRank,
        Id highestApproverId,
        DateTime approvedAt
    ) {
        if (finalApproverId == null) return false;

        Boolean changed = false;
        Id effectiveApproverId = getEffectiveQuoteApprover(q, finalApproverId, highestRank, highestApproverId);
        if (existingEffectiveApproverId != effectiveApproverId) {
            updateRow.put(effectiveApproverField, effectiveApproverId);
            changed = true;
        }

        Integer effectiveRank = quoteRank(q, effectiveApproverId);
        if (effectiveRank < 1) return changed;

        String statusField = QUOTE_STATUS_FIELDS_BY_STREAM.get(stream)[effectiveRank - 1];
        String dateField = QUOTE_DATE_FIELDS_BY_STREAM.get(stream)[effectiveRank - 1];
        String currentStatus = (String) q.get(statusField);

        if (!isTerminal(currentStatus)) {
            updateRow.put(statusField, STATUS_APPROVED);
            updateRow.put(dateField, approvedAt);
            changed = true;
        }

        return changed;
    }

    @TestVisible
    private static QuoteLineItem buildQuoteLineItemCompletionUpdate(
        QuoteLineItem qli,
        Quote parentQuote,
        Integer highestRank,
        Id highestApproverId,
        DateTime approvedAt
    ) {
        if (qli == null || qli.Final_Discount_Approver__c == null) return null;

        QuoteLineItem updateRow = new QuoteLineItem(Id = qli.Id);
        Boolean changed = false;

        Integer lineRank = qliRank(qli, parentQuote, qli.Final_Discount_Approver__c);
        Id effectiveApproverId =
            highestRank != null && highestRank > lineRank && highestApproverId != null
            ? highestApproverId
            : qli.Final_Discount_Approver__c;

        if (qli.Effective_Final_Discount_Approver__c != effectiveApproverId) {
            updateRow.Effective_Final_Discount_Approver__c = effectiveApproverId;
            changed = true;
        }

        Integer effectiveRank = qliRank(qli, parentQuote, effectiveApproverId);
        if (effectiveRank < 1) return changed ? updateRow : null;

        String statusField = DISCOUNT_STATUS_FIELDS[effectiveRank - 1];
        String dateField = DISCOUNT_DATE_FIELDS[effectiveRank - 1];
        String currentStatus = (String) qli.get(statusField);

        if (!isTerminal(currentStatus)) {
            updateRow.put(statusField, STATUS_APPROVED);
            updateRow.put(dateField, approvedAt);
            changed = true;
        }

        return changed ? updateRow : null;
    }

    @TestVisible
    private static Integer getHighestFinalApproverRank(Quote q, List<QuoteLineItem> qlis) {
        Integer highestRank = 0;
        highestRank = Math.max(highestRank, quoteRank(q, q.Final_Warranty_Terms_Approver__c));
        highestRank = Math.max(highestRank, quoteRank(q, q.Final_Validity_Offer_Approver__c));
        highestRank = Math.max(highestRank, quoteRank(q, q.Final_Total_Value_Approver__c));

        for (QuoteLineItem qli : qlis == null ? new List<QuoteLineItem>() : qlis) {
            highestRank = Math.max(highestRank, qliRank(qli, q, qli.Final_Discount_Approver__c));
        }

        return highestRank;
    }

    @TestVisible
    private static Id getApproverAtRank(Quote q, List<QuoteLineItem> qlis, Integer rank) {
        if (rank == null || rank < 1) return null;

        Id quoteApprover = (Id) q.get(QUOTE_APPROVER_FIELDS[rank - 1]);
        if (quoteApprover != null) return quoteApprover;

        for (QuoteLineItem qli : qlis == null ? new List<QuoteLineItem>() : qlis) {
            Id qliApprover = (Id) qli.get(QLI_APPROVER_FIELDS[rank - 1]);
            if (qliApprover != null) return qliApprover;
        }

        return null;
    }

    private static Id getEffectiveQuoteApprover(
        Quote q,
        Id finalApproverId,
        Integer highestRank,
        Id highestApproverId
    ) {
        if (finalApproverId == null) return null;
        Integer finalRank = quoteRank(q, finalApproverId);
        return highestRank != null && highestRank > finalRank && highestApproverId != null
            ? highestApproverId
            : finalApproverId;
    }

    private static Integer quoteRank(Quote q, Id approverId) {
        return rank(q, approverId, QUOTE_APPROVER_FIELDS);
    }

    private static Integer qliRank(QuoteLineItem qli, Quote parentQuote, Id approverId) {
        Integer rankFromLine = rank(qli, approverId, QLI_APPROVER_FIELDS);
        return rankFromLine > 0 ? rankFromLine : rank(parentQuote, approverId, QUOTE_APPROVER_FIELDS);
    }

    private static Integer rank(SObject record, Id approverId, List<String> approverFields) {
        if (record == null || approverId == null) return 0;
        for (Integer i = 0; i < approverFields.size(); i++) {
            if ((Id) record.get(approverFields[i]) == approverId) return i + 1;
        }
        return 0;
    }

    private static Boolean isTerminal(String status) {
        return status == STATUS_APPROVED || status == STATUS_REJECTED;
    }

    public static Id runNow() {
        return runNow(50);
    }

    public static Id runNow(Integer batchSize) {
        Integer safeBatchSize = batchSize == null || batchSize < 1 ? 50 : batchSize;
        return Database.executeBatch(new QuoteSapApprovalCompletionBatch(), safeBatchSize);
    }

    public static Boolean isCompletionRunning() {
        return completionRunning;
    }

    @TestVisible
    private static void setCompletionRunningForTest(Boolean value) {
        completionRunning = value;
    }
}
