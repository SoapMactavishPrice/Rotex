import { LightningElement, api, track } from 'lwc';
import getQuoteAndLineItems from '@salesforce/apex/DealerEditArcDiscountController.getQuoteAndLineItems';
import updateQuoteAndLineItems from '@salesforce/apex/DealerEditArcDiscountController.updateQuoteAndLineItems';
import getPaymentTermsOptions from '@salesforce/apex/DealerEditArcDiscountController.getPaymentTermsOptions';
import getWarrantyOptions from '@salesforce/apex/DealerEditArcDiscountController.getWarrantyOptions';
import getIncoTermsOptions from '@salesforce/apex/DealerEditArcDiscountController.getIncoTermsOptions';
import getQuoteHeader from '@salesforce/apex/DealerEditDiscountQuantityController.getQuoteHeader';
import updateQuoteHeaderFields from '@salesforce/apex/DealerEditDiscountQuantityController.updateQuoteHeaderFields';
import getRequestedValidityOfOfferPicklistValues from '@salesforce/apex/QuoteController.getRequestedValidityOfOfferPicklistValues';
import getRequestedWarrantyTermsPicklistValues from '@salesforce/apex/QuoteController.getRequestedWarrantyTermsPicklistValues';
import searchContactsForAccount from '@salesforce/apex/QuoteController.searchContactsForAccount';

function toInputDate(value) {
    if (!value) {
        return '';
    }
    return String(value).substring(0, 10);
}

function formatNumber(value, digits) {
    if (value == null || value === '') {
        return '';
    }
    const n = Number(value);
    if (!Number.isFinite(n)) {
        return '';
    }
    return n.toFixed(digits);
}

/** Payment Terms allowed on ARC Discount Approval (exact picklist values). */
const ARC_PAYMENT_TERMS_VALUES = [
    'No Credit',
    'Credit against security upto 30 days',
    'Open Credit upto 15 days',
    'Open Credit upto 30 days',
    'Open Credit upto 180 days',
    'D010 D010 D010'
];

function filterArcPaymentTermsOptions(options) {
    const list = options || [];
    const allowed = new Set(ARC_PAYMENT_TERMS_VALUES.map((v) => v.toLowerCase()));
    const filtered = list.filter(
        (opt) => allowed.has(String(opt.value || '').trim().toLowerCase()) ||
            allowed.has(String(opt.label || '').trim().toLowerCase())
    );
    // Preserve ARC order from allowlist
    return ARC_PAYMENT_TERMS_VALUES.map((value) => {
        const found = filtered.find(
            (opt) =>
                String(opt.value || '').trim().toLowerCase() === value.toLowerCase() ||
                String(opt.label || '').trim().toLowerCase() === value.toLowerCase()
        );
        return found || { label: value, value };
    });
}

export default class DealerEditArcDiscountModal extends LightningElement {
    @api quoteId;
    @api partnerAccountId;

    @track showSpinner = false;
    @track showConfirmSubmit = false;
    @track isSubmitting = false;
    @track hasConfirmedSubmit = false;
    @track headerReady = false;
    @track quoteLineItemList = [];
    @track currencyCode = '';

    @track requestedValidityOptions = [];
    @track requestedWarrantyOptions = [];
    @track paymentTermsOptions = [];
    @track warrantyOptions = [];
    @track incoTermsOptions = [];
    @track contactResults = [];
    @track showContactDropdown = false;

    quoteNumber = '';
    quoteName = '';
    accountName = '';
    accountId = null;
    quoteDate = '';
    quoteValidTill = '';
    ownerName = '';
    currencyIsoCode = '';
    status = '';
    revNo = '';
    revDate = '';

    validityOfOffer = '';
    requestedValidityOfOffer = '';
    deliveryPeriod = '';
    incoTerms = '';
    paymentTerms = '';
    prices = '';
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

    @track errors = {
        deliveryPeriod: '',
        liquidateTerms: ''
    };

    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'success';
    portalToastTimeout;
    contactTimeout;

    connectedCallback() {
        this.bootstrap();
    }

    disconnectedCallback() {
        window.clearTimeout(this.contactTimeout);
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }
    }

    get proposedArcPriceColumnLabel() {
        const currency = this.currencyCode || this.currencyIsoCode || '';
        return currency
            ? `Proposed ARC Price (${currency})`
            : 'Proposed ARC Price';
    }

    get warrantySelectValue() {
        return this.requestedWarrantyTerms || this.warrantyTerms || '';
    }

    get hasNoLines() {
        return !this.showSpinner && this.quoteLineItemList.length === 0;
    }

    get portalToastClass() {
        return `portal-toast portal-toast--${this.portalToastVariant}`;
    }

    get isActionDisabled() {
        return (
            this.showSpinner ||
            this.isSubmitting ||
            this.hasConfirmedSubmit ||
            this.showConfirmSubmit
        );
    }

    get isConfirmDisabled() {
        return this.isSubmitting || this.hasConfirmedSubmit;
    }

    get showFooterActions() {
        const status = String(this.status || '')
            .trim()
            .toLowerCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        const isDraft = !status || status === 'draft';
        return isDraft && !this.hasConfirmedSubmit && !this.isSubmitting && !this.showConfirmSubmit;
    }

    get hasSelectedContact() {
        return !!this.contactId;
    }

    get hasContactResults() {
        return this.contactResults && this.contactResults.length > 0;
    }

    get requestedValidityOptionsView() {
        return (this.requestedValidityOptions || []).map((opt) => ({
            ...opt,
            selected: opt.value === this.requestedValidityOfOffer
        }));
    }

    get requestedWarrantyOptionsView() {
        return (this.requestedWarrantyOptions || []).map((opt) => ({
            ...opt,
            selected: opt.value === this.requestedWarrantyTerms
        }));
    }

    get paymentTermsOptionsView() {
        return (this.paymentTermsOptions || []).map((opt) => ({
            ...opt,
            selected: opt.value === this.paymentTerms
        }));
    }

    get warrantyTermsOptionsView() {
        const selected = this.warrantySelectValue;
        return (this.warrantyOptions || []).map((opt) => ({
            ...opt,
            selected: opt.value === selected
        }));
    }

    get incoTermsOptionsView() {
        return (this.incoTermsOptions || []).map((opt) => ({
            ...opt,
            selected: opt.value === this.incoTerms
        }));
    }

    async bootstrap() {
        this.showSpinner = true;
        try {
            await Promise.all([this.loadHeaderAndPicklists(), this.loadLineItems()]);
        } catch (e) {
            this.showToast('Error', this.reduceError(e), 'error');
        } finally {
            this.showSpinner = false;
        }
    }

    async loadHeaderAndPicklists() {
        const [quote, reqValidity, reqWarranty, payment, warranty, inco] = await Promise.all([
            getQuoteHeader({ quoteId: this.quoteId }),
            getRequestedValidityOfOfferPicklistValues(),
            getRequestedWarrantyTermsPicklistValues(),
            getPaymentTermsOptions(),
            getWarrantyOptions(),
            getIncoTermsOptions()
        ]);
        this.requestedValidityOptions = reqValidity || [];
        this.requestedWarrantyOptions = reqWarranty || [];
        this.paymentTermsOptions = filterArcPaymentTermsOptions(payment || []);
        this.warrantyOptions = warranty || [];
        this.incoTermsOptions = inco || [];
        if (quote) {
            this.populateHeaderFromQuote(quote);
        }
        this.headerReady = true;
    }

    populateHeaderFromQuote(q) {
        this.quoteNumber = q.QuoteNumber || '';
        this.quoteName = q.Name || '';
        this.accountId = q.QuoteAccountId || q.Account__c || q.AccountId || null;
        this.accountName = q.QuoteAccount?.Name || q.Account__r?.Name || q.Account?.Name || '';
        this.quoteDate = toInputDate(q.Quote_Date__c);
        this.quoteValidTill = toInputDate(q.Quote_Valid_Till__c);
        this.ownerName = this.formatOwnerName(q);
        this.currencyIsoCode = q.CurrencyIsoCode || '';
        this.currencyCode = q.CurrencyIsoCode || this.currencyCode || '';
        this.status = q.Status || '';
        this.revNo = q.Rev_No__c != null ? String(q.Rev_No__c) : '';
        this.revDate = toInputDate(q.Rev_Date__c);

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
    }

    formatOwnerName(q) {
        return this.formatUserName(q?.CP_Owner_Name__r) || this.formatUserName(q?.Owner) || '';
    }

    formatUserName(user) {
        if (!user) {
            return '';
        }
        const firstLast = [user.FirstName, user.LastName]
            .filter((part) => part && String(part).trim())
            .join(' ')
            .trim();
        if (firstLast) {
            return firstLast;
        }
        return user.Name || '';
    }

    async loadLineItems() {
        if (!this.quoteId) {
            throw new Error('Invalid Quote Id');
        }
        const result = await getQuoteAndLineItems({ qId: this.quoteId });
        const quoteRecord = result?.quoteRecord || {};
        if (!this.currencyCode) {
            this.currencyCode = quoteRecord.CurrencyIsoCode || '';
        }

        const existingArcPrices = result?.existingArcPrices || {};
        this.quoteLineItemList = (result?.lineItems || []).map((item) => {
            const isApproved = item.Is_Discount_Approved__c === true;
            const productCode = item.Product2?.ProductCode || '';
            const existingArcPrice =
                productCode && existingArcPrices[productCode] != null
                    ? existingArcPrices[productCode]
                    : null;

            if (isApproved) {
                return {
                    ...item,
                    productCode,
                    productName: item.Product2?.Name || '',
                    Customer_Part_No__c: item.Customer_Part_No__c || '',
                    UnitPrice: 0,
                    Requested_Comments__c: item.Requested_Comments__c || '',
                    existingArcPrice,
                    existingArcPriceDisplay: existingArcPrice == null ? '' : existingArcPrice,
                    desiredPriceValue:
                        item.Sell_Price_of_Sc__c != null && item.Sell_Price_of_Sc__c !== ''
                            ? item.Sell_Price_of_Sc__c
                            : this.computeDesiredPrice(
                                  item.ListPrice,
                                  item.Discount_to_be_offered__c
                              ) || 0,
                    newDesiredPriceValue:
                        item.Sell_Price_of_Sc__c != null && item.Sell_Price_of_Sc__c !== ''
                            ? item.Sell_Price_of_Sc__c
                            : this.computeDesiredPrice(
                                  item.ListPrice,
                                  item.Discount_to_be_offered__c
                              ) || 0,
                    newDiscountValue: item.Discount_to_be_offered__c,
                    newDiscountDisplay: formatNumber(item.Discount_to_be_offered__c, 3) || '0',
                    discountDisplay: formatNumber(item.Discount_to_be_offered__c, 3) || '0',
                    Valid_from__c: toInputDate(item.Valid_from__c),
                    Valid_Till__c: toInputDate(item.Valid_Till__c),
                    isProposedPriceDisabled: false,
                    isNewProposedPriceDisabled: false,
                    isRequestedCommentsDisabled: this.computeRequestedCommentsDisabled(item, null),
                    requestedCommentsPlaceholder: 'Enter comments...'
                };
            }

            const discountIsZero = item.Discount_to_be_offered__c === 0;
            const hasExistingDiscount =
                this.hasDiscountOfferedValue(item.Discount_to_be_offered__c) && !discountIsZero;
            return {
                ...item,
                productCode,
                productName: item.Product2?.Name || '',
                Customer_Part_No__c: item.Customer_Part_No__c || '',
                UnitPrice: 0,
                Requested_Comments__c: item.Requested_Comments__c || '',
                existingArcPrice,
                existingArcPriceDisplay: existingArcPrice == null ? '' : existingArcPrice,
                newDesiredPriceValue: null,
                newDiscountValue: null,
                newDiscountDisplay: '',
                desiredPriceValue:
                    item.Sell_Price_of_Sc__c != null && item.Sell_Price_of_Sc__c !== ''
                        ? item.Sell_Price_of_Sc__c
                        : hasExistingDiscount
                          ? this.computeDesiredPrice(
                                item.ListPrice,
                                item.Discount_to_be_offered__c
                            )
                          : 0,
                discountDisplay: formatNumber(item.Discount_to_be_offered__c, 3) || '0',
                Valid_from__c: toInputDate(item.Valid_from__c),
                Valid_Till__c: toInputDate(item.Valid_Till__c),
                isProposedPriceDisabled: false,
                isNewProposedPriceDisabled: false,
                isRequestedCommentsDisabled: this.computeRequestedCommentsDisabled(item, null),
                requestedCommentsPlaceholder: 'Enter comments...'
            };
        });
    }

    computeDesiredPrice(listPrice, discountPct) {
        if (listPrice == null || discountPct == null || discountPct === '') {
            return null;
        }
        return parseFloat((listPrice * (1 - parseFloat(discountPct) / 100)).toFixed(4));
    }

    computeDiscountFromDesiredPrice(listPrice, desiredPrice) {
        if (listPrice == null || listPrice === 0 || desiredPrice == null || desiredPrice === '') {
            return null;
        }
        const raw = ((listPrice - parseFloat(desiredPrice)) / listPrice) * 100;
        return this.roundTo3Decimals(raw);
    }

    roundTo3Decimals(value) {
        if (value == null) {
            return null;
        }
        return parseFloat(parseFloat(value).toFixed(3));
    }

    hasDiscountOfferedValue(val) {
        return val != null && val !== '';
    }

    computeRequestedCommentsDisabled(item, overrideNewDiscount) {
        const newDiscount =
            overrideNewDiscount !== undefined ? overrideNewDiscount : item.newDiscountValue;
        const hasDiscountOffered =
            item.Discount_to_be_offered__c != null && item.Discount_to_be_offered__c !== '';
        const hasNewDiscount = newDiscount != null && newDiscount !== '';
        return !(hasDiscountOffered || hasNewDiscount);
    }

    isRowLocked(item) {
        // Do not lock on Item_Type__c === 'ARC' — this screen is for editing ARC proposed price
        return (
            item.Is_Discount_Approved__c === true ||
            this.hasSubmittedApproverStatus(item)
        );
    }

    isRowLockedForNewDiscount(item) {
        return this.hasSubmittedApproverStatus(item);
    }

    hasSubmittedApproverStatus(item) {
        return [
            item.Sales_Manager_Status__c,
            item.Country_Continent_Sales_H_LOB_Status__c,
            item.Global_Sales_Head_Status__c,
            item.Rotex_Board_Member_Status__c,
            item.Managing_Director_Status__c
        ].some((status) => status === 'Submitted');
    }

    handleHeaderFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        this[field] = event.target.value;
        if (field === 'deliveryPeriod' || field === 'liquidateTerms') {
            this.errors = { ...this.errors, [field]: '' };
        }
    }

    handleContactFocus() {
        if (!this.accountId) {
            this.showToast('Select Customer', 'Account is required to search contacts.', 'info');
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
            this.showToast('Error', this.reduceError(error), 'error');
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

    buildHeaderFieldsPayload() {
        return {
            Requested_Validity_Of_Offer__c: this.requestedValidityOfOffer || null,
            Delivery_Period__c: this.deliveryPeriod || null,
            Warranty_Terms_Draft__c: this.requestedWarrantyTerms || null,
            Liquidate_Terms__c: this.liquidateTerms || null,
            Transport_Details__c: this.transportDetails || null,
            Delivery_Location__c: this.deliveryLocation || null,
            Special_Remarks__c: this.specialRemarks || null,
            ContactId: this.contactId || null,
            Phone: this.phone || null,
            Email: this.email || null
        };
    }

    validateHeaderFields() {
        const next = { deliveryPeriod: '', liquidateTerms: '' };
        let valid = true;
        if (!(this.deliveryPeriod || '').trim()) {
            next.deliveryPeriod = 'Delivery Period is required.';
            valid = false;
        }
        if (!(this.liquidateTerms || '').trim()) {
            next.liquidateTerms = 'Liquidate Terms is required.';
            valid = false;
        }
        this.errors = next;
        return valid;
    }

    readInputValue(event) {
        if (event.detail && event.detail.value !== undefined) {
            return event.detail.value;
        }
        return event.target.value;
    }

    handleDesiredPriceChange(event) {
        const id = event.currentTarget.dataset.id;
        const value = this.readInputValue(event);
        const parsedDesiredPrice = value !== '' ? parseFloat(value) : null;

        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id !== id) {
                return item;
            }
            const computedDiscount = this.computeDiscountFromDesiredPrice(
                item.ListPrice,
                parsedDesiredPrice
            );
            const updatedItem = {
                ...item,
                desiredPriceValue: parsedDesiredPrice == null ? 0 : parsedDesiredPrice,
                Sell_Price_of_Sc__c: parsedDesiredPrice == null ? 0 : parsedDesiredPrice,
                Discount_to_be_offered__c: computedDiscount == null ? 0 : computedDiscount,
                discountDisplay: formatNumber(computedDiscount, 3) || '0',
                Requested_Comments__c: null
            };
            updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                updatedItem,
                item.newDiscountValue
            );
            return updatedItem;
        });
    }

    handleNewDesiredPriceChange(event) {
        const id = event.currentTarget.dataset.id;
        const value = this.readInputValue(event);
        const parsedPrice = value !== '' ? parseFloat(value) : null;

        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id !== id) {
                return item;
            }
            const computedDiscount = this.computeDiscountFromDesiredPrice(
                item.ListPrice,
                parsedPrice
            );
            const updatedItem = {
                ...item,
                newDesiredPriceValue: parsedPrice,
                newDiscountValue: computedDiscount,
                newDiscountDisplay: formatNumber(computedDiscount, 3) || '',
                Requested_Comments__c: null
            };
            updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                updatedItem,
                computedDiscount
            );
            return updatedItem;
        });
    }

    handleDiscountPercentChange(event) {
        const id = event.currentTarget.dataset.id;
        const isApprovedRow = event.currentTarget.dataset.approved === 'true';
        const value = this.readInputValue(event);
        const discNum = value !== '' ? parseFloat(value) : 0;
        const safeDisc = Number.isFinite(discNum) ? discNum : 0;

        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id !== id) {
                return item;
            }
            const listPrice = Number(item.ListPrice) || 0;
            const proposed =
                safeDisc > 0 && listPrice > 0
                    ? parseFloat((listPrice * (1 - safeDisc / 100)).toFixed(4))
                    : 0;

            if (isApprovedRow) {
                const updatedItem = {
                    ...item,
                    newDiscountValue: safeDisc,
                    newDiscountDisplay: formatNumber(safeDisc, 3) || '0',
                    newDesiredPriceValue: proposed,
                    Requested_Comments__c: null
                };
                updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                    updatedItem,
                    safeDisc
                );
                return updatedItem;
            }

            const updatedItem = {
                ...item,
                Discount_to_be_offered__c: safeDisc,
                discountDisplay: formatNumber(safeDisc, 3) || '0',
                desiredPriceValue: proposed,
                Sell_Price_of_Sc__c: proposed,
                Requested_Comments__c: null
            };
            updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                updatedItem,
                item.newDiscountValue
            );
            return updatedItem;
        });
    }

    handleRequestedCommentsChange(event) {
        const id = event.currentTarget.dataset.id;
        const value = this.readInputValue(event);
        this.quoteLineItemList = this.quoteLineItemList.map((item) =>
            item.Id === id ? { ...item, Requested_Comments__c: value } : item
        );
    }

    handleTextFieldChange(event) {
        const id = event.currentTarget.dataset.id;
        const field = event.currentTarget.dataset.field;
        const value = this.readInputValue(event);
        this.quoteLineItemList = this.quoteLineItemList.map((item) =>
            item.Id === id ? { ...item, [field]: value } : item
        );
    }

    handleNumberFieldChange(event) {
        const id = event.currentTarget.dataset.id;
        const field = event.currentTarget.dataset.field;
        const value = this.readInputValue(event);
        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id !== id) {
                return item;
            }
            return {
                ...item,
                [field]: value !== '' ? parseFloat(value) : 0
            };
        });
    }

    handleDateFieldChange(event) {
        const id = event.currentTarget.dataset.id;
        const field = event.currentTarget.dataset.field;
        const value = this.readInputValue(event);
        const inputField = event.currentTarget;

        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id !== id) {
                return item;
            }
            return {
                ...item,
                [field]: value !== '' ? value : null
            };
        });

        if (field === 'Valid_from__c') {
            const selectedDate = value
                ? new Date(new Date(value).setHours(0, 0, 0, 0))
                : null;
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            if (selectedDate && selectedDate < today) {
                inputField.setCustomValidity('Valid From date cannot be before today.');
            } else {
                inputField.setCustomValidity('');
            }
            inputField.reportValidity();
        }

        if (field === 'Valid_Till__c') {
            const selectedDate = value
                ? new Date(new Date(value).setHours(0, 0, 0, 0))
                : null;
            const fyEndDate = this.getFiscalYearEndDate();
            if (selectedDate && selectedDate > fyEndDate) {
                inputField.setCustomValidity(
                    `Date cannot be beyond Financial Year end (${this.formatDate(fyEndDate)})`
                );
            } else {
                inputField.setCustomValidity('');
            }
            inputField.reportValidity();
        }
    }

    getFiscalYearEndDate() {
        const today = new Date();
        const currentYear = today.getFullYear();
        const currentMonth = today.getMonth();
        let fyEndYear = currentYear;
        if (currentMonth >= 3) {
            fyEndYear = currentYear + 1;
        }
        return new Date(fyEndYear, 2, 31);
    }

    formatDate(date) {
        const day = String(date.getDate()).padStart(2, '0');
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const year = date.getFullYear();
        return `${day}-${month}-${year}`;
    }

    handleSubmitClick() {
        if (this.hasConfirmedSubmit || this.isSubmitting || this.showSpinner) {
            return;
        }
        if (!this.validateHeaderFields()) {
            this.showToast('Error', 'Please fill all mandatory fields.', 'error');
            return;
        }
        this.showConfirmSubmit = true;
    }

    handleConfirmCancel() {
        if (this.isConfirmDisabled) {
            return;
        }
        this.showConfirmSubmit = false;
    }

    handleConfirmOk() {
        if (this.isConfirmDisabled) {
            return;
        }
        this.hasConfirmedSubmit = true;
        this.isSubmitting = true;
        this.showConfirmSubmit = false;
        this.handleSave();
    }

    async handleSave() {
        this.showSpinner = true;
        try {
            if (!this.validateHeaderFields()) {
                this.showToast('Error', 'Please fill all mandatory fields.', 'error');
                this.isSubmitting = false;
                return;
            }

            const dateInputs = [...this.template.querySelectorAll('input[type="date"]')];
            const allValid = dateInputs.reduce((validSoFar, input) => {
                if (input.disabled) {
                    return validSoFar;
                }
                input.reportValidity();
                return validSoFar && input.checkValidity();
            }, true);

            if (!allValid) {
                this.showToast('Validation Error', 'Please check and correct the errors on the page.', 'error');
                this.isSubmitting = false;
                return;
            }

            const invalidPotentialRow = this.quoteLineItemList.find((item) => {
                const hasPotentialQty =
                    item.Potential_Qty__c !== null &&
                    item.Potential_Qty__c !== undefined &&
                    item.Potential_Qty__c !== '';
                return !hasPotentialQty;
            });
            if (invalidPotentialRow) {
                this.showToast('Validation Error', 'For each row, MOQ / Proposed Qty is mandatory.', 'error');
                this.isSubmitting = false;
                return;
            }

            const invalidNewDiscountItem = this.quoteLineItemList.find(
                (item) =>
                    item.Is_Discount_Approved__c &&
                    item.newDiscountValue != null &&
                    item.newDiscountValue !== '' &&
                    item.Discount_as_per_SAP__c > 0 &&
                    parseFloat(item.newDiscountValue) < parseFloat(item.Discount_as_per_SAP__c)
            );
            const invalidDiscountItem = this.quoteLineItemList.find(
                (item) =>
                    item.Discount_to_be_offered__c != null &&
                    item.Discount_to_be_offered__c !== '' &&
                    item.Discount_as_per_SAP__c > 0 &&
                    parseFloat(item.Discount_to_be_offered__c) < parseFloat(item.Discount_as_per_SAP__c)
            );
            if (invalidDiscountItem || invalidNewDiscountItem) {
                this.showToast('Error', 'Discount Value cannot be less than Discount as per SAP.', 'error');
                this.isSubmitting = false;
                return;
            }

            const hasNewDiscountEntered = this.quoteLineItemList.some(
                (item) =>
                    item.Is_Discount_Approved__c &&
                    item.newDiscountValue != null &&
                    item.newDiscountValue !== ''
            );

            const itemsToUpdate = this.quoteLineItemList.map((item) => {
                const updateData = {
                    Id: item.Id,
                    Quantity: 1,
                    Discount_as_per_SAP__c: 0,
                    Discount_to_be_offered__c: item.Discount_to_be_offered__c
                        ? parseFloat(item.Discount_to_be_offered__c)
                        : 0,
                    Requested_Discount__c: item.Discount_to_be_offered__c
                        ? parseFloat(item.Discount_to_be_offered__c)
                        : 0,
                    Customer_Part_No__c: item.Customer_Part_No__c || '',
                    P_F_Charges__c: item.P_F_Charges__c ? parseFloat(item.P_F_Charges__c) : 0,
                    Requested_Comments__c: item.Requested_Comments__c || null,
                    UnitPrice:
                        item.UnitPrice != null && item.UnitPrice !== ''
                            ? parseFloat(item.UnitPrice)
                            : 0,
                    Is_Discount_Only_Rejected__c: item.Is_Discount_Only_Rejected__c,
                    Final_Discount_Approver__c: item.Final_Discount_Approver__c,
                    Sales_Rep__c: item.Sales_Rep__c,
                    Sales_Manager__c: item.Sales_Manager__c,
                    Country_Continent_Sales_Head_LOB_Head__c:
                        item.Country_Continent_Sales_Head_LOB_Head__c,
                    Global_Sales_Head__c: item.Global_Sales_Head__c,
                    Rotex_Board_Member__c: item.Rotex_Board_Member__c,
                    Managing_Director_Country_Manage__c: item.Managing_Director_Country_Manage__c,
                    Is_Discount_Approved__c: item.Is_Discount_Approved__c,
                    Is_QLI_Approved_going_for_Approval__c: item.Is_QLI_Approved_going_for_Approval__c,
                    Potential_Value__c: item.Potential_Value__c
                        ? parseFloat(item.Potential_Value__c)
                        : null,
                    Potential_Qty__c: item.Potential_Qty__c ? parseFloat(item.Potential_Qty__c) : null,
                    Valid_from__c: item.Valid_from__c || null,
                    Valid_Till__c: item.Valid_Till__c || null,
                    Sell_Price_of_Sc__c:
                        item.desiredPriceValue != null && item.desiredPriceValue !== ''
                            ? parseFloat(item.desiredPriceValue)
                            : item.Sell_Price_of_Sc__c != null
                              ? parseFloat(item.Sell_Price_of_Sc__c)
                              : null
                };

                if (
                    item.Is_Discount_Approved__c &&
                    item.newDiscountValue != null &&
                    item.newDiscountValue !== ''
                ) {
                    updateData.Is_Edited_Through_Edit_Discount__c = true;
                    updateData.Previous_Discount__c = item.Discount_to_be_offered__c;
                    updateData.Discount_to_be_offered__c = parseFloat(item.newDiscountValue);
                    updateData.Requested_Discount__c = parseFloat(item.newDiscountValue);
                    updateData.New_Discount_Entered__c = true;
                    if (item.newDesiredPriceValue != null && item.newDesiredPriceValue !== '') {
                        updateData.Sell_Price_of_Sc__c = parseFloat(item.newDesiredPriceValue);
                    }
                    updateData.Sales_Manager_Comments__c = item.Sales_Manager_Comments__c;
                    updateData.Sales_Manager_Date_Time__c = item.Sales_Manager_Date_Time__c;
                    updateData.Country_Continent_Sales_LOB_Comments__c =
                        item.Country_Continent_Sales_LOB_Comments__c;
                    updateData.Country_Head_Date_Time__c = item.Country_Head_Date_Time__c;
                    updateData.Global_Sales_Head_Comments__c = item.Global_Sales_Head_Comments__c;
                    updateData.Global_Sales_Head_Date_Time__c = item.Global_Sales_Head_Date_Time__c;
                    updateData.Rotex_Board_Member_Comments__c = item.Rotex_Board_Member_Comments__c;
                    updateData.Rotex_Board_Member_Date_time__c = item.Rotex_Board_Member_Date_time__c;
                    updateData.Managing_Director_Comments__c = item.Managing_Director_Comments__c;
                    updateData.Managing_Director_Date_Time__c = item.Managing_Director_Date_Time__c;
                } else if (item.Previous_Discount__c) {
                    updateData.Previous_Discount__c = item.Previous_Discount__c;
                }

                return updateData;
            });

            await updateQuoteHeaderFields({
                quoteId: this.quoteId,
                fields: this.buildHeaderFieldsPayload()
            });

            await updateQuoteAndLineItems({
                quoteId: this.quoteId,
                quoteLineItems: itemsToUpdate,
                shouldUpdateQuoteStatus: hasNewDiscountEntered,
                paymentTerms: this.paymentTerms,
                warrantyTerms: this.requestedWarrantyTerms,
                incoTerms: this.incoTerms
            });

            await updateQuoteHeaderFields({
                quoteId: this.quoteId,
                fields: { Status: 'Submit for SOA Approval' }
            });

            this.status = 'Submit for SOA Approval';
            this.showToast(
                'Success',
                'Quote submitted for approval. Status updated to Submit for SOA Approval.',
                'success'
            );
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            window.setTimeout(() => {
                this.dispatchEvent(new CustomEvent('save', { bubbles: true, composed: true }));
            }, 800);
        } catch (e) {
            this.showToast('Error', this.reduceError(e), 'error');
            this.isSubmitting = false;
        } finally {
            this.showSpinner = false;
        }
    }

    closeModal() {
        if (this.showSpinner || this.isSubmitting) {
            return;
        }
        this.showConfirmSubmit = false;
        this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    showToast(title, message, variant) {
        this.portalToastTitle = title;
        this.portalToastMessage = message || '';
        this.portalToastVariant = variant || 'success';
        this.portalToastVisible = true;
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }
        this.portalToastTimeout = window.setTimeout(() => {
            this.portalToastVisible = false;
        }, 3500);
    }

    reduceError(error) {
        if (!error) {
            return 'Something went wrong.';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body?.message) {
            return error.body.message;
        }
        if (error.message) {
            return error.message;
        }
        return 'Something went wrong.';
    }
}