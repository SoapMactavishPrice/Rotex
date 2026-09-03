import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuoteLineItem from '@salesforce/apex/DealerEditDiscountQuantityController.getQuoteLineItem';
import updateQuoteLineItem from '@salesforce/apex/DealerEditDiscountQuantityController.updateQuoteLineItem';
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

export default class DealerEditDiscountQuantity extends LightningElement {
    @api quoteId;
    @api quoteType = '';
    @api businessLine = '';
    @api partnerAccountId;

    @track showSpinner = false;
    @track showConfirmSubmit = false;
    @track isSubmitting = false;
    /** After confirm OK once, keep footer Cancel / Submit disabled (blocks double submit). */
    @track hasConfirmedSubmit = false;
    @track quoteLineItemList = [];
    @track currencyCode = '';

    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'success';
    portalToastTimeout;

    @track requestedValidityOptions = [];
    @track requestedWarrantyOptions = [];
    @track contactResults = [];
    @track showContactDropdown = false;
    @track headerReady = false;

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

    contactTimeout;

    get isActionDisabled() {
        return (
            this.showSpinner ||
            this.isSubmitting ||
            this.hasConfirmedSubmit ||
            this.showConfirmSubmit
        );
    }

    /**
     * Footer Cancel / Submit for Approval:
     * - only while quote is Draft
     * - hidden while confirm is open / after OK
     * After OK, status becomes Submit for SOA Approval (buttons stay off on reopen).
     */
    get showFooterActions() {
        return this.canShowSubmitActions;
    }

    get isConfirmDisabled() {
        return this.isSubmitting || this.hasConfirmedSubmit;
    }

    get hasRows() {
        return this.quoteLineItemList && this.quoteLineItemList.length > 0;
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

    get normalizedBusinessLine() {
        return String(this.businessLine || '')
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
    }

    get normalizedQuoteType() {
        return String(this.quoteType || '')
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
    }

    get isSecondaryQuote() {
        return this.normalizedQuoteType === 'SECONDARY CUSTOMER';
    }

    get isBothBusinessLine() {
        return this.normalizedBusinessLine === 'BOTH';
    }

    get isNonRotexBusinessLine() {
        return this.normalizedBusinessLine === 'NON ROTEX';
    }

    get isRotexBusinessLine() {
        return this.normalizedBusinessLine === 'ROTEX';
    }

    resolveProductCode(item) {
        const fromRel = item?.Product2?.ProductCode || item?.productCode;
        if (fromRel) {
            return String(fromRel).trim();
        }
        return '';
    }

    isNonRotexProductCode(productCode) {
        const code = String(productCode || '').trim();
        return code.length >= 2 && code.substring(0, 2).toUpperCase() === 'CP';
    }

    /**
     * ROTEX business line  → all rows: Disc Offered editable, Sales Price locked
     * NON ROTEX business line → all rows: Sales Price editable, Disc Offered locked
     * BOTH (or unknown) → per product: CP* = Non-Rotex rules, else Rotex rules
     */
    isNonRotexRow(item, productCode) {
        const code = productCode || this.resolveProductCode(item);
        if (this.isNonRotexBusinessLine) {
            return true;
        }
        if (this.isRotexBusinessLine) {
            return false;
        }
        // BOTH / Self / blank business line → decide by product code
        return this.isNonRotexProductCode(code);
    }

    connectedCallback() {
        if (!this.quoteId) {
            this.showToast('Error', 'Invalid Quote Id', 'error');
            return;
        }
        this.loadHeaderAndPicklists();
        this.handleGetLineItems();
    }

    disconnectedCallback() {
        window.clearTimeout(this.contactTimeout);
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }
    }

    get portalToastClass() {
        return `portal-toast portal-toast--${this.portalToastVariant || 'info'}`;
    }

    showToast(toastTitle, toastMsg, toastType) {
        const safeTitle = toastTitle || '';
        const safeMessage = toastMsg || '';
        const safeVariant = toastType || 'info';

        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }
        this.portalToastTitle = safeTitle;
        this.portalToastMessage = safeMessage;
        this.portalToastVariant = safeVariant;
        this.portalToastVisible = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.portalToastTimeout = window.setTimeout(() => {
            this.portalToastVisible = false;
            this.portalToastTimeout = null;
        }, 3500);

        this.dispatchEvent(
            new ShowToastEvent({
                title: safeTitle,
                message: safeMessage,
                variant: safeVariant,
                mode: 'dismissable'
            })
        );
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    closeModal() {
        // Block only while save is in progress; after OK lock, X can still close on error.
        if (this.showSpinner || this.isSubmitting) {
            return;
        }
        this.showConfirmSubmit = false;
        this.dispatchEvent(new CustomEvent('close', { bubbles: true, composed: true }));
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
        // One-time lock: footer Cancel / Submit stay hidden for this modal session.
        this.hasConfirmedSubmit = true;
        this.isSubmitting = true;
        this.showConfirmSubmit = false;
        this.handleSave();
    }

    loadHeaderAndPicklists() {
        Promise.all([
            getQuoteHeader({ quoteId: this.quoteId }),
            getRequestedValidityOfOfferPicklistValues(),
            getRequestedWarrantyTermsPicklistValues()
        ])
            .then(([quote, reqValidity, reqWarranty]) => {
                this.requestedValidityOptions = reqValidity || [];
                this.requestedWarrantyOptions = reqWarranty || [];
                if (quote) {
                    this.populateHeaderFromQuote(quote);
                }
                this.headerReady = true;
            })
            .catch((error) => {
                this.headerReady = true;
                this.showToast('Error', error?.body?.message || 'Unable to load quote header', 'error');
            });
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
            this.showToast('Error', error?.body?.message || 'Unable to search contacts', 'error');
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

    /** Footer only while Draft and not yet confirmed. */
    get canShowSubmitActions() {
        const status = String(this.status || '')
            .trim()
            .toLowerCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        const isDraft = !status || status === 'draft';
        return isDraft && !this.hasConfirmedSubmit && !this.isSubmitting && !this.showConfirmSubmit;
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

    computeSalesPriceFromDiscount(listPrice, discountPct) {
        if (listPrice == null) {
            return null;
        }
        const disc = discountPct == null || discountPct === '' ? 0 : parseFloat(discountPct);
        if (Number.isNaN(disc) || disc === 0) {
            return parseFloat(parseFloat(listPrice).toFixed(2));
        }
        return parseFloat((listPrice * (1 - disc / 100)).toFixed(2));
    }

    buildRowState(item) {
        const productCode = this.resolveProductCode(item);
        const isNonRotex = this.isNonRotexRow(item, productCode);
        const isRotex = !isNonRotex;
        const isApproved = item.Is_Discount_Approved__c === true;
        const isArc = item.Item_Type__c === 'ARC';
        const isSubmitted = this.hasSubmittedApproverStatus(item);
        const hardLock = isArc || isSubmitted;

        const sapDiscountDisplay =
            item.Discount_as_per_SAP__c != null && item.Discount_as_per_SAP__c !== ''
                ? `${item.Discount_as_per_SAP__c}%`
                : '0%';

        // Exact rules:
        // Rotex     → Disc Offered editable, Sales Price locked
        // Non-Rotex → Sales Price editable, Disc Offered locked
        let discountOffered = item.Discount_to_be_offered__c;
        let unitPrice = item.UnitPrice;

        if (isNonRotex) {
            discountOffered = 0;
        } else if ((unitPrice == null || unitPrice === '') && item.ListPrice != null) {
            unitPrice = this.computeSalesPriceFromDiscount(item.ListPrice, discountOffered);
        }

        // Disc Offered / Desired Price: editable only for Rotex rows (unless ARC / submitted / approved)
        const discountLocked = Boolean(isNonRotex || hardLock || isApproved);
        // Sales Price: editable only for Non-Rotex rows (unless ARC / submitted)
        const salesPriceLocked = Boolean(isRotex || hardLock);

        const discountIsZero = discountOffered === 0 || discountOffered === '0';
        const hasExistingDiscount =
            isRotex && this.hasDiscountOfferedValue(discountOffered) && !discountIsZero;

        return {
            ...item,
            productCode,
            isNonRotex,
            isRotex,
            UnitPrice: unitPrice,
            Discount_to_be_offered__c: isNonRotex ? 0 : discountOffered,
            sapDiscountDisplay,
            newDiscountValue: null,
            desiredPriceValue: hasExistingDiscount
                ? this.computeDesiredPrice(item.ListPrice, discountOffered)
                : null,
            isSalesPriceDisabled: salesPriceLocked,
            isDiscountOfferedDisabled: discountLocked,
            isDesiredPriceDisabled: Boolean(discountLocked || hasExistingDiscount),
            isNewDiscountDisabled: Boolean(isNonRotex || isArc || !isApproved),
            isRequestedCommentsDisabled: this.computeRequestedCommentsDisabled(
                {
                    ...item,
                    Discount_to_be_offered__c: isNonRotex ? 0 : discountOffered,
                    newDiscountValue: null
                },
                null
            ),
            requestedCommentsPlaceholder: 'Enter comments...'
        };
    }

    handleGetLineItems() {
        this.showSpinner = true;
        getQuoteLineItem({ qId: this.quoteId })
            .then((result) => {
                if (result && result.length > 0) {
                    const sample = result[0];
                    const quote = sample.Quote || {};
                    if (!this.quoteType && quote.Quote_Type__c) {
                        this.quoteType = quote.Quote_Type__c;
                    }
                    const blFromQuote =
                        quote.Account?.Business_type__c ||
                        quote.QuoteAccount?.Business_type__c ||
                        quote.Account__r?.Business_type__c ||
                        '';
                    if (!this.businessLine && blFromQuote) {
                        this.businessLine = blFromQuote;
                    }
                    this.currencyCode = sample.CurrencyIsoCode || '';
                }

                // Map after business line / quote type are resolved
                this.quoteLineItemList = (result || []).map((item) => this.buildRowState(item));
            })
            .catch((error) => {
                this.showToast('Error', error?.body?.message || 'Unable to load quote line items', 'error');
            })
            .finally(() => {
                this.showSpinner = false;
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

    enforceMax3Decimals(value) {
        if (value === '' || value == null) {
            return null;
        }
        const str = String(value);
        const dotIndex = str.indexOf('.');
        if (dotIndex !== -1 && str.length - dotIndex - 1 > 3) {
            this.showToast('Invalid Input', 'Discount can have a maximum of 3 decimal places.', 'warning');
            return this.roundTo3Decimals(parseFloat(value));
        }
        return parseFloat(value);
    }

    hasMoreThan3Decimals(rawValue) {
        const str = String(rawValue);
        const dotIndex = str.indexOf('.');
        return dotIndex !== -1 && str.length - dotIndex - 1 > 3;
    }

    hasDiscountOfferedValue(val) {
        return val != null && val !== '';
    }

    isRowLocked(item) {
        return item.Item_Type__c == 'ARC' || item.Is_Discount_Approved__c || this.hasSubmittedApproverStatus(item);
    }

    isRowLockedForNewDiscount(item) {
        return item.Item_Type__c == 'ARC';
    }

    computeRequestedCommentsDisabled(item, overrideNewDiscount) {
        const newDiscount = overrideNewDiscount !== undefined ? overrideNewDiscount : item.newDiscountValue;
        const hasDiscountOffered = item.Discount_to_be_offered__c != null && item.Discount_to_be_offered__c !== '';
        const hasNewDiscount = newDiscount != null && newDiscount !== '';
        return !(hasDiscountOffered || hasNewDiscount);
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

    handleCustomerPartNoChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id === id) {
                return { ...item, Customer_Part_No__c: value };
            }
            return item;
        });
    }

    handleSalesPriceChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const parsed = value !== '' ? parseFloat(value) : null;

        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id !== id || item.isSalesPriceDisabled || !item.isNonRotex) {
                return item;
            }
            return {
                ...item,
                UnitPrice: parsed,
                Discount_to_be_offered__c: 0,
                desiredPriceValue: null
            };
        });
    }

    handleDesiredPriceChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        const parsedDesiredPrice = value !== '' ? parseFloat(value) : null;

        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id !== id || item.isNonRotex) {
                return item;
            }

            const baseLocked = this.isRowLockedForNewDiscount(item);
            const computedDiscount = this.computeDiscountFromDesiredPrice(item.ListPrice, parsedDesiredPrice);
            const desiredPriceIsNonZero = parsedDesiredPrice !== null && parsedDesiredPrice !== 0;
            const salesPrice = parsedDesiredPrice != null
                ? parseFloat(parseFloat(parsedDesiredPrice).toFixed(2))
                : this.computeSalesPriceFromDiscount(item.ListPrice, computedDiscount);

            if (item.Is_Discount_Approved__c) {
                const updatedItem = {
                    ...item,
                    desiredPriceValue: parsedDesiredPrice,
                    newDiscountValue: computedDiscount,
                    UnitPrice: salesPrice,
                    Requested_Comments__c: null,
                    isSalesPriceDisabled: true,
                    isDiscountOfferedDisabled: true,
                    isDesiredPriceDisabled: baseLocked,
                    isNewDiscountDisabled: baseLocked || desiredPriceIsNonZero
                };
                updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                    updatedItem,
                    updatedItem.newDiscountValue
                );
                return updatedItem;
            }

            const updatedItem = {
                ...item,
                desiredPriceValue: parsedDesiredPrice,
                Discount_to_be_offered__c: computedDiscount,
                UnitPrice: salesPrice,
                Requested_Comments__c: null,
                isSalesPriceDisabled: true,
                isDesiredPriceDisabled: false,
                isDiscountOfferedDisabled: desiredPriceIsNonZero
            };
            updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                updatedItem,
                item.newDiscountValue
            );
            return updatedItem;
        });
    }

    handleDiscountChange(event) {
        const id = event.target.dataset.id;
        const rawValue = event.target.value;
        const parsedDiscount = this.enforceMax3Decimals(rawValue);

        if (parsedDiscount !== null && this.hasMoreThan3Decimals(rawValue)) {
            event.target.value = parsedDiscount;
        }

        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id !== id || item.isNonRotex) {
                return item;
            }
            const hardLock =
                item.Item_Type__c === 'ARC' || this.hasSubmittedApproverStatus(item);
            const computedDesiredPrice = this.computeDesiredPrice(item.ListPrice, parsedDiscount);
            const salesPrice = this.computeSalesPriceFromDiscount(item.ListPrice, parsedDiscount);
            const discountIsNonZero = parsedDiscount !== null && parsedDiscount !== 0;
            const updatedItem = {
                ...item,
                Discount_to_be_offered__c: parsedDiscount,
                desiredPriceValue: computedDesiredPrice,
                UnitPrice: salesPrice,
                Requested_Comments__c: null,
                isSalesPriceDisabled: true,
                isDiscountOfferedDisabled: hardLock,
                isDesiredPriceDisabled: hardLock || discountIsNonZero
            };
            updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(
                updatedItem,
                item.newDiscountValue
            );
            return updatedItem;
        });
    }

    handlePFChargeChanges(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id === id) {
                return { ...item, P_F_Charges__c: value !== '' ? parseFloat(value) : null };
            }
            return item;
        });
    }

    handleQuantityChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id === id) {
                return {
                    ...item,
                    Quantity: value !== '' ? parseFloat(value) : null
                };
            }
            return item;
        });
    }

    handleNewDiscountChange(event) {
        const id = event.target.dataset.id;
        const rawValue = event.target.value;
        const parsedValue = this.enforceMax3Decimals(rawValue);

        if (parsedValue !== null && this.hasMoreThan3Decimals(rawValue)) {
            event.target.value = parsedValue;
        }

        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id !== id || item.isNonRotex) {
                return item;
            }
            const baseLocked = this.isRowLockedForNewDiscount(item);
            const computedDesiredPrice = this.computeDesiredPrice(item.ListPrice, parsedValue);
            const salesPrice = this.computeSalesPriceFromDiscount(item.ListPrice, parsedValue);
            const newDiscountIsNonZero = parsedValue !== null && parsedValue !== 0;
            const updatedItem = {
                ...item,
                newDiscountValue: parsedValue,
                desiredPriceValue: computedDesiredPrice,
                UnitPrice: salesPrice,
                Requested_Comments__c: null,
                isSalesPriceDisabled: true,
                isDiscountOfferedDisabled: true,
                isNewDiscountDisabled: baseLocked,
                isDesiredPriceDisabled: baseLocked || newDiscountIsNonZero
            };
            updatedItem.isRequestedCommentsDisabled = this.computeRequestedCommentsDisabled(updatedItem, parsedValue);
            return updatedItem;
        });
    }

    handleRequestedCommentsChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        this.quoteLineItemList = this.quoteLineItemList.map((item) => {
            if (item.Id === id) {
                return { ...item, Requested_Comments__c: value };
            }
            return item;
        });
    }

    handleSave() {
        if (!this.validateHeaderFields()) {
            this.showToast('Error', 'Please fill all mandatory fields.', 'error');
            this.showSpinner = false;
            this.isSubmitting = false;
            // Keep hasConfirmedSubmit = true so footer buttons stay hidden.
            return;
        }

        this.showSpinner = true;

        const invalidNewDiscountItem = this.quoteLineItemList.find(
            (item) =>
                !item.isNonRotex &&
                item.Is_Discount_Approved__c &&
                item.newDiscountValue != null &&
                item.newDiscountValue !== '' &&
                item.Discount_as_per_SAP__c > 0 &&
                parseFloat(item.newDiscountValue) < parseFloat(item.Discount_as_per_SAP__c)
        );

        const invalidDiscountItem = this.quoteLineItemList.find(
            (item) =>
                !item.isNonRotex &&
                item.Discount_to_be_offered__c != null &&
                item.Discount_to_be_offered__c !== '' &&
                item.Discount_as_per_SAP__c > 0 &&
                parseFloat(item.Discount_to_be_offered__c) < parseFloat(item.Discount_as_per_SAP__c)
        );

        if (invalidDiscountItem || invalidNewDiscountItem) {
            this.showToast('Error', 'Discount Value cannot be less than Discount as per SAP.', 'error');
            this.showSpinner = false;
            this.isSubmitting = false;
            // Keep hasConfirmedSubmit = true so footer buttons stay hidden.
            return;
        }

        const hasNewDiscountEntered = this.quoteLineItemList.some(
            (item) =>
                !item.isNonRotex &&
                item.Is_Discount_Approved__c &&
                item.newDiscountValue != null &&
                item.newDiscountValue !== ''
        );

        const itemsToUpdate = this.quoteLineItemList.map((item) => {
            const discountValue = item.isNonRotex
                ? 0
                : item.Discount_to_be_offered__c
                  ? parseFloat(item.Discount_to_be_offered__c)
                  : 0;
            const unitPrice = item.UnitPrice != null && item.UnitPrice !== ''
                ? parseFloat(item.UnitPrice)
                : this.computeSalesPriceFromDiscount(item.ListPrice, discountValue);

            const updateData = {
                Id: item.Id,
                Quantity: item.Quantity ? parseFloat(item.Quantity) : 0,
                UnitPrice: unitPrice != null ? unitPrice : 0,
                Discount_to_be_offered__c: discountValue,
                Requested_Discount__c: discountValue,
                Customer_Part_No__c: item.Customer_Part_No__c,
                P_F_Charges__c: item.P_F_Charges__c ? parseFloat(item.P_F_Charges__c) : 0,
                Discount_as_per_SAP__c: parseFloat(item.Discount_as_per_SAP__c),
                Requested_Comments__c: item.Requested_Comments__c || null,
                Is_Discount_Only_Rejected__c: item.Is_Discount_Only_Rejected__c,
                Final_Discount_Approver__c: item.Final_Discount_Approver__c,
                Sales_Rep__c: item.Sales_Rep__c,
                Sales_Manager__c: item.Sales_Manager__c,
                Country_Continent_Sales_Head_LOB_Head__c: item.Country_Continent_Sales_Head_LOB_Head__c,
                Global_Sales_Head__c: item.Global_Sales_Head__c,
                Rotex_Board_Member__c: item.Rotex_Board_Member__c,
                Managing_Director_Country_Manage__c: item.Managing_Director_Country_Manage__c,
                Is_Discount_Approved__c: item.Is_Discount_Approved__c,
                Is_QLI_Approved_going_for_Approval__c: item.Is_QLI_Approved_going_for_Approval__c
            };

            if (
                !item.isNonRotex &&
                item.Is_Discount_Approved__c &&
                item.newDiscountValue != null &&
                item.newDiscountValue !== ''
            ) {
                updateData.Is_Edited_Through_Edit_Discount__c = true;
                updateData.Previous_Discount__c = item.Discount_to_be_offered__c;
                updateData.Discount_to_be_offered__c = parseFloat(item.newDiscountValue);
                updateData.Requested_Discount__c = parseFloat(item.newDiscountValue);
                updateData.New_Discount_Entered__c = true;
                updateData.UnitPrice = this.computeSalesPriceFromDiscount(
                    item.ListPrice,
                    item.newDiscountValue
                );

                updateData.Sales_Manager_Comments__c = item.Sales_Manager_Comments__c;
                updateData.Sales_Manager_Date_Time__c = item.Sales_Manager_Date_Time__c;
                updateData.Country_Continent_Sales_LOB_Comments__c = item.Country_Continent_Sales_LOB_Comments__c;
                updateData.Country_Head_Date_Time__c = item.Country_Head_Date_Time__c;
                updateData.Global_Sales_Head_Comments__c = item.Global_Sales_Head_Comments__c;
                updateData.Global_Sales_Head_Date_Time__c = item.Global_Sales_Head_Date_Time__c;
                updateData.Rotex_Board_Member_Comments__c = item.Rotex_Board_Member_Comments__c;
                updateData.Rotex_Board_Member_Date_Time__c = item.Rotex_Board_Member_Date_Time__c;
                updateData.Managing_Director_Comments__c = item.Managing_Director_Comments__c;
                updateData.Managing_Director_Date_Time__c = item.Managing_Director_Date_Time__c;
            } else if (item.Previous_Discount__c) {
                updateData.Previous_Discount__c = item.Previous_Discount__c;
            }

            return updateData;
        });

        updateQuoteHeaderFields({
            quoteId: this.quoteId,
            fields: this.buildHeaderFieldsPayload()
        })
            .then(() =>
                updateQuoteLineItem({
                    quoteId: this.quoteId,
                    quoteLineItems: itemsToUpdate,
                    shouldUpdateQuoteStatus: hasNewDiscountEntered
                })
            )
            .then(() =>
                // Always set SOA status last so Cancel / Submit stay disabled on reopen.
                updateQuoteHeaderFields({
                    quoteId: this.quoteId,
                    fields: { Status: 'Submit for SOA Approval' }
                })
            )
            .then(() => {
                this.status = 'Submit for SOA Approval';
                this.showSpinner = false;
                this.isSubmitting = false;
                this.showToast(
                    'Success',
                    'Quote submitted for approval. Status updated to Submit for SOA Approval.',
                    'success'
                );
                // Let the green toast show briefly, then close modal / refresh parent.
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.setTimeout(() => {
                    this.dispatchEvent(new CustomEvent('save', { bubbles: true, composed: true }));
                }, 1200);
            })
            .catch((error) => {
                this.showToast('Error', error?.body?.message || 'Unable to update quote', 'error');
                this.showSpinner = false;
                this.isSubmitting = false;
                // Do not clear hasConfirmedSubmit — Cancel / Submit stay hidden after OK.
            });
    }
}