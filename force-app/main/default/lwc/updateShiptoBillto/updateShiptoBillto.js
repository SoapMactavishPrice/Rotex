import { LightningElement, track, api, wire } from 'lwc';
import getLineItem from '@salesforce/apex/IntegrationHandler.getLineItem';
import updateShiptoBilltoOnQuote from '@salesforce/apex/editDiscountQuantityController.updateShiptoBilltoOnQuote';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

export default class UpdateShiptoBillto extends LightningElement {
    @api recordId;
    @api objectApiName;
    @track showSpinner = false;
    @track allDataList = [];
    @track shiptoList = [];
    @track billtoList = [];
    @track shiptoValue = '';
    @track billtoValue = '';
    @track selectedShipto;
    @track selectedBillto;

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
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new RefreshEvent());
        setTimeout(() => {
            window.location.reload();
        }, 2000);
    }

    connectedCallback() {
        this.showSpinner = true;
        setTimeout(() => {
            console.log('recordId ', this.recordId);
            console.log('objectApiName ', this.objectApiName);
            if (this.recordId) {
                this.getShiptoBillto();
            }
        }, 250);
    }

    getShiptoBillto() {
        getLineItem({
            qId: this.recordId
        }).then((result) => {
            let data = JSON.parse(result);
            console.log('data:>>> ', data);
            this.allDataList = data;
            this.shiptoList = data.shList.map(item => {
                let fullAddress = `${item.Name} - ${item.Street__c}, ${item.City__c}, ${item.State__c}, ${item.Postal_Code__c}, ${item.Country__c} `;
                return {
                    label: fullAddress,
                    value: item.Id
                };
            });
            this.billtoList = data.bpList.map(item => {
                let fullAddress = `${item.Name} - ${item.Street__c}, ${item.City__c}, ${item.State__c}, ${item.Postal_Code__c}, ${item.Country__c} `;
                return {
                    label: fullAddress,
                    value: item.Id
                };
            });
        })
    }

    handleShiptoChange(event) {
        const selectedValue = event.detail.value;
        this.shiptoValue = selectedValue;

        const tofindfrom = this.allDataList.shList;
        console.log('tofindfrom ', tofindfrom);

        // Find the selected item from shiptoList
        const selectedItem = tofindfrom.find(item => item.Id === selectedValue);

        if (selectedItem) {
            console.log('Selected Ship To Details:', selectedItem);
            this.selectedShipto = selectedItem;
            // You can access other properties of the selected item here
            // For example: selectedItem.label for the full address
        }
    }

    handleBilltoChange(event) {
        const selectedValue = event.detail.value;
        this.billtoValue = selectedValue;

        const tofindfrom = this.allDataList.bpList;
        console.log('tofindfrom ', tofindfrom);

        // Find the selected item from billtoList
        const selectedItem = tofindfrom.find(item => item.Id === selectedValue);

        if (selectedItem) {
            console.log('Selected Bill To Details:', selectedItem);
            this.selectedBillto = selectedItem;
            // You can access other properties of the selected item here
            // For example: selectedItem.label for the full address
        }
    }

    handleSave() {
        console.log('shiptoValue ', this.shiptoValue);
        console.log('billtoValue ', this.billtoValue);
        console.log('selectedShipto ', this.selectedShipto);
        console.log('selectedBillto ', this.selectedBillto);

        this.showSpinner = true;

        updateShiptoBilltoOnQuote({
            qId: this.recordId,
            shipto: JSON.stringify(this.selectedShipto),
            billto: JSON.stringify(this.selectedBillto)
        }).then(() => {
            this.showSpinner = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Shipto and Billto updated successfully',
                variant: 'success'
            }));
            this.closeModal();
        }).catch((error) => {
            this.showSpinner = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Error updating Shipto and Billto',
                variant: 'error'
            }));
        });
    }

}