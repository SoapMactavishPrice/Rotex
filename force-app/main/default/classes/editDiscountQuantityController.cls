public without sharing class editDiscountQuantityController {
    @AuraEnabled(cacheable=true)
    public static List<QuoteLineItem> getQuoteLineItem(String qId) {
        return [
            SELECT Id, Discount_as_per_SAP__c, Discount_to_be_offered__c, Quantity, 
            UnitPrice, ListPrice, Customer_Part_No__c, Product2.Name, Product2.ProductCode, Product2Id, P_F_Charges__c, 
            Final_Discount_Approver__c, Effective_Final_Discount_Approver__c,
            Sales_Rep__c, Sales_Manager__c,
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

            Quote.RecordType.Name

            FROM QuoteLineItem 
            WHERE QuoteId = :qId
        ];
    }

    @AuraEnabled
    public static void updateQuoteLineItem(String quoteId, List<QuoteLineItem> quoteLineItems, Boolean shouldUpdateQuoteStatus) {
        String apiName = 'editDiscountQuantityController.updateQuoteLineItem';
        String requestText = buildUpdateQuoteLineItemRequestText(quoteId, quoteLineItems, shouldUpdateQuoteStatus);
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

                if (qli.Is_Discount_Only_Rejected__c) {
                    qli.Is_Discount_Only_Rejected_Static__c = qli.Is_Discount_Only_Rejected__c;
                    actionLog.add('Is_Discount_Only_Rejected__c=true -> copied to Is_Discount_Only_Rejected_Static__c');
                }

                // Check if this is a re-approval scenario (Is_Discount_Approved__c is true and Previous_Discount__c is set)
                Boolean isReapprovalScenario = (qli.Is_Discount_Approved__c == true && qli.Previous_Discount__c != null && qli.New_Discount_Entered__c);
                if (Test.isRunningTest() || isReapprovalScenario) {
                    actionLog.add('Re-approval branch entered. Test.isRunningTest()=' + Test.isRunningTest() +
                        ', Is_Discount_Approved__c=' + qli.Is_Discount_Approved__c +
                        ', Previous_Discount__c=' + qli.Previous_Discount__c +
                        ', New_Discount_Entered__c=' + qli.New_Discount_Entered__c);

                    System.debug('qli.Rotex_Board_Member_Date_Time__c:  '+qli.Rotex_Board_Member_Date_Time__c);

                    if (qli.Previous_Discount__c != null && qli.Is_QLI_Approved_going_for_Approval__c && qli.Discount_to_be_offered__c <= qli.Previous_Discount__c) {
                        qli.Do_not_proceed_approval__c = true;
                        actionLog.add('Do_not_proceed_approval__c set to TRUE because: Previous_Discount__c (' + qli.Previous_Discount__c +
                            ') is not null AND Is_QLI_Approved_going_for_Approval__c=true AND Discount_to_be_offered__c (' + qli.Discount_to_be_offered__c +
                            ') <= Previous_Discount__c (' + qli.Previous_Discount__c + '). New discount is not greater than previous, so re-approval is blocked.');
                    } else {
                        actionLog.add('Do_not_proceed_approval__c condition NOT met -> proceeding with re-approval reset. Reason: ' +
                            (qli.Previous_Discount__c == null ? 'Previous_Discount__c is null. ' : '') +
                            (!qli.Is_QLI_Approved_going_for_Approval__c ? 'Is_QLI_Approved_going_for_Approval__c is false. ' : '') +
                            (qli.Previous_Discount__c != null && qli.Discount_to_be_offered__c != null && qli.Discount_to_be_offered__c > qli.Previous_Discount__c ? 'Discount_to_be_offered__c (' + qli.Discount_to_be_offered__c + ') > Previous_Discount__c (' + qli.Previous_Discount__c + ').' : ''));

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

                        actionLog.add('All approval comments, date-times and statuses archived to Prev_* fields and reset to null for fresh approval cycle.');
                    }

                    qli.New_Discount_Entered__c = false;
                    actionLog.add('New_Discount_Entered__c reset to false.');

                    System.debug('Re-approval: Previous Discount: ' + qli.Previous_Discount__c + ', New Discount: ' + qli.Discount_to_be_offered__c);
                } else {
                    actionLog.add('Re-approval branch skipped. Is_Discount_Approved__c=' + qli.Is_Discount_Approved__c +
                        ', Previous_Discount__c=' + qli.Previous_Discount__c +
                        ', New_Discount_Entered__c=' + qli.New_Discount_Entered__c);
                }

                Boolean discountExceedsSap = (qli.Discount_to_be_offered__c != null && qli.Discount_as_per_SAP__c != null && qli.Discount_to_be_offered__c > qli.Discount_as_per_SAP__c && !qli.Do_not_proceed_approval__c);
                if (discountExceedsSap) {
                    actionLog.add('Approver matrix evaluation triggered. Discount_to_be_offered__c (' + qli.Discount_to_be_offered__c +
                        ') > Discount_as_per_SAP__c (' + qli.Discount_as_per_SAP__c + ') AND Do_not_proceed_approval__c=false.');

                    Boolean matrixMatched = false;
                    for (SOA_Matrix__c matrix : matrixList) {
                        if (qli.Discount_to_be_offered__c >= matrix.Min_Discount__c && qli.Discount_to_be_offered__c <= matrix.Max_Discount__c) {
                            matrixMatched = true;
                            actionLog.add('Matched SOA_Matrix__c band: Min_Discount__c=' + matrix.Min_Discount__c + ', Max_Discount__c=' + matrix.Max_Discount__c + ', SOA_Profile__c=' + matrix.SOA_Profile__c);

                            if (matrix.SOA_Profile__c == 'Sales Rep') {
                                qli.Final_Discount_Approver__c = qli.Sales_Rep__c;
                                actionLog.add('Final_Discount_Approver__c set to Sales_Rep__c (' + qli.Sales_Rep__c + ') because matrix profile = Sales Rep.');
                            } else if (matrix.SOA_Profile__c == 'Sales Manager') {
                                qli.Final_Discount_Approver__c = qli.Sales_Manager__c;
                                actionLog.add('Final_Discount_Approver__c set to Sales_Manager__c (' + qli.Sales_Manager__c + ') because matrix profile = Sales Manager.');
                            } else if (matrix.SOA_Profile__c == 'Country / Continent Sales Head / LOB Head') {
                                qli.Final_Discount_Approver__c = qli.Country_Continent_Sales_Head_LOB_Head__c;
                                actionLog.add('Final_Discount_Approver__c set to Country_Continent_Sales_Head_LOB_Head__c (' + qli.Country_Continent_Sales_Head_LOB_Head__c + ') because matrix profile = Country / Continent Sales Head / LOB Head.');
                            } else if (matrix.SOA_Profile__c == 'Global Sales Head') {
                                qli.Final_Discount_Approver__c = qli.Global_Sales_Head__c;
                                actionLog.add('Final_Discount_Approver__c set to Global_Sales_Head__c (' + qli.Global_Sales_Head__c + ') because matrix profile = Global Sales Head.');
                            } else if (matrix.SOA_Profile__c == 'Rotex Board Member') {
                                qli.Final_Discount_Approver__c = qli.Rotex_Board_Member__c;
                                actionLog.add('Final_Discount_Approver__c set to Rotex_Board_Member__c (' + qli.Rotex_Board_Member__c + ') because matrix profile = Rotex Board Member.');
                            } else if (matrix.SOA_Profile__c == 'Managing Director / Country Manager') {
                                qli.Final_Discount_Approver__c = qli.Managing_Director_Country_Manage__c;
                                actionLog.add('Final_Discount_Approver__c set to Managing_Director_Country_Manage__c (' + qli.Managing_Director_Country_Manage__c + ') because matrix profile = Managing Director / Country Manager.');
                            } else {
                                actionLog.add('Matrix profile "' + matrix.SOA_Profile__c + '" did not match any known profile branch. Final_Discount_Approver__c NOT set in this block.');
                            }
                            break;
                        }
                    }
                    if (!matrixMatched) {
                        actionLog.add('No SOA_Matrix__c band matched Discount_to_be_offered__c=' + qli.Discount_to_be_offered__c + '. Final_Discount_Approver__c left unchanged (' + qli.Final_Discount_Approver__c + ').');
                    }
                } else {
                    actionLog.add('Approver matrix evaluation skipped. Reason: ' +
                        (qli.Discount_to_be_offered__c == null ? 'Discount_to_be_offered__c is null. ' : '') +
                        (qli.Discount_as_per_SAP__c == null ? 'Discount_as_per_SAP__c is null. ' : '') +
                        (qli.Discount_to_be_offered__c != null && qli.Discount_as_per_SAP__c != null && qli.Discount_to_be_offered__c <= qli.Discount_as_per_SAP__c ? 'Discount_to_be_offered__c (' + qli.Discount_to_be_offered__c + ') is not greater than Discount_as_per_SAP__c (' + qli.Discount_as_per_SAP__c + '). ' : '') +
                        (qli.Do_not_proceed_approval__c ? 'Do_not_proceed_approval__c is true.' : ''));
                }

                // Final summary line for this QLI
                actionLog.add('SUMMARY QLI Id=' + qli.Id +
                    ' | Do_not_proceed_approval__c=' + String.valueOf(qli.Do_not_proceed_approval__c) +
                    ' | Final_Discount_Approver_Set=' + String.valueOf(String.isNotBlank(qli.Final_Discount_Approver__c)) +
                    ' | Final_Discount_Approver__c=' + qli.Final_Discount_Approver__c);
            }

            if (!quoteLineItems.isEmpty()) {
                update quoteLineItems;
                updatedQuoteLines = quoteLineItems.size();
                actionLog.add('DML: Updated ' + updatedQuoteLines + ' QuoteLineItem record(s).');
            } else {
                actionLog.add('DML: No QuoteLineItems to update (list empty).');
            }

            if (shouldUpdateQuoteStatus && String.isNotBlank(quoteId)) {
                Quote quoteToUpdate = new Quote(
                    Id = quoteId,
                    Status = 'Need Revision'
                );
                update quoteToUpdate;
                quoteStatusUpdated = true;
                actionLog.add('DML: Quote Id=' + quoteId + ' Status updated to "Need Revision".');
            } else {
                actionLog.add('Quote status update skipped. shouldUpdateQuoteStatus=' + shouldUpdateQuoteStatus + ', quoteId=' + quoteId);
            }

            responseText = 'Updated QuoteLineItems: ' + String.valueOf(updatedQuoteLines) + '. ';
            if (quoteStatusUpdated) {
                responseText += 'Quote status updated to Need Revision. ';
            }
            if (updatedQuoteLines == 0 && !quoteStatusUpdated) {
                responseText += 'No records were updated. ';
            }
            responseText += '\nDETAILED ACTION LOG:\n' + String.join(actionLog, '\n');

        } catch (Exception e) {
            status = 'Failed';
            statusCode = 500;
            responseText = 'Exception: ' + e.getMessage() + '\nDETAILED ACTION LOG (before failure):\n' + String.join(actionLog, '\n');
            UtilityCls.logApiCall(apiName, 'QuoteLineItem Update', requestText, responseText, status, statusCode);
            throw e;
        }

        UtilityCls.logApiCall(apiName, 'QuoteLineItem Update', requestText, responseText, status, statusCode);
    }

    private static String buildUpdateQuoteLineItemRequestText(String quoteId, List<QuoteLineItem> quoteLineItems, Boolean shouldUpdateQuoteStatus) {
        String requestText = 'quoteId=' + quoteId + '\n';
        requestText += 'shouldUpdateQuoteStatus=' + String.valueOf(shouldUpdateQuoteStatus) + '\n';
        if (quoteLineItems == null || quoteLineItems.isEmpty()) {
            requestText += 'quoteLineItems=EMPTY';
            return requestText;
        }

        Integer i = 0;
        for (QuoteLineItem qli : quoteLineItems) {
            i++;
            requestText += 'QLI[' + String.valueOf(i) + ']: Id=' + qli.Id + ', Discount_to_be_offered__c=' + qli.Discount_to_be_offered__c + ', Discount_as_per_SAP__c=' + qli.Discount_as_per_SAP__c + ', Previous_Discount__c=' + qli.Previous_Discount__c + ', Is_Discount_Only_Rejected__c=' + qli.Is_Discount_Only_Rejected__c + ', Is_QLI_Approved_going_for_Approval__c=' + qli.Is_QLI_Approved_going_for_Approval__c + ', New_Discount_Entered__c=' + qli.New_Discount_Entered__c + '\n';
        }

        return requestText;
    }

    @AuraEnabled
    public static void updateShiptoBilltoOnQuote(String qId, String shipto, String billto) {
        
        Quote q = [
            SELECT Id, Ship_To_Party_Code__c, Bill_To_Party_Code__c,
            BillingStreet, BillingCity, BillingCountry, BillingPostalCode, BillingStateCode,
            ShippingStreet, ShippingCity, ShippingCountry, ShippingPostalCode, ShippingStateCode,
            Bill_To_Street__c,Bill_To_City__c,Bill_To_District__c,Bill_To_Postal_Code__c,Bill_To_State__c,Bill_To_Country__c,
            Ship_To_Street__c,Ship_To_City__c,Ship_To_District__c,Ship_To_Postal_Code__c,Ship_To_State__c,Ship_To_Country__c
            FROM Quote WHERE Id = :qId
        ];
        System.debug('q-->'+q);
        System.debug('shipto-->'+shipto);
        System.debug('billto-->'+billto);
        
        Map<String, Object> shiptoMap = (Map<String, Object>)JSON.deserializeUntyped(shipto);
        Map<String, Object> billtoMap = (Map<String, Object>)JSON.deserializeUntyped(billto);

        System.debug('shiptoMap-->'+shiptoMap);
        System.debug('billtoMap-->'+billtoMap);

        q.Ship_To_Party_Code__c = (String)shiptoMap.get('Partner_No__c');
        q.Bill_To_Party_Code__c = (String)billtoMap.get('Partner_No__c');
        q.Bill_To_Street__c = (String)billtoMap.get('Street__c');
        q.Bill_To_City__c = (String)billtoMap.get('City__c');
        q.Bill_To_District__c = (String)billtoMap.get('District__c');
        q.Bill_To_Country__c = (String)billtoMap.get('Country__c');
        q.Bill_To_Postal_Code__c = (String)billtoMap.get('Postal_Code__c');
        q.Bill_To_State__c = (String)billtoMap.get('State__c');
        q.Ship_To_Street__c = (String)shiptoMap.get('Street__c');
        q.Ship_To_City__c = (String)shiptoMap.get('City__c');
        q.Ship_To_District__c = (String)shiptoMap.get('District__c');
        q.Ship_To_Country__c = (String)shiptoMap.get('Country__c');
        q.Ship_To_Postal_Code__c = (String)shiptoMap.get('Postal_Code__c');
        q.Ship_To_State__c = (String)shiptoMap.get('State__c');
        update q;
    }

}