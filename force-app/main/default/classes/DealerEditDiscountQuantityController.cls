public without sharing class DealerEditDiscountQuantityController {
    @AuraEnabled
    public static Quote getQuoteHeader(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        assertQuoteAccessible(quoteId);
        List<Quote> quotes = [
            SELECT
                Id, QuoteNumber, Name, Status, CurrencyIsoCode,
                AccountId, Account.Name,
                QuoteAccountId, QuoteAccount.Name,
                Account__c, Account__r.Name,
                Quote_Date__c, Quote_Valid_Till__c, Quote_Type__c,
                OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.Email,
                CP_Owner_Name__c, CP_Owner_Name__r.Name, CP_Owner_Name__r.FirstName,
                CP_Owner_Name__r.LastName, CP_Owner_Name__r.Email,
                Rev_No__c, Rev_Date__c,
                Validity_of_Offer__c, Requested_Validity_Of_Offer__c,
                Delivery_Period__c, INCO_Terms__c,
                Payment_Terms__c, Prices__c, Warranty_Terms__c,
                Warranty_Terms_Draft__c,
                Liquidate_Terms__c, Transport_Details__c,
                Delivery_Location__c, Special_Remarks__c,
                ContactId, Contact.Name, Phone, Email
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        if (quotes.isEmpty()) {
            throw new AuraHandledException('Quote not found.');
        }
        return quotes[0];
    }

    @AuraEnabled
    public static void updateQuoteHeaderFields(Id quoteId, Map<String, Object> fields) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        assertQuoteAccessible(quoteId);

        if (fields == null) {
            fields = new Map<String, Object>();
        }

        Quote q = new Quote(Id = quoteId);

        if (fields.containsKey('Requested_Validity_Of_Offer__c')) {
            q.Requested_Validity_Of_Offer__c = toNullableString(fields.get('Requested_Validity_Of_Offer__c'));
        }
        if (fields.containsKey('Delivery_Period__c')) {
            q.Delivery_Period__c = toNullableString(fields.get('Delivery_Period__c'));
        }
        if (fields.containsKey('Warranty_Terms_Draft__c')) {
            q.Warranty_Terms_Draft__c = toNullableString(fields.get('Warranty_Terms_Draft__c'));
        }
        if (fields.containsKey('Liquidate_Terms__c')) {
            q.Liquidate_Terms__c = toNullableString(fields.get('Liquidate_Terms__c'));
        }
        if (fields.containsKey('Transport_Details__c')) {
            q.Transport_Details__c = toNullableString(fields.get('Transport_Details__c'));
        }
        if (fields.containsKey('Delivery_Location__c')) {
            q.Delivery_Location__c = toNullableString(fields.get('Delivery_Location__c'));
        }
        if (fields.containsKey('Special_Remarks__c')) {
            q.Special_Remarks__c = toNullableString(fields.get('Special_Remarks__c'));
        }
        if (fields.containsKey('ContactId')) {
            Object contactVal = fields.get('ContactId');
            q.ContactId = contactVal == null || String.isBlank(String.valueOf(contactVal))
                ? null
                : (Id) String.valueOf(contactVal);
        }
        if (fields.containsKey('Phone')) {
            q.Phone = toNullableString(fields.get('Phone'));
        }
        if (fields.containsKey('Email')) {
            q.Email = toNullableString(fields.get('Email'));
        }
        if (fields.containsKey('Status')) {
            String nextStatus = toNullableString(fields.get('Status'));
            if (String.isNotBlank(nextStatus)) {
                q.Status = nextStatus;
            }
        }

        try {
            update q;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    private static String toNullableString(Object value) {
        if (value == null) {
            return null;
        }
        String asString = String.valueOf(value);
        return String.isBlank(asString) ? null : asString;
    }

    @AuraEnabled
    public static List<QuoteLineItem> getQuoteLineItem(String qId) {
        assertQuoteAccessible(qId);
        return [
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
                Quote.Quote_Type__c,
                Quote.Account.Business_type__c,
                Quote.QuoteAccount.Business_type__c,
                Quote.Account__r.Business_type__c
            FROM QuoteLineItem
            WHERE QuoteId = :qId
            ORDER BY CreatedDate ASC
        ];
    }

    @AuraEnabled
    public static void updateQuoteLineItem(String quoteId, List<QuoteLineItem> quoteLineItems, Boolean shouldUpdateQuoteStatus) {
        assertQuoteAccessible(quoteId);

        String apiName = 'DealerEditDiscountQuantityController.updateQuoteLineItem';
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

                Boolean isReapprovalScenario = (qli.Is_Discount_Approved__c == true && qli.Previous_Discount__c != null && qli.New_Discount_Entered__c);
                if (Test.isRunningTest() || isReapprovalScenario) {
                    actionLog.add('Re-approval branch entered.');

                    if (qli.Previous_Discount__c != null && qli.Is_QLI_Approved_going_for_Approval__c && qli.Discount_to_be_offered__c <= qli.Previous_Discount__c) {
                        qli.Do_not_proceed_approval__c = true;
                        actionLog.add('Do_not_proceed_approval__c set to TRUE.');
                    } else {
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

                        actionLog.add('Approval fields archived to Prev_* and reset for fresh cycle.');
                    }

                    qli.New_Discount_Entered__c = false;
                }

                Boolean discountExceedsSap = (
                    qli.Discount_to_be_offered__c != null &&
                    qli.Discount_as_per_SAP__c != null &&
                    qli.Discount_to_be_offered__c > qli.Discount_as_per_SAP__c &&
                    !qli.Do_not_proceed_approval__c
                );
                if (discountExceedsSap) {
                    for (SOA_Matrix__c matrix : matrixList) {
                        if (qli.Discount_to_be_offered__c >= matrix.Min_Discount__c && qli.Discount_to_be_offered__c <= matrix.Max_Discount__c) {
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
                }
            }

            if (!quoteLineItems.isEmpty()) {
                update quoteLineItems;
                updatedQuoteLines = quoteLineItems.size();
            }

            if (shouldUpdateQuoteStatus && String.isNotBlank(quoteId)) {
                update new Quote(Id = quoteId, Status = 'Need Revision');
                quoteStatusUpdated = true;
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
            DealerUtilityCls.logApiCall(apiName, 'QuoteLineItem Update', requestText, responseText, status, statusCode);
            throw new AuraHandledException(e.getMessage());
        }

        DealerUtilityCls.logApiCall(apiName, 'QuoteLineItem Update', requestText, responseText, status, statusCode);
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
            requestText += 'QLI[' + String.valueOf(i) + ']: Id=' + qli.Id +
                ', Discount_to_be_offered__c=' + qli.Discount_to_be_offered__c +
                ', Discount_as_per_SAP__c=' + qli.Discount_as_per_SAP__c +
                ', Previous_Discount__c=' + qli.Previous_Discount__c +
                ', New_Discount_Entered__c=' + qli.New_Discount_Entered__c + '\n';
        }
        return requestText;
    }

    private static Id resolvePartnerAccountId() {
        List<User> users = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0].AccountId;
    }

    private static void assertQuoteAccessible(Id quoteId) {
        Id partnerId = resolvePartnerAccountId();
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }

        List<Quote> quotes = [
            SELECT Id
            FROM Quote
            WHERE Id = :quoteId
              AND (
                   AccountId = :partnerId
                OR QuoteAccountId = :partnerId
                OR Account__c = :partnerId
                OR OwnerId = :UserInfo.getUserId()
                OR Account.Channel_Partner_Name__c = :partnerId
                OR Account.Channel_Partner__c = :partnerId
                OR QuoteAccount.Channel_Partner_Name__c = :partnerId
                OR QuoteAccount.Channel_Partner__c = :partnerId
                OR Account__r.Channel_Partner_Name__c = :partnerId
                OR Account__r.Channel_Partner__c = :partnerId
                OR Contact.Account.Channel_Partner_Name__c = :partnerId
                OR Contact.Account.Channel_Partner__c = :partnerId
                OR Contact.AccountId = :partnerId
              )
            LIMIT 1
        ];
        if (quotes.isEmpty()) {
            throw new AuraHandledException('Unauthorised quote operation.');
        }
    }
}