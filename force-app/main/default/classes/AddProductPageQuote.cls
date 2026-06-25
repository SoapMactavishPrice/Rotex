public without sharing class AddProductPageQuote {
    
    @AuraEnabled
    public static String findProduct(String recordId, List<String> productFamily, String searchKey, Integer batchNo) {
        
        try {
            System.debug('recordId ' + recordId);
            Quote qt = [SELECT Id, AccountId, Pricebook2Id, Pricebook2.Name,Pricebook2.Distribution_Channel__c FROM Quote WHERE Id = :recordId];
            
            if (qt == null) {
                return JSON.serialize(new Map<String, Object>{
                    'error' => 'Quote not found'
                });
            }
            
            List<Sales_Area_Item__c> salesAreaItemList = [
                SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Incoterms__c,CurrencyIsoCode
                FROM Sales_Area_Item__c 
                WHERE Account__c = :qt.AccountId
                AND Sales_Org__c = '1100'
                AND Distribution_Channel__c = :qt.Pricebook2.Distribution_Channel__c
               // AND Division__c NOT IN ('50', '20', '00')
            ];
            
            if (salesAreaItemList.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{
                    'error' => 'No Sales Area Item Found'
                });
            }
            
       /*     Set<Id> existingProdId = new Set<Id>();
            for (QuoteLineItem qli : [SELECT Product2Id FROM QuoteLineItem WHERE QuoteId = :recordId]) {
                existingProdId.add(qli.Product2Id);
            }   */
            
            wrapperClass wc = new wrapperClass();
            wc.priceBook = qt.Pricebook2.Name;
            
            String salesAreaCurrency = salesAreaItemList[0].CurrencyIsoCode;
            
            String query = 'SELECT Id, UnitPrice, Product2Id, ' +
                'Product2.Name, Product2.Family, ' +
                'Product2.ProductCode, Product2.Description,CurrencyIsoCode,Product2.Item_Type__c, Product2.Status__c ' +
                'FROM PricebookEntry ' +
                'WHERE Distribution_Channel__c = \'' + salesAreaItemList[0].Distribution_Channel__c + '\' ' +
                'AND Sales_Org__c = \'1100\' ' +
                'AND Pricebook2Id = \'' + qt.Pricebook2Id + '\' ' +
                'AND CurrencyIsoCode = \'' + salesAreaCurrency + '\' ' +
                'AND Product2Id IN (SELECT Product__c FROM Plant_Data__c WHERE Plant__c = \'1100\') ' ;
            //    'AND Product2Id NOT IN :existingProdId ';
            
            if (searchKey != null && searchKey != '') {
                query += 'AND (Product2.Name LIKE \'%' + searchKey + '%\' OR Product2.ProductCode LIKE \'%' + searchKey + '%\')';
            }
            query += 'ORDER BY Product2.ProductCode ASC';
            
            System.debug('query' + query);
            List<PricebookEntry> templstPBE = (List<PricebookEntry>) Database.query(query);
            List<PricebookEntry> lstPBE = new List<PricebookEntry>();
            
            Integer size = templstPBE.size();
            Integer mid = Integer.valueOf(Math.ceil((Decimal)size / 2));
            
            List<PricebookEntry> firstHalf = new List<PricebookEntry>();
            List<PricebookEntry> secondHalf = new List<PricebookEntry>();
            
            for (Integer x = 0; x < templstPBE.size(); x++) {
                if (x < mid) {
                    firstHalf.add(templstPBE[x]);
                } else {
                    secondHalf.add(templstPBE[x]);
                }
            }
            
            // Return correct half
            if (batchNo == 1) {
                lstPBE = firstHalf;
            } else if (batchNo == 2) {
                lstPBE = secondHalf;
            }
            
            Map<String, Customer_ARC_Pricing__c> arcProductMap = new Map<String, Customer_ARC_Pricing__c>();
            for (Customer_ARC_Pricing__c ca : [
                SELECT Id, Name, Customer__c, Amount__c, Material__c, Material__r.ProductCode,
                Scale_Qty1__c, Scale_Qty2__c, Scale_Qty3__c, Scale_Qty4__c, Scale_Qty5__c,
                Scale_Amt1__c, Scale_Amt2__c, Scale_Amt3__c, Scale_Amt4__c, Scale_Amt5__c,Active__c,CurrencyIsoCode
                FROM Customer_ARC_Pricing__c
                WHERE Customer__c = :qt.AccountId
                AND Material__c != null
                AND Sales_Organization__c = '1100'
                AND Distribution_Channel__c = :salesAreaItemList[0].Distribution_Channel__c
                AND Active__c = true
                AND CurrencyIsoCode = :salesAreaCurrency
                
            ]) {
                arcProductMap.put(ca.Material__r.ProductCode, ca);
            }
            
            Date todayDate = Date.today();
            List<Incoterm__c> incotermsList = [
                SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Valid_From__c, Valid_To__c, Incoterm_Percent__c
                FROM Incoterm__c
                WHERE Name = :salesAreaItemList[0].Incoterms__c
                AND Sales_Org__c = '1100'
                AND Distribution_Channel__c = :salesAreaItemList[0].Distribution_Channel__c
                AND Division__c = :salesAreaItemList[0].Division__c
                AND Valid_From__c <= :todayDate
                AND Valid_To__c >= :todayDate
            ];
            
            System.debug(incotermsList);
            
            List<ProductWrapper> lstProduct = new List<ProductWrapper>();
            Integer i = 0;
            for (PricebookEntry pbe : lstPBE) {
                ProductWrapper pw = new ProductWrapper();
                pw.Id = pbe.Id;
                pw.purl = '/lightning/r/' + pbe.Id + '/view';
                pw.Product2Id = pbe.Product2Id;
                pw.Name = pbe.Product2.Name;
                pw.ProductCode = pbe.Product2.ProductCode;
                pw.Family = pbe.Product2.Family;
                pw.Description = pbe.Product2.Description;
                pw.Quantity = 0;
                pw.ARCQuantity = 0;
                pw.itemType = pbe.Product2.Item_Type__c;
                pw.CurrencyIsoCode = pbe.CurrencyIsoCode;
                pw.Status = pbe.Product2.Status__c;
                if (arcProductMap.containsKey(pbe.Product2.ProductCode)) {
                    List<Map<String, Decimal>> scaleList = new List<Map<String, Decimal>>();
                    Customer_ARC_Pricing__c cap = arcProductMap.get(pbe.Product2.ProductCode);
                    if (cap.Scale_Amt1__c != 0 && cap.Scale_Qty1__c != 0) {
                        Map<String, Decimal> scaleMap = new Map<String, Decimal>();
                        scaleMap.put('label', cap.Scale_Qty1__c);
                        scaleMap.put('value', cap.Scale_Amt1__c);
                        scaleList.add(scaleMap);
                    }
                    if (cap.Scale_Amt2__c != 0 && cap.Scale_Qty2__c != 0) {
                        Map<String, Decimal> scaleMap = new Map<String, Decimal>();
                        scaleMap.put('label', cap.Scale_Qty2__c);
                        scaleMap.put('value', cap.Scale_Amt2__c);
                        scaleList.add(scaleMap);
                    }
                    if (cap.Scale_Amt3__c != 0 && cap.Scale_Qty3__c != 0) {
                        Map<String, Decimal> scaleMap = new Map<String, Decimal>();
                        scaleMap.put('label', cap.Scale_Qty3__c);
                        scaleMap.put('value', cap.Scale_Amt3__c);
                        scaleList.add(scaleMap);
                    }
                    if (cap.Scale_Amt4__c != 0 && cap.Scale_Qty4__c != 0) {
                        Map<String, Decimal> scaleMap = new Map<String, Decimal>();
                        scaleMap.put('label', cap.Scale_Qty4__c);
                        scaleMap.put('value', cap.Scale_Amt4__c);
                        scaleList.add(scaleMap);
                    }
                    if (cap.Scale_Amt5__c != 0 && cap.Scale_Qty5__c != 0) {
                        Map<String, Decimal> scaleMap = new Map<String, Decimal>();
                        scaleMap.put('label', cap.Scale_Qty5__c);
                        scaleMap.put('value', cap.Scale_Amt5__c);
                        scaleList.add(scaleMap);
                    }
                    pw.PriceOption = scaleList;
                    pw.Price = cap.Scale_Amt1__c;
                    pw.ListPrice = cap.Scale_Amt1__c;
                    pw.IsARC = true;
                    pw.Quantity = cap.Scale_Qty1__c;
                    pw.ARCQuantity = cap.Scale_Qty1__c;
                } else {
                    pw.Price = pbe.UnitPrice;
                    pw.ListPrice = pbe.UnitPrice;
                    pw.IsARC = false;
                }
                pw.SalesPrice = null;
                if (incotermsList.size() > 0) {
                    pw.Incoterms = incotermsList[0].Incoterm_Percent__c - 100;
                } else {
                    pw.Incoterms = 0;
                }
                pw.index = i++;
                pw.showError = false;
                lstProduct.add(pw);
                System.debug(lstProduct);
            }
            
            wc.productList = lstProduct;
            return JSON.serialize(wc);
            
        } catch (Exception e) {
            System.debug('Error in findProduct: ' + e.getMessage() + ' at ' + e.getLineNumber());
            return JSON.serialize(new Map<String, Object>{
                'error' => 'An error occurred: ' + e.getMessage()
            });
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> findProductsOptimized(String recordId, String searchKey, String itemType) {
        Quote qt = [SELECT Id, AccountId, Pricebook2Id, Pricebook2.Name,Pricebook2.Distribution_Channel__c 
                    FROM Quote WHERE Id = :recordId];
        
        if (qt == null) {
            return new List<String>{JSON.serialize(new Map<String, Object>{'error' => 'Quote not found'})};
        }
        
        List<Sales_Area_Item__c> salesAreaItemList = [
            SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Incoterms__c,CurrencyIsoCode
            FROM Sales_Area_Item__c 
            WHERE Account__c = :qt.AccountId
            AND Sales_Org__c = '1100'
            AND Distribution_Channel__c = :qt.Pricebook2.Distribution_Channel__c
           // AND Division__c NOT IN ('50', '20', '00')
        ];
        
        if (salesAreaItemList.isEmpty()) {  return new List<String>{JSON.serialize(new Map<String, Object>{'error' => 'No Sales Area Item Found'})};
        }
        
     /*   Set<Id> existingProdId = new Set<Id>();
        for (QuoteLineItem qli : [SELECT Product2Id FROM QuoteLineItem WHERE QuoteId = :recordId]) {
            existingProdId.add(qli.Product2Id);
        }  */
        
        String salesAreaCurrency = salesAreaItemList[0].CurrencyIsoCode;
        
        String query = 'SELECT Id, UnitPrice, Product2Id, ' +
            'Product2.Name, Product2.Family, ' +
            'Product2.ProductCode, Product2.Description,CurrencyIsoCode,Product2.Item_Type__c, Product2.Status__c ' +
            'FROM PricebookEntry ' +
            'WHERE Distribution_Channel__c = \'' + salesAreaItemList[0].Distribution_Channel__c + '\' ' +
            'AND Sales_Org__c = \'1100\' ' +
            'AND Pricebook2Id = \'' + qt.Pricebook2Id + '\' ' +
            'AND CurrencyIsoCode = \'' + salesAreaCurrency + '\' ' +
            'AND Product2Id IN (SELECT Product__c FROM Plant_Data__c WHERE Plant__c = \'1100\') ' ;
         //   'AND Product2Id NOT IN :existingProdId ';
        
        if (String.isNotBlank(searchKey)) {
            String escapedSearchKey = String.escapeSingleQuotes(searchKey);
            query += 'AND (Product2.Name LIKE \'%' + escapedSearchKey + '%\' ' +
                    'OR Product2.ProductCode LIKE \'%' + escapedSearchKey + '%\') ';
        }
        
        if (String.isNotBlank(itemType)) {
            String escapedItemType = String.escapeSingleQuotes(itemType);
            query += 'AND Product2.Item_Type__c = \'' + escapedItemType + '\' ';
        }
        
        query += 'ORDER BY Product2.ProductCode ASC';
        
        List<PricebookEntry> lstPBE = Database.query(query);
        
        Map<String, Customer_ARC_Pricing__c> arcProductMap = new Map<String, Customer_ARC_Pricing__c>();
        for (Customer_ARC_Pricing__c ca : [
            SELECT Id, Name, Customer__c, Amount__c, Material__c, Material__r.ProductCode,
            Scale_Qty1__c, Scale_Qty2__c, Scale_Qty3__c, Scale_Qty4__c, Scale_Qty5__c,
            Scale_Amt1__c, Scale_Amt2__c, Scale_Amt3__c, Scale_Amt4__c, Scale_Amt5__c,Active__c,CurrencyIsoCode
            FROM Customer_ARC_Pricing__c
            WHERE Customer__c = :qt.AccountId
            AND Material__c != null
            AND Sales_Organization__c = '1100'
            AND Distribution_Channel__c = :salesAreaItemList[0].Distribution_Channel__c
            AND Active__c = true
            AND CurrencyIsoCode = :salesAreaCurrency
        ]) { arcProductMap.put(ca.Material__r.ProductCode, ca);
        }
        
        Date todayDate = Date.today();
        List<Incoterm__c> incotermsList = [
            SELECT Id, Incoterm_Percent__c
            FROM Incoterm__c
            WHERE Name = :salesAreaItemList[0].Incoterms__c
            AND Sales_Org__c = '1100'
            AND Distribution_Channel__c = :salesAreaItemList[0].Distribution_Channel__c
            AND Division__c = :salesAreaItemList[0].Division__c
            AND Valid_From__c <= :todayDate
            AND Valid_To__c >= :todayDate
            LIMIT 1
        ];
        
        List<ProductWrapper> lstProduct = new List<ProductWrapper>();
        Integer i = 0;
        
        for (PricebookEntry pbe : lstPBE) {
            ProductWrapper pw = new ProductWrapper();
            pw.Id = pbe.Id;
            pw.purl = '/lightning/r/' + pbe.Id + '/view';
            pw.Product2Id = pbe.Product2Id;
            pw.Name = pbe.Product2.Name;
            pw.ProductCode = pbe.Product2.ProductCode;
            pw.Family = pbe.Product2.Family;
            pw.Description = pbe.Product2.Description;
            pw.Quantity = 0;
            pw.ARCQuantity = 0;
            pw.itemType = pbe.Product2.Item_Type__c;
            pw.CurrencyIsoCode = pbe.CurrencyIsoCode;
            pw.Status = pbe.Product2.Status__c;
            if (arcProductMap.containsKey(pbe.Product2.ProductCode)) {
                Customer_ARC_Pricing__c cap = arcProductMap.get(pbe.Product2.ProductCode);
                pw.PriceOption = buildScaleList(cap);
                pw.Price = cap.Scale_Amt1__c;
                pw.ListPrice = cap.Scale_Amt1__c;
                pw.IsARC = true;
                pw.Quantity = cap.Scale_Qty1__c;
                pw.ARCQuantity = cap.Scale_Qty1__c;
            } else {
                pw.Price = pbe.UnitPrice;
                pw.ListPrice = pbe.UnitPrice;
                pw.IsARC = false;
            }
            
            pw.SalesPrice = null;
            pw.Incoterms = incotermsList.isEmpty() ? 0 : incotermsList[0].Incoterm_Percent__c - 100;
            pw.index = i++;
            pw.showError = false;
            lstProduct.add(pw);
        }
        
        // Split into 3 chunks to avoid heap size limit
        Integer totalSize = lstProduct.size();
        Integer chunkSize = (Integer)Math.ceil(totalSize / 3.0);
        
        List<String> chunks = new List<String>();
        
        for (Integer chunkIndex = 0; chunkIndex < 3; chunkIndex++) {
            Integer startIdx = chunkIndex * chunkSize;
            Integer endIdx = Math.min(startIdx + chunkSize, totalSize);
            
            if (startIdx < totalSize) {
                List<ProductWrapper> chunkData = new List<ProductWrapper>();
                for (Integer idx = startIdx; idx < endIdx; idx++) {
                    chunkData.add(lstProduct[idx]);
                }
                
                wrapperClass wc = new wrapperClass();
                wc.priceBook = qt.Pricebook2.Name;
                wc.productList = chunkData;
                wc.chunkIndex = chunkIndex;
                wc.totalChunks = 3;
                wc.totalRecords = totalSize;
                
                chunks.add(JSON.serialize(wc));
            }
        }
        
        return chunks;
    }
    
    // Helper method to build scale list
    private static List<Map<String, Decimal>> buildScaleList(Customer_ARC_Pricing__c cap) {
        List<Map<String, Decimal>> scaleList = new List<Map<String, Decimal>>();
        
        if (cap.Scale_Amt1__c != 0 && cap.Scale_Qty1__c != 0) {
            scaleList.add(new Map<String, Decimal>{'label' => cap.Scale_Qty1__c, 'value' => cap.Scale_Amt1__c});
        }
        if (cap.Scale_Amt2__c != 0 && cap.Scale_Qty2__c != 0) {
            scaleList.add(new Map<String, Decimal>{'label' => cap.Scale_Qty2__c, 'value' => cap.Scale_Amt2__c});
        }
        if (cap.Scale_Amt3__c != 0 && cap.Scale_Qty3__c != 0) {
            scaleList.add(new Map<String, Decimal>{'label' => cap.Scale_Qty3__c, 'value' => cap.Scale_Amt3__c});
        }
        if (cap.Scale_Amt4__c != 0 && cap.Scale_Qty4__c != 0) {
            scaleList.add(new Map<String, Decimal>{'label' => cap.Scale_Qty4__c, 'value' => cap.Scale_Amt4__c});
        }
        if (cap.Scale_Amt5__c != 0 && cap.Scale_Qty5__c != 0) {
            scaleList.add(new Map<String, Decimal>{'label' => cap.Scale_Qty5__c, 'value' => cap.Scale_Amt5__c});
        }
        
        return scaleList;
    }
    
    @AuraEnabled
    public static String getCustomerDiscount(String quoteId) {
        try {
            Quote qt = [
                SELECT Id, AccountId, Account.Discount__c, Account.Name, Pricebook2Id, Pricebook2.Name, CurrencyISOCode
                FROM Quote
                WHERE Id = :quoteId
            ];
            
            return JSON.serialize(qt.Account.Discount__c);
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<PicklistValue> getproductfamily() {
        String strObjectName = 'Product2';
        String strPicklistField = 'Family';
        Map<String, String> mapPickListValues = new Map<String, String>();
        Schema.SObjectType objSobjectType = Schema.getGlobalDescribe().get(strObjectName);
        Schema.DescribeSObjectResult objDescribeSobject = objSobjectType.getDescribe();
        Map<String, Schema.SObjectField> mapFields = objDescribeSobject.fields.getMap();
        List<Schema.PicklistEntry> lstPickListValues = mapFields.get(strPicklistField).getDescribe().getPickListValues();
        List<PicklistValue> pvList = new List<PicklistValue>();
        for (Schema.PicklistEntry objPickList : lstPickListValues) {
            PicklistValue pv = new PicklistValue(objPickList.getValue(), objPickList.getLabel());
            pvList.add(pv);
        }
        return pvList;
    }
    
    @AuraEnabled
    public static String saveProducts(String recordData, String recId, Double customerSAPdiscount) {
        
        List<ProductWrapper> wc = (List<ProductWrapper>) JSON.deserialize(recordData, List<ProductWrapper>.class);
        List<QuoteLineItem> lstOpp = new List<QuoteLineItem>();
        for (ProductWrapper pw : wc) {
            System.debug(' pw' + pw);
            QuoteLineItem oli = new QuoteLineItem();
            oli.Quantity = pw.Quantity;
            oli.UnitPrice = pw.Price;
            oli.Discount_as_per_SAP__c = customerSAPdiscount != null ? customerSAPdiscount : 0;
            oli.ServiceDate = system.today();
            oli.Discount_to_be_offered__c = pw.Discount;
            oli.Description = pw.LineDescription;
            oli.QuoteId = recId;
            oli.Product2Id = pw.Product2Id;
            oli.PricebookEntryId = pw.Id;
            lstOpp.add(oli);
        }
        try {
            insert lstOpp;
            return 'success';
        } catch (Exception e) {
            System.debug(e.getMessage());
            return 'error';
        }
    }
    
    // Update wrapperClass to include chunk metadata
    public with sharing class wrapperClass {
        public String priceBook;
        public List<ProductWrapper> productList;
        public Integer chunkIndex;
        public Integer totalChunks;
        public Integer totalRecords;
    }
    
    public with sharing class ProductWrapper {
        public String Name;
        public String Id;
        public String purl;
        public String Product2Id;
        public String ProductCode;
        public String PackSize;
        public String hsnMasterId;
        public String hsnMasterCode;
        public Integer index;
        public Decimal Price;
        public Decimal SalesPrice;
        public Decimal ListPrice;
        public Boolean IsARC;
        public List<Map<String, Decimal>> PriceOption;
        public Decimal Quantity;
        public Decimal ARCQuantity;
        public Decimal IncoTerms;
        public String Family;
        public Date PDate;
        public String Description;
        public String LineDescription;
        public Decimal CGSTRATE;
        public Decimal IGSTRATE;
        public Decimal SGSTRATE;
        public Boolean showError;
        public Decimal Discount = 0;
        public String itemType;
        public String CurrencyIsoCode;
        public String Status;
    }
    
    public class PicklistValue {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }
        
        public PicklistValue(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }
}