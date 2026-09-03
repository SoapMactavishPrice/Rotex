public without sharing class DealerQuoteSapController {

    public class SapQuoteRequest {
        @AuraEnabled public Id quoteId { get; set; }
        @AuraEnabled public String requestedDeliveryDate { get; set; }
        @AuraEnabled public String customerReferenceDate { get; set; }
        @AuraEnabled public String customerReferenceNo { get; set; }
        @AuraEnabled public Id billToPartnerId { get; set; }
        @AuraEnabled public Id shipToPartnerId { get; set; }
        @AuraEnabled public Id salesAgentPartnerId { get; set; }
        @AuraEnabled public String pbgOrBgRequired { get; set; }
        @AuraEnabled public String pbgOrBgComments { get; set; }
        @AuraEnabled public String ldClauseApplicable { get; set; }
        @AuraEnabled public String ldClauseComments { get; set; }
        @AuraEnabled public String salesQuotationType { get; set; }
        @AuraEnabled public List<String> fileNames { get; set; }
        @AuraEnabled public List<LineItemRoundOffInput> lineItems { get; set; }
    }

    public class LineItemRoundOffInput {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Decimal roundOff { get; set; }
    }

    public class QuoteWrapper {
        public String SalesQuotationType;
        public String SalesOrganization;
        public String DistributionChannel;
        public String OrganizationDivision;
        public String SoldToParty;
        public String PurchaseOrderByCustomer;
        public String CustomerPurchaseOrderDate;
        public String RequestedDeliveryDate;
        public String BindingPeriodValidityStartDate;
        public String BindingPeriodValidityEndDate;
        public List<PartnerWrapper> to_Partner;
        public List<QuoteLineItemWrapper> to_Item;
        public String SalesQuotationNum;
        public String Assigned_To;
        public String Delivery_Period;
        public String Warranty_Terms;
        public String Liquidity_Terms;
        public String revision_no;
        public String revision_date;
        public String Pbg_Or_Bg_Required;
        public String Pbg_Or_Bg_Comments;
        public String LD_Clause_Applicable;
        public String LD_Clause_Comments;
        public String Remarks;
        public String Special_Remarks;
        public List<AttachmentWrapper> Attachments;
    }

    public class AttachmentWrapper {
        public String Name;
        public String Data;
    }

    public class PartnerWrapper {
        public String PartnerFunction;
        public String Customer;
    }

    public class QuoteLineItemWrapper {
        public String SalesQuotationItem;
        public String Material;
        public String RequestedQuantity;
        public String Plant;
        public String Customer_Material;
        public List<PricingElementWrapper> to_PricingElement;
        public List<ConditionWrapper> CONDITIONS;
    }

    public class ConditionWrapper {
        public String Cond_type;
        public String Cond_Value;
    }

    public class PricingElementWrapper {
        public String PricingProcedureStep;
        public String PricingProcedureCounter;
        public String ConditionType;
        public String ConditionRateValue;
        public String ConditionCurrency;
    }

    @AuraEnabled
    public static String getQuoteSapData(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }

        assertQuoteAccessible(quoteId);

        Quote q = [
            SELECT Id, QuoteNumber, RequestedDeliveryDate__c, Customer_Reference_Date__c,
                   Customer_Reference_No__c, SAP_Quotation_Number__c, Status,
                   PBG_or_BG_required__c, PBG_or_BG_comments__c,
                   LD_Clause_Applicable__c, LD_Clause_comments__c, Sales_Quotation_Type__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        Map<String, Object> response = new Map<String, Object>();
        response.put('quote', q);
        response.put('hasPoAttachment', hasQuoteAttachment(quoteId));
        response.put('validation', JSON.deserializeUntyped(quoteValidation(String.valueOf(quoteId))));
        response.put('sapData', JSON.deserializeUntyped(getLineItem(String.valueOf(quoteId))));
        return JSON.serialize(response);
    }

    @AuraEnabled
    public static void updateQuoteSapDetails(SapQuoteRequest input) {
        if (input == null || input.quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        if (String.isBlank(input.requestedDeliveryDate)
            || String.isBlank(input.customerReferenceDate)
            || String.isBlank(input.customerReferenceNo)
            || input.billToPartnerId == null
            || input.shipToPartnerId == null) {
            throw new AuraHandledException('Please fill/select all the mandatory fields.');
        }

        assertQuoteAccessible(input.quoteId);

        Quote q = new Quote(Id = input.quoteId);
        q.RequestedDeliveryDate__c = parseDate(input.requestedDeliveryDate);
        q.Customer_Reference_Date__c = parseDate(input.customerReferenceDate);
        q.Customer_Reference_No__c = input.customerReferenceNo.trim();
        q.PBG_or_BG_required__c = blankToNull(input.pbgOrBgRequired);
        q.PBG_or_BG_comments__c = (input.pbgOrBgRequired == 'Yes')
            ? blankToNull(input.pbgOrBgComments)
            : null;
        q.LD_Clause_Applicable__c = blankToNull(input.ldClauseApplicable);
        q.LD_Clause_comments__c = (input.ldClauseApplicable == 'Yes')
            ? blankToNull(input.ldClauseComments)
            : null;
        update q;

        if (input.lineItems != null && !input.lineItems.isEmpty()) {
            List<QuoteLineItem> qliUpdates = new List<QuoteLineItem>();
            for (LineItemRoundOffInput row : input.lineItems) {
                if (row == null || row.id == null) {
                    continue;
                }
                qliUpdates.add(new QuoteLineItem(
                    Id = row.id,
                    Round_Off__c = row.roundOff
                ));
            }
            if (!qliUpdates.isEmpty()) {
                update qliUpdates;
            }
        }
    }

    @AuraEnabled
    public static String sendQuoteToSap(SapQuoteRequest input) {
        if (input == null || input.quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        if (input.billToPartnerId == null || input.shipToPartnerId == null) {
            throw new AuraHandledException('Please fill/select all the mandatory fields.');
        }

        assertQuoteAccessible(input.quoteId);

        Map<String, Object> validation =
            (Map<String, Object>) JSON.deserializeUntyped(quoteValidation(String.valueOf(input.quoteId)));
        if (String.valueOf(validation.get('status')) != 'true') {
            throw new AuraHandledException(String.valueOf(validation.get('message')));
        }

        String salesQuotationType = String.isNotBlank(input.salesQuotationType)
            ? input.salesQuotationType
            : 'ZQT';
        List<String> fileNames = input.fileNames == null ? new List<String>() : input.fileNames;

        // Same flow as IntegrationHandler.salesOrderCreation
        return salesOrderCreation(
            String.valueOf(input.quoteId),
            String.valueOf(input.billToPartnerId),
            String.valueOf(input.shipToPartnerId),
            input.salesAgentPartnerId == null ? null : String.valueOf(input.salesAgentPartnerId),
            salesQuotationType,
            fileNames
        );
    }

    @AuraEnabled
    public static String updateSapQuotationNumber(Id quoteId, String sapQuotationNumber) {
        if (quoteId == null || String.isBlank(sapQuotationNumber)) {
            throw new AuraHandledException('SAP Quotation Number is required.');
        }

        assertQuoteAccessible(quoteId);
        return updateQuotation(String.valueOf(quoteId), sapQuotationNumber);
    }

    private static String quoteValidation(String qId) {
        Map<String, String> retResData = new Map<String, String>();
        retResData.put('status', 'true');
        retResData.put('message', '');

        Quote q = [
            SELECT Id, CustomerPurchaseOrderDate__c, RequestedDeliveryDate__c,
                   Quote_Date__c, Quote_Valid_Till__c, Status, SAP_Quotation_Number__c
            FROM Quote
            WHERE Id = :qId
            LIMIT 1
        ];

        if (q.Status != 'Accepted') {
            retResData.put('status', 'false');
            retResData.put('sync', 'false');
            retResData.put('message', 'Quote status is not Accepted');
        }

        return JSON.serialize(retResData);
    }

    private static String getLineItem(String qId) {
        Map<String, Object> respMap = new Map<String, Object>();

        Quote quoteRecord = [
            SELECT Id, AccountId
            FROM Quote
            WHERE Id = :qId
            LIMIT 1
        ];

        List<QuoteLineItem> quoteLineItemList = [
            SELECT Id, Product2Id, Product2.ProductCode, QuoteId, ListPrice, UnitPrice, Quantity,
                   Product2.Name, TotalPrice, Discount_to_be_offered__c, Round_Off__c, Quote.AccountId
            FROM QuoteLineItem
            WHERE QuoteId = :qId
        ];

        respMap.put('quoteLineItemList', quoteLineItemList);

        Id accountId = quoteRecord.AccountId;
        if (accountId == null && !quoteLineItemList.isEmpty()) {
            accountId = quoteLineItemList[0].Quote.AccountId;
        }

        List<Partner_Details__c> bpList = new List<Partner_Details__c>();
        List<Partner_Details__c> shList = new List<Partner_Details__c>();
        List<Partner_Details__c> caList = new List<Partner_Details__c>();

        if (accountId != null) {
            List<Sales_Area_Item__c> salesAreaItemList = [
                SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Incoterms__c
                FROM Sales_Area_Item__c
                WHERE Sales_Org__c = '1100'
                  AND Division__c != '50'
                  AND Division__c != '20'
                  AND Division__c != '00'
                  AND Account__c = :accountId
            ];

            Set<Id> salesAreaItemIdSet = new Set<Id>();
            for (Sales_Area_Item__c sai : salesAreaItemList) {
                salesAreaItemIdSet.add(sai.Id);
            }

            if (!salesAreaItemIdSet.isEmpty()) {
                for (Partner_Details__c pd : [
                    SELECT Id, Name, Partner_Function__c, Partner_No__c,
                           Street__c, City__c, District__c, State__c, Country__c, Postal_Code__c
                    FROM Partner_Details__c
                    WHERE Sales_Area_Item__c IN :salesAreaItemIdSet
                ]) {
                    if (pd.Partner_Function__c == 'BP') {
                        bpList.add(pd);
                    } else if (pd.Partner_Function__c == 'SH') {
                        shList.add(pd);
                    } else if (pd.Partner_Function__c == 'CA') {
                        caList.add(pd);
                    }
                }
            }
        }

        respMap.put('bpList', bpList);
        respMap.put('shList', shList);
        respMap.put('caList', caList);

        return JSON.serialize(respMap);
    }

    private static String salesOrderCreation(
        String parentId,
        String bpFuncId,
        String shFuncId,
        String caFuncId,
        String salesQuotationType,
        List<String> fileNames
    ) {
        String jsonPayload = '';
        HttpResponse resp;
        HttpResponse response;
        String errorMessage = '';
        Boolean sapSuccess = false;
        String quotationNumber = '';

        try {
            jsonPayload = getQuotePayload(parentId, bpFuncId, shFuncId, caFuncId, salesQuotationType, fileNames);

            if (String.isBlank(jsonPayload)) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'quotationNumber' => '',
                    'error' => 'Failed to generate payload'
                });
            }

            resp = DealerUtilityCls.doGetWithBasicAuth('Get_Session_API', 'Bulk', null, null, '');

            if (resp != null && resp.getStatusCode() == 200) {
                String csrfToken = resp.getHeader('x-csrf-token');
                String cookies = resp.getHeader('set-cookie');

                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint(System.Label.Push_Quote_to_SAP);
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setHeader('Accept', 'application/json');
                request.setBody(jsonPayload);

                String username = System.Label.Push_Quote_Username;
                String password = System.Label.Push_Quote_Password;
                String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
                request.setHeader('Authorization', authHeader);
                request.setHeader('x-csrf-token', csrfToken);
                request.setHeader('cookie', cookies);
                request.setTimeout(120000);

                try {
                    response = http.send(request);
                } catch (Exception e) {
                    errorMessage = 'HTTP Request failed: ' + e.getMessage();
                    response = null;
                }

                if (response != null && (response.getStatusCode() == 200 || response.getStatusCode() == 201)) {
                    String responseBody = response.getBody();

                    if (String.isNotBlank(responseBody)) {
                        try {
                            List<Object> respList = (List<Object>) JSON.deserializeUntyped(responseBody);
                            if (respList != null && !respList.isEmpty()) {
                                Map<String, Object> firstResp = (Map<String, Object>) respList[0];
                                quotationNumber = String.valueOf(firstResp.get('SalesQuotationNum'));

                                if (firstResp.containsKey('Message')) {
                                    Object messageObj = firstResp.get('Message');
                                    if (messageObj instanceof List<Object>) {
                                        List<Object> messages = (List<Object>) messageObj;
                                        Boolean hasError = false;
                                        for (Object msg : messages) {
                                            Map<String, Object> msgMap = (Map<String, Object>) msg;
                                            if ('E'.equals(msgMap.get('MType'))) {
                                                errorMessage = String.valueOf(msgMap.get('Message1'));
                                                hasError = true;
                                            }
                                        }
                                        if (!hasError && String.isNotBlank(quotationNumber)) {
                                            sapSuccess = true;
                                        }
                                    }
                                } else if (String.isNotBlank(quotationNumber)) {
                                    sapSuccess = true;
                                }
                            }
                        } catch (Exception e) {
                            System.debug('Parse error: ' + e.getMessage());
                        }
                    }

                    if (String.isBlank(quotationNumber)) {
                        String locationHeader = response.getHeader('Location');
                        if (String.isNotBlank(locationHeader) && locationHeader.contains('SalesQuotation(')) {
                            String temp = locationHeader.substring(locationHeader.indexOf('SalesQuotation(') + 16);
                            quotationNumber = temp.substring(0, temp.indexOf('\''));
                            if (String.isNotBlank(quotationNumber)) {
                                sapSuccess = true;
                            }
                        }
                    }

                    if (sapSuccess && String.isNotBlank(quotationNumber)) {
                        update new Quote(Id = parentId, SAP_Quotation_Number__c = quotationNumber);
                    }
                } else if (response != null) {
                    errorMessage = 'SAP API Error: ' + response.getStatusCode() + ' - ' + response.getBody();
                } else if (String.isBlank(errorMessage)) {
                    errorMessage = 'No response from SAP (connection timeout or network error)';
                }
            } else {
                errorMessage = 'Failed to get CSRF token from SAP';
            }
        } catch (Exception e) {
            errorMessage = 'Exception: ' + e.getMessage();
        } finally {
            try {
                update new Quote(Id = parentId, Sales_Quotation_Type__c = salesQuotationType);
            } catch (Exception e) {
                System.debug('Failed to update Quote Sales Quotation Type: ' + e.getMessage());
            }

            try {
                String logPayload = '';
                String logResponse = '';
                String logStatus = '';
                Integer statusCode = 0;
                Integer maxLogSize = 131072;

                if (String.isNotBlank(jsonPayload)) {
                    try {
                        Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(jsonPayload);

                        if (payloadMap.containsKey('Attachments')) {
                            Object attachmentsObj = payloadMap.get('Attachments');
                            if (attachmentsObj instanceof List<Object>) {
                                List<Object> attachments = (List<Object>) attachmentsObj;
                                List<Object> attachmentsToKeep = new List<Object>();
                                Integer totalSize = 0;
                                Integer individualFileLimit = 5000;
                                Integer totalLogLimit = 10000;

                                for (Object att : attachments) {
                                    String attJson = JSON.serialize(att);
                                    Integer attSize = attJson.length();
                                    if (attSize < individualFileLimit) {
                                        attachmentsToKeep.add(att);
                                        totalSize += attSize;
                                    }
                                }

                                if (totalSize > totalLogLimit || attachmentsToKeep.isEmpty()) {
                                    payloadMap.remove('Attachments');
                                } else {
                                    payloadMap.put('Attachments', attachmentsToKeep);
                                }
                            }
                        }

                        payloadMap.remove('Attachment1');
                        payloadMap.remove('Attachment2');
                        payloadMap.remove('Attachment3');
                        payloadMap.remove('Attachment4');
                        payloadMap.remove('Attachment5');

                        logPayload = JSON.serialize(payloadMap);
                    } catch (Exception e) {
                        logPayload = jsonPayload.length() > 1000
                            ? jsonPayload.substring(0, 1000) + '... (truncated)'
                            : jsonPayload;
                    }

                    if (logPayload.length() > maxLogSize) {
                        logPayload = logPayload.substring(0, maxLogSize) + '... (truncated)';
                    }
                } else {
                    logPayload = 'No payload generated';
                }

                if (response != null) {
                    statusCode = response.getStatusCode();
                    logStatus = String.valueOf(statusCode);
                    if (String.isNotBlank(response.getBody())) {
                        logResponse = response.getBody();
                        if (logResponse.length() > 5000) {
                            logResponse = logResponse.substring(0, 5000) + '... (truncated)';
                        }
                    } else {
                        logResponse = 'Empty response body';
                    }
                } else {
                    logResponse = String.isNotBlank(errorMessage) ? errorMessage : 'No response from SAP';
                    logStatus = '0';
                    statusCode = 0;
                }

                DealerUtilityCls.logApiCall(
                    'QuotationCreation',
                    '',
                    logPayload,
                    logResponse,
                    logStatus,
                    statusCode,
                    parentId
                );
            } catch (Exception e) {
                System.debug('Failed to create API log: ' + e.getMessage());
            }
        }

        Map<String, Object> responseMap = new Map<String, Object>();
        responseMap.put('success', sapSuccess);
        responseMap.put('quotationNumber', quotationNumber);
        responseMap.put('error', errorMessage);
        return JSON.serialize(responseMap);
    }

    private static String getQuotePayload(
        String quoteId,
        String bpId,
        String shId,
        String caId,
        String salesQuotationType,
        List<String> specificFileNames
    ) {
        String jsonPayload = '';
        try {
            List<Quote> quoteList = [
                SELECT Id, Name, QuoteNumber, OpportunityId, AccountId, BillingCity, BillingState, BillingCountry,
                       BillingPostalCode, ShippingCity, ShippingState, ShippingCountry, ShippingPostalCode, Status,
                       TotalPrice, Subtotal, Discount, Quote_Type__c, SalesOrganization__c, DistributionChannel__c,
                       OrganizationDivision__c, CurrencyISOCode, SoldToParty__c, PurchaseOrderByCustomer__c,
                       CustomerPurchaseOrderDate__c, Account.Discount__c,
                       Opportunity.Pricebook2.Distribution_Channel__c,
                       RequestedDeliveryDate__c, Quote_Date__c, Quote_Valid_Till__c, Account.SAP_Customer_Code__c,
                       Customer_Reference_Date__c, Delivery_Period__c, Warranty_Terms__c, Liquidate_Terms__c,
                       SAP_Quotation_Number__c, OwnerId, Owner.Name, Rev_No__c, Rev_Date__c,
                       PBG_or_BG_required__c, PBG_or_BG_comments__c, LD_Clause_Applicable__c, LD_Clause_comments__c,
                       Customer_Reference_No__c, Special_Remarks__c
                FROM Quote
                WHERE Id = :quoteId
            ];

            if (quoteList.isEmpty()) {
                return '';
            }

            Set<Id> quoteIds = new Set<Id>();
            for (Quote q : quoteList) {
                quoteIds.add(q.Id);
            }

            List<QuoteLineItem> quoteLineItemList = [
                SELECT Id, QuoteId, Quantity, UnitPrice, ListPrice, TotalPrice, Discount, Product2Id, Product2.Name, Plant__c,
                       LineNumber, Product2.ProductCode, Discount_to_be_offered__c, Quote.CurrencyISOCode,
                       Round_Off__c, Customer_Part_No__c, P_F_Charges__c
                FROM QuoteLineItem
                WHERE QuoteId IN :quoteIds
            ];

            String distChannel = quoteList[0].Opportunity != null
                && quoteList[0].Opportunity.Pricebook2 != null
                && String.isNotBlank(quoteList[0].Opportunity.Pricebook2.Distribution_Channel__c)
                    ? quoteList[0].Opportunity.Pricebook2.Distribution_Channel__c
                    : '10';

            Sales_Area_Item__c saItem = [
                SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c
                FROM Sales_Area_Item__c
                WHERE Sales_Org__c = '1100'
                  AND Division__c != '50'
                  AND Division__c != '20'
                  AND Division__c != '00'
                  AND Distribution_Channel__c = :distChannel
                  AND Account__c = :quoteList[0].AccountId
                LIMIT 1
            ];

            Set<String> pdIdsSet = new Set<String>();
            if (String.isNotBlank(bpId)) {
                pdIdsSet.add(bpId);
            }
            if (String.isNotBlank(shId)) {
                pdIdsSet.add(shId);
            }
            if (String.isNotBlank(caId)) {
                pdIdsSet.add(caId);
            }

            List<Partner_Details__c> partnerDetailsList = new List<Partner_Details__c>();
            if (!pdIdsSet.isEmpty()) {
                partnerDetailsList = [
                    SELECT Id, Partner_Function__c, Customer__c, Partner_No__c
                    FROM Partner_Details__c
                    WHERE Id IN :pdIdsSet
                ];
            }

            List<QuoteWrapper> quoteWrapperList = new List<QuoteWrapper>();
            for (Quote q : quoteList) {
                QuoteWrapper quoteWrapper = new QuoteWrapper();
                quoteWrapper.SalesQuotationNum = q.SAP_Quotation_Number__c;
                quoteWrapper.Assigned_To = q.Owner.Name;
                quoteWrapper.revision_no = String.valueOf(q.Rev_No__c);
                quoteWrapper.revision_date = q.Rev_Date__c != null
                    ? Datetime.newInstance(q.Rev_Date__c, Time.newInstance(0, 0, 0, 0)).format('dd.MM.yyyy')
                    : null;

                quoteWrapper.Delivery_Period = String.valueOf(q.Delivery_Period__c);
                quoteWrapper.Warranty_Terms = q.Warranty_Terms__c;
                quoteWrapper.Liquidity_Terms = q.Liquidate_Terms__c;
                quoteWrapper.SalesQuotationType = String.isNotBlank(salesQuotationType) ? salesQuotationType : 'ZQT';
                quoteWrapper.SalesOrganization = saItem.Sales_Org__c;
                quoteWrapper.DistributionChannel = saItem.Distribution_Channel__c;
                quoteWrapper.OrganizationDivision = saItem.Division__c;
                quoteWrapper.SoldToParty = q.Account.SAP_Customer_Code__c;
                quoteWrapper.PurchaseOrderByCustomer = q.Customer_Reference_No__c;
                quoteWrapper.CustomerPurchaseOrderDate = q.Customer_Reference_Date__c != null
                    ? DateTime.newInstance(q.Customer_Reference_Date__c, Time.newInstance(0, 0, 0, 0)).format('dd.MM.yyyy')
                    : null;
                quoteWrapper.RequestedDeliveryDate = q.RequestedDeliveryDate__c != null
                    ? DateTime.newInstance(q.RequestedDeliveryDate__c, Time.newInstance(0, 0, 0, 0)).format('dd.MM.yyyy')
                    : null;

                Date todayDate = Date.today();
                Date endDate = q.Quote_Valid_Till__c != null ? q.Quote_Valid_Till__c : todayDate.addDays(30);
                quoteWrapper.BindingPeriodValidityStartDate =
                    DateTime.newInstance(todayDate, Time.newInstance(0, 0, 0, 0)).format('dd.MM.yyyy');
                quoteWrapper.BindingPeriodValidityEndDate =
                    DateTime.newInstance(endDate, Time.newInstance(0, 0, 0, 0)).format('dd.MM.yyyy');

                quoteWrapper.Pbg_Or_Bg_Required = q.PBG_or_BG_required__c;
                quoteWrapper.Pbg_Or_Bg_Comments =
                    (q.PBG_or_BG_required__c == 'Yes') ? q.PBG_or_BG_comments__c : '';
                quoteWrapper.LD_Clause_Applicable = q.LD_Clause_Applicable__c;
                quoteWrapper.LD_Clause_Comments =
                    (q.LD_Clause_Applicable__c == 'Yes') ? q.LD_Clause_comments__c : '';

                quoteWrapper.Remarks =
                    'This quotation has been approved after completing Rotex SOA Process for further action';
                quoteWrapper.Special_Remarks =
                    String.isNotBlank(q.Special_Remarks__c) ? q.Special_Remarks__c : '';

                quoteWrapper.to_Partner = new List<PartnerWrapper>();
                for (Partner_Details__c pd : partnerDetailsList) {
                    PartnerWrapper partnerWrapper = new PartnerWrapper();
                    partnerWrapper.PartnerFunction = pd.Partner_Function__c;
                    partnerWrapper.Customer = pd.Partner_No__c;
                    quoteWrapper.to_Partner.add(partnerWrapper);
                }

                quoteWrapper.to_Item = new List<QuoteLineItemWrapper>();
                Integer ind = 10;
                for (QuoteLineItem qli : quoteLineItemList) {
                    if (qli.QuoteId == q.Id) {
                        QuoteLineItemWrapper lineItemWrapper = new QuoteLineItemWrapper();
                        lineItemWrapper.SalesQuotationItem = String.valueOf(ind);
                        lineItemWrapper.Material = qli.Product2.ProductCode;
                        lineItemWrapper.RequestedQuantity = String.valueOf(qli.Quantity);
                        lineItemWrapper.Plant = saItem.Sales_Org__c;
                        lineItemWrapper.Customer_Material =
                            qli.Customer_Part_No__c != null ? qli.Customer_Part_No__c : '';

                        List<ConditionWrapper> conditions = new List<ConditionWrapper>();

                        ConditionWrapper cond1 = new ConditionWrapper();
                        if (qli.Discount_to_be_offered__c != null && qli.Discount_to_be_offered__c < 0) {
                            cond1.Cond_type = 'ZLPA';
                            cond1.Cond_Value = String.valueOf(qli.Discount_to_be_offered__c * -1);
                        } else {
                            cond1.Cond_type = 'ZDIS';
                            cond1.Cond_Value = qli.Discount_to_be_offered__c != null
                                ? String.valueOf(qli.Discount_to_be_offered__c)
                                : '';
                        }
                        conditions.add(cond1);

                        ConditionWrapper cond2 = new ConditionWrapper();
                        cond2.Cond_type = 'ZROF';
                        cond2.Cond_Value = qli.Round_Off__c != null ? String.valueOf(qli.Round_Off__c) : '0.00';
                        conditions.add(cond2);

                        ConditionWrapper cond3 = new ConditionWrapper();
                        cond3.Cond_type = 'ZPFC';
                        cond3.Cond_Value = qli.P_F_Charges__c != null ? String.valueOf(qli.P_F_Charges__c) : '0.00';
                        conditions.add(cond3);

                        lineItemWrapper.CONDITIONS = conditions;
                        quoteWrapper.to_Item.add(lineItemWrapper);
                        ind = ind + 10;
                    }
                }

                List<AttachmentWrapper> attachments = new List<AttachmentWrapper>();
                if (specificFileNames != null && !specificFileNames.isEmpty()) {
                    for (String fileName : specificFileNames) {
                        List<ContentDocumentLink> docLinks = [
                            SELECT ContentDocumentId, ContentDocument.Title, Id
                            FROM ContentDocumentLink
                            WHERE LinkedEntityId = :q.Id
                              AND ContentDocument.Title = :fileName
                            ORDER BY SystemModstamp DESC
                            LIMIT 1
                        ];

                        if (!docLinks.isEmpty()) {
                            List<ContentVersion> cvList = [
                                SELECT Id, ContentDocumentId, VersionData, FileType, Title
                                FROM ContentVersion
                                WHERE ContentDocumentId = :docLinks[0].ContentDocumentId
                                  AND IsLatest = true
                                ORDER BY SystemModstamp DESC
                                LIMIT 1
                            ];

                            if (!cvList.isEmpty() && cvList[0].VersionData != null) {
                                AttachmentWrapper wrapper = new AttachmentWrapper();
                                wrapper.Name = cvList[0].Title;
                                wrapper.Data = EncodingUtil.base64Encode(cvList[0].VersionData);
                                attachments.add(wrapper);
                            }
                        }
                    }
                }

                quoteWrapper.Attachments = attachments;
                quoteWrapperList.add(quoteWrapper);
            }

            if (!quoteWrapperList.isEmpty()) {
                jsonPayload = JSON.serialize(quoteWrapperList[0], false);
            }
        } catch (Exception e) {
            System.debug('getQuotePayload Exception: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            jsonPayload = '';
        }

        return jsonPayload;
    }

    private static String updateQuotation(String qId, String qNumber) {
        Quote q = [
            SELECT Id, SAP_Quotation_Number__c, Status
            FROM Quote
            WHERE Id = :qId
            LIMIT 1
        ];
        q.SAP_Quotation_Number__c = qNumber;
        update q;
        return 'ok';
    }

    private static Date parseDate(String value) {
        return String.isBlank(value) ? null : Date.valueOf(value);
    }

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value.trim();
    }

    private static Boolean hasQuoteAttachment(Id quoteId) {
        if (quoteId == null) {
            return false;
        }
        Integer count = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId
        ];
        return count > 0;
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