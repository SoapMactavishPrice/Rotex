public class OpportunityTriggerHandler {
    
    public static void handleProposalOpportunities(List<Opportunity> newOpportunities, Map<Id, Opportunity> oldOpportunityMap) {
        
        List<Quote> qList = new List<Quote>();
        List<QuoteLineItem> qliList = new List<QuoteLineItem>();
        
        // Collect all Ids
        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        
        for (Opportunity opp : newOpportunities) {
            opportunityIds.add(opp.Id);
            if (opp.AccountId != null) accountIds.add(opp.AccountId);
            if (opp.Project_Contact__c != null) contactIds.add(opp.Project_Contact__c);
        }
        
        // Existing quotes
        Map<Id, Quote> existingQuotesMap = new Map<Id, Quote>();
        for (Quote existingQuote : [
            SELECT Id, Name, OpportunityId 
            FROM Quote 
            WHERE OpportunityId IN :oldOpportunityMap.keySet()
        ]) {
            existingQuotesMap.put(existingQuote.OpportunityId, existingQuote);
        }
        
        // Contact Map
        Map<Id, Contact> contactMap = new Map<Id, Contact>([
            SELECT Id, Name, Email, Phone, Fax 
            FROM Contact 
            WHERE Id IN :contactIds
        ]);
        
        // Account Map
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Name, Bill_To_Address_ID__c, BillingStreet, BillingCity, BillingState, BillingCountry,
            Ship_To_Address_ID__c, ShippingStreet, ShippingCity, ShippingPostalCode, ShippingState, ShippingCountry,
            Sold_To_Address_ID__c, Sold_To_Street__c, Sold_To_City__c, Sold_To_Zip_Postal_Code__c, OwnerId, State__c,
            Sold_To_State_Province__c, Sold_To_Country__c, Sold_To_Tax_Type__c, Sold_To_TAX_Number__c
            FROM Account
            WHERE Id IN :accountIds
        ]);
        
        // Sales Area Item (Optimized & Safe)
        Map<Id, Sales_Area_Item__c> salesAreaMap = new Map<Id, Sales_Area_Item__c>();
        for (Sales_Area_Item__c sa : [
            SELECT Id, Account__c, Incoterms__c, Terms_Of_Payment__c
            FROM Sales_Area_Item__c
            WHERE Account__c IN :accountIds
            AND Distribution_Channel__c = '10'
            AND Division__c = '10'
            AND Sales_Org__c = '1100'
        ]) {
            salesAreaMap.put(sa.Account__c, sa);
        }
        
        // Existing Opportunity Line Items
        Map<Id, List<OpportunityLineItem>> ExistingOppLineItemMap = new Map<Id, List<OpportunityLineItem>>();
        Set<String> productCodes = new Set<String>();
        
        for (OpportunityLineItem oli : [
            SELECT Id, Name, Quantity, OpportunityId, UnitPrice, Product2Id, PricebookEntryId, 
            Product2.ProductCode,
            Discount, Item_Group__c, Item_Description__c, Specification__c, HSN_SAC_Code__c, Location_Code__c,
            Unit__c, Unit_of_Measure_Code__c, Description, Customer_Part_No__c, Item_Number__c,
            Discount_to_be_offered__c, Discount_as_per_SAP__c
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oldOpportunityMap.keySet()
        ]) {
            if (!ExistingOppLineItemMap.containsKey(oli.OpportunityId)) {
                ExistingOppLineItemMap.put(oli.OpportunityId, new List<OpportunityLineItem>());
            }
            ExistingOppLineItemMap.get(oli.OpportunityId).add(oli);
            
            if (oli.Product2 != null && oli.Product2.ProductCode != null) {
                productCodes.add(oli.Product2.ProductCode);
            }
        }
        
        // Query Plant Data for HSN mapping
        Map<String, Plant_Data__c> plantDataMap = new Map<String, Plant_Data__c>();
        if (!productCodes.isEmpty()) {
            for (Plant_Data__c pd : [
                SELECT Id, Product_Code__c, HSN_Code__c
                FROM Plant_Data__c
                WHERE Product_Code__c IN :productCodes
            ]) {
                plantDataMap.put(pd.Product_Code__c, pd);
            }
        }
        
        // MAIN LOOP
        for (Opportunity opp : newOpportunities) {
            
            Boolean stageChanged =
                (opp.StageName == 'Firm Proposal' || opp.StageName == 'Budgetary Proposal') &&
                opp.StageName != oldOpportunityMap.get(opp.Id).StageName &&
                !existingQuotesMap.containsKey(opp.Id);
            
            if (stageChanged) {
                
                if (opp.HasOpportunityLineItem) {
                    
                    Quote newQuote = new Quote();
                    newQuote.OpportunityId = opp.Id;
                    newQuote.Name = opp.Name;
                    newQuote.Status = 'Draft';
                    newQuote.ExpirationDate = System.today() + 14;
                    newQuote.Quote_Valid_Till__c = System.today() + 14;
                    newQuote.Quote_Date__c = System.today();
                    newQuote.RFQ_No__c = opp.Customer_Enquiry_Ref_No__c;
                    newQuote.RFQ_Date__c = opp.Enquiry_Receive_Date__c;
                    newQuote.Prices__c = 'Strict net per piece and valid for order of the quantity as stated above';
                    
                    // Get Sales Area
                    Sales_Area_Item__c sa = salesAreaMap.get(opp.AccountId);
                    if (sa != null) {
                        newQuote.INCO_Terms__c = sa.Incoterms__c;
                        newQuote.Payment_Terms__c = sa.Terms_Of_Payment__c;
                    }
                    
                    // Contact
                    Contact con = contactMap.get(opp.Project_Contact__c);
                    if (con != null) {
                        newQuote.Email = con.Email;
                        newQuote.Phone = con.Phone;
                    }
                    
                    // Account
                    Account acc = accountMap.get(opp.AccountId);
                    if (acc != null) {
                        //newQuote.OwnerId = acc.OwnerId;
                        newQuote.Customer_State__c = acc.State__c;
                    }
                    
                    qList.add(newQuote);
                    
                } else {
                    opp.addError('Please add at least one Product before changing stage to Firm Proposal or Budgetary Proposal.');
                    continue;
                }
            }
        }
        
        // Insert Quotes
        if (!qList.isEmpty()) {
            insert qList;
        }
        
        // Prepare QLI
        for (Opportunity opp : newOpportunities) {
            if (ExistingOppLineItemMap.containsKey(opp.Id)) {
                
                Quote matchingQuote = null;
                for (Quote q : qList) {
                    if (q.OpportunityId == opp.Id) {
                        matchingQuote = q;
                        break;
                    }
                }
                
                if (matchingQuote == null) continue;
                
                for (OpportunityLineItem oli : ExistingOppLineItemMap.get(opp.Id)) {
                    
                    QuoteLineItem qli = new QuoteLineItem();
                    qli.QuoteId = matchingQuote.Id;
                    qli.Quantity = oli.Quantity;
                    qli.UnitPrice = oli.UnitPrice;
                    qli.Product2Id = oli.Product2Id;
                    qli.PricebookEntryId = oli.PricebookEntryId;
                    
                    // Custom fields
                    qli.Item_Group__c = oli.Item_Group__c;
                    qli.Item_Number__c = oli.Item_Number__c;
                    qli.Item_Description__c = oli.Item_Description__c;
                    qli.Specification__c = oli.Specification__c;
                    qli.Location_Code__c = oli.Location_Code__c;
                    qli.Unit__c = oli.Unit__c;
                    qli.Unit_of_Measure_Code__c = oli.Unit_of_Measure_Code__c;
                    qli.Description = oli.Description;
                    qli.Customer_Part_No__c = oli.Customer_Part_No__c;
                    qli.Discount_to_be_offered__c = oli.Discount_to_be_offered__c;
                    qli.Discount_as_per_SAP__c = oli.Discount_as_per_SAP__c;
                    
                    // --- NEW: HSN from Plant_Data__c ---
                    if (oli.Product2 != null && oli.Product2.ProductCode != null &&
                        plantDataMap.containsKey(oli.Product2.ProductCode)) {
                            
                            qli.HSN_Code__c = plantDataMap.get(oli.Product2.ProductCode).HSN_Code__c;
                        }
                    
                    qliList.add(qli);
                }
            }
        }
        
        // Insert QLI
        if (!qliList.isEmpty()) {
            insert qliList;
        }
    }
    
    // =======================================================
    // OWNER CHANGE LOGIC
    // =======================================================
    public static void handleOwnerChange(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        
        List<OpportunityShare> sharesToInsert = new List<OpportunityShare>();
        
        for (Opportunity opp : newList) {
            
            Opportunity oldRec = oldMap.get(opp.Id);
            
            if (opp.OwnerId != oldRec.OwnerId) {
                
                Id creatorId = opp.CreatedById;
                
                if (creatorId != opp.OwnerId) {
                    
                    OpportunityShare ls = new OpportunityShare();
                    ls.OpportunityId = opp.Id;
                    ls.UserOrGroupId = creatorId;
                    ls.OpportunityAccessLevel = 'Edit';
                    ls.RowCause = Schema.OpportunityShare.RowCause.Manual;
                    sharesToInsert.add(ls);
                }
            }
        }
        
        if (!sharesToInsert.isEmpty()) {
            insert sharesToInsert;
        }
    }
}