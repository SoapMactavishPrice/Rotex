import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllQuotations from '@salesforce/apex/SalesPriceApprovalForQuotation.getAllQuotations';
import updateQuoteLineItem from '@salesforce/apex/SalesPriceApprovalForQuotation.updateQuoteLineItem';
import updateWarrantyApproval from '@salesforce/apex/SalesPriceApprovalForQuotation.updateWarrantyApproval';
import submitWarrantyApprovalSingle from '@salesforce/apex/SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle';
import submitValidityOfferApprovalSingle from '@salesforce/apex/SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle';
import submitTotalValueApprovalSingle from '@salesforce/apex/SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle';
import submitMinimumOfferApprovalSingle from '@salesforce/apex/SalesPriceApprovalForQuotation.submitMinimumOfferApprovalSingle';
import USER_ID from '@salesforce/user/Id';
import { NavigationMixin } from 'lightning/navigation';

export default class QuoteSalesPriceApproval extends NavigationMixin(LightningElement) {
    @track quotes;
    @track updatedLineItems = new Map();
    @track isSaveDisabled = false;
    @track skipSoaRestrictions = false;

    /**
     * ✅ FIX: warrantyApprovalsMap is now populated inside fetchQuotes() from
     *         the warrantyApproval embedded in every QuotationWrapper returned
     *         by getAllQuotations().  Previously this map was always empty
     *         because getWarrantyApprovals() was imported but never called.
     */
    @track warrantyApprovalsMap = new Map();
    @track validityOfferApprovalsMap = new Map();
    @track totalValueApprovalsMap = new Map();
    @track minimumOfferApprovalsMap = new Map();

    userId = USER_ID;

    @track statusOptions = [
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Approved',  value: 'Approved'  },
        { label: 'Rejected',  value: 'Rejected'  }
    ];

    error;

    get isLoading() {
        return this.isSaveDisabled;
    }

    get isSubmitDisabled() {
        return this.isSaveDisabled || this.requiresNonFinalApproverComment();
    }

    connectedCallback() {
        this.fetchQuotes();
    }

    /**
     * ✅ FIX: After mapping quotes, iterate the raw server result and seed
     *         warrantyApprovalsMap with any non-null warrantyApproval payloads.
     *         This makes warranty data available when the user expands a quote
     *         row — whether it is a discount-only, warranty-only, or both quote.
     */
    fetchQuotes() {
        getAllQuotations()
            .then(result => {
                // Seed the warranty map BEFORE building the display quotes so
                // that handleToggleExpand can resolve entries immediately.
                const newWarrantyMap = new Map();
                const newValidityMap = new Map();
                const newTotalValueMap = new Map();
                const newMinimumOfferMap = new Map();
                result.forEach(q => {
                    if (q.warrantyApproval) {
                        newWarrantyMap.set(q.quoteId, { ...q.warrantyApproval });
                    }
                    if (q.validityOfferApproval) {
                        newValidityMap.set(q.quoteId, { ...q.validityOfferApproval });
                    }
                    if (q.totalValueApproval) {
                        newTotalValueMap.set(q.quoteId, { ...q.totalValueApproval });
                    }
                    if (q.minimumOfferApproval) {
                        newMinimumOfferMap.set(q.quoteId, { ...q.minimumOfferApproval });
                    }
                });
                this.warrantyApprovalsMap = newWarrantyMap;
                this.validityOfferApprovalsMap = newValidityMap;
                this.totalValueApprovalsMap = newTotalValueMap;
                this.minimumOfferApprovalsMap = newMinimumOfferMap;

                this.quotes = result.map(q => this.processQuote(q));
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                this.redirectToHome();
                setTimeout(() => { window.location.reload(); }, 2500);
            });
    }

    processQuote(q) {
        const quoteRecordUrl = `/lightning/r/Quote/${q.quoteId}/view`;
        const processedLineItems = (q.quoteLineItems || []).map(item => ({
            ...item,
            isFinalDiscountApprover: item.finalDiscountApproverId === this.userId,
            isEditable: item.approvalStatus === 'Submitted',
            skipSoaRestrictions: this.skipSoaRestrictions,
            skipEditableCommentFields: item.skipEditableCommentFields || {}
        }));

        return {
            ...q,
            quoteRecordUrl,
            isExpanded: false,
            hasLineItems: (q.quoteLineItems || []).length > 0,
            warrantyApproval: null,
            validityOfferApproval: null,
            totalValueApproval: null,
            minimumOfferApproval: null,
            showApprovalDashboard: false,
            quoteLineItems: processedLineItems,
            displayRows: this.buildDisplayRows(processedLineItems)
        };
    }

    handleToggleExpand(event) {
        const quoteId = event.currentTarget.dataset.quoteId;
        this.quotes = this.quotes.map(quote => {
            if (quote.quoteId === quoteId) {
                const expanded = !quote.isExpanded;
                const warrantyApproval = expanded ? this.warrantyApprovalsMap.get(quoteId) : null;
                const validityOfferApproval = expanded ? this.validityOfferApprovalsMap.get(quoteId) : null;
                const totalValueApproval = expanded ? this.totalValueApprovalsMap.get(quoteId) : null;
                const minimumOfferApproval = expanded ? this.minimumOfferApprovalsMap.get(quoteId) : null;
                return {
                    ...quote,
                    isExpanded: expanded,
                    warrantyApproval,
                    validityOfferApproval,
                    totalValueApproval,
                    minimumOfferApproval,
                    showApprovalDashboard: expanded && (warrantyApproval != null || validityOfferApproval != null || totalValueApproval != null || minimumOfferApproval != null)
                };
            }
            return quote;
        });
    }

    handleWarrantyStatusChange(event) {
        const { quoteId, field, value } = event.detail;
        const warranty = this.warrantyApprovalsMap.get(quoteId);

        if (warranty) {
            warranty[`${field}WarrantyStatus`] = value;
            warranty.updated = true;
            this.warrantyApprovalsMap = new Map(this.warrantyApprovalsMap);

            this.quotes = this.quotes.map(q => {
                if (q.quoteId === quoteId) {
                    return { ...q, warrantyApproval: { ...warranty } };
                }
                return q;
            });
        }
    }

    handleWarrantyCommentChange(event) {
        const { quoteId, field, value } = event.detail;
        const warranty = this.warrantyApprovalsMap.get(quoteId);

        if (warranty) {
            warranty[`${field}WarrantyComments`] = value;
            warranty.updated = true;

            this.warrantyApprovalsMap = new Map(this.warrantyApprovalsMap);

            this.quotes = this.quotes.map(q => {
                if (q.quoteId === quoteId) {
                    return { ...q, warrantyApproval: { ...warranty } };
                }
                return q;
            });
        }
    }

    handleWarrantySubmit(event) {
        const { quoteId, warrantyData } = event.detail;
        
        if (!warrantyData || !warrantyData.updated) {
            this.showToast('Warning', 'No changes to submit for warranty approval', 'warning');
            return;
        }

        this.isSaveDisabled = true;

        submitWarrantyApprovalSingle({ warrantyApprovalJson: JSON.stringify(warrantyData) })
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Warranty approval submitted successfully', 'success');
                    setTimeout(() => { window.location.reload(); }, 1500);
                } else {
                    this.showToast('Info', result, 'info');
                    this.isSaveDisabled = false;
                }
            })
            .catch(error => {
                this.isSaveDisabled = false;
                this.showToast('Error', error.body?.message || 'An error occurred while submitting warranty approval', 'error');
            });
    }

    // ── Validity Of Offer Approval Handlers ──────────────────────────────

    handleValidityOfferStatusChange(event) {
        const { quoteId, field, value } = event.detail;
        const validity = this.validityOfferApprovalsMap.get(quoteId);

        if (validity) {
            validity[`${field}ValidityOfferStatus`] = value;
            validity.updated = true;
            this.validityOfferApprovalsMap = new Map(this.validityOfferApprovalsMap);

            this.quotes = this.quotes.map(q => {
                if (q.quoteId === quoteId) {
                    return { ...q, validityOfferApproval: { ...validity } };
                }
                return q;
            });
        }
    }

    handleValidityOfferCommentChange(event) {
        const { quoteId, field, value } = event.detail;
        const validity = this.validityOfferApprovalsMap.get(quoteId);

        if (validity) {
            validity[`${field}ValidityOfferComments`] = value;
            validity.updated = true;

            this.validityOfferApprovalsMap = new Map(this.validityOfferApprovalsMap);

            this.quotes = this.quotes.map(q => {
                if (q.quoteId === quoteId) {
                    return { ...q, validityOfferApproval: { ...validity } };
                }
                return q;
            });
        }
    }

    handleValidityOfferSubmit(event) {
        const { quoteId, validityData } = event.detail;
        
        if (!validityData || !validityData.updated) {
            this.showToast('Warning', 'No changes to submit for validity of offer approval', 'warning');
            return;
        }

        this.isSaveDisabled = true;

        submitValidityOfferApprovalSingle({ validityOfferApprovalJson: JSON.stringify(validityData) })
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Validity of offer approval submitted successfully', 'success');
                    setTimeout(() => { window.location.reload(); }, 1500);
                } else {
                    this.showToast('Info', result, 'info');
                    this.isSaveDisabled = false;
                }
            })
            .catch(error => {
                this.isSaveDisabled = false;
                this.showToast('Error', error.body?.message || 'An error occurred while submitting validity of offer approval', 'error');
            });
    }

    // ── Total Value Approval Handlers ──────────────────────────────────────
    handleTotalValueStatusChange(event) {
        const { quoteId, field, value } = event.detail;
        const totalValue = this.totalValueApprovalsMap.get(quoteId);

        if (totalValue) {
            totalValue[`${field}ValueStatus`] = value;
            totalValue.updated = true;
            this.totalValueApprovalsMap = new Map(this.totalValueApprovalsMap);

            this.quotes = this.quotes.map(q => {
                if (q.quoteId === quoteId) {
                    return { ...q, totalValueApproval: { ...totalValue } };
                }
                return q;
            });
        }
    }

    handleTotalValueCommentChange(event) {
        const { quoteId, field, value } = event.detail;
        const totalValue = this.totalValueApprovalsMap.get(quoteId);

        if (totalValue) {
            totalValue[`${field}ValueComments`] = value;
            totalValue.updated = true;
            this.totalValueApprovalsMap = new Map(this.totalValueApprovalsMap);

            this.quotes = this.quotes.map(q => {
                if (q.quoteId === quoteId) {
                    return { ...q, totalValueApproval: { ...totalValue } };
                }
                return q;
            });
        }
    }

    handleTotalValueSubmit(event) {
        const { totalValueData } = event.detail;

        if (!totalValueData || !totalValueData.updated) {
            this.showToast('Warning', 'No changes to submit for total value approval', 'warning');
            return;
        }

        this.isSaveDisabled = true;
        submitTotalValueApprovalSingle({ totalValueApprovalJson: JSON.stringify(totalValueData) })
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Total value approval submitted successfully', 'success');
                    setTimeout(() => { window.location.reload(); }, 1500);
                } else {
                    this.showToast('Info', result, 'info');
                    this.isSaveDisabled = false;
                }
            })
            .catch(error => {
                this.isSaveDisabled = false;
                this.showToast('Error', error.body?.message || 'An error occurred while submitting total value approval', 'error');
            });
    }

    // ── Minimum Offer Approval Handlers ────────────────────────────────────
    handleMinimumOfferStatusChange(event) {
        const { quoteId, field, value } = event.detail;
        const minimumOffer = this.minimumOfferApprovalsMap.get(quoteId);

        if (minimumOffer) {
            minimumOffer[`${field}MinOfferStatus`] = value;
            minimumOffer.updated = true;
            this.minimumOfferApprovalsMap = new Map(this.minimumOfferApprovalsMap);

            this.quotes = this.quotes.map(q => {
                if (q.quoteId === quoteId) {
                    return { ...q, minimumOfferApproval: { ...minimumOffer } };
                }
                return q;
            });
        }
    }

    handleMinimumOfferCommentChange(event) {
        const { quoteId, field, value } = event.detail;
        const minimumOffer = this.minimumOfferApprovalsMap.get(quoteId);

        if (minimumOffer) {
            minimumOffer[`${field}MinOfferComments`] = value;
            minimumOffer.updated = true;
            this.minimumOfferApprovalsMap = new Map(this.minimumOfferApprovalsMap);

            this.quotes = this.quotes.map(q => {
                if (q.quoteId === quoteId) {
                    return { ...q, minimumOfferApproval: { ...minimumOffer } };
                }
                return q;
            });
        }
    }

    handleMinimumOfferSubmit(event) {
        const { minimumOfferData } = event.detail;

        if (!minimumOfferData || !minimumOfferData.updated) {
            this.showToast('Warning', 'No changes to submit for minimum offer approval', 'warning');
            return;
        }

        this.isSaveDisabled = true;
        submitMinimumOfferApprovalSingle({ minimumOfferApprovalJson: JSON.stringify(minimumOfferData) })
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Minimum offer approval submitted successfully', 'success');
                    setTimeout(() => { window.location.reload(); }, 1500);
                } else {
                    this.showToast('Info', result, 'info');
                    this.isSaveDisabled = false;
                }
            })
            .catch(error => {
                this.isSaveDisabled = false;
                this.showToast('Error', error.body?.message || 'An error occurred while submitting minimum offer approval', 'error');
            });
    }

    /** Returns a CSS class string for the status badge. */
    getStatusBadgeClass(status) {
        const base = 'status-badge';
        if (!status) return `${base} status-badge--default`;
        const n = status.toLowerCase();
        if (n === 'approved')  return `${base} status-badge--approved`;
        if (n === 'rejected')  return `${base} status-badge--rejected`;
        if (n === 'submitted') return `${base} status-badge--submitted`;
        return `${base} status-badge--default`;
    }

    buildDisplayRows(lineItems) {
        const displayRows = [];
        (lineItems || []).forEach(item => {
            const soaLevels = this.getSoaLevels(item);
            soaLevels.forEach((soa, idx) => {
                const formattedDateTime = soa.dateTime
                    ? new Date(soa.dateTime).toLocaleString('en-GB', {
                        day: '2-digit', month: '2-digit', year: 'numeric',
                        hour: '2-digit', minute: '2-digit'
                      })
                    : '';
                const skipCommentEnabled   = this.isSkipCommentEnabled(item, soa);
                const skipFinalStatusEnabled = this.skipSoaRestrictions && this.isFinalPreviousHierarchyRow(item, soa);
                const showStatusCombobox   = (item.isFinalDiscountApprover && soa.isCurrentUserRow && item.isEditable) || skipFinalStatusEnabled;
                const showCommentInput     = (soa.isCurrentUserRow && item.isEditable) || skipCommentEnabled;
                const soaStatus            = soa.status || '';

                displayRows.push({
                    key:              `${item.quoteLineItemId}_${idx}`,
                    isFirstRow:       idx === 0,
                    soaCount:         soaLevels.length,
                    productName:      item.productName,
                    listPrice:        item.listPrice,
                    quantity:         item.quantity,
                    d1:               item.d1,
                    previousDiscount: item.previousDiscount,
                    d2:               item.d2,
                    quoteLineItemId:  item.quoteLineItemId,
                    parentId:         item.parentId,
                    approvalStatus:   skipFinalStatusEnabled ? soa.status : item.approvalStatus,
                    soaStatusField:   soa.statusField,
                    soaDisplay:       soa.name ? `${soa.label} - ${soa.name}` : '',
                    soaStatus,
                    statusBadgeClass: this.getStatusBadgeClass(soaStatus),
                    soaDateTime:      formattedDateTime,
                    prevSoaComments:  soa.previousCommentsValue || '',
                    soaComments:      soa.commentsValue || '',
                    soaCommentsField: soa.commentsField,
                    showStatusCombobox,
                    showStatusText:   !showStatusCombobox,
                    showCommentInput,
                    soaCommentsDisabled: !(soa.isCurrentUserRow && item.isEditable) && !skipCommentEnabled,
                    rowStyle: ''
                });
            });
        });
        return displayRows;
    }

    getSoaLevels(item) {
        return [
            {
                label: 'SM', name: item.salesManagerName, approverId: item.salesManagerId,
                status: item.salesManagerStatus, statusField: 'Sales_Manager_Status__c',
                dateTime: item.salesManagerDateTime, commentsField: 'Sales_Manager_Comments',
                commentsValue: item.Sales_Manager_Comments,
                previousCommentsValue: item.prevSalesManagerComments,
                isCurrentUserRow: !item.bcheck1, hierarchyIndex: 1
            },
            {
                label: 'CH', name: item.countryContinentSalesName, approverId: item.countryContinentSalesId,
                status: item.countryContinentSalesStatus, statusField: 'Country_Continent_Sales_H_LOB_Status__c',
                dateTime: item.countryHeadDateTime, commentsField: 'Country_Continent_Sales_LOB_Comments',
                commentsValue: item.Country_Continent_Sales_LOB_Comments,
                previousCommentsValue: item.prevCountryContinentSalesComments,
                isCurrentUserRow: !item.bcheck2, hierarchyIndex: 2
            },
            {
                label: 'GS', name: item.globalSalesHeadName, approverId: item.globalSalesHeadId,
                status: item.globalSalesHeadStatus, statusField: 'Global_Sales_Head_Status__c',
                dateTime: item.globalSalesHeadDateTime, commentsField: 'Global_Sales_Head_Comments',
                commentsValue: item.Global_Sales_Head_Comments,
                previousCommentsValue: item.prevGlobalSalesHeadComments,
                isCurrentUserRow: !item.bcheck5, hierarchyIndex: 3
            },
            {
                label: 'BM', name: item.rotexBoardMemberName, approverId: item.rotexBoardMemberId,
                status: item.rotexBoardMemberStatus, statusField: 'Rotex_Board_Member_Status__c',
                dateTime: item.rotexBoardMemberDateTime, commentsField: 'Rotex_Board_Member_Comments',
                commentsValue: item.Rotex_Board_Member_Comments,
                previousCommentsValue: item.prevRotexBoardMemberComments,
                isCurrentUserRow: !item.bcheck3, hierarchyIndex: 4
            },
            {
                label: 'MD', name: item.managingDirectorName, approverId: item.managingDirectorId,
                status: item.managingDirectorStatus, statusField: 'Managing_Director_Status__c',
                dateTime: item.managingDirectorDateTime, commentsField: 'Managing_Director_Comments',
                commentsValue: item.Managing_Director_Comments,
                previousCommentsValue: item.prevManagingDirectorComments,
                isCurrentUserRow: !item.bcheck4, hierarchyIndex: 5
            }
        ];
    }

    isPreviousHierarchyRow(item, hierarchyIndex) {
        const currentUserIndex = this.getCurrentUserHierarchyIndex(item);
        return currentUserIndex && hierarchyIndex < currentUserIndex;
    }

    isFinalPreviousHierarchyRow(item, soa) {
        return this.isPreviousHierarchyRow(item, soa.hierarchyIndex) &&
               soa.approverId === item.finalDiscountApproverId;
    }

    isSkipCommentEnabled(item, soa) {
        return this.skipSoaRestrictions &&
               item.skipEditableCommentFields &&
               item.skipEditableCommentFields[soa.commentsField] === true;
    }

    getCurrentUserHierarchyIndex(item) {
        if (item.bcheck1 === false) return 1;
        if (item.bcheck2 === false) return 2;
        if (item.bcheck5 === false) return 3;
        if (item.bcheck3 === false) return 4;
        if (item.bcheck4 === false) return 5;
        return null;
    }

    handleToggleSkipSoaRestrictions(event) {
        this.skipSoaRestrictions = event.target.checked;

        if (this.skipSoaRestrictions) {
            this.quotes = (this.quotes || []).map(quote => {
                const quoteLineItems = (quote.quoteLineItems || []).map(item => ({
                    ...item,
                    skipSoaRestrictions: true,
                    skipEditableCommentFields: {
                        ...(item.skipEditableCommentFields || {}),
                        ...this.getSkipEditableCommentFields(item)
                    }
                }));
                return { ...quote, quoteLineItems, displayRows: this.buildDisplayRows(quoteLineItems) };
            });
        } else {
            this.quotes = (this.quotes || []).map(quote => {
                const quoteLineItems = (quote.quoteLineItems || []).map(item => {
                    const clearedItem  = { ...item };
                    const skipFields   = item.skipEditableCommentFields || {};
                    Object.keys(skipFields).forEach(f => { if (skipFields[f] === true) clearedItem[f] = null; });
                    this.getSoaLevels(item).forEach(soa => {
                        if (this.isFinalPreviousHierarchyRow(item, soa)) clearedItem.approvalStatus = null;
                    });
                    return { ...clearedItem, skipSoaRestrictions: false, skipEditableCommentFields: {} };
                });
                return { ...quote, quoteLineItems, displayRows: this.buildDisplayRows(quoteLineItems) };
            });
        }
    }

    getSkipEditableCommentFields(item) {
        const editable = {};
        this.getSoaLevels(item).forEach(soa => {
            if (this.isPreviousHierarchyRow(item, soa.hierarchyIndex) && !this.hasValue(soa.commentsValue)) {
                editable[soa.commentsField] = true;
            }
        });
        return editable;
    }

    handleLineItemChanges(event) {
        const field      = event.target.dataset.field;
        const lineItemId = event.target.dataset.id;
        const parentId   = event.target.dataset.parent;
        const value      = event.target.value;
        const stageField = event.target.dataset.stageField;

        const specificQuote        = this.quotes.find(q => q.quoteId == parentId);
        const specificQuoteLineItem = specificQuote.quoteLineItems.find(qli => qli.quoteLineItemId == lineItemId);

        specificQuoteLineItem[field] = value;
        if (field === 'approvalStatus' && stageField) {
            specificQuoteLineItem.currentStageField = stageField;
            this.setStageStatusValue(specificQuoteLineItem, stageField, value);
        }
        specificQuoteLineItem.skipSoaRestrictions = this.skipSoaRestrictions;
        specificQuoteLineItem['updated'] = true;
        specificQuote['updated']         = true;
        specificQuote.displayRows        = this.buildDisplayRows(specificQuote.quoteLineItems);
        this.quotes = [...this.quotes];
    }

    setStageStatusValue(lineItem, stageField, value) {
        if (stageField === 'Sales_Manager_Status__c')                   lineItem.salesManagerStatus = value;
        else if (stageField === 'Country_Continent_Sales_H_LOB_Status__c') lineItem.countryContinentSalesStatus = value;
        else if (stageField === 'Global_Sales_Head_Status__c')           lineItem.globalSalesHeadStatus = value;
        else if (stageField === 'Rotex_Board_Member_Status__c')          lineItem.rotexBoardMemberStatus = value;
        else if (stageField === 'Managing_Director_Status__c')           lineItem.managingDirectorStatus = value;
    }

    validateQuoteData() {
        if (!this.requiresNonFinalApproverComment()) return true;
        this.showToast('Error', 'Enter at least one comment before submitting.', 'error');
        return false;
    }

    requiresNonFinalApproverComment() {
        if (!this.quotes) return false;
        let hasCommentOnlyLine    = false;
        let hasCurrentUserComment = false;

        for (const quote of this.quotes) {
            for (const item of quote.quoteLineItems || []) {
                const required = this.getRequiredCommentFields(item);
                if (!required.length) continue;
                hasCommentOnlyLine = true;
                if (required.some(f => this.hasValue(item[f]))) {
                    hasCurrentUserComment = true;
                    break;
                }
            }
            if (hasCurrentUserComment) break;
        }

        return hasCommentOnlyLine && !hasCurrentUserComment;
    }

    getRequiredCommentFields(item) {
        const required          = [];
        const currentUserComment = this.getCurrentUserComment(item);
        if (currentUserComment && !item.isFinalDiscountApprover && item.isEditable) {
            required.push(currentUserComment.fieldName);
        }
        Object.keys(item.skipEditableCommentFields || {}).forEach(f => {
            if (item.skipEditableCommentFields[f] === true) required.push(f);
        });
        return required;
    }

    getCurrentUserComment(item) {
        if (item.bcheck1 === false) return { fieldName: 'Sales_Manager_Comments' };
        if (item.bcheck2 === false) return { fieldName: 'Country_Continent_Sales_LOB_Comments' };
        if (item.bcheck3 === false) return { fieldName: 'Rotex_Board_Member_Comments' };
        if (item.bcheck4 === false) return { fieldName: 'Managing_Director_Comments' };
        if (item.bcheck5 === false) return { fieldName: 'Global_Sales_Head_Comments' };
        return null;
    }

    hasValue(value) {
        return value !== undefined && value !== null && String(value).trim() !== '';
    }

    saveChanges() {
        this.isSaveDisabled = true;
        const valid = this.validateQuoteData();

        console.log('Final Quote List', JSON.stringify(this.quotes));

        setTimeout(() => {
            if (valid) {
                // Only submit discount approvals through main Submit button
                // Warranty approvals now have their own separate Submit button
                const discountPromise = updateQuoteLineItem({
                    quotationListStringObject: JSON.stringify(this.quotes)
                });

                discountPromise
                    .then(result => {
                        if (result === 'Success') {
                            this.showToast('Success', 'Discount approvals updated successfully', 'success');
                            setTimeout(() => { window.location.reload(); }, 1500);
                        } else {
                            this.showToast('Error', 'Update failed', 'error');
                            this.isSaveDisabled = false;
                        }
                    })
                    .catch(error => {
                        this.isSaveDisabled = false;
                        this.showToast('Error', error.body?.message || 'An error occurred', 'error');
                    });
            } else {
                this.isSaveDisabled = false;
            }
        }, 1000);
    }

    redirectToHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'home' }
        });
    }

    showToast(title, msg, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant }));
    }
}