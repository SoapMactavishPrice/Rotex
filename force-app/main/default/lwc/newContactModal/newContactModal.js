import { LightningElement, api, track } from 'lwc';

import createContact from '@salesforce/apex/ContactController.createContact';
import updateContact from '@salesforce/apex/ContactController.updateContact';

const PORTAL_TOAST_DURATION_MS = 4000;
import getSalutationPicklistValues from '@salesforce/apex/ContactController.getSalutationPicklistValues';
import getStatusPicklistValues from '@salesforce/apex/ContactController.getStatusPicklistValues';
import searchCustomerAccounts from '@salesforce/apex/ContactController.searchCustomerAccounts';

const EMPTY_ERRORS = {
    firstName: '',
    lastName: '',
    accountId: ''
};

export default class NewContactModal extends LightningElement {
    @api partnerAccountId;
    @api contactRecord;

    @track salutationOptions = [];
    @track statusOptions = ['Active', 'Inactive'];
    @track accountResults = [];
    @track isSaving = false;
    @track errors = { ...EMPTY_ERRORS };
    @track showAccountDropdown = false;
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';

    portalToastTimeout;
    contactId = null;
    salutation = '';
    firstName = '';
    lastName = '';
    email = '';
    mobilePhone = '';
    designation = '';
    status = 'Active';
    accountId = null;
    accountName = '';
    accountSearch = '';
    dob = '';
    anniversary = '';
    street = '';
    city = '';
    state = '';
    postalCode = '';
    country = '';

    accountTimeout;

    connectedCallback() {
        this.populateFromRecord(this.contactRecord);

        getSalutationPicklistValues()
            .then((data) => {
                this.salutationOptions = data || [];
            })
            .catch((error) => {
                console.error(error);
            });

        getStatusPicklistValues()
            .then((data) => {
                if (data && data.length) {
                    this.statusOptions = data;
                    if (!this.statusOptions.includes(this.status)) {
                        this.status = this.statusOptions[0];
                    }
                }
            })
            .catch((error) => {
                console.error(error);
            });
    }

    get isEditMode() {
        return !!(this.contactId || this.contactRecord?.Id);
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Contact' : 'New Contact';
    }

    get saveButtonLabel() {
        return this.isEditMode ? 'Update' : 'Save';
    }

    get hasSelectedAccount() {
        return !!this.accountId;
    }

    get hasAccountResults() {
        return this.accountResults && this.accountResults.length > 0;
    }

    get firstNameInputClass() {
        return this.errors.firstName ? 'form-input form-input-error' : 'form-input';
    }

    get lastNameInputClass() {
        return this.errors.lastName ? 'form-input form-input-error' : 'form-input';
    }

    get accountInputClass() {
        return this.errors.accountId ? 'form-input form-input-error' : 'form-input';
    }

    populateFromRecord(record) {
        if (!record || !record.Id) {
            return;
        }

        this.contactId = record.Id;
        this.salutation = record.Salutation || '';
        this.firstName = record.FirstName || '';
        this.lastName = record.LastName || '';
        this.email = record.Email || '';
        this.mobilePhone = record.MobilePhone || '';
        this.designation = record.Contact_Person_Designation__c || record.designation || '';
        this.status = record.Status__c || record.statusValue || 'Active';
        this.accountId = record.AccountId || null;
        const accountLabel = record.Account?.Name || record.accountName || '';
        this.accountName = accountLabel === '—' ? '' : accountLabel;
        this.dob = this.formatDateForInput(record.DOB__c);
        this.anniversary = this.formatDateForInput(record.Anniversary__c);
        this.street = record.MailingStreet || '';
        this.city = record.MailingCity || '';
        this.state = record.MailingState || '';
        this.postalCode = record.MailingPostalCode || '';
        this.country = record.MailingCountry || '';
    }

    formatDateForInput(value) {
        if (!value) {
            return '';
        }
        if (typeof value === 'string') {
            return value.substring(0, 10);
        }
        try {
            const d = new Date(value);
            if (Number.isNaN(d.getTime())) {
                return '';
            }
            const yyyy = d.getFullYear();
            const mm = String(d.getMonth() + 1).padStart(2, '0');
            const dd = String(d.getDate()).padStart(2, '0');
            return `${yyyy}-${mm}-${dd}`;
        } catch (e) {
            return '';
        }
    }

    clearFieldError(field) {
        if (this.errors[field]) {
            this.errors = { ...this.errors, [field]: '' };
        }
    }

    handleSalutationChange(event) {
        this.salutation = event.target.value;
    }

    handleFirstNameChange(event) {
        this.firstName = event.target.value;
        this.clearFieldError('firstName');
    }

    handleLastNameChange(event) {
        this.lastName = event.target.value;
        this.clearFieldError('lastName');
    }

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handleMobileChange(event) {
        this.mobilePhone = event.target.value;
    }

    handleDesignationChange(event) {
        this.designation = event.target.value;
    }

    handleStatusChange(event) {
        this.status = event.target.value;
    }

    handleDobChange(event) {
        this.dob = event.target.value;
    }

    handleAnniversaryChange(event) {
        this.anniversary = event.target.value;
    }

    handleStreetChange(event) {
        this.street = event.target.value;
    }

    handleCityChange(event) {
        this.city = event.target.value;
    }

    handleStateChange(event) {
        this.state = event.target.value;
    }

    handlePostalCodeChange(event) {
        this.postalCode = event.target.value;
    }

    handleCountryChange(event) {
        this.country = event.target.value;
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
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        }
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

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleClose() {
        if (this.isSaving) {
            return;
        }
        this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
    }

    validate() {
        const next = { ...EMPTY_ERRORS };
        let valid = true;

        if (!this.firstName || !this.firstName.trim()) {
            next.firstName = 'First Name is required.';
            valid = false;
        }
        if (!this.lastName || !this.lastName.trim()) {
            next.lastName = 'Last Name is required.';
            valid = false;
        }
        if (!this.accountId) {
            next.accountId = 'Customer Name is required.';
            valid = false;
        }

        this.errors = next;
        return valid;
    }

    handleSave() {
        if (this.isSaving) {
            return;
        }
        if (!this.validate()) {
            return;
        }

        this.isSaving = true;

        const input = {
            contactId: this.contactId || null,
            salutation: this.salutation,
            firstName: this.firstName,
            lastName: this.lastName,
            email: this.email,
            mobilePhone: this.mobilePhone,
            designation: this.designation,
            status: this.status || 'Active',
            accountId: this.accountId,
            dob: this.dob || null,
            anniversary: this.anniversary || null,
            street: this.street,
            city: this.city,
            postalCode: this.postalCode,
            state: this.state,
            country: this.country,
            partnerAccountId: this.partnerAccountId
        };

        const savePromise = this.isEditMode
            ? updateContact({ input })
            : createContact({ input });

        savePromise
            .then((savedContact) => {
                this.isSaving = false;
                this.dispatchEvent(
                    new CustomEvent('save', {
                        detail: savedContact,
                        bubbles: true,
                        composed: true
                    })
                );
                this.dispatchEvent(
                    new CustomEvent('close', { bubbles: true, composed: true })
                );
            })
            .catch((error) => {
                this.isSaving = false;
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    get portalToastClass() {
        return `portal-toast portal-toast--${this.portalToastVariant || 'info'}`;
    }

    showToast(title, message, variant) {
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }
        this.portalToastTitle = title || 'Info';
        this.portalToastMessage = message || '';
        this.portalToastVariant = variant || 'info';
        this.portalToastVisible = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.portalToastTimeout = window.setTimeout(() => {
            this.portalToastVisible = false;
            this.portalToastTimeout = null;
        }, PORTAL_TOAST_DURATION_MS);
    }

    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong. Please try again.';
    }
}