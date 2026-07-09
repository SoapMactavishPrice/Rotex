public without sharing class QuoteHighestApprovalCoordinator {
    private static Boolean recalculationInProgress = false;

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

    public static void afterQuoteChange(List<Quote> newQuotes) {
        Set<Id> quoteIds = new Set<Id>();
        for (Quote q : newQuotes) if (q.Id != null) quoteIds.add(q.Id);
        recalculate(quoteIds, new Set<Id>());
    }

    public static void afterQliChange(
        List<QuoteLineItem> newQlis,
        Map<Id, QuoteLineItem> oldMap
    ) {
        Set<Id> quoteIds = new Set<Id>();
        Set<Id> isolatedReapprovalQliIds = new Set<Id>();

        for (QuoteLineItem qli : newQlis) {
            if (qli.QuoteId != null) quoteIds.add(qli.QuoteId);
            QuoteLineItem oldQli = oldMap == null ? null : oldMap.get(qli.Id);
            if (oldQli != null &&
                oldQli.Is_Discount_Approved__c == true &&
                qli.Discount_to_be_offered__c != oldQli.Discount_to_be_offered__c) {
                // A completed line was edited. Its new effective approver is
                // refreshed without reopening any other approval on the quote.
                isolatedReapprovalQliIds.add(qli.Id);
            }
        }
        recalculate(quoteIds, isolatedReapprovalQliIds);
    }

    private static void recalculate(Set<Id> quoteIds, Set<Id> isolatedReapprovalQliIds) {
        if (recalculationInProgress || quoteIds == null || quoteIds.isEmpty()) return;
        recalculationInProgress = true;
        try {
            Map<Id, Quote> quotes = new Map<Id, Quote>([
                SELECT Id,
                       Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                       Global_Sales_Head__c, Rotex_Board_Member__c,
                       Managing_Director_Country_Manager__c,
                       Final_Warranty_Terms_Approver__c,
                       Final_Validity_Offer_Approver__c,
                       Final_Total_Value_Approver__c,
                       Highest_Final_Approver__c,
                       Effective_Final_Warranty_Approver__c,
                       Effective_Final_Validity_Approver__c,
                       Effective_Final_Total_Value_Approver__c,
                       SM_Warranty_Status__c, CH_Warranty_Status__c,
                       GS_Warranty_Status__c, BM_Warranty_Status__c, MD_Warranty_Status__c,
                       SM_Validity_Offer_Status__c, CH_Validity_Offer_Status__c,
                       GS_Validity_Offer_Status__c, BM_Validity_Offer_Status__c,
                       MD_Validity_Offer_Status__c,
                       SM_Value_Status__c, CH_Value_Status__c, GS_Value_Status__c,
                       BM_Value_Status__c, MD_Value_Status__c
                FROM Quote
                WHERE Id IN :quoteIds
            ]);

            List<QuoteLineItem> qlis = [
                SELECT Id, QuoteId, Final_Discount_Approver__c,
                       Effective_Final_Discount_Approver__c,
                       Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                       Global_Sales_Head__c, Rotex_Board_Member__c,
                       Managing_Director_Country_Manage__c,
                       Sales_Manager_Status__c, Country_Continent_Sales_H_LOB_Status__c,
                       Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c,
                       Managing_Director_Status__c
                FROM QuoteLineItem
                WHERE QuoteId IN :quoteIds
            ];

            Map<Id, List<QuoteLineItem>> qlisByQuote = new Map<Id, List<QuoteLineItem>>();
            for (QuoteLineItem qli : qlis) {
                if (!qlisByQuote.containsKey(qli.QuoteId)) {
                    qlisByQuote.put(qli.QuoteId, new List<QuoteLineItem>());
                }
                qlisByQuote.get(qli.QuoteId).add(qli);
            }

            List<Quote> quoteUpdates = new List<Quote>();
            List<QuoteLineItem> qliUpdates = new List<QuoteLineItem>();

            for (Quote q : quotes.values()) {
                Integer highestRank = 0;
                highestRank = Math.max(highestRank, quoteRank(q, q.Final_Warranty_Terms_Approver__c));
                highestRank = Math.max(highestRank, quoteRank(q, q.Final_Validity_Offer_Approver__c));
                highestRank = Math.max(highestRank, quoteRank(q, q.Final_Total_Value_Approver__c));

                for (QuoteLineItem qli : qlisByQuote.get(q.Id) == null
                        ? new List<QuoteLineItem>() : qlisByQuote.get(q.Id)) {
                    highestRank = Math.max(highestRank, qliRank(qli, qli.Final_Discount_Approver__c));
                }

                Id highestApproverId = quoteApproverAt(q, highestRank);
                Quote quoteUpdate = new Quote(Id = q.Id);
                Boolean quoteChanged = false;

                if (q.Highest_Final_Approver__c != highestApproverId) {
                    quoteUpdate.Highest_Final_Approver__c = highestApproverId;
                    quoteChanged = true;
                }

                if (!isQuoteStreamTerminal(q, 'Warranty') &&
                    q.Final_Warranty_Terms_Approver__c != null &&
                    q.Effective_Final_Warranty_Approver__c != highestApproverId) {
                    quoteUpdate.Effective_Final_Warranty_Approver__c = highestApproverId;
                    quoteChanged = true;
                }
                if (!isQuoteStreamTerminal(q, 'Validity') &&
                    q.Final_Validity_Offer_Approver__c != null &&
                    q.Effective_Final_Validity_Approver__c != highestApproverId) {
                    quoteUpdate.Effective_Final_Validity_Approver__c = highestApproverId;
                    quoteChanged = true;
                }
                if (!isQuoteStreamTerminal(q, 'Total') &&
                    q.Final_Total_Value_Approver__c != null &&
                    q.Effective_Final_Total_Value_Approver__c != highestApproverId) {
                    quoteUpdate.Effective_Final_Total_Value_Approver__c = highestApproverId;
                    quoteChanged = true;
                }
                if (quoteChanged) quoteUpdates.add(quoteUpdate);

                for (QuoteLineItem qli : qlisByQuote.get(q.Id) == null
                        ? new List<QuoteLineItem>() : qlisByQuote.get(q.Id)) {
                    Boolean refreshThisCycle = isolatedReapprovalQliIds.contains(qli.Id);
                    Boolean canSynchronize = refreshThisCycle || !isQliTerminal(qli);
                    if (canSynchronize && qli.Final_Discount_Approver__c != null &&
                        qli.Effective_Final_Discount_Approver__c != highestApproverId) {
                        qliUpdates.add(new QuoteLineItem(
                            Id = qli.Id,
                            Effective_Final_Discount_Approver__c = highestApproverId
                        ));
                    }
                }
            }

            if (!quoteUpdates.isEmpty()) update quoteUpdates;
            if (!qliUpdates.isEmpty()) update qliUpdates;
        } finally {
            recalculationInProgress = false;
        }
    }

    public static Integer quoteRank(Quote q, Id approverId) {
        return rank(q, approverId, QUOTE_APPROVER_FIELDS);
    }

    public static Integer qliRank(QuoteLineItem qli, Id approverId) {
        return rank(qli, approverId, QLI_APPROVER_FIELDS);
    }

    public static Id effectiveQuoteApprover(Quote q, Id streamApproverId) {
        Id effective = (Id)q.get('Highest_Final_Approver__c');
        return quoteRank(q, effective) > quoteRank(q, streamApproverId)
            ? effective : streamApproverId;
    }

    public static Boolean isEffectiveQliApprovalJustGranted(
        QuoteLineItem qli,
        QuoteLineItem oldQli
    ) {
        if (qli == null || oldQli == null) return false;
        Id effectiveId = qli.Effective_Final_Discount_Approver__c == null
            ? qli.Final_Discount_Approver__c : qli.Effective_Final_Discount_Approver__c;
        Integer effectiveRank = qliRank(qli, effectiveId);
        if (effectiveRank == 0) return false;
        List<String> statusFields = new List<String>{
            'Sales_Manager_Status__c',
            'Country_Continent_Sales_H_LOB_Status__c',
            'Global_Sales_Head_Status__c',
            'Rotex_Board_Member_Status__c',
            'Managing_Director_Status__c'
        };
        String fieldName = statusFields[effectiveRank - 1];
        return (String)qli.get(fieldName) == 'Approved'
            && (String)oldQli.get(fieldName) != 'Approved';
    }

    private static Integer rank(SObject record, Id approverId, List<String> approverFields) {
        if (record == null || approverId == null) return 0;
        for (Integer i = 0; i < approverFields.size(); i++) {
            if ((Id)record.get(approverFields[i]) == approverId) return i + 1;
        }
        return 0;
    }

    private static Id quoteApproverAt(Quote q, Integer rank) {
        return rank == null || rank < 1 ? null : (Id)q.get(QUOTE_APPROVER_FIELDS[rank - 1]);
    }

    private static Boolean isQuoteStreamTerminal(Quote q, String stream) {
        Id effectiveId;
        List<String> statuses;
        if (stream == 'Warranty') {
            effectiveId = q.Effective_Final_Warranty_Approver__c;
            statuses = new List<String>{ q.SM_Warranty_Status__c, q.CH_Warranty_Status__c,
                q.GS_Warranty_Status__c, q.BM_Warranty_Status__c, q.MD_Warranty_Status__c };
        } else if (stream == 'Validity') {
            effectiveId = q.Effective_Final_Validity_Approver__c;
            statuses = new List<String>{ q.SM_Validity_Offer_Status__c, q.CH_Validity_Offer_Status__c,
                q.GS_Validity_Offer_Status__c, q.BM_Validity_Offer_Status__c,
                q.MD_Validity_Offer_Status__c };
        } else {
            effectiveId = q.Effective_Final_Total_Value_Approver__c;
            statuses = new List<String>{ q.SM_Value_Status__c, q.CH_Value_Status__c,
                q.GS_Value_Status__c, q.BM_Value_Status__c, q.MD_Value_Status__c };
        }
        Integer effectiveRank = quoteRank(q, effectiveId);
        return effectiveRank > 0 && isTerminal(statuses[effectiveRank - 1]);
    }

    private static Boolean isQliTerminal(QuoteLineItem qli) {
        Integer effectiveRank = qliRank(qli, qli.Effective_Final_Discount_Approver__c);
        if (effectiveRank == 0) return false;
        List<String> statuses = new List<String>{
            qli.Sales_Manager_Status__c,
            qli.Country_Continent_Sales_H_LOB_Status__c,
            qli.Global_Sales_Head_Status__c,
            qli.Rotex_Board_Member_Status__c,
            qli.Managing_Director_Status__c
        };
        return isTerminal(statuses[effectiveRank - 1]);
    }

    private static Boolean isTerminal(String status) {
        return status == 'Approved' || status == 'Rejected';
    }
}
