import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getMyInventories from '@salesforce/apex/InventoryListController.getMyInventories';
import getInventoryTransactions from '@salesforce/apex/InventoryListController.getInventoryTransactions';
import updateInventoryLevels from '@salesforce/apex/InventoryListController.updateInventoryLevels';

export default class DealerInventory extends LightningElement {
    @track inventories = [];
    @track showInventoryList = true;
    @track selectedInventory = null;
    @track activeTab = 'details';
    
    @track transactions = [];
    @track isLoadingTransactions = false;
    @track selectedTransactionId = null;

    @track showEditModal = false;
    @track isSavingEdit = false;
    editMinimumOrderQty = '';
    editMinimumStockLevel = '';

    searchKey = '';
    wiredInventoriesResult;

    connectedCallback() {
        this._boundShowList = () => this.backToList();
        window.addEventListener('portalshowlist', this._boundShowList);
    }

    disconnectedCallback() {
        if (this._boundShowList) {
            window.removeEventListener('portalshowlist', this._boundShowList);
        }
    }

    @wire(getMyInventories)
    wiredInventories(result) {
        this.wiredInventoriesResult = result;
        if (result.data) {
            this.inventories = (result.data || []).map((o) => this.mapInventory(o));
            this.openInventoryFromNotification();
        } else if (result.error) {
            this.inventories = [];
            this.showToast('Error', this.extractErrorMessage(result.error), 'error');
        }
    }

    openInventoryFromNotification() {
        let inventoryId;
        try {
            inventoryId = sessionStorage.getItem('portalOpenInventoryId');
            if (inventoryId) {
                sessionStorage.removeItem('portalOpenInventoryId');
            }
        } catch (e) {
            return;
        }
        if (!inventoryId) {
            return;
        }
        const found = this.inventories.find((o) => o.Id === inventoryId);
        if (found) {
            this.selectedInventory = found;
            this.activeTab = 'details';
        }
    }

    mapInventory(o) {
        const partnerName = o.Channel_Partner__r?.Name || '—';
        const productName = o.Product__r?.Name || '—';

        return {
            ...o,
            partnerDisplay: partnerName,
            productDisplay: productName,
            ownerName: this.formatOwnerName(o.Owner),
            createdDate: this.formatDateDisplay(o.CreatedDate, false),
            
            inventoryNumberDisplay: this.displayOrNotSet(o.Name),
            productCodeDisplay: this.displayOrNotSet(o.Product_Code__c),
            lastGrnDateDisplay: this.formatDateDisplay(o.Last_GRN_Date__c),
            lastSaleDateDisplay: this.formatDateDisplay(o.Last_Sale_Date__c),
            minimumOrderQtyDisplay: this.displayOrNotSet(o.Minimum_Order_Quantity__c),
            minimumStockLevelDisplay: this.displayOrNotSet(o.Minimum_Stock_Level__c),

            totalGrnQtyDisplay: this.displayOrNotSet(o.Total_GRN_Quantity__c),
            totalReservedQtyDisplay: this.displayOrNotSet(o.Total_Reserved_Quantity__c),
            totalInvoiceQtyDisplay: this.displayOrNotSet(o.Total_Invoice_Quantity__c),
            totalCancelledQtyDisplay: this.displayOrNotSet(o.Total_Cancelled_Quantity__c),
            onHandQtyDisplay: this.displayOrNotSet(o.On_Hand_Quantity__c),
            currentReservedQtyDisplay: this.displayOrNotSet(o.Current_Reserved_Quantity__c),
            availableQtyDisplay: this.displayOrNotSet(o.Available_Quantity__c),

            statusDisplay: this.displayOrNotSet(o.Status__c),
            statusBadgeClass: this.statusBadgeClass(o.Status__c)
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

    displayOrNotSet(value) {
        return value !== null && value !== undefined && String(value).trim() !== '' ? value : 'Not set';
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

    formatDateTimeDisplay(value) {
        if (!value) {
            return '—';
        }
        try {
            return new Date(value).toLocaleString('en-GB', {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            });
        } catch (e) {
            return String(value);
        }
    }

    get isDetailsTab() {
        return this.activeTab === 'details';
    }

    get isTransactionsTab() {
        return this.activeTab === 'transactions';
    }

    get detailsTabClass() {
        return this.isDetailsTab ? 'quote-tab quote-tab-active' : 'quote-tab';
    }

    get transactionsTabClass() {
        return this.isTransactionsTab ? 'quote-tab quote-tab-active' : 'quote-tab';
    }

    get showTransactionListView() {
        return this.selectedTransactionId == null;
    }

    get showTransactionDetailView() {
        return this.selectedTransactionId != null;
    }

    get selectedTransaction() {
        if (!this.selectedTransactionId) return null;
        return this.transactions.find((t) => t.id === this.selectedTransactionId);
    }

    get hasTransactions() {
        return this.transactions && this.transactions.length > 0;
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        this.selectedTransactionId = null;
        if (this.activeTab === 'transactions') {
            this.loadTransactions();
        }
    }

    async loadTransactions() {
        if (!this.selectedInventory?.Id) {
            this.transactions = [];
            return;
        }
        this.isLoadingTransactions = true;
        try {
            const result = await getInventoryTransactions({ inventoryId: this.selectedInventory.Id });
            const mapped = (result || []).map(t => ({
                id: t.Id,
                createdDateMs: t.CreatedDate ? new Date(t.CreatedDate).getTime() : 0,
                transactionDateMs: t.Transaction_Date_Time__c
                    ? new Date(t.Transaction_Date_Time__c).getTime()
                    : 0,
                transactionNumberDisplay: this.displayOrNotSet(t.Name),
                transactionTypeDisplay: this.displayOrNotSet(t.Transaction_Type__c),
                transactionDateDisplay: this.formatDateTimeDisplay(t.Transaction_Date_Time__c),
                quantityDisplay: this.displayOrNotSet(t.Quantity__c),
                remarksDisplay: this.displayOrNotSet(t.Remarks__c),
                grnLineItemDisplay: this.displayOrNotSet(t.GRN_Line_Item__r?.Name),
                quoteLineItemDisplay: this.displayOrNotSet(t.Quote_Line_Item__r?.LineNumber),
                secondaryInvoiceDisplay: this.displayOrNotSet(t.Secondary_Invoice__r?.Name)
            }));
            // Newest created transactions first
            mapped.sort((a, b) => {
                const byCreated = (b.createdDateMs || 0) - (a.createdDateMs || 0);
                if (byCreated !== 0) {
                    return byCreated;
                }
                return (b.transactionDateMs || 0) - (a.transactionDateMs || 0);
            });
            this.transactions = mapped;
        } catch (error) {
            this.transactions = [];
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoadingTransactions = false;
        }
    }

    handleTransactionClick(event) {
        this.selectedTransactionId = event.currentTarget.dataset.id;
    }

    handleBackToTransactions() {
        this.selectedTransactionId = null;
    }

    statusBadgeClass(status) {
        const s = (status || '').toLowerCase();
        if (s === 'available' || s === 'active') {
            return 'grn-status grn-status-complete';
        }
        if (s === 'out of stock' || s === 'inactive') {
            return 'grn-status grn-status-partial';
        }
        return 'grn-status';
    }

    get filteredInventories() {
        const key = (this.searchKey || '').trim().toLowerCase();
        if (!key) {
            return this.inventories;
        }
        return this.inventories.filter((o) => {
            return (
                (o.Name || '').toLowerCase().includes(key) ||
                (o.partnerDisplay || '').toLowerCase().includes(key) ||
                (o.productDisplay || '').toLowerCase().includes(key) ||
                (o.Product_Code__c || '').toLowerCase().includes(key)
            );
        });
    }

    get hasInventories() {
        return this.filteredInventories && this.filteredInventories.length > 0;
    }

    handleSearch(event) {
        this.searchKey = event.target.value || '';
    }

    async refreshSelectedInventory() {
        if (this.wiredInventoriesResult) {
            await refreshApex(this.wiredInventoriesResult);
        }
        if (this.selectedInventory) {
            const found = this.inventories.find((o) => o.Id === this.selectedInventory.Id);
            if (found) {
                this.selectedInventory = found;
            }
        }
    }

    async openInventoryDetail(event) {
        const id = event.currentTarget.dataset.id;
        if (this.wiredInventoriesResult) {
            await refreshApex(this.wiredInventoriesResult);
        }
        const found = this.inventories.find((o) => o.Id === id);
        if (found) {
            this.selectedInventory = found;
            this.activeTab = 'details';
            this.selectedTransactionId = null;
            this.transactions = [];
        }
    }

    backToList() {
        this.showInventoryList = true;
        this.selectedInventory = null;
        this.activeTab = 'details';
        this.selectedTransactionId = null;
        this.transactions = [];
        this.showEditModal = false;
    }

    get saveButtonLabel() {
        return this.isSavingEdit ? 'Saving...' : 'Save';
    }

    handleOpenEdit() {
        if (!this.selectedInventory) {
            return;
        }
        this.editMinimumOrderQty =
            this.selectedInventory.Minimum_Order_Quantity__c != null
                ? String(this.selectedInventory.Minimum_Order_Quantity__c)
                : '';
        this.editMinimumStockLevel =
            this.selectedInventory.Minimum_Stock_Level__c != null
                ? String(this.selectedInventory.Minimum_Stock_Level__c)
                : '';
        this.showEditModal = true;
    }

    handleCloseEdit() {
        if (this.isSavingEdit) {
            return;
        }
        this.showEditModal = false;
    }

    stopEditModalBubble(event) {
        event.stopPropagation();
    }

    handleEditMoqChange(event) {
        this.editMinimumOrderQty = event.target.value;
    }

    handleEditMslChange(event) {
        this.editMinimumStockLevel = event.target.value;
    }

    parseOptionalNumber(raw) {
        const text = raw == null ? '' : String(raw).trim();
        if (text === '') {
            return null;
        }
        const num = Number(text);
        if (Number.isNaN(num)) {
            throw new Error('Please enter valid numbers.');
        }
        if (num < 0) {
            throw new Error('Values cannot be negative.');
        }
        return num;
    }

    async handleSaveEdit() {
        if (!this.selectedInventory?.Id || this.isSavingEdit) {
            return;
        }

        const moqInput = this.template.querySelector('input[data-field="moq"]');
        const mslInput = this.template.querySelector('input[data-field="msl"]');
        if (moqInput) {
            this.editMinimumOrderQty = moqInput.value;
        }
        if (mslInput) {
            this.editMinimumStockLevel = mslInput.value;
        }

        let moq;
        let msl;
        try {
            moq = this.parseOptionalNumber(this.editMinimumOrderQty);
            msl = this.parseOptionalNumber(this.editMinimumStockLevel);
        } catch (e) {
            this.showToast('Error', e.message, 'error');
            return;
        }

        this.isSavingEdit = true;
        try {
            await updateInventoryLevels({
                inventoryId: this.selectedInventory.Id,
                minimumOrderQuantity: moq,
                minimumStockLevel: msl
            });

            const next = this.mapInventory({
                ...this.selectedInventory,
                Minimum_Order_Quantity__c: moq,
                Minimum_Stock_Level__c: msl
            });
            this.selectedInventory = next;
            this.inventories = this.inventories.map((inv) =>
                inv.Id === next.Id ? next : inv
            );
            this.showEditModal = false;
            this.showToast('Success', 'Inventory updated successfully.', 'success');
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isSavingEdit = false;
        }
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