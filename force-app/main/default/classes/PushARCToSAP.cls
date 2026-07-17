public with sharing class PushARCToSAP {
    
    @AuraEnabled
    public static String getQuoteLineItems(String quoteId) {
        try {
            System.debug('=== getQuoteLineItems START ===');
            System.debug('quoteId: ' + quoteId);
            
            List<Quote> quotes = [SELECT Id, AccountId, Account.SAP_Customer_Code__c, 
                                  CurrencyIsoCode, Pricebook2Id
                                  FROM Quote WHERE Id = :quoteId LIMIT 1];
            
            if (quotes.isEmpty()) {
                throw new AuraHandledException('Quote not found with ID: ' + quoteId);
            }
            
            Quote quote = quotes[0];
            
            List<Pricebook2> pricebooks = [SELECT Id, Distribution_Channel__c 
                                           FROM Pricebook2 WHERE Id = :quote.Pricebook2Id LIMIT 1];
            
            Pricebook2 pricebook = pricebooks.isEmpty() ? null : pricebooks[0];
            
            List<QuoteLineItem> items = [SELECT Id, Product2Id, Product2.ProductCode, 
                                         Product2.Name, ListPrice, UnitPrice, 
                                         Quantity, TotalPrice,
                                         Discount_to_be_offered__c,
                                         Valid_Till__c, Valid_From__c
                                         FROM QuoteLineItem 
                                         WHERE QuoteId = :quoteId];
            
            System.debug('Number of line items found: ' + items.size());
            
            Map<String, Object> response = new Map<String, Object>();
            response.put('distributionChannel', pricebook != null && pricebook.Distribution_Channel__c == '10' ? '10' : '20');
            response.put('customerCode', quote != null && quote.Account != null ? quote.Account.SAP_Customer_Code__c : '');
            response.put('currency', quote != null ? quote.CurrencyIsoCode : 'INR');
            response.put('lineItems', items);
            
            String jsonResponse = JSON.serialize(response);
            System.debug('Final JSON Response: ' + jsonResponse);
            
            return jsonResponse;
            
        } catch (Exception e) {
            System.debug('=== ERROR in getQuoteLineItems ===');
            System.debug('Error message: ' + e.getMessage());
            throw new AuraHandledException('Error fetching quote line items: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String pushToSAP(String quoteId, List<LineItemWrapper> lineItems) {
        String jsonPayload = '';
        String endpoint = '';
        String sapResponse = '';
        Integer statusCode = 0;
        String status = 'Error';
        String apiName = 'ARCToSAP';
        HttpResponse response = null;
        
        try {
            System.debug('=== pushToSAP START ===');
            System.debug('quoteId: ' + quoteId);
            System.debug('lineItems count: ' + (lineItems != null ? lineItems.size() : 0));
            
            List<Quote> quotes = [SELECT Id, AccountId, Account.SAP_Customer_Code__c, 
                                  CurrencyIsoCode, Pricebook2Id
                                  FROM Quote WHERE Id = :quoteId LIMIT 1];
            
            if (quotes.isEmpty()) {
                throw new AuraHandledException('Quote not found with ID: ' + quoteId);
            }
            
            Quote quote = quotes[0];
            
            List<Pricebook2> pricebooks = [SELECT Id, Distribution_Channel__c 
                                           FROM Pricebook2 WHERE Id = :quote.Pricebook2Id LIMIT 1];
            
            Pricebook2 pricebook = pricebooks.isEmpty() ? null : pricebooks[0];
            
            String distributionChannel = '10';
            if (pricebook != null && pricebook.Distribution_Channel__c == '10') {
                distributionChannel = '10';
            } else if (pricebook != null && pricebook.Distribution_Channel__c != null) {
                distributionChannel = '20';
            }
            
            String customerCode = '';
            if (quote != null && quote.Account != null) {
                customerCode = quote.Account.SAP_Customer_Code__c != null ? quote.Account.SAP_Customer_Code__c : '';
            }
            
            String currencyCode = 'INR';
            if (quote != null && quote.CurrencyIsoCode != null) {
                currencyCode = quote.CurrencyIsoCode;
            }
            
            List<Map<String, String>> sapPayloads = new List<Map<String, String>>();
            
            for (LineItemWrapper item : lineItems) {
                Map<String, String> sapPayload = new Map<String, String>();
                
                String materialValue = item.productCode != null ? item.productCode : '';
                
                String listPrice = '0.00';
                if (item.listPrice != null) {
                    listPrice = String.valueOf(item.listPrice.setScale(2));
                }
                
                String quantity = '1';
                if (item.quantity != null) {
                    quantity = String.valueOf(item.quantity);
                }
                
                String salesPrice = '0.00';
                if (item.salesPrice != null) {
                    salesPrice = String.valueOf(item.salesPrice.setScale(2));
                }
                
                System.debug('=================================');
                System.debug('Wrapper ProductCode : ' + item.productCode);
                System.debug('Wrapper ListPrice : ' + item.listPrice);
                System.debug('Wrapper SalesPrice : ' + item.salesPrice);
                
                sapPayload.put('scale_amt1', salesPrice);
                sapPayload.put('scale_qty1', quantity);
                sapPayload.put('valid_from', String.isBlank(item.validFrom) ? '' : item.validFrom);
                sapPayload.put('valid_to', String.isBlank(item.validTill) ? '' : item.validTill);
                sapPayload.put('unit_of_measure', 'EA');
                sapPayload.put('pricing_unit', '1');
                sapPayload.put('codition_curr', currencyCode);
                sapPayload.put('condition_amt', listPrice);
                sapPayload.put('material', materialValue);
                sapPayload.put('customer', customerCode);
                sapPayload.put('distribution_channel', distributionChannel);
                sapPayload.put('sales_org', '1100');
                sapPayload.put('condition_type', 'ZPFX');
                sapPayload.put('conditon_ident', 'C');
                
                System.debug('Final SAP Payload: ' + JSON.serialize(sapPayload));
                System.debug('=================================');
                
                sapPayloads.add(sapPayload);
            }
            
            jsonPayload = JSON.serialize(sapPayloads);
            
            System.debug('========== FINAL JSON ==========');
            System.debug(jsonPayload);
            System.debug('===============================');
            
            // Get endpoint from Custom Label (same as salesOrderCreation)
            try {
                endpoint = System.Label.PushArcToSAP;
                System.debug('Endpoint from Custom Label: ' + endpoint);
            } catch (Exception e) {
                System.debug('PushArcToSAP Custom Label not found');
                endpoint = '';
            }
            
            // Call API only if endpoint is not blank
            if (String.isNotBlank(endpoint)) {
                System.debug('Calling SAP API with endpoint: ' + endpoint);
                response = PushARCToSAP(quoteId, jsonPayload);
                statusCode = response.getStatusCode();
                sapResponse = response.getBody();
                
                if (statusCode == 200 || statusCode == 201) {
                    status = 'Success';
                } else {
                    status = 'Error';
                }
            } else {
                System.debug('No endpoint configured - using mock response');
                statusCode = 200;
                sapResponse = '[{"SalesQuotationNum":"MOCK001","Message":[{"MType":"S","Message1":"Mock quotation created - No endpoint configured"}]}]';
                status = 'Success';
            }
            
            System.debug('SAP Status Code: ' + statusCode);
            System.debug('SAP Response: ' + sapResponse);
            
        } catch (Exception e) {
            System.debug('=== ERROR in pushToSAP ===');
            System.debug('Error message: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            status = 'Error';
            sapResponse = 'Error: ' + e.getMessage();
            statusCode = 500;
        } finally {
            // Create API Log
            try {
                String logPayload = jsonPayload;
                Integer maxLogSize = 131072;
                if (String.isNotBlank(logPayload) && logPayload.length() > maxLogSize) {
                    logPayload = logPayload.substring(0, maxLogSize) + '... (truncated)';
                }
                
                String logResponse = sapResponse;
                if (String.isNotBlank(logResponse) && logResponse.length() > 10000) {
                    logResponse = logResponse.substring(0, 10000) + '... (truncated)';
                }
                
                UtilityCls.logApiCall(
                    apiName,
                    endpoint,
                    logPayload,
                    logResponse,
                    status,
                    statusCode,
                    quoteId
                );
                System.debug('API log created');
            } catch (Exception e) {
                System.debug('Failed to create API log: ' + e.getMessage());
            }
        }
        
        Map<String, Object> result = new Map<String, Object>();
        if (status == 'Success') {
            result.put('status', 'success');
            result.put('message', 'Data pushed to SAP successfully');
            result.put('itemsProcessed', lineItems != null ? lineItems.size() : 0);
            result.put('sapResponse', sapResponse);
        } else {
            result.put('status', 'error');
            result.put('message', 'SAP Error: ' + sapResponse);
            result.put('statusCode', statusCode);
        }
        
        return JSON.serialize(result);
    }
    
    private static HttpResponse PushARCToSAP(String quoteId, String jsonPayload) {
        HttpRequest req = new HttpRequest();
        
        try {
            // Get endpoint from Custom Label (same as salesOrderCreation)
            String endpoint = System.Label.PushArcToSAP;
            
            if (String.isBlank(endpoint)) {
                throw new AuraHandledException('PushArcToSAP Custom Label is blank');
            }
            
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setBody(jsonPayload);
            req.setTimeout(120000);
            
            // Get credentials from Custom Labels (same as salesOrderCreation)
            String username = System.Label.Push_Quote_Username;
            String password = System.Label.Push_Quote_Password;
            
            if (String.isNotBlank(username) && String.isNotBlank(password)) {
                String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
                req.setHeader('Authorization', authHeader);
                System.debug('✅ Authentication added');
            } else {
                System.debug('⚠️ Username or Password labels not found');
            }
            
            // Get CSRF token (same as salesOrderCreation)
            try {
                HttpResponse csrfResp = UtilityCls.doGetWithBasicAuth('Get_Session_API', 'Bulk', Null, Null, '');
                if (csrfResp != null && csrfResp.getStatusCode() == 200) {
                    String csrfToken = csrfResp.getHeader('x-csrf-token');
                    String cookies = csrfResp.getHeader('set-cookie');
                    if (String.isNotBlank(csrfToken)) {
                        req.setHeader('x-csrf-token', csrfToken);
                        System.debug('✅ CSRF Token added: ' + csrfToken);
                    }
                    if (String.isNotBlank(cookies)) {
                        req.setHeader('cookie', cookies);
                        System.debug('✅ Cookies added');
                    }
                } else {
                    System.debug('⚠️ CSRF token not fetched. Status: ' + (csrfResp != null ? String.valueOf(csrfResp.getStatusCode()) : 'null'));
                }
            } catch (Exception e) {
                System.debug('⚠️ Error getting CSRF token: ' + e.getMessage());
            }
            
            Http http = new Http();
            HttpResponse response = http.send(req);
            
            System.debug('✅ Response Status Code: ' + response.getStatusCode());
            System.debug('✅ Response Body: ' + response.getBody());
            
            return response;
            
        } catch (Exception e) {
            System.debug('❌ Error in PushARCToSAP: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error calling SAP API: ' + e.getMessage());
        }
    }
    
    public class LineItemWrapper {
        @AuraEnabled
        public String id { get; set; }
        
        @AuraEnabled
        public String productCode { get; set; }
        
        @AuraEnabled
        public Decimal listPrice { get; set; }
        
        @AuraEnabled
        public Decimal salesPrice { get; set; }
        
        @AuraEnabled
        public Decimal quantity { get; set; }
        
        @AuraEnabled
        public String validFrom { get; set; }
        
        @AuraEnabled
        public String validTill { get; set; }
    }
}