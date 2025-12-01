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
    
        // Fetch all pending line items first
        List<QuoteLineItem> quoteLineItems = [
            SELECT Approval_Comments__c, Approval_Status__c, Approver__c, CreatedById, ServiceDate,
                Discount, LastModifiedById, Description, LineNumber, ListPrice,
                Product2Id, Product2.Name, Quantity, QuoteId, Discount_as_per_SAP__c, Global_Sales_Head__c,
                Global_Sales_Head_Status__c, Reject_Reason__c, UnitPrice, SortOrder, Subtotal, TotalPrice,
                Discount_to_be_offered__c, Sales_Rep__c, Sales_Rep_Status__c, Sales_Manager__c,
                Sales_Manager_Status__c, Country_Continent_Sales_Head_LOB_Head__c,
                Country_Continent_Sales_H_LOB_Status__c, Managing_Director_Country_Manage__c,
                Managing_Director_Status__c, Rotex_Board_Member__c, Rotex_Board_Member_Status__c,
                Country_Continent_Sales_LOB_Comments__c, Global_Sales_Head_Comments__c,
                Managing_Director_Comments__c, Rotex_Board_Member_Comments__c,
                Sales_Manager_Comments__c,
                Sales_Manager__r.Name, Country_Continent_Sales_Head_LOB_Head__r.Name,
                Rotex_Board_Member__r.Name, Managing_Director_Country_Manage__r.Name,
                Global_Sales_Head__r.Name
            FROM QuoteLineItem
            WHERE (
                    (Sales_Rep_Status__c = 'Submitted' AND Sales_Rep__c = :currentUserId) OR
                    (Sales_Manager_Status__c = 'Submitted' AND Sales_Manager__c = :currentUserId) OR
                    (Country_Continent_Sales_H_LOB_Status__c = 'Submitted' AND Country_Continent_Sales_Head_LOB_Head__c = :currentUserId) OR
                    (Global_Sales_Head_Status__c = 'Submitted' AND Global_Sales_Head__c = :currentUserId) OR
                    (Managing_Director_Status__c = 'Submitted' AND Managing_Director_Country_Manage__c = :currentUserId) OR
                    (Rotex_Board_Member_Status__c = 'Submitted' AND Rotex_Board_Member__c = :currentUserId)
                )
                AND Discount_offered_SAP__c = true
        ];

    
        if (quoteLineItems.isEmpty()) {
            throw new AuraHandledException('No Quotation Line Items found with their status as "Pending"');
        }
    
        // collect Quote Ids
        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem eachQli : quoteLineItems) {
            quoteIds.add(eachQli.QuoteId);
        }
    
        // fetch only those Quotes that belong to the user (owner) or where user is HOD
        Map<Id, Quote> quoteMap = new Map<Id, Quote>(
            [SELECT Id, Name, Owner.Email, Owner.Name, OwnerId, Account.Name, QuoteNumber, Sales_Rep__c,Sales_Manager__c,Sales_Manager_Status__c,Sales_Rep_Status__c,
             Country_Continent_Sales_Head_LOB_Head__c,Country_Continent_Sales_H_LOB_Status__c,Managing_Director_Country_Manager__c,Managing_Director_Status__c,Rotex_Board_Member__c,Rotex_Board_Member_Status__c
             FROM Quote
             WHERE Id IN :quoteIds
               AND (OwnerId = :currentUserId OR Sales_Rep__c = :currentUserId or 
                   Sales_Manager__c = :currentUserId OR Country_Continent_Sales_Head_LOB_Head__c = :currentUserId or 
                    Managing_Director_Country_Manager__c = :currentUserId OR Rotex_Board_Member__c = :currentUserId 
                   )]
        );
    
        // map line items to their parent Quote
        Map<Id, List<QuoteLineItem>> quoteToQuoteLineItemMap = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem eachLine : quoteLineItems) {
            if (quoteMap.containsKey(eachLine.QuoteId)) {
                if (!quoteToQuoteLineItemMap.containsKey(eachLine.QuoteId)) {
                    quoteToQuoteLineItemMap.put(eachLine.QuoteId, new List<QuoteLineItem>());
                }
                quoteToQuoteLineItemMap.get(eachLine.QuoteId).add(eachLine);
            }
        }
    
        // build wrapper list
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

        for (QuotationWrapper eachQuotation : quotations) {
            if (eachQuotation.updated && eachQuotation.quoteLineItems != null && !eachQuotation.quoteLineItems.isEmpty()) {
                for (QuotationLineItemWrapper eachQuoteLineItem : eachQuotation.quoteLineItems) {
                    if (eachQuoteLineItem.updated) {
                        QuoteLineItem quoteLineItem = new QuoteLineItem();
                        quoteLineItem.Id = eachQuoteLineItem.quoteLineItemId;

                        if(eachQuoteLineItem.currentStageField =='Sales_Rep_Status__c'){
                            quoteLineItem.Sales_Rep_Status__c = eachQuoteLineItem.approvalStatus;
                            quoteLineItem.Approval_Comments__c= eachQuoteLineItem.approvalComments;
                        }
                        if(eachQuoteLineItem.currentStageField =='Sales_Manager_Status__c'){
                            quoteLineItem.Sales_Manager_Status__c = eachQuoteLineItem.approvalStatus;
                            quoteLineItem.Sales_Manager_Comments__c= eachQuoteLineItem.Sales_Manager_Comments;
                        } 
                        if(eachQuoteLineItem.currentStageField =='Country_Continent_Sales_H_LOB_Status__c'){
                            quoteLineItem.Country_Continent_Sales_H_LOB_Status__c = eachQuoteLineItem.approvalStatus;
                            quoteLineItem.Country_Continent_Sales_LOB_Comments__c= eachQuoteLineItem.Country_Continent_Sales_LOB_Comments;
                        } 
                        if(eachQuoteLineItem.currentStageField =='Managing_Director_Status__c'){
                            quoteLineItem.Managing_Director_Status__c = eachQuoteLineItem.approvalStatus;
                            quoteLineItem.Managing_Director_Comments__c= eachQuoteLineItem.Managing_Director_Comments;
                        } 
                        if(eachQuoteLineItem.currentStageField =='Rotex_Board_Member_Status__c'){
                            quoteLineItem.Rotex_Board_Member_Status__c = eachQuoteLineItem.approvalStatus;
                            quoteLineItem.Rotex_Board_Member_Comments__c= eachQuoteLineItem.Rotex_Board_Member_Comments;
                        } 
                        
                        if(eachQuoteLineItem.currentStageField =='Global_Sales_Head_Status__c'){
                            quoteLineItem.Global_Sales_Head_Status__c = eachQuoteLineItem.approvalStatus;
                            quoteLineItem.Global_Sales_Head_Comments__c= eachQuoteLineItem.Global_Sales_Head_Comments;
                        } 
                        
                        quotationLineItemsToBeUpdated.add(quoteLineItem);
                    }
                }
            }
        }

        UPDATE quotationLineItemsToBeUpdated;

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

    public class QuotationWrapper {
        @AuraEnabled public String quoteId;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public String accountName;
        @AuraEnabled public String quoteOwnerId;
        @AuraEnabled public String quoteOwnerEmail;
        @AuraEnabled public String quoteOwnerName;
        @AuraEnabled public String quoteLink;
        @AuraEnabled public String hodUserId; 
        @AuraEnabled public List<QuotationLineItemWrapper> quoteLineItems;
        @AuraEnabled public Boolean updated;

        public QuotationWrapper() {}

        public QuotationWrapper(Quote quote, List<QuoteLineItem> quoteLineItems) {
            this.quoteId = quote.Id;
            this.quoteName = quote.Name;
            this.accountName = quote.Account.Name;
            this.quoteNumber = quote.QuoteNumber;
            this.quoteOwnerId = quote.OwnerId;
            this.quoteOwnerEmail = quote.Owner.Email;
            this.quoteOwnerName = quote.Owner.Name;
            
            Id hodUserId;
            Id currentUserId = UserInfo.getUserId();
            
            if (quote.Sales_Rep__c == currentUserId) {
                hodUserId = quote.Sales_Rep__c;
            } else if (quote.Sales_Manager__c == currentUserId) {
                hodUserId = quote.Sales_Manager__c;
            } else if (quote.Country_Continent_Sales_Head_LOB_Head__c == currentUserId) {
                hodUserId = quote.Country_Continent_Sales_Head_LOB_Head__c;
            } else if (quote.Managing_Director_Country_Manager__c == currentUserId) {
                hodUserId = quote.Managing_Director_Country_Manager__c;
            } else if (quote.Rotex_Board_Member__c == currentUserId) {
                hodUserId = quote.Rotex_Board_Member__c;
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
        
        @AuraEnabled public String salesManagerName;
        @AuraEnabled public String countryContinentSalesName;
        @AuraEnabled public String rotexBoardMemberName;
        @AuraEnabled public String managingDirectorName;
        @AuraEnabled public String globalSalesHeadName;
        
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Decimal salesPrice;
        @AuraEnabled public Decimal d1;
        @AuraEnabled public Decimal d2;
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
            
            this.Country_Continent_Sales_LOB_Comments = quoteLineItem.Country_Continent_Sales_LOB_Comments__c;
            this.Global_Sales_Head_Comments = quoteLineItem.Global_Sales_Head_Comments__c;
            this.Managing_Director_Comments = quoteLineItem.Managing_Director_Comments__c;
            this.Rotex_Board_Member_Comments = quoteLineItem.Rotex_Board_Member_Comments__c;
            this.Sales_Manager_Comments = quoteLineItem.Sales_Manager_Comments__c;
            
            // Set names
            this.salesManagerName = quoteLineItem.Sales_Manager__r?.Name;
            this.countryContinentSalesName = quoteLineItem.Country_Continent_Sales_Head_LOB_Head__r?.Name;
            this.rotexBoardMemberName = quoteLineItem.Rotex_Board_Member__r?.Name;
            this.managingDirectorName = quoteLineItem.Managing_Director_Country_Manage__r?.Name;
            this.globalSalesHeadName = quoteLineItem.Global_Sales_Head__r?.Name;
            
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
            } else if (quoteLineItem.Global_Sales_Head__c == currentUserId) {
                hodUserId = quoteLineItem.Global_Sales_Head__c;
                this.bcheck5 = false;
                currentStage = quoteLineItem.Global_Sales_Head_Status__c;
                currentStageField = 'Global_Sales_Head_Status__c';
                approvalComments = quoteLineItem.Global_Sales_Head_Comments__c;
            }
            
            this.hodUserId = hodUserId;
            this.currentStage = currentStage;
            this.currentStageField = currentStageField;
            this.d1 = quoteLineItem.Discount_as_per_SAP__c;
            this.d2 = quoteLineItem.Discount_to_be_offered__c;
            this.approvalStatus = currentStage;
            this.approvalComments = approvalComments;
            this.updated = false;
        }
    }
}