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
            this.quoteLineItemList = result;
            console.log('quoteLineItemList ', this.quoteLineItemList);
        })
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

    handleSave() {
        this.showSpinner = true;

        const itemsToUpdate = this.quoteLineItemList.map(item => ({
            Id: item.Id,
            Quantity: item.Quantity ? parseFloat(item.Quantity) : 0,
            Discount_to_be_offered__c: item.Discount_to_be_offered__c ? parseFloat(item.Discount_to_be_offered__c) : 0,
            Customer_Part_No__c: item.Customer_Part_No__c,
            P_F_Charges__c: item.P_F_Charges__c ? parseFloat(item.P_F_Charges__c) : 0
        }));

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