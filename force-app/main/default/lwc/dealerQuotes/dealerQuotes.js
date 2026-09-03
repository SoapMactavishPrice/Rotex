import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getMyQuotes from '@salesforce/apex/QuoteController.getMyQuotes';
import getMyChannelPartnerAccountId from '@salesforce/apex/QuoteController.getMyChannelPartnerAccountId';
import getUpcomingActivities from '@salesforce/apex/QuoteController.getUpcomingActivities';
import getQuoteNotes from '@salesforce/apex/QuoteController.getQuoteNotes';
import getQuoteFiles from '@salesforce/apex/QuoteController.getQuoteFiles';
import addQuoteNote from '@salesforce/apex/QuoteController.addQuoteNote';
import saveQuoteAttachment from '@salesforce/apex/QuoteController.saveQuoteAttachment';
import updateQuoteStatus from '@salesforce/apex/QuoteController.updateQuoteStatus';

const STATUS_PATH_STEPS = [
    { label: 'Draft', value: 'Draft' },
    { label: 'Under Review by Sales Rep', value: 'Under Review by Sales Rep' },
    { label: 'Submit for SOA Approval', value: 'Submit for SOA Approval' },
    { label: 'Submitted to Customer', value: 'Submitted to Customer', aliases: ['Submitted'] },
    { label: 'Negotiation', value: 'Negotiation' },
    { label: 'Closed Won', value: 'Accepted', aliases: ['Closed Won'] },
    { label: 'Closed Lost', value: 'Closed Lost' },
    { label: 'Scrap Quote', value: 'Scrap Quote' }
];

/** List-filter tabs (lead-style). Always shown, including 0 counts. */
const STATUS_FILTER_TABS = [
    { label: 'Draft', value: 'Draft' },
    { label: 'SOA Approval', value: 'Submit for SOA Approval' },
    { label: 'Submitted', value: 'Submitted to Customer', aliases: ['Submitted'] },
    { label: 'Negotiation', value: 'Negotiation' },
    { label: 'Closed Won', value: 'Accepted', aliases: ['Closed Won'] },
    { label: 'Closed Lost', value: 'Closed Lost' },
    { label: 'Scrap', value: 'Scrap Quote' }
];

/** Hidden from Self quote path + status picklist */
const SELF_QUOTE_EXCLUDED_STATUSES = [
    'Under Review by Sales Rep',
    'Submitted to Customer'
];

/** Hidden from Secondary Customer quote path + status picklist */
const SECONDARY_QUOTE_EXCLUDED_STATUSES = [
    'Under Review by Sales Rep',
    'Submit for SOA Approval'
];

export default class DealerQuotes extends LightningElement {
    @track quotes = [];
    @track selectedQuote = null;
    @track showQuoteModal = false;
    @track editingQuoteId = null;
    @track discountQtyMode = false;
    @track showEditDiscountModal = false;
    @track showArcDiscountModal = false;
    @track quoteModalCartWide = false;
    @track quoteModalProductsWide = false;
    @track showSapModal = false;
    @track showArcSapModal = false;
    @track showAddProductModal = false;
    @track addProductCartWide = false;
    @track addProductProductsWide = false;
    @track addProductAccountId = null;
    @track addProductQuoteType = '';
    @track addProductQuoteRecordTypeName = '';
    @track addProductBusinessLine = '';
    @track addProductProductMode = 'catalogue';
    @track addProductUsePartnerProducts = false;
    @track lineItemPanelKey = 0;
    @track partnerAccountId = null;
    @track upcomingActivities = [];
    @track quoteNotes = [];
    @track quoteFiles = [];
    @track previewFile = null;
    @track showTaskModal = false;
    @track showEventModal = false;
    @track activeTab = 'details';
    @track showQuoteCreatedDialog = false;
    @track createdQuoteNumber = '';
    @track createdQuoteId = null;

    searchKey = '';
    selectedQuoteType = 'All';
    selectedStatus = 'All';
    noteText = '';
    wiredQuotesResult;
    quoteCreatedDialogTimeout;

    connectedCallback() {
        this._boundShowList = () => this.backToList();
        window.addEventListener('portalshowlist', this._boundShowList);
    }

    disconnectedCallback() {
        if (this._boundShowList) {
            window.removeEventListener('portalshowlist', this._boundShowList);
        }
    }

    @wire(getMyChannelPartnerAccountId)
    wiredPartner({ data }) {
        if (data) {
            this.partnerAccountId = data;
        }
    }

    @wire(getMyQuotes)
    wiredQuotes(result) {
        this.wiredQuotesResult = result;
        if (result.data) {
            this.quotes = (result.data || []).map((q) => this.mapQuote(q));
            this.openQuoteFromNotification();
        } else if (result.error) {
            this.quotes = [];
            this.showToast('Error', this.extractErrorMessage(result.error), 'error');
        }
    }

    openQuoteFromNotification() {
        let quoteId;
        try {
            quoteId = sessionStorage.getItem('portalOpenQuoteId');
            if (quoteId) {
                sessionStorage.removeItem('portalOpenQuoteId');
            }
        } catch (e) {
            return;
        }
        if (!quoteId) {
            return;
        }
        this.openQuoteById(quoteId);
    }

    mapQuote(q) {
        const accountName =
            q.Account?.Name ||
            q.QuoteAccount?.Name ||
            q.Account__r?.Name ||
            '—';

        return {
            ...q,
            accountName,
            contactName: q.Contact?.Name || '',
            quoteLabel: q.Name || q.QuoteNumber || 'Quote',
            relatedAccountId: q.QuoteAccountId || q.Account__c || q.AccountId || null,
            businessLine:
                q.Account?.Business_type__c ||
                q.QuoteAccount?.Business_type__c ||
                q.Account__r?.Business_type__c ||
                '',
            ownerName: this.formatOwnerName(q.CP_Owner_Name__r),
            createdDate: this.formatDateDisplay(q.CreatedDate, false),
            quoteDateDisplay: this.formatDateDisplay(q.Quote_Date__c),
            validTillDisplay: this.formatDateDisplay(q.Quote_Valid_Till__c),
            revDateDisplay: this.formatDateDisplay(q.Rev_Date__c),
            isMtaQuote: this.isMtaQuoteValue(q.MTA_Quote__c),
            poDateDisplay: this.formatDateDisplay(q.Customer_Reference_Date__c),
            deliveryDateDisplay: this.formatDateDisplay(q.RequestedDeliveryDate__c),
            quoteNumberDisplay: this.displayOrNotSet(q.QuoteNumber),
            statusDisplay: this.displayOrNotSet(q.Status),
            quoteTypeDisplay: this.displayOrNotSet(q.Quote_Type__c),
            recordTypeDisplay: this.displayOrNotSet(this.getQuoteRecordTypeLabel(q)),
            currencyDisplay: this.displayOrNotSet(q.CurrencyIsoCode),
            sapNumberDisplay: this.displayOrNotSet(q.SAP_Quotation_Number__c),
            revNoDisplay: this.displayOrNotSet(
                q.Rev_No__c !== null && q.Rev_No__c !== undefined ? String(q.Rev_No__c) : ''
            ),
            poNumberDisplay: this.displayOrNotSet(q.Customer_Reference_No__c),
            pbgRequiredDisplay: this.displayOrNotSet(q.PBG_or_BG_required__c),
            pbgCommentsDisplay: this.displayOrNotSet(q.PBG_or_BG_comments__c),
            ldApplicableDisplay: this.displayOrNotSet(q.LD_Clause_Applicable__c),
            ldCommentsDisplay: this.displayOrNotSet(q.LD_Clause_comments__c),
            validityDisplay: this.displayOrNotSet(q.Validity_of_Offer__c),
            requestedValidityDisplay: this.displayOrNotSet(q.Requested_Validity_Of_Offer__c),
            deliveryPeriodDisplay: this.displayOrNotSet(q.Delivery_Period__c),
            incoDisplay: this.displayOrNotSet(q.INCO_Terms__c),
            paymentDisplay: this.displayOrNotSet(q.Payment_Terms__c),
            pricesDisplay: this.displayOrNotSet(q.Prices__c),
            warrantyDisplay: this.displayOrNotSet(q.Warranty_Terms__c),
            requestedWarrantyDisplay: this.displayOrNotSet(q.Warranty_Terms_Draft__c),
            liquidateDisplay: this.displayOrNotSet(q.Liquidate_Terms__c),
            transportDisplay: this.displayOrNotSet(q.Transport_Details__c),
            deliveryLocationDisplay: this.displayOrNotSet(q.Delivery_Location__c),
            remarksDisplay: this.displayOrNotSet(q.Special_Remarks__c),
            contactDisplay: this.displayOrNotSet(q.Contact?.Name),
            phoneDisplay: this.displayOrNotSet(q.Phone),
            emailDisplay: this.displayOrNotSet(q.Email),
            billPartyDisplay: this.displayOrNotSet(q.Bill_To_Party_Code__c),
            billStreetDisplay: this.displayOrNotSet(q.Bill_To_Street__c),
            billCityDisplay: this.displayOrNotSet(q.Bill_To_City__c),
            billPostalDisplay: this.displayOrNotSet(q.Bill_To_Postal_Code__c),
            billStateDisplay: this.displayOrNotSet(q.Bill_To_State__c),
            billCountryDisplay: this.displayOrNotSet(q.Bill_To_Country__c),
            shipPartyDisplay: this.displayOrNotSet(q.Ship_To_Party_Code__c),
            shipStreetDisplay: this.displayOrNotSet(q.Ship_To_Street__c),
            shipCityDisplay: this.displayOrNotSet(q.Ship_To_City__c),
            shipPostalDisplay: this.displayOrNotSet(q.Ship_To_Postal_Code__c),
            shipStateDisplay: this.displayOrNotSet(q.Ship_To_State__c),
            shipCountryDisplay: this.displayOrNotSet(q.Ship_To_Country__c),
            statusClass: this.valueClass(q.Status),
            quoteTypeClass: this.valueClass(q.Quote_Type__c),
            recordTypeClass: this.valueClass(this.getQuoteRecordTypeLabel(q)),
            currencyClass: this.valueClass(q.CurrencyIsoCode),
            sapClass: this.valueClass(q.SAP_Quotation_Number__c),
            revNoClass: this.valueClass(
                q.Rev_No__c !== null && q.Rev_No__c !== undefined ? String(q.Rev_No__c) : ''
            ),
            poNumberClass: this.valueClass(q.Customer_Reference_No__c),
            pbgRequiredClass: this.valueClass(q.PBG_or_BG_required__c),
            pbgCommentsClass: this.valueClass(q.PBG_or_BG_comments__c),
            ldApplicableClass: this.valueClass(q.LD_Clause_Applicable__c),
            ldCommentsClass: this.valueClass(q.LD_Clause_comments__c),
            validityClass: this.valueClass(q.Validity_of_Offer__c),
            requestedValidityClass: this.valueClass(q.Requested_Validity_Of_Offer__c),
            deliveryPeriodClass: this.valueClass(q.Delivery_Period__c),
            incoClass: this.valueClass(q.INCO_Terms__c),
            paymentClass: this.valueClass(q.Payment_Terms__c),
            pricesClass: this.valueClass(q.Prices__c),
            warrantyClass: this.valueClass(q.Warranty_Terms__c),
            requestedWarrantyClass: this.valueClass(q.Warranty_Terms_Draft__c),
            liquidateClass: this.valueClass(q.Liquidate_Terms__c),
            transportClass: this.valueClass(q.Transport_Details__c),
            deliveryLocationClass: this.valueClass(q.Delivery_Location__c),
            remarksClass: this.valueClass(q.Special_Remarks__c),
            contactClass: this.valueClass(q.Contact?.Name),
            phoneClass: this.valueClass(q.Phone),
            emailClass: this.valueClass(q.Email),
            billPartyClass: this.valueClass(q.Bill_To_Party_Code__c),
            billStreetClass: this.valueClass(q.Bill_To_Street__c),
            billCityClass: this.valueClass(q.Bill_To_City__c),
            billPostalClass: this.valueClass(q.Bill_To_Postal_Code__c),
            billStateClass: this.valueClass(q.Bill_To_State__c),
            billCountryClass: this.valueClass(q.Bill_To_Country__c),
            shipPartyClass: this.valueClass(q.Ship_To_Party_Code__c),
            shipStreetClass: this.valueClass(q.Ship_To_Street__c),
            shipCityClass: this.valueClass(q.Ship_To_City__c),
            shipPostalClass: this.valueClass(q.Ship_To_Postal_Code__c),
            shipStateClass: this.valueClass(q.Ship_To_State__c),
            shipCountryClass: this.valueClass(q.Ship_To_Country__c),
            quoteDateClass: this.valueClass(q.Quote_Date__c),
            validTillClass: this.valueClass(q.Quote_Valid_Till__c),
            revDateClass: this.valueClass(q.Rev_Date__c),
            poDateClass: this.valueClass(q.Customer_Reference_Date__c),
            deliveryDateClass: this.valueClass(q.RequestedDeliveryDate__c),
            showPbgComments: q.PBG_or_BG_required__c === 'Yes',
            showLdComments: q.LD_Clause_Applicable__c === 'Yes'
        };
    }
    formatOwnerName(owner) {
        if (!owner) {
            return '—';
        }
        const firstLast = [owner.FirstName, owner.LastName]
            .filter((part) => part && String(part).trim())
            .join(' ')
            .trim();
        if (firstLast) {
            return firstLast;
        }
        const name = owner.Name ? String(owner.Name).trim() : '';
        if (name && !/^User\d{8,}$/i.test(name)) {
            return name;
        }
        if (owner.Email && String(owner.Email).trim()) {
            return owner.Email;
        }
        return name || '—';
    }

    get statusPathSteps() {
        const current = this.normalizeStatus(this.selectedQuote?.Status);
        const steps = this.getStatusPathStepsForQuote();
        const currentIndex = steps.findIndex((step) => this.statusMatches(step, current));
        const clickable = this.isSecondaryCustomerSelectedQuote;
        return steps.map((step, index) => ({
            label: step.label,
            key: step.value,
            value: step.value,
            className: this.statusPathClass(index, currentIndex, clickable),
            title: clickable ? 'Click to update status' : step.label
        }));
    }

    get isSecondaryCustomerSelectedQuote() {
        const quoteType = String(this.selectedQuote?.Quote_Type__c || '')
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        return quoteType === 'SECONDARY CUSTOMER';
    }

    getStatusPathStepsForQuote() {
        const quoteType = String(this.selectedQuote?.Quote_Type__c || '')
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        if (quoteType === 'SELF') {
            return STATUS_PATH_STEPS.filter(
                (step) => !SELF_QUOTE_EXCLUDED_STATUSES.includes(step.value)
            );
        }
        if (quoteType === 'SECONDARY CUSTOMER') {
            return STATUS_PATH_STEPS.filter(
                (step) => !SECONDARY_QUOTE_EXCLUDED_STATUSES.includes(step.value)
            );
        }
        return STATUS_PATH_STEPS;
    }

    statusMatches(step, current) {
        const values = [step.value, step.label, ...(step.aliases || [])];
        return values.some((value) => this.normalizeStatus(value) === current);
    }

    statusPathClass(index, currentIndex, clickable) {
        let className = 'status-path-step';
        if (index === currentIndex) {
            className += ' status-path-step-current';
        } else if (currentIndex > -1 && index < currentIndex) {
            className += ' status-path-step-complete';
        }
        if (clickable) {
            className += ' status-path-step-clickable';
        }
        return className;
    }

    handleStatusPathClick(event) {
        if (!this.isSecondaryCustomerSelectedQuote || !this.selectedQuote?.Id) {
            return;
        }
        const status = event.currentTarget.dataset.status;
        if (!status || status === this.selectedQuote.Status) {
            return;
        }

        updateQuoteStatus({ quoteId: this.selectedQuote.Id, status })
            .then((updated) => {
                const mapped = this.mapQuote(updated);
                this.selectedQuote = mapped;
                this.quotes = (this.quotes || []).map((q) => (q.Id === mapped.Id ? mapped : q));
                this.showToast('Success', 'Quote status updated to ' + mapped.Status, 'success');
                return refreshApex(this.wiredQuotesResult);
            })
            .catch((error) => {
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    normalizeStatus(value) {
        return (value || '').toLowerCase().replace(/\s+/g, ' ').trim();
    }

    displayOrNotSet(value) {
        return value && String(value).trim() ? value : 'Not set';
    }

    getQuoteRecordTypeLabel(q) {
        const name = q?.RecordType?.Name || q?.RecordType?.DeveloperName || q?.RecordTypeName || '';
        const normalized = String(name).trim().toUpperCase().replace(/\s+/g, '_');
        if (!normalized) {
            return '';
        }
        if (normalized === 'ARC' || normalized.includes('ARC')) {
            return 'ARC';
        }
        if (normalized === 'NORMAL' || normalized.includes('NORMAL')) {
            return 'Normal';
        }
        return q?.RecordType?.Name || name;
    }

    valueClass(value) {
        return value && String(value).trim()
            ? 'info-row-value'
            : 'info-row-value value-empty';
    }

    formatDateDisplay(value, emptyAsNotSet = true) {
        if (!value) {
            return emptyAsNotSet ? 'Not set' : '—';
        }
        try {
            return new Date(value).toLocaleDateString('en-GB', {
                day: '2-digit',
                month: 'short',
                year: 'numeric'
            });
        } catch (e) {
            return String(value);
        }
    }

    isMtaQuoteValue(value) {
        return value === true || value === 'true' || value === 1 || value === '1';
    }

    get isDetailsTab() {
    return this.activeTab === 'details';
}
get isLineItemTab() {
    return this.activeTab === 'lineItem';
}
get detailsTabClass() {
    return this.isDetailsTab ? 'quote-tab quote-tab-active' : 'quote-tab';
}
get lineItemTabClass() {
    return this.isLineItemTab ? 'quote-tab quote-tab-active' : 'quote-tab';
}

    /** Add Product: only when quote Status is Draft. */
    get showAddProductButton() {
        if (!this.selectedQuote) {
            return false;
        }
        const status = String(this.selectedQuote.Status || '')
            .trim()
            .toLowerCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        return status === 'draft';
    }

    /** ARC Discount Approval: Draft + Quote Record Type ARC */
    get showArcDiscountApproval() {
        if (!this.selectedQuote) {
            return false;
        }
        const status = String(this.selectedQuote.Status || '')
            .trim()
            .toLowerCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        if (status !== 'draft') {
            return false;
        }
        const rt =
            this.selectedQuote.RecordType?.DeveloperName ||
            this.selectedQuote.RecordType?.Name ||
            this.selectedQuote.RecordTypeName ||
            '';
        const normalizedRt = String(rt)
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        return normalizedRt === 'ARC' || normalizedRt.includes('ARC');
    }

    /** Submit for approval: Self quotes in Draft only. After OK → status SOA → button hidden. */
    get showSubmitForApproval() {
        if (!this.selectedQuote) {
            return false;
        }
        const quoteType = String(this.selectedQuote.Quote_Type__c || '')
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        if (quoteType !== 'SELF') {
            return false;
        }
        const status = String(this.selectedQuote.Status || '')
            .trim()
            .toLowerCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        return status === 'draft' || status === '';
    }

    /** Push to SAP: Self quotes only, and only when status is Closed Won (Accepted). */
    get showPushQuoteToSap() {
        if (!this.selectedQuote) {
            return false;
        }
        const quoteType = String(this.selectedQuote.Quote_Type__c || '')
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        if (quoteType !== 'SELF') {
            return false;
        }
        const status = String(this.selectedQuote.Status || '')
            .trim()
            .toLowerCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        return status === 'accepted' || status === 'closed won';
    }

    /** Push ARC to SAP: Record Type ARC + status Closed Won (Accepted). */
    get showPushArcToSap() {
        if (!this.selectedQuote) {
            return false;
        }
        const rt =
            this.selectedQuote.RecordType?.DeveloperName ||
            this.selectedQuote.RecordType?.Name ||
            this.selectedQuote.RecordTypeName ||
            '';
        const normalizedRt = String(rt)
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        if (!(normalizedRt === 'ARC' || normalizedRt.includes('ARC'))) {
            return false;
        }
        const status = String(this.selectedQuote.Status || '')
            .trim()
            .toLowerCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        return status === 'accepted' || status === 'closed won';
    }

handleTabClick(event) {
    this.activeTab = event.currentTarget.dataset.tab;
}

    get filteredQuotes() {
        const key = (this.searchKey || '').trim().toLowerCase();
        return (this.quotes || []).filter((q) => {
            const matchesType =
                this.selectedQuoteType === 'All' ||
                q.Quote_Type__c === this.selectedQuoteType;

            if (!matchesType) {
                return false;
            }

            const matchesStatus =
                this.selectedStatus === 'All' ||
                this.statusMatchesFilter(q.Status, this.selectedStatus);

            if (!matchesStatus) {
                return false;
            }

            if (!key) {
                return true;
            }

            return (
                (q.Name || '').toLowerCase().includes(key) ||
                (q.QuoteNumber || '').toLowerCase().includes(key) ||
                (q.accountName || '').toLowerCase().includes(key) ||
                (q.Status || '').toLowerCase().includes(key) ||
                (q.Quote_Type__c || '').toLowerCase().includes(key) ||
                (q.contactName || '').toLowerCase().includes(key) ||
                (q.ownerName || '').toLowerCase().includes(key)
            );
        });
    }

    get hasQuotes() {
        return this.filteredQuotes && this.filteredQuotes.length > 0;
    }

    get totalQuoteCount() {
        return (this.quotes || []).length;
    }

    get selfQuoteCount() {
        return (this.quotes || []).filter((q) => q.Quote_Type__c === 'Self').length;
    }

    get secondaryQuoteCount() {
        return (this.quotes || []).filter(
            (q) => q.Quote_Type__c === 'Secondary Customer'
        ).length;
    }

    get quoteTypeFilterOptions() {
        return [
            {
                label: `All (${this.totalQuoteCount})`,
                value: 'All',
                selected: this.selectedQuoteType === 'All'
            },
            {
                label: `Self (${this.selfQuoteCount})`,
                value: 'Self',
                selected: this.selectedQuoteType === 'Self'
            },
            {
                label: `Secondary Customer (${this.secondaryQuoteCount})`,
                value: 'Secondary Customer',
                selected: this.selectedQuoteType === 'Secondary Customer'
            }
        ];
    }

    get allStatusTabClass() {
        return this.selectedStatus === 'All' ? 'tab active' : 'tab';
    }

    get statusTabItems() {
        return STATUS_FILTER_TABS.map((tab) => {
            const keys = [tab.value, ...(tab.aliases || [])];
            const count = (this.quotes || []).filter((q) =>
                keys.some((key) => this.statusMatchesFilter(q.Status, key))
            ).length;
            const isActive =
                this.selectedStatus !== 'All' &&
                keys.some(
                    (key) =>
                        this.normalizeStatus(this.selectedStatus) ===
                            this.normalizeStatus(key) ||
                        this.statusMatchesFilter(this.selectedStatus, key)
                );
            return {
                label: tab.label,
                value: tab.value,
                count,
                tabClass: isActive ? 'tab active' : 'tab'
            };
        });
    }

    statusMatchesFilter(quoteStatus, filterValue) {
        if (!filterValue || filterValue === 'All') {
            return true;
        }
        const normalizedQuote = this.normalizeStatus(quoteStatus);
        const normalizedFilter = this.normalizeStatus(filterValue);
        if (normalizedQuote === normalizedFilter) {
            return true;
        }
        const allSteps = [...STATUS_PATH_STEPS, ...STATUS_FILTER_TABS];
        for (const step of allSteps) {
            const keys = [step.value, ...(step.aliases || [])].map((v) =>
                this.normalizeStatus(v)
            );
            if (keys.includes(normalizedFilter) && keys.includes(normalizedQuote)) {
                return true;
            }
        }
        return false;
    }

    get quoteInitials() {
        if (!this.selectedQuote || !this.selectedQuote.Name) {
            return 'Q';
        }
        const parts = this.selectedQuote.Name.trim().split(/\s+/);
        if (parts.length >= 2) {
            return (parts[0][0] + parts[1][0]).toUpperCase();
        }
        return this.selectedQuote.Name.substring(0, 2).toUpperCase();
    }

    handleSearch(event) {
        this.searchKey = event.target.value || '';
    }

    handleListFilterChange(event) {
        const filter = event.target.dataset.filter;
        const value = event.target.value || 'All';
        if (filter === 'quoteType') {
            this.selectedQuoteType = value;
        }
    }

    handleStatusFilter(event) {
        this.selectedStatus = event.currentTarget.dataset.status || 'All';
    }

    handleCreateQuote() {
        this.editingQuoteId = null;
        this.discountQtyMode = false;
        this.showQuoteModal = true;
    }

    handleEditQuote() {
        if (!this.selectedQuote) {
            return;
        }
        this.editingQuoteId = this.selectedQuote.Id;
        this.discountQtyMode = false;
        this.showQuoteModal = true;
    }

    handleEditDiscountQty() {
        if (!this.selectedQuote) {
            return;
        }
        this.showEditDiscountModal = true;
    }

    closeEditDiscountModal() {
        this.showEditDiscountModal = false;
    }

    async handleEditDiscountSaved() {
        this.closeEditDiscountModal();
        this.lineItemPanelKey = Date.now();
        await this.refreshSelectedQuote();
    }

    handleArcDiscountApproval() {
        if (!this.selectedQuote) {
            return;
        }
        this.showArcDiscountModal = true;
    }

    closeArcDiscountModal() {
        this.showArcDiscountModal = false;
    }

    async handleArcDiscountSaved() {
        this.closeArcDiscountModal();
        this.lineItemPanelKey = Date.now();
        await this.refreshSelectedQuote();
    }

    handlePushQuoteToSap() {
        if (!this.selectedQuote) {
            return;
        }
        this.showSapModal = true;
    }

    closeSapModal() {
        this.showSapModal = false;
    }

    async handleSapQuoteSaved() {
        await this.refreshSelectedQuote();
    }

    handlePushArcToSap() {
        if (!this.selectedQuote) {
            return;
        }
        this.showArcSapModal = true;
    }

    closeArcSapModal() {
        this.showArcSapModal = false;
    }

    async handleArcSapSaved() {
        await this.refreshSelectedQuote();
    }

    handleQuotePdfSaved() {
        if (this.selectedQuote?.Id) {
            this.loadQuoteFiles(this.selectedQuote.Id);
        }
    }

    handleAddProduct() {
        if (!this.selectedQuote) {
            return;
        }
        const q = this.selectedQuote;
        const accountId = q.relatedAccountId || q.AccountId || q.QuoteAccountId || q.Account__c || null;
        const quoteType = q.Quote_Type__c || '';
        const businessLine = q.businessLine || '';
        const normalizedType = String(quoteType)
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        const normalizedBl = String(businessLine)
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');

        let productMode = '';
        let usePartnerProducts = false;
        const quoteRecordTypeName =
            q.RecordType?.DeveloperName || q.RecordType?.Name || q.RecordTypeName || '';
        const normalizedRt = String(quoteRecordTypeName)
            .trim()
            .toUpperCase()
            .replace(/[-_]+/g, ' ')
            .replace(/\s+/g, ' ');
        const isArcQuoteType = normalizedRt === 'ARC' || normalizedRt.includes('ARC');
        // Match New Quote create flow product sources
        if (normalizedType === 'SECONDARY CUSTOMER') {
            // Secondary ARC: Rotex catalogue only (Item Type + Search). Normal unchanged.
            if (isArcQuoteType) {
                productMode = 'catalogue';
                usePartnerProducts = false;
            } else if (normalizedBl === 'NON ROTEX') {
                productMode = 'partner';
                usePartnerProducts = true;
            } else if (normalizedBl === 'ROTEX') {
                productMode = 'catalogue';
            } else if (normalizedBl === 'BOTH') {
                productMode = 'both';
            } else {
                productMode = 'catalogue';
            }
        } else {
            // Self — same catalogue path as create quote
            productMode = 'catalogue';
        }

        // Create Self uses CP account; Secondary uses related customer (catalogue still uses partnerAccountId)
        this.addProductAccountId =
            normalizedType === 'SECONDARY CUSTOMER'
                ? accountId
                : this.partnerAccountId || accountId;
        this.addProductQuoteType = quoteType || (normalizedType === 'SELF' ? 'Self' : quoteType);
        this.addProductQuoteRecordTypeName = quoteRecordTypeName;
        this.addProductBusinessLine =
            normalizedType === 'SECONDARY CUSTOMER' ? businessLine : '';
        this.addProductProductMode = productMode;
        this.addProductUsePartnerProducts = usePartnerProducts;
        this.addProductProductsWide = true;
        this.addProductCartWide = false;
        this.showAddProductModal = true;
    }

    closeAddProductModal() {
        this.showAddProductModal = false;
        this.addProductProductsWide = false;
        this.addProductCartWide = false;
        this.addProductAccountId = null;
        this.addProductQuoteType = '';
        this.addProductQuoteRecordTypeName = '';
        this.addProductBusinessLine = '';
        this.addProductProductMode = 'catalogue';
        this.addProductUsePartnerProducts = false;
    }

    handleAddProductCartViewChange(event) {
        const layout = event?.detail?.layout;
        if (layout === 'cart') {
            this.addProductCartWide = true;
            this.addProductProductsWide = false;
        } else if (layout === 'products') {
            this.addProductCartWide = false;
            this.addProductProductsWide = true;
        } else {
            this.addProductCartWide = false;
            this.addProductProductsWide = false;
        }
    }

    get addProductModalHostClass() {
        if (this.addProductCartWide) {
            return 'quote-modal-host quote-modal-host--cart';
        }
        if (this.addProductProductsWide) {
            return 'quote-modal-host quote-modal-host--products';
        }
        return 'quote-modal-host quote-modal-host--products';
    }

    get addProductModalStopClass() {
        // Detail-only stop classes — do not reuse create's quote-modal-stop--products
        if (this.addProductCartWide) {
            return 'quote-modal-stop quote-modal-stop--add-product-cart';
        }
        return 'quote-modal-stop quote-modal-stop--add-product';
    }

    get addProductShellClass() {
        return this.addProductCartWide
            ? 'add-product-shell add-product-shell--cart'
            : 'add-product-shell add-product-shell--products';
    }

    get addProductModalTitle() {
        return this.addProductCartWide ? 'Edit Selected Products' : 'Add Products';
    }

    get addProductModalKey() {
        return `add-product-${this.selectedQuote?.Id || 'none'}`;
    }

    async handleAddProductSaved() {
        this.closeAddProductModal();
        this.lineItemPanelKey = Date.now();
        await this.refreshSelectedQuote();
    }

    closeQuoteModal() {
        this.showQuoteModal = false;
        this.editingQuoteId = null;
        this.discountQtyMode = false;
        this.quoteModalCartWide = false;
        this.quoteModalProductsWide = false;
    }

    stopQuoteModalBubble(event) {
        event.stopPropagation();
    }

    handleQuoteCartViewChange(event) {
        const layout = event?.detail?.layout;
        if (layout === 'cart') {
            this.quoteModalCartWide = true;
            this.quoteModalProductsWide = false;
        } else if (layout === 'products') {
            this.quoteModalCartWide = false;
            this.quoteModalProductsWide = true;
        } else {
            this.quoteModalCartWide = false;
            this.quoteModalProductsWide = false;
        }
    }

    get quoteModalHostClass() {
        if (this.quoteModalCartWide) {
            return 'quote-modal-host quote-modal-host--cart';
        }
        if (this.quoteModalProductsWide) {
            return 'quote-modal-host quote-modal-host--products';
        }
        return 'quote-modal-host';
    }

    get quoteModalStopClass() {
        if (this.quoteModalCartWide) {
            return 'quote-modal-stop quote-modal-stop--cart';
        }
        if (this.quoteModalProductsWide) {
            return 'quote-modal-stop quote-modal-stop--products';
        }
        return 'quote-modal-stop';
    }

    get quoteModalKey() {
        return `${this.editingQuoteId || 'new'}-${this.discountQtyMode}`;
    }

    get hasCreatedQuoteNumber() {
        return !!(this.createdQuoteNumber || '').trim();
    }

    async handleQuoteSaved(event) {
        const detail = event?.detail || {};
        const created = detail.created === true;
        const quoteNumber =
            detail.quoteNumber ||
            detail.quote?.QuoteNumber ||
            detail.QuoteNumber ||
            '';
        const quoteId = detail.quote?.Id || detail.Id || null;
        const savedQuote = detail.quote || null;

        this.closeQuoteModal();
        await this.refreshSelectedQuote();

        if (created && quoteId) {
            this.openQuoteById(quoteId, savedQuote);
            this.showQuoteCreatedPopup(quoteNumber, quoteId);
        }
    }

    openQuoteById(quoteId, fallbackQuote) {
        if (!quoteId) {
            return;
        }
        const found = this.quotes.find((q) => q.Id === quoteId) || fallbackQuote;
        if (!found) {
            return;
        }
        this.selectedQuote = found;
        this.resetSidebarState();
        this.loadQuoteSidebar(found.Id);
    }

    showQuoteCreatedPopup(quoteNumber, quoteId) {
        if (this.quoteCreatedDialogTimeout) {
            window.clearTimeout(this.quoteCreatedDialogTimeout);
            this.quoteCreatedDialogTimeout = null;
        }
        this.createdQuoteNumber = quoteNumber || '';
        this.createdQuoteId = quoteId || null;
        this.showQuoteCreatedDialog = true;
        this.quoteCreatedDialogTimeout = window.setTimeout(() => {
            this.closeQuoteCreatedDialog();
        }, 5000);
    }

    closeQuoteCreatedDialog() {
        if (this.quoteCreatedDialogTimeout) {
            window.clearTimeout(this.quoteCreatedDialogTimeout);
            this.quoteCreatedDialogTimeout = null;
        }
        this.showQuoteCreatedDialog = false;
        this.createdQuoteNumber = '';
        this.createdQuoteId = null;
    }

    openCreatedQuote() {
        const id = this.createdQuoteId;
        this.closeQuoteCreatedDialog();
        this.openQuoteById(id);
    }

    async refreshSelectedQuote() {
        if (this.wiredQuotesResult) {
            await refreshApex(this.wiredQuotesResult);
        }
        if (this.selectedQuote) {
            const found = this.quotes.find((q) => q.Id === this.selectedQuote.Id);
            if (found) {
                this.selectedQuote = found;
            }
        }
    }

  async openQuoteDetail(event) {
    const id = event.currentTarget.dataset.id;

    if (this.wiredQuotesResult) {
        await refreshApex(this.wiredQuotesResult);
    }

    const found = this.quotes.find((q) => q.Id === id);
    if (found) {
        this.selectedQuote = found;
        this.resetSidebarState();
        this.loadQuoteSidebar(found.Id);
    }
}

    backToList() {
        this.selectedQuote = null;
        this.resetSidebarState();
    }

    resetSidebarState() {
        this.upcomingActivities = [];
        this.quoteNotes = [];
        this.quoteFiles = [];
        this.noteText = '';
        this.previewFile = null;
        this.showTaskModal = false;
        this.showEventModal = false;
        this.activeTab = 'details'; 
    }

    loadQuoteSidebar(quoteId) {
        this.loadUpcomingActivities(quoteId);
        this.loadQuoteNotes(quoteId);
        this.loadQuoteFiles(quoteId);
    }

    loadUpcomingActivities(quoteId) {
        getUpcomingActivities({ quoteId })
            .then((data) => {
                this.upcomingActivities = data || [];
            })
            .catch((error) => {
                console.error(error);
            });
    }

    get hasUpcomingActivities() {
        return this.upcomingActivities && this.upcomingActivities.length > 0;
    }

    handleNewTask() {
        if (!this.selectedQuote) {
            return;
        }
        this.showTaskModal = true;
    }

    closeTaskModal() {
        this.showTaskModal = false;
    }

    handleTaskSaved(event) {
        const summary = event.detail;
        if (summary) {
            this.upcomingActivities = [...this.upcomingActivities, summary];
        } else if (this.selectedQuote) {
            this.loadUpcomingActivities(this.selectedQuote.Id);
        }
        this.showTaskModal = false;
    }

    handleNewEvent() {
        if (!this.selectedQuote) {
            return;
        }
        this.showEventModal = true;
    }

    closeEventModal() {
        this.showEventModal = false;
    }

    handleEventSaved(event) {
        const summary = event.detail;
        if (summary) {
            this.upcomingActivities = [...this.upcomingActivities, summary];
        } else if (this.selectedQuote) {
            this.loadUpcomingActivities(this.selectedQuote.Id);
        }
        this.showEventModal = false;
    }

    handleNoteChange(event) {
        this.noteText = event.target.value;
    }

    handleAddNote() {
        if (!this.noteText || !this.noteText.trim() || !this.selectedQuote) {
            return;
        }

        const quoteId = this.selectedQuote.Id;
        const bodyText = this.noteText.trim();
        this.noteText = '';

        addQuoteNote({ quoteId, noteBody: bodyText })
            .then((newNote) => {
                if (newNote && newNote.id) {
                    this.quoteNotes = [newNote, ...this.quoteNotes];
                } else {
                    this.loadQuoteNotes(quoteId);
                }
            })
            .catch((error) => {
                this.noteText = bodyText;
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    loadQuoteNotes(quoteId) {
        getQuoteNotes({ quoteId })
            .then((data) => {
                this.quoteNotes = data || [];
            })
            .catch((error) => {
                console.error(error);
            });
    }

    get hasNotes() {
        return this.quoteNotes && this.quoteNotes.length > 0;
    }

    loadQuoteFiles(quoteId) {
        getQuoteFiles({ quoteId })
            .then((data) => {
                this.quoteFiles = data || [];
            })
            .catch((error) => {
                console.error(error);
            });
    }

    get hasFiles() {
        return this.quoteFiles && this.quoteFiles.length > 0;
    }

    handleFilePreview(event) {
        const fileId = event.currentTarget.dataset.id;
        const file = this.quoteFiles.find((item) => item.id === fileId);
        if (!file || !file.versionId) {
            return;
        }

        const downloadUrl = '/sfc/servlet.shepherd/version/download/' + file.versionId;
        const type = (file.fileType || '').toUpperCase();
        const imageTypes = ['PNG', 'JPG', 'JPEG', 'GIF', 'WEBP', 'BMP', 'SVG'];

        this.previewFile = {
            title: file.title,
            url: downloadUrl,
            isImage: imageTypes.includes(type),
            isPdf: type === 'PDF'
        };
    }

    closeFilePreview() {
        this.previewFile = null;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    get hasFilePreview() {
        return this.previewFile !== null;
    }

    handleFileInputChange(event) {
        const files = event.target.files;
        if (!files || files.length === 0) {
            return;
        }

        Array.from(files).forEach((file) => {
            this.uploadFile(file);
        });
        event.target.value = '';
    }

    uploadFile(file) {
        if (!this.selectedQuote) {
            return;
        }

        const quoteId = this.selectedQuote.Id;
        const reader = new FileReader();

        reader.onload = () => {
            const base64Data = reader.result.split(',')[1];
            saveQuoteAttachment({
                quoteId,
                fileName: file.name,
                base64Data
            })
                .then((newFile) => {
                    this.quoteFiles = [newFile, ...this.quoteFiles];
                })
                .catch((error) => {
                    this.showToast('Error', this.extractErrorMessage(error), 'error');
                });
        };

        reader.onerror = () => {
            this.showToast('Error', 'Could not read file: ' + file.name, 'error');
        };

        reader.readAsDataURL(file);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant: variant || 'info'
            })
        );
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