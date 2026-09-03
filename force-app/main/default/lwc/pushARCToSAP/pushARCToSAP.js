import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import getQuoteLineItems from '@salesforce/apex/PushARCToSAP.getQuoteLineItems';
import pushToSAP from '@salesforce/apex/PushARCToSAP.pushToSAP';

export default class PushARCToSAP extends LightningElement {
    @api recordId;

    @track lineItems = [];
    @track showSpinner = true;
    @track isSaving = false;
    @track errorMessage = '';
    @track successMessage = '';
    @track sapPayloadJson = '';

    get hasLineItems() {
        return this.lineItems && this.lineItems.length > 0;
    }

    get hasNoLineItems() {
        return this.lineItems && this.lineItems.length === 0 && !this.showSpinner;
    }

    connectedCallback() {
        console.log('=== PushARCToSAP Component Loaded ===');

        let quoteId = this.getRecordId();

        if (quoteId) {
            console.log('Found recordId:', quoteId);
            this.loadLineItems(quoteId);
        } else {
            console.error('No recordId found!');
            this.errorMessage = 'No Quote ID found. Please try again.';
            this.showSpinner = false;
        }
    }

    getRecordId() {
        if (this.recordId) {
            return this.recordId;
        }

        try {
            const urlParams = new URLSearchParams(window.location.search);
            const idFromUrl = urlParams.get('recordId') || urlParams.get('id');
            if (idFromUrl) {
                this.recordId = idFromUrl;
                return idFromUrl;
            }
        } catch (e) {
            console.error('Error getting URL params:', e);
        }

        try {
            const path = window.location.pathname;
            const match = path.match(/\/0Q0[A-Za-z0-9]+/);
            if (match) {
                const idFromPath = match[0].replace('/', '');
                this.recordId = idFromPath;
                return idFromPath;
            }
        } catch (e) {
            console.error('Error getting path:', e);
        }

        return null;
    }

    loadLineItems(quoteId) {
        console.log('Loading for Quote ID:', quoteId);

        this.showSpinner = true;
        this.errorMessage = '';

        getQuoteLineItems({ quoteId: quoteId })
            .then(result => {
                let data;
                try {
                    data = JSON.parse(result);
                    console.log('=== PARSED DATA ===');
                    console.log('Distribution Channel:', data.distributionChannel);
                    console.log('Customer Code:', data.customerCode);
                    console.log('Currency:', data.currency);

                    // DEBUG: Log raw line items
                    console.log('=== RAW LINE ITEMS FROM APEX ===');
                    console.log(JSON.stringify(data.lineItems));

                } catch (parseError) {
                    console.error('JSON Parse Error:', parseError);
                    this.errorMessage = 'Error parsing response: ' + parseError.message;
                    this.showSpinner = false;
                    return;
                }

                if (data && data.lineItems && data.lineItems.length > 0) {
                    this.lineItems = data.lineItems.map((item) => {
                        // DEBUG: Log each item
                        console.log('=== PROCESSING ITEM ===');
                        console.log('Item Id:', item.Id);
                        console.log('Product2:', item.Product2);
                        console.log('Product2.Name:', item.Product2 ? item.Product2.Name : 'NULL');
                        console.log('Product2.ProductCode:', item.Product2 ? item.Product2.ProductCode : 'NULL');

                        const listPrice = item.ListPrice || 0;
                        const unitPrice = item.UnitPrice || listPrice;
                        const quantity = item.Quantity || 1;
                        const discount = item.Discount_to_be_offered__c || 0;

                        // FIX: Access ProductCode from Product2 object
                        const productCode = item.Product2 ? item.Product2.ProductCode : '';
                        console.log('Extracted productCode:', productCode);

                        return {
                            id: item.Id,
                            productName: item.Product2 ? item.Product2.Name : '',
                            productCode: productCode,  // This should now have value
                            listPrice: listPrice,
                            salesPrice: unitPrice,
                            discount: discount,
                            quantity: quantity,
                            totalPrice: unitPrice * quantity,
                            validFrom: item.Valid_From__c || this.getDefaultDate(),
                            validTill: item.Valid_Till__c || '9999-12-31',
                            formattedListPrice: this.formatCurrency(listPrice),
                            formattedSalesPrice: this.formatCurrency(unitPrice),
                            formattedDiscount: this.formatPercentage(discount),
                            formattedTotalPrice: this.formatCurrency(unitPrice * quantity)
                        };
                    });

                    console.log('=== MAPPED LINE ITEMS ===');
                    console.log(JSON.stringify(this.lineItems));

                    this.showSapJsonStructure();
                } else {
                    this.lineItems = [];
                }

                this.showSpinner = false;
            })
            .catch(error => {
                console.error('Apex Error:', error);
                this.errorMessage = 'Error loading line items: ' + (error.body ? error.body.message : error.message);
                this.showSpinner = false;
                this.lineItems = [];
            });
    }

    showSapJsonStructure() {
        const samplePayload = this.lineItems.map(item => ({
            "conditon_ident": "C",
            "condition_type": "ZPFX",
            "sales_org": "1100",
            "distribution_channel": "10",
            "customer": "110021",
            "material": item.productCode,
            "condition_amt": String(item.listPrice),
            "codition_curr": "INR",
            "pricing_unit": "1",
            "unit_of_measure": "EA",
            "valid_to": item.validTill,
            "valid_from": item.validFrom,
            "scale_qty1": String(item.quantity),
            "scale_amt1": String(item.salesPrice)
        }));

        this.sapPayloadJson = JSON.stringify(samplePayload, null, 2);
        console.log('=== SAP PAYLOAD STRUCTURE ===');
        console.log(this.sapPayloadJson);
    }

    handleSave() {
        console.log('=== handleSave START ===');

        const idToUse = this.getRecordId();
        if (!idToUse) {
            this.showToast('Error', 'No Quote ID available', 'error');
            return;
        }

        // DEBUG: Log lineItems before preparing payload
        console.log('=== LINE ITEMS BEFORE SAVE ===');
        console.log(JSON.stringify(this.lineItems));

        this.isSaving = true;
        this.errorMessage = '';
        this.successMessage = '';

        const payload = this.lineItems.map(item => {
            console.log('Item before send:', JSON.stringify(item));

            return {
                id: item.id,
                productCode: item.productCode,
                listPrice: item.listPrice,
                salesPrice: item.salesPrice,
                quantity: item.quantity,
                validFrom: item.validFrom,
                validTill: item.validTill
            };
        });

        console.log('================ PAYLOAD TO APEX ================');
        console.log(JSON.stringify(payload, null, 2));
        console.log('=================================================');

        pushToSAP({
            quoteId: this.recordId,
            lineItems: payload
        })
            .then(result => {
                console.log('SAP Response:', result);
                const response = JSON.parse(result);

                if (response.status === 'success') {
                    this.successMessage = response.message + ' (' + response.itemsProcessed + ' items)';
                    this.showToast('Success', this.successMessage, 'success');

                    setTimeout(() => {
                        this.closeModal();
                    }, 2000);
                } else {
                    this.errorMessage = response.message || 'Failed to push to SAP';
                    this.showToast('Error', this.errorMessage, 'error');
                    this.isSaving = false;
                }
            })
            .catch(error => {
                console.error('Push error:', error);
                this.errorMessage = 'Error pushing to SAP: ' + (error.body ? error.body.message : error.message);
                this.showToast('Error', this.errorMessage, 'error');
                this.isSaving = false;
            });
    }

    handleCancel() {
        this.closeModal();
    }

    getDefaultDate() {
        const today = new Date();
        return today.toISOString().split('T')[0];
    }

    formatCurrency(value) {
        if (!value || value === 0) return '₹0.00';
        return '₹' + parseFloat(value).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }

    formatPercentage(value) {
        if (!value || value === 0) return '0.00%';
        return parseFloat(value).toFixed(2) + '%';
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new RefreshEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        }));
    }
}