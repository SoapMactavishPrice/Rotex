import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import getQuoteLineItem from '@salesforce/apex/editDiscountQuantityController.getQuoteLineItem';
import updateQuoteLineItem from '@salesforce/apex/editDiscountQuantityController.updateQuoteLineItem';

export default class EditDiscountQuantity extends LightningElement {
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

    closeModal(event) {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new RefreshEvent());
        // setTimeout(() => {
        //     window.location.reload();
        // }, 250);
    }

    connectedCallback() {
        this.showSpinner = true;
        setTimeout(() => {
            console.log('recordId ', this.recordId);
            console.log('objectApiName ', this.objectApiName);
            if (this.recordId) {
                this.showSpinner = false;
                this.handleGetLineItems();
            } else {
                this.showToast('Error', 'Invalid Record Id', 'error');
            }
        }, 2000);
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
        console.log('quoteLineItemList ', this.quoteLineItemList);

        const itemsToUpdate = this.quoteLineItemList.map(item => ({
            Id: item.Id,
            Quantity: item.Quantity ? parseFloat(item.Quantity) : 0,
            Discount_to_be_offered__c: item.Discount_to_be_offered__c ? parseFloat(item.Discount_to_be_offered__c) : 0,
            Customer_Part_No__c: item.Customer_Part_No__c
        }));

        updateQuoteLineItem({
            quoteLineItems: itemsToUpdate
        }).then(() => {
            this.showToast('Quote Line Items Updated', '', 'success');
            this.closeModal();
            // window.location.reload();
        }).catch((error) => {
            this.showToast('Error', 'Something went wrong!!!', 'error');
            this.errorResponseMessage = error;
            this.showSpinner = false;
        })
    }

}