public class SyncQuote {
    
    Id recordId {get; set;}
    
    public SyncQuote() {
        recordId = Apexpages.currentPage().getParameters().get('id');
    }
    public PageReference syncQuoteOpp(){
        
        set<Id> qId = new set<Id>(); 
        set<Id> opptyId = new set<Id>(); 
        map<Id,Id> quoToOppty = new map<Id,Id>();
        system.debug('recordId'+recordId);
        string quote = 'Select  ' + Utilitycls.getAllFields('Quote').get('Quote') + ' from Quote where Id  =:  recordId';
        Quote quo = database.query(Quote);
        string oppId = quo.OpportunityId;
        
        if(quo.Status != 'Accepted') {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.Error, 'Make Sure Quote Stage Is Accepted Before Sync'));
            return null;
        } 
        
        string lineItem = 'Select Quote.OpportunityId, ' + Utilitycls.getAllFields('QuoteLineItem').get('QuoteLineItem') + ' from QuoteLineItem where QuoteId =:  recordId order by SystemModstamp';
        List<QuoteLineItem> quoLineItem = database.query(lineItem);
        
        system.debug('quoLineItem'+quoLineItem.size()+'  '+quoLineItem);
        
        List<OpportunityLineItem> UpdateQpllist = new List<OpportunityLineItem>();
        
        string opptylineItem = 'Select ' + Utilitycls.getAllFields('OpportunityLineItem').get('OpportunityLineItem') + ' from OpportunityLineItem where OpportunityId =: oppId order by SystemModstamp';
        List<OpportunityLineItem> optyline = database.query(opptylineItem);
        map<Id,OpportunityLineItem>lineMap = new map<Id,OpportunityLineItem>();
        
        for(OpportunityLineItem  qp : optyline){
            lineMap.put(qp.Product2Id, qp);
        }
        Opportunity op = new Opportunity();
        op.Id = oppId;
        op.SyncedQuoteId = quo.id;
        
        system.debug(quoLineItem.size());
        for(QuoteLineItem optl : quoLineItem){
            if(lineMap.containskey(optl.Product2Id) && optyline.size() > 0){
                system.debug('inside if');
                OpportunityLineItem opt = new OpportunityLineItem();
                opt.OpportunityId = quo.OpportunityId;
                opt.Id = lineMap.get(optl.Product2Id).Id;
                opt.UnitPrice = optl.UnitPrice;
                opt.Quantity = optl.Quantity;
                //opt.PricebookEntryId = optl.PricebookEntryId;
                opt.Discount = optl.Discount;
                opt.Description = optl.Description;
                opt.Customer_Part_No__c = optl.Customer_Part_No__c;
                UpdateQpllist.add(opt);
            }
            else{
                system.debug('inside else');
                OpportunityLineItem opt = new OpportunityLineItem();
                opt.OpportunityId = quo.OpportunityId;
                opt.Product2Id = optl.Product2Id;
                opt.UnitPrice = optl.UnitPrice;
                opt.Quantity = optl.Quantity;
                opt.Discount = optl.Discount;
                opt.Description = optl.Description;
                opt.PricebookEntryId = optl.PricebookEntryId;
                opt.Customer_Part_No__c = optl.Customer_Part_No__c;
                UpdateQpllist.add(opt);
            }     
        }
        
        if(UpdateQpllist.size() > 0){
            upsert UpdateQpllist;
        } 		
        
        PageReference pgref = new PageReference('/'+quo.OpportunityId);
        pgref.setRedirect(true);
        return pgref;
    }
}