public with sharing class ZPR0PricingAPI {
    
    public class ZPR0Request {
        public String conditon_ident, condition_type, valid_to;
    }
    
    public static void ZPR0Pricing() {
        
        HttpResponse resp;
        String requestBody = '';
        Integer total = 0, prepared = 0, success = 0, failed = 0, productNotFound = 0, pricebookNotFound = 0;
        List<String> logs = new List<String>();
        
        try {
            Date dateOfExc = Date.today();
            
            ZPR0Request req = new ZPR0Request();
            req.conditon_ident = 'P';
            req.condition_type = 'ZPR0';
            req.valid_to = String.valueOf(dateOfExc);
            //req.valid_to = '2026-08-31';
            
            requestBody = JSON.serialize(new List<ZPR0Request>{ req });
            resp = UtilityCls.doPostWithBasicAuth('ZPR0_API', requestBody);
            
            if(resp.getStatusCode() != 200) throw new CalloutException('API failed. Status: ' + resp.getStatusCode());
            if(String.isBlank(resp.getBody())) throw new CalloutException('Empty SAP response.');
            
            List<IntegrationRequestBuilder.ZPR0Response> responses = IntegrationRequestBuilder.ZPR0ResponseParse(resp.getBody());
            total = responses.size();
            
            // Get normalized SAP Product Codes
            Set<String> productCodes = new Set<String>();
            for(IntegrationRequestBuilder.ZPR0Response r : responses) {
                String code = normalize(r.Material);
                if(code != null) productCodes.add(code);
            }
            
            // Product Map
            Map<String, Id> productMap = new Map<String, Id>();
            for(Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :productCodes])
                productMap.put(normalize(p.ProductCode), p.Id);
            
            // Pricebook Map
            Map<String, Id> pricebookMap = new Map<String, Id>();
            for(Pricebook2 pb : [SELECT Id, Distribution_Channel__c, Channel_Partner__c FROM Pricebook2 WHERE Distribution_Channel__c != null AND Channel_Partner__c=null])
                pricebookMap.put(clean(pb.Distribution_Channel__c), pb.Id);
             
            
            // Existing Pricebook Entry Map - Store only Id
            Map<String, Id> existingPBEMap = new Map<String, Id>();
            
            if(!productMap.isEmpty()) {
                for(PricebookEntry pbe : [
                    SELECT Id, Product2.ProductCode, Sales_Org__c,
                    Distribution_Channel__c, CurrencyIsoCode
                    FROM PricebookEntry
                    WHERE Product2Id IN :productMap.values()
                ]) {
                    existingPBEMap.put(
                        getKey(normalize(pbe.Product2.ProductCode), pbe.Sales_Org__c, pbe.Distribution_Channel__c, pbe.CurrencyIsoCode),
                        pbe.Id
                    );
                }
            }
            
            // Prepare Insert / Update Records
            Map<String, PricebookEntry> pbeToSave = new Map<String, PricebookEntry>();
            
            for(IntegrationRequestBuilder.ZPR0Response r : responses) {
                
                try {
                    
                    String productCode = normalize(r.Material);
                    String salesOrg = clean(r.SalesOrg);
                    String channel = clean(r.DistributionChannel);
                    String currencyCode = clean(r.CoditionCurr);
                    
                    if(productCode == null || !productMap.containsKey(productCode)) {
                        productNotFound++;
                        logs.add('PRODUCT NOT FOUND | SAP: ' + r.Material + ' | ProductCode: ' + productCode);
                        continue;
                    }
                    
                    Id pricebookId = pricebookMap.get(channel);
                    
                    if(pricebookId == null) {
                        pricebookNotFound++;
                        logs.add('PRICEBOOK NOT FOUND | Product: ' + productCode + ' | Channel: ' + channel);
                        continue;
                    }
                    
                    String key = getKey(productCode, salesOrg, channel, currencyCode);
                    
                    // Fresh SObject for both Insert and Update
                    PricebookEntry pbe = existingPBEMap.containsKey(key)
                        ? new PricebookEntry(Id = existingPBEMap.get(key))
                        : new PricebookEntry(
                            Pricebook2Id = pricebookId,
                            Product2Id = productMap.get(productCode),
                            Sales_Org__c = salesOrg,
                            Distribution_Channel__c = channel,
                            CurrencyIsoCode = currencyCode,
                            IsActive = true,
                            UseStandardPrice = false
                        );
                    
                    pbe.UnitPrice = toDecimal(r.ConditionAmt);
                    pbe.Pricing_Unit__c = toDecimal(r.PricingUnit);
                    pbe.Unit_of_Measure__c = clean(r.UnitOfMeasure);
                    pbe.Valid_From__c = parseSAPDate(r.ValidFrom);
                    pbe.Valid_To__c = parseSAPDate(r.ValidTo);
                    
                    pbeToSave.put(key, pbe);
                    
                } catch(Exception ex) {
                    failed++;
                    logs.add('RECORD ERROR | Material: ' + r.Material + ' | ' + ex.getMessage());
                }
            }
            
            prepared = pbeToSave.size();
            
            // DML
            if(!pbeToSave.isEmpty()) {
                
                Database.UpsertResult[] results = Database.upsert(pbeToSave.values(), false);
                
                for(Database.UpsertResult result : results) {
                    if(result.isSuccess()) success++;
                    else {
                        failed++;
                        for(Database.Error err : result.getErrors())
                            logs.add('DML ERROR | ' + err.getMessage());
                    }
                }
            }
            
            System.debug('ZPR0 SUMMARY | Total=' + total + ', Prepared=' + prepared + ', Success=' + success + ', Failed=' + failed + ', ProductNotFound=' + productNotFound + ', PricebookNotFound=' + pricebookNotFound);
            
        } catch(Exception e) {
            
            failed++;
            logs.add('EXCEPTION | ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
            System.debug(logs[logs.size() - 1]);
            
        } finally {
            
            if(resp != null) {
                try {
                    UtilityCls.logApiCall('ZPR0_API', '', requestBody,
                                          buildLog(total, prepared, success, failed, productNotFound, pricebookNotFound, logs),
                                          '', resp.getStatusCode()
                                         );
                } catch(Exception e) {
                    System.debug('API Log Error | ' + e.getMessage());
                }
            }
        }
    }
    
    // Remove SAP leading zeros
    private static String normalize(String value) {
        if(String.isBlank(value)) return null;
        value = value.trim().replaceFirst('^0+', '');
        return String.isBlank(value) ? '0' : value;
    }
    
    // Safe Trim
    private static String clean(String value) {
        return String.isBlank(value) ? null : value.trim();
    }
    
    // Unique PBE Key
    private static String getKey(String productCode, String salesOrg, String channel, String currencyCode) {
        return clean(productCode) + '_' + clean(salesOrg) + '_' + clean(channel) + '_' + clean(currencyCode);
    }
    
    // Decimal Conversion
    private static Decimal toDecimal(String value) {
        return String.isBlank(value) ? null : Decimal.valueOf(value.trim());
    }
    
    // SAP Date Format: yyyyMMdd
    private static Date parseSAPDate(String value) {
        
        if(String.isBlank(value)) return null;
        
        value = value.trim();
        
        if(value.contains('9999')) return Date.newInstance(2030, 12, 31);
        
        if(value.length() != 8 || !value.isNumeric())
            throw new IllegalArgumentException('Invalid SAP date: ' + value);
        
        return Date.newInstance(
            Integer.valueOf(value.substring(0, 4)),
            Integer.valueOf(value.substring(4, 6)),
            Integer.valueOf(value.substring(6, 8))
        );
    }
    
    // Compact API Processing Log
    private static String buildLog(
        Integer total,
        Integer prepared,
        Integer success,
        Integer failed,
        Integer productNotFound,
        Integer pricebookNotFound,
        List<String> logs
    ) {
        
        String output =
            'ZPR0 API PROCESSING SUMMARY\n' +
            'Total SAP Records: ' + total + '\n' +
            'Records Prepared: ' + prepared + '\n' +
            'PBE Success: ' + success + '\n' +
            'PBE Failed: ' + failed + '\n' +
            'Product Not Found: ' + productNotFound + '\n' +
            'Pricebook Not Found: ' + pricebookNotFound + '\n\n';
        
        Integer maxLength = 100000;
        
        for(String log : logs) {
            if(output.length() + log.length() + 1 > maxLength) {
                output += '--- LOG TRUNCATED ---';
                break;
            }
            output += log + '\n';
        }
        
        return output;
    }
    
}