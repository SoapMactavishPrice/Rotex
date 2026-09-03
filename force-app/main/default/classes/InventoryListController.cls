public without sharing class InventoryListController {
    
    @AuraEnabled(cacheable=true)
    public static List<Inventory__c> getMyInventories() {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            Id userId = UserInfo.getUserId();
            return [
                SELECT
                    Id, Name, Product__c, Product__r.Name, Product_Code__c,
                    Channel_Partner__c, Channel_Partner__r.Name,
                    Total_GRN_Quantity__c, Total_Reserved_Quantity__c, Total_Invoice_Quantity__c,
                    Total_Cancelled_Quantity__c,
                    On_Hand_Quantity__c, Current_Reserved_Quantity__c, Available_Quantity__c,
                    Minimum_Order_Quantity__c, Minimum_Stock_Level__c, Status__c,
                    Last_GRN_Date__c, Last_Sale_Date__c,
                    CreatedDate, OwnerId, Owner.Name
                FROM Inventory__c
                WHERE OwnerId = :userId
                ORDER BY CreatedDate DESC
            ];
        }

        return [
            SELECT
                Id, Name, Product__c, Product__r.Name, Product_Code__c,
                Channel_Partner__c, Channel_Partner__r.Name,
                Total_GRN_Quantity__c, Total_Reserved_Quantity__c, Total_Invoice_Quantity__c,
                Total_Cancelled_Quantity__c,
                On_Hand_Quantity__c, Current_Reserved_Quantity__c, Available_Quantity__c,
                Minimum_Order_Quantity__c, Minimum_Stock_Level__c, Status__c,
                Last_GRN_Date__c, Last_Sale_Date__c,
                CreatedDate, OwnerId, Owner.Name
            FROM Inventory__c
            WHERE Channel_Partner__c = :partnerId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Inventory_Transaction__c> getInventoryTransactions(Id inventoryId) {
        return [
            SELECT Id, Name, Transaction_Type__c, Transaction_Date_Time__c, CreatedDate,
                   GRN_Line_Item__r.Name, Quote_Line_Item__r.LineNumber, Secondary_Invoice__r.Name,
                   Quantity__c, Remarks__c 
            FROM Inventory_Transaction__c 
            WHERE Inventory__c = :inventoryId 
            ORDER BY CreatedDate DESC, Transaction_Date_Time__c DESC NULLS LAST
        ];
    }

    @AuraEnabled
    public static Inventory__c updateInventoryLevels(
        Id inventoryId,
        Decimal minimumOrderQuantity,
        Decimal minimumStockLevel
    ) {
        if (inventoryId == null) {
            throw new AuraHandledException('Inventory Id is required.');
        }
        assertInventoryAccessible(inventoryId);

        Inventory__c inv = new Inventory__c(
            Id = inventoryId,
            Minimum_Order_Quantity__c = minimumOrderQuantity,
            Minimum_Stock_Level__c = minimumStockLevel
        );
        try {
            update inv;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return [
            SELECT
                Id, Name, Product__c, Product__r.Name, Product_Code__c,
                Channel_Partner__c, Channel_Partner__r.Name,
                Total_GRN_Quantity__c, Total_Reserved_Quantity__c, Total_Invoice_Quantity__c,
                Total_Cancelled_Quantity__c,
                On_Hand_Quantity__c, Current_Reserved_Quantity__c, Available_Quantity__c,
                Minimum_Order_Quantity__c, Minimum_Stock_Level__c, Status__c,
                Last_GRN_Date__c, Last_Sale_Date__c,
                CreatedDate, OwnerId, Owner.Name
            FROM Inventory__c
            WHERE Id = :inventoryId
            LIMIT 1
        ];
    }

    private static void assertInventoryAccessible(Id inventoryId) {
        Id partnerId = resolvePartnerAccountId(null);
        List<Inventory__c> rows;
        if (partnerId != null) {
            rows = [
                SELECT Id
                FROM Inventory__c
                WHERE Id = :inventoryId
                  AND Channel_Partner__c = :partnerId
                LIMIT 1
            ];
        } else {
            Id userId = UserInfo.getUserId();
            rows = [
                SELECT Id
                FROM Inventory__c
                WHERE Id = :inventoryId
                  AND OwnerId = :userId
                LIMIT 1
            ];
        }
        if (rows.isEmpty()) {
            throw new AuraHandledException('You do not have access to this inventory record.');
        }
    }

    private static Id resolvePartnerAccountId(Id partnerAccountId) {
        if (partnerAccountId != null) {
            return partnerAccountId;
        }
        List<User> users = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (!users.isEmpty() && users[0].AccountId != null) {
            return users[0].AccountId;
        }
        return null;
    }
}