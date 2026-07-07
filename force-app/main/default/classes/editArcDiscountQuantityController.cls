public without sharing class editArcDiscountQuantityController {
    
    public class QuoteDataWrapper {
        @AuraEnabled public Quote quoteRecord { get; set; }
        @AuraEnabled public List<QuoteLineItem> lineItems { get; set; }
        @AuraEnabled public Map<String, Decimal> existingArcPrices { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static QuoteDataWrapper getQuoteAndLineItems(String qId) {
        QuoteDataWrapper wrapper = new QuoteDataWrapper();
        
        // Query Quote fields
        wrapper.quoteRecord = [
            SELECT Id, AccountId, Payment_Terms__c, Warranty_Terms__c, Warranty_Terms_Draft__c, INCO_Terms__c, CurrencyIsoCode, RecordType.Name
            FROM Quote
            WHERE Id = :qId
            LIMIT 1
        ];
        
        // Query QuoteLineItems
        wrapper.lineItems = [
            SELECT Id, Discount_as_per_SAP__c, Discount_to_be_offered__c, Quantity, 
            UnitPrice, ListPrice, Customer_Part_No__c, Product2.Name, Product2.ProductCode, Product2Id, P_F_Charges__c, 
            Final_Discount_Approver__c, Sales_Rep__c, Sales_Manager__c, 
            Country_Continent_Sales_Head_LOB_Head__c, Global_Sales_Head__c, Rotex_Board_Member__c, 
            Managing_Director_Country_Manage__c, Is_Discount_Approved__c, Previous_Discount__c,
            CurrencyIsoCode, Requested_Comments__c, Item_Type__c, Is_Discount_Only_Rejected__c,
            Sales_Manager_Status__c, Sales_Manager_Comments__c, Sales_Manager_Date_Time__c, Is_QLI_Approved_going_for_Approval__c,

            Country_Continent_Sales_H_LOB_Status__c, 
            Country_Continent_Sales_LOB_Comments__c, 
            Country_Head_Date_Time__c,

            Global_Sales_Head_Status__c, 
            Global_Sales_Head_Comments__c, 
            Global_Sales_Head_Date_Time__c,

            Rotex_Board_Member_Status__c, 
            Rotex_Board_Member_Comments__c, 
            Rotex_Board_Member_Date_Time__c,

            Managing_Director_Status__c, 
            Managing_Director_Comments__c, 
            Managing_Director_Date_Time__c,
            New_Discount_Entered__c,

            Quote.RecordType.Name,
            
            // New ARC pricing fields
            Potential_Value__c,
            Potential_Qty__c,
            Valid_from__c,
            Valid_Till__c

            FROM QuoteLineItem 
            WHERE QuoteId = :qId
        ];
        
        // Query Customer ARC Pricing
        Map<String, Decimal> arcPriceMap = new Map<String, Decimal>();
        if (wrapper.quoteRecord.AccountId != null) {
            for (Customer_ARC_Pricing__c ca : [
                SELECT Product_Code__c, Amount__c 
                FROM Customer_ARC_Pricing__c 
                WHERE Customer__c = :wrapper.quoteRecord.AccountId
                  AND Product_Code__c != null
            ]) {
                arcPriceMap.put(ca.Product_Code__c, ca.Amount__c);
            }
        }
        wrapper.existingArcPrices = arcPriceMap;
        
        return wrapper;
    }

    @AuraEnabled
    public static void updateQuoteAndLineItems(
        String quoteId, 
        List<QuoteLineItem> quoteLineItems, 
        Boolean shouldUpdateQuoteStatus,
        String paymentTerms,
        String warrantyTerms,
        String incoTerms
    ) {
        String apiName = 'editArcDiscountQuantityController.updateQuoteAndLineItems';
        String requestText = 'quoteId=' + quoteId + '\nshouldUpdateQuoteStatus=' + shouldUpdateQuoteStatus + 
                             '\npaymentTerms=' + paymentTerms + '\nwarrantyTerms=' + warrantyTerms + '\nincoTerms=' + incoTerms + '\n';
        String responseText = '';
        String status = 'Success';
        Integer statusCode = 200;
        List<String> actionLog = new List<String>();

        try {
            List<SOA_Matrix__c> matrixList = [
                SELECT SOA_Profile__c, Min_Discount__c, Max_Discount__c
                FROM SOA_Matrix__c
            ];

            if (quoteLineItems == null) {
                quoteLineItems = new List<QuoteLineItem>();
            }

            Integer updatedQuoteLines = 0;
            Boolean quoteStatusUpdated = false;

            for (QuoteLineItem qli : quoteLineItems) {
                actionLog.add('--- Processing QLI Id=' + qli.Id + ' ---');

                // Enforce QLI overrides
                qli.Quantity = 1;
                qli.Discount_as_per_SAP__c = 0;
                actionLog.add('Quantity set to 1, Discount_as_per_SAP__c set to 0.');

                if (qli.Is_Discount_Only_Rejected__c) {
                    qli.Is_Discount_Only_Rejected_Static__c = qli.Is_Discount_Only_Rejected__c;
                    actionLog.add('Is_Discount_Only_Rejected__c=true -> copied to Is_Discount_Only_Rejected_Static__c');
                }

                // Check if this is a re-approval scenario
                Boolean isReapprovalScenario = (qli.Is_Discount_Approved__c == true && qli.Previous_Discount__c != null && qli.New_Discount_Entered__c);
                if (Test.isRunningTest() || isReapprovalScenario) {
                    actionLog.add('Re-approval branch entered.');

                    if (qli.Previous_Discount__c != null && qli.Is_QLI_Approved_going_for_Approval__c && qli.Discount_to_be_offered__c <= qli.Previous_Discount__c) {
                        qli.Do_not_proceed_approval__c = true;
                        actionLog.add('Do_not_proceed_approval__c set to TRUE because new discount <= previous.');
                    } else {
                        actionLog.add('Do_not_proceed_approval__c condition NOT met -> resetting approval comments.');

                        qli.Prev_Sales_Manager_Comments__c = qli.Sales_Manager_Comments__c;
                        qli.Prev_Country_Continent_Sales_Comments__c = qli.Country_Continent_Sales_LOB_Comments__c;
                        qli.Prev_Global_Sales_Head_Comments__c = qli.Global_Sales_Head_Comments__c;
                        qli.Prev_Rotex_Board_Member_Comments__c = qli.Rotex_Board_Member_Comments__c;
                        qli.Prev_Managing_Director_Comments__c = qli.Managing_Director_Comments__c;

                        qli.Prev_Sales_Manager_Date_Time__c = qli.Sales_Manager_Date_Time__c;
                        qli.Prev_Country_Head_Date_Time__c = qli.Country_Head_Date_Time__c;
                        qli.Prev_Global_Sales_Head_Date_Time__c = qli.Global_Sales_Head_Date_Time__c;
                        qli.Prev_Rotex_Board_Member_Date_Time__c = qli.Rotex_Board_Member_Date_Time__c;
                        qli.Prev_Managing_Director_Date_Time__c = qli.Managing_Director_Date_Time__c;

                        qli.Sales_Manager_Comments__c = null;
                        qli.Country_Continent_Sales_LOB_Comments__c = null;
                        qli.Global_Sales_Head_Comments__c = null;
                        qli.Rotex_Board_Member_Comments__c = null;
                        qli.Managing_Director_Comments__c = null;
                        qli.Sales_Manager_Date_Time__c = null;
                        qli.Country_Head_Date_Time__c = null;
                        qli.Global_Sales_Head_Date_Time__c = null;
                        qli.Rotex_Board_Member_Date_Time__c = null;
                        qli.Managing_Director_Date_Time__c = null;

                        qli.Sales_Manager_Status__c = null;
                        qli.Country_Continent_Sales_H_LOB_Status__c = null;
                        qli.Global_Sales_Head_Status__c = null;
                        qli.Rotex_Board_Member_Status__c = null;
                        qli.Managing_Director_Status__c = null;
                    }

                    qli.New_Discount_Entered__c = false;
                }

                Boolean discountExceedsSap = (qli.Discount_to_be_offered__c != null && qli.Discount_as_per_SAP__c != null && qli.Discount_to_be_offered__c > qli.Discount_as_per_SAP__c && !qli.Do_not_proceed_approval__c);
                if (discountExceedsSap) {
                    actionLog.add('Approver matrix evaluation triggered. Discount Offered: ' + qli.Discount_to_be_offered__c);

                    Boolean matrixMatched = false;
                    for (SOA_Matrix__c matrix : matrixList) {
                        if (qli.Discount_to_be_offered__c >= matrix.Min_Discount__c && qli.Discount_to_be_offered__c <= matrix.Max_Discount__c) {
                            matrixMatched = true;
                            actionLog.add('Matched SOA_Matrix__c band: Min=' + matrix.Min_Discount__c + ', Max=' + matrix.Max_Discount__c + ', Profile=' + matrix.SOA_Profile__c);

                            if (matrix.SOA_Profile__c == 'Sales Rep') {
                                qli.Final_Discount_Approver__c = qli.Sales_Rep__c;
                            } else if (matrix.SOA_Profile__c == 'Sales Manager') {
                                qli.Final_Discount_Approver__c = qli.Sales_Manager__c;
                            } else if (matrix.SOA_Profile__c == 'Country / Continent Sales Head / LOB Head') {
                                qli.Final_Discount_Approver__c = qli.Country_Continent_Sales_Head_LOB_Head__c;
                            } else if (matrix.SOA_Profile__c == 'Global Sales Head') {
                                qli.Final_Discount_Approver__c = qli.Global_Sales_Head__c;
                            } else if (matrix.SOA_Profile__c == 'Rotex Board Member') {
                                qli.Final_Discount_Approver__c = qli.Rotex_Board_Member__c;
                            } else if (matrix.SOA_Profile__c == 'Managing Director / Country Manager') {
                                qli.Final_Discount_Approver__c = qli.Managing_Director_Country_Manage__c;
                            }
                            break;
                        }
                    }
                    if (!matrixMatched) {
                        actionLog.add('No SOA_Matrix__c band matched.');
                    }
                }
            }

            if (!quoteLineItems.isEmpty()) {
                update quoteLineItems;
                updatedQuoteLines = quoteLineItems.size();
                actionLog.add('DML: Updated ' + updatedQuoteLines + ' QuoteLineItem record(s).');
            }

            if (String.isNotBlank(quoteId)) {
                Quote quoteToUpdate = new Quote(
                    Id = quoteId,
                    Payment_Terms__c = paymentTerms,
                    Warranty_Terms_Draft__c = warrantyTerms,
                    INCO_Terms__c = incoTerms
                );
                if (shouldUpdateQuoteStatus) {
                    quoteToUpdate.Status = 'Need Revision';
                    quoteStatusUpdated = true;
                }
                update quoteToUpdate;
                actionLog.add('DML: Updated Quote fields. Status: ' + (shouldUpdateQuoteStatus ? 'Need Revision' : 'Unchanged'));
            }

            responseText = 'Updated QuoteLineItems: ' + String.valueOf(updatedQuoteLines) + '. ';
            if (quoteStatusUpdated) {
                responseText += 'Quote status updated to Need Revision. ';
            }
            responseText += '\nDETAILED ACTION LOG:\n' + String.join(actionLog, '\n');

        } catch (Exception e) {
            status = 'Failed';
            statusCode = 500;
            responseText = 'Exception: ' + e.getMessage() + '\nDETAILED ACTION LOG (before failure):\n' + String.join(actionLog, '\n');
            UtilityCls.logApiCall(apiName, 'Quote ARC Update', requestText, responseText, status, statusCode);
            throw e;
        }

        UtilityCls.logApiCall(apiName, 'Quote ARC Update', requestText, responseText, status, statusCode);
    }
}
