import { LightningElement, api, track } from 'lwc';
import saveOrder from '@salesforce/apex/OrderController.saveOrder';
import searchCustomerAccounts from '@salesforce/apex/QuoteController.searchCustomerAccounts';
import getCurrentUserName from '@salesforce/apex/QuoteController.getCurrentUserName';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NewOrderModal extends LightningElement {
    @api partnerAccountId;
    @api partnerAccountName;

    @track isSaving = false;
    @track errorMsg = '';

    @track ownerName = '';
    @track accountId = null;
    @track accountName = '';
    @track accountSearch = '';
    @track accountResults = [];
    @track showAccountDropdown = false;
    @track errors = { accountId: '' };

    @track formData = {
        soNo: '',
        type: '',
        effectiveDate: new Date().toISOString().split('T')[0],
        currencyIsoCode: 'INR',
        netValue: '',
        billTo: '',
        shipTo: '',
        billToCustomerName: '',
        soldTo: '',
        custRef: '',
        termsOfPayment: '',
        custRefDate: '',
        incoterms: '',
        reqDelDate: ''
    };

    connectedCallback() {
        getCurrentUserName()
            .then(name => {
                this.ownerName = name;
            })
            .catch(err => console.error(err));

        if (this.partnerAccountId && this.partnerAccountName) {
            this.accountId = this.partnerAccountId;
            this.accountName = this.partnerAccountName;
        }
    }

    get hasSelectedAccount() {
        return !!this.accountId && !!this.accountName;
    }

    get hasAccountResults() {
        return this.accountResults && this.accountResults.length > 0;
    }

    get accountInputClass() {
        return this.errors.accountId ? 'form-input form-input-error' : 'form-input';
    }

    get saveLabel() {
        return this.isSaving ? 'Saving...' : 'Save';
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.value;
    }

    clearFieldError(field) {
        if (this.errors[field]) {
            this.errors = { ...this.errors, [field]: '' };
        }
    }

    handleAccountFocus() {
        this.showAccountDropdown = true;
        this.runAccountSearch(this.accountSearch || '');
    }

    handleAccountSearch(event) {
        this.accountSearch = event.target.value;
        this.showAccountDropdown = true;
        window.clearTimeout(this.accountTimeout);
        this.accountTimeout = window.setTimeout(() => {
            this.runAccountSearch(this.accountSearch);
        }, 200);
    }

    async runAccountSearch(term) {
        try {
            const data = await searchCustomerAccounts({
                searchText: term || '',
                partnerAccountId: this.partnerAccountId || null
            });
            this.accountResults = data || [];
            this.showAccountDropdown = true;
        } catch (error) {
            this.accountResults = [];
            console.error(error);
        }
    }

    hideAccountDropdown() {
        this.showAccountDropdown = false;
    }

    selectAccount(event) {
        event.preventDefault();
        this.accountId = event.currentTarget.dataset.id;
        this.accountName = event.currentTarget.dataset.label;
        this.accountSearch = '';
        this.accountResults = [];
        this.showAccountDropdown = false;
        this.clearFieldError('accountId');
    }

    clearAccount(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.accountId = null;
        this.accountName = '';
        this.accountSearch = '';
        this.accountResults = [];
    }

    handleSave() {
        this.errorMsg = '';

        let hasError = false;
        if (!this.accountId) {
            this.errors = { ...this.errors, accountId: 'Complete this field.' };
            hasError = true;
        }
        if (!this.formData.effectiveDate) {
            this.errorMsg = 'Order Date is required.';
            hasError = true;
        }

        if (hasError) return;

        this.isSaving = true;

        const input = {
            accountId: this.accountId,
            soNo: this.formData.soNo,
            type: this.formData.type,
            effectiveDate: this.formData.effectiveDate,
            currencyIsoCode: this.formData.currencyIsoCode,
            netValue: this.formData.netValue ? parseFloat(this.formData.netValue) : null,
            billTo: this.formData.billTo,
            shipTo: this.formData.shipTo,
            billToCustomerName: this.formData.billToCustomerName,
            soldTo: this.formData.soldTo,
            custRef: this.formData.custRef,
            termsOfPayment: this.formData.termsOfPayment,
            custRefDate: this.formData.custRefDate,
            incoterms: this.formData.incoterms,
            reqDelDate: this.formData.reqDelDate
        };

        saveOrder({ inputStr: JSON.stringify(input) })
            .then((result) => {
                this.isSaving = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Order created successfully!',
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CustomEvent('save'));
            })
            .catch((error) => {
                this.isSaving = false;
                this.errorMsg = error.body ? error.body.message : error.message;
            });
    }
}