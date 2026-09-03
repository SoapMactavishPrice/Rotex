import { LightningElement, api, track } from 'lwc';

const PORTAL_TOAST_DURATION_MS = 5000;

import createQuoteWithProducts from '@salesforce/apex/QuoteController.createQuoteWithProducts';
import updateQuote from '@salesforce/apex/QuoteController.updateQuote';
import getQuoteById from '@salesforce/apex/QuoteController.getQuoteById';
import getCurrentUserName from '@salesforce/apex/QuoteController.getCurrentUserName';
import getLineItemsForQuote from '@salesforce/apex/QuoteLineItemController.getLineItemsForQuote';
import updateQuoteLineItems from '@salesforce/apex/QuoteLineItemController.updateQuoteLineItems';
import getStatusPicklistValues from '@salesforce/apex/QuoteController.getStatusPicklistValues';
import getCurrencyPicklistValues from '@salesforce/apex/QuoteController.getCurrencyPicklistValues';
import getIncoTermsPicklistValues from '@salesforce/apex/QuoteController.getIncoTermsPicklistValues';
import getPaymentTermsPicklistValues from '@salesforce/apex/QuoteController.getPaymentTermsPicklistValues';
import getValidityOfOfferPicklistValues from '@salesforce/apex/QuoteController.getValidityOfOfferPicklistValues';
import getWarrantyTermsPicklistValues from '@salesforce/apex/QuoteController.getWarrantyTermsPicklistValues';
import getYesNoPicklistValues from '@salesforce/apex/QuoteController.getYesNoPicklistValues';
import getRequestedValidityOfOfferPicklistValues from '@salesforce/apex/QuoteController.getRequestedValidityOfOfferPicklistValues';
import getRequestedWarrantyTermsPicklistValues from '@salesforce/apex/QuoteController.getRequestedWarrantyTermsPicklistValues';
import searchCustomerAccounts from '@salesforce/apex/QuoteController.searchCustomerAccounts';
import searchContactsForAccount from '@salesforce/apex/QuoteController.searchContactsForAccount';
import getMyLoginAccount from '@salesforce/apex/QuoteController.getMyLoginAccount';
import getQuoteTypePicklistValues from '@salesforce/apex/QuoteController.getQuoteTypePicklistValues';
import getQuoteRecordTypeOptions from '@salesforce/apex/QuoteController.getQuoteRecordTypeOptions';
import validateSecondaryCustomerAccount from '@salesforce/apex/QuoteController.validateSecondaryCustomerAccount';

const EMPTY_ERRORS = {
    name: '',
    accountId: '',
    quoteType: '',
    quoteRecordTypeId: '',
    contactId: ''
};

function toIsoDate(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function addDays(date, days) {
    const next = new Date(date.getTime());
    next.setDate(next.getDate() + days);
    return next;
}

function toInputDate(value) {
    if (!value) {
        return '';
    }
    return String(value).substring(0, 10);
}

export default class NewQuoteModal extends LightningElement {
    @api partnerAccountId;
    @api quoteId;
    @api discountQtyMode = false;

    createStep = 'details'; // details | products
    productStepKey = 0;
    @track isCartWide = false;
    usePartnerProducts = false;
    businessLine = '';
    /** catalogue | partner | inventory | both — set before product step */
    productMode = 'catalogue';

    @track statusOptions = [];
    @track allStatusOptions = [];
    @track quoteTypeOptions = [];
    @track quoteRecordTypeOptions = [];
    @track lineItemRows = [];
    @track currencyOptions = [];
    @track incoOptions = [];
    @track paymentOptions = [];
    @track validityOptions = [];
    @track warrantyOptions = [];
    @track yesNoOptions = [];
    @track requestedValidityOptions = [];
    @track requestedWarrantyOptions = [];
    @track accountResults = [];
    @track contactResults = [];
    @track isSaving = false;
    @track isLoadingQuote = false;
    @track errors = { ...EMPTY_ERRORS };
    @track showAccountDropdown = false;
    @track showContactDropdown = false;
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';

    ownerName = '';
    quoteNumber = '';
    name = '';
    quoteType = '';
    quoteRecordTypeId = '';
    accountId = null;
    accountName = '';
    accountSearch = '';
    quoteDate = '';
    quoteValidTill = '';
    currencyIsoCode = 'INR';
    status = 'Draft';
    loginAccountId = null;
    loginAccountName = '';

    customerReferenceNo = '';
    customerReferenceDate = '';
    requestedDeliveryDate = '';
    pbgOrBgRequired = '';
    pbgOrBgComments = '';
    ldClauseApplicable = '';
    ldClauseComments = '';

    validityOfOffer = '';
    requestedValidityOfOffer = '';
    deliveryPeriod = '';
    incoTerms = '';
    paymentTerms = '';
    prices = 'Strict net per piece and valid for order of the quantity as stated above';
    warrantyTerms = '';
    requestedWarrantyTerms = '';
    liquidateTerms = '';
    transportDetails = '';
    deliveryLocation = '';
    specialRemarks = '';

    contactId = null;
    contactName = '';
    contactSearch = '';
    phone = '';
    email = '';

    billToPartyCode = '';
    billToStreet = '';
    billToCity = '';
    billToPostalCode = '';
    billToState = '';
    billToCountry = '';

    shipToPartyCode = '';
    shipToStreet = '';
    shipToCity = '';
    shipToPostalCode = '';
    shipToState = '';
    shipToCountry = '';

    accountTimeout;
    contactTimeout;
    portalToastTimeout;

    disconnectedCallback() {
        this.hidePortalToast();
    }

    connectedCallback() {
        if (!this.isEditMode) {
            const today = new Date();
            this.quoteDate = toIsoDate(today);
            this.quoteValidTill = toIsoDate(addDays(today, 30));
        }

        if (this.discountQtyMode && this.quoteId) {
            getLineItemsForQuote({ quoteId: this.quoteId })
                .then((data) => {
                    this.lineItemRows = this.mapLineItems(data);
                })
                .catch((error) => {
                    this.lineItemRows = [];
                    this.showToast('Error', this.extractErrorMessage(error), 'error');
                });
            return;
        }

        Promise.all([
            getStatusPicklistValues(),
            getQuoteTypePicklistValues(),
            getQuoteRecordTypeOptions(),
            getCurrencyPicklistValues(),
            getIncoTermsPicklistValues(),
            getPaymentTermsPicklistValues(),
            getValidityOfOfferPicklistValues(),
            getWarrantyTermsPicklistValues(),
            getYesNoPicklistValues(),
            getRequestedValidityOfOfferPicklistValues(),
            getRequestedWarrantyTermsPicklistValues(),
            this.isEditMode ? Promise.resolve('') : getCurrentUserName(),
            this.isEditMode ? Promise.resolve(null) : getMyLoginAccount(),
            this.isEditMode && this.quoteId
                ? getQuoteById({ quoteId: this.quoteId })
                : Promise.resolve(null)
        ])
            .then(
                ([
                    status,
                    quoteTypes,
                    quoteRecordTypes,
                    currency,
                    inco,
                    payment,
                    validity,
                    warranty,
                    yesNo,
                    reqValidity,
                    reqWarranty,
                    currentUserName,
                    loginAccount,
                    quoteRecord
                ]) => {
                    this.allStatusOptions = status || [];
                    this.applyStatusOptionsForQuoteType();
                    this.quoteTypeOptions = (quoteTypes || []).filter((option) =>
                        ['Self', 'Secondary Customer'].includes(option.value)
                    );
                    this.quoteRecordTypeOptions = quoteRecordTypes || [];
                    this.currencyOptions = currency || [];
                    this.incoOptions = inco || [];
                    this.paymentOptions = payment || [];
                    this.validityOptions = validity || [];
                    this.warrantyOptions = warranty || [];
                    this.yesNoOptions = yesNo || [];
                    this.requestedValidityOptions = reqValidity || [];
                    this.requestedWarrantyOptions = reqWarranty || [];

                    if (loginAccount) {
                        this.loginAccountId = loginAccount.id;
                        this.loginAccountName = loginAccount.label || '';
                    }

                    if (this.isEditMode && quoteRecord) {
                        this.populateFromQuote(quoteRecord);
                    } else {
                        this.ownerName = currentUserName || '';
                    }
                }
            )
            .catch((error) => {
                console.error(error);
                if (this.isEditMode) {
                    this.showToast('Error', this.extractErrorMessage(error), 'error');
                }
            });
    }

    mapLineItems(data) {
        return (data || []).map((item) => ({
            id: item.id,
            lineItemNumber: item.lineItemNumber || '—',
            productName: item.productName || '—',
            quantity: item.quantity ?? '',
            requestedDiscount: item.requestedDiscount ?? '',
            discountToBeOffered: item.discountToBeOffered ?? ''
        }));
    }

    get isEditMode() {
        return !!this.quoteId;
    }

    get modalTitle() {
        if (this.discountQtyMode) {
            return 'Edit Discount & Qty';
        }
        if (!this.isEditMode && this.createStep === 'products') {
            return this.isCartWide ? 'Edit Selected Products' : 'Add Products';
        }
        return this.isEditMode ? 'Edit Quote' : 'New Quote';
    }

    get showModalTitle() {
        return !!this.modalTitle;
    }

    get quoteModalContainerClass() {
        const classes = ['modal-container'];
        if (this.isCartWide) {
            classes.push('modal-container--cart');
        } else if (this.showCreateProducts) {
            classes.push('modal-container--products');
        }
        if (!this.showModalTitle) {
            classes.push('modal-container--no-title');
        }
        return classes.join(' ');
    }

    get showQuoteForm() {
        return !this.discountQtyMode && this.isEditMode;
    }

    get showCreateQuoteForm() {
        return !this.discountQtyMode && !this.isEditMode && this.createStep === 'details';
    }

    get showCreateProducts() {
        return !this.discountQtyMode && !this.isEditMode && this.createStep === 'products';
    }

    get showCreateNextButton() {
        return this.showCreateQuoteForm;
    }

    get showEditSaveButton() {
        return this.isEditMode || this.discountQtyMode;
    }

    get createModeFlag() {
        return true;
    }

    get embeddedFlag() {
        return true;
    }

    get isSelfQuoteType() {
        return this.quoteType === 'Self';
    }

    get isSecondaryCustomerQuoteType() {
        return this.quoteType === 'Secondary Customer';
    }

    get showQuoteRecordTypeField() {
        return this.isSecondaryCustomerQuoteType;
    }

    get quoteRecordTypeInputClass() {
        return this.errors.quoteRecordTypeId ? 'form-input form-input-error' : 'form-input';
    }

    get selectedQuoteRecordTypeName() {
        const id = this.quoteRecordTypeId;
        if (!id) {
            return '';
        }
        const opt = (this.quoteRecordTypeOptions || []).find((o) => o.value === id);
        return opt?.label || '';
    }

    applyStatusOptionsForQuoteType() {
        const selfExcluded = ['Under Review by Sales Rep', 'Submitted to Customer'];
        const secondaryExcluded = ['Under Review by Sales Rep', 'Submit for SOA Approval'];
        const all = this.allStatusOptions || [];

        let excluded = [];
        if (this.isSelfQuoteType) {
            excluded = selfExcluded;
        } else if (this.isSecondaryCustomerQuoteType) {
            excluded = secondaryExcluded;
        }

        if (excluded.length > 0) {
            let options = all.filter(
                (opt) => !excluded.includes(opt.value) && !excluded.includes(opt.label)
            );
            if (
                this.status &&
                excluded.includes(this.status) &&
                !options.some((opt) => opt.value === this.status)
            ) {
                options = [{ label: this.status, value: this.status }, ...options];
            } else if (!this.isEditMode && excluded.includes(this.status)) {
                this.status = 'Draft';
            }
            this.statusOptions = options;
        } else {
            this.statusOptions = all;
        }
    }

    get isAccountLookupDisabled() {
        return !this.isSecondaryCustomerQuoteType;
    }

    get isContactLookupDisabled() {
        return !this.accountId;
    }

    get contactPlaceholder() {
        return this.accountId
            ? 'Search contacts for selected Customer...'
            : 'Select Customer Name first...';
    }

    get contactLabelClass() {
        return this.isSecondaryCustomerQuoteType
            ? 'form-label form-required'
            : 'form-label';
    }

    get contactInputClass() {
        return this.errors.contactId ? 'form-input form-input-error' : 'form-input';
    }

    get quoteTypeInputClass() {
        return this.errors.quoteType ? 'form-input form-input-error' : 'form-input';
    }

    get portalToastClass() {
        return `portal-toast portal-toast--${this.portalToastVariant || 'info'}`;
    }

    get hasLineItemRows() {
        return this.lineItemRows && this.lineItemRows.length > 0;
    }

    handleLineItemChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.lineItemRows = this.lineItemRows.map((row) => {
            if (row.id !== id) {
                return row;
            }
            return { ...row, [field]: value };
        });
    }

    get quoteNumberDisplay() {
        return this.quoteNumber || 'Auto-generated';
    }

    get quoteTypeDisplay() {
        if (!this.quoteType) {
            return '';
        }
        const match = (this.quoteTypeOptions || []).find((opt) => opt.value === this.quoteType);
        return match?.label || this.quoteType;
    }

    get currencyDisplay() {
        if (!this.currencyIsoCode) {
            return '';
        }
        const match = (this.currencyOptions || []).find((opt) => opt.value === this.currencyIsoCode);
        return match?.label || this.currencyIsoCode;
    }

    get customerPoInputClass() {
        return this.isEditMode ? 'form-input form-input-readonly' : 'form-input';
    }

    get additionalInfoTextareaClass() {
        return this.isEditMode
            ? 'form-input form-textarea form-input-readonly'
            : 'form-input form-textarea';
    }

    get addressInputClass() {
        return this.isEditMode ? 'form-input form-input-readonly' : 'form-input';
    }

    populateFromQuote(q) {
        this.quoteNumber = q.QuoteNumber || '';
        this.name = q.Name || '';
        this.accountId = q.QuoteAccountId || q.Account__c || q.AccountId || null;
        this.accountName = q.QuoteAccount?.Name || q.Account__r?.Name || q.Account?.Name || '';
        this.quoteDate = toInputDate(q.Quote_Date__c);
        this.quoteValidTill = toInputDate(q.Quote_Valid_Till__c);
        this.currencyIsoCode = q.CurrencyIsoCode || 'INR';
        this.quoteType = q.Quote_Type__c || '';
        this.applyStatusOptionsForQuoteType();
        this.status = q.Status || 'Draft';
        this.applyStatusOptionsForQuoteType();
        this.ownerName = this.formatOwnerName(q.Owner);

        this.customerReferenceNo = q.Customer_Reference_No__c || '';
        this.customerReferenceDate = toInputDate(q.Customer_Reference_Date__c);
        this.requestedDeliveryDate = toInputDate(q.RequestedDeliveryDate__c);
        this.pbgOrBgRequired = q.PBG_or_BG_required__c || '';
        this.pbgOrBgComments = q.PBG_or_BG_comments__c || '';
        this.ldClauseApplicable = q.LD_Clause_Applicable__c || '';
        this.ldClauseComments = q.LD_Clause_comments__c || '';

        this.validityOfOffer = q.Validity_of_Offer__c || '';
        this.requestedValidityOfOffer = q.Requested_Validity_Of_Offer__c || '';
        this.deliveryPeriod = q.Delivery_Period__c || '';
        this.incoTerms = q.INCO_Terms__c || '';
        this.paymentTerms = q.Payment_Terms__c || '';
        this.prices = q.Prices__c || '';
        this.warrantyTerms = q.Warranty_Terms__c || '';
        this.requestedWarrantyTerms = q.Warranty_Terms_Draft__c || '';
        this.liquidateTerms = q.Liquidate_Terms__c || '';
        this.transportDetails = q.Transport_Details__c || '';
        this.deliveryLocation = q.Delivery_Location__c || '';
        this.specialRemarks = q.Special_Remarks__c || '';

        this.contactId = q.ContactId || null;
        this.contactName = q.Contact?.Name || '';
        this.phone = q.Phone || '';
        this.email = q.Email || '';

        this.billToPartyCode = q.Bill_To_Party_Code__c || '';
        this.billToStreet = q.Bill_To_Street__c || '';
        this.billToCity = q.Bill_To_City__c || '';
        this.billToPostalCode = q.Bill_To_Postal_Code__c || '';
        this.billToState = q.Bill_To_State__c || '';
        this.billToCountry = q.Bill_To_Country__c || '';

        this.shipToPartyCode = q.Ship_To_Party_Code__c || '';
        this.shipToStreet = q.Ship_To_Street__c || '';
        this.shipToCity = q.Ship_To_City__c || '';
        this.shipToPostalCode = q.Ship_To_Postal_Code__c || '';
        this.shipToState = q.Ship_To_State__c || '';
        this.shipToCountry = q.Ship_To_Country__c || '';
    }

    formatOwnerName(owner) {
        if (!owner) {
            return '';
        }
        const firstLast = [owner.FirstName, owner.LastName]
            .filter((part) => part && String(part).trim())
            .join(' ')
            .trim();
        if (firstLast) {
            return firstLast;
        }
        return owner.Name || '';
    }

    get hasSelectedAccount() {
        return !!this.accountId;
    }

    get hasSelectedContact() {
        return !!this.contactId;
    }

    get hasAccountResults() {
        return this.accountResults && this.accountResults.length > 0;
    }

    get hasContactResults() {
        return this.contactResults && this.contactResults.length > 0;
    }

    get nameInputClass() {
        return this.errors.name ? 'form-input form-input-error' : 'form-input';
    }

    get accountInputClass() {
        return this.errors.accountId ? 'form-input form-input-error' : 'form-input';
    }

    get showPbgComments() {
        return this.pbgOrBgRequired === 'Yes';
    }

    get showLdComments() {
        return this.ldClauseApplicable === 'Yes';
    }

    clearFieldError(field) {
        if (this.errors[field]) {
            this.errors = { ...this.errors, [field]: '' };
        }
    }

    handleQuoteTypeChange(event) {
        this.quoteType = event.target.value;
        this.clearFieldError('quoteType');
        this.clearFieldError('accountId');
        this.clearFieldError('quoteRecordTypeId');
        this.applyStatusOptionsForQuoteType();

        if (this.quoteType !== 'Secondary Customer') {
            this.quoteRecordTypeId = '';
        }

        if (this.quoteType === 'Self') {
            this.accountId = this.loginAccountId || this.partnerAccountId || null;
            this.accountName = this.loginAccountName || '';
            this.accountSearch = '';
            this.accountResults = [];
            this.showAccountDropdown = false;
            if (!this.accountId && this.partnerAccountId) {
                this.accountId = this.partnerAccountId;
            }
            if (!this.accountName && this.loginAccountName) {
                this.accountName = this.loginAccountName;
            }
            this.usePartnerProducts = false;
            this.businessLine = '';
            this.productMode = 'catalogue';
            this.clearContact();
            if (this.accountId) {
                this.runContactSearch('');
            }
            return;
        }

        // Secondary Customer or cleared — reset account so user can pick a connecting customer
        this.accountId = null;
        this.accountName = '';
        this.accountSearch = '';
        this.accountResults = [];
        this.showAccountDropdown = false;
        this.usePartnerProducts = false;
        this.businessLine = '';
        this.productMode = 'catalogue';
        this.clearContact();
    }

    handleQuoteRecordTypeChange(event) {
        this.quoteRecordTypeId = event.target.value;
        this.clearFieldError('quoteRecordTypeId');
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        this[field] = event.target.value;
        if (field === 'name') {
            this.clearFieldError('name');
        }
        if (field === 'pbgOrBgRequired' && this.pbgOrBgRequired !== 'Yes') {
            this.pbgOrBgComments = '';
        }
        if (field === 'ldClauseApplicable' && this.ldClauseApplicable !== 'Yes') {
            this.ldClauseComments = '';
        }
    }

    handleAccountFocus() {
        if (!this.isSecondaryCustomerQuoteType) {
            this.showToast('Select Quote for', 'Select Secondary Customer to search connecting customers.', 'info');
            return;
        }
        this.showAccountDropdown = true;
        this.runAccountSearch(this.accountSearch || '');
    }

    handleAccountSearch(event) {
        if (!this.isSecondaryCustomerQuoteType) {
            return;
        }
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
        this.clearContact();
        this.runContactSearch('');
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
        this.clearContact();
    }

    handleContactFocus() {
        if (!this.accountId) {
            this.showToast('Select Customer', 'Please select Customer Name first.', 'info');
            return;
        }
        this.showContactDropdown = true;
        this.runContactSearch(this.contactSearch || '');
    }

    handleContactSearch(event) {
        this.contactSearch = event.target.value;
        this.showContactDropdown = true;
        window.clearTimeout(this.contactTimeout);
        this.contactTimeout = window.setTimeout(() => {
            this.runContactSearch(this.contactSearch);
        }, 200);
    }

    async runContactSearch(term) {
        if (!this.accountId) {
            this.contactResults = [];
            return;
        }
        try {
            const data = await searchContactsForAccount({
                searchText: term || '',
                accountId: this.accountId,
                partnerAccountId: this.partnerAccountId || null
            });
            this.contactResults = data || [];
            this.showContactDropdown = true;
        } catch (error) {
            this.contactResults = [];
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        }
    }

    selectContact(event) {
        event.preventDefault();
        this.contactId = event.currentTarget.dataset.id;
        this.contactName = event.currentTarget.dataset.label;
        this.email = event.currentTarget.dataset.email || '';
        this.phone = event.currentTarget.dataset.phone || '';
        this.contactSearch = '';
        this.contactResults = [];
        this.showContactDropdown = false;
        this.clearFieldError('contactId');
    }

    clearContact(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.contactId = null;
        this.contactName = '';
        this.contactSearch = '';
        this.contactResults = [];
        this.phone = '';
        this.email = '';
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    validate() {
        const next = { ...EMPTY_ERRORS };
        let valid = true;

        if (!this.quoteType) {
            next.quoteType = 'Quote for is required.';
            valid = false;
        }
        if (this.isSecondaryCustomerQuoteType && !this.quoteRecordTypeId) {
            next.quoteRecordTypeId = 'Quote Type is required.';
            valid = false;
        }
        if (!this.accountId) {
            next.accountId = 'Customer Name is required.';
            valid = false;
        }
        if (this.isSecondaryCustomerQuoteType && !this.contactId) {
            next.contactId = 'Contact Name is required.';
            valid = false;
        }

        this.errors = next;
        return valid;
    }

    handleNext() {
        if (this.isSaving) {
            return;
        }
        if (!this.validate()) {
            return;
        }

        if (this.isSecondaryCustomerQuoteType) {
            this.isSaving = true;
            validateSecondaryCustomerAccount({ accountId: this.accountId })
                .then((result) => {
                    this.isSaving = false;
                    if (!result || result.ok !== true) {
                        const message = result?.message || 'Secondary customer validation failed.';
                        this.showToast('Cannot proceed', message, 'error');
                        return;
                    }
                    this.businessLine = result.businessLine || '';
                    const normalizedBl = String(this.businessLine)
                        .trim()
                        .toUpperCase()
                        .replace(/[-_]+/g, ' ')
                        .replace(/\s+/g, ' ');
                    const arcRt = String(this.selectedQuoteRecordTypeName || '')
                        .trim()
                        .toUpperCase()
                        .replace(/[-_]+/g, ' ')
                        .replace(/\s+/g, ' ');
                    const isArcQuoteType = arcRt === 'ARC' || arcRt.includes('ARC');
                    this.usePartnerProducts =
                        result.usePartnerProducts === true || normalizedBl === 'NON ROTEX';
                    // Secondary ARC: Rotex catalogue only (Item Type + Search). Normal / Self unchanged.
                    if (isArcQuoteType) {
                        this.productMode = 'catalogue';
                        this.usePartnerProducts = false;
                    } else if (this.usePartnerProducts || normalizedBl === 'NON ROTEX') {
                        this.productMode = 'partner';
                    } else if (normalizedBl === 'ROTEX') {
                        // Same full catalogue as Self (not inventory-only)
                        this.productMode = 'catalogue';
                    } else if (normalizedBl === 'BOTH') {
                        this.productMode = 'both';
                    } else {
                        this.productMode = 'catalogue';
                    }
                    this.goToProductsStep();
                })
                .catch((error) => {
                    this.isSaving = false;
                    const message = this.extractErrorMessage(error);
                    this.showToast('Cannot proceed', message, 'error');
                });
            return;
        }

        // Self — always catalogue (never inventory / partner products)
        this.businessLine = '';
        this.usePartnerProducts = false;
        this.productMode = 'catalogue';
        this.goToProductsStep();
    }

    goToProductsStep() {
        // Stay UI-only until final Save — no Opportunity/Quote draft yet
        this.createStep = 'products';
        this.productStepKey = Date.now();
        this.setModalLayout('products');
    }

    handleProductStepBack() {
        this.createStep = 'details';
        this.setModalLayout('default');
    }

    handleCartViewChange(event) {
        const isCart = !!event?.detail?.isCart;
        this.setModalLayout(isCart ? 'cart' : 'products');
    }

    setCartWide(isCart) {
        if (isCart) {
            this.setModalLayout('cart');
        } else if (this.createStep === 'products') {
            this.setModalLayout('products');
        } else {
            this.setModalLayout('default');
        }
    }

    setModalLayout(layout) {
        this.isCartWide = layout === 'cart';
        this.dispatchEvent(
            new CustomEvent('cartviewchange', {
                detail: { layout, isCart: layout === 'cart' },
                bubbles: true,
                composed: true
            })
        );
    }

    handleCreateProductsSave(event) {
        if (this.isSaving) {
            return;
        }

        const products = event?.detail?.products || [];
        const customerSAPdiscount = event?.detail?.customerSAPdiscount;
        const usePartnerProducts = event?.detail?.usePartnerProducts === true;
        if (!products.length) {
            this.showToast('Error', 'Please add at least one product.', 'error');
            return;
        }

        this.isSaving = true;
        const input = {
            name: this.name,
            accountId: this.accountId,
            quoteType: this.quoteType,
            recordTypeId: this.isSecondaryCustomerQuoteType ? this.quoteRecordTypeId || null : null,
            quoteDate: this.quoteDate || null,
            quoteValidTill: this.quoteValidTill || null,
            currencyIsoCode: this.currencyIsoCode || 'INR',
            status: 'Draft',
            contactId: this.contactId || null,
            email: this.email || null,
            phone: this.phone || null,
            prices: this.prices || null,
            partnerAccountId: this.partnerAccountId,
            usePartnerProducts
        };

        createQuoteWithProducts({
            input,
            recordData: JSON.stringify(products),
            customerSAPdiscount
        })
            .then((saved) => {
                this.isSaving = false;
                this.dispatchEvent(
                    new CustomEvent('save', {
                        detail: {
                            quote: saved,
                            created: true,
                            quoteNumber: saved?.QuoteNumber || '',
                            quoteName: saved?.Name || ''
                        },
                        bubbles: true,
                        composed: true
                    })
                );
                this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
            })
            .catch((error) => {
                this.isSaving = false;
                const productModal = this.template.querySelector('c-dealer-add-product-modal');
                if (productModal && typeof productModal.clearDraftSaving === 'function') {
                    productModal.clearDraftSaving();
                }
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    handleClose() {
        if (this.isSaving) {
            return;
        }
        this.setModalLayout('default');
        this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
    }

    handleSave() {
        if (this.isSaving) {
            return;
        }

        if (this.discountQtyMode) {
            this.saveLineItems();
            return;
        }

        if (!this.isEditMode) {
            this.handleNext();
            return;
        }

        if (!this.validate()) {
            return;
        }

        this.isSaving = true;

        const input = {
            quoteId: this.quoteId || null,
            name: this.name,
            accountId: this.accountId,
            quoteType: this.quoteType,
            quoteDate: this.quoteDate || null,
            quoteValidTill: this.quoteValidTill || null,
            currencyIsoCode: this.currencyIsoCode,
            status: this.status,
            customerReferenceNo: this.customerReferenceNo,
            customerReferenceDate: this.customerReferenceDate || null,
            requestedDeliveryDate: this.requestedDeliveryDate || null,
            pbgOrBgRequired: this.pbgOrBgRequired,
            pbgOrBgComments: this.pbgOrBgComments,
            ldClauseApplicable: this.ldClauseApplicable,
            ldClauseComments: this.ldClauseComments,
            validityOfOffer: this.validityOfOffer,
            requestedValidityOfOffer: this.requestedValidityOfOffer,
            deliveryPeriod: this.deliveryPeriod,
            incoTerms: this.incoTerms,
            paymentTerms: this.paymentTerms,
            prices: this.prices,
            warrantyTerms: this.warrantyTerms,
            requestedWarrantyTerms: this.requestedWarrantyTerms,
            liquidateTerms: this.liquidateTerms,
            transportDetails: this.transportDetails,
            deliveryLocation: this.deliveryLocation,
            specialRemarks: this.specialRemarks,
            contactId: this.contactId,
            phone: this.phone,
            email: this.email,
            billToPartyCode: this.billToPartyCode,
            billToStreet: this.billToStreet,
            billToCity: this.billToCity,
            billToPostalCode: this.billToPostalCode,
            billToState: this.billToState,
            billToCountry: this.billToCountry,
            shipToPartyCode: this.shipToPartyCode,
            shipToStreet: this.shipToStreet,
            shipToCity: this.shipToCity,
            shipToPostalCode: this.shipToPostalCode,
            shipToState: this.shipToState,
            shipToCountry: this.shipToCountry,
            partnerAccountId: this.partnerAccountId
        };

        updateQuote({ input })
            .then((saved) => {
                this.isSaving = false;
                this.showToast('Success', 'Quote updated successfully.', 'success');
                this.dispatchEvent(
                    new CustomEvent('save', {
                        detail: saved,
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

    saveLineItems() {
        if (!this.hasLineItemRows) {
            this.showToast('Error', 'No quote line items found.', 'error');
            return;
        }

        this.isSaving = true;
        const items = this.lineItemRows.map((row) => ({
            id: row.id,
            quantity: row.quantity === '' || row.quantity === null ? null : Number(row.quantity),
            requestedDiscount:
                row.requestedDiscount === '' || row.requestedDiscount === null
                    ? null
                    : Number(row.requestedDiscount),
            discountToBeOffered:
                row.discountToBeOffered === '' || row.discountToBeOffered === null
                    ? null
                    : Number(row.discountToBeOffered)
        }));

        updateQuoteLineItems({ items })
            .then(() => {
                this.isSaving = false;
                this.showToast('Success', 'Line items updated successfully.', 'success');
                this.dispatchEvent(
                    new CustomEvent('save', {
                        bubbles: true,
                        composed: true
                    })
                );
                this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
            })
            .catch((error) => {
                this.isSaving = false;
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    hidePortalToast() {
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
            this.portalToastTimeout = null;
        }
        this.portalToastVisible = false;
    }

    showToast(title, message, variant) {
        const safeVariant = variant || 'info';
        const safeTitle = title || 'Info';
        const safeMessage = message || '';

        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }

        this.portalToastTitle = safeTitle;
        this.portalToastMessage = safeMessage;
        this.portalToastVariant = safeVariant;
        this.portalToastVisible = true;

        this.portalToastTimeout = window.setTimeout(() => {
            this.portalToastVisible = false;
            this.portalToastTimeout = null;
        }, PORTAL_TOAST_DURATION_MS);
    }

    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.body?.output?.errors?.length) {
            return error.body.output.errors[0].message;
        }
        if (error?.body?.pageErrors?.length) {
            return error.body.pageErrors[0].message;
        }
        if (Array.isArray(error?.body) && error.body.length) {
            return error.body[0].message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong. Please try again.';
    }
}