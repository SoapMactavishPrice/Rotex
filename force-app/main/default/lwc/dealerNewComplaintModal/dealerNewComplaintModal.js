import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createComplaint from '@salesforce/apex/ComplaintController.createComplaint';
import getAllCasePicklists from '@salesforce/apex/ComplaintController.getAllCasePicklists';
import getAvailableAccounts from '@salesforce/apex/ComplaintController.getAvailableAccounts';
import getAvailableContacts from '@salesforce/apex/ComplaintController.getAvailableContacts';
import getCategoryRelatedData from '@salesforce/apex/ComplaintController.getCategoryRelatedData';

export default class DealerNewComplaintModal extends LightningElement {
    @track showCustomerLookup = false;
    @track showQuoteLookup = false;
    @track showOrderLookup = false;
    @track showInvoiceLookup = false;
    @track showGrnLookup = false;
    @track showProductLookup = false;
    @track showOtherLookup = false;

    @track isSaving = false;

    @track customerLookupOptions = [];
    @track quoteLookupOptions = [];
    @track orderLookupOptions = [];
    @track invoiceLookupOptions = [];
    @track grnLookupOptions = [];
    @track productLookupOptions = [];

    @track ticketTypeOptions = [];
    @track categoryOptions = [];
    @track priorityOptions = [];
    @track rootCauseOptions = [];
    @track csatOptions = [];
    @track statusOptions = [];

    @track accountOptions = [];
    @track contactOptions = [];

    selectedAccountId = null;

    @wire(getAllCasePicklists)
    wiredPicklists({ error, data }) {
        if (data) {
            this.ticketTypeOptions = data.Ticket_Type__c || [];
            this.categoryOptions = data.Category__c || [];
            this.priorityOptions = data.Priority || [];
            this.rootCauseOptions = data.Root_Cause__c || [];
            this.csatOptions = data.Customer_Satisfaction__c || [];
            this.statusOptions = data.Status || [];
        }
    }

    @wire(getAvailableAccounts)
    wiredAccounts({ error, data }) {
        if (data) {
            this.accountOptions = data;
        }
    }

    @wire(getAvailableContacts)
    wiredContacts({ error, data }) {
        if (data) {
            this.contactOptions = data;
        }
    }

    @wire(getCategoryRelatedData, { accountId: '$selectedAccountId' })
    wiredCategoryData({ error, data }) {
        if (data) {
            this.customerLookupOptions = data.Customer || [];
            this.quoteLookupOptions = data.Quote || [];
            this.orderLookupOptions = data.Order || [];
            this.invoiceLookupOptions = data.Invoice || [];
            this.grnLookupOptions = data.GRN || [];
            this.productLookupOptions = data.Product || [];
        } else if (error) {
            console.error('Error fetching category data', error);
        }
    }

    formData = {
        Priority: 'Medium',
        Status: 'New',
        AccountId: '',
        ContactId: ''
    };

    closeModal() {
        this.dispatchEvent(new CustomEvent('closemodal'));
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        if (field) {
            this.formData[field] = value;
            if (field === 'AccountId') {
                this.selectedAccountId = value;
                this.formData['ContactId'] = ''; // reset contact on account change
            }
        }
    }

    handleCategoryChange(event) {
        const cat = event.target.value;
        this.formData['Category__c'] = cat;

        this.showCustomerLookup = (cat === 'Customer');
        this.showQuoteLookup = (cat === 'Quote');
        this.showOrderLookup = (cat === 'Order');
        this.showInvoiceLookup = (cat === 'Invoice');
        this.showGrnLookup = (cat === 'GRN');
        this.showProductLookup = (cat === 'Product');
        this.showOtherLookup = (cat === 'Other');
    }

    openDatePicker(event) {
        try {
            if (event.target && typeof event.target.showPicker === 'function') {
                event.target.showPicker();
            }
        } catch (e) {
            console.warn('Error opening date picker', e);
        }
    }

    @track fieldErrors = {};

    get isCategorySelected() {
        return this.showCustomerLookup || this.showQuoteLookup || this.showOrderLookup || this.showInvoiceLookup || this.showGrnLookup || this.showProductLookup || this.showOtherLookup;
    }

    get statusClass() {
        return this.isCategorySelected ? 'form-field order-last' : 'form-field';
    }

    get todayDate() {
        const d = new Date();
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    async saveRecord() {
        if (this.isSaving) return;
        this.fieldErrors = {};

        // Remove previous error classes
        this.template.querySelectorAll('.form-input, .form-select').forEach(el => {
            el.classList.remove('input-error');
        });

        // Validation for mandatory fields
        const requiredFields = [
            { field: 'Ticket_Type__c', name: 'Ticket Type' },
            { field: 'Category__c', name: 'Category' },
            { field: 'AccountId', name: 'Channel Partner' },
            { field: 'ContactId', name: 'Contact' },
            { field: 'Priority', name: 'Priority' },
            { field: 'Status', name: 'Status' },
            { field: 'Subject', name: 'Subject' }
        ];

        let missingFields = [];
        for (let req of requiredFields) {
            if (!this.formData[req.field] || String(this.formData[req.field]).trim() === '') {
                missingFields.push(req.name);
                this.fieldErrors[req.field] = `${req.name} is required.`;

                // Add error class to input
                const inputEl = this.template.querySelector(`[data-field="${req.field}"]`);
                if (inputEl) {
                    inputEl.classList.add('input-error');
                }
            }
        }

        if (missingFields.length > 0) {
            return;
        }

        this.isSaving = true;

        try {
            await createComplaint({ caseData: this.formData });
            this.isSaving = false;
            this.dispatchEvent(new CustomEvent('complaintcreated'));
        } catch (error) {
            this.isSaving = false;
            let errMsg = 'An unknown error occurred';
            if (error.body && error.body.message) {
                errMsg = error.body.message;
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error saving record',
                    message: errMsg,
                    variant: 'error'
                })
            );
        }
    }
}