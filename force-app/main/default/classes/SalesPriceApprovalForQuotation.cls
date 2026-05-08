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

        // ── PART A : Quote IDs that have pending DISCOUNT QLIs ────────────
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
        ];

        Set<Id> discountQuoteIds = new Set<Id>();
        for (QuoteLineItem qli : submittedQlis) {
            discountQuoteIds.add(qli.QuoteId);
        }

        // ── PART B : Quote IDs that have a pending WARRANTY approval ───────
        // Mirror the exact filter used by the old getWarrantyApprovals() method.
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

        // ── PART C : Quote IDs that have a pending VALIDITY OF OFFER approval ──
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

        // ── UNION: all quotes relevant to this user ────────────────────────
        Set<Id> allRelevantQuoteIds = new Set<Id>(discountQuoteIds);
        allRelevantQuoteIds.addAll(warrantyQuoteIds);
        allRelevantQuoteIds.addAll(validityOfferQuoteIds);

        if (allRelevantQuoteIds.isEmpty()) {
            throw new AuraHandledException(
                'No Quotation Line Items found with their status as "Pending"'
            );
        }

        // ── Fetch ALL QLIs for discount quotes only ────────────────────────
        // (Warranty-only quotes will simply have an empty lineItems list.)
        List<QuoteLineItem> quoteLineItems = new List<QuoteLineItem>();
        if (!discountQuoteIds.isEmpty()) {
            quoteLineItems = [
                SELECT Approval_Comments__c, Approval_Status__c, Approver__c, CreatedById, ServiceDate,
                       Discount, LastModifiedById, Description, LineNumber, ListPrice,
                       Product2Id, Product2.Name, Quantity, QuoteId, Discount_as_per_SAP__c,
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
                WHERE  QuoteId IN :discountQuoteIds
                       AND Discount_offered_SAP__c = true
            ];
        }

        // ── Fetch all relevant Quote records (includes warranty fields) ────
        Map<Id, Quote> quoteMap = new Map<Id, Quote>([
            SELECT Id, Name, Owner.Email, Owner.Name, OwnerId, Account.Name, QuoteNumber,
                   Account.OwnerId, Sales_Rep__c, Sales_Manager__c, Sales_Manager_Status__c,
                   Sales_Rep_Status__c, Country_Continent_Sales_Head_LOB_Head__c,
                   Country_Continent_Sales_H_LOB_Status__c, Global_Sales_Head__c,
                   Managing_Director_Country_Manager__c, Managing_Director_Status__c,
                   Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                   Total_Value__c, Rev_No__c, Validity_of_Offer__c, Payment_Terms__c,
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
                   Final_Validity_Offer_Approver__c
            FROM   Quote
            WHERE  Id IN :allRelevantQuoteIds
        ]);

        // ── Group QLIs by Quote ────────────────────────────────────────────
        Map<Id, List<QuoteLineItem>> quoteToQliMap = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem eachLine : quoteLineItems) {
            if (!quoteToQliMap.containsKey(eachLine.QuoteId)) {
                quoteToQliMap.put(eachLine.QuoteId, new List<QuoteLineItem>());
            }
            quoteToQliMap.get(eachLine.QuoteId).add(eachLine);
        }

        // ── Build wrapper list for ALL relevant quotes ─────────────────────
        // Warranty-only quotes get an empty List<QuoteLineItem> so they still
        // appear in the UI (showing only the warranty approval section).
        List<QuotationWrapper> quotations = new List<QuotationWrapper>();
        for (Id eachQuoteId : allRelevantQuoteIds) {
            Quote q = quoteMap.get(eachQuoteId);
            if (q == null) continue;

            List<QuoteLineItem> lineItems = quoteToQliMap.containsKey(eachQuoteId)
                ? quoteToQliMap.get(eachQuoteId)
                : new List<QuoteLineItem>();

            quotations.add(new QuotationWrapper(q, lineItems, currentUserId));
        }

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

        // Rows below final approver — auto-approve if comment provided
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

        // Final approver's row — apply chosen status + comment
        if      (finalPos == 1) { q.SM_Warranty_Status__c = wrapper.smWarrantyStatus; q.SM_Warranty_Comments__c = wrapper.smWarrantyComments; q.SM_Warranty_Date_Time__c = DateTime.now(); }
        else if (finalPos == 2) { q.CH_Warranty_Status__c = wrapper.chWarrantyStatus; q.CH_Warranty_Comments__c = wrapper.chWarrantyComments; q.CH_Warranty_Date_Time__c = DateTime.now(); }
        else if (finalPos == 3) { q.GS_Warranty_Status__c = wrapper.gsWarrantyStatus; q.GS_Warranty_Comments__c = wrapper.gsWarrantyComments; q.GS_Warranty_Date_Time__c = DateTime.now(); }
        else if (finalPos == 4) { q.BM_Warranty_Status__c = wrapper.bmWarrantyStatus; q.BM_Warranty_Comments__c = wrapper.bmWarrantyComments; q.BM_Warranty_Date_Time__c = DateTime.now(); }
        else if (finalPos == 5) { q.MD_Warranty_Status__c = wrapper.mdWarrantyStatus; q.MD_Warranty_Comments__c = wrapper.mdWarrantyComments; q.MD_Warranty_Date_Time__c = DateTime.now(); }
    }

    // ── getWarrantyApprovals kept for backward-compatibility but the LWC ──
    // ── no longer needs to call it — getAllQuotations covers it now.      ──
    @AuraEnabled
    public static List<WarrantyApprovalWrapper> getWarrantyApprovals() {
        Id currentUserId = UserInfo.getUserId();

        // Updated query: show ALL quotes where user is ANY approver, not just Submitted status
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

        Quote q = new Quote(Id = wrapper.quoteId);

        // ── Skip-SOA higher-hierarchy path (mirrors applySkippedComments for QLIs) ──
        if (wrapper.skipSoaRestrictions == true &&
            (wrapper.isHigherHierarchy == true || wrapper.isFinalApproverWithPendingLower == true)) {
            applySkippedWarrantyComments(q, wrapper);
            update q;
            return 'Success';
        }

        // ── Normal per-role path (unchanged below) ────────────────────────────────
        Boolean hasChanges = false;
        Id currentUserId   = UserInfo.getUserId();
        Id finalApproverId = wrapper.finalWarrantyApprover;

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
            update q;
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

        Quote q = new Quote(Id = wrapper.quoteId);
        Boolean hasChanges = false;
        Id finalApproverId = wrapper.finalValidityOfferApprover;

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
    public static String updateQuoteLineItem(String quotationListStringObject) {

        List<QuotationWrapper> quotations = parseHeaderAndLine(quotationListStringObject);

        List<QuoteLineItem> quotationLineItemsToBeUpdated = new List<QuoteLineItem>();
        Set<Id> updatedQuoteLineItemIds = new Set<Id>();

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
                       Managing_Director_Comments__c
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
                    Boolean shouldUpdate           = statusChanged || commentChanged;
                    Boolean canSubmitAsFinal       = eachQli.isFinalDiscountApprover == true ||
                                                     canSkipToPreviousFinalApprover(existing, eachQli);

                    if (statusChanged && (existing == null || !canSubmitAsFinal)) {
                        throw new AuraHandledException(
                            'Only the Final Discount Approver can change the approval status of a Quote Line Item.'
                        );
                    }

                    QuoteLineItem qli = new QuoteLineItem();
                    qli.Id = eachQli.quoteLineItemId;
                    applySkippedComments(qli, existing, eachQli);

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

        String body = 'Dear ' + quotation.quoteOwnerName + ',<br/><br/>';
        body += 'The Sales Price has been ' + status.toLowerCase() + ' for the following Quote:<br/><br/>';
        body += 'Quote Name: '  + quotation.quoteName  + '<br/>';
        body += 'Quote Link: '  + quotation.quoteLink  + '</a><br/><br/>';
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

    public class QuotationWrapper {
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
        @AuraEnabled public List<QuotationLineItemWrapper> quoteLineItems;
        @AuraEnabled public Boolean updated;
        @AuraEnabled public WarrantyApprovalWrapper warrantyApproval;
        @AuraEnabled public ValidityOfferApprovalWrapper validityOfferApproval;

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
            this.revNo           = getStringFieldSafely(quote, 'Rev_No__c');
            this.validityOfOffer = getStringFieldSafely(quote, 'Validity_of_Offer__c');
            this.paymentTerms    = getStringFieldSafely(quote, 'Payment_Terms__c');
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

            this.quoteLineItems = new List<QuotationLineItemWrapper>();
            for (QuoteLineItem eachLine : lineItems) {
                this.quoteLineItems.add(new QuotationLineItemWrapper(eachLine));
            }
        }

        private WarrantyApprovalWrapper createWarrantyApprovalIfNeeded(Quote q, Id currentUserId) {
            if (String.isBlank(q.Warranty_Terms_Draft__c) ||
                q.Warranty_Terms_Draft__c == '12 Months from date of supply') {
                return null;
            }
            Boolean isApprover =
                (q.Sales_Manager__c                         == currentUserId && q.SM_Warranty_Status__c == 'Submitted') ||
                (q.Country_Continent_Sales_Head_LOB_Head__c == currentUserId && q.CH_Warranty_Status__c == 'Submitted') ||
                (q.Global_Sales_Head__c                     == currentUserId && q.GS_Warranty_Status__c == 'Submitted') ||
                (q.Rotex_Board_Member__c                    == currentUserId && q.BM_Warranty_Status__c == 'Submitted') ||
                (q.Managing_Director_Country_Manager__c     == currentUserId && q.MD_Warranty_Status__c == 'Submitted');

            if (!isApprover) {
                Integer currentPos = getHierarchyPos(q, currentUserId);
                Integer finalPos   = getHierarchyPos(q, q.Final_Warranty_Terms_Approver__c);
                if (currentPos != null && finalPos != null) {
                    if (currentPos > finalPos) {
                        // Higher hierarchy than final approver → read-only view
                        isApprover = true;
                    } else if (currentPos == finalPos) {
                        // IS the final approver, but a lower level is still Submitted
                        // → show dashboard so they can use Skip SOA
                        isApprover = warrantyAnyLowerSubmitted(q, finalPos);
                    }
                }
            }
            return isApprover ? new WarrantyApprovalWrapper(q) : null;
        }

        private ValidityOfferApprovalWrapper createValidityOfferApprovalIfNeeded(Quote q, Id currentUserId) {
            if (String.isBlank(q.Requested_Validity_Of_Offer__c) ||
                q.Requested_Validity_Of_Offer__c == '30 Days') {
                return null;
            }
            Boolean isApprover =
                (q.Sales_Manager__c                         == currentUserId && q.SM_Validity_Offer_Status__c == 'Submitted') ||
                (q.Country_Continent_Sales_Head_LOB_Head__c == currentUserId && q.CH_Validity_Offer_Status__c == 'Submitted') ||
                (q.Global_Sales_Head__c                     == currentUserId && q.GS_Validity_Offer_Status__c == 'Submitted') ||
                (q.Rotex_Board_Member__c                    == currentUserId && q.BM_Validity_Offer_Status__c == 'Submitted') ||
                (q.Managing_Director_Country_Manager__c     == currentUserId && q.MD_Validity_Offer_Status__c == 'Submitted');

            if (!isApprover) {
                Integer currentPos = getValidityOfferHierarchyPos(q, currentUserId);
                Integer finalPos   = getValidityOfferHierarchyPos(q, q.Final_Validity_Offer_Approver__c);
                if (currentPos != null && finalPos != null) {
                    if (currentPos > finalPos) {
                        isApprover = true;
                    }
                }
            }
            return isApprover ? new ValidityOfferApprovalWrapper(q) : null;
        }
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

    public class QuotationLineItemWrapper {
        @AuraEnabled public String  parentId;
        @AuraEnabled public String  quoteLineItemId;
        @AuraEnabled public String  productId;
        @AuraEnabled public String  productName;
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

            this.salesManagerName        = qli.Sales_Manager__r?.Name;
            this.countryContinentSalesName = qli.Country_Continent_Sales_Head_LOB_Head__r?.Name;
            this.rotexBoardMemberName    = qli.Rotex_Board_Member__r?.Name;
            this.managingDirectorName    = qli.Managing_Director_Country_Manage__r?.Name;
            this.globalSalesHeadName     = qli.Global_Sales_Head__r?.Name;
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
        @AuraEnabled public String   warrantyTerms;
        @AuraEnabled public String   finalWarrantyApprover;
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
            this.warrantyTerms       = q.Warranty_Terms__c;
            this.finalWarrantyApprover = getStringFieldSafely(q, 'Final_Warranty_Terms_Approver__c');
            this.updated             = false;

            this.smId = q.Sales_Manager__c; this.smName = q.Sales_Manager__r?.Name;
            this.smWarrantyStatus = q.SM_Warranty_Status__c; this.smWarrantyDateTime = q.SM_Warranty_Date_Time__c;
            this.smWarrantyComments = q.SM_Warranty_Comments__c; this.isSmCurrentUser = q.Sales_Manager__c == currentUserId;
            this.originalSmWarrantyStatus = q.SM_Warranty_Status__c; this.originalSmWarrantyComments = q.SM_Warranty_Comments__c;

            this.chId = q.Country_Continent_Sales_Head_LOB_Head__c; this.chName = q.Country_Continent_Sales_Head_LOB_Head__r?.Name;
            this.chWarrantyStatus = q.CH_Warranty_Status__c; this.chWarrantyDateTime = q.CH_Warranty_Date_Time__c;
            this.chWarrantyComments = q.CH_Warranty_Comments__c; this.isChCurrentUser = q.Country_Continent_Sales_Head_LOB_Head__c == currentUserId;
            this.originalChWarrantyStatus = q.CH_Warranty_Status__c; this.originalChWarrantyComments = q.CH_Warranty_Comments__c;

            this.gsId = q.Global_Sales_Head__c; this.gsName = q.Global_Sales_Head__r?.Name;
            this.gsWarrantyStatus = q.GS_Warranty_Status__c; this.gsWarrantyDateTime = q.GS_Warranty_Date_Time__c;
            this.gsWarrantyComments = q.GS_Warranty_Comments__c; this.isGsCurrentUser = q.Global_Sales_Head__c == currentUserId;
            this.originalGsWarrantyStatus = q.GS_Warranty_Status__c; this.originalGsWarrantyComments = q.GS_Warranty_Comments__c;

            this.bmId = q.Rotex_Board_Member__c; this.bmName = q.Rotex_Board_Member__r?.Name;
            this.bmWarrantyStatus = q.BM_Warranty_Status__c; this.bmWarrantyDateTime = q.BM_Warranty_Date_Time__c;
            this.bmWarrantyComments = q.BM_Warranty_Comments__c; this.isBmCurrentUser = q.Rotex_Board_Member__c == currentUserId;
            this.originalBmWarrantyStatus = q.BM_Warranty_Status__c; this.originalBmWarrantyComments = q.BM_Warranty_Comments__c;

            this.mdId = q.Managing_Director_Country_Manager__c; this.mdName = q.Managing_Director_Country_Manager__r?.Name;
            this.mdWarrantyStatus = q.MD_Warranty_Status__c; this.mdWarrantyDateTime = q.MD_Warranty_Date_Time__c;
            this.mdWarrantyComments = q.MD_Warranty_Comments__c; this.isMdCurrentUser = q.Managing_Director_Country_Manager__c == currentUserId;
            this.originalMdWarrantyStatus = q.MD_Warranty_Status__c; this.originalMdWarrantyComments = q.MD_Warranty_Comments__c;

            setHierarchyPositions(q, currentUserId);
            setEditPermissions(q, currentUserId);
        }

        private void setHierarchyPositions(Quote q, Id currentUserId) {
            this.currentUserHierarchyPosition   = getWarrantyHierarchyIndex(q, currentUserId);
            Id finalId = q.Final_Warranty_Terms_Approver__c;
            this.finalApproverHierarchyPosition = getWarrantyHierarchyIndex(q, finalId);
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
        @AuraEnabled public String   validityOfOffer;
        @AuraEnabled public String   finalValidityOfferApprover;
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

        public ValidityOfferApprovalWrapper() {}

        public ValidityOfferApprovalWrapper(Quote q) {
            Id currentUserId = UserInfo.getUserId();
            this.quoteId                    = q.Id;
            this.quoteName                  = q.Name;
            this.quoteNumber                = q.QuoteNumber;
            this.requestedValidityOfOffer   = q.Requested_Validity_Of_Offer__c;
            this.validityOfOffer            = q.Validity_of_Offer__c;
            this.finalValidityOfferApprover = getStringFieldSafely(q, 'Final_Validity_Offer_Approver__c');
            this.updated                    = false;

            this.smId = q.Sales_Manager__c; this.smName = q.Sales_Manager__r?.Name;
            this.smValidityOfferStatus = q.SM_Validity_Offer_Status__c; this.smValidityOfferDateTime = q.SM_Validity_Offer_Date_Time__c;
            this.smValidityOfferComments = q.SM_Validity_Offer_Comments__c; this.isSmCurrentUser = q.Sales_Manager__c == currentUserId;
            this.originalSmValidityOfferStatus = q.SM_Validity_Offer_Status__c; this.originalSmValidityOfferComments = q.SM_Validity_Offer_Comments__c;

            this.chId = q.Country_Continent_Sales_Head_LOB_Head__c; this.chName = q.Country_Continent_Sales_Head_LOB_Head__r?.Name;
            this.chValidityOfferStatus = q.CH_Validity_Offer_Status__c; this.chValidityOfferDateTime = q.CH_Validity_Offer_Date_Time__c;
            this.chValidityOfferComments = q.CH_Validity_Offer_Comments__c; this.isChCurrentUser = q.Country_Continent_Sales_Head_LOB_Head__c == currentUserId;
            this.originalChValidityOfferStatus = q.CH_Validity_Offer_Status__c; this.originalChValidityOfferComments = q.CH_Validity_Offer_Comments__c;

            this.gsId = q.Global_Sales_Head__c; this.gsName = q.Global_Sales_Head__r?.Name;
            this.gsValidityOfferStatus = q.GS_Validity_Offer_Status__c; this.gsValidityOfferDateTime = q.GS_Validity_Offer_Date_Time__c;
            this.gsValidityOfferComments = q.GS_Validity_Offer_Comments__c; this.isGsCurrentUser = q.Global_Sales_Head__c == currentUserId;
            this.originalGsValidityOfferStatus = q.GS_Validity_Offer_Status__c; this.originalGsValidityOfferComments = q.GS_Validity_Offer_Comments__c;

            this.bmId = q.Rotex_Board_Member__c; this.bmName = q.Rotex_Board_Member__r?.Name;
            this.bmValidityOfferStatus = q.BM_Validity_Offer_Status__c; this.bmValidityOfferDateTime = q.BM_Validity_Offer_Date_Time__c;
            this.bmValidityOfferComments = q.BM_Validity_Offer_Comments__c; this.isBmCurrentUser = q.Rotex_Board_Member__c == currentUserId;
            this.originalBmValidityOfferStatus = q.BM_Validity_Offer_Status__c; this.originalBmValidityOfferComments = q.BM_Validity_Offer_Comments__c;

            this.mdId = q.Managing_Director_Country_Manager__c; this.mdName = q.Managing_Director_Country_Manager__r?.Name;
            this.mdValidityOfferStatus = q.MD_Validity_Offer_Status__c; this.mdValidityOfferDateTime = q.MD_Validity_Offer_Date_Time__c;
            this.mdValidityOfferComments = q.MD_Validity_Offer_Comments__c; this.isMdCurrentUser = q.Managing_Director_Country_Manager__c == currentUserId;
            this.originalMdValidityOfferStatus = q.MD_Validity_Offer_Status__c; this.originalMdValidityOfferComments = q.MD_Validity_Offer_Comments__c;

            setValidityOfferHierarchyPositions(q, currentUserId);
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
}