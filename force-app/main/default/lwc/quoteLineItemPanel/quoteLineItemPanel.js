import { LightningElement, api, track } from 'lwc';
import getLineItemsForQuote from '@salesforce/apex/QuoteLineItemController.getLineItemsForQuote';

export default class QuoteLineItemPanel extends LightningElement {
    @api quoteId;

    @track lineItems = [];
    @track selectedLine = null;
    @track hasLoaded = false;
    isLoading = false;

    connectedCallback() {
        this.loadLineItems();
    }

    @api
    refresh() {
        this.selectedLine = null;
        this.loadLineItems();
    }

    loadLineItems() {
        if (!this.quoteId) {
            return;
        }
        this.isLoading = true;
        getLineItemsForQuote({ quoteId: this.quoteId })
            .then((data) => {
                this.lineItems = (data || []).map((item, index) => this.mapLineItem(item, index));
                this.hasLoaded = true;
            })
            .catch((error) => {
                this.lineItems = [];
                this.hasLoaded = true;
                // eslint-disable-next-line no-console
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    mapLineItem(item, index) {
        const money = (v) => (v === null || v === undefined ? '—' : 'INR ' + Number(v).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }));
        const num = (v) => (v === null || v === undefined ? '—' : Number(v).toFixed(2));
        const pct = (v) => (v === null || v === undefined ? '—' : Number(v).toFixed(2) + '%');

        return {
            id: item.id,
            srNo: String(index + 1),
            customerPartNo: item.customerPartNo || '—',
            productName: item.productName || '—',
            productCode: item.productCode || '—',
            hsnCode: item.hsnCode || '—',
            listPriceDisplay: money(item.listPrice),
            discountAsPerSapDisplay: pct(item.discountAsPerSap),
            salesPriceDisplay: money(item.salesPrice),
            requestedDiscountDisplay: pct(item.requestedDiscount),
            quantityDisplay: num(item.quantity),
            discountToBeOfferedDisplay: pct(item.discountToBeOffered),
            cgstAmountDisplay: money(item.cgstAmount),
            sgstAmountDisplay: money(item.sgstAmount),
            igstAmountDisplay: money(item.igstAmount),
            totalValueDisplay: money(item.totalValue),
            grandTotalDisplay: money(item.grandTotal)
        };
    }

    get hasLineItems() {
        return this.lineItems && this.lineItems.length > 0;
    }

    get showListView() {
        return !this.selectedLine;
    }

    get showDetailView() {
        return !!this.selectedLine;
    }

    get listMetaText() {
        const count = this.lineItems?.length || 0;
        return `${count} item${count === 1 ? '' : 's'} • Sorted by Line Number`;
    }

    handleRowClick(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedLine = this.lineItems.find((line) => line.id === id) || null;
    }

    handleRowKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleRowClick(event);
        }
    }

    handleBackToList() {
        this.selectedLine = null;
    }
}