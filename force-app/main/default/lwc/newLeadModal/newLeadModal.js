import { LightningElement, api, track } from 'lwc';

import createLead
    from '@salesforce/apex/NewLeadController.createLead';
import updateLead
    from '@salesforce/apex/NewLeadController.updateLead';
import getLeadSourcePicklistValues
    from '@salesforce/apex/NewLeadController.getLeadSourcePicklistValues';
import getLeadStatusPicklistValues
    from '@salesforce/apex/NewLeadController.getLeadStatusPicklistValues';
import verifyGST
    from '@salesforce/apex/CustomerController.verifyGST';
import getStateDistrictByPincode
    from '@salesforce/apex/CustomerController.getStateDistrictByPincode';

const PORTAL_TOAST_DURATION_MS = 4000;

const EMPTY_ERRORS = {
    firstName: '',
    lastName: '',
    company: '',
    status: '',
    leadSource: '',
    requirement: '',
    gstNumber: '',
    postalCode: ''
};

export default class NewLeadModal extends LightningElement {

    @api partnerAccountId;
    /** When set (has Id), modal is Edit mode and form is prefilled. Create leaves this null. */
    @api leadToEdit;

    @track leadSourceOptions = [];
    @track statusOptions = [];
    @track isSaving = false;
    @track errors = { ...EMPTY_ERRORS };
    @track gstVerified = false;
    @track gstMessage = '';
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';

    portalToastTimeout;
    editLeadId = null;
    salutation = '';
    firstName = '';
    lastName = '';
    company = '';
    title = '';
    phone = '';
    email = '';
    website = '';
    status = 'New';
    leadSource = '';
    requirement = '';
    gstNumber = '';
    street = '';
    city = '';
    state = '';
    postalCode = '';
    country = '';

    connectedCallback() {
        this._applyLeadToEdit();

        getLeadSourcePicklistValues()
            .then(data => {
                this.leadSourceOptions = data || [];
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.setTimeout(() => this._syncSelectsAndTextareas(), 0);
            })
            .catch(error => {
                console.error(error);
            });

        getLeadStatusPicklistValues()
            .then(data => {
                this.statusOptions = data && data.length ? data : ['New'];
                if (!this.editLeadId) {
                    if (!this.status) {
                        this.status = 'New';
                    }
                    if (this.statusOptions.indexOf(this.status) === -1) {
                        this.status = this.statusOptions[0];
                    }
                }
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.setTimeout(() => this._syncSelectsAndTextareas(), 0);
            })
            .catch(error => {
                console.error(error);
                this.statusOptions = ['New'];
                if (!this.editLeadId) {
                    this.status = 'New';
                }
            });
    }

    _applyLeadToEdit() {
        const lead = this.leadToEdit;
        if (!lead || !lead.Id) {
            this.editLeadId = null;
            return;
        }
        this.editLeadId = lead.Id;
        this.salutation = lead.Salutation || '';
        this.firstName = lead.FirstName || '';
        this.lastName = lead.LastName || '';
        this.company = lead.Company || '';
        this.title = lead.Title || '';
        this.phone = lead.Phone || '';
        this.email = lead.Email || '';
        this.website = lead.Website || '';
        this.status = lead.Dealer_Status__c || lead.Status || 'New';
        this.leadSource = lead.LeadSource || '';
        this.requirement = lead.Requirement__c || '';
        this.gstNumber = lead.GST_Number__c || '';
        this.street = lead.Street || '';
        this.city = lead.City || '';
        this.state = lead.State || '';
        this.postalCode = lead.PostalCode || '';
        this.country = lead.Country || '';
        if (this.gstNumber && this.gstNumber.length === 15) {
            this.gstVerified = true;
            this.gstMessage = 'GST Verified';
        }
    }

    _syncSelectsAndTextareas() {
        const setVal = (selector, value) => {
            const el = this.template.querySelector(selector);
            if (el != null && String(el.value) !== String(value || '')) {
                el.value = value == null ? '' : String(value);
            }
        };
        setVal('select[data-field="salutation"]', this.salutation);
        setVal('select[data-field="status"]', this.status);
        setVal('select[data-field="leadSource"]', this.leadSource);
        setVal('textarea[data-field="requirement"]', this.requirement);
        setVal('input[data-field="company"]', this.company);
        setVal('input[data-field="firstName"]', this.firstName);
        setVal('input[data-field="lastName"]', this.lastName);
        setVal('input[data-field="website"]', this.website);
        setVal('input[data-field="email"]', this.email);
        setVal('input[data-field="phone"]', this.phone);
        setVal('input[data-field="title"]', this.title);
        setVal('input[data-field="gstNumber"]', this.gstNumber);
        setVal('input[data-field="street"]', this.street);
        setVal('input[data-field="postalCode"]', this.postalCode);
        setVal('input[data-field="city"]', this.city);
        setVal('input[data-field="state"]', this.state);
        setVal('input[data-field="country"]', this.country);
    }

    get isEditMode() {
        return !!this.editLeadId;
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Lead' : 'New Lead';
    }

    get firstNameInputClass() {
        return this.errors.firstName ? 'form-input form-input-error' : 'form-input';
    }

    get lastNameInputClass() {
        return this.errors.lastName ? 'form-input form-input-error' : 'form-input';
    }

    get companyInputClass() {
        return this.errors.company ? 'form-input form-input-error' : 'form-input';
    }

    get statusInputClass() {
        return this.errors.status ? 'form-input form-input-error' : 'form-input';
    }

    get leadSourceInputClass() {
        return this.errors.leadSource ? 'form-input form-input-error' : 'form-input';
    }

    get requirementInputClass() {
        return this.errors.requirement
            ? 'form-textarea form-input-error'
            : 'form-textarea';
    }

    get gstNumberInputClass() {
        return this.errors.gstNumber ? 'form-input form-input-error' : 'form-input';
    }

    get postalCodeInputClass() {
        return this.errors.postalCode ? 'form-input form-input-error' : 'form-input';
    }

    get gstClass() {
        return this.gstVerified ? 'gst-success' : 'gst-error';
    }

    get statusOptionsView() {
        const current = this.status || '';
        return (this.statusOptions || []).map(opt => ({
            value: opt,
            selected: opt === current
        }));
    }

    get leadSourceOptionsView() {
        const current = this.leadSource || '';
        return (this.leadSourceOptions || []).map(opt => ({
            value: opt,
            selected: opt === current
        }));
    }

    get salutationOptionsView() {
        const current = this.salutation || '';
        const opts = ['', 'Mr.', 'Ms.', 'Mrs.', 'Dr.', 'Prof.'];
        const labels = {
            '': '--None--',
            'Mr.': 'Mr.',
            'Ms.': 'Ms.',
            'Mrs.': 'Mrs.',
            'Dr.': 'Dr.',
            'Prof.': 'Prof.'
        };
        return opts.map(v => ({
            key: v || 'none',
            value: v,
            label: labels[v],
            selected: v === current
        }));
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

    handleCompanyChange(event) {
        this.company = event.target.value;
        this.clearFieldError('company');
    }

    handleTitleChange(event) {
        this.title = event.target.value;
    }

    handlePhoneChange(event) {
        this.phone = event.target.value;
    }

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handleWebsiteChange(event) {
        this.website = event.target.value;
    }

    handleStatusChange(event) {
        this.status = event.target.value;
        this.clearFieldError('status');
    }

    handleLeadSourceChange(event) {
        this.leadSource = event.target.value;
        this.clearFieldError('leadSource');
    }

    handleRequirementChange(event) {
        this.requirement = event.target.value;
        this.clearFieldError('requirement');
    }

    async handleGstNumberChange(event) {
        const val = (event.target.value || '').trim().toUpperCase();
        this.gstNumber = val;
        this.gstVerified = false;
        this.gstMessage = '';
        this.clearFieldError('gstNumber');

        if (val.length > 0 && val.length < 15) {
            this.errors = {
                ...this.errors,
                gstNumber: 'GST Number must be exactly 15 characters.'
            };
            return;
        }

        if (val.length === 15) {
            try {
                const verified = await verifyGST({ gstNo: val });
                if (verified) {
                    this.gstVerified = true;
                    this.gstMessage = 'GST Verified';
                } else {
                    this.gstVerified = false;
                    this.gstMessage = 'GST Number is not verified';
                }
            } catch (error) {
                this.gstVerified = false;
                this.gstMessage = 'Unable to verify GST';
            }
        }
    }

    handleStreetChange(event) {
        this.street = event.target.value;
    }

    async handlePostalCodeChange(event) {
        const val = (event.target.value || '').trim();
        this.postalCode = val;
        this.clearFieldError('postalCode');

        if (val.length > 0 && val.length < 6) {
            return;
        }

        if (val.length === 6 && !/^\d{6}$/.test(val)) {
            this.city = '';
            this.state = '';
            this.errors = { ...this.errors, postalCode: 'Invalid Pincode.' };
            return;
        }

        if (val.length === 6) {
            await this.populateStateCity(val);
        } else if (!val) {
            this.city = '';
            this.state = '';
        }
    }

    async populateStateCity(pinCode) {
        try {
            const result = await getStateDistrictByPincode({ pinCode });
            if (result && result.state && result.district) {
                this.state = result.state;
                this.city = result.district;
                this.clearFieldError('postalCode');
            } else {
                this.state = '';
                this.city = '';
                this.errors = { ...this.errors, postalCode: 'Invalid Pincode.' };
            }
        } catch (error) {
            console.error(error);
            this.state = '';
            this.city = '';
            this.errors = { ...this.errors, postalCode: 'Invalid Pincode.' };
        }
    }

    handleCountryChange(event) {
        this.country = event.target.value;
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
        if (!this.company || !this.company.trim()) {
            next.company = 'Customer Name is required.';
            valid = false;
        }
        if (!this.status || !this.status.trim()) {
            next.status = 'Lead Status is required.';
            valid = false;
        }
        if (!this.leadSource || !this.leadSource.trim()) {
            next.leadSource = 'Lead Source is required.';
            valid = false;
        }
        if (!this.requirement || !this.requirement.trim()) {
            next.requirement = 'Requirement is required.';
            valid = false;
        }
        if (this.gstNumber && this.gstNumber.trim()) {
            if (this.gstNumber.trim().length !== 15) {
                next.gstNumber = 'GST Number must be exactly 15 characters.';
                valid = false;
            } else if (!this.gstVerified) {
                next.gstNumber = 'Please enter a verified GST Number.';
                valid = false;
            }
        }
        if (this.postalCode && !/^\d{6}$/.test(this.postalCode.trim())) {
            next.postalCode = 'Pin Code must be exactly 6 digits.';
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
            salutation: this.salutation,
            firstName: this.firstName,
            lastName: this.lastName,
            company: this.company,
            title: this.title,
            phone: this.phone,
            email: this.email,
            website: this.website,
            status: this.status,
            leadSource: this.leadSource,
            requirement: this.requirement,
            gstNumber: this.gstNumber,
            street: this.street,
            city: this.city,
            state: this.state,
            postalCode: this.postalCode,
            country: this.country,
            partnerAccountId: this.partnerAccountId
        };

        // Create path unchanged (createLead). Edit only uses updateLead.
        const savePromise = this.editLeadId
            ? updateLead({ input, leadId: this.editLeadId })
            : createLead({ input });

        savePromise
            .then(savedLead => {
                this.isSaving = false;
                this.dispatchEvent(
                    new CustomEvent('save', {
                        detail: {
                            lead: savedLead,
                            isEdit: !!this.editLeadId
                        },
                        bubbles: true,
                        composed: true
                    })
                );
                this.dispatchEvent(
                    new CustomEvent('close', { bubbles: true, composed: true })
                );
            })
            .catch(error => {
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