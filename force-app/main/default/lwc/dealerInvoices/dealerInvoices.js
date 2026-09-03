import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';

import getMyInvoices from '@salesforce/apex/InvoiceController.getMyInvoices';
import getGrnsForInvoice from '@salesforce/apex/GrnController.getGrnsForInvoice';
import getGrnLineItemsForInvoice from '@salesforce/apex/GrnController.getGrnLineItemsForInvoice';
import getGrnLineItemFiles from '@salesforce/apex/GrnController.getGrnLineItemFiles';
import getShowCreateGrnFlag from '@salesforce/apex/GrnController.getShowCreateGrnFlag';

const PORTAL_TOAST_DURATION_MS = 4000;

export default class DealerInvoices extends LightningElement {
    @track invoices = [];
    @track showInvoiceList = true;
    @track selectedInvoice = null;
    @track activeTab = 'details';
    @track selectedLineItemId = null;
    @track showCreateGrnModal = false;
    /** Feature_Setting__mdt.Default.Show_Create_GRN__c — true shows Create GRN */
    @track showCreateGrnButton = false;
    @track grnRows = [];
    @track grnLineRows = [];
    @track isLoadingGrn = false;
    @track selectedGrnId = null;
    @track selectedGrnLineId = null;
    @track selectedGrnLineFiles = [];
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';

    searchKey = '';
    wiredInvoicesResult;
    portalToastTimeout;

    connectedCallback() {
        this._boundShowList = () => this.backToList();
        window.addEventListener('portalshowlist', this._boundShowList);
        this.loadCreateGrnFeatureFlag();
    }

    async loadCreateGrnFeatureFlag() {
        try {
            this.showCreateGrnButton = await getShowCreateGrnFlag();
        } catch (e) {
            this.showCreateGrnButton = false;
        }
    }

    disconnectedCallback() {
        if (this._boundShowList) {
            window.removeEventListener('portalshowlist', this._boundShowList);
        }
    }

    @wire(getMyInvoices)
    wiredInvoices(result) {
        this.wiredInvoicesResult = result;
        if (result.data) {
            this.invoices = (result.data || []).map((o) => this.mapInvoice(o));
        } else if (result.error) {
            this.invoices = [];
            this.showToast('Error', this.extractErrorMessage(result.error), 'error');
        }
    }

    mapInvoice(o) {
        const accountName = o.Account__r?.Name || '—';
        const lineItemsRaw = o.Invoice_Line_item__r || [];

        return {
            ...o,
            accountName,
            invoiceLabel: o.Name || o.Bill_Doc_No__c || 'Invoice',
            ownerName: this.formatOwnerName(o.Owner),
            createdDate: this.formatDateDisplay(o.CreatedDate, false),
            billDateDisplay: this.formatDateDisplay(o.Bill_Date__c),

            invoiceNumberDisplay: this.displayOrNotSet(o.Name),
            soNumberDisplay: this.displayOrNotSet(o.SO_No__c),
            accDocNumberDisplay: this.displayOrNotSet(o.Acc_Doc_No__c),
            soldToDisplay: this.displayOrNotSet(o.Sold_To__c),
            excRateDisplay: this.displayOrNotSet(o.Exc_Rate__c),
            billDocTypeDisplay: this.displayOrNotSet(o.Bill_Doc_Type__c),
            currencyDisplay: this.displayOrNotSet(o.CurrencyIsoCode || o.Currency__c),
            netValueDisplay: this.displayOrNotSet(o.Net_Value__c),
            taxValueDisplay: this.displayOrNotSet(o.Tax_Value__c),

            billToDisplay: this.displayOrNotSet(o.Bill_To__c),
            payerDisplay: this.displayOrNotSet(o.Payer__c),
            termsOfPaymentDisplay: this.displayOrNotSet(o.Terms_Of_Payment__c),
            incotermsDisplay: this.displayOrNotSet(o.Incoterms__c),

            billDocNoClass: this.valueClass(o.Bill_Doc_No__c),
            soNumberClass: this.valueClass(o.SO_No__c),
            netValueClass: this.valueClass(o.Net_Value__c),
            taxValueClass: this.valueClass(o.Tax_Value__c),

            lineItems: lineItemsRaw.map((li, index) => ({
                id: li.Id,
                itemNumberDisplay: String(index + 1),
                itemDisplay: this.displayOrNotSet(li.Product__r?.Name || li.Product_Description__c),
                itemCodeDisplay: this.displayOrNotSet(li.Item_Code__c),
                uomDisplay: this.displayOrNotSet(li.UOM__c),
                unitPriceDisplay: this.displayOrNotSet(li.Unit_Price__c),
                gstAmountDisplay: this.displayOrNotSet(li.GST_Amount__c),
                quantityDisplay: this.displayOrNotSet(li.Quantity__c || li.QTY__c),
                totalPriceDisplay: this.displayOrNotSet(li.Line_Amount__c),
                grnQtyDisplay: this.displayQty(li.GRN_Qty__c),
                pendingGrnQtyDisplay: this.displayQty(li.Pending_GRN_Qty__c)
            })),
            hasLineItems: lineItemsRaw.length > 0
        };
    }

    displayQty(value) {
        if (value === null || value === undefined || value === '') {
            return 'Not set';
        }
        return value;
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

    displayOrNotSet(value) {
        return value && String(value).trim() ? value : 'Not set';
    }

    displayDash(value) {
        return value !== null && value !== undefined && String(value).trim() !== ''
            ? value
            : '—';
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

    statusBadgeClass(status) {
        const s = (status || '').toLowerCase();
        if (s === 'complete') {
            return 'grn-status grn-status-complete';
        }
        if (s === 'partial') {
            return 'grn-status grn-status-partial';
        }
        return 'grn-status';
    }

    mapGrnRow(g) {
        return {
            id: g.Id,
            nameDisplay: this.displayDash(g.Name),
            dateDisplay: this.formatDateDisplay(g.GRN_Date__c, false),
            partnerDisplay: this.displayDash(g.Channel_Partner__r?.Name),
            receivedByDisplay: this.displayDash(g.Received_By__r?.Name),
            statusDisplay: this.displayDash(g.Status__c),
            statusClass: this.statusBadgeClass(g.Status__c),
            remarksDisplay: this.displayDash(g.Remarks__c)
        };
    }

    mapGrnLineRow(li) {
        return {
            id: li.Id,
            grnNameDisplay: this.displayDash(li.GRN__r?.Name),
            nameDisplay: this.displayDash(li.Name),
            productDisplay: this.displayDash(li.Product__r?.Name),
            productCodeDisplay: this.displayDash(li.Product__r?.ProductCode),
            orderedDisplay: this.displayDash(li.Ordered_Qty__c),
            receivedDisplay: this.displayDash(li.Received_Qty__c),
            pendingDisplay: this.displayDash(li.Pending_Qty__c),
            damageDisplay: this.displayDash(li.Damage_Qty__c),
            shortDisplay: this.displayDash(li.Short_Qty__c),
            acceptedDisplay: this.displayDash(li.Accepted_Qty__c),
            statusDisplay: this.displayDash(li.Status__c),
            statusClass: this.statusBadgeClass(li.Status__c),
            rejectionDisplay: this.displayDash(li.Rejection_Reason__c),
            remarksDisplay: this.displayDash(li.Remarks__c)
        };
    }

    get isDetailsTab() {
        return this.activeTab === 'details';
    }

    get isLineItemTab() {
        return this.activeTab === 'lineItem';
    }

    get isGrnTab() {
        return this.activeTab === 'grn';
    }

    get isGrnLineTab() {
        return this.activeTab === 'grnLine';
    }

    get detailsTabClass() {
        return this.isDetailsTab ? 'quote-tab quote-tab-active' : 'quote-tab';
    }

    get lineItemTabClass() {
        return this.isLineItemTab ? 'quote-tab quote-tab-active' : 'quote-tab';
    }

    get grnTabClass() {
        return this.isGrnTab ? 'quote-tab quote-tab-active' : 'quote-tab';
    }

    get grnLineTabClass() {
        return this.isGrnLineTab ? 'quote-tab quote-tab-active' : 'quote-tab';
    }

    get showLineItemListView() {
        return this.selectedLineItemId == null;
    }

    get showLineItemDetailView() {
        return this.selectedLineItemId != null;
    }

    get selectedLineItem() {
        if (!this.selectedInvoice || !this.selectedLineItemId) return null;
        return this.selectedInvoice.lineItems.find((li) => li.id === this.selectedLineItemId);
    }

    get hasGrns() {
        return this.grnRows && this.grnRows.length > 0;
    }

    get hasGrnLines() {
        return this.grnLineRows && this.grnLineRows.length > 0;
    }

    get showGrnListView() {
        return this.selectedGrnId == null;
    }

    get showGrnDetailView() {
        return this.selectedGrnId != null && this.selectedGrn != null;
    }

    get selectedGrn() {
        if (!this.selectedGrnId) return null;
        return this.grnRows.find((g) => g.id === this.selectedGrnId) || null;
    }

    get showGrnLineListView() {
        return this.selectedGrnLineId == null;
    }

    get showGrnLineDetailView() {
        return this.selectedGrnLineId != null && this.selectedGrnLine != null;
    }

    get selectedGrnLine() {
        if (!this.selectedGrnLineId) return null;
        return this.grnLineRows.find((l) => l.id === this.selectedGrnLineId) || null;
    }

    get hasGrnLineFiles() {
        return this.selectedGrnLineFiles && this.selectedGrnLineFiles.length > 0;
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        this.selectedLineItemId = null;
        this.selectedGrnId = null;
        this.selectedGrnLineId = null;
        this.selectedGrnLineFiles = [];
        if (this.activeTab === 'grn' || this.activeTab === 'grnLine') {
            this.loadGrnData();
        }
    }

    handleLineItemClick(event) {
        this.selectedLineItemId = event.currentTarget.dataset.id;
    }

    handleBackToLineItems() {
        this.selectedLineItemId = null;
    }

    handleGrnClick(event) {
        this.selectedGrnId = event.currentTarget.dataset.id;
    }

    handleBackToGrns() {
        this.selectedGrnId = null;
    }

    async handleGrnLineClick(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedGrnLineId = id;
        this.selectedGrnLineFiles = [];
        try {
            const files = await getGrnLineItemFiles({ lineItemId: id });
            this.selectedGrnLineFiles = (files || []).map((f) => ({
                id: f.id,
                title: f.title || 'File',
                size: f.size || '',
                uploadedDate: f.uploadedDate || ''
            }));
        } catch (error) {
            this.selectedGrnLineFiles = [];
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        }
    }

    handleBackToGrnLines() {
        this.selectedGrnLineId = null;
        this.selectedGrnLineFiles = [];
    }

    handleCreateGrn() {
        if (!this.selectedInvoice?.Id) {
            return;
        }
        this.showCreateGrnModal = true;
    }

    handleCloseCreateGrn() {
        this.showCreateGrnModal = false;
    }

    async handleGrnSaved(event) {
        const grnName = event?.detail?.grn?.Name || '';
        this.showCreateGrnModal = false;
        this.selectedGrnId = null;
        this.selectedGrnLineId = null;
        this.selectedGrnLineFiles = [];
        this.showToast(
            'Success',
            grnName ? `GRN ${grnName} created successfully.` : 'GRN created successfully.',
            'success'
        );
        await this.loadGrnData();
        if (this.wiredInvoicesResult) {
            await refreshApex(this.wiredInvoicesResult);
        }
        this.activeTab = 'grn';
    }

    async loadGrnData() {
        if (!this.selectedInvoice?.Id) {
            this.grnRows = [];
            this.grnLineRows = [];
            return;
        }
        this.isLoadingGrn = true;
        try {
            const [grns, lines] = await Promise.all([
                getGrnsForInvoice({ invoiceId: this.selectedInvoice.Id }),
                getGrnLineItemsForInvoice({ invoiceId: this.selectedInvoice.Id })
            ]);
            this.grnRows = (grns || []).map((g) => this.mapGrnRow(g));
            this.grnLineRows = (lines || []).map((li) => this.mapGrnLineRow(li));
        } catch (error) {
            this.grnRows = [];
            this.grnLineRows = [];
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoadingGrn = false;
        }
    }

    get filteredInvoices() {
        const key = (this.searchKey || '').trim().toLowerCase();
        if (!key) {
            return this.invoices;
        }
        return this.invoices.filter((o) => {
            return (
                (o.Name || '').toLowerCase().includes(key) ||
                (o.Bill_Doc_No__c || '').toLowerCase().includes(key) ||
                (o.SO_No__c || '').toLowerCase().includes(key) ||
                (o.accountName || '').toLowerCase().includes(key) ||
                (o.ownerName || '').toLowerCase().includes(key)
            );
        });
    }

    get hasInvoices() {
        return this.filteredInvoices && this.filteredInvoices.length > 0;
    }

    get invoiceInitials() {
        if (!this.selectedInvoice || !this.selectedInvoice.Name) {
            return 'I';
        }
        return this.selectedInvoice.Name.substring(0, 2).toUpperCase();
    }

    handleSearch(event) {
        this.searchKey = event.target.value || '';
    }

    async refreshSelectedInvoice() {
        if (this.wiredInvoicesResult) {
            await refreshApex(this.wiredInvoicesResult);
        }
        if (this.selectedInvoice) {
            const found = this.invoices.find((o) => o.Id === this.selectedInvoice.Id);
            if (found) {
                this.selectedInvoice = found;
            }
        }
    }

    async openInvoiceDetail(event) {
        const id = event.currentTarget.dataset.id;
        if (this.wiredInvoicesResult) {
            await refreshApex(this.wiredInvoicesResult);
        }
        const found = this.invoices.find((o) => o.Id === id);
        if (found) {
            this.selectedInvoice = found;
            this.activeTab = 'details';
            this.selectedLineItemId = null;
            this.selectedGrnId = null;
            this.selectedGrnLineId = null;
            this.selectedGrnLineFiles = [];
            this.grnRows = [];
            this.grnLineRows = [];
            this.showCreateGrnModal = false;
        }
    }

    backToList() {
        this.showInvoiceList = true;
        this.selectedInvoice = null;
        this.activeTab = 'details';
        this.selectedLineItemId = null;
        this.selectedGrnId = null;
        this.selectedGrnLineId = null;
        this.selectedGrnLineFiles = [];
        this.grnRows = [];
        this.grnLineRows = [];
        this.showCreateGrnModal = false;
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