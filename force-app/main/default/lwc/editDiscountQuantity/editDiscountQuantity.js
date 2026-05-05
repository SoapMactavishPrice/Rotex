import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import modal from "@salesforce/resourceUrl/containerCss";
import { loadStyle } from "lightning/platformResourceLoader";
import getQuoteLineItem from '@salesforce/apex/editDiscountQuantityController.getQuoteLineItem';
import updateQuoteLineItem from '@salesforce/apex/editDiscountQuantityController.updateQuoteLineItem';
import { NavigationMixin } from 'lightning/navigation';

export default class EditDiscountQuantity extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @track showSpinner = false;
    @track quoteLineItemList = [];

    showToast(toastTitle, toastMsg, toastType) {
        const event = new ShowToastEvent({
            title: toastTitle,
            message: toastMsg,
            variant: toastType,
            mode: "dismissable"
        });
        this.dispatchEvent(event);
    }

    closeModal() {
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Quote',
                actionName: 'view',

            }
        });
        setTimeout(() => {
            window.location.reload();
        }, 1000);
    }

    connectedCallback() {
        this.showSpinner = true;
        loadStyle(this, modal);
        setTimeout(() => {
            console.log('recordId ', this.recordId);
            console.log('objectApiName ', this.objectApiName);
            if (this.recordId) {
                this.handleGetLineItems();
                this.showSpinner = false;
            } else {
                this.showToast('Error', 'Invalid Record Id', 'error');
            }
        }, 1000);
    }

    handleGetLineItems() {
        getQuoteLineItem({
            qId: this.recordId
        }).then((result) => {
            // let data = JSON.parse(result);
            console.log('data:>>> ', result);
            // Initialize newDiscountValue for items that need it
            this.quoteLineItemList = result.map(item => ({
                ...item,
                newDiscountValue: null,
                isDiscountOfferedDisabled: item.Is_Discount_Approved__c || this.hasSubmittedApproverStatus(item)
            }));
            console.log('quoteLineItemList ', this.quoteLineItemList);
        })
    }

    hasSubmittedApproverStatus(item) {
        return [
            item.Sales_Manager_Status__c,
            item.Country_Continent_Sales_H_LOB_Status__c,
            item.Global_Sales_Head_Status__c,
            item.Rotex_Board_Member_Status__c,
            item.Managing_Director_Status__c
        ].some(status => status === 'Submitted');
    }

    handleCustomerPartNoChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const updatedItems = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                return { ...item, Customer_Part_No__c: value };
            }
            return item;
        });
        this.quoteLineItemList = updatedItems;
    }

    handleDiscountChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const updatedItems = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                return { ...item, Discount_to_be_offered__c: parseInt(value) };
            }
            return item;
        });
        this.quoteLineItemList = updatedItems;
    }

    handlePFChargeChanges(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const updatedItems = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                return { ...item, P_F_Charges__c: parseInt(value) };
            }
            return item;
        });
        this.quoteLineItemList = updatedItems;
    }

    handleQuantityChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const updatedItems = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                return { ...item, Quantity: parseInt(value) };
            }
            return item;
        });
        this.quoteLineItemList = updatedItems;
    }

    handleNewDiscountChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const updatedItems = this.quoteLineItemList.map(item => {
            if (item.Id === id) {
                // Store the new discount value temporarily
                return { ...item, newDiscountValue: parseFloat(value) };
            }
            return item;
        });
        this.quoteLineItemList = updatedItems;
        console.log('New Discount entered for item:', id, 'Value:', value);
    }

    handleSave() {
        this.showSpinner = true;

        const itemsToUpdate = this.quoteLineItemList.map(item => {
            const updateData = {
                Id: item.Id,
                Quantity: item.Quantity ? parseFloat(item.Quantity) : 0,
                Discount_to_be_offered__c: item.Discount_to_be_offered__c ? parseFloat(item.Discount_to_be_offered__c) : 0,
                Customer_Part_No__c: item.Customer_Part_No__c,
                P_F_Charges__c: item.P_F_Charges__c ? parseFloat(item.P_F_Charges__c) : 0,
                Discount_as_per_SAP__c: parseFloat(item.Discount_as_per_SAP__c),

                Final_Discount_Approver__c: item.Final_Discount_Approver__c,
                Sales_Rep__c: item.Sales_Rep__c,
                Sales_Manager__c: item.Sales_Manager__c,
                Country_Continent_Sales_Head_LOB_Head__c: item.Country_Continent_Sales_Head_LOB_Head__c,
                Global_Sales_Head__c: item.Global_Sales_Head__c,
                Rotex_Board_Member__c: item.Rotex_Board_Member__c,
                Managing_Director_Country_Manage__c: item.Managing_Director_Country_Manage__c,
                Is_Discount_Approved__c: item.Is_Discount_Approved__c
            };

            if (item.Is_Discount_Approved__c && item.newDiscountValue != null && item.newDiscountValue !== '') {
    
                updateData.Previous_Discount__c = item.Discount_to_be_offered__c;
                updateData.Discount_to_be_offered__c = parseFloat(item.newDiscountValue);
                updateData.New_Discount_Entered__c = true;

                updateData.Sales_Manager_Comments__c = item.Sales_Manager_Comments__c;
                updateData.Sales_Manager_Date_Time__c = item.Sales_Manager_Date_Time__c;

                updateData.Country_Continent_Sales_LOB_Comments__c = item.Country_Continent_Sales_LOB_Comments__c;
                updateData.Country_Head_Date_Time__c = item.Country_Head_Date_Time__c;

                updateData.Global_Sales_Head_Comments__c = item.Global_Sales_Head_Comments__c;
                updateData.Global_Sales_Head_Date_Time__c = item.Global_Sales_Head_Date_Time__c;

                updateData.Rotex_Board_Member_Comments__c = item.Rotex_Board_Member_Comments__c;
                updateData.Rotex_Board_Member_Date_time__c = item.Rotex_Board_Member_Date_time__c;

                updateData.Managing_Director_Comments__c = item.Managing_Director_Comments__c;
                updateData.Managing_Director_Date_Time__c = item.Managing_Director_Date_Time__c;
            } else if (item.Previous_Discount__c) {
                updateData.Previous_Discount__c = item.Previous_Discount__c;
            }

            return updateData;
        });

        updateQuoteLineItem({
            quoteLineItems: itemsToUpdate
        }).then(() => {
            this.showToast('Quote Line Items Updated', '', 'success');
            this.closeModal();
        }).catch((error) => {
            console.error(error?.body);
            this.showToast('Error', error?.body?.message, 'error');
            this.errorResponseMessage = error;
            this.showSpinner = false;
        })
    }

}
