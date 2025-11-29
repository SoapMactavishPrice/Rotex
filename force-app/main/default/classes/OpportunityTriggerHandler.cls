public class OpportunityTriggerHandler {
    
    public static void handleProposalOpportunities(List < Opportunity > newOpportunities, Map < Id, Opportunity > oldOpportunityMap) {
        
        List < Quote > qList = new List < Quote > ();
        List < QuoteLineItem > qliList = new List < QuoteLineItem > ();
        
        Set < Id > opportunityIds = new Set < Id > ();
        for (opportunity opp: newOpportunities) {
            opportunityIds.add(opp.Id);
        }
        
        Map < Id, Quote > existingQuotesMap = new Map < Id, Quote > ();
        For(Quote existingQuote: [SELECT Id, Name, OpportunityId FROM Quote WHERE OpportunityId IN: oldOpportunityMap.keySet()]) {
            existingQuotesMap.put(existingQuote.opportunityId, existingQuote);
        }
        
        Map < Id, Contact > ContactMap = new Map < Id, Contact > ([
            SELECT Id, Name, Email, Phone, fax FROM Contact WHERE Id IN (SELECT Project_Contact__c FROM Opportunity WHERE Id In: OpportunityIds)
        ]);
        
        Map < Id, Account > AccountMap = new Map < Id, Account >
            ([SELECT Id, Name, Bill_To_Address_ID__c, BillingStreet, BillingCity, BillingState, BillingCountry,
              Ship_To_Address_ID__c, ShippingStreet, ShippingCity, ShippingPostalCode, ShippingState, ShippingCountry,
              Sold_To_Address_ID__c, Sold_To_Street__c, Sold_To_City__c,
              Sold_To_Zip_Postal_Code__c, OwnerId, State__c,  
              Sold_To_State_Province__c, Sold_To_Country__c, Sold_To_Tax_Type__c, Sold_To_TAX_Number__c
              FROM Account
              WHERE Id IN(SELECT AccountId FROM Opportunity WHERE Id IN: opportunityIds)
             ]);
        
        Opportunity opt = [SELECT Id, Name, AccountId FROM Opportunity WHERE Id IN: opportunityIds];
        
        /*  Sales_Area_Item__c sa = [SELECT Id, Name, Incoterms__c, Terms_Of_Payment__c  
FROM Sales_Area_Item__c 
WHERE Account__c =: opt.AccountId AND Distribution_Channel__c = '10' AND
Division__c = '10'  AND Sales_Org__c = '1100']; */
        
        For(Opportunity Opp: newOpportunities) {
            if ((opp.StageName == 'Firm Proposal' || opp.StageName == 'Budgetary Proposal') &&
                opp.StageName != oldOpportunityMap.get(opp.Id).stageName && !existingQuotesMap.containsKey(Opp.Id)) {
                    
                    // Create Quote
                    if (opp.HasOpportunityLineItem) {
                        
                        Quote newQuote = new Quote();
                        newQuote.OpportunityId = opp.Id;
                        newQuote.Name = opp.Name;
                        newQuote.Status = 'Draft';
                        newQuote.ExpirationDate = system.today() + 14;
                        newQuote.Quote_Valid_Till__c = system.today() + 14;
                        newQuote.Quote_Date__c = system.today();
                        newQuote.RFQ_No__c = opp.Customer_Enquiry_Ref_No__c; 
                        newQuote.RFQ_Date__c = opp.Enquiry_Receive_Date__c; 
                        newQuote.Prices__c = 'Strict net per piece and valid for order of the quantity as stated above';
                        
                        //   newQuote.INCO_Terms__c = sa.Incoterms__c;
                        //   NewQuote.Payment_Terms__c = sa.Terms_Of_Payment__c;
                        
                        newQuote.ContactId = opp.Project_Contact__c;
                        newQuote.Quote_Type__c = opp.Type;
                        newQuote.Description = opp.Description;
                        
                        Contact con = ContactMap.get(Opp.Project_Contact__c);
                        if (con != null) {
                            newQuote.Email = con.Email;
                            newQuote.Phone = con.Phone;
                            newQuote.Fax = con.Fax;
                        }
                        system.debug('ContactMap' + con);
                        
                        Account Acc = AccountMap.get(opp.AccountId);
                        if (Acc != null) {
                            
                            newQuote.BillingName = acc.Name;
                            newQuote.OwnerId = acc.OwnerId;
                            newQuote.BillingStreet = acc.BillingStreet;
                            newQuote.BillingCity = acc.BillingCity;
                            newQuote.BillingPostalCode = acc.ShippingPostalCode;
                            newQuote.BillingState = acc.BillingState;
                            newQuote.Customer_State__c = acc.State__c;
                            newQuote.BillingCountry = acc.BillingCountry;
                            newQuote.ShippingName = acc.Name;
                            newQuote.ShippingStreet = acc.ShippingStreet;
                            newQuote.ShippingCity = acc.ShippingCity;
                            newQuote.ShippingPostalCode = acc.ShippingPostalCode;
                            newQuote.ShippingState = acc.ShippingState;
                            newQuote.ShippingCountry = acc.ShippingCountry;
                        }
                        qList.add(newQuote);
                    }
                    
                    if (!qList.isEmpty()) {
                        insert qList;
                    } else {
                        opp.addError('Please add atleast one Product before changing stage to - Firm Proposal or Budgetary Proposal.');
                        continue;
                    }
                }
            
            //QuotelineItem          
            Map < Id, List < OpportunityLineItem >> ExistingOppLineItemMap = new Map < Id, List < OpportunityLineItem >> ();
            for (OpportunityLineItem ExistingOppLines: [SELECT Id, Name, Quantity, OpportunityId, UnitPrice, Product2Id, PricebookEntryId, Discount,
                                                        Item_Group__c, Item_Description__c, Specification__c, HSN_SAC_Code__c, Location_Code__c,
                                                        Unit__c, Unit_of_Measure_Code__c, Description, Customer_Part_No__c, Item_Number__c, Discount_to_be_offered__c, Discount_as_per_SAP__c
                                                        FROM OpportunityLineItem
                                                        WHERE opportunityId In: oldOpportunityMap.keyset()
                                                       ]) {
                                                           if (!ExistingOppLineItemMap.containsKey(ExistingOppLines.OpportunityId)) {
                                                               ExistingOppLineItemMap.put(ExistingOppLines.OpportunityId, new List < OpportunityLineItem > ());
                                                           }
                                                           System.debug('ExistingOppLineItemMap: ' + ExistingOppLineItemMap);
                                                           System.debug('ExistingOppLines.OpportunityId: ' + ExistingOppLines.OpportunityId);
                                                           ExistingOppLineItemMap.get(ExistingOppLines.OpportunityId).add(ExistingOppLines);
                                                       }
            
            if (ExistingOppLineItemMap.containsKey(opp.Id)) {
                for (OpportunityLineItem opro: ExistingOppLineItemMap.get(opp.Id)) {
                    if (opro.Quantity != null && opro.Name != null) {
                        
                        QuoteLineItem newQuoteLineItem = new QuoteLineItem();
                        if (qList.size() > 0) {
                            newQuoteLineItem.QuoteId = qList[0].Id;
                        } else {
                            System.debug('qList list is empty');
                            continue;
                        }
                        
                        newQuoteLineItem.Quantity = opro.Quantity;
                        newQuoteLineItem.UnitPrice = opro.UnitPrice;
                        newQuoteLineItem.Product2Id = opro.Product2Id;
                        newQuoteLineItem.PricebookEntryId = opro.PricebookEntryId;
                        newQuoteLineItem.Discount = opro.Discount;
                        newQuoteLineItem.Item_Group__c = opro.Item_Group__c;
                        newQuoteLineItem.Item_Number__c = opro.Item_Number__c;
                        newQuoteLineItem.Item_Description__c = opro.Item_Description__c;
                        newQuoteLineItem.Specification__c = opro.Specification__c;
                        newQuoteLineItem.HSN_SAC_Code__c = opro.HSN_SAC_Code__c;
                        newQuoteLineItem.Location_Code__c = opro.Location_Code__c;
                        newQuoteLineItem.Unit__c = opro.Unit__c;
                        newQuoteLineItem.Unit_of_Measure_Code__c = opro.Unit_of_Measure_Code__c;
                        newQuoteLineItem.Description = opro.Description;
                        newQuoteLineItem.Customer_Part_No__c = opro.Customer_Part_No__c;
                        newQuoteLineItem.Discount_to_be_offered__c = opro.Discount_to_be_offered__c;
                        newQuoteLineItem.Discount_as_per_SAP__c = opro.Discount_as_per_SAP__c;
                        qliList.add(newQuoteLineItem);
                    }
                }
            }
            if (!qliList.isEmpty()) {
                insert qliList;
            }
        }
    }
}