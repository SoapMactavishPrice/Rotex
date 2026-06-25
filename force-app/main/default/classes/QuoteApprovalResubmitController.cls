public without sharing class QuoteApprovalResubmitController {

    private static final String TYPE_WARRANTY = 'WARRANTY';
    private static final String TYPE_VALIDITY = 'VALIDITY';
    private static final String TYPE_TOTAL_VALUE = 'TOTAL_VALUE';

    private static final String STATUS_SUBMITTED = 'Submitted';
    private static final String STATUS_REJECTED = 'Rejected';

    private static final String PROFILE_SALES_REP = 'Sales Rep';
    private static final String PROFILE_SALES_MANAGER = 'Sales Manager';
    private static final String PROFILE_COUNTRY_HEAD = 'Country / Continent Sales Head / LOB Head';
    private static final String PROFILE_GLOBAL_SALES_HEAD = 'Global Sales Head';
    private static final String PROFILE_ROTEX_BOARD_MEMBER = 'Rotex Board Member';
    private static final String PROFILE_MANAGING_DIRECTOR = 'Managing Director / Country Manager';

    @AuraEnabled(cacheable=true)
    public static ResubmitData getResubmittableApprovals(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }

        Quote q = getQuote(quoteId);
        assertCanResubmit(q);

        ResubmitData data = new ResubmitData();
        data.quoteId = q.Id;
        data.quoteNumber = q.QuoteNumber;
        data.options = new List<ApprovalOption>();

        if (isWarrantyRejected(q)) {
            data.options.add(new ApprovalOption(
                TYPE_WARRANTY,
                'Warranty Terms',
                q.Warranty_Terms_Draft__c,
                getRejectedLevelLabel(q, TYPE_WARRANTY)
            ));
        }
        if (isValidityRejected(q)) {
            data.options.add(new ApprovalOption(
                TYPE_VALIDITY,
                'Validity Of Offer',
                q.Requested_Validity_Of_Offer__c,
                getRejectedLevelLabel(q, TYPE_VALIDITY)
            ));
        }
        if (isTotalValueRejected(q)) {
            data.options.add(new ApprovalOption(
                TYPE_TOTAL_VALUE,
                'Total Value',
                q.Total_Value__c == null ? null : String.valueOf(q.Total_Value__c),
                getRejectedLevelLabel(q, TYPE_TOTAL_VALUE)
            ));
        }

        return data;
    }

    @AuraEnabled
    public static String resubmitApproval(Id quoteId, String approvalType) {
        if (String.isBlank(approvalType)) {
            throw new AuraHandledException('Select at least one approval type to resubmit.');
        }
        return resubmitApprovals(quoteId, new List<String>{ approvalType });
    }

    @AuraEnabled
    public static String resubmitApprovals(Id quoteId, List<String> approvalTypes) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        if (approvalTypes == null || approvalTypes.isEmpty()) {
            throw new AuraHandledException('Select at least one approval type to resubmit.');
        }

        Quote q = getQuote(quoteId);
        assertCanResubmit(q);

        Quote updateQuote = new Quote(Id = q.Id);
        Boolean bypassWarrantyReset = false;
        Boolean bypassValidityReset = false;

        Set<String> normalizedApprovalTypes = new Set<String>();
        for (String approvalType : approvalTypes) {
            if (String.isBlank(approvalType)) continue;
            normalizedApprovalTypes.add(approvalType.trim().toUpperCase());
        }

        if (normalizedApprovalTypes.isEmpty()) {
            throw new AuraHandledException('Select at least one approval type to resubmit.');
        }

        for (String approvalType : normalizedApprovalTypes) {
            if (approvalType == TYPE_WARRANTY) {
                if (!isWarrantyRejected(q)) {
                    throw new AuraHandledException('Warranty Terms approval is not rejected.');
                }
                resetWarrantyForResubmit(q, updateQuote);
                bypassWarrantyReset = true;
            } else if (approvalType == TYPE_VALIDITY) {
                if (!isValidityRejected(q)) {
                    throw new AuraHandledException('Validity Of Offer approval is not rejected.');
                }
                resetValidityForResubmit(q, updateQuote);
                bypassValidityReset = true;
            } else if (approvalType == TYPE_TOTAL_VALUE) {
                if (!isTotalValueRejected(q)) {
                    throw new AuraHandledException('Total Value approval is not rejected.');
                }
                resetTotalValueForResubmit(q, updateQuote);
            } else {
                throw new AuraHandledException('Unsupported approval type.');
            }
        }

        QuoteWarrantyApprovalHandler.bypassDraftApprovalReset = bypassWarrantyReset;
        QuoteValidityOfferApprovalHandler.bypassRequestedValidityApprovalReset = bypassValidityReset;
        try {
            update updateQuote;
        } finally {
            QuoteWarrantyApprovalHandler.bypassDraftApprovalReset = false;
            QuoteValidityOfferApprovalHandler.bypassRequestedValidityApprovalReset = false;
        }

        return 'Success';
    }

    private static Quote getQuote(Id quoteId) {
        return [
            SELECT Id, QuoteNumber, OwnerId, CreatedById,
                   Warranty_Terms_Draft__c,
                   Requested_Validity_Of_Offer__c,
                   Total_Value__c,
                   Sales_Manager__c, Sales_Manager__r.DelegatedApproverId,
                   Country_Continent_Sales_Head_LOB_Head__c, Country_Continent_Sales_Head_LOB_Head__r.DelegatedApproverId,
                   Global_Sales_Head__c, Global_Sales_Head__r.DelegatedApproverId,
                   Rotex_Board_Member__c, Rotex_Board_Member__r.DelegatedApproverId,
                   Managing_Director_Country_Manager__c, Managing_Director_Country_Manager__r.DelegatedApproverId,
                   Final_Warranty_Terms_Approver__c,
                   Final_Validity_Offer_Approver__c,
                   Final_Total_Value_Approver__c,
                   SM_Warranty_Status__c, SM_Warranty_Date_Time__c, SM_Warranty_Comments__c,
                   CH_Warranty_Status__c, CH_Warranty_Date_Time__c, CH_Warranty_Comments__c,
                   GS_Warranty_Status__c, GS_Warranty_Date_Time__c, GS_Warranty_Comments__c,
                   BM_Warranty_Status__c, BM_Warranty_Date_Time__c, BM_Warranty_Comments__c,
                   MD_Warranty_Status__c, MD_Warranty_Date_Time__c, MD_Warranty_Comments__c,
                   SM_Validity_Offer_Status__c, SM_Validity_Offer_Date_Time__c, SM_Validity_Offer_Comments__c,
                   CH_Validity_Offer_Status__c, CH_Validity_Offer_Date_Time__c, CH_Validity_Offer_Comments__c,
                   GS_Validity_Offer_Status__c, GS_Validity_Offer_Date_Time__c, GS_Validity_Offer_Comments__c,
                   BM_Validity_Offer_Status__c, BM_Validity_Offer_Date_Time__c, BM_Validity_Offer_Comments__c,
                   MD_Validity_Offer_Status__c, MD_Validity_Offer_Date_Time__c, MD_Validity_Offer_Comments__c,
                   Is_Total_Value_Approved__c,
                   SM_Value_Status__c, SM_Value_Date_Time__c, SM_Value_Comments__c,
                   CH_Value_Status__c, CH_Value_Date_Time__c, CH_Value_Comments__c,
                   GS_Value_Status__c, GS_Value_Date_Time__c, GS_Value_Comments__c,
                   BM_Value_Status__c, BM_Value_Date_Time__c, BM_Value_Comments__c,
                   MD_Value_Status__c, MD_Value_Date_Time__c, MD_Value_Comments__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
    }

    private static void assertCanResubmit(Quote q) {
        Id currentUserId = UserInfo.getUserId();
        if (q.OwnerId == currentUserId || q.CreatedById == currentUserId) {
            return;
        }

        List<User> crrUsers = [SELECT Id FROM User WHERE Profile.Name = 'CRR'];
        if (!crrUsers.isEmpty()) {
            for (User crrUser : crrUsers) {
                if (currentUserId == crrUser.Id) {
                    return;
                }
            }
        }

        throw new AuraHandledException('Only the Quote Owner/Quote Created By user/CRR Profile users can resubmit this approval.');
    }

    private static void resetWarrantyForResubmit(Quote source, Quote target) {
        String finalProfile = determineWarrantyFinalApproverProfile(source.Warranty_Terms_Draft__c);
        target.Final_Warranty_Terms_Approver__c = resolveApproverUserId(source, finalProfile);

        target.SM_Warranty_Status__c = STATUS_SUBMITTED;
        target.SM_Warranty_Date_Time__c = null;
        target.CH_Warranty_Status__c = null;
        target.CH_Warranty_Date_Time__c = null;
        target.GS_Warranty_Status__c = null;
        target.GS_Warranty_Date_Time__c = null;
        target.BM_Warranty_Status__c = null;
        target.BM_Warranty_Date_Time__c = null;
        target.MD_Warranty_Status__c = null;
        target.MD_Warranty_Date_Time__c = null;
    }

    private static void resetValidityForResubmit(Quote source, Quote target) {
        String finalProfile = determineValidityFinalApproverProfile(source.Requested_Validity_Of_Offer__c);
        target.Final_Validity_Offer_Approver__c = resolveApproverUserId(source, finalProfile);

        target.SM_Validity_Offer_Status__c = STATUS_SUBMITTED;
        target.SM_Validity_Offer_Date_Time__c = null;
        target.CH_Validity_Offer_Status__c = null;
        target.CH_Validity_Offer_Date_Time__c = null;
        target.GS_Validity_Offer_Status__c = null;
        target.GS_Validity_Offer_Date_Time__c = null;
        target.BM_Validity_Offer_Status__c = null;
        target.BM_Validity_Offer_Date_Time__c = null;
        target.MD_Validity_Offer_Status__c = null;
        target.MD_Validity_Offer_Date_Time__c = null;
    }

    private static void resetTotalValueForResubmit(Quote source, Quote target) {
        String finalProfile = determineTotalValueFinalApproverProfile(source.Total_Value__c);
        target.Is_Total_Value_Approved__c = false;
        target.Final_Total_Value_Approver__c = finalProfile == PROFILE_SALES_REP
            ? null
            : resolveApproverUserId(source, finalProfile);

        if (finalProfile == PROFILE_SALES_REP) {
            target.Is_Total_Value_Approved__c = true;
            target.SM_Value_Status__c = null;
        } else {
            target.SM_Value_Status__c = STATUS_SUBMITTED;
        }
        target.SM_Value_Date_Time__c = null;
        target.CH_Value_Status__c = null;
        target.CH_Value_Date_Time__c = null;
        target.GS_Value_Status__c = null;
        target.GS_Value_Date_Time__c = null;
        target.BM_Value_Status__c = null;
        target.BM_Value_Date_Time__c = null;
        target.MD_Value_Status__c = null;
        target.MD_Value_Date_Time__c = null;
    }

    private static String determineWarrantyFinalApproverProfile(String warrantyTerms) {
        String normalizedTerm;

        if (warrantyTerms == '24 Months from date of supply') normalizedTerm = '24 Months';
        else if (warrantyTerms == '30 Months from date of supply') normalizedTerm = '30 Months';
        else if (warrantyTerms == '36 Months from date of supply') normalizedTerm = '36 Months';
        else if (warrantyTerms == '48 Months from date of supply') normalizedTerm = '48 Months';
        else if (warrantyTerms == 'More than 48 Months from date of supply') normalizedTerm = 'More than 48 Months';

        if (String.isNotBlank(normalizedTerm)) {
            List<SOA_Matrix__c> rows = [
                SELECT SOA_Profile__c
                FROM SOA_Matrix__c
                WHERE Warranty_Terms__c = :normalizedTerm
                LIMIT 1
            ];
            if (!rows.isEmpty() && String.isNotBlank(rows[0].SOA_Profile__c)) {
                return rows[0].SOA_Profile__c;
            }
        }

        return PROFILE_SALES_MANAGER;
    }

    private static String determineValidityFinalApproverProfile(String validityOffer) {
        if (String.isNotBlank(validityOffer)) {
            List<SOA_Matrix__c> rows = [
                SELECT SOA_Profile__c
                FROM SOA_Matrix__c
                WHERE Validity_of_Offer__c = :validityOffer
                LIMIT 1
            ];
            if (!rows.isEmpty() && String.isNotBlank(rows[0].SOA_Profile__c)) {
                return rows[0].SOA_Profile__c;
            }
        }

        return PROFILE_SALES_MANAGER;
    }

    private static String determineTotalValueFinalApproverProfile(Decimal totalValue) {
        if (totalValue != null) {
            for (SOA_Matrix__c row : [
                SELECT SOA_Profile__c, Min_Total_Value__c, Max_Total_Value__c
                FROM SOA_Matrix__c
                WHERE Min_Total_Value__c != null
                  AND Max_Total_Value__c != null
            ]) {
                if (totalValue > row.Min_Total_Value__c && totalValue <= row.Max_Total_Value__c &&
                    String.isNotBlank(row.SOA_Profile__c)) {
                    return row.SOA_Profile__c;
                }
            }
        }

        return PROFILE_SALES_MANAGER;
    }

    private static Id resolveApproverUserId(Quote q, String profileName) {
        if (profileName == PROFILE_SALES_MANAGER) return q.Sales_Manager__c;
        if (profileName == PROFILE_COUNTRY_HEAD) return q.Country_Continent_Sales_Head_LOB_Head__c;
        if (profileName == PROFILE_GLOBAL_SALES_HEAD) return q.Global_Sales_Head__c;
        if (profileName == PROFILE_ROTEX_BOARD_MEMBER) return q.Rotex_Board_Member__c;
        if (profileName == PROFILE_MANAGING_DIRECTOR) return q.Managing_Director_Country_Manager__c;
        return q.Sales_Manager__c;
    }

    private static Boolean isWarrantyRejected(Quote q) {
        return q.SM_Warranty_Status__c == STATUS_REJECTED ||
            q.CH_Warranty_Status__c == STATUS_REJECTED ||
            q.GS_Warranty_Status__c == STATUS_REJECTED ||
            q.BM_Warranty_Status__c == STATUS_REJECTED ||
            q.MD_Warranty_Status__c == STATUS_REJECTED;
    }

    private static Boolean isValidityRejected(Quote q) {
        return q.SM_Validity_Offer_Status__c == STATUS_REJECTED ||
            q.CH_Validity_Offer_Status__c == STATUS_REJECTED ||
            q.GS_Validity_Offer_Status__c == STATUS_REJECTED ||
            q.BM_Validity_Offer_Status__c == STATUS_REJECTED ||
            q.MD_Validity_Offer_Status__c == STATUS_REJECTED;
    }

    private static Boolean isTotalValueRejected(Quote q) {
        return q.SM_Value_Status__c == STATUS_REJECTED ||
            q.CH_Value_Status__c == STATUS_REJECTED ||
            q.GS_Value_Status__c == STATUS_REJECTED ||
            q.BM_Value_Status__c == STATUS_REJECTED ||
            q.MD_Value_Status__c == STATUS_REJECTED;
    }

    private static String getRejectedLevelLabel(Quote q, String approvalType) {
        if (approvalType == TYPE_WARRANTY) {
            return rejectedLevel(q.SM_Warranty_Status__c, q.CH_Warranty_Status__c, q.GS_Warranty_Status__c, q.BM_Warranty_Status__c, q.MD_Warranty_Status__c);
        }
        if (approvalType == TYPE_VALIDITY) {
            return rejectedLevel(q.SM_Validity_Offer_Status__c, q.CH_Validity_Offer_Status__c, q.GS_Validity_Offer_Status__c, q.BM_Validity_Offer_Status__c, q.MD_Validity_Offer_Status__c);
        }
        return rejectedLevel(q.SM_Value_Status__c, q.CH_Value_Status__c, q.GS_Value_Status__c, q.BM_Value_Status__c, q.MD_Value_Status__c);
    }

    private static String rejectedLevel(String sm, String ch, String gs, String bm, String md) {
        if (sm == STATUS_REJECTED) return 'Sales Manager';
        if (ch == STATUS_REJECTED) return 'Country / Continent Sales Head / LOB Head';
        if (gs == STATUS_REJECTED) return 'Global Sales Head';
        if (bm == STATUS_REJECTED) return 'Rotex Board Member';
        if (md == STATUS_REJECTED) return 'Managing Director / Country Manager';
        return null;
    }

    public class ResubmitData {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public List<ApprovalOption> options;
    }

    public class ApprovalOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public String currentValue;
        @AuraEnabled public String rejectedLevel;

        public ApprovalOption(String value, String label, String currentValue, String rejectedLevel) {
            this.value = value;
            this.label = label;
            this.currentValue = currentValue;
            this.rejectedLevel = rejectedLevel;
        }
    }
}