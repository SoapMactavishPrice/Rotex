public with sharing class QuoteProductViewController {

    @AuraEnabled(cacheable=true)
    public static List<QuoteProductWrapper> getQuoteProducts(Id quoteId) {

        List<QuoteProductWrapper> results = new List<QuoteProductWrapper>();

        List<QuoteLineItem> qliList = [

            SELECT

                Id,
                QuoteId,
                Quantity,
                UnitPrice,
                ListPrice,
                Discount,
                Description,
                Product2.Name,
                Product2.ProductCode,

                Discount_as_per_SAP__c,
                Previous_Discount__c,
                Discount_to_be_offered__c,
                Requested_Comments__c,

                Sales_Manager__c,
                Sales_Manager__r.Name,
                Sales_Manager_Status__c,
                Sales_Manager_Comments__c,
                Sales_Manager_Date_Time__c,

                Country_Continent_Sales_Head_LOB_Head__c,
                Country_Continent_Sales_Head_LOB_Head__r.Name,
                Country_Continent_Sales_H_LOB_Status__c,
                Country_Continent_Sales_LOB_Comments__c,
                Country_Head_Date_Time__c,

                Global_Sales_Head__c,
                Global_Sales_Head__r.Name,
                Global_Sales_Head_Status__c,
                Global_Sales_Head_Comments__c,
                Global_Sales_Head_Date_Time__c,

                Rotex_Board_Member__c,
                Rotex_Board_Member__r.Name,
                Rotex_Board_Member_Status__c,
                Rotex_Board_Member_Comments__c,
                Rotex_Board_Member_Date_Time__c,

                Managing_Director_Country_Manage__c,
                Managing_Director_Country_Manage__r.Name,
                Managing_Director_Status__c,
                Managing_Director_Comments__c,
                Managing_Director_Date_Time__c,

                Prev_Sales_Manager_Comments__c,
                Prev_Country_Continent_Sales_Comments__c,
                Prev_Global_Sales_Head_Comments__c,
                Prev_Rotex_Board_Member_Comments__c,
                Prev_Managing_Director_Comments__c

            FROM QuoteLineItem

            WHERE QuoteId = :quoteId

            ORDER BY SortOrder ASC, LineNumber ASC

        ];

        for(QuoteLineItem qli : qliList){

            QuoteProductWrapper row = new QuoteProductWrapper();

            row.quoteLineItemId = qli.Id;

            row.productName = qli.Product2.Name;
            row.productCode = qli.Product2.ProductCode;

            row.listPrice = qli.ListPrice;
            row.quantity = qli.Quantity;

            row.discountSAP = qli.Discount_as_per_SAP__c;
            row.previousDiscount = qli.Previous_Discount__c;
            row.discount = qli.Discount_to_be_offered__c;

            row.salesPrice = qli.UnitPrice;

            row.requestorComments = qli.Requested_Comments__c;

            row.soaUsers = new List<SOAWrapper>();

            //--------------------------------------------
            // Sales Manager
            //--------------------------------------------

            if(qli.Sales_Manager__c != null){

                SOAWrapper sm = new SOAWrapper();

                sm.approverName = 'SM - ' + qli.Sales_Manager__r.Name;
                sm.status = qli.Sales_Manager_Status__c;
                sm.comments = qli.Sales_Manager_Comments__c;
                sm.previousComments = qli.Prev_Sales_Manager_Comments__c;
                sm.dateTimeData = qli.Sales_Manager_Date_Time__c;

                row.soaUsers.add(sm);

            }

            //--------------------------------------------
            // Country Head
            //--------------------------------------------

            if(qli.Country_Continent_Sales_Head_LOB_Head__c != null){

                SOAWrapper ch = new SOAWrapper();

                ch.approverName =
                    'CH - ' +
                    qli.Country_Continent_Sales_Head_LOB_Head__r.Name;

                ch.status =
                    qli.Country_Continent_Sales_H_LOB_Status__c;

                ch.comments =
                    qli.Country_Continent_Sales_LOB_Comments__c;

                ch.previousComments =
                    qli.Prev_Country_Continent_Sales_Comments__c;

                ch.dateTimeData =
                    qli.Country_Head_Date_Time__c;

                row.soaUsers.add(ch);

            }

            //--------------------------------------------
            // Global Sales Head
            //--------------------------------------------

            if(qli.Global_Sales_Head__c != null){

                SOAWrapper gs = new SOAWrapper();

                gs.approverName =
                    'GS - ' +
                    qli.Global_Sales_Head__r.Name;

                gs.status =
                    qli.Global_Sales_Head_Status__c;

                gs.comments =
                    qli.Global_Sales_Head_Comments__c;

                gs.previousComments =
                    qli.Prev_Global_Sales_Head_Comments__c;

                gs.dateTimeData =
                    qli.Global_Sales_Head_Date_Time__c;

                row.soaUsers.add(gs);

            }

            //--------------------------------------------
            // Board Member
            //--------------------------------------------

            if(qli.Rotex_Board_Member__c != null){

                SOAWrapper bm = new SOAWrapper();

                bm.approverName =
                    'BM - ' +
                    qli.Rotex_Board_Member__r.Name;

                bm.status =
                    qli.Rotex_Board_Member_Status__c;

                bm.comments =
                    qli.Rotex_Board_Member_Comments__c;

                bm.previousComments =
                    qli.Prev_Rotex_Board_Member_Comments__c;

                bm.dateTimeData =
                    qli.Rotex_Board_Member_Date_Time__c;

                row.soaUsers.add(bm);

            }

            //--------------------------------------------
            // Managing Director
            //--------------------------------------------

            if(qli.Managing_Director_Country_Manage__c != null){

                SOAWrapper md = new SOAWrapper();

                md.approverName =
                    'MD - ' +
                    qli.Managing_Director_Country_Manage__r.Name;

                md.status =
                    qli.Managing_Director_Status__c;

                md.comments =
                    qli.Managing_Director_Comments__c;

                md.previousComments =
                    qli.Prev_Managing_Director_Comments__c;

                md.dateTimeData =
                    qli.Managing_Director_Date_Time__c;

                row.soaUsers.add(md);

            }

            results.add(row);

        }

        return results;

    }

    //---------------------------------------------------------
    // Product Wrapper
    //---------------------------------------------------------

    public class QuoteProductWrapper{

        @AuraEnabled public Id quoteLineItemId;

        @AuraEnabled public String productName;

        @AuraEnabled public String productCode;

        @AuraEnabled public Decimal listPrice;

        @AuraEnabled public Decimal quantity;

        @AuraEnabled public Decimal discountSAP;

        @AuraEnabled public Decimal previousDiscount;

        @AuraEnabled public Decimal discount;

        @AuraEnabled public Decimal salesPrice;

        @AuraEnabled public String requestorComments;

        @AuraEnabled public List<SOAWrapper> soaUsers;

    }

    //---------------------------------------------------------
    // SOA Wrapper
    //---------------------------------------------------------

    public class SOAWrapper{

        @AuraEnabled public String approverName;

        @AuraEnabled public String status;

        @AuraEnabled public String comments;

        @AuraEnabled public String previousComments;

        @AuraEnabled public Datetime dateTimeData;

    }

}