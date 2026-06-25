// trigger CreatePricebookEntryForAllCurrencies on Product2 (after insert) {
//     // Get active standard pricebook
//     Pricebook2 standardPB = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
    
//     // Get all active currencies in the org
//     List<CurrencyType> activeCurrencies = [SELECT IsoCode FROM CurrencyType WHERE IsActive = true];
    
//     List<PricebookEntry> entriesToInsert = new List<PricebookEntry>();
    
//     for (Product2 prod : Trigger.New) {
//         for (CurrencyType curr : activeCurrencies) {
//             entriesToInsert.add(new PricebookEntry(
//                 Pricebook2Id = standardPB.Id,
//                 Product2Id = prod.Id,
//                 UnitPrice = 1, // You can customize this value
//                 UseStandardPrice = false,
//                 CurrencyIsoCode = curr.IsoCode,
//                 IsActive = true
//             ));
//         }
//     }
    
//     if (!entriesToInsert.isEmpty()) {
//         insert entriesToInsert;
//     }
// }
trigger CreatePricebookEntryForAllCurrencies on Product2 (after insert) {
    try {
        // Get active standard pricebook
        List<Pricebook2> standardPBs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (standardPBs.isEmpty()) return;
        
        Pricebook2 standardPB = standardPBs[0];
        
        // Get all active currencies
        List<CurrencyType> activeCurrencies = [SELECT IsoCode FROM CurrencyType WHERE IsActive = true];
        if (activeCurrencies.isEmpty()) return;
        
        // Get existing entries to avoid duplicates
        Set<Id> existingProductIds = new Map<Id, PricebookEntry>([
            SELECT Product2Id, CurrencyIsoCode 
            FROM PricebookEntry 
            WHERE Product2Id IN :Trigger.newMap.keySet()
        ]).keySet();
        
        List<PricebookEntry> entriesToInsert = new List<PricebookEntry>();
        
        for (Product2 prod : Trigger.New) {
            // Skip if product already has entries
            if (existingProductIds.contains(prod.Id)) continue;
            
            for (CurrencyType curr : activeCurrencies) {
                entriesToInsert.add(new PricebookEntry(
                    Pricebook2Id = standardPB.Id,
                    Product2Id = prod.Id,
                    UnitPrice = 1,
                    UseStandardPrice = false,
                    CurrencyIsoCode = curr.IsoCode,
                    IsActive = true
                ));
            }
        }
        
        if (!entriesToInsert.isEmpty()) {
            insert entriesToInsert;
        }
    } catch (Exception e) {
        // Handle error appropriately
        System.debug('Error in CreatePricebookEntryForAllCurrencies: ' + e.getMessage());
    }
}