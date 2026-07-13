public without sharing class QuoteHighestFinalApproverBackfillBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static Boolean backfillRunning = false;

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

    public Integer processedQuotes { get; private set; }
    public Integer processedQuoteLineItems { get; private set; }
    public Integer updatedQuotes { get; private set; }
    public Integer updatedQuoteLineItems { get; private set; }

    public QuoteHighestFinalApproverBackfillBatch() {
        processedQuotes = 0;
        processedQuoteLineItems = 0;
        updatedQuotes = 0;
        updatedQuoteLineItems = 0;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Quote
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
            SELECT Id,
                   Sales_Manager__c,
                   Country_Continent_Sales_Head_LOB_Head__c,
                   Global_Sales_Head__c,
                   Rotex_Board_Member__c,
                   Managing_Director_Country_Manager__c,
                   Final_Warranty_Terms_Approver__c,
                   Final_Validity_Offer_Approver__c,
                   Final_Total_Value_Approver__c,
                   Highest_Final_Approver__c,
                   Effective_Final_Warranty_Approver__c,
                   Effective_Final_Validity_Approver__c,
                   Effective_Final_Total_Value_Approver__c
            FROM Quote
            WHERE Id IN :quoteIds
        ];

        Map<Id, Quote> quoteById = new Map<Id, Quote>(quotes);
        List<QuoteLineItem> qlis = [
            SELECT Id,
                   QuoteId,
                   Sales_Manager__c,
                   Country_Continent_Sales_Head_LOB_Head__c,
                   Global_Sales_Head__c,
                   Rotex_Board_Member__c,
                   Managing_Director_Country_Manage__c,
                   Final_Discount_Approver__c,
                   Effective_Final_Discount_Approver__c
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

        for (Quote q : quotes) {
            List<QuoteLineItem> quoteQlis = qlisByQuoteId.containsKey(q.Id)
                ? qlisByQuoteId.get(q.Id)
                : new List<QuoteLineItem>();

            Integer highestRank = getHighestFinalApproverRank(q, quoteQlis);
            Id highestApproverId = getApproverAtRank(q, quoteQlis, highestRank);

            Quote quoteUpdate = buildQuoteEffectiveApproverUpdate(q, highestRank, highestApproverId);
            if (quoteUpdate != null) quoteUpdates.add(quoteUpdate);

            for (QuoteLineItem qli : quoteQlis) {
                QuoteLineItem qliUpdate =
                    buildQuoteLineItemEffectiveApproverUpdate(qli, q, highestRank, highestApproverId);
                if (qliUpdate != null) qliUpdates.add(qliUpdate);
            }
        }

        backfillRunning = true;
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
            backfillRunning = false;
        }

        processedQuotes += quotes.size();
        processedQuoteLineItems += qlis.size();
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            LoggingLevel.INFO,
            'QuoteHighestFinalApproverBackfillBatch finished. ' +
            'Processed Quotes: ' + processedQuotes +
            ', processed QuoteLineItems: ' + processedQuoteLineItems +
            ', updated Quotes: ' + updatedQuotes +
            ', updated QuoteLineItems: ' + updatedQuoteLineItems
        );
    }

    @TestVisible
    private static Quote buildQuoteEffectiveApproverUpdate(
        Quote q,
        Integer highestRank,
        Id highestApproverId
    ) {
        if (q == null) return null;

        Quote updateRow = new Quote(Id = q.Id);
        Boolean changed = false;

        if (q.Highest_Final_Approver__c != highestApproverId) {
            updateRow.Highest_Final_Approver__c = highestApproverId;
            changed = true;
        }

        Id effectiveWarrantyApprover = getEffectiveApprover(
            q,
            q.Final_Warranty_Terms_Approver__c,
            highestRank,
            highestApproverId
        );
        if (q.Final_Warranty_Terms_Approver__c != null &&
            q.Effective_Final_Warranty_Approver__c != effectiveWarrantyApprover) {
            updateRow.Effective_Final_Warranty_Approver__c = effectiveWarrantyApprover;
            changed = true;
        }

        Id effectiveValidityApprover = getEffectiveApprover(
            q,
            q.Final_Validity_Offer_Approver__c,
            highestRank,
            highestApproverId
        );
        if (q.Final_Validity_Offer_Approver__c != null &&
            q.Effective_Final_Validity_Approver__c != effectiveValidityApprover) {
            updateRow.Effective_Final_Validity_Approver__c = effectiveValidityApprover;
            changed = true;
        }

        Id effectiveTotalValueApprover = getEffectiveApprover(
            q,
            q.Final_Total_Value_Approver__c,
            highestRank,
            highestApproverId
        );
        if (q.Final_Total_Value_Approver__c != null &&
            q.Effective_Final_Total_Value_Approver__c != effectiveTotalValueApprover) {
            updateRow.Effective_Final_Total_Value_Approver__c = effectiveTotalValueApprover;
            changed = true;
        }

        return changed ? updateRow : null;
    }

    @TestVisible
    private static QuoteLineItem buildQuoteLineItemEffectiveApproverUpdate(
        QuoteLineItem qli,
        Quote parentQuote,
        Integer highestRank,
        Id highestApproverId
    ) {
        if (qli == null || qli.Final_Discount_Approver__c == null) return null;

        Integer lineRank = qliRank(qli, parentQuote, qli.Final_Discount_Approver__c);
        Id effectiveApprover = highestRank != null && highestRank > lineRank && highestApproverId != null
            ? highestApproverId
            : qli.Final_Discount_Approver__c;

        if (qli.Effective_Final_Discount_Approver__c == effectiveApprover) return null;

        return new QuoteLineItem(
            Id = qli.Id,
            Effective_Final_Discount_Approver__c = effectiveApprover
        );
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

    private static Id getEffectiveApprover(
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

    public static Id runNow() {
        return runNow(50);
    }

    public static Boolean isBackfillRunning() {
        return backfillRunning;
    }

    @TestVisible
    private static void setBackfillRunningForTest(Boolean value) {
        backfillRunning = value;
    }

    public static Id runNow(Integer batchSize) {
        Integer safeBatchSize = batchSize == null || batchSize < 1 ? 50 : batchSize;
        return Database.executeBatch(new QuoteHighestFinalApproverBackfillBatch(), safeBatchSize);
    }
}
