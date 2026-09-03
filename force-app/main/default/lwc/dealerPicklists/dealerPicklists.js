import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';

import getMyPicklists from '@salesforce/apex/DealerPicklistController.getMyPicklists';
import getPicklistLineItems from '@salesforce/apex/DealerPicklistController.getPicklistLineItems';

const PORTAL_TOAST_DURATION_MS = 4000;

export default class DealerPicklists extends LightningElement {
    @track picklists = [];
    @track selectedPicklist = null;
    @track lineItems = [];
    @track selectedLineItem = null;
    @track activeTab = 'details';
    @track showCreateModal = false;
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';

    searchKey = '';
    wiredPicklistsResult;
    portalToastTimeout;

    connectedCallback() {
        this._boundShowList = () => this.backToList();
        window.addEventListener('portalshowlist', this._boundShowList);
    }

    disconnectedCallback() {
        if (this._boundShowList) {
            window.removeEventListener('portalshowlist', this._boundShowList);
        }
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }
    }

    @wire(getMyPicklists)
    wiredPicklists(result) {
        this.wiredPicklistsResult = result;
        if (result.data) {
            this.picklists = (result.data || []).map((p) => this.mapPicklist(p));
        } else if (result.error) {
            this.picklists = [];
            this.showToast('Error', this.extractErrorMessage(result.error), 'error');
        }
    }

    mapPicklist(p) {
        return {
            ...p,
            secondaryCustomerName: p.Secondary_Customer__r?.Name || '—',
            channelPartnerName: p.Channel_Partner__r?.Name || '—',
            pickListDateDisplay: this.formatDateDisplay(p.Pick_List_Date__c),
            requestedDeliveryDateDisplay: this.formatDateDisplay(p.Requested_Delivery_Date__c),
            remarksDisplay: this.displayOrNotSet(p.Remarks__c),
            ownerName: this.formatOwnerName(p.Owner),
            createdDate: this.formatDateDisplay(p.CreatedDate, false),
            numberDisplay: this.displayOrNotSet(p.Name),
            secondaryClass: this.valueClass(p.Secondary_Customer__r?.Name),
            partnerClass: this.valueClass(p.Channel_Partner__r?.Name),
            pickDateClass: this.valueClass(p.Pick_List_Date__c),
            deliveryDateClass: this.valueClass(p.Requested_Delivery_Date__c),
            remarksClass: this.valueClass(p.Remarks__c)
        };
    }

    mapLineItem(li) {
        const available = li.Inventory__r?.Available_Quantity__c;
        const pick = li.Pick_Quantity__c;
        const remaining =
            available != null && pick != null ? Number(available) - Number(pick) : null;
        return {
            ...li,
            lineNumberDisplay: this.displayOrNotSet(li.Name),
            productName: li.Product__r?.Name || '—',
            productCode: li.Product_Code__c || '—',
            inventoryName: li.Inventory__r?.Name || '—',
            availableQtyDisplay: this.formatNumber(available),
            pickQtyDisplay: this.formatNumber(pick),
            remainingQtyDisplay: this.formatNumber(remaining),
            remarksDisplay: this.displayOrNotSet(li.Remarks__c),
            productNameClass: this.valueClass(li.Product__r?.Name),
            productCodeClass: this.valueClass(li.Product_Code__c),
            inventoryNameClass: this.valueClass(li.Inventory__r?.Name),
            availableClass: this.valueClass(available),
            pickClass: this.valueClass(pick),
            remainingClass: this.valueClass(remaining),
            lineRemarksClass: this.valueClass(li.Remarks__c)
        };
    }

    get filteredPicklists() {
        const key = (this.searchKey || '').trim().toLowerCase();
        if (!key) {
            return this.picklists;
        }
        return this.picklists.filter((p) => {
            return (
                (p.Name || '').toLowerCase().includes(key) ||
                (p.secondaryCustomerName || '').toLowerCase().includes(key) ||
                (p.channelPartnerName || '').toLowerCase().includes(key) ||
                (p.ownerName || '').toLowerCase().includes(key) ||
                (p.Remarks__c || '').toLowerCase().includes(key)
            );
        });
    }

    get hasPicklists() {
        return this.filteredPicklists && this.filteredPicklists.length > 0;
    }

    get hasLineItems() {
        return this.lineItems && this.lineItems.length > 0;
    }

    get isLineItemDetail() {
        return this.selectedLineItem != null;
    }

    get isLineItemsList() {
        return this.isLineItemsTab && !this.isLineItemDetail;
    }

    get isDetailsTab() {
        return this.activeTab === 'details';
    }

    get isLineItemsTab() {
        return this.activeTab === 'lineItems';
    }

    get detailsTabClass() {
        return this.isDetailsTab ? 'tab active' : 'tab';
    }

    get lineItemsTabClass() {
        return this.isLineItemsTab ? 'tab active' : 'tab';
    }

    get portalToastClass() {
        const base = 'portal-toast';
        if (this.portalToastVariant === 'error') {
            return `${base} portal-toast--error`;
        }
        if (this.portalToastVariant === 'success') {
            return `${base} portal-toast--success`;
        }
        return base;
    }

    get listViewClass() {
        return this.showCreateModal ? 'list-view list-view--modal-open' : 'list-view';
    }

    handleSearch(event) {
        this.searchKey = event.target.value || '';
    }

    handleCreate() {
        this.showCreateModal = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            const modal = this.template.querySelector('c-new-picklist-modal');
            if (modal && typeof modal.open === 'function') {
                modal.open();
            }
        }, 0);
    }

    handleModalClose() {
        this.showCreateModal = false;
    }

    async handleModalSaved(event) {
        this.showCreateModal = false;
        const number = event?.detail?.picklistNumber || '';
        this.showToast(
            'Success',
            number ? `Picklist ${number} created successfully.` : 'Picklist created successfully.',
            'success'
        );
        if (this.wiredPicklistsResult) {
            await refreshApex(this.wiredPicklistsResult);
        }
        const id = event?.detail?.picklistId;
        if (id) {
            const found = this.picklists.find((p) => p.Id === id);
            if (found) {
                await this.openPicklistById(found.Id);
            }
        }
    }

    handleModalToast(event) {
        const detail = event?.detail || {};
        this.showToast(detail.title || 'Notice', detail.message || '', detail.variant || 'info');
    }

    async openPicklistDetail(event) {
        const id = event.currentTarget.dataset.id;
        await this.openPicklistById(id);
    }

    async openPicklistById(id) {
        if (!id) {
            return;
        }
        if (this.wiredPicklistsResult) {
            await refreshApex(this.wiredPicklistsResult);
        }
        const found = this.picklists.find((p) => p.Id === id);
        if (!found) {
            return;
        }
        this.selectedPicklist = found;
        this.activeTab = 'details';
        this.lineItems = [];
        this.selectedLineItem = null;
        await this.loadLineItems(id);
    }

    async loadLineItems(picklistId) {
        try {
            const rows = await getPicklistLineItems({ picklistId });
            this.lineItems = (rows || []).map((li) => this.mapLineItem(li));
        } catch (e) {
            this.lineItems = [];
            this.showToast('Error', this.extractErrorMessage(e), 'error');
        }
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab || 'details';
        this.selectedLineItem = null;
        if (this.activeTab === 'lineItems' && this.selectedPicklist) {
            this.loadLineItems(this.selectedPicklist.Id);
        }
    }

    openLineItemDetail(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) {
            return;
        }
        const found = this.lineItems.find((li) => li.Id === id);
        if (found) {
            this.selectedLineItem = found;
        }
    }

    handleLineItemKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.openLineItemDetail(event);
        }
    }

    backToLineItems() {
        this.selectedLineItem = null;
    }

    backToList() {
        this.selectedPicklist = null;
        this.lineItems = [];
        this.selectedLineItem = null;
        this.activeTab = 'details';
        if (this.wiredPicklistsResult) {
            refreshApex(this.wiredPicklistsResult);
        }
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

    valueClass(value) {
        return value && String(value).trim()
            ? 'info-row-value'
            : 'info-row-value value-empty';
    }

    formatDateDisplay(value, dateOnly = true) {
        if (!value) {
            return 'Not set';
        }
        try {
            const d = new Date(value);
            if (dateOnly) {
                return d.toLocaleDateString('en-GB', {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric'
                });
            }
            return d.toLocaleDateString('en-GB', {
                day: '2-digit',
                month: 'short',
                year: 'numeric'
            });
        } catch (e) {
            return String(value);
        }
    }

    formatNumber(value) {
        if (value === null || value === undefined || value === '') {
            return '—';
        }
        const n = Number(value);
        if (isNaN(n)) {
            return String(value);
        }
        return n.toLocaleString('en-IN');
    }

    extractErrorMessage(error) {
        if (!error) {
            return 'Unexpected error.';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return error.message || 'Unexpected error.';
    }

    showToast(title, message, variant) {
        this.portalToastTitle = title || '';
        this.portalToastMessage = message || '';
        this.portalToastVariant = variant || 'info';
        this.portalToastVisible = true;
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.portalToastTimeout = window.setTimeout(() => {
            this.portalToastVisible = false;
        }, PORTAL_TOAST_DURATION_MS);
    }
}