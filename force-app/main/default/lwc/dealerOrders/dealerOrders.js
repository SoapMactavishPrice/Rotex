import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getMyOrders from '@salesforce/apex/OrderController.getMyOrders';
import getOrderNotes from '@salesforce/apex/OrderController.getOrderNotes';
import getOrderFiles from '@salesforce/apex/OrderController.getOrderFiles';
import addOrderNote from '@salesforce/apex/OrderController.addOrderNote';
import saveOrderAttachment from '@salesforce/apex/OrderController.saveOrderAttachment';

const STATUS_PATH_STEPS = [
    'Draft',
    'Activated'
];

export default class DealerOrders extends LightningElement {
    @track orders = [];
    @track selectedOrder = null;
    @track selectedLineItemId = null;
    @track orderNotes = [];
    @track orderFiles = [];
    @track previewFile = null;
    @track activeTab = 'details';

    searchKey = '';
    noteText = '';
    wiredOrdersResult;

    connectedCallback() {
        this._boundShowList = () => this.backToList();
        window.addEventListener('portalshowlist', this._boundShowList);
    }

    disconnectedCallback() {
        if (this._boundShowList) {
            window.removeEventListener('portalshowlist', this._boundShowList);
        }
    }

    @wire(getMyOrders)
    wiredOrders(result) {
        this.wiredOrdersResult = result;
        if (result.data) {
            this.orders = (result.data || []).map((o) => this.mapOrder(o));
            this.openOrderFromNotification();
        } else if (result.error) {
            this.orders = [];
            this.showToast('Error', this.extractErrorMessage(result.error), 'error');
        }
    }

    openOrderFromNotification() {
        let orderId;
        try {
            orderId = sessionStorage.getItem('portalOpenOrderId');
            if (orderId) {
                sessionStorage.removeItem('portalOpenOrderId');
            }
        } catch (e) {
            return;
        }
        if (!orderId) {
            return;
        }
        const found = this.orders.find((o) => o.Id === orderId);
        if (found) {
            this.selectedOrder = found;
            this.resetSidebarState();
            this.loadOrderSidebar(found.Id);
        }
    }

    mapOrder(o) {
        const accountName = o.Account?.Name || '—';

        return {
            ...o,
            accountName,
            orderLabel: o.Name || o.OrderNumber || 'Order',
            ownerName: this.formatOwnerName(o.Owner),
            createdDate: this.formatDateDisplay(o.CreatedDate, false),
            statusDisplay: this.displayOrNotSet(o.Status),
            // Order Information (CP Excel)
            orderNumberDisplay: this.displayOrNotSet(o.OrderNumber),
            rotexOrderNumberDisplay: this.displayOrNotSet(o.SO_No__c),
            orderTypeDisplay: this.displayOrNotSet(o.SO_Type__c),
            orderDateDisplay: this.formatDateDisplay(o.EffectiveDate),
            orderCurrencyDisplay: this.displayOrNotSet(o.CurrencyIsoCode),
            netValueDisplay: this.displayOrNotSet(o.Net_Value__c),
            // Additional Information (CP Excel)
            billToDisplay: this.displayOrNotSet(o.Bill_To__c),
            billToCustomerNameDisplay: this.displayOrNotSet(o.Bill_To_Customer_Name__r?.Name),
            custRefNumberDisplay: this.displayOrNotSet(o.Cust_Ref__c),
            custRefDateDisplay: this.formatDateDisplay(o.Cust_Ref_Date__c),
            reqDelDateDisplay: this.formatDateDisplay(o.Req_Del_Date__c),
            shipToDisplay: this.displayOrNotSet(o.Ship_To__c),
            soldToDisplay: this.displayOrNotSet(o.Sold_To__c),
            termsOfPaymentDisplay: this.displayOrNotSet(o.Terms_Of_Payment__c),
            incotermsDisplay: this.displayOrNotSet(o.Incoterms__c),
            // value classes
            orderNumberClass: this.valueClass(o.OrderNumber),
            rotexOrderNumberClass: this.valueClass(o.SO_No__c),
            accountNameClass: this.valueClass(accountName !== '—' ? accountName : ''),
            orderTypeClass: this.valueClass(o.SO_Type__c),
            orderDateClass: this.valueClass(o.EffectiveDate),
            orderCurrencyClass: this.valueClass(o.CurrencyIsoCode),
            netValueClass: this.valueClass(o.Net_Value__c),
            billToClass: this.valueClass(o.Bill_To__c),
            billToCustomerNameClass: this.valueClass(o.Bill_To_Customer_Name__r?.Name),
            custRefNumberClass: this.valueClass(o.Cust_Ref__c),
            custRefDateClass: this.valueClass(o.Cust_Ref_Date__c),
            reqDelDateClass: this.valueClass(o.Req_Del_Date__c),
            shipToClass: this.valueClass(o.Ship_To__c),
            soldToClass: this.valueClass(o.Sold_To__c),
            termsOfPaymentClass: this.valueClass(o.Terms_Of_Payment__c),
            incotermsClass: this.valueClass(o.Incoterms__c),
            // list view helpers
            effectiveDateDisplay: this.formatDateDisplay(o.EffectiveDate),
            totalAmountDisplay: this.displayOrNotSet(o.TotalAmount),
            lineItems: (o.OrderItems || []).map((li, index) => ({
                id: li.Id,
                itemNumberDisplay: String(index + 1),
                itemDisplay: this.displayOrNotSet(li.Product2?.Name),
                itemCodeDisplay: this.displayOrNotSet(li.Product2?.ProductCode),
                uomDisplay: this.displayOrNotSet(li.UOM__c),
                listPriceDisplay: this.displayOrNotSet(li.ListPrice),
                unitPriceDisplay: this.displayOrNotSet(li.UnitPrice),
                quantityDisplay: this.displayOrNotSet(li.Quantity),
                totalPriceDisplay: this.displayOrNotSet(li.TotalPrice)
            })),
            hasLineItems: o.OrderItems && o.OrderItems.length > 0
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
        const current = this.normalizeStatus(this.selectedOrder?.Status);
        const currentIndex = STATUS_PATH_STEPS.findIndex(
            (step) => this.normalizeStatus(step) === current
        );
        return STATUS_PATH_STEPS.map((label, index) => ({
            label,
            key: label,
            className:
                index === currentIndex
                    ? 'status-path-step status-path-step-current'
                    : 'status-path-step'
        }));
    }

    normalizeStatus(value) {
        return (value || '').toLowerCase().replace(/\s+/g, ' ').trim();
    }

    displayOrNotSet(value) {
        return value && String(value).trim() ? value : 'Not set';
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

    get showLineItemListView() {
        return this.selectedLineItemId == null;
    }

    get showLineItemDetailView() {
        return this.selectedLineItemId != null;
    }

    get selectedLineItem() {
        if (!this.selectedOrder || !this.selectedLineItemId) {
            return null;
        }
        return this.selectedOrder.lineItems.find((li) => li.id === this.selectedLineItemId);
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        if (this.activeTab !== 'lineItem') {
            this.selectedLineItemId = null;
        }
    }

    handleLineItemClick(event) {
        this.selectedLineItemId = event.currentTarget.dataset.id;
    }

    handleBackToLineItems() {
        this.selectedLineItemId = null;
    }

    get filteredOrders() {
        const key = (this.searchKey || '').trim().toLowerCase();
        if (!key) {
            return this.orders;
        }
        return this.orders.filter((o) => {
            return (
                (o.Name || '').toLowerCase().includes(key) ||
                (o.OrderNumber || '').toLowerCase().includes(key) ||
                (o.SO_No__c || '').toLowerCase().includes(key) ||
                (o.accountName || '').toLowerCase().includes(key) ||
                (o.Status || '').toLowerCase().includes(key) ||
                (o.ownerName || '').toLowerCase().includes(key)
            );
        });
    }

    get hasOrders() {
        return this.filteredOrders && this.filteredOrders.length > 0;
    }

    handleSearch(event) {
        this.searchKey = event.target.value || '';
    }

    async refreshSelectedOrder() {
        if (this.wiredOrdersResult) {
            await refreshApex(this.wiredOrdersResult);
        }
        if (this.selectedOrder) {
            const found = this.orders.find((o) => o.Id === this.selectedOrder.Id);
            if (found) {
                this.selectedOrder = found;
            }
        }
    }

    async openOrderDetail(event) {
        const id = event.currentTarget.dataset.id;
        if (this.wiredOrdersResult) {
            await refreshApex(this.wiredOrdersResult);
        }
        const found = this.orders.find((o) => o.Id === id);
        if (found) {
            this.selectedOrder = found;
            this.resetSidebarState();
            this.loadOrderSidebar(found.Id);
        }
    }

    backToList() {
        this.selectedOrder = null;
        this.resetSidebarState();
    }

    resetSidebarState() {
        this.orderNotes = [];
        this.orderFiles = [];
        this.noteText = '';
        this.previewFile = null;
        this.activeTab = 'details';
        this.selectedLineItemId = null;
    }

    loadOrderSidebar(orderId) {
        this.loadOrderNotes(orderId);
        this.loadOrderFiles(orderId);
    }

    handleNoteChange(event) {
        this.noteText = event.target.value;
    }

    handleAddNote() {
        if (!this.noteText || !this.noteText.trim() || !this.selectedOrder) {
            return;
        }

        const orderId = this.selectedOrder.Id;
        const bodyText = this.noteText.trim();
        this.noteText = '';

        addOrderNote({ orderId, noteBody: bodyText })
            .then((newNote) => {
                if (newNote && newNote.id) {
                    this.orderNotes = [newNote, ...this.orderNotes];
                } else {
                    this.loadOrderNotes(orderId);
                }
            })
            .catch((error) => {
                this.noteText = bodyText;
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    loadOrderNotes(orderId) {
        getOrderNotes({ orderId })
            .then((data) => {
                this.orderNotes = data || [];
            })
            .catch((error) => {
                console.error(error);
            });
    }

    get hasNotes() {
        return this.orderNotes && this.orderNotes.length > 0;
    }

    loadOrderFiles(orderId) {
        getOrderFiles({ orderId })
            .then((data) => {
                this.orderFiles = data || [];
            })
            .catch((error) => {
                console.error(error);
            });
    }

    get hasFiles() {
        return this.orderFiles && this.orderFiles.length > 0;
    }

    handleFilePreview(event) {
        const fileId = event.currentTarget.dataset.id;
        const file = this.orderFiles.find((item) => item.id === fileId);
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
        if (!this.selectedOrder) {
            return;
        }

        const orderId = this.selectedOrder.Id;
        const reader = new FileReader();

        reader.onload = () => {
            const base64Data = reader.result.split(',')[1];
            saveOrderAttachment({
                orderId,
                fileName: file.name,
                base64Data
            })
                .then((newFile) => {
                    this.orderFiles = [newFile, ...this.orderFiles];
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