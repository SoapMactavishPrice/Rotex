public with sharing class ZPR0PricingAPI {

    public class ZPR0Request {
        public String conditon_ident;
        public String condition_type;
        public String valid_to;
    }

    public static void ZPR0Pricing() {

        HttpResponse resp;
        String requestBody = '';
        
        try {
            Date dateOfExc = Date.today();

            // Build Request Body
            List<ZPR0Request> reqList = new List<ZPR0Request>();

            ZPR0Request req = new ZPR0Request();
            req.conditon_ident = 'P';
            req.condition_type = 'ZPR0';
            req.valid_to = String.valueOf(dateOfExc);
            //req.valid_to = '2026-07-14';

            reqList.add(req);

            requestBody = JSON.serialize(reqList);
            System.debug('Request Body ==> ' + requestBody);

            // POST Callout
            resp = UtilityCls.doPostWithBasicAuth('ZPR0_API', requestBody);

            if(resp.getStatusCode() == 200){

                System.debug(resp.getBody());

                List<PricebookEntry> upsertPBEList = new List<PricebookEntry>();

                Set<String> productCodeSet = new Set<String>();
                
                System.debug('Status Code ==> ' + resp.getStatusCode());
                System.debug('Response Body ==> ' + resp.getBody());
                System.debug('Response Headers ==> ' + resp.getHeaderKeys());
                
                if(String.isBlank(resp.getBody())){
                    throw new CalloutException('Response body is empty.');
                }

                // Deserialize JSON Array
                List<IntegrationRequestBuilder.ZPR0Response> parentWrappers =
                    IntegrationRequestBuilder.ZPR0ResponseParse(resp.getBody());

                // Product Codes
                for(IntegrationRequestBuilder.ZPR0Response parent : parentWrappers){
                    productCodeSet.add(parent.Material);
                }

                // Products
                List<Product2> productList = [
                    SELECT Id, ProductCode
                    FROM Product2
                    WHERE ProductCode IN :productCodeSet
                ];

                Map<String,Id> productIdMap = new Map<String,Id>();

                for(Product2 p : productList){
                    productIdMap.put(p.ProductCode, p.Id);
                }

                // Pricebooks
                List<Pricebook2> pricebookList = [
                    SELECT Id, Distribution_Channel__c
                    FROM Pricebook2
                    WHERE Distribution_Channel__c != null
                ];

                Map<String,Id> pbMap = new Map<String,Id>();

                for(Pricebook2 pb : pricebookList){
                    pbMap.put(pb.Distribution_Channel__c, pb.Id);
                }

                // Existing Pricebook Entries
                List<PricebookEntry> existingPBEList = [

                    SELECT Id,
                           ProductCode,
                           CurrencyIsoCode,
                           Sales_Org__c,
                           Distribution_Channel__c
                    FROM PricebookEntry
                    WHERE Product2Id IN :productIdMap.values()
                    AND Distribution_Channel__c != null
                ];

                Map<String,Id> pbeMap = new Map<String,Id>();

                for(PricebookEntry pbe : existingPBEList){

                    String key =
                        pbe.ProductCode+'_'+
                        pbe.Sales_Org__c+'_'+
                        pbe.Distribution_Channel__c+'_'+
                        pbe.CurrencyIsoCode;

                    pbeMap.put(key,pbe.Id);

                }

                // Insert / Update
                for(IntegrationRequestBuilder.ZPR0Response parent : parentWrappers){

                    if(productIdMap.containsKey(parent.Material)){

                        String key =
                            parent.Material+'_'+
                            parent.SalesOrg+'_'+
                            parent.DistributionChannel+'_'+
                            parent.CoditionCurr;

                        PricebookEntry pbe = new PricebookEntry();

                        if(pbeMap.containsKey(key)){

                            pbe.Id = pbeMap.get(key);

                        }else{

                            pbe.Pricebook2Id = pbMap.get(parent.DistributionChannel);
                            pbe.Product2Id = productIdMap.get(parent.Material);
                            pbe.Sales_Org__c = parent.SalesOrg;
                            pbe.Distribution_Channel__c = parent.DistributionChannel;
                            pbe.CurrencyIsoCode = parent.CoditionCurr;
                            pbe.IsActive = true;
                            pbe.UseStandardPrice = false;

                        }

                        pbe.UnitPrice =
                            Decimal.valueOf(parent.ConditionAmt.trim());

                        pbe.Pricing_Unit__c =
                            Decimal.valueOf(parent.PricingUnit.trim());

                        pbe.Unit_of_Measure__c =
                            parent.UnitOfMeasure;

                        pbe.Valid_From__c =
                            UtilityCls.getDateFormate(parent.ValidFrom);

                        if(String.isNotBlank(parent.ValidTo)
                           && parent.ValidTo.contains('9999')){

                            pbe.Valid_To__c =
                                Date.newInstance(2030,12,31);

                        }else{

                            pbe.Valid_To__c =
                                UtilityCls.getDateFormate(parent.ValidTo);

                        }

                        upsertPBEList.add(pbe);

                    }else{

                        System.debug(
                            'Product Not Found : '+parent.Material
                        );

                    }

                }

                if(!upsertPBEList.isEmpty()){

                    upsert upsertPBEList;

                    System.debug(
                        'Pricebook Entries Processed : '+
                        upsertPBEList.size()
                    );

                }

            }

        }catch(Exception e){

            System.debug(
                'Exception : '+e.getMessage()
            );

        }finally{

            if(resp != null){

                UtilityCls.logApiCall(
                    'ZPR0_API',
                    '',
                    requestBody,
                    resp.getBody(),
                    '',
                    resp.getStatusCode()
                );

            }

        }

    }

}