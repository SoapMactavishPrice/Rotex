public without sharing class SalesPriceApprovalForQuotation {

    public QuotationWrapper quotation;

    public SalesPriceApprovalForQuotation(QuotationWrapper quotation) {
        this.quotation = quotation;
    }

    /**
     * @description: Merged method — returns ALL quotes where the current user
     *               has either a pending DISCOUNT approval (QLI-level) OR a
     *               pending WARRANTY approval (Quote-level).
     *               Previously the two concerns lived in getAllQuotations() and
     *               getWarrantyApprovals() separately; they are now unified so
     *               the LWC only needs a single server call.
     */
    @AuraEnabled
    public static List<QuotationWrapper> getAllQuotations() {
        Id currentUserId = UserInfo.getUserId();

        List<QuoteLineItem> submittedQlis = [
            SELECT QuoteId
            FROM   QuoteLineItem
            WHERE  (
                       Sales_Manager__c                       = :currentUserId OR
                       Country_Continent_Sales_Head_LOB_Head__c = :currentUserId OR
                       Global_Sales_Head__c                   = :currentUserId OR
                       Managing_Director_Country_Manage__c    = :currentUserId OR
                       Rotex_Board_Member__c                  = :currentUserId
                   )
                   AND Discount_offered_SAP__c = true
                   AND Is_Discount_Approved__c = false
                   AND (
                       Sales_Manager_Status__c = 'Submitted' OR
                       Country_Continent_Sales_H_LOB_Status__c = 'Submitted' OR
                       Global_Sales_Head_Status__c = 'Submitted' OR
                       Rotex_Board_Member_Status__c = 'Submitted' OR
                       Managing_Director_Status__c = 'Submitted'
                   )
        ];

        Set<Id> discountQuoteIds = new Set<Id>();
        for (QuoteLineItem qli : submittedQlis) {
            discountQuoteIds.add(qli.QuoteId);
        }

        List<Quote> warrantyQuotes = [
            SELECT Id
            FROM   Quote
            WHERE  (
                       Sales_Manager__c                          = :currentUserId OR
                       Country_Continent_Sales_Head_LOB_Head__c  = :currentUserId OR
                       Global_Sales_Head__c                      = :currentUserId OR
                       Rotex_Board_Member__c                     = :currentUserId OR
                       Managing_Director_Country_Manager__c      = :currentUserId
                   )
                   AND Warranty_Terms_Draft__c != null
                   AND Warranty_Terms_Draft__c != '12 Months from date of supply'
                   AND (
                       SM_Warranty_Status__c = 'Submitted' OR
                       CH_Warranty_Status__c = 'Submitted' OR
                       GS_Warranty_Status__c = 'Submitted' OR
                       BM_Warranty_Status__c = 'Submitted' OR
                       MD_Warranty_Status__c = 'Submitted'
                   )
        ];

        Set<Id> warrantyQuoteIds = new Set<Id>();
        for (Quote q : warrantyQuotes) {
            warrantyQuoteIds.add(q.Id);
        }

        List<Quote> validityOfferQuotes = [
            SELECT Id
            FROM   Quote
            WHERE  (
                       Sales_Manager__c                          = :currentUserId OR
                       Country_Continent_Sales_Head_LOB_Head__c  = :currentUserId OR
                       Global_Sales_Head__c                      = :currentUserId OR
                       Rotex_Board_Member__c                     = :currentUserId OR
                       Managing_Director_Country_Manager__c      = :currentUserId
                   )
                   AND Requested_Validity_Of_Offer__c != null
                   AND Requested_Validity_Of_Offer__c != '30 Days'
                   AND (
                       SM_Validity_Offer_Status__c = 'Submitted' OR
                       CH_Validity_Offer_Status__c = 'Submitted' OR
                       GS_Validity_Offer_Status__c = 'Submitted' OR
                       BM_Validity_Offer_Status__c = 'Submitted' OR
                       MD_Validity_Offer_Status__c = 'Submitted'
                   )
        ];

        Set<Id> validityOfferQuoteIds = new Set<Id>();
        for (Quote q : validityOfferQuotes) {
            validityOfferQuoteIds.add(q.Id);
        }

        List<Quote> totalValueQuotes = [
            SELECT Id
            FROM   Quote
            WHERE  (
                       Sales_Manager__c                          = :currentUserId OR
                       Country_Continent_Sales_Head_LOB_Head__c  = :currentUserId OR
                       Global_Sales_Head__c                      = :currentUserId OR
                       Rotex_Board_Member__c                     = :currentUserId OR
                       Managing_Director_Country_Manager__c      = :currentUserId
                   )
                   AND Total_Value__c != null
                   AND Is_Total_Value_Approved__c = false
                   AND (
                       SM_Value_Status__c = 'Submitted' OR
                       CH_Value_Status__c = 'Submitted' OR
                       GS_Value_Status__c = 'Submitted' OR
                       BM_Value_Status__c = 'Submitted' OR
                       MD_Value_Status__c = 'Submitted'
                   )
        ];

        Set<Id> totalValueQuoteIds = new Set<Id>();
        for (Quote q : totalValueQuotes) {
            totalValueQuoteIds.add(q.Id);
        }

        List<Quote> minimumOfferQuotes = [
            SELECT Id
            FROM   Quote
            WHERE  (
                       Global_Sales_Head__c                  = :currentUserId OR
                       Rotex_Board_Member__c                 = :currentUserId OR
                       Managing_Director_Country_Manager__c  = :currentUserId
                   )
                   AND Is_Small_Order_Handling__c = true
                   AND Total_Value__c != null
                   AND Total_Value__c < 25000
                   AND Is_Minimum_Offer_Value_Approved__c = false
                   AND (
                       GS_Min_Offer_Status__c = 'Submitted' OR
                       BM_Min_Offer_Status__c = 'Submitted' OR
                       MD_Min_Offer_Status__c = 'Submitted'
                   )
        ];

        Set<Id> minimumOfferQuoteIds = new Set<Id>();
        for (Quote q : minimumOfferQuotes) {
            minimumOfferQuoteIds.add(q.Id);
        }

        Set<Id> allRelevantQuoteIds = new Set<Id>(discountQuoteIds);
        allRelevantQuoteIds.addAll(warrantyQuoteIds);
        allRelevantQuoteIds.addAll(validityOfferQuoteIds);
        allRelevantQuoteIds.addAll(totalValueQuoteIds);
        allRelevantQuoteIds.addAll(minimumOfferQuoteIds);

        if (allRelevantQuoteIds.isEmpty()) {
            throw new AuraHandledException(
                'No Quotation Line Items found with their status as "Pending"'
            );
        }

        List<QuoteLineItem> quoteLineItems = new List<QuoteLineItem>();
        if (!allRelevantQuoteIds.isEmpty()) {
            quoteLineItems = [
                SELECT Approval_Comments__c, Approval_Status__c, Approver__c, CreatedById, ServiceDate,
                       Discount, LastModifiedById, Description, LineNumber, ListPrice,
                       Product2Id, Product2.Name, Quantity, QuoteId, Discount_as_per_SAP__c, Product2.ProductCode,
                       Global_Sales_Head__c, Global_Sales_Head_Status__c, Reject_Reason__c,
                       UnitPrice, SortOrder, Subtotal, TotalPrice, Discount_to_be_offered__c,
                       Sales_Rep__c, Sales_Rep_Status__c, Sales_Manager__c, Sales_Manager_Status__c,
                       Country_Continent_Sales_Head_LOB_Head__c, Country_Continent_Sales_H_LOB_Status__c,
                       Managing_Director_Country_Manage__c, Managing_Director_Status__c,
                       Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                       Final_Discount_Approver__c,
                       Country_Continent_Sales_LOB_Comments__c, Global_Sales_Head_Comments__c,
                       Managing_Director_Comments__c, Rotex_Board_Member_Comments__c,
                       Sales_Manager_Comments__c, Sales_Manager__r.Name,
                       Country_Continent_Sales_Head_LOB_Head__r.Name, Rotex_Board_Member__r.Name,
                       Managing_Director_Country_Manage__r.Name, Global_Sales_Head__r.Name,
                       Sales_Manager_Date_Time__c, Country_Head_Date_Time__c,
                       Global_Sales_Head_Date_Time__c, Rotex_Board_Member_Date_Time__c,
                       Managing_Director_Date_Time__c, Previous_Discount__c, Is_Discount_Approved__c,
                       Prev_Sales_Manager_Comments__c, Prev_Country_Continent_Sales_Comments__c,
                       Prev_Global_Sales_Head_Comments__c, Prev_Rotex_Board_Member_Comments__c,
                       Prev_Managing_Director_Comments__c
                FROM   QuoteLineItem
                WHERE  QuoteId IN :allRelevantQuoteIds
                       AND Discount_offered_SAP__c = true
                       AND (
                           Sales_Manager_Status__c != null OR
                           Country_Continent_Sales_H_LOB_Status__c != null OR
                           Global_Sales_Head_Status__c != null OR
                           Rotex_Board_Member_Status__c != null OR
                           Managing_Director_Status__c != null
                       )
            ];
        }

        Map<Id, Quote> quoteMap = new Map<Id, Quote>([
            SELECT Id, Name, Owner.Email, Owner.Name, OwnerId, Account.Name, QuoteNumber,
                   Account.OwnerId, Sales_Rep__c, Sales_Manager__c, Sales_Manager_Status__c,
                   Sales_Rep_Status__c, Country_Continent_Sales_Head_LOB_Head__c,
                   Country_Continent_Sales_H_LOB_Status__c, Global_Sales_Head__c,
                   Managing_Director_Country_Manager__c, Managing_Director_Status__c,
                   Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                   Total_Value__c, Avg_Discount_Requested__c, Avg_Discount_Approved__c,
                   Rev_No__c, Validity_of_Offer__c, Payment_Terms__c,
                   Warranty_Terms__c, Delivery_Period__c, Warranty_Terms_Draft__c,
                   Sales_Manager__r.Name, Country_Continent_Sales_Head_LOB_Head__r.Name,
                   Global_Sales_Head__r.Name, Rotex_Board_Member__r.Name,
                   Managing_Director_Country_Manager__r.Name,
                   SM_Warranty_Status__c,  SM_Warranty_Date_Time__c,  SM_Warranty_Comments__c,
                   CH_Warranty_Status__c,  CH_Warranty_Date_Time__c,  CH_Warranty_Comments__c,
                   GS_Warranty_Status__c,  GS_Warranty_Date_Time__c,  GS_Warranty_Comments__c,
                   BM_Warranty_Status__c,  BM_Warranty_Date_Time__c,  BM_Warranty_Comments__c,
                   MD_Warranty_Status__c,  MD_Warranty_Date_Time__c,  MD_Warranty_Comments__c,
                   Final_Warranty_Terms_Approver__c,
                   Requested_Validity_Of_Offer__c,
                   SM_Validity_Offer_Status__c,  SM_Validity_Offer_Date_Time__c,  SM_Validity_Offer_Comments__c,
                   CH_Validity_Offer_Status__c,  CH_Validity_Offer_Date_Time__c,  CH_Validity_Offer_Comments__c,
                   GS_Validity_Offer_Status__c,  GS_Validity_Offer_Date_Time__c,  GS_Validity_Offer_Comments__c,
                   BM_Validity_Offer_Status__c,  BM_Validity_Offer_Date_Time__c,  BM_Validity_Offer_Comments__c,
                   MD_Validity_Offer_Status__c,  MD_Validity_Offer_Date_Time__c,  MD_Validity_Offer_Comments__c,
                   Final_Validity_Offer_Approver__c,
                   SM_Value_Status__c,  SM_Value_Date_Time__c,  SM_Value_Comments__c,
                   CH_Value_Status__c,  CH_Value_Date_Time__c,  CH_Value_Comments__c,
                   GS_Value_Status__c,  GS_Value_Date_Time__c,  GS_Value_Comments__c,
                   BM_Value_Status__c,  BM_Value_Date_Time__c,  BM_Value_Comments__c,
                   MD_Value_Status__c,  MD_Value_Date_Time__c,  MD_Value_Comments__c,
                   Final_Total_Value_Approver__c, Is_Total_Value_Approved__c, Is_Small_Order_Handling__c,
                   SM_Min_Offer_Status__c,  SM_Min_Offer_Date_Time__c,  SM_Min_Offer_Comments__c,
                   CH_Min_Offer_Status__c,  CH_Min_Offer_Date_Time__c,  CH_Min_Offer_Comments__c,
                   GS_Min_Offer_Status__c,  GS_Min_Offer_Date_Time__c,  GS_Min_Offer_Comments__c,
                   BM_Min_Offer_Status__c,  BM_Min_Offer_Date_Time__c,  BM_Min_Offer_Comments__c,
                   MD_Min_Offer_Status__c,  MD_Min_Offer_Date_Time__c,  MD_Min_Offer_Comments__c,
                   Final_Minimum_Offer_Value_Approver__c, Is_Minimum_Offer_Value_Approved__c
            FROM   Quote
            WHERE  Id IN :allRelevantQuoteIds
        ]);

        Map<Id, List<QuoteLineItem>> quoteToQliMap = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem eachLine : quoteLineItems) {
            if (!quoteToQliMap.containsKey(eachLine.QuoteId)) {
                quoteToQliMap.put(eachLine.QuoteId, new List<QuoteLineItem>());
            }
            quoteToQliMap.get(eachLine.QuoteId).add(eachLine);
        }

        List<QuotationWrapper> quotations = new List<QuotationWrapper>();
        for (Id eachQuoteId : allRelevantQuoteIds) {
            Quote q = quoteMap.get(eachQuoteId);
            if (q == null) continue;

            List<QuoteLineItem> lineItems = quoteToQliMap.containsKey(eachQuoteId)
                ? quoteToQliMap.get(eachQuoteId)
                : new List<QuoteLineItem>();

            quotations.add(new QuotationWrapper(q, lineItems, currentUserId));
        }

        quotations.sort();
        return quotations;
    }

    /**
     * Mirrors applySkippedComments for QLIs.
     * Rows below the final approver get auto-approved if a comment is provided.
     * The final approver's row gets the status + comment from the wrapper.
     */
    private static void applySkippedWarrantyComments(Quote q, WarrantyApprovalWrapper wrapper) {
        Integer finalPos = wrapper.finalApproverHierarchyPosition;
        if (finalPos == null) return;

        if (finalPos > 1 && String.isNotBlank(wrapper.smWarrantyComments) &&
            wrapper.smId != wrapper.finalWarrantyApprover) {
            q.SM_Warranty_Status__c    = 'Approved';
            q.SM_Warranty_Comments__c  = wrapper.smWarrantyComments;
            q.SM_Warranty_Date_Time__c = DateTime.now();
        }
        if (finalPos > 2 && String.isNotBlank(wrapper.chWarrantyComments) &&
            wrapper.chId != wrapper.finalWarrantyApprover) {
            q.CH_Warranty_Status__c    = 'Approved';
            q.CH_Warranty_Comments__c  = wrapper.chWarrantyComments;
            q.CH_Warranty_Date_Time__c = DateTime.now();
        }
        if (finalPos > 3 && String.isNotBlank(wrapper.gsWarrantyComments) &&
            wrapper.gsId != wrapper.finalWarrantyApprover) {
            q.GS_Warranty_Status__c    = 'Approved';
            q.GS_Warranty_Comments__c  = wrapper.gsWarrantyComments;
            q.GS_Warranty_Date_Time__c = DateTime.now();
        }
        if (finalPos > 4 && String.isNotBlank(wrapper.bmWarrantyComments) &&
            wrapper.bmId != wrapper.finalWarrantyApprover) {
            q.BM_Warranty_Status__c    = 'Approved';
            q.BM_Warranty_Comments__c  = wrapper.bmWarrantyComments;
            q.BM_Warranty_Date_Time__c = DateTime.now();
        }

        if      (finalPos == 1) { q.SM_Warranty_Status__c = wrapper.smWarrantyStatus; q.SM_Warranty_Comments__c = wrapper.smWarrantyComments; q.SM_Warranty_Date_Time__c = DateTime.now(); }
        else if (finalPos == 2) { q.CH_Warranty_Status__c = wrapper.chWarrantyStatus; q.CH_Warranty_Comments__c = wrapper.chWarrantyComments; q.CH_Warranty_Date_Time__c = DateTime.now(); }
        else if (finalPos == 3) { q.GS_Warranty_Status__c = wrapper.gsWarrantyStatus; q.GS_Warranty_Comments__c = wrapper.gsWarrantyComments; q.GS_Warranty_Date_Time__c = DateTime.now(); }
        else if (finalPos == 4) { q.BM_Warranty_Status__c = wrapper.bmWarrantyStatus; q.BM_Warranty_Comments__c = wrapper.bmWarrantyComments; q.BM_Warranty_Date_Time__c = DateTime.now(); }
        else if (finalPos == 5) { q.MD_Warranty_Status__c = wrapper.mdWarrantyStatus; q.MD_Warranty_Comments__c = wrapper.mdWarrantyComments; q.MD_Warranty_Date_Time__c = DateTime.now(); }
    }

    private static void applySkippedTotalValueComments(Quote q, TotalValueApprovalWrapper wrapper) {
        Integer finalPos = wrapper.finalApproverHierarchyPosition;
        if (finalPos == null) return;

        if (finalPos > 1 && String.isNotBlank(wrapper.smValueComments) &&
            wrapper.smId != wrapper.finalTotalValueApprover) {
            q.SM_Value_Status__c    = 'Approved';
            q.SM_Value_Comments__c  = wrapper.smValueComments;
            q.SM_Value_Date_Time__c = DateTime.now();
        }
        if (finalPos > 2 && String.isNotBlank(wrapper.chValueComments) &&
            wrapper.chId != wrapper.finalTotalValueApprover) {
            q.CH_Value_Status__c    = 'Approved';
            q.CH_Value_Comments__c  = wrapper.chValueComments;
            q.CH_Value_Date_Time__c = DateTime.now();
        }
        if (finalPos > 3 && String.isNotBlank(wrapper.gsValueComments) &&
            wrapper.gsId != wrapper.finalTotalValueApprover) {
            q.GS_Value_Status__c    = 'Approved';
            q.GS_Value_Comments__c  = wrapper.gsValueComments;
            q.GS_Value_Date_Time__c = DateTime.now();
        }
        if (finalPos > 4 && String.isNotBlank(wrapper.bmValueComments) &&
            wrapper.bmId != wrapper.finalTotalValueApprover) {
            q.BM_Value_Status__c    = 'Approved';
            q.BM_Value_Comments__c  = wrapper.bmValueComments;
            q.BM_Value_Date_Time__c = DateTime.now();
        }

        if      (finalPos == 1) { q.SM_Value_Status__c = wrapper.smValueStatus; q.SM_Value_Comments__c = wrapper.smValueComments; q.SM_Value_Date_Time__c = DateTime.now(); }
        else if (finalPos == 2) { q.CH_Value_Status__c = wrapper.chValueStatus; q.CH_Value_Comments__c = wrapper.chValueComments; q.CH_Value_Date_Time__c = DateTime.now(); }
        else if (finalPos == 3) { q.GS_Value_Status__c = wrapper.gsValueStatus; q.GS_Value_Comments__c = wrapper.gsValueComments; q.GS_Value_Date_Time__c = DateTime.now(); }
        else if (finalPos == 4) { q.BM_Value_Status__c = wrapper.bmValueStatus; q.BM_Value_Comments__c = wrapper.bmValueComments; q.BM_Value_Date_Time__c = DateTime.now(); }
        else if (finalPos == 5) { q.MD_Value_Status__c = wrapper.mdValueStatus; q.MD_Value_Comments__c = wrapper.mdValueComments; q.MD_Value_Date_Time__c = DateTime.now(); }
    }

    private static void applySkippedValidityOfferComments(Quote q, ValidityOfferApprovalWrapper wrapper) {
        Integer finalPos = wrapper.finalApproverHierarchyPosition;
        if (finalPos == null) return;

        if (finalPos > 1 && String.isNotBlank(wrapper.smValidityOfferComments) &&
            wrapper.smId != wrapper.finalValidityOfferApprover) {
            q.SM_Validity_Offer_Status__c    = 'Approved';
            q.SM_Validity_Offer_Comments__c  = wrapper.smValidityOfferComments;
            q.SM_Validity_Offer_Date_Time__c = DateTime.now();
        }
        if (finalPos > 2 && String.isNotBlank(wrapper.chValidityOfferComments) &&
            wrapper.chId != wrapper.finalValidityOfferApprover) {
            q.CH_Validity_Offer_Status__c    = 'Approved';
            q.CH_Validity_Offer_Comments__c  = wrapper.chValidityOfferComments;
            q.CH_Validity_Offer_Date_Time__c = DateTime.now();
        }
        if (finalPos > 3 && String.isNotBlank(wrapper.gsValidityOfferComments) &&
            wrapper.gsId != wrapper.finalValidityOfferApprover) {
            q.GS_Validity_Offer_Status__c    = 'Approved';
            q.GS_Validity_Offer_Comments__c  = wrapper.gsValidityOfferComments;
            q.GS_Validity_Offer_Date_Time__c = DateTime.now();
        }
        if (finalPos > 4 && String.isNotBlank(wrapper.bmValidityOfferComments) &&
            wrapper.bmId != wrapper.finalValidityOfferApprover) {
            q.BM_Validity_Offer_Status__c    = 'Approved';
            q.BM_Validity_Offer_Comments__c  = wrapper.bmValidityOfferComments;
            q.BM_Validity_Offer_Date_Time__c = DateTime.now();
        }

        if      (finalPos == 1) { q.SM_Validity_Offer_Status__c = wrapper.smValidityOfferStatus; q.SM_Validity_Offer_Comments__c = wrapper.smValidityOfferComments; q.SM_Validity_Offer_Date_Time__c = DateTime.now(); }
        else if (finalPos == 2) { q.CH_Validity_Offer_Status__c = wrapper.chValidityOfferStatus; q.CH_Validity_Offer_Comments__c = wrapper.chValidityOfferComments; q.CH_Validity_Offer_Date_Time__c = DateTime.now(); }
        else if (finalPos == 3) { q.GS_Validity_Offer_Status__c = wrapper.gsValidityOfferStatus; q.GS_Validity_Offer_Comments__c = wrapper.gsValidityOfferComments; q.GS_Validity_Offer_Date_Time__c = DateTime.now(); }
        else if (finalPos == 4) { q.BM_Validity_Offer_Status__c = wrapper.bmValidityOfferStatus; q.BM_Validity_Offer_Comments__c = wrapper.bmValidityOfferComments; q.BM_Validity_Offer_Date_Time__c = DateTime.now(); }
        else if (finalPos == 5) { q.MD_Validity_Offer_Status__c = wrapper.mdValidityOfferStatus; q.MD_Validity_Offer_Comments__c = wrapper.mdValidityOfferComments; q.MD_Validity_Offer_Date_Time__c = DateTime.now(); }
    }

    private static void applySkippedMinimumOfferComments(Quote q, MinimumOfferApprovalWrapper wrapper) {
        Integer finalPos = wrapper.finalApproverHierarchyPosition;
        if (finalPos == null) return;

        // Min offer only has GS (3), BM (4), MD (5) levels
        if (finalPos > 3 && String.isNotBlank(wrapper.gsMinOfferComments) &&
            wrapper.gsId != wrapper.finalMinimumOfferValueApprover) {
            q.GS_Min_Offer_Status__c    = 'Approved';
            q.GS_Min_Offer_Comments__c  = wrapper.gsMinOfferComments;
            q.GS_Min_Offer_Date_Time__c = DateTime.now();
        }
        if (finalPos > 4 && String.isNotBlank(wrapper.bmMinOfferComments) &&
            wrapper.bmId != wrapper.finalMinimumOfferValueApprover) {
            q.BM_Min_Offer_Status__c    = 'Approved';
            q.BM_Min_Offer_Comments__c  = wrapper.bmMinOfferComments;
            q.BM_Min_Offer_Date_Time__c = DateTime.now();
        }

        if      (finalPos == 3) { q.GS_Min_Offer_Status__c = wrapper.gsMinOfferStatus; q.GS_Min_Offer_Comments__c = wrapper.gsMinOfferComments; q.GS_Min_Offer_Date_Time__c = DateTime.now(); }
        else if (finalPos == 4) { q.BM_Min_Offer_Status__c = wrapper.bmMinOfferStatus; q.BM_Min_Offer_Comments__c = wrapper.bmMinOfferComments; q.BM_Min_Offer_Date_Time__c = DateTime.now(); }
        else if (finalPos == 5) { q.MD_Min_Offer_Status__c = wrapper.mdMinOfferStatus; q.MD_Min_Offer_Comments__c = wrapper.mdMinOfferComments; q.MD_Min_Offer_Date_Time__c = DateTime.now(); }
    }

    // ── getWarrantyApprovals kept for backward-compatibility but the LWC ──
    // ── no longer needs to call it — getAllQuotations covers it now.      ──
    @AuraEnabled
    public static List<WarrantyApprovalWrapper> getWarrantyApprovals() {
        Id currentUserId = UserInfo.getUserId();

        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Warranty_Terms_Draft__c, Warranty_Terms__c,
                   Sales_Manager__c, Sales_Manager__r.Name,
                   Country_Continent_Sales_Head_LOB_Head__c, Country_Continent_Sales_Head_LOB_Head__r.Name,
                   Global_Sales_Head__c, Global_Sales_Head__r.Name,
                   Rotex_Board_Member__c, Rotex_Board_Member__r.Name,
                   Managing_Director_Country_Manager__c, Managing_Director_Country_Manager__r.Name,
                   SM_Warranty_Status__c, SM_Warranty_Date_Time__c, SM_Warranty_Comments__c,
                   CH_Warranty_Status__c, CH_Warranty_Date_Time__c, CH_Warranty_Comments__c,
                   GS_Warranty_Status__c, GS_Warranty_Date_Time__c, GS_Warranty_Comments__c,
                   BM_Warranty_Status__c, BM_Warranty_Date_Time__c, BM_Warranty_Comments__c,
                   MD_Warranty_Status__c, MD_Warranty_Date_Time__c, MD_Warranty_Comments__c,
                   Final_Warranty_Terms_Approver__c
            FROM   Quote
            WHERE  (
                       Sales_Manager__c                         = :currentUserId OR
                       Country_Continent_Sales_Head_LOB_Head__c = :currentUserId OR
                       Global_Sales_Head__c                     = :currentUserId OR
                       Rotex_Board_Member__c                    = :currentUserId OR
                       Managing_Director_Country_Manager__c     = :currentUserId
                   )
                   AND Warranty_Terms_Draft__c != null
                   AND Warranty_Terms_Draft__c != '12 Months from date of supply'
        ];

        List<WarrantyApprovalWrapper> warrantyApprovals = new List<WarrantyApprovalWrapper>();
        for (Quote q : quotes) {
            warrantyApprovals.add(new WarrantyApprovalWrapper(q));
        }
        return warrantyApprovals;
    }

    /**
     * @description: Submits warranty approval for a single quote with auto-approve logic.
     * If user is not final approver and only provided comments, auto-approve.
     */
    @AuraEnabled
    public static String submitWarrantyApprovalSingle(String warrantyApprovalJson) {
        WarrantyApprovalWrapper wrapper = (WarrantyApprovalWrapper) JSON.deserialize(
            warrantyApprovalJson, WarrantyApprovalWrapper.class
        );

        if (!wrapper.updated) {
            return 'No changes to submit';
        }

        Quote existingQuote = getQuoteForApprovalValidation((Id) wrapper.quoteId);
        Quote q = new Quote(Id = wrapper.quoteId);

        if (wrapper.skipSoaRestrictions == true &&
            (wrapper.isHigherHierarchy == true || wrapper.isFinalApproverWithPendingLower == true)) {
            applySkippedWarrantyComments(q, wrapper);
            update q;
            return 'Success';
        }

        Boolean hasChanges = false;
        Id currentUserId   = UserInfo.getUserId();
        Id finalApproverId = existingQuote.Final_Warranty_Terms_Approver__c;
        System.debug('submitWarrantyApprovalSingle finalApproverId ==> '+ finalApproverId);
        Integer finalApproverPosition = getHierarchyPos(existingQuote, finalApproverId);
        System.debug('submitWarrantyApprovalSingle finalApproverPosition ==> '+ finalApproverPosition);
        validateWarrantyTermsForApprover(wrapper.warrantyTermsDraft, finalApproverPosition);
        if (wrapper.warrantyTermsDraft != wrapper.originalWarrantyTermsDraft) {
            if (currentUserId != finalApproverId) {
                throw new AuraHandledException('Only the final warranty approver can change Requested Warranty Terms.');
            }
            q.Warranty_Terms_Draft__c = wrapper.warrantyTermsDraft;
            hasChanges = true;
        }

        // SM
        if (wrapper.smWarrantyStatus != wrapper.originalSmWarrantyStatus ||
            wrapper.smWarrantyComments != wrapper.originalSmWarrantyComments) {
            if (wrapper.isSmCurrentUser) {
                if (wrapper.smId != finalApproverId &&
                    wrapper.smWarrantyStatus == wrapper.originalSmWarrantyStatus &&
                    String.isNotBlank(wrapper.smWarrantyComments)) {
                    q.SM_Warranty_Status__c = 'Approved';
                } else {
                    q.SM_Warranty_Status__c = wrapper.smWarrantyStatus;
                }
                q.SM_Warranty_Comments__c  = wrapper.smWarrantyComments;
                q.SM_Warranty_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }
        // CH
        if (wrapper.chWarrantyStatus != wrapper.originalChWarrantyStatus ||
            wrapper.chWarrantyComments != wrapper.originalChWarrantyComments) {
            if (wrapper.isChCurrentUser) {
                if (wrapper.chId != finalApproverId &&
                    wrapper.chWarrantyStatus == wrapper.originalChWarrantyStatus &&
                    String.isNotBlank(wrapper.chWarrantyComments)) {
                    q.CH_Warranty_Status__c = 'Approved';
                } else {
                    q.CH_Warranty_Status__c = wrapper.chWarrantyStatus;
                }
                q.CH_Warranty_Comments__c  = wrapper.chWarrantyComments;
                q.CH_Warranty_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }
        // GS
        if (wrapper.gsWarrantyStatus != wrapper.originalGsWarrantyStatus ||
            wrapper.gsWarrantyComments != wrapper.originalGsWarrantyComments) {
            if (wrapper.isGsCurrentUser) {
                if (wrapper.gsId != finalApproverId &&
                    wrapper.gsWarrantyStatus == wrapper.originalGsWarrantyStatus &&
                    String.isNotBlank(wrapper.gsWarrantyComments)) {
                    q.GS_Warranty_Status__c = 'Approved';
                } else {
                    q.GS_Warranty_Status__c = wrapper.gsWarrantyStatus;
                }
                q.GS_Warranty_Comments__c  = wrapper.gsWarrantyComments;
                q.GS_Warranty_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }
        // BM
        if (wrapper.bmWarrantyStatus != wrapper.originalBmWarrantyStatus ||
            wrapper.bmWarrantyComments != wrapper.originalBmWarrantyComments) {
            if (wrapper.isBmCurrentUser) {
                if (wrapper.bmId != finalApproverId &&
                    wrapper.bmWarrantyStatus == wrapper.originalBmWarrantyStatus &&
                    String.isNotBlank(wrapper.bmWarrantyComments)) {
                    q.BM_Warranty_Status__c = 'Approved';
                } else {
                    q.BM_Warranty_Status__c = wrapper.bmWarrantyStatus;
                }
                q.BM_Warranty_Comments__c  = wrapper.bmWarrantyComments;
                q.BM_Warranty_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }
        // MD
        if (wrapper.mdWarrantyStatus != wrapper.originalMdWarrantyStatus ||
            wrapper.mdWarrantyComments != wrapper.originalMdWarrantyComments) {
            if (wrapper.isMdCurrentUser) {
                if (wrapper.mdId != finalApproverId &&
                    wrapper.mdWarrantyStatus == wrapper.originalMdWarrantyStatus &&
                    String.isNotBlank(wrapper.mdWarrantyComments)) {
                    q.MD_Warranty_Status__c = 'Approved';
                } else {
                    q.MD_Warranty_Status__c = wrapper.mdWarrantyStatus;
                }
                q.MD_Warranty_Comments__c  = wrapper.mdWarrantyComments;
                q.MD_Warranty_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }

        if (hasChanges) {
            updateWarrantyApprovalQuote(q);
        }
        return 'Success';
    }

    /**
     * @description: Submits validity of offer approval for a single quote.
     * No Skip SOA logic — validity of offer does not use the SOA toggle.
     */
    @AuraEnabled
    public static String submitValidityOfferApprovalSingle(String validityOfferApprovalJson) {
        ValidityOfferApprovalWrapper wrapper = (ValidityOfferApprovalWrapper) JSON.deserialize(
            validityOfferApprovalJson, ValidityOfferApprovalWrapper.class
        );

        if (!wrapper.updated) {
            return 'No changes to submit';
        }

        // ── Skip SOA: higher hierarchy or final-approver-with-pending-lower path ──
        if (wrapper.skipSoaRestrictions == true &&
            (wrapper.isHigherHierarchy == true || wrapper.isFinalApproverWithPendingLower == true)) {
            Quote q = new Quote(Id = wrapper.quoteId);
            applySkippedValidityOfferComments(q, wrapper);
            updateValidityApprovalQuote(q);
            return 'Success';
        }

        Quote existingQuote = getQuoteForApprovalValidation((Id) wrapper.quoteId);
        Quote q = new Quote(Id = wrapper.quoteId);
        Boolean hasChanges = false;
        Id currentUserId = UserInfo.getUserId();
        Id finalApproverId = existingQuote.Final_Validity_Offer_Approver__c;
        Integer finalApproverPosition = getValidityOfferHierarchyPos(existingQuote, finalApproverId);
        validateValidityOfferForApprover(wrapper.requestedValidityOfOffer, finalApproverPosition);
        if (wrapper.requestedValidityOfOffer != wrapper.originalRequestedValidityOfOffer) {
            if (currentUserId != finalApproverId) {
                throw new AuraHandledException('Only the final validity approver can change Requested Validity of Offer.');
            }
            q.Requested_Validity_Of_Offer__c = wrapper.requestedValidityOfOffer;
            hasChanges = true;
        }

        // SM
        if (wrapper.smValidityOfferStatus != wrapper.originalSmValidityOfferStatus ||
            wrapper.smValidityOfferComments != wrapper.originalSmValidityOfferComments) {
            if (wrapper.isSmCurrentUser) {
                if (wrapper.smId != finalApproverId &&
                    wrapper.smValidityOfferStatus == wrapper.originalSmValidityOfferStatus &&
                    String.isNotBlank(wrapper.smValidityOfferComments)) {
                    q.SM_Validity_Offer_Status__c = 'Approved';
                } else {
                    q.SM_Validity_Offer_Status__c = wrapper.smValidityOfferStatus;
                }
                q.SM_Validity_Offer_Comments__c  = wrapper.smValidityOfferComments;
                q.SM_Validity_Offer_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }
        // CH
        if (wrapper.chValidityOfferStatus != wrapper.originalChValidityOfferStatus ||
            wrapper.chValidityOfferComments != wrapper.originalChValidityOfferComments) {
            if (wrapper.isChCurrentUser) {
                if (wrapper.chId != finalApproverId &&
                    wrapper.chValidityOfferStatus == wrapper.originalChValidityOfferStatus &&
                    String.isNotBlank(wrapper.chValidityOfferComments)) {
                    q.CH_Validity_Offer_Status__c = 'Approved';
                } else {
                    q.CH_Validity_Offer_Status__c = wrapper.chValidityOfferStatus;
                }
                q.CH_Validity_Offer_Comments__c  = wrapper.chValidityOfferComments;
                q.CH_Validity_Offer_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }
        // GS
        if (wrapper.gsValidityOfferStatus != wrapper.originalGsValidityOfferStatus ||
            wrapper.gsValidityOfferComments != wrapper.originalGsValidityOfferComments) {
            if (wrapper.isGsCurrentUser) {
                if (wrapper.gsId != finalApproverId &&
                    wrapper.gsValidityOfferStatus == wrapper.originalGsValidityOfferStatus &&
                    String.isNotBlank(wrapper.gsValidityOfferComments)) {
                    q.GS_Validity_Offer_Status__c = 'Approved';
                } else {
                    q.GS_Validity_Offer_Status__c = wrapper.gsValidityOfferStatus;
                }
                q.GS_Validity_Offer_Comments__c  = wrapper.gsValidityOfferComments;
                q.GS_Validity_Offer_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }
        // BM
        if (wrapper.bmValidityOfferStatus != wrapper.originalBmValidityOfferStatus ||
            wrapper.bmValidityOfferComments != wrapper.originalBmValidityOfferComments) {
            if (wrapper.isBmCurrentUser) {
                if (wrapper.bmId != finalApproverId &&
                    wrapper.bmValidityOfferStatus == wrapper.originalBmValidityOfferStatus &&
                    String.isNotBlank(wrapper.bmValidityOfferComments)) {
                    q.BM_Validity_Offer_Status__c = 'Approved';
                } else {
                    q.BM_Validity_Offer_Status__c = wrapper.bmValidityOfferStatus;
                }
                q.BM_Validity_Offer_Comments__c  = wrapper.bmValidityOfferComments;
                q.BM_Validity_Offer_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }
        // MD
        if (wrapper.mdValidityOfferStatus != wrapper.originalMdValidityOfferStatus ||
            wrapper.mdValidityOfferComments != wrapper.originalMdValidityOfferComments) {
            if (wrapper.isMdCurrentUser) {
                if (wrapper.mdId != finalApproverId &&
                    wrapper.mdValidityOfferStatus == wrapper.originalMdValidityOfferStatus &&
                    String.isNotBlank(wrapper.mdValidityOfferComments)) {
                    q.MD_Validity_Offer_Status__c = 'Approved';
                } else {
                    q.MD_Validity_Offer_Status__c = wrapper.mdValidityOfferStatus;
                }
                q.MD_Validity_Offer_Comments__c  = wrapper.mdValidityOfferComments;
                q.MD_Validity_Offer_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }

        if (hasChanges) {
            updateValidityApprovalQuote(q);
        }
        return 'Success';
    }

    @AuraEnabled
    public static String submitTotalValueApprovalSingle(String totalValueApprovalJson) {
        TotalValueApprovalWrapper wrapper = (TotalValueApprovalWrapper) JSON.deserialize(
            totalValueApprovalJson, TotalValueApprovalWrapper.class
        );

        if (!wrapper.updated) {
            return 'No changes to submit';
        }

        // ── Skip SOA: higher hierarchy or final-approver-with-pending-lower path ──
        if (wrapper.skipSoaRestrictions == true &&
            (wrapper.isHigherHierarchy == true || wrapper.isFinalApproverWithPendingLower == true)) {
            Quote q = new Quote(Id = wrapper.quoteId);
            applySkippedTotalValueComments(q, wrapper);
            update q;
            return 'Success';
        }

        Quote q = new Quote(Id = wrapper.quoteId);
        Boolean hasChanges = false;
        Id finalApproverId = wrapper.finalTotalValueApprover;

        if (wrapper.smValueStatus != wrapper.originalSmValueStatus ||
            wrapper.smValueComments != wrapper.originalSmValueComments) {
            if (wrapper.isSmCurrentUser) {
                if (wrapper.smId != finalApproverId &&
                    wrapper.smValueStatus == wrapper.originalSmValueStatus &&
                    String.isNotBlank(wrapper.smValueComments)) {
                    q.SM_Value_Status__c = 'Approved';
                } else {
                    q.SM_Value_Status__c = wrapper.smValueStatus;
                }
                q.SM_Value_Comments__c  = wrapper.smValueComments;
                q.SM_Value_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }

        if (wrapper.chValueStatus != wrapper.originalChValueStatus ||
            wrapper.chValueComments != wrapper.originalChValueComments) {
            if (wrapper.isChCurrentUser) {
                if (wrapper.chId != finalApproverId &&
                    wrapper.chValueStatus == wrapper.originalChValueStatus &&
                    String.isNotBlank(wrapper.chValueComments)) {
                    q.CH_Value_Status__c = 'Approved';
                } else {
                    q.CH_Value_Status__c = wrapper.chValueStatus;
                }
                q.CH_Value_Comments__c  = wrapper.chValueComments;
                q.CH_Value_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }

        if (wrapper.gsValueStatus != wrapper.originalGsValueStatus ||
            wrapper.gsValueComments != wrapper.originalGsValueComments) {
            if (wrapper.isGsCurrentUser) {
                if (wrapper.gsId != finalApproverId &&
                    wrapper.gsValueStatus == wrapper.originalGsValueStatus &&
                    String.isNotBlank(wrapper.gsValueComments)) {
                    q.GS_Value_Status__c = 'Approved';
                } else {
                    q.GS_Value_Status__c = wrapper.gsValueStatus;
                }
                q.GS_Value_Comments__c  = wrapper.gsValueComments;
                q.GS_Value_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }

        if (wrapper.bmValueStatus != wrapper.originalBmValueStatus ||
            wrapper.bmValueComments != wrapper.originalBmValueComments) {
            if (wrapper.isBmCurrentUser) {
                if (wrapper.bmId != finalApproverId &&
                    wrapper.bmValueStatus == wrapper.originalBmValueStatus &&
                    String.isNotBlank(wrapper.bmValueComments)) {
                    q.BM_Value_Status__c = 'Approved';
                } else {
                    q.BM_Value_Status__c = wrapper.bmValueStatus;
                }
                q.BM_Value_Comments__c  = wrapper.bmValueComments;
                q.BM_Value_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }

        if (wrapper.mdValueStatus != wrapper.originalMdValueStatus ||
            wrapper.mdValueComments != wrapper.originalMdValueComments) {
            if (wrapper.isMdCurrentUser) {
                if (wrapper.mdId != finalApproverId &&
                    wrapper.mdValueStatus == wrapper.originalMdValueStatus &&
                    String.isNotBlank(wrapper.mdValueComments)) {
                    q.MD_Value_Status__c = 'Approved';
                } else {
                    q.MD_Value_Status__c = wrapper.mdValueStatus;
                }
                q.MD_Value_Comments__c  = wrapper.mdValueComments;
                q.MD_Value_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }

        if (hasChanges) {
            update q;
        }
        return 'Success';
    }

    @AuraEnabled
    public static String submitMinimumOfferApprovalSingle(String minimumOfferApprovalJson) {
        MinimumOfferApprovalWrapper wrapper = (MinimumOfferApprovalWrapper) JSON.deserialize(
            minimumOfferApprovalJson, MinimumOfferApprovalWrapper.class
        );

        if (!wrapper.updated) {
            return 'No changes to submit';
        }

        // ── Skip SOA: higher hierarchy or final-approver-with-pending-lower path ──
        if (wrapper.skipSoaRestrictions == true &&
            (wrapper.isHigherHierarchy == true || wrapper.isFinalApproverWithPendingLower == true)) {
            Quote q = new Quote(Id = wrapper.quoteId);
            applySkippedMinimumOfferComments(q, wrapper);
            update q;
            return 'Success';
        }

        Quote q = new Quote(Id = wrapper.quoteId);
        Boolean hasChanges = false;
        Id finalApproverId = wrapper.finalMinimumOfferValueApprover;

        if (wrapper.gsMinOfferStatus != wrapper.originalGsMinOfferStatus ||
            wrapper.gsMinOfferComments != wrapper.originalGsMinOfferComments) {
            if (wrapper.isGsCurrentUser) {
                if (wrapper.gsId != finalApproverId &&
                    wrapper.gsMinOfferStatus == wrapper.originalGsMinOfferStatus &&
                    String.isNotBlank(wrapper.gsMinOfferComments)) {
                    q.GS_Min_Offer_Status__c = 'Approved';
                } else {
                    q.GS_Min_Offer_Status__c = wrapper.gsMinOfferStatus;
                }
                q.GS_Min_Offer_Comments__c  = wrapper.gsMinOfferComments;
                q.GS_Min_Offer_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }

        if (wrapper.bmMinOfferStatus != wrapper.originalBmMinOfferStatus ||
            wrapper.bmMinOfferComments != wrapper.originalBmMinOfferComments) {
            if (wrapper.isBmCurrentUser) {
                if (wrapper.bmId != finalApproverId &&
                    wrapper.bmMinOfferStatus == wrapper.originalBmMinOfferStatus &&
                    String.isNotBlank(wrapper.bmMinOfferComments)) {
                    q.BM_Min_Offer_Status__c = 'Approved';
                } else {
                    q.BM_Min_Offer_Status__c = wrapper.bmMinOfferStatus;
                }
                q.BM_Min_Offer_Comments__c  = wrapper.bmMinOfferComments;
                q.BM_Min_Offer_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }

        if (wrapper.mdMinOfferStatus != wrapper.originalMdMinOfferStatus ||
            wrapper.mdMinOfferComments != wrapper.originalMdMinOfferComments) {
            if (wrapper.isMdCurrentUser) {
                if (wrapper.mdId != finalApproverId &&
                    wrapper.mdMinOfferStatus == wrapper.originalMdMinOfferStatus &&
                    String.isNotBlank(wrapper.mdMinOfferComments)) {
                    q.MD_Min_Offer_Status__c = 'Approved';
                } else {
                    q.MD_Min_Offer_Status__c = wrapper.mdMinOfferStatus;
                }
                q.MD_Min_Offer_Comments__c  = wrapper.mdMinOfferComments;
                q.MD_Min_Offer_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
        }

        if (hasChanges) {
            update q;
        }
        return 'Success';
    }

    /**
     * @description: Updates warranty approval status and comments.
     */
    @AuraEnabled
    public static String updateWarrantyApproval(String warrantyApprovalsJson) {
        List<WarrantyApprovalWrapper> warrantyApprovals =
            (List<WarrantyApprovalWrapper>) JSON.deserialize(
                warrantyApprovalsJson, List<WarrantyApprovalWrapper>.class
            );

        List<Quote> quotesToUpdate = new List<Quote>();

        for (WarrantyApprovalWrapper wrapper : warrantyApprovals) {
            if (!wrapper.updated) continue;

            Quote q = new Quote(Id = wrapper.quoteId);
            Boolean hasChanges = false;

            if (wrapper.smWarrantyStatus != wrapper.originalSmWarrantyStatus ||
                wrapper.smWarrantyComments != wrapper.originalSmWarrantyComments) {
                q.SM_Warranty_Status__c   = wrapper.smWarrantyStatus;
                q.SM_Warranty_Comments__c = wrapper.smWarrantyComments;
                q.SM_Warranty_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
            if (wrapper.chWarrantyStatus != wrapper.originalChWarrantyStatus ||
                wrapper.chWarrantyComments != wrapper.originalChWarrantyComments) {
                q.CH_Warranty_Status__c   = wrapper.chWarrantyStatus;
                q.CH_Warranty_Comments__c = wrapper.chWarrantyComments;
                q.CH_Warranty_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
            if (wrapper.gsWarrantyStatus != wrapper.originalGsWarrantyStatus ||
                wrapper.gsWarrantyComments != wrapper.originalGsWarrantyComments) {
                q.GS_Warranty_Status__c   = wrapper.gsWarrantyStatus;
                q.GS_Warranty_Comments__c = wrapper.gsWarrantyComments;
                q.GS_Warranty_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
            if (wrapper.bmWarrantyStatus != wrapper.originalBmWarrantyStatus ||
                wrapper.bmWarrantyComments != wrapper.originalBmWarrantyComments) {
                q.BM_Warranty_Status__c   = wrapper.bmWarrantyStatus;
                q.BM_Warranty_Comments__c = wrapper.bmWarrantyComments;
                q.BM_Warranty_Date_Time__c = DateTime.now();
                hasChanges = true;
            }
            if (wrapper.mdWarrantyStatus != wrapper.originalMdWarrantyStatus ||
                wrapper.mdWarrantyComments != wrapper.originalMdWarrantyComments) {
                q.MD_Warranty_Status__c   = wrapper.mdWarrantyStatus;
                q.MD_Warranty_Comments__c = wrapper.mdWarrantyComments;
                q.MD_Warranty_Date_Time__c = DateTime.now();
                hasChanges = true;
            }

            if (hasChanges) {
                quotesToUpdate.add(q);
            }
        }

        if (!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;
        }
        return 'Success';
    }

    /**
     * @description: Updates approval status and comments of QLIs.
     */
    @AuraEnabled
    public static String submitUnifiedQuoteApprovals(
        String quotationListStringObject,
        String warrantyApprovalJson,
        String validityOfferApprovalJson,
        String totalValueApprovalJson,
        String minimumOfferApprovalJson
    ) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (String.isNotBlank(quotationListStringObject)) {
                assertSuccessfulSubmission(
                    'Discount',
                    updateQuoteLineItem(quotationListStringObject)
                );
            }
            if (String.isNotBlank(warrantyApprovalJson)) {
                assertSuccessfulSubmission(
                    'Warranty Terms',
                    submitWarrantyApprovalSingle(warrantyApprovalJson)
                );
            }
            if (String.isNotBlank(totalValueApprovalJson)) {
                assertSuccessfulSubmission(
                    'Total Value',
                    submitTotalValueApprovalSingle(totalValueApprovalJson)
                );
            }
            if (String.isNotBlank(minimumOfferApprovalJson)) {
                assertSuccessfulSubmission(
                    'Min Offer Value',
                    submitMinimumOfferApprovalSingle(minimumOfferApprovalJson)
                );
            }
            if (String.isNotBlank(validityOfferApprovalJson)) {
                assertSuccessfulSubmission(
                    'Validity Offer',
                    submitValidityOfferApprovalSingle(validityOfferApprovalJson)
                );
            }
            return 'Success';
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void assertSuccessfulSubmission(String label, String result) {
        if (result != 'Success') {
            throw new AuraHandledException(label + ' submission failed: ' + result);
        }
    }

    private static Quote getQuoteForApprovalValidation(Id quoteId) {
        return [
            SELECT Id,
                   Sales_Manager__c,
                   Country_Continent_Sales_Head_LOB_Head__c,
                   Global_Sales_Head__c,
                   Rotex_Board_Member__c,
                   Managing_Director_Country_Manager__c,
                   Final_Warranty_Terms_Approver__c,
                   Final_Validity_Offer_Approver__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
    }

    private static void updateWarrantyApprovalQuote(Quote q) {
        QuoteWarrantyApprovalHandler.bypassDraftApprovalReset = true;
        try {
            update q;
        } finally {
            QuoteWarrantyApprovalHandler.bypassDraftApprovalReset = false;
        }
    }

    private static void updateValidityApprovalQuote(Quote q) {
        QuoteValidityOfferApprovalHandler.bypassRequestedValidityApprovalReset = true;
        try {
            update q;
        } finally {
            QuoteValidityOfferApprovalHandler.bypassRequestedValidityApprovalReset = false;
        }
    }

    @AuraEnabled
    public static String updateQuoteLineItem(String quotationListStringObject) {

        List<QuotationWrapper> quotations = parseHeaderAndLine(quotationListStringObject);

        List<QuoteLineItem> quotationLineItemsToBeUpdated = new List<QuoteLineItem>();
        Set<Id> updatedQuoteLineItemIds = new Set<Id>();

        // ── SOA Matrix max-discount pre-load ──────────────────────────────
        Map<String, Decimal> profileMaxDiscountMap = new Map<String, Decimal>();

        for (SOA_Matrix__c m : [
            SELECT SOA_Profile__c, Max_Discount__c
            FROM SOA_Matrix__c
            WHERE Max_Discount__c != null
        ]) {
            String profile = m.SOA_Profile__c != null ? m.SOA_Profile__c.trim() : null;

            if (profile == null) continue;

            Decimal existingMax = profileMaxDiscountMap.get(profile);

            if (existingMax == null || m.Max_Discount__c > existingMax) {
                profileMaxDiscountMap.put(profile, m.Max_Discount__c);
            }
        }

        // kept only so remaining code compiles if referenced elsewhere
        Map<Id, User> finalApproverUserMap = new Map<Id, User>();
        // ─────────────────────────────────────────────────────────────────

        for (QuotationWrapper eachQuotation : quotations) {
            if (eachQuotation.updated &&
                eachQuotation.quoteLineItems != null &&
                !eachQuotation.quoteLineItems.isEmpty()) {
                for (QuotationLineItemWrapper eachQli : eachQuotation.quoteLineItems) {
                    if (eachQli.updated && String.isNotBlank(eachQli.quoteLineItemId)) {
                        updatedQuoteLineItemIds.add((Id) eachQli.quoteLineItemId);
                    }
                }
            }
        }

        Map<Id, QuoteLineItem> existingQliMap = new Map<Id, QuoteLineItem>();
        if (!updatedQuoteLineItemIds.isEmpty()) {
            existingQliMap = new Map<Id, QuoteLineItem>([
                SELECT Id, Final_Discount_Approver__c, Sales_Rep_Status__c, Sales_Manager_Status__c,
                       Country_Continent_Sales_H_LOB_Status__c, Global_Sales_Head_Status__c,
                       Rotex_Board_Member_Status__c, Managing_Director_Status__c,
                       Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                       Global_Sales_Head__c, Rotex_Board_Member__c,
                       Managing_Director_Country_Manage__c,
                       Sales_Manager_Comments__c, Country_Continent_Sales_LOB_Comments__c,
                       Global_Sales_Head_Comments__c, Rotex_Board_Member_Comments__c,
                       Managing_Director_Comments__c, Discount_to_be_offered__c, Discount_as_per_SAP__c
                FROM   QuoteLineItem
                WHERE  Id IN :updatedQuoteLineItemIds
            ]);
        }

        Set<Quote> quotesToUpdate = new Set<Quote>();

        for (QuotationWrapper eachQuotation : quotations) {
            if (eachQuotation.updated &&
                eachQuotation.quoteLineItems != null &&
                !eachQuotation.quoteLineItems.isEmpty()) {

                for (QuotationLineItemWrapper eachQli : eachQuotation.quoteLineItems) {
                    if (!eachQli.updated) continue;

                    QuoteLineItem existing = existingQliMap.get((Id) eachQli.quoteLineItemId);
                    String existingStageStatus    = getStageStatus(existing, eachQli.currentStageField);
                    Boolean statusChanged          = eachQli.approvalStatus != existingStageStatus;
                    Boolean commentChanged         = didCurrentStageCommentChange(existing, eachQli);
                    Boolean canSubmitAsFinal       = eachQli.isFinalDiscountApprover == true ||
                                                     canSkipToPreviousFinalApprover(existing, eachQli);
                    Boolean discountChanged        = canSubmitAsFinal &&
                                                     eachQli.d2 != null &&
                                                     (existing == null || eachQli.d2 != existing.Discount_to_be_offered__c);
                    Boolean shouldUpdate           = statusChanged || commentChanged || discountChanged;

                    // ── Validate discount does not exceed SOA Matrix max ──
                    if (canSubmitAsFinal && eachQli.d2 != null) {
                        Decimal sapDiscount = existing != null ? existing.Discount_as_per_SAP__c : eachQli.d1;
                        if (sapDiscount != null && eachQli.d2 < sapDiscount) {
                            throw new AuraHandledException(
                                'Discount of ' + eachQli.d2 +
                                '% cannot be less than the Discount as per SAP of ' + sapDiscount + '%'
                            );
                        }

                        Integer finalApproverPos =
                            getApproverIndex(existing, (Id) eachQli.finalDiscountApproverId);

                        String soaProfile = getSoaProfileByPosition(finalApproverPos);

                        Decimal maxDiscount = null;

                        if (String.isNotBlank(soaProfile)) {

                            maxDiscount = profileMaxDiscountMap.get(soaProfile);

                            if (maxDiscount == null) {
                                for (String key : profileMaxDiscountMap.keySet()) {
                                    if (key.equalsIgnoreCase(soaProfile)) {
                                        maxDiscount = profileMaxDiscountMap.get(key);
                                        break;
                                    }
                                }
                            }
                        }

                        if (maxDiscount != null && eachQli.d2 > maxDiscount) {
                            throw new AuraHandledException(
                                'Discount of ' + eachQli.d2 +
                                '% exceeds the maximum discount allowed as per the SOA Matrix'
                            );
                        }
                    }
                    // ─────────────────────────────────────────────────────
                    // ─────────────────────────────────────────────────────

                    if (statusChanged && (existing == null || !canSubmitAsFinal)) {
                        throw new AuraHandledException(
                            'Only the Final Discount Approver can change the approval status of a Quote Line Item.'
                        );
                    }

                    QuoteLineItem qli = new QuoteLineItem();
                    qli.Id = eachQli.quoteLineItemId;
                    applySkippedComments(qli, existing, eachQli);

                    if (discountChanged) {
                        qli.Discount_to_be_offered__c = eachQli.d2;
                    }

                    if (shouldUpdate && eachQli.currentStageField == 'Sales_Rep_Status__c') {
                        qli.Sales_Rep_Status__c  = canSubmitAsFinal ? eachQli.approvalStatus : 'Approved';
                        qli.Approval_Comments__c = eachQli.approvalComments;
                    }
                    if (shouldUpdate && eachQli.currentStageField == 'Sales_Manager_Status__c') {
                        if (canSubmitAsFinal && statusChanged) qli.Sales_Manager_Status__c = eachQli.approvalStatus;
                        else if (!canSubmitAsFinal)            qli.Sales_Manager_Status__c = 'Approved';
                        qli.Sales_Manager_Comments__c  = eachQli.Sales_Manager_Comments;
                        qli.Sales_Manager_Date_Time__c = DateTime.now();
                    }
                    if (shouldUpdate && eachQli.currentStageField == 'Country_Continent_Sales_H_LOB_Status__c') {
                        if (canSubmitAsFinal && statusChanged) qli.Country_Continent_Sales_H_LOB_Status__c = eachQli.approvalStatus;
                        else if (!canSubmitAsFinal)            qli.Country_Continent_Sales_H_LOB_Status__c = 'Approved';
                        qli.Country_Continent_Sales_LOB_Comments__c = eachQli.Country_Continent_Sales_LOB_Comments;
                        qli.Country_Head_Date_Time__c = DateTime.now();
                    }
                    if (shouldUpdate && eachQli.currentStageField == 'Global_Sales_Head_Status__c') {
                        if (canSubmitAsFinal && statusChanged) qli.Global_Sales_Head_Status__c = eachQli.approvalStatus;
                        else if (!canSubmitAsFinal)            qli.Global_Sales_Head_Status__c = 'Approved';
                        qli.Global_Sales_Head_Comments__c  = eachQli.Global_Sales_Head_Comments;
                        qli.Global_Sales_Head_Date_Time__c = DateTime.now();
                    }
                    if (shouldUpdate && eachQli.currentStageField == 'Rotex_Board_Member_Status__c') {
                        if (canSubmitAsFinal && statusChanged) qli.Rotex_Board_Member_Status__c = eachQli.approvalStatus;
                        else if (!canSubmitAsFinal)            qli.Rotex_Board_Member_Status__c = 'Approved';
                        qli.Rotex_Board_Member_Comments__c  = eachQli.Rotex_Board_Member_Comments;
                        qli.Rotex_Board_Member_Date_Time__c = DateTime.now();
                    }
                    if (shouldUpdate && eachQli.currentStageField == 'Managing_Director_Status__c') {
                        if (canSubmitAsFinal && statusChanged) qli.Managing_Director_Status__c = eachQli.approvalStatus;
                        else if (!canSubmitAsFinal)            qli.Managing_Director_Status__c = 'Approved';
                        qli.Managing_Director_Comments__c  = eachQli.Managing_Director_Comments;
                        qli.Managing_Director_Date_Time__c = DateTime.now();
                    }

                    if (canSubmitAsFinal) {
                        Quote quote = new Quote();
                        quote.Id      = eachQuotation.quoteId;
                        quote.OwnerId = eachQuotation.accountOwner;
                        quotesToUpdate.add(quote);
                    }

                    quotationLineItemsToBeUpdated.add(qli);
                }
            }
        }

        UPDATE quotationLineItemsToBeUpdated;
        UPDATE new List<Quote>(quotesToUpdate);

        for (QuotationWrapper eachQuotation : quotations) {
            SalesPriceApprovalForQuotation ctrl = new SalesPriceApprovalForQuotation(eachQuotation);
            ctrl.sendEmailNotification();
        }

        return 'Success';
    }

    // ── Email / Notification helpers ──────────────────────────────────────

    private void sendEmailNotification() {
        Boolean isApproved = false;
        Boolean isRejected = false;
        for (QuotationLineItemWrapper item : quotation.quoteLineItems) {
            if (item.approvalStatus == 'Approved') isApproved = true;
            else if (item.approvalStatus == 'Rejected') isRejected = true;
        }
        if (isApproved) { this.sendEmail(this.quotation, 'Approved'); this.sendCustomNotification(this.quotation, 'Approved'); }
        if (isRejected) { this.sendEmail(this.quotation, 'Rejected'); this.sendCustomNotification(this.quotation, 'Rejected'); }
    }

    private void sendEmail(QuotationWrapper quotation, String status) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[]{ quotation.quoteOwnerEmail });
        email.setSubject('Sales Price ' + status + ' - ' + quotation.quoteName);
        email.setWhatId(quotation.quoteId);
        email.setSaveAsActivity(true);

        String approvalPageUrl = URL.getOrgDomainUrl().toExternalForm()+ '/lightning/n/Quote_Discount_Approval';
        String body = 'Dear ' + quotation.quoteOwnerName + ',<br/><br/>';
        body += 'The Sales Price has been ' + status.toLowerCase() + ' for the following Quote:<br/><br/>';
        body += 'Quote Name: ' + quotation.quoteName + '<br/>';
        body += 'Quote Approval Page: <a href="' + approvalPageUrl + '">click here</a><br/><br/>';
        body += 'Below are the product details:<br/><br/>';
        body += '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse:collapse;width:100%;">';
        body += '<thead><tr style="background-color:#f2f2f2;"><th>Product Name</th><th>List Price</th><th>Sales Price</th><th>Approval Status</th></tr></thead><tbody>';

        for (QuotationLineItemWrapper item : quotation.quoteLineItems) {
            if (item.approvalStatus == status && item.updated) {
                body += '<tr>';
                body += '<td>' + item.productName + '</td>';
                body += '<td>' + (item.listPrice  != null ? String.valueOf(item.listPrice)  : 'Not Available') + '</td>';
                body += '<td>' + (item.salesPrice != null ? String.valueOf(item.salesPrice) : 'Not Available') + '</td>';
                body += '<td>' + (item.approvalStatus != null ? item.approvalStatus : '') + '</td>';
                body += '</tr>';
            }
        }

        body += '</tbody></table><br/>';
        body += 'Sales Price has been ' + status.toLowerCase() + ', kindly review the details at your earliest convenience.<br/><br/>';
        body += 'Regards,<br/>';
        body += (quotation.quoteOwnerId != null ? quotation.quoteOwnerName : 'System Notification');
        email.setHtmlBody(body);

        try {
            // Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ email });
        } catch (Exception e) {
            System.debug('Email Sending Failed: ' + e.getMessage());
        }
    }

    private void sendCustomNotification(QuotationWrapper quotation, String status) {
        try {
            CustomNotificationType notificationType = [
                SELECT Id, DeveloperName FROM CustomNotificationType
                WHERE DeveloperName = 'Approval_Alert' LIMIT 1
            ];
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTitle('Sales Price ' + status);
            notification.setBody('Quote ' + quotation.quoteName + ' has been ' + status.toLowerCase() + '. Please review the details.');
            notification.setTargetId(quotation.quoteId);
            notification.send(new Set<String>{ quotation.quoteOwnerId });
        } catch (Exception e) {
            System.debug('Custom Notification Failed: ' + e.getMessage());
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────

    private static List<QuotationWrapper> parseHeaderAndLine(String js) {
        return (List<QuotationWrapper>) System.JSON.deserialize(js, List<QuotationWrapper>.class);
    }

    public static String getStringFieldSafely(SObject record, String fieldApiName) {
        try {
            Object value = record.get(fieldApiName);
            return value == null ? null : String.valueOf(value);
        } catch (SObjectException e) { return null; }
    }

    public static String getPicklistLabel(String objectApiName, String fieldApiName, String apiValue) {
        if (String.isBlank(apiValue)) return apiValue;
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
        if (objType == null) return apiValue;
        Schema.SObjectField sField = objType.getDescribe().fields.getMap().get(fieldApiName);
        if (sField == null) return apiValue;
        for (Schema.PicklistEntry entry : sField.getDescribe().getPicklistValues()) {
            if (entry.getValue() == apiValue) return entry.getLabel();
        }
        return apiValue;
    }

    public static Datetime getDateTimeFieldSafely(SObject record, String fieldApiName) {
        try {
            Object value = record.get(fieldApiName);
            return value == null ? null : (Datetime) value;
        } catch (SObjectException e) { return null; }
    }

    public static Decimal getDecimalFieldSafely(SObject record, String fieldApiName) {
        try {
            Object value = record.get(fieldApiName);
            return value == null ? null : (Decimal) value;
        } catch (SObjectException e) { return null; }
    }

    private static String getStageStatus(QuoteLineItem qli, String currentStageField) {
        if (qli == null || String.isBlank(currentStageField)) return null;
        return getStringFieldSafely(qli, currentStageField);
    }

    private static Boolean didCurrentStageCommentChange(QuoteLineItem qli, QuotationLineItemWrapper li) {
        if (qli == null || li == null || String.isBlank(li.currentStageField)) return false;
        String existing;
        String submitted;
        if      (li.currentStageField == 'Sales_Rep_Status__c')                        { existing = getStringFieldSafely(qli, 'Approval_Comments__c');                    submitted = li.approvalComments; }
        else if (li.currentStageField == 'Sales_Manager_Status__c')                    { existing = getStringFieldSafely(qli, 'Sales_Manager_Comments__c');                submitted = li.Sales_Manager_Comments; }
        else if (li.currentStageField == 'Country_Continent_Sales_H_LOB_Status__c')    { existing = getStringFieldSafely(qli, 'Country_Continent_Sales_LOB_Comments__c');  submitted = li.Country_Continent_Sales_LOB_Comments; }
        else if (li.currentStageField == 'Global_Sales_Head_Status__c')                { existing = getStringFieldSafely(qli, 'Global_Sales_Head_Comments__c');            submitted = li.Global_Sales_Head_Comments; }
        else if (li.currentStageField == 'Rotex_Board_Member_Status__c')               { existing = getStringFieldSafely(qli, 'Rotex_Board_Member_Comments__c');           submitted = li.Rotex_Board_Member_Comments; }
        else if (li.currentStageField == 'Managing_Director_Status__c')               { existing = getStringFieldSafely(qli, 'Managing_Director_Comments__c');            submitted = li.Managing_Director_Comments; }
        return normalizeComment(existing) != normalizeComment(submitted);
    }

    private static String normalizeComment(String value) {
        return value == null ? '' : value.trim();
    }

    private static Boolean canSkipToPreviousFinalApprover(QuoteLineItem qli, QuotationLineItemWrapper li) {
        if (qli == null || li == null || li.skipSoaRestrictions != true) return false;
        Integer currentIdx      = getApproverIndex(qli, UserInfo.getUserId());
        Integer finalIdx        = getApproverIndex(qli, qli.Final_Discount_Approver__c);
        Id      stageApproverId = getApproverIdForStage(qli, li.currentStageField);
        return currentIdx != null && finalIdx != null &&
               finalIdx < currentIdx &&
               stageApproverId == qli.Final_Discount_Approver__c;
    }

    private static Integer getApproverIndex(QuoteLineItem qli, Id approverId) {
        if (qli == null || approverId == null) return null;
        if (qli.Sales_Manager__c                          == approverId) return 1;
        if (qli.Country_Continent_Sales_Head_LOB_Head__c  == approverId) return 2;
        if (qli.Global_Sales_Head__c                      == approverId) return 3;
        if (qli.Rotex_Board_Member__c                     == approverId) return 4;
        if (qli.Managing_Director_Country_Manage__c       == approverId) return 5;
        return null;
    }

    private static Id getApproverIdForStage(QuoteLineItem qli, String stageField) {
        if (qli == null || String.isBlank(stageField)) return null;
        if (stageField == 'Sales_Manager_Status__c')                    return qli.Sales_Manager__c;
        if (stageField == 'Country_Continent_Sales_H_LOB_Status__c')    return qli.Country_Continent_Sales_Head_LOB_Head__c;
        if (stageField == 'Global_Sales_Head_Status__c')                return qli.Global_Sales_Head__c;
        if (stageField == 'Rotex_Board_Member_Status__c')               return qli.Rotex_Board_Member__c;
        if (stageField == 'Managing_Director_Status__c')                return qli.Managing_Director_Country_Manage__c;
        return null;
    }

    private static void applySkippedComments(QuoteLineItem qli, QuoteLineItem existing, QuotationLineItemWrapper li) {
        if (qli == null || existing == null || li == null || li.skipSoaRestrictions != true) return;
        Integer currentIdx = getApproverIndex(existing, UserInfo.getUserId());
        if (currentIdx == null) return;

        if (1 < currentIdx && existing.Sales_Manager__c != existing.Final_Discount_Approver__c &&
            String.isBlank(existing.Sales_Manager_Comments__c) && String.isNotBlank(li.Sales_Manager_Comments)) {
            qli.Sales_Manager_Comments__c  = li.Sales_Manager_Comments;
            qli.Sales_Manager_Status__c    = 'Approved';
            qli.Sales_Manager_Date_Time__c = DateTime.now();
        }
        if (2 < currentIdx && existing.Country_Continent_Sales_Head_LOB_Head__c != existing.Final_Discount_Approver__c &&
            String.isBlank(existing.Country_Continent_Sales_LOB_Comments__c) && String.isNotBlank(li.Country_Continent_Sales_LOB_Comments)) {
            qli.Country_Continent_Sales_LOB_Comments__c  = li.Country_Continent_Sales_LOB_Comments;
            qli.Country_Continent_Sales_H_LOB_Status__c  = 'Approved';
            qli.Country_Head_Date_Time__c                 = DateTime.now();
        }
        if (3 < currentIdx && existing.Global_Sales_Head__c != existing.Final_Discount_Approver__c &&
            String.isBlank(existing.Global_Sales_Head_Comments__c) && String.isNotBlank(li.Global_Sales_Head_Comments)) {
            qli.Global_Sales_Head_Comments__c  = li.Global_Sales_Head_Comments;
            qli.Global_Sales_Head_Status__c    = 'Approved';
            qli.Global_Sales_Head_Date_Time__c = DateTime.now();
        }
        if (4 < currentIdx && existing.Rotex_Board_Member__c != existing.Final_Discount_Approver__c &&
            String.isBlank(existing.Rotex_Board_Member_Comments__c) && String.isNotBlank(li.Rotex_Board_Member_Comments)) {
            qli.Rotex_Board_Member_Comments__c  = li.Rotex_Board_Member_Comments;
            qli.Rotex_Board_Member_Status__c    = 'Approved';
            qli.Rotex_Board_Member_Date_Time__c = DateTime.now();
        }
        if (5 < currentIdx && existing.Managing_Director_Country_Manage__c != existing.Final_Discount_Approver__c &&
            String.isBlank(existing.Managing_Director_Comments__c) && String.isNotBlank(li.Managing_Director_Comments)) {
            qli.Managing_Director_Comments__c  = li.Managing_Director_Comments;
            qli.Managing_Director_Status__c    = 'Approved';
            qli.Managing_Director_Date_Time__c = DateTime.now();
        }
    }

    // ── Inner Wrappers ────────────────────────────────────────────────────

    public class QuotationWrapper implements Comparable{
        @AuraEnabled public String quoteId;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountOwner;
        @AuraEnabled public String quoteOwnerId;
        @AuraEnabled public String quoteOwnerEmail;
        @AuraEnabled public String quoteOwnerName;
        @AuraEnabled public String quoteLink;
        @AuraEnabled public String hodUserId;
        @AuraEnabled public Decimal totalValue;
        @AuraEnabled public String revNo;
        @AuraEnabled public String validityOfOffer;
        @AuraEnabled public String paymentTerms;
        @AuraEnabled public String warrantyTerms;
        @AuraEnabled public String deliveryPeriod;
        @AuraEnabled public Decimal avgDiscountRequested;
        @AuraEnabled public Decimal avgDiscountApproved;
        @AuraEnabled public List<QuotationLineItemWrapper> quoteLineItems;
        @AuraEnabled public Boolean updated;
        @AuraEnabled public WarrantyApprovalWrapper warrantyApproval;
        @AuraEnabled public ValidityOfferApprovalWrapper validityOfferApproval;
        @AuraEnabled public TotalValueApprovalWrapper totalValueApproval;
        @AuraEnabled public MinimumOfferApprovalWrapper minimumOfferApproval;

        public QuotationWrapper() {}

        public QuotationWrapper(Quote quote, List<QuoteLineItem> lineItems, Id currentUserId) {
            this.quoteId        = quote.Id;
            this.quoteName      = quote.Name;
            this.accountName    = quote.Account.Name;
            this.accountOwner   = quote.Account.OwnerId;
            this.quoteNumber    = quote.QuoteNumber;
            this.quoteOwnerId   = quote.OwnerId;
            this.quoteOwnerEmail = quote.Owner.Email;
            this.quoteOwnerName  = quote.Owner.Name;
            this.totalValue      = getDecimalFieldSafely(quote, 'Total_Value__c');
            this.avgDiscountRequested = getDecimalFieldSafely(quote, 'Avg_Discount_Requested__c');
            this.avgDiscountApproved  = getDecimalFieldSafely(quote, 'Avg_Discount_Approved__c');
            this.revNo           = getStringFieldSafely(quote, 'Rev_No__c');
            this.validityOfOffer = getStringFieldSafely(quote, 'Validity_of_Offer__c');
            this.paymentTerms    = getPicklistLabel('Quote', 'Payment_Terms__c', getStringFieldSafely(quote, 'Payment_Terms__c'));
            this.warrantyTerms   = getStringFieldSafely(quote, 'Warranty_Terms__c');
            this.deliveryPeriod  = getStringFieldSafely(quote, 'Delivery_Period__c');
            this.updated         = false;

            Id hod;
            if      (quote.Sales_Rep__c                              == currentUserId) hod = quote.Sales_Rep__c;
            else if (quote.Sales_Manager__c                          == currentUserId) hod = quote.Sales_Manager__c;
            else if (quote.Country_Continent_Sales_Head_LOB_Head__c  == currentUserId) hod = quote.Country_Continent_Sales_Head_LOB_Head__c;
            else if (quote.Global_Sales_Head__c                      == currentUserId) hod = quote.Global_Sales_Head__c;
            else if (quote.Rotex_Board_Member__c                     == currentUserId) hod = quote.Rotex_Board_Member__c;
            else if (quote.Managing_Director_Country_Manager__c      == currentUserId) hod = quote.Managing_Director_Country_Manager__c;
            this.hodUserId = hod;

            // Warranty approval data — always populate when current user is a
            // warranty approver for this quote (warranty-only quotes rely on this).
            this.warrantyApproval = createWarrantyApprovalIfNeeded(quote, currentUserId);
            this.validityOfferApproval = createValidityOfferApprovalIfNeeded(quote, currentUserId);
            this.totalValueApproval = createTotalValueApprovalIfNeeded(quote, currentUserId);
            this.minimumOfferApproval = createMinimumOfferApprovalIfNeeded(quote, currentUserId);

            this.quoteLineItems = new List<QuotationLineItemWrapper>();
            for (QuoteLineItem eachLine : lineItems) {
                this.quoteLineItems.add(new QuotationLineItemWrapper(eachLine));
            }
        }

        public Integer compareTo(Object compareTo) {
            QuotationWrapper other = (QuotationWrapper) compareTo;
            if (this.quoteNumber == null && other.quoteNumber == null) return 0;
            if (this.quoteNumber == null) return 1;
            if (other.quoteNumber == null) return -1;
            return other.quoteNumber.compareTo(this.quoteNumber); // descending
        }

        private WarrantyApprovalWrapper createWarrantyApprovalIfNeeded(Quote q, Id currentUserId) {
            if (!hasAnyWarrantyStatus(q) &&
                (String.isBlank(q.Warranty_Terms_Draft__c) ||
                 q.Warranty_Terms_Draft__c == '12 Months from date of supply')) {
                return null;
            }
            // Show to ANY approver in the chain until the final approver has approved/rejected.
            // This keeps the row visible for earlier approvers (e.g. SM) even after they comment.
            Boolean isInChain =
                q.Sales_Manager__c                         == currentUserId ||
                q.Country_Continent_Sales_Head_LOB_Head__c == currentUserId ||
                q.Global_Sales_Head__c                     == currentUserId ||
                q.Rotex_Board_Member__c                    == currentUserId ||
                q.Managing_Director_Country_Manager__c     == currentUserId;
            if (!isInChain) return null;
            return new WarrantyApprovalWrapper(q);
        }

        private ValidityOfferApprovalWrapper createValidityOfferApprovalIfNeeded(Quote q, Id currentUserId) {
            if (!hasAnyValidityOfferStatus(q) &&
                (String.isBlank(q.Requested_Validity_Of_Offer__c) ||
                 q.Requested_Validity_Of_Offer__c == '30 Days')) {
                return null;
            }
            Boolean isInChain =
                q.Sales_Manager__c                         == currentUserId ||
                q.Country_Continent_Sales_Head_LOB_Head__c == currentUserId ||
                q.Global_Sales_Head__c                     == currentUserId ||
                q.Rotex_Board_Member__c                    == currentUserId ||
                q.Managing_Director_Country_Manager__c     == currentUserId;
            if (!isInChain) return null;
            return new ValidityOfferApprovalWrapper(q);
        }

        private TotalValueApprovalWrapper createTotalValueApprovalIfNeeded(Quote q, Id currentUserId) {
            if (!hasAnyTotalValueStatus(q) &&
                (q.Total_Value__c == null || q.Is_Total_Value_Approved__c == true)) {
                return null;
            }
            Boolean isInChain =
                q.Sales_Manager__c                         == currentUserId ||
                q.Country_Continent_Sales_Head_LOB_Head__c == currentUserId ||
                q.Global_Sales_Head__c                     == currentUserId ||
                q.Rotex_Board_Member__c                    == currentUserId ||
                q.Managing_Director_Country_Manager__c     == currentUserId;
            if (!isInChain) return null;
            return new TotalValueApprovalWrapper(q);
        }

        private MinimumOfferApprovalWrapper createMinimumOfferApprovalIfNeeded(Quote q, Id currentUserId) {
            if (!hasAnyMinimumOfferStatus(q) &&
                (q.Total_Value__c == null ||
                 q.Total_Value__c >= 25000 ||
                 q.Is_Small_Order_Handling__c != true ||
                 q.Is_Minimum_Offer_Value_Approved__c == true)) {
                return null;
            }
            Boolean isInChain =
                q.Global_Sales_Head__c                 == currentUserId ||
                q.Rotex_Board_Member__c                == currentUserId ||
                q.Managing_Director_Country_Manager__c == currentUserId;
            if (!isInChain) return null;
            return new MinimumOfferApprovalWrapper(q);
        }
    }

    // ── "Finally decided" helpers: true once the final approver has approved or rejected ──

    private static Boolean hasAnyWarrantyStatus(Quote q) {
        return String.isNotBlank(q.SM_Warranty_Status__c) ||
               String.isNotBlank(q.CH_Warranty_Status__c) ||
               String.isNotBlank(q.GS_Warranty_Status__c) ||
               String.isNotBlank(q.BM_Warranty_Status__c) ||
               String.isNotBlank(q.MD_Warranty_Status__c);
    }

    private static Boolean hasAnyValidityOfferStatus(Quote q) {
        return String.isNotBlank(q.SM_Validity_Offer_Status__c) ||
               String.isNotBlank(q.CH_Validity_Offer_Status__c) ||
               String.isNotBlank(q.GS_Validity_Offer_Status__c) ||
               String.isNotBlank(q.BM_Validity_Offer_Status__c) ||
               String.isNotBlank(q.MD_Validity_Offer_Status__c);
    }

    private static Boolean hasAnyTotalValueStatus(Quote q) {
        return String.isNotBlank(q.SM_Value_Status__c) ||
               String.isNotBlank(q.CH_Value_Status__c) ||
               String.isNotBlank(q.GS_Value_Status__c) ||
               String.isNotBlank(q.BM_Value_Status__c) ||
               String.isNotBlank(q.MD_Value_Status__c);
    }

    private static Boolean hasAnyMinimumOfferStatus(Quote q) {
        return String.isNotBlank(q.GS_Min_Offer_Status__c) ||
               String.isNotBlank(q.BM_Min_Offer_Status__c) ||
               String.isNotBlank(q.MD_Min_Offer_Status__c);
    }

    private static Boolean isWarrantyFinallyDecided(Quote q) {
        Id finalId = q.Final_Warranty_Terms_Approver__c;
        if (finalId == null) return false;
        if (q.Sales_Manager__c                         == finalId) return q.SM_Warranty_Status__c == 'Approved' || q.SM_Warranty_Status__c == 'Rejected';
        if (q.Country_Continent_Sales_Head_LOB_Head__c == finalId) return q.CH_Warranty_Status__c == 'Approved' || q.CH_Warranty_Status__c == 'Rejected';
        if (q.Global_Sales_Head__c                     == finalId) return q.GS_Warranty_Status__c == 'Approved' || q.GS_Warranty_Status__c == 'Rejected';
        if (q.Rotex_Board_Member__c                    == finalId) return q.BM_Warranty_Status__c == 'Approved' || q.BM_Warranty_Status__c == 'Rejected';
        if (q.Managing_Director_Country_Manager__c     == finalId) return q.MD_Warranty_Status__c == 'Approved' || q.MD_Warranty_Status__c == 'Rejected';
        return false;
    }

    private static Boolean isValidityOfferFinallyDecided(Quote q) {
        Id finalId = q.Final_Validity_Offer_Approver__c;
        if (finalId == null) return false;
        if (q.Sales_Manager__c                         == finalId) return q.SM_Validity_Offer_Status__c == 'Approved' || q.SM_Validity_Offer_Status__c == 'Rejected';
        if (q.Country_Continent_Sales_Head_LOB_Head__c == finalId) return q.CH_Validity_Offer_Status__c == 'Approved' || q.CH_Validity_Offer_Status__c == 'Rejected';
        if (q.Global_Sales_Head__c                     == finalId) return q.GS_Validity_Offer_Status__c == 'Approved' || q.GS_Validity_Offer_Status__c == 'Rejected';
        if (q.Rotex_Board_Member__c                    == finalId) return q.BM_Validity_Offer_Status__c == 'Approved' || q.BM_Validity_Offer_Status__c == 'Rejected';
        if (q.Managing_Director_Country_Manager__c     == finalId) return q.MD_Validity_Offer_Status__c == 'Approved' || q.MD_Validity_Offer_Status__c == 'Rejected';
        return false;
    }

    private static Boolean isTotalValueFinallyDecided(Quote q) {
        Id finalId = q.Final_Total_Value_Approver__c;
        if (finalId == null) return false;
        if (q.Sales_Manager__c                         == finalId) return q.SM_Value_Status__c == 'Approved' || q.SM_Value_Status__c == 'Rejected';
        if (q.Country_Continent_Sales_Head_LOB_Head__c == finalId) return q.CH_Value_Status__c == 'Approved' || q.CH_Value_Status__c == 'Rejected';
        if (q.Global_Sales_Head__c                     == finalId) return q.GS_Value_Status__c == 'Approved' || q.GS_Value_Status__c == 'Rejected';
        if (q.Rotex_Board_Member__c                    == finalId) return q.BM_Value_Status__c == 'Approved' || q.BM_Value_Status__c == 'Rejected';
        if (q.Managing_Director_Country_Manager__c     == finalId) return q.MD_Value_Status__c == 'Approved' || q.MD_Value_Status__c == 'Rejected';
        return false;
    }

    private static Boolean isMinimumOfferFinallyDecided(Quote q) {
        Id finalId = q.Final_Minimum_Offer_Value_Approver__c;
        if (finalId == null) return false;
        if (q.Global_Sales_Head__c                     == finalId) return q.GS_Min_Offer_Status__c == 'Approved' || q.GS_Min_Offer_Status__c == 'Rejected';
        if (q.Rotex_Board_Member__c                    == finalId) return q.BM_Min_Offer_Status__c == 'Approved' || q.BM_Min_Offer_Status__c == 'Rejected';
        if (q.Managing_Director_Country_Manager__c     == finalId) return q.MD_Min_Offer_Status__c == 'Approved' || q.MD_Min_Offer_Status__c == 'Rejected';
        return false;
    }

    private static Integer getHierarchyPos(Quote q, Id userId) {
        if (userId == null) return null;
        if (q.Sales_Manager__c                         == userId) return 1;
        if (q.Country_Continent_Sales_Head_LOB_Head__c == userId) return 2;
        if (q.Global_Sales_Head__c                     == userId) return 3;
        if (q.Rotex_Board_Member__c                    == userId) return 4;
        if (q.Managing_Director_Country_Manager__c     == userId) return 5;
        return null;
    }

    private static Boolean warrantyAnyLowerSubmitted(Quote q, Integer pos) {
        if (pos > 1 && q.SM_Warranty_Status__c == 'Submitted') return true;
        if (pos > 2 && q.CH_Warranty_Status__c == 'Submitted') return true;
        if (pos > 3 && q.GS_Warranty_Status__c == 'Submitted') return true;
        if (pos > 4 && q.BM_Warranty_Status__c == 'Submitted') return true;
        return false;
    }

    private static Integer getValidityOfferHierarchyPos(Quote q, Id userId) {
        if (userId == null) return null;
        if (q.Sales_Manager__c                         == userId) return 1;
        if (q.Country_Continent_Sales_Head_LOB_Head__c == userId) return 2;
        if (q.Global_Sales_Head__c                     == userId) return 3;
        if (q.Rotex_Board_Member__c                    == userId) return 4;
        if (q.Managing_Director_Country_Manager__c     == userId) return 5;
        return null;
    }

    private static Integer getTotalValueHierarchyPos(Quote q, Id userId) {
        if (userId == null) return null;
        if (q.Sales_Manager__c                         == userId) return 1;
        if (q.Country_Continent_Sales_Head_LOB_Head__c == userId) return 2;
        if (q.Global_Sales_Head__c                     == userId) return 3;
        if (q.Rotex_Board_Member__c                    == userId) return 4;
        if (q.Managing_Director_Country_Manager__c     == userId) return 5;
        return null;
    }

    private static Integer getMinimumOfferHierarchyPos(Quote q, Id userId) {
        if (userId == null) return null;
        if (q.Global_Sales_Head__c                     == userId) return 3;
        if (q.Rotex_Board_Member__c                    == userId) return 4;
        if (q.Managing_Director_Country_Manager__c     == userId) return 5;
        return null;
    }

    private static String getSoaProfileByPosition(Integer position) {

        if (position == null) return null;

        if (position == 1) return 'Sales Manager';

        if (position == 2)
            return 'Country / Continent Sales Head / LOB Head';

        if (position == 3) return 'Global Sales Head';

        if (position == 4) return 'Rotex Board Member';

        if (position == 5)
            return 'Managing Director / Country Manager';

        return null;
    }

    private static List<ApprovalValueOption> getAllowedWarrantyTermOptions(Integer maxPosition) {
        List<ApprovalValueOption> options = new List<ApprovalValueOption>();
        Set<String> added = new Set<String>();
        if (maxPosition == null) return options;
        System.debug('getAllowedWarrantyTermOptions maxPosition ==> ' + maxPosition);
        for (SOA_Matrix__c matrix : getSoaMatrixRows()) {
            Integer position = getSoaPositionByProfile(matrix.SOA_Profile__c);
            System.debug('getAllowedWarrantyTermOptions position ==> ' + position);
            String value = matrix.Warranty_Terms__c;
            System.debug('getAllowedWarrantyTermOptions value ==> ' + value);
            if (position != null && position <= maxPosition && String.isNotBlank(value) && !added.contains(value)) {
                options.add(new ApprovalValueOption(value, value));
                added.add(value);
            }
        }
        System.debug('getAllowedWarrantyTermOptions options ==>' + options);
        return options;
    }

    private static List<ApprovalValueOption> getAllowedValidityOfferOptions(Integer maxPosition) {
        List<ApprovalValueOption> options = new List<ApprovalValueOption>();
        Set<String> added = new Set<String>();
        if (maxPosition == null) return options;

        for (SOA_Matrix__c matrix : getSoaMatrixRows()) {
            Integer position = getSoaPositionByProfile(matrix.SOA_Profile__c);
            String value = matrix.Validity_of_Offer__c;
            if (position != null && position <= maxPosition && String.isNotBlank(value) && !added.contains(value)) {
                options.add(new ApprovalValueOption(value, value));
                added.add(value);
            }
        }
        return options;
    }

    private static void validateWarrantyTermsForApprover(String value, Integer maxPosition) {
        System.debug('validateWarrantyTermsForApprover Value ==> '+value+ ' maxPosition ==> ' + maxPosition);
        if (String.isBlank(value)) return;
        String normalizedValue = normalizeWarrantyTermValue(value);
        System.debug('validateWarrantyTermsForApprover normalizedValue ==> '+normalizedValue);
        for (ApprovalValueOption option : getAllowedWarrantyTermOptions(maxPosition)) {
            System.debug('ApprovalValueOption option label ==> '+option.label);
            System.debug('ApprovalValueOption option value ==> '+option.value);
            if (normalizeWarrantyTermValue(option.value) == normalizedValue) {
                System.debug('validateWarrantyTermsForApprover It is approved');
                return;
            }
        }
        System.debug('validateWarrantyTermsForApprover It is rejected');
        throw new AuraHandledException('Requested Warranty Terms are above the final approver SOA level.');
    }

    private static void validateValidityOfferForApprover(String value, Integer maxPosition) {
        if (String.isBlank(value)) return;
        String normalizedValue = normalizeValidityOfferValue(value);
        for (ApprovalValueOption option : getAllowedValidityOfferOptions(maxPosition)) {
            if (normalizeValidityOfferValue(option.value) == normalizedValue) return;
        }
        throw new AuraHandledException('Requested Validity of Offer is above the final approver SOA level.');
    }

    private static String normalizeApprovalValue(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }

    private static String normalizeWarrantyTermValue(String value) {
        String normalized = normalizeApprovalValue(value);
        if (normalized.contains('more than 48')) return 'more-than-48-months';
        Matcher m = Pattern.compile('(\\d+)\\s*months?').matcher(normalized);
        return m.find() ? m.group(1) + '-months' : normalized;
    }

    private static String normalizeValidityOfferValue(String value) {
        String normalized = normalizeApprovalValue(value);
        if (normalized.contains('more than 365')) return 'more-than-365-days';
        Matcher m = Pattern.compile('(\\d+)\\s*days?').matcher(normalized);
        return m.find() ? m.group(1) + '-days' : normalized;
    }

    private static List<SOA_Matrix__c> cachedSoaMatrixRows;
    private static List<SOA_Matrix__c> getSoaMatrixRows() {
        if (cachedSoaMatrixRows == null) {
            cachedSoaMatrixRows = [
                SELECT SOA_Profile__c, Warranty_Terms__c, Validity_of_Offer__c
                FROM SOA_Matrix__c
                ORDER BY Name ASC
            ];
        }
        return cachedSoaMatrixRows;
    }

    private static Integer getSoaPositionByProfile(String profile) {
        System.debug('getSoaPositionByProfile profile ==> ' + profile);

        if (String.isBlank(profile)) {
            return null;
        }

        String normalized = profile.toLowerCase().trim();

        if (Pattern.matches('.*\\bsales rep\\b.*', normalized)) {
            return 0;
        }

        if (Pattern.matches('.*\\bsales manager\\b.*', normalized)) {
            return 1;
        }

        if (
            Pattern.matches('.*\\bmanaging director\\b.*', normalized) ||
            Pattern.matches('.*\\bcountry manager\\b.*', normalized)
        ) {
            return 5;
        }

        if (Pattern.matches('.*\\bglobal sales\\b.*', normalized)) {
            return 3;
        }

        if (
            Pattern.matches('.*\\bcountry\\b.*', normalized) ||
            Pattern.matches('.*\\bcontinent\\b.*', normalized) ||
            Pattern.matches('.*\\blob\\b.*', normalized)
        ) {
            return 2;
        }

        if (Pattern.matches('.*\\bboard\\b.*', normalized)) {
            return 4;
        }

        return null;
    }

    public class ApprovalValueOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public ApprovalValueOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class QuotationLineItemWrapper {
        @AuraEnabled public String  parentId;
        @AuraEnabled public String  quoteLineItemId;
        @AuraEnabled public String  productId;
        @AuraEnabled public String  productName;
        @AuraEnabled public String  productCode;
        @AuraEnabled public String  Country_Continent_Sales_LOB_Comments;
        @AuraEnabled public String  Global_Sales_Head_Comments;
        @AuraEnabled public String  Managing_Director_Comments;
        @AuraEnabled public String  Rotex_Board_Member_Comments;
        @AuraEnabled public String  Sales_Manager_Comments;
        @AuraEnabled public String  prevSalesManagerComments;
        @AuraEnabled public String  prevCountryContinentSalesComments;
        @AuraEnabled public String  prevGlobalSalesHeadComments;
        @AuraEnabled public String  prevRotexBoardMemberComments;
        @AuraEnabled public String  prevManagingDirectorComments;
        @AuraEnabled public String  salesManagerName;
        @AuraEnabled public String  countryContinentSalesName;
        @AuraEnabled public String  rotexBoardMemberName;
        @AuraEnabled public String  managingDirectorName;
        @AuraEnabled public String  globalSalesHeadName;
        @AuraEnabled public String  salesManagerId;
        @AuraEnabled public String  countryContinentSalesId;
        @AuraEnabled public String  rotexBoardMemberId;
        @AuraEnabled public String  managingDirectorId;
        @AuraEnabled public String  globalSalesHeadId;
        @AuraEnabled public String  salesManagerStatus;
        @AuraEnabled public String  countryContinentSalesStatus;
        @AuraEnabled public String  rotexBoardMemberStatus;
        @AuraEnabled public String  managingDirectorStatus;
        @AuraEnabled public String  globalSalesHeadStatus;
        @AuraEnabled public DateTime salesManagerDateTime;
        @AuraEnabled public DateTime countryHeadDateTime;
        @AuraEnabled public DateTime managingDirectorDateTime;
        @AuraEnabled public DateTime globalSalesHeadDateTime;
        @AuraEnabled public DateTime rotexBoardMemberDateTime;
        @AuraEnabled public Decimal  quantity;
        @AuraEnabled public Decimal  listPrice;
        @AuraEnabled public Decimal  salesPrice;
        @AuraEnabled public Decimal  d1;
        @AuraEnabled public Decimal  d2;
        @AuraEnabled public Decimal  previousDiscount;
        @AuraEnabled public Boolean  bcheck;
        @AuraEnabled public Boolean  bcheck1;
        @AuraEnabled public Boolean  bcheck2;
        @AuraEnabled public Boolean  bcheck3;
        @AuraEnabled public Boolean  bcheck4;
        @AuraEnabled public Boolean  bcheck5;
        @AuraEnabled public String   approvalStatus;
        @AuraEnabled public String   approvalComments;
        @AuraEnabled public Boolean  updated;
        @AuraEnabled public String   hodUserId;
        @AuraEnabled public String   currentStage;
        @AuraEnabled public String   currentStageField;
        @AuraEnabled public String   finalDiscountApproverId;
        @AuraEnabled public Boolean  isFinalDiscountApprover;
        @AuraEnabled public Boolean  skipSoaRestrictions;

        public QuotationLineItemWrapper() {}

        public QuotationLineItemWrapper(QuoteLineItem qli) {
            this.parentId         = qli.QuoteId;
            this.quoteLineItemId  = qli.Id;
            this.productId        = qli.Product2Id;
            this.productName      = qli.Product2.Name;
            this.productCode      = qli.Product2.ProductCode;
            this.quantity         = qli.Quantity;
            this.listPrice        = qli.ListPrice;
            this.salesPrice       = qli.UnitPrice;
            this.bcheck  = true; this.bcheck1 = true; this.bcheck2 = true;
            this.bcheck3 = true; this.bcheck4 = true; this.bcheck5 = true;
            this.finalDiscountApproverId = qli.Final_Discount_Approver__c;

            this.Country_Continent_Sales_LOB_Comments = qli.Country_Continent_Sales_LOB_Comments__c;
            this.Global_Sales_Head_Comments           = qli.Global_Sales_Head_Comments__c;
            this.Managing_Director_Comments           = qli.Managing_Director_Comments__c;
            this.Rotex_Board_Member_Comments          = qli.Rotex_Board_Member_Comments__c;
            this.Sales_Manager_Comments               = qli.Sales_Manager_Comments__c;
            this.prevSalesManagerComments             = getStringFieldSafely(qli, 'Prev_Sales_Manager_Comments__c');
            this.prevCountryContinentSalesComments    = getStringFieldSafely(qli, 'Prev_Country_Continent_Sales_Comments__c');
            this.prevGlobalSalesHeadComments          = getStringFieldSafely(qli, 'Prev_Global_Sales_Head_Comments__c');
            this.prevRotexBoardMemberComments         = getStringFieldSafely(qli, 'Prev_Rotex_Board_Member_Comments__c');
            this.prevManagingDirectorComments         = getStringFieldSafely(qli, 'Prev_Managing_Director_Comments__c');

            this.salesManagerName        = qli.Sales_Manager__r != null ? qli.Sales_Manager__r.Name : null;
            this.countryContinentSalesName = qli.Country_Continent_Sales_Head_LOB_Head__r != null ? qli.Country_Continent_Sales_Head_LOB_Head__r.Name : null;
            this.rotexBoardMemberName    = qli.Rotex_Board_Member__r != null ? qli.Rotex_Board_Member__r.Name : null;
            this.managingDirectorName    = qli.Managing_Director_Country_Manage__r != null ? qli.Managing_Director_Country_Manage__r.Name : null;
            this.globalSalesHeadName     = qli.Global_Sales_Head__r != null ? qli.Global_Sales_Head__r.Name : null;
            this.salesManagerId          = String.valueOf(qli.Sales_Manager__c);
            this.countryContinentSalesId = String.valueOf(qli.Country_Continent_Sales_Head_LOB_Head__c);
            this.rotexBoardMemberId      = String.valueOf(qli.Rotex_Board_Member__c);
            this.managingDirectorId      = String.valueOf(qli.Managing_Director_Country_Manage__c);
            this.globalSalesHeadId       = String.valueOf(qli.Global_Sales_Head__c);

            Id     hod   = null;
            String stage = '';
            String stageField = '';
            String comments   = '';
            Id     currUser   = UserInfo.getUserId();

            if      (qli.Sales_Rep__c                              == currUser) { this.bcheck  = false; hod = qli.Sales_Rep__c;                              stage = qli.Sales_Rep_Status__c;                      stageField = 'Sales_Rep_Status__c';                         comments = qli.Approval_Comments__c; }
            else if (qli.Sales_Manager__c                          == currUser) { this.bcheck1 = false; hod = qli.Sales_Manager__c;                          stage = qli.Sales_Manager_Status__c;                  stageField = 'Sales_Manager_Status__c';                     comments = qli.Sales_Manager_Comments__c; }
            else if (qli.Country_Continent_Sales_Head_LOB_Head__c  == currUser) { this.bcheck2 = false; hod = qli.Country_Continent_Sales_Head_LOB_Head__c;  stage = qli.Country_Continent_Sales_H_LOB_Status__c;  stageField = 'Country_Continent_Sales_H_LOB_Status__c';     comments = qli.Country_Continent_Sales_LOB_Comments__c; }
            else if (qli.Global_Sales_Head__c                      == currUser) { this.bcheck5 = false; hod = qli.Global_Sales_Head__c;                      stage = qli.Global_Sales_Head_Status__c;              stageField = 'Global_Sales_Head_Status__c';                 comments = qli.Global_Sales_Head_Comments__c; }
            else if (qli.Rotex_Board_Member__c                     == currUser) { this.bcheck3 = false; hod = qli.Rotex_Board_Member__c;                     stage = qli.Rotex_Board_Member_Status__c;             stageField = 'Rotex_Board_Member_Status__c';                comments = qli.Rotex_Board_Member_Comments__c; }
            else if (qli.Managing_Director_Country_Manage__c       == currUser) { this.bcheck4 = false; hod = qli.Managing_Director_Country_Manage__c;       stage = qli.Managing_Director_Status__c;              stageField = 'Managing_Director_Status__c';                 comments = qli.Managing_Director_Comments__c; }

            this.hodUserId        = hod;
            this.currentStage     = stage;
            this.currentStageField = stageField;
            this.approvalStatus   = stage;
            this.approvalComments = comments;
            this.d1               = qli.Discount_as_per_SAP__c;
            this.d2               = qli.Discount_to_be_offered__c;
            this.previousDiscount = getDecimalFieldSafely(qli, 'Previous_Discount__c');
            this.updated          = false;
            this.skipSoaRestrictions = false;

            this.salesManagerStatus          = getStringFieldSafely(qli, 'Sales_Manager_Status__c');
            this.countryContinentSalesStatus  = getStringFieldSafely(qli, 'Country_Continent_Sales_H_LOB_Status__c');
            this.rotexBoardMemberStatus       = getStringFieldSafely(qli, 'Rotex_Board_Member_Status__c');
            this.managingDirectorStatus       = getStringFieldSafely(qli, 'Managing_Director_Status__c');
            this.globalSalesHeadStatus        = getStringFieldSafely(qli, 'Global_Sales_Head_Status__c');
            this.salesManagerDateTime         = getDateTimeFieldSafely(qli, 'Sales_Manager_Date_Time__c');
            this.countryHeadDateTime          = getDateTimeFieldSafely(qli, 'Country_Head_Date_Time__c');
            this.managingDirectorDateTime     = getDateTimeFieldSafely(qli, 'Managing_Director_Date_Time__c');
            this.globalSalesHeadDateTime      = getDateTimeFieldSafely(qli, 'Global_Sales_Head_Date_Time__c');
            this.rotexBoardMemberDateTime     = getDateTimeFieldSafely(qli, 'Rotex_Board_Member_Date_Time__c');
        }
    }

    public class WarrantyApprovalWrapper {
        @AuraEnabled public String   quoteId;
        @AuraEnabled public String   quoteName;
        @AuraEnabled public String   quoteNumber;
        @AuraEnabled public String   warrantyTermsDraft;
        @AuraEnabled public String   originalWarrantyTermsDraft;
        @AuraEnabled public String   warrantyTerms;
        @AuraEnabled public String   finalWarrantyApprover;
        @AuraEnabled public List<ApprovalValueOption> allowedWarrantyTerms;
        @AuraEnabled public Boolean  updated;

        @AuraEnabled public String   smName;         @AuraEnabled public String   smId;
        @AuraEnabled public String   smWarrantyStatus; @AuraEnabled public DateTime smWarrantyDateTime;
        @AuraEnabled public String   smWarrantyComments; @AuraEnabled public Boolean isSmCurrentUser;
        @AuraEnabled public Boolean  canSmEditStatus; @AuraEnabled public Boolean  canSmEditComments;
        @AuraEnabled public String   originalSmWarrantyStatus; @AuraEnabled public String originalSmWarrantyComments;

        @AuraEnabled public String   chName;         @AuraEnabled public String   chId;
        @AuraEnabled public String   chWarrantyStatus; @AuraEnabled public DateTime chWarrantyDateTime;
        @AuraEnabled public String   chWarrantyComments; @AuraEnabled public Boolean isChCurrentUser;
        @AuraEnabled public Boolean  canChEditStatus; @AuraEnabled public Boolean  canChEditComments;
        @AuraEnabled public String   originalChWarrantyStatus; @AuraEnabled public String originalChWarrantyComments;

        @AuraEnabled public String   gsName;         @AuraEnabled public String   gsId;
        @AuraEnabled public String   gsWarrantyStatus; @AuraEnabled public DateTime gsWarrantyDateTime;
        @AuraEnabled public String   gsWarrantyComments; @AuraEnabled public Boolean isGsCurrentUser;
        @AuraEnabled public Boolean  canGsEditStatus; @AuraEnabled public Boolean  canGsEditComments;
        @AuraEnabled public String   originalGsWarrantyStatus; @AuraEnabled public String originalGsWarrantyComments;

        @AuraEnabled public String   bmName;         @AuraEnabled public String   bmId;
        @AuraEnabled public String   bmWarrantyStatus; @AuraEnabled public DateTime bmWarrantyDateTime;
        @AuraEnabled public String   bmWarrantyComments; @AuraEnabled public Boolean isBmCurrentUser;
        @AuraEnabled public Boolean  canBmEditStatus; @AuraEnabled public Boolean  canBmEditComments;
        @AuraEnabled public String   originalBmWarrantyStatus; @AuraEnabled public String originalBmWarrantyComments;

        @AuraEnabled public String   mdName;         @AuraEnabled public String   mdId;
        @AuraEnabled public String   mdWarrantyStatus; @AuraEnabled public DateTime mdWarrantyDateTime;
        @AuraEnabled public String   mdWarrantyComments; @AuraEnabled public Boolean isMdCurrentUser;
        @AuraEnabled public Boolean  canMdEditStatus; @AuraEnabled public Boolean  canMdEditComments;
        @AuraEnabled public String   originalMdWarrantyStatus; @AuraEnabled public String originalMdWarrantyComments;

        @AuraEnabled public Integer  currentUserHierarchyPosition;
        @AuraEnabled public Integer  finalApproverHierarchyPosition;
        @AuraEnabled public Boolean  isHigherHierarchy;
        @AuraEnabled public Boolean  canViewReadOnly;
        @AuraEnabled public Boolean  skipSoaRestrictions;
        @AuraEnabled public Boolean  isFinalApproverWithPendingLower;

        public WarrantyApprovalWrapper() {}

        public WarrantyApprovalWrapper(Quote q) {
            Id currentUserId = UserInfo.getUserId();
            this.quoteId             = q.Id;
            this.quoteName           = q.Name;
            this.quoteNumber         = q.QuoteNumber;
            this.warrantyTermsDraft  = q.Warranty_Terms_Draft__c;
            this.originalWarrantyTermsDraft = q.Warranty_Terms_Draft__c;
            this.warrantyTerms       = q.Warranty_Terms__c;
            this.finalWarrantyApprover = getStringFieldSafely(q, 'Final_Warranty_Terms_Approver__c');
            this.updated             = false;

            this.smId = q.Sales_Manager__c; this.smName = q.Sales_Manager__r != null ? q.Sales_Manager__r.Name : null;
            this.smWarrantyStatus = q.SM_Warranty_Status__c; this.smWarrantyDateTime = q.SM_Warranty_Date_Time__c;
            this.smWarrantyComments = q.SM_Warranty_Comments__c; this.isSmCurrentUser = q.Sales_Manager__c == currentUserId;
            this.originalSmWarrantyStatus = q.SM_Warranty_Status__c; this.originalSmWarrantyComments = q.SM_Warranty_Comments__c;

            this.chId = q.Country_Continent_Sales_Head_LOB_Head__c; this.chName = q.Country_Continent_Sales_Head_LOB_Head__r != null ? q.Country_Continent_Sales_Head_LOB_Head__r.Name : null;
            this.chWarrantyStatus = q.CH_Warranty_Status__c; this.chWarrantyDateTime = q.CH_Warranty_Date_Time__c;
            this.chWarrantyComments = q.CH_Warranty_Comments__c; this.isChCurrentUser = q.Country_Continent_Sales_Head_LOB_Head__c == currentUserId;
            this.originalChWarrantyStatus = q.CH_Warranty_Status__c; this.originalChWarrantyComments = q.CH_Warranty_Comments__c;

            this.gsId = q.Global_Sales_Head__c; this.gsName = q.Global_Sales_Head__r != null ? q.Global_Sales_Head__r.Name : null;
            this.gsWarrantyStatus = q.GS_Warranty_Status__c; this.gsWarrantyDateTime = q.GS_Warranty_Date_Time__c;
            this.gsWarrantyComments = q.GS_Warranty_Comments__c; this.isGsCurrentUser = q.Global_Sales_Head__c == currentUserId;
            this.originalGsWarrantyStatus = q.GS_Warranty_Status__c; this.originalGsWarrantyComments = q.GS_Warranty_Comments__c;

            this.bmId = q.Rotex_Board_Member__c; this.bmName = q.Rotex_Board_Member__r != null ? q.Rotex_Board_Member__r.Name : null;
            this.bmWarrantyStatus = q.BM_Warranty_Status__c; this.bmWarrantyDateTime = q.BM_Warranty_Date_Time__c;
            this.bmWarrantyComments = q.BM_Warranty_Comments__c; this.isBmCurrentUser = q.Rotex_Board_Member__c == currentUserId;
            this.originalBmWarrantyStatus = q.BM_Warranty_Status__c; this.originalBmWarrantyComments = q.BM_Warranty_Comments__c;

            this.mdId = q.Managing_Director_Country_Manager__c; this.mdName = q.Managing_Director_Country_Manager__r != null ? q.Managing_Director_Country_Manager__r.Name : null;
            this.mdWarrantyStatus = q.MD_Warranty_Status__c; this.mdWarrantyDateTime = q.MD_Warranty_Date_Time__c;
            this.mdWarrantyComments = q.MD_Warranty_Comments__c; this.isMdCurrentUser = q.Managing_Director_Country_Manager__c == currentUserId;
            this.originalMdWarrantyStatus = q.MD_Warranty_Status__c; this.originalMdWarrantyComments = q.MD_Warranty_Comments__c;

            setHierarchyPositions(q, currentUserId);
            this.allowedWarrantyTerms = getAllowedWarrantyTermOptions(this.finalApproverHierarchyPosition);
            setEditPermissions(q, currentUserId);
        }

        private void setHierarchyPositions(Quote q, Id currentUserId) {
            this.currentUserHierarchyPosition   = getWarrantyHierarchyIndex(q, currentUserId);
            System.debug('setHierarchyPositions currentUserHierarchyPosition ==> ' + this.currentUserHierarchyPosition);
            Id finalId = q.Final_Warranty_Terms_Approver__c;
            System.debug('setHierarchyPositions finalId ==> '+finalId);
            this.finalApproverHierarchyPosition = getWarrantyHierarchyIndex(q, finalId);
            System.debug('setHierarchyPositions finalApproverHierarchyPosition ==> ' + this.finalApproverHierarchyPosition);
            this.isHigherHierarchy = this.currentUserHierarchyPosition != null &&
                                    this.finalApproverHierarchyPosition != null &&
                                    this.currentUserHierarchyPosition > this.finalApproverHierarchyPosition;
            this.canViewReadOnly = this.isHigherHierarchy;

            // True when user IS the final approver but a lower level is still Submitted
            this.isFinalApproverWithPendingLower =
                !this.isHigherHierarchy &&
                this.currentUserHierarchyPosition != null &&
                this.finalApproverHierarchyPosition != null &&
                this.currentUserHierarchyPosition == this.finalApproverHierarchyPosition &&
                isAnyLowerLevelSubmitted(q, this.finalApproverHierarchyPosition);
        }

        private Boolean isAnyLowerLevelSubmitted(Quote q, Integer pos) {
            if (pos > 1 && q.SM_Warranty_Status__c == 'Submitted') return true;
            if (pos > 2 && q.CH_Warranty_Status__c == 'Submitted') return true;
            if (pos > 3 && q.GS_Warranty_Status__c == 'Submitted') return true;
            if (pos > 4 && q.BM_Warranty_Status__c == 'Submitted') return true;
            return false;
        }

        private Integer getWarrantyHierarchyIndex(Quote q, Id approverId) {
            System.debug('getWarrantyHierarchyIndex approverId ==> '+ approverId);
            if (approverId == null) return null;
            if (q.Sales_Manager__c == approverId) return 1;
            if (q.Country_Continent_Sales_Head_LOB_Head__c == approverId) return 2;
            if (q.Global_Sales_Head__c == approverId) return 3;
            if (q.Rotex_Board_Member__c == approverId) return 4;
            if (q.Managing_Director_Country_Manager__c == approverId) return 5;
            return null;
        }

        private void setEditPermissions(Quote q, Id currentUserId) {
            Id finalId = q.Final_Warranty_Terms_Approver__c;
            if (this.isSmCurrentUser && this.smWarrantyStatus == 'Submitted') { this.canSmEditComments = true; this.canSmEditStatus = (q.Sales_Manager__c == finalId); }
            if (this.isChCurrentUser && this.chWarrantyStatus == 'Submitted') { this.canChEditComments = true; this.canChEditStatus = (q.Country_Continent_Sales_Head_LOB_Head__c == finalId); }
            if (this.isGsCurrentUser && this.gsWarrantyStatus == 'Submitted') { this.canGsEditComments = true; this.canGsEditStatus = (q.Global_Sales_Head__c == finalId); }
            if (this.isBmCurrentUser && this.bmWarrantyStatus == 'Submitted') { this.canBmEditComments = true; this.canBmEditStatus = (q.Rotex_Board_Member__c == finalId); }
            if (this.isMdCurrentUser && this.mdWarrantyStatus == 'Submitted') { this.canMdEditComments = true; this.canMdEditStatus = (q.Managing_Director_Country_Manager__c == finalId); }
        }
    }

    public class ValidityOfferApprovalWrapper {
        @AuraEnabled public String   quoteId;
        @AuraEnabled public String   quoteName;
        @AuraEnabled public String   quoteNumber;
        @AuraEnabled public String   requestedValidityOfOffer;
        @AuraEnabled public String   originalRequestedValidityOfOffer;
        @AuraEnabled public String   validityOfOffer;
        @AuraEnabled public String   finalValidityOfferApprover;
        @AuraEnabled public List<ApprovalValueOption> allowedValidityOfferValues;
        @AuraEnabled public Boolean  updated;

        @AuraEnabled public String   smName;         @AuraEnabled public String   smId;
        @AuraEnabled public String   smValidityOfferStatus; @AuraEnabled public DateTime smValidityOfferDateTime;
        @AuraEnabled public String   smValidityOfferComments; @AuraEnabled public Boolean isSmCurrentUser;
        @AuraEnabled public Boolean  canSmEditStatus; @AuraEnabled public Boolean  canSmEditComments;
        @AuraEnabled public String   originalSmValidityOfferStatus; @AuraEnabled public String originalSmValidityOfferComments;

        @AuraEnabled public String   chName;         @AuraEnabled public String   chId;
        @AuraEnabled public String   chValidityOfferStatus; @AuraEnabled public DateTime chValidityOfferDateTime;
        @AuraEnabled public String   chValidityOfferComments; @AuraEnabled public Boolean isChCurrentUser;
        @AuraEnabled public Boolean  canChEditStatus; @AuraEnabled public Boolean  canChEditComments;
        @AuraEnabled public String   originalChValidityOfferStatus; @AuraEnabled public String originalChValidityOfferComments;

        @AuraEnabled public String   gsName;         @AuraEnabled public String   gsId;
        @AuraEnabled public String   gsValidityOfferStatus; @AuraEnabled public DateTime gsValidityOfferDateTime;
        @AuraEnabled public String   gsValidityOfferComments; @AuraEnabled public Boolean isGsCurrentUser;
        @AuraEnabled public Boolean  canGsEditStatus; @AuraEnabled public Boolean  canGsEditComments;
        @AuraEnabled public String   originalGsValidityOfferStatus; @AuraEnabled public String originalGsValidityOfferComments;

        @AuraEnabled public String   bmName;         @AuraEnabled public String   bmId;
        @AuraEnabled public String   bmValidityOfferStatus; @AuraEnabled public DateTime bmValidityOfferDateTime;
        @AuraEnabled public String   bmValidityOfferComments; @AuraEnabled public Boolean isBmCurrentUser;
        @AuraEnabled public Boolean  canBmEditStatus; @AuraEnabled public Boolean  canBmEditComments;
        @AuraEnabled public String   originalBmValidityOfferStatus; @AuraEnabled public String originalBmValidityOfferComments;

        @AuraEnabled public String   mdName;         @AuraEnabled public String   mdId;
        @AuraEnabled public String   mdValidityOfferStatus; @AuraEnabled public DateTime mdValidityOfferDateTime;
        @AuraEnabled public String   mdValidityOfferComments; @AuraEnabled public Boolean isMdCurrentUser;
        @AuraEnabled public Boolean  canMdEditStatus; @AuraEnabled public Boolean  canMdEditComments;
        @AuraEnabled public String   originalMdValidityOfferStatus; @AuraEnabled public String originalMdValidityOfferComments;

        @AuraEnabled public Integer  currentUserHierarchyPosition;
        @AuraEnabled public Integer  finalApproverHierarchyPosition;
        @AuraEnabled public Boolean  isHigherHierarchy;
        @AuraEnabled public Boolean  canViewReadOnly;
        @AuraEnabled public Boolean  skipSoaRestrictions;
        @AuraEnabled public Boolean  isFinalApproverWithPendingLower;

        public ValidityOfferApprovalWrapper() {}

        public ValidityOfferApprovalWrapper(Quote q) {
            Id currentUserId = UserInfo.getUserId();
            this.quoteId                    = q.Id;
            this.quoteName                  = q.Name;
            this.quoteNumber                = q.QuoteNumber;
            this.requestedValidityOfOffer   = q.Requested_Validity_Of_Offer__c;
            this.originalRequestedValidityOfOffer = q.Requested_Validity_Of_Offer__c;
            this.validityOfOffer            = q.Validity_of_Offer__c;
            this.finalValidityOfferApprover = getStringFieldSafely(q, 'Final_Validity_Offer_Approver__c');
            this.updated                    = false;

            this.smId = q.Sales_Manager__c; this.smName = q.Sales_Manager__r != null ? q.Sales_Manager__r.Name : null;
            this.smValidityOfferStatus = q.SM_Validity_Offer_Status__c; this.smValidityOfferDateTime = q.SM_Validity_Offer_Date_Time__c;
            this.smValidityOfferComments = q.SM_Validity_Offer_Comments__c; this.isSmCurrentUser = q.Sales_Manager__c == currentUserId;
            this.originalSmValidityOfferStatus = q.SM_Validity_Offer_Status__c; this.originalSmValidityOfferComments = q.SM_Validity_Offer_Comments__c;

            this.chId = q.Country_Continent_Sales_Head_LOB_Head__c; this.chName = q.Country_Continent_Sales_Head_LOB_Head__r != null ? q.Country_Continent_Sales_Head_LOB_Head__r.Name : null;
            this.chValidityOfferStatus = q.CH_Validity_Offer_Status__c; this.chValidityOfferDateTime = q.CH_Validity_Offer_Date_Time__c;
            this.chValidityOfferComments = q.CH_Validity_Offer_Comments__c; this.isChCurrentUser = q.Country_Continent_Sales_Head_LOB_Head__c == currentUserId;
            this.originalChValidityOfferStatus = q.CH_Validity_Offer_Status__c; this.originalChValidityOfferComments = q.CH_Validity_Offer_Comments__c;

            this.gsId = q.Global_Sales_Head__c; this.gsName = q.Global_Sales_Head__r != null ? q.Global_Sales_Head__r.Name : null;
            this.gsValidityOfferStatus = q.GS_Validity_Offer_Status__c; this.gsValidityOfferDateTime = q.GS_Validity_Offer_Date_Time__c;
            this.gsValidityOfferComments = q.GS_Validity_Offer_Comments__c; this.isGsCurrentUser = q.Global_Sales_Head__c == currentUserId;
            this.originalGsValidityOfferStatus = q.GS_Validity_Offer_Status__c; this.originalGsValidityOfferComments = q.GS_Validity_Offer_Comments__c;

            this.bmId = q.Rotex_Board_Member__c; this.bmName = q.Rotex_Board_Member__r != null ? q.Rotex_Board_Member__r.Name : null;
            this.bmValidityOfferStatus = q.BM_Validity_Offer_Status__c; this.bmValidityOfferDateTime = q.BM_Validity_Offer_Date_Time__c;
            this.bmValidityOfferComments = q.BM_Validity_Offer_Comments__c; this.isBmCurrentUser = q.Rotex_Board_Member__c == currentUserId;
            this.originalBmValidityOfferStatus = q.BM_Validity_Offer_Status__c; this.originalBmValidityOfferComments = q.BM_Validity_Offer_Comments__c;

            this.mdId = q.Managing_Director_Country_Manager__c; this.mdName = q.Managing_Director_Country_Manager__r != null ? q.Managing_Director_Country_Manager__r.Name : null;
            this.mdValidityOfferStatus = q.MD_Validity_Offer_Status__c; this.mdValidityOfferDateTime = q.MD_Validity_Offer_Date_Time__c;
            this.mdValidityOfferComments = q.MD_Validity_Offer_Comments__c; this.isMdCurrentUser = q.Managing_Director_Country_Manager__c == currentUserId;
            this.originalMdValidityOfferStatus = q.MD_Validity_Offer_Status__c; this.originalMdValidityOfferComments = q.MD_Validity_Offer_Comments__c;

            setValidityOfferHierarchyPositions(q, currentUserId);
            this.allowedValidityOfferValues = getAllowedValidityOfferOptions(this.finalApproverHierarchyPosition);
            setValidityOfferEditPermissions(q, currentUserId);
        }

        private void setValidityOfferHierarchyPositions(Quote q, Id currentUserId) {
            this.currentUserHierarchyPosition   = getValidityOfferHierarchyIdx(q, currentUserId);
            Id finalId = q.Final_Validity_Offer_Approver__c;
            this.finalApproverHierarchyPosition = getValidityOfferHierarchyIdx(q, finalId);
            this.isHigherHierarchy = this.currentUserHierarchyPosition != null &&
                                    this.finalApproverHierarchyPosition != null &&
                                    this.currentUserHierarchyPosition > this.finalApproverHierarchyPosition;
            this.canViewReadOnly = this.isHigherHierarchy;
            this.isFinalApproverWithPendingLower =
                !this.isHigherHierarchy &&
                this.currentUserHierarchyPosition != null &&
                this.finalApproverHierarchyPosition != null &&
                this.currentUserHierarchyPosition == this.finalApproverHierarchyPosition &&
                isAnyValidityOfferLowerLevelSubmitted(q, this.finalApproverHierarchyPosition);
        }

        private Boolean isAnyValidityOfferLowerLevelSubmitted(Quote q, Integer pos) {
            if (pos > 1 && q.SM_Validity_Offer_Status__c == 'Submitted') return true;
            if (pos > 2 && q.CH_Validity_Offer_Status__c == 'Submitted') return true;
            if (pos > 3 && q.GS_Validity_Offer_Status__c == 'Submitted') return true;
            if (pos > 4 && q.BM_Validity_Offer_Status__c == 'Submitted') return true;
            return false;
        }

        private Integer getValidityOfferHierarchyIdx(Quote q, Id approverId) {
            if (approverId == null) return null;
            if (q.Sales_Manager__c == approverId) return 1;
            if (q.Country_Continent_Sales_Head_LOB_Head__c == approverId) return 2;
            if (q.Global_Sales_Head__c == approverId) return 3;
            if (q.Rotex_Board_Member__c == approverId) return 4;
            if (q.Managing_Director_Country_Manager__c == approverId) return 5;
            return null;
        }

        private void setValidityOfferEditPermissions(Quote q, Id currentUserId) {
            Id finalId = q.Final_Validity_Offer_Approver__c;
            if (this.isSmCurrentUser && this.smValidityOfferStatus == 'Submitted') { this.canSmEditComments = true; this.canSmEditStatus = (q.Sales_Manager__c == finalId); }
            if (this.isChCurrentUser && this.chValidityOfferStatus == 'Submitted') { this.canChEditComments = true; this.canChEditStatus = (q.Country_Continent_Sales_Head_LOB_Head__c == finalId); }
            if (this.isGsCurrentUser && this.gsValidityOfferStatus == 'Submitted') { this.canGsEditComments = true; this.canGsEditStatus = (q.Global_Sales_Head__c == finalId); }
            if (this.isBmCurrentUser && this.bmValidityOfferStatus == 'Submitted') { this.canBmEditComments = true; this.canBmEditStatus = (q.Rotex_Board_Member__c == finalId); }
            if (this.isMdCurrentUser && this.mdValidityOfferStatus == 'Submitted') { this.canMdEditComments = true; this.canMdEditStatus = (q.Managing_Director_Country_Manager__c == finalId); }
        }
    }

    public class TotalValueApprovalWrapper {
        @AuraEnabled public String   quoteId;
        @AuraEnabled public String   quoteName;
        @AuraEnabled public String   quoteNumber;
        @AuraEnabled public Decimal  totalValue;
        @AuraEnabled public String   finalTotalValueApprover;
        @AuraEnabled public Boolean  updated;

        @AuraEnabled public String   smName; @AuraEnabled public String smId;
        @AuraEnabled public String   smValueStatus; @AuraEnabled public DateTime smValueDateTime;
        @AuraEnabled public String   smValueComments; @AuraEnabled public Boolean isSmCurrentUser;
        @AuraEnabled public Boolean  canSmEditStatus; @AuraEnabled public Boolean canSmEditComments;
        @AuraEnabled public String   originalSmValueStatus; @AuraEnabled public String originalSmValueComments;

        @AuraEnabled public String   chName; @AuraEnabled public String chId;
        @AuraEnabled public String   chValueStatus; @AuraEnabled public DateTime chValueDateTime;
        @AuraEnabled public String   chValueComments; @AuraEnabled public Boolean isChCurrentUser;
        @AuraEnabled public Boolean  canChEditStatus; @AuraEnabled public Boolean canChEditComments;
        @AuraEnabled public String   originalChValueStatus; @AuraEnabled public String originalChValueComments;

        @AuraEnabled public String   gsName; @AuraEnabled public String gsId;
        @AuraEnabled public String   gsValueStatus; @AuraEnabled public DateTime gsValueDateTime;
        @AuraEnabled public String   gsValueComments; @AuraEnabled public Boolean isGsCurrentUser;
        @AuraEnabled public Boolean  canGsEditStatus; @AuraEnabled public Boolean canGsEditComments;
        @AuraEnabled public String   originalGsValueStatus; @AuraEnabled public String originalGsValueComments;

        @AuraEnabled public String   bmName; @AuraEnabled public String bmId;
        @AuraEnabled public String   bmValueStatus; @AuraEnabled public DateTime bmValueDateTime;
        @AuraEnabled public String   bmValueComments; @AuraEnabled public Boolean isBmCurrentUser;
        @AuraEnabled public Boolean  canBmEditStatus; @AuraEnabled public Boolean canBmEditComments;
        @AuraEnabled public String   originalBmValueStatus; @AuraEnabled public String originalBmValueComments;

        @AuraEnabled public String   mdName; @AuraEnabled public String mdId;
        @AuraEnabled public String   mdValueStatus; @AuraEnabled public DateTime mdValueDateTime;
        @AuraEnabled public String   mdValueComments; @AuraEnabled public Boolean isMdCurrentUser;
        @AuraEnabled public Boolean  canMdEditStatus; @AuraEnabled public Boolean canMdEditComments;
        @AuraEnabled public String   originalMdValueStatus; @AuraEnabled public String originalMdValueComments;

        @AuraEnabled public Integer  currentUserHierarchyPosition;
        @AuraEnabled public Integer  finalApproverHierarchyPosition;
        @AuraEnabled public Boolean  isHigherHierarchy;
        @AuraEnabled public Boolean  canViewReadOnly;
        @AuraEnabled public Boolean  skipSoaRestrictions;
        @AuraEnabled public Boolean  isFinalApproverWithPendingLower;

        public TotalValueApprovalWrapper() {}

        public TotalValueApprovalWrapper(Quote q) {
            Id currentUserId = UserInfo.getUserId();
            this.quoteId                  = q.Id;
            this.quoteName                = q.Name;
            this.quoteNumber              = q.QuoteNumber;
            this.totalValue               = q.Total_Value__c;
            this.finalTotalValueApprover  = getStringFieldSafely(q, 'Final_Total_Value_Approver__c');
            this.updated                  = false;

            this.smId = q.Sales_Manager__c; this.smName = q.Sales_Manager__r != null ? q.Sales_Manager__r.Name : null;
            this.smValueStatus = q.SM_Value_Status__c; this.smValueDateTime = q.SM_Value_Date_Time__c;
            this.smValueComments = q.SM_Value_Comments__c; this.isSmCurrentUser = q.Sales_Manager__c == currentUserId;
            this.originalSmValueStatus = q.SM_Value_Status__c; this.originalSmValueComments = q.SM_Value_Comments__c;

            this.chId = q.Country_Continent_Sales_Head_LOB_Head__c; this.chName = q.Country_Continent_Sales_Head_LOB_Head__r != null ? q.Country_Continent_Sales_Head_LOB_Head__r.Name : null;
            this.chValueStatus = q.CH_Value_Status__c; this.chValueDateTime = q.CH_Value_Date_Time__c;
            this.chValueComments = q.CH_Value_Comments__c; this.isChCurrentUser = q.Country_Continent_Sales_Head_LOB_Head__c == currentUserId;
            this.originalChValueStatus = q.CH_Value_Status__c; this.originalChValueComments = q.CH_Value_Comments__c;

            this.gsId = q.Global_Sales_Head__c; this.gsName = q.Global_Sales_Head__r != null ? q.Global_Sales_Head__r.Name : null;
            this.gsValueStatus = q.GS_Value_Status__c; this.gsValueDateTime = q.GS_Value_Date_Time__c;
            this.gsValueComments = q.GS_Value_Comments__c; this.isGsCurrentUser = q.Global_Sales_Head__c == currentUserId;
            this.originalGsValueStatus = q.GS_Value_Status__c; this.originalGsValueComments = q.GS_Value_Comments__c;

            this.bmId = q.Rotex_Board_Member__c; this.bmName = q.Rotex_Board_Member__r != null ? q.Rotex_Board_Member__r.Name : null;
            this.bmValueStatus = q.BM_Value_Status__c; this.bmValueDateTime = q.BM_Value_Date_Time__c;
            this.bmValueComments = q.BM_Value_Comments__c; this.isBmCurrentUser = q.Rotex_Board_Member__c == currentUserId;
            this.originalBmValueStatus = q.BM_Value_Status__c; this.originalBmValueComments = q.BM_Value_Comments__c;

            this.mdId = q.Managing_Director_Country_Manager__c; this.mdName = q.Managing_Director_Country_Manager__r != null ? q.Managing_Director_Country_Manager__r.Name : null;
            this.mdValueStatus = q.MD_Value_Status__c; this.mdValueDateTime = q.MD_Value_Date_Time__c;
            this.mdValueComments = q.MD_Value_Comments__c; this.isMdCurrentUser = q.Managing_Director_Country_Manager__c == currentUserId;
            this.originalMdValueStatus = q.MD_Value_Status__c; this.originalMdValueComments = q.MD_Value_Comments__c;

            setTotalValueHierarchyPositions(q, currentUserId);
            setTotalValueEditPermissions(q);
        }

        private void setTotalValueHierarchyPositions(Quote q, Id currentUserId) {
            this.currentUserHierarchyPosition   = getTotalValueHierarchyPos(q, currentUserId);
            Id finalId = q.Final_Total_Value_Approver__c;
            this.finalApproverHierarchyPosition = getTotalValueHierarchyPos(q, finalId);
            this.isHigherHierarchy = this.currentUserHierarchyPosition != null &&
                                    this.finalApproverHierarchyPosition != null &&
                                    this.currentUserHierarchyPosition > this.finalApproverHierarchyPosition;
            this.canViewReadOnly = this.isHigherHierarchy;
            this.isFinalApproverWithPendingLower =
                !this.isHigherHierarchy &&
                this.currentUserHierarchyPosition != null &&
                this.finalApproverHierarchyPosition != null &&
                this.currentUserHierarchyPosition == this.finalApproverHierarchyPosition &&
                isAnyTotalValueLowerLevelSubmitted(q, this.finalApproverHierarchyPosition);
        }

        private Boolean isAnyTotalValueLowerLevelSubmitted(Quote q, Integer pos) {
            if (pos > 1 && q.SM_Value_Status__c == 'Submitted') return true;
            if (pos > 2 && q.CH_Value_Status__c == 'Submitted') return true;
            if (pos > 3 && q.GS_Value_Status__c == 'Submitted') return true;
            if (pos > 4 && q.BM_Value_Status__c == 'Submitted') return true;
            return false;
        }

        private void setTotalValueEditPermissions(Quote q) {
            Id finalId = q.Final_Total_Value_Approver__c;
            if (this.isSmCurrentUser && this.smValueStatus == 'Submitted') { this.canSmEditComments = true; this.canSmEditStatus = (q.Sales_Manager__c == finalId); }
            if (this.isChCurrentUser && this.chValueStatus == 'Submitted') { this.canChEditComments = true; this.canChEditStatus = (q.Country_Continent_Sales_Head_LOB_Head__c == finalId); }
            if (this.isGsCurrentUser && this.gsValueStatus == 'Submitted') { this.canGsEditComments = true; this.canGsEditStatus = (q.Global_Sales_Head__c == finalId); }
            if (this.isBmCurrentUser && this.bmValueStatus == 'Submitted') { this.canBmEditComments = true; this.canBmEditStatus = (q.Rotex_Board_Member__c == finalId); }
            if (this.isMdCurrentUser && this.mdValueStatus == 'Submitted') { this.canMdEditComments = true; this.canMdEditStatus = (q.Managing_Director_Country_Manager__c == finalId); }
        }
    }

    public class MinimumOfferApprovalWrapper {
        @AuraEnabled public String   quoteId;
        @AuraEnabled public String   quoteName;
        @AuraEnabled public String   quoteNumber;
        @AuraEnabled public Decimal  totalValue;
        @AuraEnabled public String   finalMinimumOfferValueApprover;
        @AuraEnabled public Boolean  updated;

        @AuraEnabled public String   gsName; @AuraEnabled public String gsId;
        @AuraEnabled public String   gsMinOfferStatus; @AuraEnabled public DateTime gsMinOfferDateTime;
        @AuraEnabled public String   gsMinOfferComments; @AuraEnabled public Boolean isGsCurrentUser;
        @AuraEnabled public Boolean  canGsEditStatus; @AuraEnabled public Boolean canGsEditComments;
        @AuraEnabled public String   originalGsMinOfferStatus; @AuraEnabled public String originalGsMinOfferComments;

        @AuraEnabled public String   bmName; @AuraEnabled public String bmId;
        @AuraEnabled public String   bmMinOfferStatus; @AuraEnabled public DateTime bmMinOfferDateTime;
        @AuraEnabled public String   bmMinOfferComments; @AuraEnabled public Boolean isBmCurrentUser;
        @AuraEnabled public Boolean  canBmEditStatus; @AuraEnabled public Boolean canBmEditComments;
        @AuraEnabled public String   originalBmMinOfferStatus; @AuraEnabled public String originalBmMinOfferComments;

        @AuraEnabled public String   mdName; @AuraEnabled public String mdId;
        @AuraEnabled public String   mdMinOfferStatus; @AuraEnabled public DateTime mdMinOfferDateTime;
        @AuraEnabled public String   mdMinOfferComments; @AuraEnabled public Boolean isMdCurrentUser;
        @AuraEnabled public Boolean  canMdEditStatus; @AuraEnabled public Boolean canMdEditComments;
        @AuraEnabled public String   originalMdMinOfferStatus; @AuraEnabled public String originalMdMinOfferComments;

        @AuraEnabled public Integer  currentUserHierarchyPosition;
        @AuraEnabled public Integer  finalApproverHierarchyPosition;
        @AuraEnabled public Boolean  isHigherHierarchy;
        @AuraEnabled public Boolean  canViewReadOnly;
        @AuraEnabled public Boolean  skipSoaRestrictions;
        @AuraEnabled public Boolean  isFinalApproverWithPendingLower;

        public MinimumOfferApprovalWrapper() {}

        public MinimumOfferApprovalWrapper(Quote q) {
            Id currentUserId = UserInfo.getUserId();
            this.quoteId                        = q.Id;
            this.quoteName                      = q.Name;
            this.quoteNumber                    = q.QuoteNumber;
            this.totalValue                     = q.Total_Value__c;
            this.finalMinimumOfferValueApprover = getStringFieldSafely(q, 'Final_Minimum_Offer_Value_Approver__c');
            this.updated                        = false;

            this.gsId = q.Global_Sales_Head__c; this.gsName = q.Global_Sales_Head__r != null ? q.Global_Sales_Head__r.Name : null;
            this.gsMinOfferStatus = q.GS_Min_Offer_Status__c; this.gsMinOfferDateTime = q.GS_Min_Offer_Date_Time__c;
            this.gsMinOfferComments = q.GS_Min_Offer_Comments__c; this.isGsCurrentUser = q.Global_Sales_Head__c == currentUserId;
            this.originalGsMinOfferStatus = q.GS_Min_Offer_Status__c; this.originalGsMinOfferComments = q.GS_Min_Offer_Comments__c;

            this.bmId = q.Rotex_Board_Member__c; this.bmName = q.Rotex_Board_Member__r != null ? q.Rotex_Board_Member__r.Name : null;
            this.bmMinOfferStatus = q.BM_Min_Offer_Status__c; this.bmMinOfferDateTime = q.BM_Min_Offer_Date_Time__c;
            this.bmMinOfferComments = q.BM_Min_Offer_Comments__c; this.isBmCurrentUser = q.Rotex_Board_Member__c == currentUserId;
            this.originalBmMinOfferStatus = q.BM_Min_Offer_Status__c; this.originalBmMinOfferComments = q.BM_Min_Offer_Comments__c;

            this.mdId = q.Managing_Director_Country_Manager__c; this.mdName = q.Managing_Director_Country_Manager__r != null ? q.Managing_Director_Country_Manager__r.Name : null;
            this.mdMinOfferStatus = q.MD_Min_Offer_Status__c; this.mdMinOfferDateTime = q.MD_Min_Offer_Date_Time__c;
            this.mdMinOfferComments = q.MD_Min_Offer_Comments__c; this.isMdCurrentUser = q.Managing_Director_Country_Manager__c == currentUserId;
            this.originalMdMinOfferStatus = q.MD_Min_Offer_Status__c; this.originalMdMinOfferComments = q.MD_Min_Offer_Comments__c;

            setMinimumOfferHierarchyPositions(q, currentUserId);
            setMinimumOfferEditPermissions(q);
        }

        private void setMinimumOfferHierarchyPositions(Quote q, Id currentUserId) {
            this.currentUserHierarchyPosition   = getMinimumOfferHierarchyPos(q, currentUserId);
            Id finalId = q.Final_Minimum_Offer_Value_Approver__c;
            this.finalApproverHierarchyPosition = getMinimumOfferHierarchyPos(q, finalId);
            this.isHigherHierarchy = this.currentUserHierarchyPosition != null &&
                                    this.finalApproverHierarchyPosition != null &&
                                    this.currentUserHierarchyPosition > this.finalApproverHierarchyPosition;
            this.canViewReadOnly = this.isHigherHierarchy;
            this.isFinalApproverWithPendingLower =
                !this.isHigherHierarchy &&
                this.currentUserHierarchyPosition != null &&
                this.finalApproverHierarchyPosition != null &&
                this.currentUserHierarchyPosition == this.finalApproverHierarchyPosition &&
                isAnyMinimumOfferLowerLevelSubmitted(q, this.finalApproverHierarchyPosition);
        }

        private Boolean isAnyMinimumOfferLowerLevelSubmitted(Quote q, Integer pos) {
            // Min offer levels start at GS (position 3)
            if (pos > 3 && q.GS_Min_Offer_Status__c == 'Submitted') return true;
            if (pos > 4 && q.BM_Min_Offer_Status__c == 'Submitted') return true;
            return false;
        }

        private void setMinimumOfferEditPermissions(Quote q) {
            Id finalId = q.Final_Minimum_Offer_Value_Approver__c;
            if (this.isGsCurrentUser && this.gsMinOfferStatus == 'Submitted') { this.canGsEditComments = true; this.canGsEditStatus = (q.Global_Sales_Head__c == finalId); }
            if (this.isBmCurrentUser && this.bmMinOfferStatus == 'Submitted') { this.canBmEditComments = true; this.canBmEditStatus = (q.Rotex_Board_Member__c == finalId); }
            if (this.isMdCurrentUser && this.mdMinOfferStatus == 'Submitted') { this.canMdEditComments = true; this.canMdEditStatus = (q.Managing_Director_Country_Manager__c == finalId); }
        }
    }
}
