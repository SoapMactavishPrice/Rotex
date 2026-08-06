import { LightningElement, api, track } from 'lwc';

export default class QuoteLineItemView extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track errorMessage = '';

    // Field definitions - easy to maintain and modify
    detailsFields = [
        { apiName: 'QuoteId', label: 'Quote' },
        { apiName: 'HSN_Code__c', label: 'HSN Code' },
        { apiName: 'LineNumber', label: 'Line Item Number' },
        { apiName: 'Customer_Part_No__c', label: 'Customer Part No' },
        { apiName: 'Product2Id', label: 'Product' },
        { apiName: 'Item_Type__c', label: 'Item Type' },
        { apiName: 'Potential_Qty__c', label: 'Potential Qty' },
        { apiName: 'Is_Discount_Only_Approved__c', label: 'Is Discount Only Approved' },
        { apiName: 'Potential_Value__c', label: 'Potential Value' },
        { apiName: 'Valid_from__c', label: 'Valid From' },
        { apiName: '', label: '' },
        { apiName: 'Valid_Till__c', label: 'Valid Till' },
        
    ];

    priceFields = [
        { apiName: 'ListPrice', label: 'List Price' },
        { apiName: 'Discount_as_per_SAP__c', label: 'Discount as per SAP' },
        { apiName: 'List_Price_Backend__c', label: 'List Price Backend' },
        { apiName: 'Previous_Discount__c', label: 'Previous Discount' },
        { apiName: 'Quantity', label: 'Quantity' },
        { apiName: 'Requested_Discount__c', label: 'Requested Discount' },
        { apiName: 'Unit_Price__c', label: 'Unit Price' },
        { apiName: 'Discount_to_be_offered__c', label: 'Discount to be offered' },
        { apiName: 'Round_Off__c', label: 'Round Off' },
        { apiName: 'Discount_offered_SAP__c', label: 'Discount offered > SAP' },
        { apiName: 'UnitPrice', label: 'Sales Price' },
        { apiName: 'P_F_Charges__c', label: 'PF Charges' },
        { apiName: 'Desired_Sales_Price__c', label: 'Desired Sales Price' },
        { apiName: 'P_F_Charges_Amount__c', label: 'PF Charges Amount' },
        { apiName: 'Subtotal', label: 'Subtotal' },
        { apiName: 'Total_Value__c', label: 'Total Value' },
        { apiName: 'TotalPrice', label: 'Total Price' },
        { apiName: 'Grand_Total__c', label: 'Grand Total' }
    ];

    gstFields = [
        { apiName: 'CGST__c', label: 'CGST' },
        { apiName: 'CGST_Amount__c', label: 'CGST Amount' },
        { apiName: 'SGST__c', label: 'SGST' },
        { apiName: 'SGST_Amount__c', label: 'SGST Amount' },
        { apiName: 'IGST__c', label: 'IGST' },
        { apiName: 'IGST_Amount__c', label: 'IGST Amount' }
    ];

    soaFields = [
        { apiName: 'Effective_Final_Discount_Approver__c', label: 'Effective Final Discount Approver' },
        { apiName: '', label: '' },
        { apiName: 'Final_Discount_Approver__c', label: 'Final Discount Approver' },
        { apiName: '', label: '' },
        { apiName: 'Managing_Director_Country_Manage__c', label: 'Managing Director/Country Manager' },
        { apiName: 'Managing_Director_Status__c', label: 'Managing Director Status' },
        { apiName: 'Rotex_Board_Member__c', label: 'Rotex Board Member' },
        { apiName: 'Rotex_Board_Member_Status__c', label: 'Rotex Board Member Status' },
        { apiName: 'Global_Sales_Head__c', label: 'Global Sales Head' },
        { apiName: 'Global_Sales_Head_Status__c', label: 'Global Sales Head Status' },
        { apiName: 'Country_Continent_Sales_Head_LOB_Head__c', label: 'Country/Continent Sales Head/LOB Head' },
        { apiName: 'Country_Continent_Sales_H_LOB_Status__c', label: 'Country/Continent Sales H/LOB Status' },
        { apiName: 'Sales_Manager__c', label: 'Sales Manager' },
        { apiName: 'Sales_Manager_Status__c', label: 'Sales Manager Status' },
        { apiName: 'Sales_Rep__c', label: 'Sales Rep' }
    ];

    commentsFields = [
        { apiName: 'Sales_Manager_Comments__c', label: 'Sales Manager Comments' },
        { apiName: 'Sales_Manager_Date_Time__c', label: 'Sales Manager Date/Time' },
        { apiName: 'Country_Continent_Sales_LOB_Comments__c', label: 'Country/Continent Sales LOB Comments' },
        { apiName: 'Country_Head_Date_Time__c', label: 'Country Head Date/Time' },
        { apiName: 'Global_Sales_Head_Comments__c', label: 'Global Sales Head Comments' },
        { apiName: 'Global_Sales_Head_Date_Time__c', label: 'Global Sales Head Date/Time' },
        { apiName: 'Rotex_Board_Member_Comments__c', label: 'Rotex Board Member Comments' },
        { apiName: 'Rotex_Board_Member_Date_time__c', label: 'Rotex Board Member Date/Time' },
        { apiName: 'Managing_Director_Comments__c', label: 'Managing Director Comments' },
        { apiName: 'Managing_Director_Date_Time__c', label: 'Managing Director Date/Time' }
    ];

    prevCommentsFields = [
        { apiName: 'Prev_Sales_Manager_Comments__c', label: 'Previous Sales Manager Comments' },
        { apiName: 'Prev_Sales_Manager_Date_Time__c', label: 'Previous Sales Manager Date/Time' },
        { apiName: 'Prev_Country_Continent_Sales_Comments__c', label: 'Previous Country/Continent Sales Comments' },
        { apiName: 'Prev_Country_Head_Date_Time__c', label: 'Previous Country Head Date/Time' },
        { apiName: 'Prev_Global_Sales_Head_Comments__c', label: 'Previous Global Sales Head Comments' },
        { apiName: 'Prev_Global_Sales_Head_Date_Time__c', label: 'Previous Global Sales Head Date/Time' },
        { apiName: 'Prev_Rotex_Board_Member_Comments__c', label: 'Previous Rotex Board Member Comments' },
        { apiName: 'Prev_Rotex_Board_Member_Date_time__c', label: 'Previous Rotex Board Member Date/Time' },
        { apiName: 'Prev_Managing_Director_Comments__c', label: 'Previous Managing Director Comments' },
        { apiName: 'Prev_Managing_Director_Date_Time__c', label: 'Previous Managing Director Date/Time' }
    ];

    systemFields = [
        { apiName: 'CreatedById', label: 'Created By' },
        { apiName: 'LastModifiedById', label: 'Last Modified By' },
        { apiName: 'CreatedDate', label: 'Created Date' },
        { apiName: 'LastModifiedDate', label: 'Last Modified Date' }
    ];

    handleLoad(event) {
        this.isLoading = false;
        this.errorMessage = '';
    }

    handleError(event) {
        this.isLoading = false;
        this.errorMessage = 'Error loading record: ' + (event.detail?.message || 'Unknown error');
        console.error('Quote Line Item load error:', event.detail);
    }
}