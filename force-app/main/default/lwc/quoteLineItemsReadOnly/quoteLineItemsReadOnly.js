import { api, LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getQuoteLineItemsReadOnly from '@salesforce/apex/SalesPriceApprovalForQuotation.getQuoteLineItemsReadOnly';

export default class QuoteLineItemsReadOnly extends NavigationMixin(LightningElement) {
    @api quoteId;

    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';

    // Quote fields
    @track quoteNumber = '';
    @track accountName = '';
    @track quoteOwnerName = '';
    @track quoteValidTill = '';
    @track totalValueFormatted = '0';
    @track avgDiscountRequested = '';
    @track avgDiscountApproved = '';
    @track revNo = '';
    @track validityOfOffer = '';
    @track paymentTerms = '';
    @track warrantyTerms = '';
    @track deliveryPeriod = '';

    @track displayRows = [];
    @track hasLineItems = false;
    @track isARCRecordType = false;

    connectedCallback() {
        if (this.quoteId) {
            this.fetchQuoteData();
        } else {
            this.hasError = true;
            this.errorMessage = 'No Quote ID provided.';
            this.isLoading = false;
        }
    }

    fetchQuoteData() {
        this.isLoading = true;
        this.hasError = false;
        this.errorMessage = '';

        getQuoteLineItemsReadOnly({ quoteId: this.quoteId })
            .then(result => {
                if (!result) {
                    this.hasError = true;
                    this.errorMessage = 'No data returned for this quote.';
                    this.isLoading = false;
                    return;
                }

                // Populate quote header fields
                this.quoteNumber = result.quoteNumber || '';
                this.accountName = result.accountName || '';
                this.quoteOwnerName = result.quoteOwnerName || '';
                this.quoteValidTill = result.quoteValidTill || '';
                this.totalValueFormatted = result.totalValue ? 
                    Number(result.totalValue).toLocaleString('en-IN') : '0';
                this.avgDiscountRequested = result.avgDiscountRequested || '';
                this.avgDiscountApproved = result.avgDiscountApproved || '';
                this.revNo = result.revNo || '';
                this.validityOfOffer = result.validityOfOffer || '';
                this.paymentTerms = result.paymentTerms || '';
                this.warrantyTerms = result.warrantyTerms || '';
                this.deliveryPeriod = result.deliveryPeriod || '';
                this.isARCRecordType = result.recordTypeName === 'ARC';

                // Build display rows from line items
                if (result.quoteLineItems && result.quoteLineItems.length > 0) {
                    this.displayRows = this.buildDisplayRows(result.quoteLineItems);
                    this.hasLineItems = true;
                } else {
                    this.hasLineItems = false;
                }

                this.isLoading = false;
            })
            .catch(error => {
                this.hasError = true;
                this.errorMessage = error.body?.message || 'Failed to load quote line items.';
                this.isLoading = false;
                this.showToast('Error', this.errorMessage, 'error');
                console.error('Error fetching quote line items:', error);
            });
    }

    buildDisplayRows(lineItems) {
        const displayRows = [];

        lineItems.forEach(item => {
            // Only include items that require discount approval
            if (!item.isDiscountApprovalRequired) {
                displayRows.push({
                    key: `${item.quoteLineItemId}_view`,
                    isFirstRow: true,
                    soaCount: 1,
                    productName: item.productName || '',
                    productCode: item.productCode || '',
                    listPriceFormatted: this.formatCurrency(item.listPrice),
                    quantity: this.isARCRecordType ? item.potentialQty : item.quantity,
                    d1: item.d1 || '',
                    previousDiscount: item.previousDiscount || '',
                    d2: item.d2 || '',
                    salesPrice: this.formatSalesPrice(item.listPrice, item.d2),
                    validFrom: item.validFrom || '',
                    validTill: item.validTill || '',
                    soaDisplay: '',
                    soaStatus: '',
                    statusBadgeClass: 'status-badge status-badge--default',
                    soaDateTime: '',
                    requestedComments: item.requestedComments || '',
                    prevSoaComments: '',
                    soaComments: ''
                });
                return;
            }

            // Get all SOA levels for this line item
            const allSoaLevels = this.getSoaLevels(item);

            const originalFinalApproverId = item.originalFinalDiscountApproverId || item.finalDiscountApproverId;
            const effectiveFinalApproverId = item.finalDiscountApproverId || originalFinalApproverId;
            const originalFinalLevel = allSoaLevels.find(soa => soa.approverId === originalFinalApproverId);
            const effectiveFinalLevel = allSoaLevels.find(soa => soa.approverId === effectiveFinalApproverId);
            const originalMaxHierarchyIndex = originalFinalLevel ? originalFinalLevel.hierarchyIndex : null;
            const effectiveHierarchyIndex = effectiveFinalLevel ? effectiveFinalLevel.hierarchyIndex : originalMaxHierarchyIndex;

            // Filter SOA levels to show only those up to the final approver
            const soaLevels = originalMaxHierarchyIndex
                ? allSoaLevels.filter(soa =>
                    soa.hierarchyIndex <= originalMaxHierarchyIndex ||
                    soa.hierarchyIndex === effectiveHierarchyIndex
                )
                : (effectiveHierarchyIndex
                    ? allSoaLevels.filter(soa => soa.hierarchyIndex <= effectiveHierarchyIndex)
                    : allSoaLevels);

            soaLevels.forEach((soa, idx) => {
                const formattedDateTime = soa.dateTime
                    ? new Date(soa.dateTime).toLocaleString('en-GB', {
                        day: '2-digit',
                        month: '2-digit',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    })
                    : '';

                const isFinalApproverRow = soa.approverId === originalFinalApproverId ||
                    soa.approverId === effectiveFinalApproverId;

                const soaStatus = this.getDisplayStatus(
                    soa.status || '',
                    isFinalApproverRow
                );

                displayRows.push({
                    key: `${item.quoteLineItemId}_${idx}`,
                    isFirstRow: idx === 0,
                    soaCount: soaLevels.length,
                    productName: item.productName || '',
                    productCode: item.productCode || '',
                    listPriceFormatted: this.formatCurrency(item.listPrice),
                    quantity: this.isARCRecordType ? item.potentialQty : item.quantity,
                    d1: item.d1 || '',
                    previousDiscount: item.previousDiscount || '',
                    d2: item.d2 || '',
                    salesPrice: this.formatSalesPrice(item.listPrice, item.d2),
                    validFrom: item.validFrom || '',
                    validTill: item.validTill || '',
                    soaDisplay: soa.name ? `${soa.label} - ${soa.name}` : soa.label || '',
                    soaStatus: soaStatus,
                    statusBadgeClass: this.getStatusBadgeClass(soaStatus),
                    soaDateTime: formattedDateTime,
                    requestedComments: item.requestedComments || '',
                    prevSoaComments: soa.previousCommentsValue || '',
                    soaComments: soa.commentsValue || ''
                });
            });
        });

        return displayRows;
    }

    getSoaLevels(item) {
        return [
            {
                label: 'SM',
                name: item.salesManagerName,
                approverId: item.salesManagerId,
                status: item.salesManagerStatus || '',
                statusField: 'Sales_Manager_Status__c',
                dateTime: item.salesManagerDateTime,
                commentsValue: item.Sales_Manager_Comments || '',
                previousCommentsValue: item.prevSalesManagerComments || '',
                isCurrentUserRow: !item.bcheck1,
                hierarchyIndex: 1
            },
            {
                label: 'CH',
                name: item.countryContinentSalesName,
                approverId: item.countryContinentSalesId,
                status: item.countryContinentSalesStatus || '',
                statusField: 'Country_Continent_Sales_H_LOB_Status__c',
                dateTime: item.countryHeadDateTime,
                commentsValue: item.Country_Continent_Sales_LOB_Comments || '',
                previousCommentsValue: item.prevCountryContinentSalesComments || '',
                isCurrentUserRow: !item.bcheck2,
                hierarchyIndex: 2
            },
            {
                label: 'GS',
                name: item.globalSalesHeadName,
                approverId: item.globalSalesHeadId,
                status: item.globalSalesHeadStatus || '',
                statusField: 'Global_Sales_Head_Status__c',
                dateTime: item.globalSalesHeadDateTime,
                commentsValue: item.Global_Sales_Head_Comments || '',
                previousCommentsValue: item.prevGlobalSalesHeadComments || '',
                isCurrentUserRow: !item.bcheck5,
                hierarchyIndex: 3
            },
            {
                label: 'BM',
                name: item.rotexBoardMemberName,
                approverId: item.rotexBoardMemberId,
                status: item.rotexBoardMemberStatus || '',
                statusField: 'Rotex_Board_Member_Status__c',
                dateTime: item.rotexBoardMemberDateTime,
                commentsValue: item.Rotex_Board_Member_Comments || '',
                previousCommentsValue: item.prevRotexBoardMemberComments || '',
                isCurrentUserRow: !item.bcheck3,
                hierarchyIndex: 4
            },
            {
                label: 'MD',
                name: item.managingDirectorName,
                approverId: item.managingDirectorId,
                status: item.managingDirectorStatus || '',
                statusField: 'Managing_Director_Status__c',
                dateTime: item.managingDirectorDateTime,
                commentsValue: item.Managing_Director_Comments || '',
                previousCommentsValue: item.prevManagingDirectorComments || '',
                isCurrentUserRow: !item.bcheck4,
                hierarchyIndex: 5
            }
        ];
    }

    getDisplayStatus(status, isFinalApprover) {
        if (status === 'Submitted') {
            return 'Pending';
        }
        if (status === 'Approved' && !isFinalApprover) {
            return 'Commented';
        }
        return status || '';
    }

    getStatusBadgeClass(status) {
        const base = 'status-badge';
        if (!status) return `${base} status-badge--default`;
        const n = status.toLowerCase();
        if (n === 'approved') return `${base} status-badge--approved`;
        if (n === 'rejected') return `${base} status-badge--rejected`;
        if (n === 'submitted') return `${base} status-badge--submitted`;
        if (n === 'pending') return `${base} status-badge--submitted`;
        if (n === 'commented') return `${base} status-badge--commented`;
        return `${base} status-badge--default`;
    }

    formatCurrency(value) {
        if (value === undefined || value === null || value === '') return '';
        const num = Number(value);
        if (isNaN(num)) return String(value);
        return num.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    formatSalesPrice(listPrice, discount) {
        if (listPrice === undefined || listPrice === null) return '';
        const lp = Number(listPrice);
        const d = Number(discount);
        if (isNaN(lp)) return '';
        const disc = isNaN(d) ? 0 : d;
        const sp = lp * (1 - disc / 100);
        return this.formatCurrency(sp);
    }

    handleCancel() {
        // Navigate back to the quote record
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.quoteId,
                objectApiName: 'Quote',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}