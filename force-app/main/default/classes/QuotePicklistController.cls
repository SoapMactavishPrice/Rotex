public without sharing class QuotePicklistController {
    public class ProductRow {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public Id inventoryId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public Decimal availableQty;
        @AuraEnabled public Decimal quoteQty;
    }

    @AuraEnabled
    public static List<ProductRow> getQuoteProducts(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }

        Quote visibleQuote;
        for (Quote row : QuoteController.getMyQuotes()) {
            if (row.Id == quoteId) {
                visibleQuote = row;
                break;
            }
        }
        if (visibleQuote == null) {
            throw new AuraHandledException('You do not have access to this quote.');
        }

        String status = normalize(visibleQuote.Status);
        String quoteType = normalize(visibleQuote.Quote_Type__c);
        if (status != 'ACCEPTED' && status != 'CLOSED WON') {
            throw new AuraHandledException('A pick list can only be created for a Closed Won quote.');
        }
        if (quoteType != 'SECONDARY CUSTOMER') {
            throw new AuraHandledException('A pick list can only be created for a Secondary Customer quote.');
        }

        Id partnerId = resolvePartnerAccountId();
        if (partnerId == null) {
            throw new AuraHandledException('Channel Partner account could not be resolved.');
        }

        List<QuoteLineItem> quoteLines = Database.query(
            'SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, Quantity ' +
            'FROM QuoteLineItem WHERE QuoteId = :quoteId ORDER BY LineNumber ASC',
            AccessLevel.SYSTEM_MODE
        );
        if (quoteLines.isEmpty()) {
            return new List<ProductRow>();
        }

        Set<Id> productIds = new Set<Id>();
        for (QuoteLineItem line : quoteLines) {
            if (line.Product2Id != null) {
                productIds.add(line.Product2Id);
            }
        }

        List<Inventory__c> inventories = new List<Inventory__c>();
        if (!productIds.isEmpty()) {
            inventories = [
                SELECT Id, Product__c, Product_Code__c, Available_Quantity__c
                FROM Inventory__c
                WHERE Channel_Partner__c = :partnerId
                  AND Product__c IN :productIds
                ORDER BY Available_Quantity__c DESC NULLS LAST
            ];
        }
        return buildProductRows(quoteLines, inventories);
    }

    @TestVisible
    private static List<ProductRow> buildProductRows(
        List<QuoteLineItem> quoteLines,
        List<Inventory__c> inventories
    ) {
        Map<Id, Inventory__c> inventoryByProduct = new Map<Id, Inventory__c>();
        for (Inventory__c inventory : inventories) {
            if (!inventoryByProduct.containsKey(inventory.Product__c)) {
                inventoryByProduct.put(inventory.Product__c, inventory);
            }
        }
        List<ProductRow> results = new List<ProductRow>();
        Map<Id, ProductRow> resultByProduct = new Map<Id, ProductRow>();
        for (QuoteLineItem line : quoteLines) {
            if (line.Product2Id == null) {
                continue;
            }
            ProductRow result = resultByProduct.get(line.Product2Id);
            if (result == null) {
                Inventory__c inventory = inventoryByProduct.get(line.Product2Id);
                result = new ProductRow();
                result.lineItemId = line.Id;
                result.inventoryId = inventory == null ? null : inventory.Id;
                result.productId = line.Product2Id;
                result.productName = line.Product2 == null ? '' : line.Product2.Name;
                result.productCode = inventory != null && String.isNotBlank(inventory.Product_Code__c)
                    ? inventory.Product_Code__c
                    : (line.Product2 == null ? '' : line.Product2.ProductCode);
                result.availableQty = inventory == null || inventory.Available_Quantity__c == null
                    ? 0
                    : inventory.Available_Quantity__c;
                result.quoteQty = 0;
                results.add(result);
                resultByProduct.put(line.Product2Id, result);
            }
            result.quoteQty += line.Quantity == null ? 0 : line.Quantity;
        }
        return results;
    }

    private static Id resolvePartnerAccountId() {
        User currentUser = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return currentUser.AccountId;
    }

    private static String normalize(String value) {
        return String.isBlank(value)
            ? ''
            : value.trim().toUpperCase().replaceAll('[-_]+', ' ').replaceAll('\\s+', ' ');
    }
}