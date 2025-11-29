public without sharing class AddProductPageOpp {

    // @AuraEnabled
    // public static String findProduct(string recordId, List < String > productFamily) {

    //     try {

    //         system.debug('recordId ' + recordId);
    //         Opportunity op = [SELECT Id, AccountId, Pricebook2Id, Pricebook2.Name FROM Opportunity WHERE Id =: recordId];

    //         if (op == null) {
    //             return JSON.serialize(new Map < String, Object > {
    //                 'error' => 'Opportunity not found'
    //             });
    //         }

    //         List < Sales_Area_Item__c > salesAreaItemList = [
    //             SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Incoterms__c
    //             FROM Sales_Area_Item__c WHERE Account__c =: op.AccountId
    //             AND Sales_Org__c = '1100'
    //             AND Division__c != '50'
    //             AND Division__c != '20'
    //             AND Division__c != '00'
    //         ];

    //         if (salesAreaItemList.isEmpty()) {
    //             return JSON.serialize(new Map < String, Object > {
    //                 'error' => 'No Sales Area Item Found'
    //             });
    //         }

    //         List < OpportunityLineItem > oplIst = [SELECT Id, Product2Id FROM OpportunityLineItem WHERE OpportunityId =: recordId];

    //         set < Id > existingProdId = new set < Id > ();
    //         if (oplIst.size() > 0) {
    //             for (OpportunityLineItem opr: oplIst) {
    //                 existingProdId.add(opr.Product2Id);

    //             }
    //         }
    //         wrapperClass wc = new wrapperClass();
    //         wc.priceBook = op.Pricebook2.Name;

    //         // string productQuery = 'SELECT Id, Product__r.Name, Product__c FROM Plant_Data__c WHERE Plant__c = \'1100\' AND Product__c NOT IN :existingProdId';
    //         // // string productQuery = 'select Id,Name,Family  from Product2 where Id NOT IN :existingProdId';

    //         // if (productFamily.size() > 0) {
    //         //     productQuery += ' where Family IN : productFamily';
    //         // }
    //         // // productQuery += ' LIMIT 28000';

    //         // set < Id > prodId = new set < Id > ();
    //         // for (Plant_Data__c pd: database.query(productQuery)) {
    //         //     // prodId.add(pd.Id);
    //         //     prodId.add(pd.Product__c);
    //         // }

    //         String query = 'SELECT Id ,UnitPrice,Product2Id,Product2.Name,Product2.Family,Product2.ProductCode,Product2.Description FROM PricebookEntry WHERE Distribution_Channel__c = \'' + salesAreaItemList[0].Distribution_Channel__c + '\' and Sales_Org__c = \'1100\' AND Pricebook2Id = \'' + op.Pricebook2Id + '\'  AND Product2Id IN (SELECT Product__c FROM Plant_Data__c WHERE Plant__c = \'1100\') AND Product2Id NOT IN :existingProdId ORDER BY Product2.Name';
            
    //         system.debug('query' + query);
    //         List < PricebookEntry > lstPBE = (List < PricebookEntry > ) Database.query(query);
    //         // return lstPBE;

    //         List < Customer_ARC_Pricing__c > custARCpriceList = [
    //             SELECT Id, Name, Customer__c, Amount__c, Material__c, Material__r.ProductCode,
    //             Scale_Qty1__c, Scale_Qty2__c, Scale_Qty3__c, Scale_Qty4__c, Scale_Qty5__c,
    //             Scale_Amt1__c, Scale_Amt2__c, Scale_Amt3__c, Scale_Amt4__c, Scale_Amt5__c
    //             FROM Customer_ARC_Pricing__c WHERE Customer__c =: op.AccountId
    //             AND Sales_Organization__c = '1100'
    //             AND Distribution_Channel__c =: salesAreaItemList[0].Distribution_Channel__c
    //         ];

    //         Map < String, Customer_ARC_Pricing__c > arcProductMap = new Map < String, Customer_ARC_Pricing__c > ();
    //         if (custARCpriceList.size() > 0) {
    //             for (Customer_ARC_Pricing__c ca: custARCpriceList) {
    //                 arcProductMap.put(ca.Material__r.ProductCode, ca);
    //             }
    //         }

    //         Date todayDate = Date.today();
    //         List < Incoterm__c > incotermsList = [
    //             SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Valid_From__c, Valid_To__c, Incoterm_Percent__c
    //             FROM Incoterm__c
    //             WHERE Name =: salesAreaItemList[0].Incoterms__c
    //             AND Sales_Org__c = '1100'
    //             AND Distribution_Channel__c =: salesAreaItemList[0].Distribution_Channel__c
    //             AND Division__c =: salesAreaItemList[0].Division__c
    //             AND Valid_From__c <=: todayDate
    //             AND Valid_To__c >=: todayDate
    //         ];

    //         System.debug(incotermsList);

    //         List < ProductWrapper > lstProduct = new List < ProductWrapper > ();
    //         integer i = 0;
    //         for (PricebookEntry pbe: lstPBE) {
    //             ProductWrapper pw = new ProductWrapper();
    //             pw.Id = pbe.Id;
    //             pw.purl = '/lightning/r/' + pbe.Id + '/view';
    //             pw.Product2Id = pbe.Product2Id;
    //             pw.Name = pbe.Product2.Name;
    //             pw.ProductCode = pbe.Product2.ProductCode;

    //             //pw.PackSize = pbe.Product2.Pack_Size__c;
    //             pw.Family = pbe.Product2.Family;

    //             pw.Description = pbe.Product2.Description;
    //             pw.Quantity = 0;
    //             pw.ARCQuantity = 0;
    //             if (arcProductMap.containsKey(pbe.Product2.ProductCode)) {
    //                 List < Map < String, Decimal >> scaleList = new List < Map < String, Decimal >> ();
    //                 Customer_ARC_Pricing__c cap = arcProductMap.get(pbe.Product2.ProductCode);
    //                 if (cap.Scale_Amt1__c != 0 && cap.Scale_Qty1__c != 0) {
    //                     Map < String, Decimal > scaleMap = new Map < String, Decimal > ();
    //                     scaleMap.put('label', cap.Scale_Qty1__c);
    //                     scaleMap.put('value', cap.Scale_Amt1__c);
    //                     scaleList.add(scaleMap);
    //                 }
    //                 if (cap.Scale_Amt2__c != 0 && cap.Scale_Qty2__c != 0) {
    //                     Map < String, Decimal > scaleMap = new Map < String, Decimal > ();
    //                     scaleMap.put('label', cap.Scale_Qty2__c);
    //                     scaleMap.put('value', cap.Scale_Amt2__c);
    //                     scaleList.add(scaleMap);
    //                 }
    //                 if (cap.Scale_Amt3__c != 0 && cap.Scale_Qty3__c != 0) {
    //                     Map < String, Decimal > scaleMap = new Map < String, Decimal > ();
    //                     scaleMap.put('label', cap.Scale_Qty3__c);
    //                     scaleMap.put('value', cap.Scale_Amt3__c);
    //                     scaleList.add(scaleMap);
    //                 }
    //                 if (cap.Scale_Amt4__c != 0 && cap.Scale_Qty4__c != 0) {
    //                     Map < String, Decimal > scaleMap = new Map < String, Decimal > ();
    //                     scaleMap.put('label', cap.Scale_Qty4__c);
    //                     scaleMap.put('value', cap.Scale_Amt4__c);
    //                     scaleList.add(scaleMap);
    //                 }
    //                 if (cap.Scale_Amt5__c != 0 && cap.Scale_Qty5__c != 0) {
    //                     Map < String, Decimal > scaleMap = new Map < String, Decimal > ();
    //                     scaleMap.put('label', cap.Scale_Qty5__c);
    //                     scaleMap.put('value', cap.Scale_Amt5__c);
    //                     scaleList.add(scaleMap);
    //                 }
    //                 pw.PriceOption = scaleList;
    //                 pw.Price = cap.Scale_Amt1__c;
    //                 pw.ListPrice = cap.Scale_Amt1__c;
    //                 pw.IsARC = true;
    //                 pw.Quantity = cap.Scale_Qty1__c;
    //                 pw.ARCQuantity = cap.Scale_Qty1__c;
    //             } else {
    //                 pw.Price = pbe.UnitPrice;
    //                 pw.ListPrice = pbe.UnitPrice;
    //                 pw.IsARC = false;
    //             }
    //             pw.SalesPrice = null;
    //             if (incotermsList.size() > 0) {
    //                 pw.Incoterms = incotermsList[0].Incoterm_Percent__c - 100;
    //             } else {
    //                 pw.Incoterms = 0;
    //             }
    //             //pw.hsnMasterId = pbe.Product2.HSN_Code__c;
    //             //pw.hsnMasterCode =pbe.Product2.HSN_Code__r.Name;
    //             //pw.CGSTRATE = pbe.Product2.HSN_Code__r.CGST_Rate__c;
    //             // pw.SGSTRATE = pbe.Product2.HSN_Code__r.SGST_Rate__c;
    //             //pw.IGSTRATE = pbe.Product2.HSN_Code__r.IGST_Rate__c;
    //             pw.index = i++;
    //             pw.showError = false;
    //             lstProduct.add(pw);
    //             system.debug(lstProduct);
    //         }
    //         wc.productList = lstProduct;
    //         return JSON.serialize(wc);

    //     } catch (Exception e) {
    //         System.debug('Error in findProduct: ' + e.getMessage() + ' at ' + e.getLineNumber());
    //         return JSON.serialize(new Map < String, Object > {
    //             'error' => 'An error occurred: ' + e.getMessage()
    //         });
    //     }

    // }

    @AuraEnabled
    public static String findProduct(string recordId, List < String > productFamily, String searchKey, Integer batchNo) {

        try {

            system.debug('recordId ' + recordId);
            Opportunity op = [SELECT Id, AccountId, Pricebook2Id, Pricebook2.Name FROM Opportunity WHERE Id =: recordId];

            if (op == null) {
                return JSON.serialize(new Map < String, Object > {
                    'error' => 'Opportunity not found'
                });
            }

            List < Sales_Area_Item__c > salesAreaItemList = [
                SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Incoterms__c
                FROM Sales_Area_Item__c WHERE Account__c =: op.AccountId
                AND Sales_Org__c = '1100'
                AND Division__c NOT IN ('50', '20', '00')
            ];

            if (salesAreaItemList.isEmpty()) {
                return JSON.serialize(new Map < String, Object > {
                    'error' => 'No Sales Area Item Found'
                });
            }

            Set<Id> existingProdId = new Set<Id>();
            for (OpportunityLineItem opr : [SELECT Product2Id FROM OpportunityLineItem WHERE OpportunityId =: recordId]) {
                existingProdId.add(opr.Product2Id);
            }

            wrapperClass wc = new wrapperClass();
            wc.priceBook = op.Pricebook2.Name;

            // string productQuery = 'SELECT Id, Product__r.Name, Product__c FROM Plant_Data__c WHERE Plant__c = \'1100\' AND Product__c NOT IN :existingProdId';
            // // string productQuery = 'select Id,Name,Family  from Product2 where Id NOT IN :existingProdId';

            // if (productFamily.size() > 0) {
            //     productQuery += ' where Family IN : productFamily';
            // }
            // // productQuery += ' LIMIT 28000';

            // set < Id > prodId = new set < Id > ();
            // for (Plant_Data__c pd: database.query(productQuery)) {
            //     // prodId.add(pd.Id);
            //     prodId.add(pd.Product__c);
            // }

            // String query = 'SELECT Id ,UnitPrice,Product2Id,Product2.Name,Product2.Family,Product2.ProductCode,Product2.Description FROM PricebookEntry WHERE Distribution_Channel__c = \'' + salesAreaItemList[0].Distribution_Channel__c + '\' and Sales_Org__c = \'1100\' AND Pricebook2Id = \'' + op.Pricebook2Id + '\'  AND Product2Id IN (SELECT Product__c FROM Plant_Data__c WHERE Plant__c = \'1100\') AND Product2Id NOT IN :existingProdId ORDER BY Product2.Name';
            
            String query = 'SELECT Id, UnitPrice, Product2Id, ' +
                'Product2.Name, Product2.Family, ' +
                'Product2.ProductCode, Product2.Description ' +
                'FROM PricebookEntry ' +
                'WHERE Distribution_Channel__c = \'' + salesAreaItemList[0].Distribution_Channel__c + '\' ' +
                'AND Sales_Org__c = \'1100\' ' +
                'AND Pricebook2Id = \'' + op.Pricebook2Id + '\' ' +
                'AND Product2Id IN (SELECT Product__c FROM Plant_Data__c WHERE Plant__c = \'1100\') ' +
                'AND Product2Id NOT IN :existingProdId ';

            if(searchKey != null && searchKey != '') {
                query += 'AND (Product2.Name LIKE \'%' + searchKey + '%\' OR Product2.ProductCode LIKE \'%' + searchKey + '%\')';
            }
            query += 'ORDER BY Product2.ProductCode ASC LIMIT 12345';

            system.debug('query' + query);
            List < PricebookEntry > templstPBE = (List < PricebookEntry > ) Database.query(query);
            List < PricebookEntry > lstPBE = new List < PricebookEntry > ();
            // return lstPBE;

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

            Map < String, Customer_ARC_Pricing__c > arcProductMap = new Map < String, Customer_ARC_Pricing__c > ();
            for (Customer_ARC_Pricing__c ca: [
                SELECT Id, Name, Customer__c, Amount__c, Material__c, Material__r.ProductCode,
                Scale_Qty1__c, Scale_Qty2__c, Scale_Qty3__c, Scale_Qty4__c, Scale_Qty5__c,
                Scale_Amt1__c, Scale_Amt2__c, Scale_Amt3__c, Scale_Amt4__c, Scale_Amt5__c
                FROM Customer_ARC_Pricing__c
                WHERE Customer__c =: op.AccountId
                AND Material__c != null
                AND Sales_Organization__c = '1100'
                AND Distribution_Channel__c =: salesAreaItemList[0].Distribution_Channel__c
            ]) {
                arcProductMap.put(ca.Material__r.ProductCode, ca);
            }

            Date todayDate = Date.today();
            List < Incoterm__c > incotermsList = [
                SELECT Id, Name, Sales_Org__c, Distribution_Channel__c, Division__c, Valid_From__c, Valid_To__c, Incoterm_Percent__c
                FROM Incoterm__c
                WHERE Name =: salesAreaItemList[0].Incoterms__c
                AND Sales_Org__c = '1100'
                AND Distribution_Channel__c =: salesAreaItemList[0].Distribution_Channel__c
                AND Division__c =: salesAreaItemList[0].Division__c
                AND Valid_From__c <=: todayDate
                AND Valid_To__c >=: todayDate
            ];

            System.debug(incotermsList);

            List < ProductWrapper > lstProduct = new List < ProductWrapper > ();
            integer i = 0;
            for (PricebookEntry pbe: lstPBE) {
                ProductWrapper pw = new ProductWrapper();
                pw.Id = pbe.Id;
                pw.purl = '/lightning/r/' + pbe.Id + '/view';
                pw.Product2Id = pbe.Product2Id;
                pw.Name = pbe.Product2.Name;
                pw.ProductCode = pbe.Product2.ProductCode;

                //pw.PackSize = pbe.Product2.Pack_Size__c;
                pw.Family = pbe.Product2.Family;

                pw.Description = pbe.Product2.Description;
                pw.Quantity = 0;
                pw.ARCQuantity = 0;
                if (arcProductMap.containsKey(pbe.Product2.ProductCode)) {
                    List < Map < String, Decimal >> scaleList = new List < Map < String, Decimal >> ();
                    Customer_ARC_Pricing__c cap = arcProductMap.get(pbe.Product2.ProductCode);
                    if (cap.Scale_Amt1__c != 0 && cap.Scale_Qty1__c != 0) {
                        Map < String, Decimal > scaleMap = new Map < String, Decimal > ();
                        scaleMap.put('label', cap.Scale_Qty1__c);
                        scaleMap.put('value', cap.Scale_Amt1__c);
                        scaleList.add(scaleMap);
                    }
                    if (cap.Scale_Amt2__c != 0 && cap.Scale_Qty2__c != 0) {
                        Map < String, Decimal > scaleMap = new Map < String, Decimal > ();
                        scaleMap.put('label', cap.Scale_Qty2__c);
                        scaleMap.put('value', cap.Scale_Amt2__c);
                        scaleList.add(scaleMap);
                    }
                    if (cap.Scale_Amt3__c != 0 && cap.Scale_Qty3__c != 0) {
                        Map < String, Decimal > scaleMap = new Map < String, Decimal > ();
                        scaleMap.put('label', cap.Scale_Qty3__c);
                        scaleMap.put('value', cap.Scale_Amt3__c);
                        scaleList.add(scaleMap);
                    }
                    if (cap.Scale_Amt4__c != 0 && cap.Scale_Qty4__c != 0) {
                        Map < String, Decimal > scaleMap = new Map < String, Decimal > ();
                        scaleMap.put('label', cap.Scale_Qty4__c);
                        scaleMap.put('value', cap.Scale_Amt4__c);
                        scaleList.add(scaleMap);
                    }
                    if (cap.Scale_Amt5__c != 0 && cap.Scale_Qty5__c != 0) {
                        Map < String, Decimal > scaleMap = new Map < String, Decimal > ();
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
                //pw.hsnMasterId = pbe.Product2.HSN_Code__c;
                //pw.hsnMasterCode =pbe.Product2.HSN_Code__r.Name;
                //pw.CGSTRATE = pbe.Product2.HSN_Code__r.CGST_Rate__c;
                // pw.SGSTRATE = pbe.Product2.HSN_Code__r.SGST_Rate__c;
                //pw.IGSTRATE = pbe.Product2.HSN_Code__r.IGST_Rate__c;
                pw.index = i++;
                pw.showError = false;
                lstProduct.add(pw);
                system.debug(lstProduct);
            }

            wc.productList = lstProduct;
            return JSON.serialize(wc);

        } catch (Exception e) {
            System.debug('Error in findProduct: ' + e.getMessage() + ' at ' + e.getLineNumber());
            return JSON.serialize(new Map < String, Object > {
                'error' => 'An error occurred: ' + e.getMessage()
            });
        }

    }

    @AuraEnabled
    public static String getCustomerDiscount(String oppId) {
        try {

            Opportunity opp = [
                SELECT Id, AccountId, Account.Discount__c, Account.Name, Pricebook2Id, Pricebook2.Name, CurrencyISOCode
                FROM Opportunity
                WHERE Id =: oppId
            ];

            return JSON.serialize(opp.Account.Discount__c);

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* @AuraEnabled
    public static String findProduct(string recordId, List<String> productFamily){
         system.debug('recordId '+recordId);
         Opportunity op = [SELECT Id, Pricebook2Id, Pricebook2.Name FROM Opportunity WHERE Id =:recordId];
        
         List<OpportunityLineItem>  oplIst = [select Id,Product2Id from OpportunityLineItem where OpportunityId =:recordId ]; 
        
        set<Id>existingProdId = new set<Id>();
        if(oplIst.size() > 0){
            for(OpportunityLineItem opr : oplIst){
              existingProdId.add(opr.Product2Id);  
            }
        }
         wrapperClass wc = new wrapperClass();
         wc.priceBook = op.Pricebook2.Name;
        
        string productQuery = 'select Id,Name,Family  from Product2 where Id NOT IN :existingProdId';
        
        if(productFamily.size() > 0){
            productQuery+=' where Family IN : productFamily';
           // productQuery+=' where Family IN '+productFamily;
        }
        
        set<Id> prodId = new set<Id>();
        //List<Product2> pdList = database.query(productQuery);
        for(Product2 pd : database.query(productQuery)){
            prodId.add(pd.Id);
           // system.debug('prodId'+prodId);
        }
        
        
       //String query = 'SELECT Id ,UnitPrice,Product2Id  FROM PricebookEntry WHERE CurrencyISOCode =\''+op.currencyISOcode +'\'  and Pricebook2Id = \''+ op.Pricebook2Id +'\' AND IsActive = true AND Product2Id IN :prodId';
      // String query = 'SELECT Id ,UnitPrice,Product2Id,Product2.Name,Product2.Pack_Size__c,Product2.HSN_Code__c, Product2.HSN_Code__r.Name,Product2.Family,Product2.ProductCode,Product2.Description,Product2.HSN_Code__r.IGST_Rate__c,Product2.HSN_Code__r.CGST_Rate__c,  Product2.HSN_Code__r.SGST_Rate__c FROM PricebookEntry WHERE Pricebook2Id = \''+ op.Pricebook2Id +'\' AND IsActive = true AND Product2Id IN :prodId';
         String query  ='SELECT Id ,UnitPrice,Product2Id,Product2.Name,Product2.Family,Product2.ProductCode,Product2.Description FROM PricebookEntry WHERE Pricebook2Id = \''+ op.Pricebook2Id +'\' AND IsActive = true AND Product2Id IN :prodId';
       		//system.debug('query'+query);
        List<PricebookEntry> lstPBE = (List<PricebookEntry>)Database.query(query);
        //system.debug('lstPBE'+lstPBE);
        List<ProductWrapper> lstProduct= new List<ProductWrapper>();
        integer i = 0;
        for(PricebookEntry pbe : lstPBE){
            ProductWrapper pw = new ProductWrapper();
            pw.Id = pbe.Id;
                    pw.purl = '/lightning/r/' +pbe.Id+'/view';
                    pw.Product2Id = pbe.Product2Id;
                    pw.Name =pbe.Product2.Name;
                    pw.ProductCode = pbe.Product2.ProductCode;
            
                    //pw.PackSize = pbe.Product2.Pack_Size__c;
                    pw.Family = pbe.Product2.Family;
            		
                    pw.Description= pbe.Product2.Description;
                    pw.Price = pbe.UnitPrice;
                    pw.SalesPrice = null;
            		//pw.hsnMasterId = pbe.Product2.HSN_Code__c;
                    //pw.hsnMasterCode =pbe.Product2.HSN_Code__r.Name;
				    //pw.CGSTRATE = pbe.Product2.HSN_Code__r.CGST_Rate__c;
                   // pw.SGSTRATE = pbe.Product2.HSN_Code__r.SGST_Rate__c;
                    //pw.IGSTRATE = pbe.Product2.HSN_Code__r.IGST_Rate__c;
            		pw.index = i++;
                    pw.showError = false;
                    lstProduct.add(pw);
            		system.debug(lstProduct);
        }
        wc.productList = lstProduct;
	        return JSON.serialize(wc);
    }
    */
    @AuraEnabled
    public static List < PicklistValue > getproductfamily() {
        String strObjectName = 'Product2';
        String strPicklistField = 'Family';
        Map < String, String > mapPickListValues = new Map < String, String > ();
        Schema.SObjectType objSobjectType = Schema.getGlobalDescribe().get(strObjectName);
        Schema.DescribeSObjectResult objDescribeSobject = objSobjectType.getDescribe();
        Map < String, Schema.SObjectField > mapFields = objDescribeSobject.fields.getMap();
        List < Schema.PicklistEntry > lstPickListValues = mapFields.get(strPicklistField).getDescribe().getPickListValues();
        List < PicklistValue > pvList = new List < PicklistValue > ();
        for (Schema.PicklistEntry objPickList: lstPickListValues) {
            PicklistValue pv = new PicklistValue(objPickList.getValue(), objPickList.getLabel());
            pvList.add(pv);
            // system.debug(pvList);
        }
        return pvList;

    }

    @AuraEnabled
    public static String saveProducts(String recordData, String recId, double customerSAPdiscount) {

        List < ProductWrapper > wc = (List < ProductWrapper > ) json.deserialize(recordData, List < ProductWrapper > .class);
        List < OpportunityLineItem > lstOpp = new List < OpportunityLineItem > ();
        for (ProductWrapper pw: wc) {
            OpportunityLineItem oli = new OpportunityLineItem();
            oli.Quantity = pw.Quantity;
            oli.UnitPrice = pw.Price;
            oli.UnitPrice = pw.Price;
            oli.UnitPrice = pw.Price;
            oli.Discount_as_per_SAP__c = customerSAPdiscount != null ? customerSAPdiscount : 0;

            //oli.Product_Category__c = pw.Family;
            oli.UnitPrice = pw.Price;
            system.debug(oli.UnitPrice);
            oli.ServiceDate = system.today();
            oli.Discount_to_be_offered__c = pw.Discount;
            oli.Description = pw.LineDescription;
            oli.OpportunityId = recId; //'0065j00000N2RXiAAN';
            oli.Product2Id = pw.Product2Id;
            oli.Item_Type__c = pw.IsARC ? 'ARC' : 'Discount';
            // oli.HSN_Master__c = pw.hsnMasterId;
            //oli.CGST_RATE__c = pw.CGSTRATE;
            //oli.SGST_RATE__c = pw.SGSTRATE;
            //oli.IGST_RATE__c = pw.IGSTRATE;
            //oli.Pack_Size__c = pw.PackSize;
            oli.PricebookEntryId = pw.Id; //'01u5j000003Pq51AAC';
            lstOpp.add(oli);
            //  System.debug(' pw' + lstOpp);

        }
        try {
            insert lstOpp;
            return 'success';
        } catch (Exception e) {
            System.debug(e.getMessage());
            return 'error';
        }
    }

    public with sharing class wrapperClass {
        public String priceBook;
        public List < ProductWrapper > productList;
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
        public integer index;
        public Decimal Price;
        public Decimal SalesPrice;
        public Decimal ListPrice;
        public Boolean IsARC;
        public List < Map < String, Decimal >> PriceOption;
        public Decimal Quantity;
        public Decimal ARCQuantity;
        public Decimal IncoTerms;
        public String Family;
        public Date PDate;
        public String Description;
        public String LineDescription;
        public decimal CGSTRATE;
        public decimal IGSTRATE;
        public decimal SGSTRATE;
        public boolean showError;
        public decimal Discount = 0;
    }

    public class PicklistValue {
        @auraenabled
        public String label {
            get;
            set;
        }
        @auraenabled
        public String value {
            get;
            set;
        }

        public PicklistValue(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }
}