public without sharing class SalesPriceApprovalForQuotation {

    public QuotationWrapper quotation;

    public SalesPriceApprovalForQuotation(QuotationWrapper quotation) {
        this.quotation = quotation;
    }


    /**
     * @description: This method is used to get all the Quotations in which the line item's status is pending
     */
    @AuraEnabled
    public static List<QuotationWrapper> getAllQuotations() {
        Id currentUserId = UserInfo.getUserId();

        // Step 1 — find QuoteIds where current user has at least one Submitted QLI
        List<QuoteLineItem> submittedQlis = [
            SELECT QuoteId
            FROM QuoteLineItem
            WHERE (
                    Sales_Manager__c = :currentUserId OR
                    Country_Continent_Sales_Head_LOB_Head__c = :currentUserId OR
                    Global_Sales_Head__c = :currentUserId OR
                    Managing_Director_Country_Manage__c = :currentUserId OR
                    Rotex_Board_Member__c = :currentUserId
                )
                AND Discount_offered_SAP__c = true
                AND Is_Discount_Approved__c = false
        ];

        if (submittedQlis.isEmpty()) {
            throw new AuraHandledException('No Quotation Line Items found with their status as "Pending"');
        }

        Set<Id> quoteIdsWithSubmitted = new Set<Id>();
        for (QuoteLineItem qli : submittedQlis) {
            quoteIdsWithSubmitted.add(qli.QuoteId);
        }

        // Step 2 — fetch ALL QLIs for those quotes (not just Submitted ones)
        List<QuoteLineItem> quoteLineItems = [
            SELECT Approval_Comments__c, Approval_Status__c, Approver__c, CreatedById, ServiceDate,
                Discount, LastModifiedById, Description, LineNumber, ListPrice,
                Product2Id, Product2.Name, Quantity, QuoteId, Discount_as_per_SAP__c, Global_Sales_Head__c,
                Global_Sales_Head_Status__c, Reject_Reason__c, UnitPrice, SortOrder, Subtotal, TotalPrice,
                Discount_to_be_offered__c, Sales_Rep__c, Sales_Rep_Status__c, Sales_Manager__c,
                Sales_Manager_Status__c, Country_Continent_Sales_Head_LOB_Head__c,
                Country_Continent_Sales_H_LOB_Status__c, Managing_Director_Country_Manage__c,
                Managing_Director_Status__c, Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                Final_Discount_Approver__c,
                Country_Continent_Sales_LOB_Comments__c, Global_Sales_Head_Comments__c,
                Managing_Director_Comments__c, Rotex_Board_Member_Comments__c,
                Sales_Manager_Comments__c, Sales_Manager__r.Name, Country_Continent_Sales_Head_LOB_Head__r.Name,
                Rotex_Board_Member__r.Name, Managing_Director_Country_Manage__r.Name,
                Global_Sales_Head__r.Name,
                Sales_Manager_Date_Time__c, Country_Head_Date_Time__c,
                Global_Sales_Head_Date_Time__c, Rotex_Board_Member_Date_Time__c,
                Managing_Director_Date_Time__c, Previous_Discount__c, Is_Discount_Approved__c,
                Prev_Sales_Manager_Comments__c, Prev_Country_Continent_Sales_Comments__c,
                Prev_Global_Sales_Head_Comments__c, Prev_Rotex_Board_Member_Comments__c,
                Prev_Managing_Director_Comments__c
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIdsWithSubmitted
                AND Discount_offered_SAP__c = true
        ];

        // Collect Quote Ids from fetched QLIs
        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem eachQli : quoteLineItems) {
            quoteIds.add(eachQli.QuoteId);
        }

        // Fetch Quote records — no extra user filter needed since quoteIdsWithSubmitted
        // already guarantees the current user is an approver on at least one QLI per quote
        Map<Id, Quote> quoteMap = new Map<Id, Quote>(
            [SELECT Id, Name, Owner.Email, Owner.Name, OwnerId, Account.Name, QuoteNumber, Account.OwnerId,
                    Sales_Rep__c, Sales_Manager__c, Sales_Manager_Status__c, Sales_Rep_Status__c,
                    Country_Continent_Sales_Head_LOB_Head__c, Country_Continent_Sales_H_LOB_Status__c,
                    Global_Sales_Head__c,
                    Managing_Director_Country_Manager__c, Managing_Director_Status__c,
                    Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                    Total_Value__c, Rev_No__c, Validity_of_Offer__c, Payment_Terms__c,
                    Warranty_Terms__c, Delivery_Period__c
            FROM Quote
            WHERE Id IN :quoteIds]
        );

        // Map line items to their parent Quote
        Map<Id, List<QuoteLineItem>> quoteToQuoteLineItemMap = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem eachLine : quoteLineItems) {
            if (!quoteToQuoteLineItemMap.containsKey(eachLine.QuoteId)) {
                quoteToQuoteLineItemMap.put(eachLine.QuoteId, new List<QuoteLineItem>());
            }
            quoteToQuoteLineItemMap.get(eachLine.QuoteId).add(eachLine);
        }

        // Build wrapper list
        List<QuotationWrapper> quotations = new List<QuotationWrapper>();
        for (Id eachQuoteId : quoteToQuoteLineItemMap.keySet()) {
            quotations.add(new QuotationWrapper(quoteMap.get(eachQuoteId), quoteToQuoteLineItemMap.get(eachQuoteId)));
        }

        return quotations;
    }


    /**
     * @description: This method is used to update the approval status and approval comments of the line item
     * @param: quotationListStringObject: It is a JSON stringified list of QuotationWrapper objects
     */
    @AuraEnabled
    public static String updateQuoteLineItem(String quotationListStringObject) {

        List<QuotationWrapper> quotations = parseHeaderAndLine(quotationListStringObject);

        List<QuoteLineItem> quotationLineItemsToBeUpdated = new List<QuoteLineItem>();
        Set<Id> updatedQuoteLineItemIds = new Set<Id>();

        for (QuotationWrapper eachQuotation : quotations) {
            if (eachQuotation.updated && eachQuotation.quoteLineItems != null && !eachQuotation.quoteLineItems.isEmpty()) {
                for (QuotationLineItemWrapper eachQuoteLineItem : eachQuotation.quoteLineItems) {
                    if (eachQuoteLineItem.updated && String.isNotBlank(eachQuoteLineItem.quoteLineItemId)) {
                        updatedQuoteLineItemIds.add((Id)eachQuoteLineItem.quoteLineItemId);
                    }
                }
            }
        }

        Map<Id, QuoteLineItem> existingQuoteLineItems = new Map<Id, QuoteLineItem>();
        if (!updatedQuoteLineItemIds.isEmpty()) {
            existingQuoteLineItems = new Map<Id, QuoteLineItem>([
                SELECT Id, Final_Discount_Approver__c, Sales_Rep_Status__c, Sales_Manager_Status__c,
                    Country_Continent_Sales_H_LOB_Status__c, Global_Sales_Head_Status__c,
                    Rotex_Board_Member_Status__c, Managing_Director_Status__c,
                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c,
                    Global_Sales_Head__c, Rotex_Board_Member__c,
                    Managing_Director_Country_Manage__c,
                    Sales_Manager_Comments__c, Country_Continent_Sales_LOB_Comments__c,
                    Global_Sales_Head_Comments__c, Rotex_Board_Member_Comments__c,
                    Managing_Director_Comments__c
                FROM QuoteLineItem
                WHERE Id IN :updatedQuoteLineItemIds
            ]);
        }
        Set<Quote> quotesToUpdate = new Set<Quote>();
        for (QuotationWrapper eachQuotation : quotations) {
            if (eachQuotation.updated && eachQuotation.quoteLineItems != null && !eachQuotation.quoteLineItems.isEmpty()) {
                for (QuotationLineItemWrapper eachQuoteLineItem : eachQuotation.quoteLineItems) {
                    if (eachQuoteLineItem.updated) {
                        QuoteLineItem existingQuoteLineItem = existingQuoteLineItems.get((Id)eachQuoteLineItem.quoteLineItemId);
                        String existingStageStatus = getStageStatus(existingQuoteLineItem, eachQuoteLineItem.currentStageField);
                        Boolean statusChanged = eachQuoteLineItem.approvalStatus != existingStageStatus;
                        Boolean currentStageCommentChanged = didCurrentStageCommentChange(existingQuoteLineItem, eachQuoteLineItem);
                        Boolean shouldUpdateCurrentStage = statusChanged || currentStageCommentChanged;
                        Boolean canSubmitAsFinalApprover = eachQuoteLineItem.isFinalDiscountApprover == true ||
                            canSkipToPreviousFinalApprover(existingQuoteLineItem, eachQuoteLineItem);
                        if (statusChanged && (existingQuoteLineItem == null || !canSubmitAsFinalApprover)) {
                            throw new AuraHandledException('Only the Final Discount Approver can change the approval status of a Quote Line Item.');
                        }

                        QuoteLineItem quoteLineItem = new QuoteLineItem();
                        quoteLineItem.Id = eachQuoteLineItem.quoteLineItemId;
                        applySkippedComments(quoteLineItem, existingQuoteLineItem, eachQuoteLineItem);

                        if(shouldUpdateCurrentStage && eachQuoteLineItem.currentStageField == 'Sales_Rep_Status__c'){
                            if (canSubmitAsFinalApprover) {
                                quoteLineItem.Sales_Rep_Status__c = eachQuoteLineItem.approvalStatus;
                            } else {
                                quoteLineItem.Sales_Rep_Status__c = 'Approved';
                            }
                            quoteLineItem.Approval_Comments__c = eachQuoteLineItem.approvalComments;
                        }
                        if(shouldUpdateCurrentStage && eachQuoteLineItem.currentStageField == 'Sales_Manager_Status__c'){
                            if (canSubmitAsFinalApprover && statusChanged) {
                                quoteLineItem.Sales_Manager_Status__c = eachQuoteLineItem.approvalStatus;
                            } else if (!canSubmitAsFinalApprover) {
                                quoteLineItem.Sales_Manager_Status__c = 'Approved';
                            }
                            quoteLineItem.Sales_Manager_Comments__c = eachQuoteLineItem.Sales_Manager_Comments;
                            quoteLineItem.Sales_Manager_Date_Time__c = DateTime.now(); // ✅
                        } 
                        if(shouldUpdateCurrentStage && eachQuoteLineItem.currentStageField == 'Country_Continent_Sales_H_LOB_Status__c'){
                            if (canSubmitAsFinalApprover && statusChanged) {
                                quoteLineItem.Country_Continent_Sales_H_LOB_Status__c = eachQuoteLineItem.approvalStatus;
                            } else if (!canSubmitAsFinalApprover) {
                                quoteLineItem.Country_Continent_Sales_H_LOB_Status__c = 'Approved';
                            }
                            quoteLineItem.Country_Continent_Sales_LOB_Comments__c = eachQuoteLineItem.Country_Continent_Sales_LOB_Comments;
                            quoteLineItem.Country_Head_Date_Time__c = DateTime.now(); // ✅
                        } 
                        if(shouldUpdateCurrentStage && eachQuoteLineItem.currentStageField == 'Global_Sales_Head_Status__c'){
                            if (canSubmitAsFinalApprover && statusChanged) {
                                quoteLineItem.Global_Sales_Head_Status__c = eachQuoteLineItem.approvalStatus;
                            } else if (!canSubmitAsFinalApprover) {
                                quoteLineItem.Global_Sales_Head_Status__c = 'Approved';
                            }
                            quoteLineItem.Global_Sales_Head_Comments__c = eachQuoteLineItem.Global_Sales_Head_Comments;
                            quoteLineItem.Global_Sales_Head_Date_Time__c = DateTime.now(); // ✅
                        }
                        if(shouldUpdateCurrentStage && eachQuoteLineItem.currentStageField =='Rotex_Board_Member_Status__c'){
                            if (canSubmitAsFinalApprover && statusChanged) {
                                quoteLineItem.Rotex_Board_Member_Status__c = eachQuoteLineItem.approvalStatus;
                            } else if (!canSubmitAsFinalApprover) {
                                quoteLineItem.Rotex_Board_Member_Status__c = 'Approved';
                            }
                            quoteLineItem.Rotex_Board_Member_Comments__c= eachQuoteLineItem.Rotex_Board_Member_Comments;
                            quoteLineItem.Rotex_Board_Member_Date_Time__c = DateTime.now(); // ✅
                        } 
                        if(shouldUpdateCurrentStage && eachQuoteLineItem.currentStageField == 'Managing_Director_Status__c'){
                            if (canSubmitAsFinalApprover && statusChanged) {
                                quoteLineItem.Managing_Director_Status__c = eachQuoteLineItem.approvalStatus;
                            } else if (!canSubmitAsFinalApprover) {
                                quoteLineItem.Managing_Director_Status__c = 'Approved';
                            }
                            quoteLineItem.Managing_Director_Comments__c = eachQuoteLineItem.Managing_Director_Comments;
                            quoteLineItem.Managing_Director_Date_Time__c = DateTime.now(); // ✅
                        } 

                        if (canSubmitAsFinalApprover) {
                            Quote quote = new Quote();
                            quote.Id = eachQuotation.quoteId;
                            quote.OwnerId = eachQuotation.accountOwner;
                            quotesToUpdate.add(quote);
                        }

                        
                        
                        quotationLineItemsToBeUpdated.add(quoteLineItem);
                    }
                }
            }
        }

        UPDATE quotationLineItemsToBeUpdated;
        UPDATE new List<Quote>(quotesToUpdate);

        for (QuotationWrapper eachQuotation : quotations) {
            SalesPriceApprovalForQuotation controller = new SalesPriceApprovalForQuotation(eachQuotation);
            controller.sendEmailNotification();
        }

        return 'Success';
    }

    private void sendEmailNotification() {
        Boolean isApproved = false;
        Boolean isRejected = false;
        for (QuotationLineItemWrapper item : quotation.quoteLineItems) {
            if (item.approvalStatus == 'Approved') {
                isApproved = true;
            } else if (item.approvalStatus == 'Rejected') {
                isRejected = true;
            }
        }

        if (isApproved) {
            this.sendEmail(this.quotation, 'Approved');
            this.sendCustomNotification(this.quotation, 'Approved');
        }

        if (isRejected) {
            this.sendEmail(this.quotation, 'Rejected');
            this.sendCustomNotification(this.quotation, 'Rejected');
        }
    }

    private void sendEmail(QuotationWrapper quotation, String status) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[]{quotation.quoteOwnerEmail});
        email.setSubject('Sales Price ' + status + ' - ' + quotation.quoteName);
        email.setWhatId(quotation.quoteId);
        email.setSaveAsActivity(true);

        String body = 'Dear ' + quotation.quoteOwnerName + ',<br/><br/>';
        body += 'The Sales Price has been ' + status.toLowerCase() + ' for the following Quote:<br/><br/>';
        body += 'Quote Name: ' + quotation.quoteName + '<br/>';
        body += 'Quote Link: ' + quotation.quoteLink + '</a><br/><br/>';
        body += 'Below are the product details:<br/><br/>';

        body += '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse: collapse; width: 100%;">';
        body += '<thead><tr style="background-color: #f2f2f2;"><th>Product Name</th><th>List Price</th><th>Sales Price</th><th>Approval Status</th></tr></thead><tbody>';

        for (QuotationLineItemWrapper item : quotation.quoteLineItems) {
            if (item.approvalStatus == status && item.updated) {
                body += '<tr>';
                body += '<td>' + item.productName + '</td>';
                body += '<td>' + (item.listPrice != null ? String.valueOf(item.listPrice) : 'Not Available') + '</td>';
                body += '<td>' + (item.salesPrice != null ? String.valueOf(item.salesPrice) : 'Not Available') + '</td>';
                body += '<td>' + (item.approvalStatus != null ? String.valueOf(item.approvalStatus) : '') + '</td>';
                body += '</tr>';
            }
        }

        body += '</tbody></table><br/>';
        body += 'Sales Price has been ' + status.toLowerCase() + ', kindly review the details at your earliest convenience.<br/><br/>';
        body += 'Regards,<br/>';
        body += (quotation.quoteOwnerId != null ? quotation.quoteOwnerName : 'System Notification');

        email.setHtmlBody(body);

        try {
            //Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
        } catch (Exception e) {
            System.debug('Email Sending Failed: ' + e.getMessage());
        }
    }

    private void sendCustomNotification(QuotationWrapper quotation, String status) {
        try {
            CustomNotificationType notificationType = [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType 
                WHERE DeveloperName = 'Approval_Alert' 
                LIMIT 1
            ];
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            
            notification.setNotificationTypeId(notificationType.Id);
            
            notification.setTitle('Sales Price ' + status);
            
            String body = 'Quote ' + quotation.quoteName + ' has been ' + status.toLowerCase() + '. Please review the details.';
            notification.setBody(body);
            
            notification.setTargetId(quotation.quoteId);
            
            notification.send(new Set<String>{quotation.quoteOwnerId});
            
            System.debug('Custom notification sent successfully to: ' + quotation.quoteOwnerEmail);
            
        } catch (Exception e) {
            System.debug('Custom Notification Failed: ' + e.getMessage());
        }
    }

    private static List<QuotationWrapper> parseHeaderAndLine(string js){
        return (List<QuotationWrapper>)system.JSON.deserialize(js,List<QuotationWrapper>.class);
    }

    private static String getStringFieldSafely(SObject record, String fieldApiName) {
        try {
            Object value = record.get(fieldApiName);
            return value == null ? null : String.valueOf(value);
        } catch (SObjectException e) {
            return null;
        }
    }

    private static Datetime getDateTimeFieldSafely(SObject record, String fieldApiName) {
        try {
            Object value = record.get(fieldApiName);
            return value == null ? null : (Datetime)value;
        } catch (SObjectException e) {
            return null;
        }
    }

    private static Decimal getDecimalFieldSafely(SObject record, String fieldApiName) {
        try {
            Object value = record.get(fieldApiName);
            return value == null ? null : (Decimal)value;
        } catch (SObjectException e) {
            return null;
        }
    }

    private static String getStageStatus(QuoteLineItem quoteLineItem, String currentStageField) {
        if (quoteLineItem == null || String.isBlank(currentStageField)) {
            return null;
        }

        return getStringFieldSafely(quoteLineItem, currentStageField);
    }

    private static Boolean didCurrentStageCommentChange(
        QuoteLineItem quoteLineItem,
        QuotationLineItemWrapper lineItem
    ) {
        if (quoteLineItem == null || lineItem == null || String.isBlank(lineItem.currentStageField)) {
            return false;
        }

        String existingComment;
        String submittedComment;

        if (lineItem.currentStageField == 'Sales_Rep_Status__c') {
            existingComment = getStringFieldSafely(quoteLineItem, 'Approval_Comments__c');
            submittedComment = lineItem.approvalComments;
        } else if (lineItem.currentStageField == 'Sales_Manager_Status__c') {
            existingComment = getStringFieldSafely(quoteLineItem, 'Sales_Manager_Comments__c');
            submittedComment = lineItem.Sales_Manager_Comments;
        } else if (lineItem.currentStageField == 'Country_Continent_Sales_H_LOB_Status__c') {
            existingComment = getStringFieldSafely(quoteLineItem, 'Country_Continent_Sales_LOB_Comments__c');
            submittedComment = lineItem.Country_Continent_Sales_LOB_Comments;
        } else if (lineItem.currentStageField == 'Global_Sales_Head_Status__c') {
            existingComment = getStringFieldSafely(quoteLineItem, 'Global_Sales_Head_Comments__c');
            submittedComment = lineItem.Global_Sales_Head_Comments;
        } else if (lineItem.currentStageField == 'Rotex_Board_Member_Status__c') {
            existingComment = getStringFieldSafely(quoteLineItem, 'Rotex_Board_Member_Comments__c');
            submittedComment = lineItem.Rotex_Board_Member_Comments;
        } else if (lineItem.currentStageField == 'Managing_Director_Status__c') {
            existingComment = getStringFieldSafely(quoteLineItem, 'Managing_Director_Comments__c');
            submittedComment = lineItem.Managing_Director_Comments;
        }

        return normalizeComment(existingComment) != normalizeComment(submittedComment);
    }

    private static String normalizeComment(String value) {
        return value == null ? '' : value.trim();
    }

    private static Boolean canSkipToPreviousFinalApprover(
        QuoteLineItem quoteLineItem,
        QuotationLineItemWrapper lineItem
    ) {
        if (quoteLineItem == null || lineItem == null || lineItem.skipSoaRestrictions != true) {
            return false;
        }

        Integer currentUserIndex = getApproverIndex(quoteLineItem, UserInfo.getUserId());
        Integer finalApproverIndex = getApproverIndex(quoteLineItem, quoteLineItem.Final_Discount_Approver__c);
        Id stageApproverId = getApproverIdForStage(quoteLineItem, lineItem.currentStageField);

        return currentUserIndex != null &&
            finalApproverIndex != null &&
            finalApproverIndex < currentUserIndex &&
            stageApproverId == quoteLineItem.Final_Discount_Approver__c;
    }

    private static Integer getApproverIndex(QuoteLineItem quoteLineItem, Id approverId) {
        if (quoteLineItem == null || approverId == null) {
            return null;
        }

        if (quoteLineItem.Sales_Manager__c == approverId) {
            return 1;
        }
        if (quoteLineItem.Country_Continent_Sales_Head_LOB_Head__c == approverId) {
            return 2;
        }
        if (quoteLineItem.Global_Sales_Head__c == approverId) {
            return 3;
        }
        if (quoteLineItem.Rotex_Board_Member__c == approverId) {
            return 4;
        }
        if (quoteLineItem.Managing_Director_Country_Manage__c == approverId) {
            return 5;
        }

        return null;
    }

    private static Id getApproverIdForStage(QuoteLineItem quoteLineItem, String stageField) {
        if (quoteLineItem == null || String.isBlank(stageField)) {
            return null;
        }

        if (stageField == 'Sales_Manager_Status__c') {
            return quoteLineItem.Sales_Manager__c;
        }
        if (stageField == 'Country_Continent_Sales_H_LOB_Status__c') {
            return quoteLineItem.Country_Continent_Sales_Head_LOB_Head__c;
        }
        if (stageField == 'Global_Sales_Head_Status__c') {
            return quoteLineItem.Global_Sales_Head__c;
        }
        if (stageField == 'Rotex_Board_Member_Status__c') {
            return quoteLineItem.Rotex_Board_Member__c;
        }
        if (stageField == 'Managing_Director_Status__c') {
            return quoteLineItem.Managing_Director_Country_Manage__c;
        }

        return null;
    }

    private static void applySkippedComments(
        QuoteLineItem quoteLineItem,
        QuoteLineItem existingQuoteLineItem,
        QuotationLineItemWrapper lineItem
    ) {
        if (quoteLineItem == null || existingQuoteLineItem == null || lineItem == null || lineItem.skipSoaRestrictions != true) {
            return;
        }

        Integer currentUserIndex = getApproverIndex(existingQuoteLineItem, UserInfo.getUserId());
        if (currentUserIndex == null) {
            return;
        }

        if (1 < currentUserIndex &&
            existingQuoteLineItem.Sales_Manager__c != existingQuoteLineItem.Final_Discount_Approver__c &&
            String.isBlank(existingQuoteLineItem.Sales_Manager_Comments__c) &&
            String.isNotBlank(lineItem.Sales_Manager_Comments)) {
            quoteLineItem.Sales_Manager_Comments__c = lineItem.Sales_Manager_Comments;
            quoteLineItem.Sales_Manager_Status__c = 'Approved';
            quoteLineItem.Sales_Manager_Date_Time__c = DateTime.now();
        }
        if (2 < currentUserIndex &&
            existingQuoteLineItem.Country_Continent_Sales_Head_LOB_Head__c != existingQuoteLineItem.Final_Discount_Approver__c &&
            String.isBlank(existingQuoteLineItem.Country_Continent_Sales_LOB_Comments__c) &&
            String.isNotBlank(lineItem.Country_Continent_Sales_LOB_Comments)) {
            quoteLineItem.Country_Continent_Sales_LOB_Comments__c = lineItem.Country_Continent_Sales_LOB_Comments;
            quoteLineItem.Country_Continent_Sales_H_LOB_Status__c = 'Approved';
            quoteLineItem.Country_Head_Date_Time__c = DateTime.now();
        }
        if (3 < currentUserIndex &&
            existingQuoteLineItem.Global_Sales_Head__c != existingQuoteLineItem.Final_Discount_Approver__c &&
            String.isBlank(existingQuoteLineItem.Global_Sales_Head_Comments__c) &&
            String.isNotBlank(lineItem.Global_Sales_Head_Comments)) {
            quoteLineItem.Global_Sales_Head_Comments__c = lineItem.Global_Sales_Head_Comments;
            quoteLineItem.Global_Sales_Head_Status__c = 'Approved';
            quoteLineItem.Global_Sales_Head_Date_Time__c = DateTime.now();
        }
        if (4 < currentUserIndex &&
            existingQuoteLineItem.Rotex_Board_Member__c != existingQuoteLineItem.Final_Discount_Approver__c &&
            String.isBlank(existingQuoteLineItem.Rotex_Board_Member_Comments__c) &&
            String.isNotBlank(lineItem.Rotex_Board_Member_Comments)) {
            quoteLineItem.Rotex_Board_Member_Comments__c = lineItem.Rotex_Board_Member_Comments;
            quoteLineItem.Rotex_Board_Member_Status__c = 'Approved';
            quoteLineItem.Rotex_Board_Member_Date_Time__c = DateTime.now();
        }
        if (5 < currentUserIndex &&
            existingQuoteLineItem.Managing_Director_Country_Manage__c != existingQuoteLineItem.Final_Discount_Approver__c &&
            String.isBlank(existingQuoteLineItem.Managing_Director_Comments__c) &&
            String.isNotBlank(lineItem.Managing_Director_Comments)) {
            quoteLineItem.Managing_Director_Comments__c = lineItem.Managing_Director_Comments;
            quoteLineItem.Managing_Director_Status__c = 'Approved';
            quoteLineItem.Managing_Director_Date_Time__c = DateTime.now();
        }
    }

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

        public QuotationWrapper() {}

        public QuotationWrapper(Quote quote, List<QuoteLineItem> quoteLineItems) {
            this.quoteId = quote.Id;
            this.quoteName = quote.Name;
            this.accountName = quote.Account.Name;
            this.accountOwner = quote.Account.OwnerId;
            this.quoteNumber = quote.QuoteNumber;
            this.quoteOwnerId = quote.OwnerId;
            this.quoteOwnerEmail = quote.Owner.Email;
            this.quoteOwnerName = quote.Owner.Name;
            this.totalValue = getDecimalFieldSafely(quote, 'Total_Value__c');
            this.revNo = getStringFieldSafely(quote, 'Rev_No__c');
            this.validityOfOffer = getStringFieldSafely(quote, 'Validity_of_Offer__c');
            this.paymentTerms = getStringFieldSafely(quote, 'Payment_Terms__c');
            this.warrantyTerms = getStringFieldSafely(quote, 'Warranty_Terms__c');
            this.deliveryPeriod = getStringFieldSafely(quote, 'Delivery_Period__c');
            
            Id hodUserId;
            Id currentUserId = UserInfo.getUserId();
            
            if (quote.Sales_Rep__c == currentUserId) {
                hodUserId = quote.Sales_Rep__c;
            } else if (quote.Sales_Manager__c == currentUserId) {
                hodUserId = quote.Sales_Manager__c;
            } else if (quote.Country_Continent_Sales_Head_LOB_Head__c == currentUserId) {
                hodUserId = quote.Country_Continent_Sales_Head_LOB_Head__c;
            } else if (quote.Global_Sales_Head__c == currentUserId) {
                hodUserId = quote.Global_Sales_Head__c;
            } else if (quote.Rotex_Board_Member__c == currentUserId) {
                hodUserId = quote.Rotex_Board_Member__c;
            } else if (quote.Managing_Director_Country_Manager__c == currentUserId) {
                hodUserId = quote.Managing_Director_Country_Manager__c;
            }
            
            this.hodUserId = hodUserId;
            this.updated = false;

            if (this.quoteLineItems == null) {
                this.quoteLineItems = new list<QuotationLineItemWrapper>();
            }

            for (QuoteLineItem eachLine : quoteLineItems) {
                this.quoteLineItems.add(new QuotationLineItemWrapper(eachLine));
            }
        }
    }

    public class QuotationLineItemWrapper {
        @AuraEnabled public String parentId;
        @AuraEnabled public String quoteLineItemId;
        @AuraEnabled public String productId;
        @AuraEnabled public String productName;
        
        @AuraEnabled public String Country_Continent_Sales_LOB_Comments;
        @AuraEnabled public String Global_Sales_Head_Comments;
        @AuraEnabled public String Managing_Director_Comments;
        @AuraEnabled public String Rotex_Board_Member_Comments;
        @AuraEnabled public String Sales_Manager_Comments;

        @AuraEnabled public String prevSalesManagerComments;
        @AuraEnabled public String prevCountryContinentSalesComments;
        @AuraEnabled public String prevGlobalSalesHeadComments;
        @AuraEnabled public String prevRotexBoardMemberComments;
        @AuraEnabled public String prevManagingDirectorComments;
        
        @AuraEnabled public String salesManagerName;
        @AuraEnabled public String countryContinentSalesName;
        @AuraEnabled public String rotexBoardMemberName;
        @AuraEnabled public String managingDirectorName;
        @AuraEnabled public String globalSalesHeadName;
        @AuraEnabled public String salesManagerId;
        @AuraEnabled public String countryContinentSalesId;
        @AuraEnabled public String rotexBoardMemberId;
        @AuraEnabled public String managingDirectorId;
        @AuraEnabled public String globalSalesHeadId;

        // Per-SOA status fields (for displaying each approver's current status)
        @AuraEnabled public String salesManagerStatus;
        @AuraEnabled public String countryContinentSalesStatus;
        @AuraEnabled public String rotexBoardMemberStatus;
        @AuraEnabled public String managingDirectorStatus;
        @AuraEnabled public String globalSalesHeadStatus;

        // Per-SOA date/time fields
        @AuraEnabled public DateTime salesManagerDateTime;
        @AuraEnabled public DateTime countryHeadDateTime;
        @AuraEnabled public DateTime managingDirectorDateTime;
        @AuraEnabled public DateTime globalSalesHeadDateTime;
        @AuraEnabled public DateTime rotexBoardMemberDateTime;
        
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Decimal salesPrice;
        @AuraEnabled public Decimal d1;
        @AuraEnabled public Decimal d2;
        @AuraEnabled public Decimal previousDiscount;
        @AuraEnabled public boolean bcheck;
        @AuraEnabled public boolean bcheck1;
        @AuraEnabled public boolean bcheck2;
        @AuraEnabled public boolean bcheck3;
        @AuraEnabled public boolean bcheck4;
        @AuraEnabled public boolean bcheck5;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String approvalComments;
        @AuraEnabled public Boolean updated;
        @AuraEnabled public String hodUserId; 
        @AuraEnabled public String currentStage; 
        @AuraEnabled public String currentStageField; 
        @AuraEnabled public String finalDiscountApproverId;
        @AuraEnabled public Boolean isFinalDiscountApprover;
        @AuraEnabled public Boolean skipSoaRestrictions;

        public QuotationLineItemWrapper() {}

        public QuotationLineItemWrapper(QuoteLineItem quoteLineItem) {
            this.parentId = quoteLineItem.QuoteId;
            this.quoteLineItemId = quoteLineItem.Id;
            this.productId = quoteLineItem.Product2Id;
            this.productName = quoteLineItem.Product2.Name;
            this.quantity = quoteLineItem.Quantity;
            this.listPrice = quoteLineItem.ListPrice;
            this.salesPrice = quoteLineItem.UnitPrice;
            this.bcheck = true;
            this.bcheck1 = true;
            this.bcheck2 = true;
            this.bcheck3 = true;
            this.bcheck4 = true;
            this.bcheck5 = true;
            this.finalDiscountApproverId = quoteLineItem.Final_Discount_Approver__c;
            
            this.Country_Continent_Sales_LOB_Comments = quoteLineItem.Country_Continent_Sales_LOB_Comments__c;
            this.Global_Sales_Head_Comments = quoteLineItem.Global_Sales_Head_Comments__c;
            this.Managing_Director_Comments = quoteLineItem.Managing_Director_Comments__c;
            this.Rotex_Board_Member_Comments = quoteLineItem.Rotex_Board_Member_Comments__c;
            this.Sales_Manager_Comments = quoteLineItem.Sales_Manager_Comments__c;
            this.prevSalesManagerComments = SalesPriceApprovalForQuotation.getStringFieldSafely(quoteLineItem, 'Prev_Sales_Manager_Comments__c');
            this.prevCountryContinentSalesComments = SalesPriceApprovalForQuotation.getStringFieldSafely(quoteLineItem, 'Prev_Country_Continent_Sales_Comments__c');
            this.prevGlobalSalesHeadComments = SalesPriceApprovalForQuotation.getStringFieldSafely(quoteLineItem, 'Prev_Global_Sales_Head_Comments__c');
            this.prevRotexBoardMemberComments = SalesPriceApprovalForQuotation.getStringFieldSafely(quoteLineItem, 'Prev_Rotex_Board_Member_Comments__c');
            this.prevManagingDirectorComments = SalesPriceApprovalForQuotation.getStringFieldSafely(quoteLineItem, 'Prev_Managing_Director_Comments__c');
            
            // Set names
            this.salesManagerName = quoteLineItem.Sales_Manager__r?.Name;
            this.countryContinentSalesName = quoteLineItem.Country_Continent_Sales_Head_LOB_Head__r?.Name;
            this.rotexBoardMemberName = quoteLineItem.Rotex_Board_Member__r?.Name;
            this.managingDirectorName = quoteLineItem.Managing_Director_Country_Manage__r?.Name;
            this.globalSalesHeadName = quoteLineItem.Global_Sales_Head__r?.Name;
            this.salesManagerId = String.valueOf(quoteLineItem.Sales_Manager__c);
            this.countryContinentSalesId = String.valueOf(quoteLineItem.Country_Continent_Sales_Head_LOB_Head__c);
            this.rotexBoardMemberId = String.valueOf(quoteLineItem.Rotex_Board_Member__c);
            this.managingDirectorId = String.valueOf(quoteLineItem.Managing_Director_Country_Manage__c);
            this.globalSalesHeadId = String.valueOf(quoteLineItem.Global_Sales_Head__c);
            
            Id hodUserId;
            string approvalComments = '';
            string currentStage = '';
            string currentStageField = '';
 
            Id currentUserId = UserInfo.getUserId();
            if (quoteLineItem.Sales_Rep__c == currentUserId) {
                this.bcheck = false;
                hodUserId = quoteLineItem.Sales_Rep__c;
                currentStage = quoteLineItem.Sales_Rep_Status__c;
                currentStageField = 'Sales_Rep_Status__c';
                approvalComments = quoteLineItem.Approval_Comments__c;
            } else if (quoteLineItem.Sales_Manager__c == currentUserId) {
                hodUserId = quoteLineItem.Sales_Manager__c;
                this.bcheck1 = false;
                currentStage = quoteLineItem.Sales_Manager_Status__c;
                currentStageField = 'Sales_Manager_Status__c';
                approvalComments = quoteLineItem.Sales_Manager_Comments__c;
            } else if (quoteLineItem.Country_Continent_Sales_Head_LOB_Head__c == currentUserId) {
                hodUserId = quoteLineItem.Country_Continent_Sales_Head_LOB_Head__c;
                this.bcheck2 = false;
                currentStage = quoteLineItem.Country_Continent_Sales_H_LOB_Status__c;
                currentStageField = 'Country_Continent_Sales_H_LOB_Status__c';
                approvalComments = quoteLineItem.Country_Continent_Sales_LOB_Comments__c;
            } else if (quoteLineItem.Global_Sales_Head__c == currentUserId) {
                hodUserId = quoteLineItem.Global_Sales_Head__c;
                this.bcheck5 = false;
                currentStage = quoteLineItem.Global_Sales_Head_Status__c;
                currentStageField = 'Global_Sales_Head_Status__c';
                approvalComments = quoteLineItem.Global_Sales_Head_Comments__c;
            } else if (quoteLineItem.Rotex_Board_Member__c == currentUserId) {
                hodUserId = quoteLineItem.Rotex_Board_Member__c;
                this.bcheck3 = false;
                currentStage = quoteLineItem.Rotex_Board_Member_Status__c;
                currentStageField = 'Rotex_Board_Member_Status__c';
                this.approvalStatus = currentStage;
                approvalComments = quoteLineItem.Rotex_Board_Member_Comments__c;
            } else if (quoteLineItem.Managing_Director_Country_Manage__c == currentUserId) {
                hodUserId = quoteLineItem.Managing_Director_Country_Manage__c;
                this.bcheck4 = false;
                currentStage = quoteLineItem.Managing_Director_Status__c;
                currentStageField = 'Managing_Director_Status__c';
                this.approvalStatus = currentStage;
                approvalComments = quoteLineItem.Managing_Director_Comments__c;
            }
            
            this.hodUserId = hodUserId;
            this.currentStage = currentStage;
            this.currentStageField = currentStageField;
            this.d1 = quoteLineItem.Discount_as_per_SAP__c;
            this.d2 = quoteLineItem.Discount_to_be_offered__c;
            this.previousDiscount = SalesPriceApprovalForQuotation.getDecimalFieldSafely(quoteLineItem, 'Previous_Discount__c');
            this.approvalStatus = currentStage;
            this.approvalComments = approvalComments;
            this.updated = false;
            this.skipSoaRestrictions = false;

            // Map per-SOA statuses
            this.salesManagerStatus          = SalesPriceApprovalForQuotation.getStringFieldSafely(quoteLineItem, 'Sales_Manager_Status__c');
            this.countryContinentSalesStatus = SalesPriceApprovalForQuotation.getStringFieldSafely(quoteLineItem, 'Country_Continent_Sales_H_LOB_Status__c');
            this.rotexBoardMemberStatus      = SalesPriceApprovalForQuotation.getStringFieldSafely(quoteLineItem, 'Rotex_Board_Member_Status__c');
            this.managingDirectorStatus      = SalesPriceApprovalForQuotation.getStringFieldSafely(quoteLineItem, 'Managing_Director_Status__c');
            this.globalSalesHeadStatus       = SalesPriceApprovalForQuotation.getStringFieldSafely(quoteLineItem, 'Global_Sales_Head_Status__c');

            // Map per-SOA date/times
            this.salesManagerDateTime     = SalesPriceApprovalForQuotation.getDateTimeFieldSafely(quoteLineItem, 'Sales_Manager_Date_Time__c');
            this.countryHeadDateTime      = SalesPriceApprovalForQuotation.getDateTimeFieldSafely(quoteLineItem, 'Country_Head_Date_Time__c');
            this.managingDirectorDateTime = SalesPriceApprovalForQuotation.getDateTimeFieldSafely(quoteLineItem, 'Managing_Director_Date_Time__c');
            this.globalSalesHeadDateTime  = SalesPriceApprovalForQuotation.getDateTimeFieldSafely(quoteLineItem, 'Global_Sales_Head_Date_Time__c');
            this.rotexBoardMemberDateTime = SalesPriceApprovalForQuotation.getDateTimeFieldSafely(quoteLineItem, 'Rotex_Board_Member_Date_Time__c');
        }
    }
}
