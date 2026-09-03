public without sharing class InvoiceController {
    
    @AuraEnabled(cacheable=true)
    public static Id getMyChannelPartnerAccountId() {
        return resolvePartnerAccountId(null);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SO_Invoice__c> getMyInvoices() {
        Id partnerId = resolvePartnerAccountId(null);
        if (partnerId == null) {
            Id userId = UserInfo.getUserId();
            return [
                SELECT
                    Id, Name, Bill_Doc_No__c, SO_No__c, Acc_Doc_No__c, Sold_To__c,
                    Exc_Rate__c, Bill_Date__c, Bill_Doc_Type__c, CurrencyIsoCode, Currency__c,
                    Net_Value__c, Tax_Value__c, Bill_To__c, Payer__c, Terms_Of_Payment__c, Incoterms__c,
                    Account__c, Account__r.Name, CreatedDate, OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.Email,
                    (SELECT Id, Name, Item_No__c, Product__r.Name, Product_Description__c, Item_Code__c, UOM__c, Unit_Price__c, GST_Amount__c, Quantity__c, QTY__c, Line_Amount__c, GRN_Qty__c, Pending_GRN_Qty__c FROM Invoice_Line_item__r)
                FROM SO_Invoice__c
                WHERE CreatedById = :userId
                ORDER BY CreatedDate DESC
            ];
        }

        return [
            SELECT
                Id, Name, Bill_Doc_No__c, SO_No__c, Acc_Doc_No__c, Sold_To__c,
                Exc_Rate__c, Bill_Date__c, Bill_Doc_Type__c, CurrencyIsoCode, Currency__c,
                Net_Value__c, Tax_Value__c, Bill_To__c, Payer__c, Terms_Of_Payment__c, Incoterms__c,
                Account__c, Account__r.Name, CreatedDate, OwnerId, Owner.Name, Owner.FirstName, Owner.LastName, Owner.Email,
                (SELECT Id, Name, Item_No__c, Product__r.Name, Product_Description__c, Item_Code__c, UOM__c, Unit_Price__c, GST_Amount__c, Quantity__c, QTY__c, Line_Amount__c, GRN_Qty__c, Pending_GRN_Qty__c FROM Invoice_Line_item__r)
                FROM SO_Invoice__c
            WHERE Account__c = :partnerId
               OR Account__r.Channel_Partner_Name__c = :partnerId
               OR Account__r.Channel_Partner__c = :partnerId
            ORDER BY CreatedDate DESC
        ];
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