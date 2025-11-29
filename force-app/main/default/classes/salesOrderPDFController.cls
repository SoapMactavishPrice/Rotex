public class salesOrderPDFController {
    
    public id ordId {get;set;}
    public OrderdataWrapper orderRecord {get;set;}
    public boolean showSaveOrder {get;set;}
    public Order ordData {get;set;}
    public PageReference pdf {get; set;}
    public String pdfUrl {get; set;}
    public string pdfName{get;set;}
    public List<OrderItem> ordItem {get;set;}
    public boolean isValid{get;set;}
    public Decimal totalQuantity { get; set; } 
    public Decimal totalValueINR{ get; set; } 
    public decimal TotalGst {get;set;}
    public Decimal TaxableAmount {get;set;}
    public Decimal TotalTaxableValue {get;set;}
    public string no2words {get;set;}
    public Boolean createNew {get; set;}
    public string emailId{get;set;}
    public string CC_Addresses{get; set;}
    public String subject {get; set;}
    public String body {get; set;}
    
    
    public salesOrderPDFController(){
        
        ordId = ApexPages.currentPage().getparameters().get('id');
        system.debug('ordId'+ordId);
        if(ordId ==null){
            ordId = '801Hz000001mB3sIAE';
        }
        
        /*     try {
// Query to get a sample order ID
Order sampleOrder = [SELECT Id FROM Order LIMIT 1];
ordId = sampleOrder.Id;
} catch (Exception e) {
System.debug('Error querying for sample Order ID: ' + e.getMessage());
ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No Order records found.'));
isValid = false;
return;
}*/
        
        
        
        orderRecord = new OrderdataWrapper();
        showSaveOrder = true;
        ordData =[SELECT Id, OwnerId, ContractId, AccountId, Pricebook2Id, OriginalOrderId, OpportunityId, EffectiveDate, EndDate, Status, Order.Name,
                  Description, CustomerAuthorizedById, CompanyAuthorizedById, Type, BillingStreet, BillingCity, BillingState, BillingPostalCode, 
                  BillingCountry, BillingStateCode, BillingCountryCode, BillingLatitude, BillingLongitude, BillingGeocodeAccuracy, BillingAddress, 
                  ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry, ShippingStateCode, ShippingCountryCode, 
                  ShippingLatitude, ShippingLongitude, ShippingGeocodeAccuracy, ShippingAddress, ActivatedDate, ActivatedById, StatusCode, 
                  OrderNumber, TotalAmount, CreatedDate, CreatedById, Employee_Wise_Target_Line_Item__c 
                  
                  FROM Order 
                  where ID =: ordId];
        pdf = Page.salesOrder;
        pdfURL = '/apex/salesOrder?id='+ordId+'#toolbar=0';
        pdfName = ordData.Name;
        TaxableAmount = 0;
        TotalTaxableValue = 0;
        
        
        
        ordItem = new List<OrderItem>();
        ordItem = [ SELECT Id, Product2Id, OrderId, PricebookEntryId, OriginalOrderItemId, AvailableQuantity, Quantity, UnitPrice, ListPrice, 
                   TotalPrice, ServiceDate, EndDate, Description, CreatedDate, OrderItemNumber, Product2.name,Product2.productcode
                   FROM OrderItem 
                   
                   where OrderId =:OrdData.Id]; 
        
        // order by Serial_Number__c asc NULLS LAST];
        
        if(ordItem.size() == 0){ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.Error, 'Before making a Order Pdf please add atleast One Product'));isValid = false;
        }
            
            
        
        // order by Serial_Number__c asc NULLS LAST];
        
        if(ordItem.size() == 0){  ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.Error, 'Before making a Order Pdf please add atleast One Product'));  isValid = false;
           
           
        }
        totalQuantity = 0;
        totalValueINR = 0;
        TotalGst = 0;
        
        if(ordItem.size() > 0){
            for(OrderItem OItem : ordItem) {
                OrderItemWrapper OIW = new OrderItemWrapper();
                OIW.Line_Item_Id = OItem.Id;
                OIW.Name = OItem.OrderItemNumber;
                OIW.Goodsservices = OItem.Product2.name;
                OIW.RotexItemNumber = OItem.Product2.Productcode;
                OIW.Quantity = OItem.Quantity;
                OIW.rate = OItem.UnitPrice;
                OIW.Totalvalue = OItem.TotalPrice;
                totalQuantity += OItem.Quantity;
                totalValueINR += OItem.TotalPrice;
                TaxableAmount = OIW.Quantity*OIW.rate;
                TotalTaxableValue += TaxableAmount;
                orderRecord.orderItems.add(OIW);
                Integer totalValueINRInt = totalValueINR.intValue();
                String totalValueINRWords = convertCurrencytowords.convert(totalValueINRInt);
                
                no2words = totalValueINRWords + ' Rupees Only.';
                 
            }
        }
        
    }
    
     public PageReference save() {
        String finalString = '%' + ordData.Name + '%';
        List<ContentDocument > contentDocs = [select Id, title from ContentDocument where title like: finalString order by createdDate desc limit 1];
        String version = '0';
        if(contentDocs.size() > 0)  version = contentDocs[0].title.substringAfterLast('_').subStringBeforelast('.');
           
        if(!createNew) {
            if(contentDocs.size() > 0)  Database.delete(contentDocs, false);  }
       
               
        
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.ContentLocation = 'S';
        Integer newVersion = Integer.valueOf(version) + 1;
        contentVersion.PathOnClient = String.valueOf(ordData.Name+ '_' + newVersion + '.pdf');
        contentVersion.Title = String.valueOf(ordData.Name + '_' + newVersion + '.pdf');
        contentVersion.isMajorVersion = false;
        if(Test.isRunningTest())
            ContentVersion.versionData = Blob.toPdf('test');
        else
            ContentVersion.versionData = pdf.getContentAsPDF();
        upsert contentVersion;
        
        contentVersion = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id =: contentVersion.Id];
        ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
        contentDocumentLink.ContentDocumentId = contentVersion.ContentDocumentId;
        contentDocumentLink.LinkedEntityId = ordData.Id;
        contentDocumentLink.ShareType = 'V';
        upsert contentDocumentLink;
        
        Pagereference pageRef = new PageReference('/'+OrdId);
        pageRef.setRedirect(true);
        return pageRef;    
    }
    public PageReference saveAndSend() {
        
        if( emailId != '' && subject != '') 
        {
            String finalString = '%' + ordData.Name + '%';
            List<ContentDocument> contentDocs = [select Id, title from ContentDocument where title like: finalString order by createdDate desc limit 1];
            String version = '0';
            if(contentDocs.size() > 0)
                version = contentDocs[0].title.substringAfterLast('_').subStringBeforelast('.');
            if(!createNew) {
                if(contentDocs.size() > 0)
                    Database.delete(contentDocs, false);
            }
            
            List<ContentDocumentLink> cdls = new List<ContentDocumentLink>();
            if(ordId !=null)
                cdls = [select id, ContentDocument.LatestPublishedVersionId from ContentDocumentLink where LinkedEntityId =: ordId];
            Set<String> LatestPublishedVersionIds = new Set<String>();
            for(ContentDocumentLink cdl: cdls) {
                LatestPublishedVersionIds.add(cdl.ContentDocument.LatestPublishedVersionId);
            }
            
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.ContentLocation = 'S';
            Integer newVersion = Integer.valueOf(version) + 1;
            contentVersion.PathOnClient = String.valueOf(ordData.Name+ '_' + newVersion + '.pdf');
            contentVersion.Title = String.valueOf(+ ordData.Name + '_' + newVersion + '.pdf');
            contentVersion.isMajorVersion = false;
            if(Test.isRunningTest())
                ContentVersion.versionData = Blob.toPdf('test');
            else
                ContentVersion.versionData = pdf.getContentAsPDF();
            upsert contentVersion;
            
            contentVersion = [SELECT Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId, Title, versionData
                              FROM ContentVersion WHERE Id =: contentVersion.Id];
            ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
            contentDocumentLink.ContentDocumentId = contentVersion.ContentDocumentId;
            contentDocumentLink.LinkedEntityId = ordId;
            contentDocumentLink.ShareType = 'V';
            upsert contentDocumentLink;
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            System.debug(emailId);
            email.setToAddresses(new String[] {emailId});
            if(String.isNotBlank(CC_Addresses)){
                CC_Addresses = CC_Addresses.replaceAll('[;,:]', ',');
                Set<String> CCEmails = new Set<String>();
                for(String str : CC_Addresses.split(',')) {
                    if(String.isNotBlank(str))
                        CCEmails.add(str);
                }
                
                email.setCcAddresses(new List<String>(CCEmails));
                System.debug(CC_Addresses);
            }
            
            LatestPublishedVersionIds.add(contentVersion.ContentDocument.LatestPublishedVersionId);
            
            if(LatestPublishedVersionIds.size() > 0) {
                List<String> LatestPublishedVersionIdList = new List<String>();
                LatestPublishedVersionIdList.addAll(LatestPublishedVersionIds);
                email.setEntityAttachments(LatestPublishedVersionIdList);
            }
            
            /*  email.setReplyTo(ordData.Quote__r.email);
if(String.isNotBlank(ordData.Quote__r.email)) {
email.setBccAddresses(new List<String> {ordData.Quote__r.email});
}*/
            email.setSubject(subject);
            email.setHtmlBody(body);
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
        } else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Email Id and subject are the mandatory fields, please verify'));
            return null;
        }
        
        Pagereference pageRef = new PageReference('/'+ordId);
        pageRef.setRedirect(true);
        return pageRef;
        
    }
    
    
    
    public PageReference cancel() {
        Pagereference pageRef = new PageReference('/'+ordId);
        pageRef.setRedirect(true);
        return pageRef;
    }
    class OrderdataWrapper {
        
        
        public List<OrderItemWrapper> orderItems {get; set;}
        
        public OrderdataWrapper() {
            orderItems = new List<OrderItemWrapper>();
        }
    }
    
     class OrderItemWrapper {
         public string Name {get;set;}
         public string Line_Item_Id {get;set;}
         public string Goodsservices{get;set;}
         public string RotexItemNumber{get;set;}
         public Decimal Rate{get;set;}
         public Decimal Quantity{get;set;}
         public Decimal Totalvalue{get;set;}
         
     }
  
}