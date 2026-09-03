import { LightningElement, api, track } from 'lwc';
import getExportPreview from '@salesforce/apex/DealerDataExportController.getExportPreview';
import exportData from '@salesforce/apex/DealerDataExportController.exportData';
import getExportAccounts from '@salesforce/apex/DealerDataExportController.getExportAccounts';

const MAX_ROWS = 5000;

const OBJECT_LABELS = {
    quote: 'Quotes',
    quotes: 'Quotes',
    order: 'Orders',
    orders: 'Orders',
    lead: 'Leads',
    leads: 'Leads',
    invoice: 'Invoices',
    invoices: 'Invoices',
    contact: 'Contacts',
    contacts: 'Contacts',
    case: 'Complaints',
    complaint: 'Complaints',
    complaints: 'Complaints',
    inventory: 'Inventory',
    inventories: 'Inventory',
    picklist: 'Picklists',
    picklists: 'Picklists',
    product: 'Products',
    products: 'Products',
    event: 'Events',
    events: 'Events',
    visit: 'Events',
    visits: 'Events',
    task: 'Tasks',
    tasks: 'Tasks',
    customer: 'Customers',
    customers: 'Customers',
    account: 'Customers',
    accounts: 'Customers'
};

/** Pages where Account Name filter is relevant */
const ACCOUNT_FILTER_OBJECTS = new Set([
    'quote',
    'quotes',
    'order',
    'orders',
    'invoice',
    'invoices',
    'contact',
    'contacts',
    'case',
    'complaint',
    'complaints',
    'picklist',
    'picklists'
]);

export default class DealerDataExport extends LightningElement {
    /** Object key: Quote | Order | Lead | Invoice | Contact | Case | Inventory | Product */
    @api objectKey = 'Quote';
    @api buttonLabel = 'Export';
    /** Page status tab value (Draft, Active, All, ...) */
    @api statusFilter = 'All';
    /** Page type/ownership filter (Self, Secondary Customer, All, ...) */
    @api typeFilter = 'All';
    /** Page search box text */
    @api searchKey = '';

    @track showModal = false;
    @track fromDate = '';
    @track toDate = '';
    @track recordCount = 0;
    @track truncated = false;
    @track previewLoaded = false;
    @track isPreviewing = false;
    @track isExporting = false;
    @track errorMessage = '';
    @track selectedAccountId = '';
    @track accountOptionsRaw = [];

    previewTimer;

    get maxRows() {
        return MAX_ROWS;
    }

    get objectKeyNormalized() {
        return String(this.objectKey || '').trim().toLowerCase();
    }

    get objectLabel() {
        return OBJECT_LABELS[this.objectKeyNormalized] || 'Data';
    }

    get showAccountFilter() {
        return ACCOUNT_FILTER_OBJECTS.has(this.objectKeyNormalized);
    }

    get accountOptions() {
        return (this.accountOptionsRaw || []).map((opt) => ({
            label: opt.label,
            value: opt.value == null ? '' : String(opt.value),
            selected: String(opt.value || '') === String(this.selectedAccountId || '')
        }));
    }

    get hasRecords() {
        return this.recordCount > 0;
    }

    get isBusy() {
        return this.isPreviewing || this.isExporting;
    }

    get exportDisabled() {
        return this.isBusy || !this.fromDate || !this.toDate || !this.hasRecords;
    }

    get hasActivePageFilters() {
        return this.filterChips.length > 0;
    }

    get filterChips() {
        const chips = [];
        const status = (this.statusFilter || '').trim();
        const type = (this.typeFilter || '').trim();
        const search = (this.searchKey || '').trim();
        if (status && status.toLowerCase() !== 'all') {
            chips.push({ key: 'status', label: `Status: ${status}` });
        }
        if (type && type.toLowerCase() !== 'all') {
            const typeLabel =
                this.objectKeyNormalized === 'customer' ||
                this.objectKeyNormalized === 'customers' ||
                this.objectKeyNormalized === 'account' ||
                this.objectKeyNormalized === 'accounts'
                    ? 'Business Line'
                    : 'Type';
            chips.push({ key: 'type', label: `${typeLabel}: ${type}` });
        }
        if (search) {
            chips.push({ key: 'search', label: `Search: ${search}` });
        }
        if (this.selectedAccountId) {
            const selected = (this.accountOptionsRaw || []).find(
                (o) => String(o.value || '') === String(this.selectedAccountId)
            );
            if (selected?.label) {
                chips.push({ key: 'account', label: `Account: ${selected.label}` });
            }
        }
        return chips;
    }

    async openModal() {
        const today = new Date();
        const firstOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
        this.fromDate = this.toIsoDate(firstOfMonth);
        this.toDate = this.toIsoDate(today);
        this.selectedAccountId = '';
        this.recordCount = 0;
        this.truncated = false;
        this.previewLoaded = false;
        this.errorMessage = '';
        this.showModal = true;

        if (this.showAccountFilter) {
            await this.loadAccounts();
        } else {
            this.accountOptionsRaw = [];
        }
        this.schedulePreview();
    }

    async loadAccounts() {
        try {
            const rows = await getExportAccounts({ objectKey: this.objectKey });
            this.accountOptionsRaw = rows || [];
        } catch (e) {
            this.accountOptionsRaw = [{ label: 'All Accounts', value: '' }];
            this.errorMessage = this.reduceError(e);
        }
    }

    closeModal() {
        if (this.isExporting) {
            return;
        }
        this.showModal = false;
        this.clearPreviewTimer();
    }

    stopBubble(event) {
        event.stopPropagation();
    }

    handleFromChange(event) {
        this.fromDate = event.target.value;
        this.schedulePreview();
    }

    handleToChange(event) {
        this.toDate = event.target.value;
        this.schedulePreview();
    }

    handleAccountChange(event) {
        this.selectedAccountId = event.target.value || '';
        this.schedulePreview();
    }

    schedulePreview() {
        this.clearPreviewTimer();
        this.errorMessage = '';
        this.previewTimer = window.setTimeout(() => {
            this.loadPreview();
        }, 250);
    }

    clearPreviewTimer() {
        if (this.previewTimer) {
            window.clearTimeout(this.previewTimer);
            this.previewTimer = null;
        }
    }

    exportParams() {
        return {
            objectKey: this.objectKey,
            fromDate: this.fromDate,
            toDate: this.toDate,
            statusFilter: this.statusFilter || 'All',
            typeFilter: this.typeFilter || 'All',
            searchKey: this.searchKey || '',
            accountId: this.showAccountFilter ? this.selectedAccountId || '' : ''
        };
    }

    async loadPreview() {
        if (!this.fromDate || !this.toDate) {
            this.previewLoaded = false;
            return;
        }
        this.isPreviewing = true;
        this.errorMessage = '';
        try {
            const result = await getExportPreview(this.exportParams());
            this.recordCount = result?.recordCount || 0;
            this.truncated = result?.truncated === true;
            this.previewLoaded = true;
        } catch (e) {
            this.previewLoaded = false;
            this.recordCount = 0;
            this.errorMessage = this.reduceError(e);
        } finally {
            this.isPreviewing = false;
        }
    }

    async handleExport() {
        if (this.exportDisabled) {
            return;
        }
        this.isExporting = true;
        this.errorMessage = '';
        try {
            const result = await exportData(this.exportParams());
            if (!result?.csvContent) {
                throw new Error('No export data returned.');
            }
            this.downloadFile(result.fileName || 'export.xls', result.csvContent);
            this.showModal = false;
        } catch (e) {
            this.errorMessage = this.reduceError(e);
        } finally {
            this.isExporting = false;
        }
    }

    downloadFile(fileName, fileContent) {
        const safeName = fileName || 'export.xls';
        try {
            const blob = new Blob([fileContent], { type: 'application/octet-stream' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = safeName;
            link.rel = 'noopener';
            link.click();
            window.setTimeout(() => URL.revokeObjectURL(url), 1000);
            return;
        } catch (e) {
            const base64 = window.btoa(unescape(encodeURIComponent(fileContent)));
            const link = document.createElement('a');
            link.href = `data:application/octet-stream;base64,${base64}`;
            link.download = safeName;
            link.rel = 'noopener';
            link.click();
        }
    }

    toIsoDate(d) {
        const yyyy = d.getFullYear();
        const mm = String(d.getMonth() + 1).padStart(2, '0');
        const dd = String(d.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
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

    disconnectedCallback() {
        this.clearPreviewTimer();
    }
}