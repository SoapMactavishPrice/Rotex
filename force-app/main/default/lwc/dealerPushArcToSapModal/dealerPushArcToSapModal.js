import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuoteLineItems from '@salesforce/apex/PushARCToSAP.getQuoteLineItems';
import pushToSAP from '@salesforce/apex/PushARCToSAP.pushToSAP';

export default class DealerPushArcToSapModal extends LightningElement {
    @api quoteId;

    @track lineItems = [];
    @track showSpinner = true;
    @track isSaving = false;
    @track errorMessage = '';
    @track successMessage = '';

    get hasLineItems() {
        return this.lineItems && this.lineItems.length > 0;
    }

    get hasNoLineItems() {
        return this.lineItems && this.lineItems.length === 0 && !this.showSpinner;
    }

    connectedCallback() {
        if (this.quoteId) {
            this.loadLineItems(this.quoteId);
        } else {
            this.errorMessage = 'No Quote ID found. Please try again.';
            this.showSpinner = false;
        }
    }

    loadLineItems(quoteId) {
        this.showSpinner = true;
        this.errorMessage = '';

        getQuoteLineItems({ quoteId })
            .then((result) => {
                let data;
                try {
                    data = JSON.parse(result);
                } catch (parseError) {
                    this.errorMessage = 'Error parsing response: ' + parseError.message;
                    this.showSpinner = false;
                    return;
                }

                if (data && data.lineItems && data.lineItems.length > 0) {
                    this.lineItems = data.lineItems.map((item) => {
                        const listPrice = item.ListPrice || 0;
                        const unitPrice = item.UnitPrice || listPrice;
                        const quantity = item.Quantity || 1;
                        const discount = item.Discount_to_be_offered__c || 0;
                        const productCode = item.Product2 ? item.Product2.ProductCode : '';
                        const validFrom =
                            item.Valid_from__c || item.Valid_From__c || this.getDefaultDate();
                        const validTill = item.Valid_Till__c || '9999-12-31';

                        return {
                            id: item.Id,
                            productName: item.Product2 ? item.Product2.Name : '',
                            productCode,
                            listPrice,
                            salesPrice: unitPrice,
                            discount,
                            quantity,
                            totalPrice: unitPrice * quantity,
                            validFrom,
                            validTill,
                            formattedListPrice: this.formatCurrency(listPrice),
                            formattedSalesPrice: this.formatCurrency(unitPrice),
                            formattedDiscount: this.formatPercentage(discount),
                            formattedTotalPrice: this.formatCurrency(unitPrice * quantity)
                        };
                    });
                } else {
                    this.lineItems = [];
                }

                this.showSpinner = false;
            })
            .catch((error) => {
                this.errorMessage =
                    'Error loading line items: ' +
                    (error.body ? error.body.message : error.message);
                this.showSpinner = false;
                this.lineItems = [];
            });
    }

    handleSave() {
        if (!this.quoteId) {
            this.showToast('Error', 'No Quote ID available', 'error');
            return;
        }

        this.isSaving = true;
        this.errorMessage = '';
        this.successMessage = '';

        const payload = this.lineItems.map((item) => ({
            id: item.id,
            productCode: item.productCode,
            listPrice: item.listPrice,
            salesPrice: item.salesPrice,
            quantity: item.quantity,
            validFrom: item.validFrom,
            validTill: item.validTill
        }));

        pushToSAP({
            quoteId: this.quoteId,
            lineItems: payload
        })
            .then((result) => {
                const response = JSON.parse(result);

                if (response.status === 'success') {
                    this.successMessage =
                        response.message + ' (' + response.itemsProcessed + ' items)';
                    this.showToast('Success', this.successMessage, 'success');
                    this.dispatchEvent(new CustomEvent('save', { bubbles: true, composed: true }));
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    setTimeout(() => {
                        this.dispatchEvent(
                            new CustomEvent('close', { bubbles: true, composed: true })
                        );
                    }, 1500);
                } else {
                    this.errorMessage = response.message || 'Failed to push to SAP';
                    this.showToast('Error', this.errorMessage, 'error');
                    this.isSaving = false;
                }
            })
            .catch((error) => {
                this.errorMessage =
                    'Error pushing to SAP: ' + (error.body ? error.body.message : error.message);
                this.showToast('Error', this.errorMessage, 'error');
                this.isSaving = false;
            });
    }

    handleCancel() {
        if (this.isSaving) {
            return;
        }
        this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    getDefaultDate() {
        return new Date().toISOString().split('T')[0];
    }

    formatCurrency(value) {
        if (!value || value === 0) {
            return '₹0.00';
        }
        return (
            '₹' +
            parseFloat(value)
                .toFixed(2)
                .replace(/\B(?=(\d{3})+(?!\d))/g, ',')
        );
    }

    formatPercentage(value) {
        if (!value || value === 0) {
            return '0.00%';
        }
        return parseFloat(value).toFixed(2) + '%';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: variant || 'info',
                mode: 'dismissable'
            })
        );
    }
}