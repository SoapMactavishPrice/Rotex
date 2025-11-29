import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getLineItem from '@salesforce/apex/IntegrationHandler.getLineItem';
import quoteValidation from '@salesforce/apex/IntegrationHandler.quoteValidation';
import salesOrderCreation from '@salesforce/apex/IntegrationHandler.salesOrderCreation';
import updateQuotation from '@salesforce/apex/IntegrationHandler.updateQuotation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

export default class SendQuoteToSAP extends LightningElement {

    @api recordId;
    @api objectApiName;
    @api salesDocNo;
    @track showSpinner = false;
    @track recTypeName = '';
    @track ResponseMessage = '';
    @track errorResponseMessage = '';
    @track syncDataResponseFlag = false;
    @track partnerfunctionOptions = [];
    @track partnerfunctionValue = '';
    @track bpOptions = [];
    @track bpValue = '';
    @track shOptions = [];
    @track shValue = '';
    @track caOptions = [];
    @track caValue = '';

    showToast(toastTitle, toastMsg, toastType) {
        const event = new ShowToastEvent({
            title: toastTitle,
            message: toastMsg,
            variant: toastType,
            mode: "dismissable"
        });
        this.dispatchEvent(event);
    }

    connectedCallback() {
        this.showSpinner = true;
        setTimeout(() => {
            console.log('recordId ', this.recordId);
            console.log('objectApiName ', this.objectApiName);
            if (this.recordId) {
                this.handleQuoteCheck();
                this.handleGetLineItems();
            } else {
                this.showToast('Error', 'Invalid Record Id', 'error');
            }
        }, 2000);
    }

    // Send Quote as SO to SAP
    handleQuoteCheck() {
        quoteValidation({
            qId: this.recordId
        }).then((result) => {
            console.log('quoteValidation result ', result);
            let data = JSON.parse(result);
            if (data.status == 'true') {
                // this.showToast('Please wait for callout response', '', 'info');
                // this.handleCallout();
            } else {
                this.closeModal();
                this.showToast(data.message, '', 'error');
                this.errorResponseMessage = data.message;
                this.showSpinner = false;
            }
            this.showSpinner = false;
        }).catch((error) => {
            console.log('= erorr quoteValidation : ', error);
            this.showSpinner = false;
        })
    }

    @track orderLineItemList = [];
    handleGetLineItems() {
        getLineItem({
            qId: this.recordId
        }).then((result) => {
            let data = JSON.parse(result);
            console.log('data:>>> ', data);
            this.orderLineItemList = data.quoteLineItemList;
            console.log('orderLineItemList ', this.orderLineItemList);

            this.bpOptions = data.bpList.map(item => {
                let fullAddress = `${item.Name} - ${item.Street__c}, ${item.City__c}, ${item.State__c}, ${item.Postal_Code__c}, ${item.Country__c} `;
                return {
                    label: fullAddress,
                    value: item.Id
                };
            });
            this.shOptions = data.shList.map(item => {
                let fullAddress = `${item.Name} - ${item.Street__c}, ${item.City__c}, ${item.State__c}, ${item.Postal_Code__c}, ${item.Country__c} `;
                return {
                    label: fullAddress,
                    value: item.Id
                };
            });
            this.caOptions = data.caList.map(item => {
                let fullAddress = `${item.Name} - ${item.Street__c}, ${item.City__c}, ${item.State__c}, ${item.Postal_Code__c}, ${item.Country__c} `;
                return {
                    label: fullAddress,
                    value: item.Id
                };
            });
        })
    }

    closeModal(event) {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new RefreshEvent());
    }

    handleInputChange(event) {
        if (event.target.name == 'bp') {
            this.bpValue = event.target.value;
        }
        if (event.target.name == 'sh') {
            this.shValue = event.target.value;
        }
        if (event.target.name == 'ca') {
            this.caValue = event.target.value;
        }
    }

    // ------------ Main Order Submit --------------------
    handleMainSubmit(event) {
        this.showSpinner = true;
        event.preventDefault();
        const mandatoryFields = ['RequestedDeliveryDate__c', 'Customer_Reference_No__c', 'Customer_Reference_Date__c'];
        const lwcInputFields = this.template.querySelectorAll('lightning-input-field');
        let validationFlag = false;
        if (lwcInputFields) {
            lwcInputFields.forEach(field => {
                if (mandatoryFields.includes(field.fieldName) && (field.value == null || field.value === '')) {
                    console.log(field.fieldName);
                    validationFlag = true;
                }
                field.reportValidity();
            });
            if (this.bpValue == '' || this.shValue == '') {
                validationFlag = true;
            }
            if (validationFlag) {
                console.log('validation flag trigger');
                // Optionally show a toast message for validation errors
                this.showToast('Please fill/select all the mandatory fields', '', 'error');
                this.showSpinner = false;
            } else {
                const form1 = this.template.querySelector('lightning-record-edit-form[data-id="mainform"]');
                const fields = {};
                form1.submit();
            }
        }
    }

    handleNewError(event) {
        // This will display the error in the lightning-messages component
        const error = event.detail;
        console.log('Error occurred: ', error);

        // Optionally show an error toast message
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'An error occurred: ' + error.detail,
                variant: 'error'
            })
        );

    }

    handleMainSuccess(event) {
        // this.showToast('Customer Details Save', '', 'success');
        this.showToast('Please wait for callout response', '', 'info');
        this.syncDataResponseFlag = true;
        // this.showSpinner = false;
        this.handleCallout();
    }

    handleCallout() {
        salesOrderCreation({
            parentId: this.recordId,
            bpFuncId: this.bpValue,
            shFuncId: this.shValue,
            caFuncId: this.caValue
        }).then((result) => {
            console.log('result ', result);
            let data = JSON.parse(JSON.parse(result));
            console.log('data:>>> ', data);
            if (data.d) {
                if (data.d.SalesQuotation) {
                    // this.ResponseMessage = 'SAP Quotation Number: ' + data.d.SalesQuotation;
                    this.handlerUpdateQuotation(data.d.SalesQuotation);
                    // this.showToast('Quotation created in SAP succesfully!', '', 'success');
                }
            } else {
                this.showSpinner = false;
                this.errorResponseMessage = JSON.stringify(data.error.message);
                this.showToast('Error', 'Something went wrong!!!', 'error');
            }

        }).catch((error) => {
            console.log('= erorr salesOrderCreation', error);
            this.showToast('Error', 'Something went wrong!!!', 'error');
            this.errorResponseMessage = error;
            this.showSpinner = false;
        })
    }

    handlerUpdateQuotation(para) {
        updateQuotation({
            qId: this.recordId,
            qNumber: para
        }).then((result) => {
            console.log('updateQuotation result : ', result);
            if (result == 'ok') {
                this.showToast('Quotation created in SAP succesfully!', '', 'success');
                this.ResponseMessage = 'SAP Quotation Number: ' + para;
            } else {
                this.showToast('Error', 'Something went wrong while updating the SAP quation number in salesforce!!!', 'error');
            }
            this.showSpinner = false;
        }).catch((error) => {
            console.log('= erorr updateQuotation : ', error);
            this.showToast('Error', 'Something went wrong!!!', 'error');
        })
    }

}