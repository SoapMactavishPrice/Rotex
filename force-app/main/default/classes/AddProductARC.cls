public without sharing class AddProductARC {

    /**
     * Fetches List Price (from PricebookEntry) and Existing ARC Pricing
     * (from Customer_ARC_Pricing__c) for the selected product codes.
     * Called when transitioning to Page 2 of the ARC product entry component.
     */
    @AuraEnabled
    public static String getARCProductData(String oppId, String productCodesJson) {
        try {
            List<String> productCodes = (List<String>) JSON.deserialize(productCodesJson, List<String>.class);

            Opportunity opp = [
                SELECT Id, AccountId, CurrencyIsoCode, Pricebook2Id
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];

            // Fetch Distribution Channel from Sales_Area_Item__c (same logic as AddProductPageOpp)
            List<Sales_Area_Item__c> salesAreaList = [
                SELECT Distribution_Channel__c
                FROM Sales_Area_Item__c
                WHERE Account__c = :opp.AccountId
                AND Sales_Org__c = '1100'
                AND Division__c NOT IN ('50', '20', '00')
                LIMIT 1
            ];

            // Build PricebookEntry query to get pure List Price
            String pbeQuery = 'SELECT Id, UnitPrice, Product2.ProductCode ' +
                'FROM PricebookEntry ' +
                'WHERE Pricebook2Id = \'' + opp.Pricebook2Id + '\' ' +
                'AND Sales_Org__c = \'1100\' ' +
                'AND Product2.ProductCode IN :productCodes ' +
                'AND IsActive = true ';

            if (!salesAreaList.isEmpty() && String.isNotBlank(salesAreaList[0].Distribution_Channel__c)) {
                pbeQuery += 'AND Distribution_Channel__c = \'' + salesAreaList[0].Distribution_Channel__c + '\' ';
            }

            Map<String, Decimal> productCodeToListPrice = new Map<String, Decimal>();
            Map<String, String> productCodeToPBEId = new Map<String, String>();

            for (PricebookEntry pbe : (List<PricebookEntry>) Database.query(pbeQuery)) {
                String pc = pbe.Product2.ProductCode;
                if (!productCodeToListPrice.containsKey(pc)) {
                    productCodeToListPrice.put(pc, pbe.UnitPrice);
                    productCodeToPBEId.put(pc, pbe.Id);
                }
            }

            // Fetch existing ARC pricing records for this customer + product codes
            Map<String, ARCData> arcMap = new Map<String, ARCData>();
            for (Customer_ARC_Pricing__c arc : [
                SELECT Id, Amount__c, Valid_To__c, Material__r.ProductCode
                FROM Customer_ARC_Pricing__c
                WHERE Customer__c = :opp.AccountId
                AND Material__c != null
                AND Material__r.ProductCode IN :productCodes
                AND Active__c = true
            ]) {
                String pc = arc.Material__r.ProductCode;
                if (!arcMap.containsKey(pc)) {
                    ARCData ad = new ARCData();
                    ad.existingARCPrice = arc.Amount__c;
                    ad.existingARCExpiryDate = arc.Valid_To__c;
                    arcMap.put(pc, ad);
                }
            }

            // Build result list
            List<ARCProductResult> resultList = new List<ARCProductResult>();
            for (String pc : productCodes) {
                ARCProductResult r = new ARCProductResult();
                r.productCode      = pc;
                r.listPrice        = productCodeToListPrice.get(pc);
                r.pricebookEntryId = productCodeToPBEId.get(pc);
                if (arcMap.containsKey(pc)) {
                    r.existingARCPrice      = arcMap.get(pc).existingARCPrice;
                    r.existingARCExpiryDate = arcMap.get(pc).existingARCExpiryDate;
                }
                resultList.add(r);
            }

            return JSON.serialize(resultList);

        } catch (Exception e) {
            System.debug('Error in getARCProductData: ' + e.getMessage() + ' at ' + e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Saves OpportunityLineItem records for ARC products.
     */
    @AuraEnabled
    public static String saveARCProducts(String recordData, String recId) {
        try {
            List<ARCOLIWrapper> wrapperList = (List<ARCOLIWrapper>) JSON.deserialize(
                recordData, List<ARCOLIWrapper>.class
            );

            List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();

            for (ARCOLIWrapper w : wrapperList) {
                OpportunityLineItem oli = new OpportunityLineItem();
                oli.OpportunityId      = recId;
                oli.Product2Id         = w.product2Id;
                oli.PricebookEntryId   = w.pricebookEntryId;

                // Quantity = Potential Qty (min 1)
                Decimal qty = (w.potentialQty != null && w.potentialQty > 0) ? w.potentialQty : 1;
                oli.Quantity = qty;

                // UnitPrice = Proposed ARC Price
                oli.UnitPrice = (w.listPrice != null && w.listPrice >= 0) ? w.listPrice : 0;

                // ARC-specific fields
                oli.Discount_to_be_offered__c = w.discountPct;
                oli.Potential_Value__c        = w.potentialValue;
                oli.Potential_Qty__c          = w.potentialQty;

                // Date fields (sent as ISO strings from JS)
                if (String.isNotBlank(w.validFrom)) {
                    oli.Valid_from__c = Date.valueOf(w.validFrom);
                }
                if (String.isNotBlank(w.validTill)) {
                    oli.Valid_Till__c = Date.valueOf(w.validTill);
                }

                // Mark as ARC item type
                if (!Test.isRunningTest()) {
                    oli.Item_Type__c = 'ARC';
                }

                oliList.add(oli);
            }

            insert oliList;
            return 'success';

        } catch (Exception e) {
            System.debug('Error in saveARCProducts: ' + e.getMessage() + ' at ' + e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─── Inner Classes ──────────────────────────────────────────────────────────

    /** Result wrapper returned to LWC for each product on Page 2 */
    public class ARCProductResult {
        public String  productCode;
        public Decimal listPrice;
        public String  pricebookEntryId;
        public Decimal existingARCPrice;
        public Date    existingARCExpiryDate;
    }

    /** Helper class for ARC pricing data */
    public class ARCData {
        public Decimal existingARCPrice;
        public Date    existingARCExpiryDate;
    }

    /** Wrapper for OLI save data coming from LWC */
    public class ARCOLIWrapper {
        public String  productCode;
        public String  productName;
        public String  product2Id;
        public String  pricebookEntryId;
        public Decimal listPrice;
        public Decimal discountPct;
        public Decimal proposedARCPrice;
        public Decimal potentialValue;
        public Decimal potentialQty;
        public String  validFrom;
        public String  validTill;
    }
}