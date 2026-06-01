import { LightningElement, track, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllQuotations from '@salesforce/apex/SalesPriceApprovalForQuotation.getAllQuotations';
import updateQuoteLineItem from '@salesforce/apex/SalesPriceApprovalForQuotation.updateQuoteLineItem';
import submitWarrantyApprovalSingle from '@salesforce/apex/SalesPriceApprovalForQuotation.submitWarrantyApprovalSingle';
import submitValidityOfferApprovalSingle from '@salesforce/apex/SalesPriceApprovalForQuotation.submitValidityOfferApprovalSingle';
import submitTotalValueApprovalSingle from '@salesforce/apex/SalesPriceApprovalForQuotation.submitTotalValueApprovalSingle';
// import submitMinimumOfferApprovalSingle from '@salesforce/apex/SalesPriceApprovalForQuotation.submitMinimumOfferApprovalSingle';
import submitUnifiedQuoteApprovals from '@salesforce/apex/SalesPriceApprovalForQuotation.submitUnifiedQuoteApprovals';
import USER_ID from '@salesforce/user/Id';
import { NavigationMixin } from 'lightning/navigation';

import QUOTE_OBJECT from '@salesforce/schema/Quote';
import WARRANTY_TERMS_FIELD from '@salesforce/schema/Quote.Warranty_Terms__c';
import VALIDITY_OF_OFFER_FIELD from '@salesforce/schema/Quote.Validity_of_Offer__c';

export default class QuoteSalesPriceApproval extends NavigationMixin(LightningElement) {
    @track quotes;
    @track updatedLineItems = new Map();
    @track isSaveDisabled = false;
    @track skipSoaRestrictions = false;
    @track activeTab = 'pending';

    @track showTaskModal = false;
    @track taskModalApproverId = null;
    @track taskModalApproverName = null;
    @track taskModalQuoteId = null;

    /**
     * ✅ FIX: warrantyApprovalsMap is now populated inside fetchQuotes() from
     *         the warrantyApproval embedded in every QuotationWrapper returned
     *         by getAllQuotations().  Previously this map was always empty
     *         because getWarrantyApprovals() was imported but never called.
     */
    @track warrantyApprovalsMap = new Map();
    @track validityOfferApprovalsMap = new Map();
    @track totalValueApprovalsMap = new Map();
    // @track minimumOfferApprovalsMap = new Map();

    userId = USER_ID;

    @track statusOptions = [
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Approved',  value: 'Approved'  },
        { label: 'Rejected',  value: 'Rejected'  }
    ];

    @wire(getObjectInfo, { objectApiName: QUOTE_OBJECT })
    quoteObjectInfo;

    @track warrantyOptions = [];

    @wire(getPicklistValues, {
        recordTypeId: '$quoteObjectInfo.data.defaultRecordTypeId',
        fieldApiName: WARRANTY_TERMS_FIELD
    })
    wiredWarrantyTerms({ data, error }) {
        if (data) {
            this.warrantyOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
            console.log('wiredWarrantyTerms data', JSON.parse(JSON.stringify(this.warrantyOptions)));
            this.refreshExpandedApprovalDashboards();
        } else if (error) {
            console.error(error);
        }
    }

    @track validityOfferOptions = [];

    @wire(getPicklistValues, {
        recordTypeId: '$quoteObjectInfo.data.defaultRecordTypeId',
        fieldApiName: VALIDITY_OF_OFFER_FIELD
    })
    wiredValidityOfferValues({ data, error }) {
        if (data) {
            this.validityOfferOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
            this.refreshExpandedApprovalDashboards();
        } else if (error) {
            console.error(error);
        }
    }

    error;

    get isLoading() {
        return this.isSaveDisabled;
    }

    get isSubmitDisabled() {
        return this.isSaveDisabled || this.requiresNonFinalApproverComment();
    }

    get showSkipSOAButton() {
        return this.activeTab === 'all';
    }

    // ── Tab class getters ──
    get allTabClass()      { return this.activeTab === 'all'      ? 'tab-btn tab-btn--active' : 'tab-btn'; }
    get pendingTabClass()  { return this.activeTab === 'pending'  ? 'tab-btn tab-btn--active' : 'tab-btn'; }
    get approvedTabClass() { return this.activeTab === 'approved' ? 'tab-btn tab-btn--active' : 'tab-btn'; }
    get rejectedTabClass() { return this.activeTab === 'rejected' ? 'tab-btn tab-btn--active' : 'tab-btn'; }

    // ── Tab badge counts ──
    get allCount()      { return this.quotes ? this.quotes.filter(quote => !quote._isFullyDecided).length : 0; }
    get pendingCount()  { return this._getTabCount('pending');  }
    get approvedCount() { return this._getTabCount('approved'); }
    get rejectedCount() { return this._getTabCount('rejected'); }

    /**
     * True when the active tab is Approved or Rejected.
     * Used in the HTML to hide the Submit button for those views.
     */
    get isApprovedOrRejectedTab() {
        return this.activeTab === 'approved' || this.activeTab === 'rejected';
    }

    /**
     * Quotes visible in the current tab.
     * - all      : every quote returned by the server
     * - pending  : quotes where the current user has at least one 'Submitted' status
     * - approved : quotes where the current user has at least one 'Approved' status
     * - rejected : quotes where the current user has at least one 'Rejected' status
     */
    get filteredQuotes() {
        if (!this.quotes) return [];
        let result;
        if (this.activeTab === 'all') {
            result = this.quotes.filter(q => !q._isFullyDecided);
        } else {
            result = this.quotes.filter(quote => {
                const statuses = this._getCurrentUserStatusesForQuote(quote);
                if (this.activeTab === 'pending')  return this._isQuotePendingForCurrentUser(quote);
                if (this.activeTab === 'approved') return statuses.some(s => s === 'Approved');
                if (this.activeTab === 'rejected') return statuses.some(s => s === 'Rejected');
                return true;
            });
        }
        return result.map(quote => ({
            ...quote,
            quoteHeaderClass: (this.activeTab === 'approved' && quote.isAllApprovalsFinalApproved)
                ? 'quote-header quote-header--final-approved'
                : 'quote-header'
        }));
    }

    get hasFilteredQuotes() {
        return this.filteredQuotes.length > 0;
    }

    // ── Tab change handler ──
    handleTabChange(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    /**
     * Collects all server-persisted status values that belong to the current user
     * for a given quote (across discount QLIs and combined approval flows).
     * Used to decide which tab a quote appears in.
     */
    _getCurrentUserStatusesForQuote(quote) {
        const statuses = [];

        // ── Discount QLI statuses ──
        // bcheckN === false means the current user IS that approver level
        for (const item of (quote.quoteLineItems || [])) {
            let status = null;
            if      (item.bcheck1 === false) status = item.origSalesManagerStatus          || item.salesManagerStatus;
            else if (item.bcheck2 === false) status = item.origCountryContinentSalesStatus  || item.countryContinentSalesStatus;
            else if (item.bcheck5 === false) status = item.origGlobalSalesHeadStatus        || item.globalSalesHeadStatus;
            else if (item.bcheck3 === false) status = item.origRotexBoardMemberStatus       || item.rotexBoardMemberStatus;
            else if (item.bcheck4 === false) status = item.origManagingDirectorStatus       || item.managingDirectorStatus;
            if (status) statuses.push(status);
        }

        // ── Combined approval statuses (warranty / validityOffer / totalValue) ──
        const combCfgs = [
            { map: this.warrantyApprovalsMap,      statusSuffix: 'WarrantyStatus'      },
            { map: this.validityOfferApprovalsMap, statusSuffix: 'ValidityOfferStatus' },
            { map: this.totalValueApprovalsMap,    statusSuffix: 'ValueStatus'         }
        ];
        for (const cfg of combCfgs) {
            const approval = cfg.map.get(quote.quoteId);
            if (!approval) continue;
            for (const level of ['sm', 'ch', 'gs', 'bm', 'md']) {
                if (approval[`is${this.capitalize(level)}CurrentUser`]) {
                    const origKey = `original${this.capitalize(level)}${cfg.statusSuffix}`;
                    const status  = approval[origKey] || approval[`${level}${cfg.statusSuffix}`];
                    if (status) statuses.push(status);
                }
            }
        }

        return statuses;
    }

    /** Returns the number of quotes that match the given tab filter. */
    _getTabCount(tab) {
        if (!this.quotes) return 0;
        return this.quotes.filter(quote => {
            if (tab === 'pending') return this._isQuotePendingForCurrentUser(quote);
            const statuses = this._getCurrentUserStatusesForQuote(quote);
            if (tab === 'approved') return statuses.some(s => s === 'Approved');
            if (tab === 'rejected') return statuses.some(s => s === 'Rejected');
            return false;
        }).length;
    }

    /**
     * Returns true when the quote should appear in the Pending tab:
     * current user has a 'Submitted' status AND the final approver
     * has not yet approved or rejected that row (Table 1 or Table 2).
     */
    _isQuotePendingForCurrentUser(quote) {
        // ── Table 2: Discount QLIs ──
        for (const item of (quote.quoteLineItems || [])) {
            let status = null;
            if      (item.bcheck1 === false) status = item.origSalesManagerStatus          || item.salesManagerStatus;
            else if (item.bcheck2 === false) status = item.origCountryContinentSalesStatus  || item.countryContinentSalesStatus;
            else if (item.bcheck5 === false) status = item.origGlobalSalesHeadStatus        || item.globalSalesHeadStatus;
            else if (item.bcheck3 === false) status = item.origRotexBoardMemberStatus       || item.rotexBoardMemberStatus;
            else if (item.bcheck4 === false) status = item.origManagingDirectorStatus       || item.managingDirectorStatus;

            if (status === 'Submitted') {
                const soaLevels  = this.getSoaLevels(item);
                const finalLevel = soaLevels.find(soa => soa.approverId === item.finalDiscountApproverId);
                if (finalLevel) {
                    const finalOrigStatus = finalLevel.originalStatus || '';
                    if (finalOrigStatus !== 'Approved' && finalOrigStatus !== 'Rejected') return true;
                }
            }
        }

        // ── Table 1: Combined approvals ──
        const levelByPos = { 1: 'sm', 2: 'ch', 3: 'gs', 4: 'bm', 5: 'md' };
        const combCfgs = [
            { map: this.warrantyApprovalsMap,      statusSuffix: 'WarrantyStatus'      },
            { map: this.validityOfferApprovalsMap, statusSuffix: 'ValidityOfferStatus' },
            { map: this.totalValueApprovalsMap,    statusSuffix: 'ValueStatus'         }
        ];
        for (const cfg of combCfgs) {
            const approval = cfg.map.get(quote.quoteId);
            if (!approval) continue;
            for (const level of ['sm', 'ch', 'gs', 'bm', 'md']) {
                if (!approval[`is${this.capitalize(level)}CurrentUser`]) continue;
                const origKey = `original${this.capitalize(level)}${cfg.statusSuffix}`;
                const status  = approval[origKey] || approval[`${level}${cfg.statusSuffix}`];
                if (status !== 'Submitted') continue;

                // Check final approver hasn't decided yet
                const finalLevel = levelByPos[approval.finalApproverHierarchyPosition];
                if (finalLevel) {
                    const finalOrigKey    = `original${this.capitalize(finalLevel)}${cfg.statusSuffix}`;
                    const finalOrigStatus = approval[finalOrigKey] || '';
                    if (finalOrigStatus !== 'Approved' && finalOrigStatus !== 'Rejected') return true;
                }
            }
        }
        return false;
    }

    connectedCallback() {
        this.fetchQuotes();
    }

    fetchQuotes(preserveExpandedQuoteIds = []) {
        getAllQuotations()
            .then(result => {
                const newWarrantyMap      = new Map();
                const newValidityMap      = new Map();
                const newTotalValueMap    = new Map();
                // const newMinimumOfferMap  = new Map();
                result.forEach(q => {
                    if (q.warrantyApproval)     newWarrantyMap.set(q.quoteId,     { ...q.warrantyApproval });
                    if (q.validityOfferApproval) newValidityMap.set(q.quoteId,    { ...q.validityOfferApproval });
                    if (q.totalValueApproval)   newTotalValueMap.set(q.quoteId,   { ...q.totalValueApproval });
                    // if (q.minimumOfferApproval) newMinimumOfferMap.set(q.quoteId, { ...q.minimumOfferApproval });
                });
                this.warrantyApprovalsMap      = newWarrantyMap;
                this.validityOfferApprovalsMap = newValidityMap;
                this.totalValueApprovalsMap    = newTotalValueMap;

                console.log('Fetched totalValueApprovalsMap', JSON.parse(JSON.stringify(this.totalValueApprovalsMap)));
                // this.minimumOfferApprovalsMap  = newMinimumOfferMap;

                this.quotes = result.map(q => {
                    const processed = this.processQuote(q);

                    // ── Restore expanded state for quotes that were open ──
                    if (preserveExpandedQuoteIds.includes(q.quoteId)) {
                        const warrantyApproval      = this.warrantyApprovalsMap.get(q.quoteId)      || null;
                        const validityOfferApproval = this.validityOfferApprovalsMap.get(q.quoteId) || null;
                        const totalValueApproval    = this.totalValueApprovalsMap.get(q.quoteId)    || null;
                        // const minimumOfferApproval  = this.minimumOfferApprovalsMap.get(q.quoteId)  || null;
                        const approvalDashboard     = this.buildApprovalDashboard({
                            warrantyApproval, validityOfferApproval, totalValueApproval
                        });
                        return {
                            ...processed,
                            isExpanded:                        true,
                            warrantyApproval,
                            validityOfferApproval,
                            totalValueApproval,
                            // minimumOfferApproval,
                            showApprovalDashboard:             approvalDashboard.rows.length > 0,
                            approvalColumns:                   approvalDashboard.columns,
                            approvalDashboardRows:             approvalDashboard.rows,
                            isCombinedApprovalSubmitDisabled:  true   // fresh data, nothing changed yet
                        };
                    }

                    return processed;
                }).filter(quote => {
                    quote._isFullyDecided = false;
                    const warrantyApproval      = this.warrantyApprovalsMap.get(quote.quoteId)      || null;
                    const validityOfferApproval = this.validityOfferApprovalsMap.get(quote.quoteId) || null;
                    const totalValueApproval    = this.totalValueApprovalsMap.get(quote.quoteId)    || null;
                    // const minimumOfferApproval  = this.minimumOfferApprovalsMap.get(quote.quoteId)  || null;

                    const dashboardRows = this.buildApprovalDashboard({
                        warrantyApproval, validityOfferApproval, totalValueApproval
                    }).rows;

                    // ── Visibility rule: hide a quote only when ALL backend approvals are 'Approved' ──
                    // Checks original (server-persisted) statuses only — live UI changes never trigger hiding.
                    // Table 1 (warranty / validity of offer / total value / minimum offer):
                    const isTable1FinalApproved = (approvalData, statusSuffix) => {
                        if (!approvalData) return true; // this approval type not applicable → don't block
                        const levelByPos = { 1: 'sm', 2: 'ch', 3: 'gs', 4: 'bm', 5: 'md' };
                        const finalPos   = approvalData.finalApproverHierarchyPosition;
                        if (!finalPos) return true;
                        const finalLevel = levelByPos[finalPos];
                        if (!finalLevel) return false;
                        const origKey = `original${this.capitalize(finalLevel)}${statusSuffix}`;
                        return (approvalData[origKey] || '') === 'Approved' || (approvalData[origKey] || '') === 'Rejected';
                    };

                    const allTable1Approved =
                        isTable1FinalApproved(warrantyApproval,      'WarrantyStatus')      &&
                        isTable1FinalApproved(validityOfferApproval, 'ValidityOfferStatus') &&
                        isTable1FinalApproved(totalValueApproval,    'ValueStatus')
                        // isTable1FinalApproved(minimumOfferApproval,  'MinOfferStatus');

                    console.log('WarrantyStatus final approved? ', isTable1FinalApproved(warrantyApproval, 'WarrantyStatus'));
                    console.log('ValidityOfferStatus final approved? ', isTable1FinalApproved(validityOfferApproval, 'ValidityOfferStatus'));
                    console.log('TotalValueStatus final approved? ', isTable1FinalApproved(totalValueApproval, 'ValueStatus'));

                    // Table 2 (discount QLIs): every QLI's final approver original status is 'Approved'
                    const allTable2Approved = (quote.quoteLineItems || []).every(item => {
                        const soaLevels  = this.getSoaLevels(item);
                        const finalLevel = soaLevels.find(soa => soa.approverId === item.finalDiscountApproverId);
                        if (!finalLevel) return true; // final approver not mapped → don't block
                        return (finalLevel.originalStatus || '') === 'Approved' || (finalLevel.originalStatus || '') === 'Rejected';
                    });

                    const hasContent = quote.hasLineItems || dashboardRows.length > 0;
                    if (!hasContent) return false;          // no approvals at all → already hidden
                    console.log(`Quote ${quote.quoteNumber} - allTable1Approved: ${allTable1Approved}, allTable2Approved: ${allTable2Approved}`);
                    if (allTable1Approved && allTable2Approved) {
                        quote._isFullyDecided = true;
                        const userStatuses = this._getCurrentUserStatusesForQuote(quote);
                        const hasDecidedStatus = userStatuses.some(s => s === 'Approved' || s === 'Rejected');
                        if (!hasDecidedStatus) return false;
                        return true;
                    }
                    return true;
                });

                console.log('Processed quotes', JSON.parse(JSON.stringify(this.quotes)));

                // ── Re-apply Skip SOA editable-field snapshots if the toggle is still ON ──
                // After a submit + re-fetch, processQuote resets skipEditableCommentFields/StatusFields
                // to {}. Re-compute them from the fresh server data so the UI stays consistent.
                if (this.skipSoaRestrictions) {
                    this.applySkipSoaToQuotes();
                }
            })
            .catch(error => {
                console.error('Error fetching quotations', error);
                // this.showToast('Error', error.body.message, 'error');
                // this.redirectToHome();
                // setTimeout(() => { window.location.reload(); }, 2500);
            });
    }

    /**
     * Re-applies Skip SOA editable-field snapshots to all line items using the
     * current (freshly fetched) data, then rebuilds displayRows and approval
     * dashboards. Called automatically by fetchQuotes() when Skip SOA is ON.
     */
    applySkipSoaToQuotes() {
        if (!this.skipSoaRestrictions || !this.quotes) return;
        this.quotes = this.quotes.map(quote => {
            const quoteLineItems = (quote.quoteLineItems || []).map(item => ({
                ...item,
                skipSoaRestrictions:       true,
                skipEditableCommentFields: this.getSkipEditableCommentFields(item),
                skipEditableStatusFields:  this.getSkipEditableStatusFields(item)
            }));
            return { ...quote, quoteLineItems, displayRows: this.buildDisplayRows(quoteLineItems) };
        });
        this.refreshExpandedApprovalDashboards();
    }

    processQuote(q) {
        const quoteRecordUrl = `/lightning/r/Quote/${q.quoteId}/view`;
        const processedLineItems = (q.quoteLineItems || []).map(item => ({
            ...item,
            isFinalDiscountApprover: item.finalDiscountApproverId === this.userId || item.finalDiscountApproverDelegatedId === this.userId,
            origApprovalStatus: item.approvalStatus,
            isEditable: item.approvalStatus === 'Submitted' || item.updated === true,
            skipSoaRestrictions: this.skipSoaRestrictions,
            skipEditableCommentFields: item.skipEditableCommentFields || {},
            skipEditableStatusFields: item.skipEditableStatusFields || {},
            // Snapshot the backend statuses at load time so that Skip SOA "already decided"
            // checks always compare against the persisted value, not the live UI state.
            origSalesManagerStatus:         item.salesManagerStatus,
            origCountryContinentSalesStatus: item.countryContinentSalesStatus,
            origGlobalSalesHeadStatus:       item.globalSalesHeadStatus,
            origRotexBoardMemberStatus:      item.rotexBoardMemberStatus,
            origManagingDirectorStatus:      item.managingDirectorStatus
        }));

        return {
            ...q,
            quoteRecordUrl,
            isExpanded: false,
            hasLineItems: (q.quoteLineItems || []).length > 0,
            warrantyApproval: null,
            validityOfferApproval: null,
            totalValueApproval: null,
            // minimumOfferApproval: null,
            showApprovalDashboard: false,
            approvalColumns: [],
            approvalDashboardRows: [],
            isCombinedApprovalSubmitDisabled: true,
            isUnifiedSubmitDisabled: true,
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
                // const minimumOfferApproval = expanded ? this.minimumOfferApprovalsMap.get(quoteId) : null;
                const approvalDashboard = this.buildApprovalDashboard({
                    warrantyApproval,
                    validityOfferApproval,
                    totalValueApproval
                    // minimumOfferApproval
                });
                const hasDiscountChanges = this.hasDiscountChanges(quote);
                const hasCombinedChanges = approvalDashboard.hasChanges;
                return {
                    ...quote,
                    isExpanded: expanded,
                    warrantyApproval,
                    validityOfferApproval,
                    totalValueApproval,
                    // minimumOfferApproval,
                    showApprovalDashboard: expanded && approvalDashboard.rows.length > 0,
                    approvalColumns: approvalDashboard.columns,
                    approvalDashboardRows: approvalDashboard.rows,
                    isCombinedApprovalSubmitDisabled: this.isSaveDisabled || !approvalDashboard.hasChanges,
                    isUnifiedSubmitDisabled: this.isSaveDisabled || (!hasDiscountChanges && !hasCombinedChanges)
                };
            }
            return quote;
        });
    }

    buildApprovalDashboard(quote) {
        const columns = this.buildApprovalColumns(quote);
        const rows = [
            this.buildApprovalRow('warranty', 'Warranty Terms', quote.warrantyApproval, {
                currentValueKey: 'warrantyTerms',
                requestedValueKey: 'warrantyTermsDraft',
                statusSuffix: 'WarrantyStatus',
                commentsSuffix: 'WarrantyComments',
                dateTimeSuffix: 'WarrantyDateTime'
            }, columns),
            this.buildApprovalRow('totalValue', 'Total Value', quote.totalValueApproval, {
                currentValueKey: 'totalValue',
                requestedValueKey: 'totalValue',
                statusSuffix: 'ValueStatus',
                commentsSuffix: 'ValueComments',
                dateTimeSuffix: 'ValueDateTime'
            }, columns),
            // this.buildApprovalRow('minimumOffer', 'Min Offer Value', quote.minimumOfferApproval, {
            //     currentValueKey: 'totalValue',
            //     requestedValueKey: 'totalValue',
            //     statusSuffix: 'MinOfferStatus',
            //     commentsSuffix: 'MinOfferComments',
            //     dateTimeSuffix: 'MinOfferDateTime'
            // }, columns),
            this.buildApprovalRow('validityOffer', 'Validity Offer', quote.validityOfferApproval, {
                currentValueKey: 'validityOfOffer',
                requestedValueKey: 'requestedValidityOfOffer',
                statusSuffix: 'ValidityOfferStatus',
                commentsSuffix: 'ValidityOfferComments',
                dateTimeSuffix: 'ValidityOfferDateTime'
            }, columns)
        ].filter(row => row != null);

        return {
            columns,
            rows,
            hasChanges: true
        };
    }

    buildApprovalColumns(quote) {
        const levels = [
            { key: 'sm', label: 'SM' },
            { key: 'ch', label: 'CH' },
            { key: 'gs', label: 'GS' },
            { key: 'bm', label: 'BM' },
            { key: 'md', label: 'MD' }
        ];
        const approvals = [
            quote.warrantyApproval,
            quote.validityOfferApproval,
            quote.totalValueApproval
            // quote.minimumOfferApproval
        ].filter(approval => approval != null);

        return levels.map(level => {
            const name = approvals.map(approval => approval[`${level.key}Name`]).find(value => this.hasValue(value));
            return {
                key: level.key,
                label: name ? `${level.label} - ${name}` : level.label
            };
        });
    }

    buildApprovalRow(type, label, data, config, columns) {
        if (!data) return null;

        // Show the row if the current user is any approver in this chain (regardless of status).
        // If not in chain at all → don't show.
        const levels = ['sm', 'ch', 'gs', 'bm', 'md'];
        const currentUserIsInChain = levels.some(level => data[`is${this.capitalize(level)}CurrentUser`]);
        if (!currentUserIsInChain) return null;
        if (!levels.some(level => this.hasValue(data[`${level}${config.statusSuffix}`]))) return null;

        return {
            type,
            label,
            statusKey: `${type}-status`,
            commentsKey: `${type}-comments`,
            dateTimeKey: `${type}-datetime`,
            currentValue: this.formatApprovalValue(data[config.currentValueKey]),
            requestedValue: this.formatApprovalValue(data[config.requestedValueKey]),
            requestedValueOptions: this.getRequestedValueOptions(type, data, data[config.requestedValueKey]),
            showRequestedValueCombobox: this.canEditRequestedApprovalValue(type, data),
            approvers: columns.map(column => this.buildApprovalApprover(type, data, config, column.key))
        };
    }

    getRequestedValueOptions(type, data, requestedValue) {
        const sourceOptions = type === 'warranty'
            ? this.warrantyOptions
            : type === 'validityOffer'
                ? this.validityOfferOptions
                : [];
        const allowedOptions = type === 'warranty'
            ? data.allowedWarrantyTerms
            : type === 'validityOffer'
                ? data.allowedValidityOfferValues
                : [];

        let filteredOptions = this.filterRequestedValueOptionsBySoa(
            type,
            sourceOptions,
            allowedOptions,
            data.finalApproverHierarchyPosition
        );

        if (
            this.hasValue(requestedValue) &&
            !filteredOptions.some(
                opt => this.normalizeOptionValue(opt.value) === this.normalizeOptionValue(requestedValue)
            )
        ) {
            filteredOptions = [{ label: requestedValue, value: requestedValue }, ...filteredOptions];
        }

        return filteredOptions;
    }

    filterRequestedValueOptionsBySoa(type, sourceOptions, allowedOptions, finalApproverHierarchyPosition) {
        if (!sourceOptions || !sourceOptions.length) return [];

        if (allowedOptions && allowedOptions.length) {
            const allowedValues = new Set(
                allowedOptions
                    .map(option => this.normalizeApprovalLimitValue(type, option.value || option.label))
                    .filter(value => value)
            );
            return sourceOptions.filter(option =>
                allowedValues.has(this.normalizeApprovalLimitValue(type, option.value)) ||
                allowedValues.has(this.normalizeApprovalLimitValue(type, option.label))
            );
        }

        if (finalApproverHierarchyPosition !== null && finalApproverHierarchyPosition !== undefined) {
            return sourceOptions.slice(0, Number(finalApproverHierarchyPosition) + 1);
        }

        return sourceOptions;
    }

    normalizeOptionValue(value) {
        return this.hasValue(value) ? String(value).trim().toLowerCase() : '';
    }

    normalizeApprovalLimitValue(type, value) {
        const normalized = this.normalizeOptionValue(value);
        if (!normalized) return '';

        if (type === 'warranty') {
            if (normalized.includes('more than 48')) return 'more-than-48-months';
            const match = normalized.match(/(\d+)\s*months?/);
            return match ? `${match[1]}-months` : normalized;
        }

        if (type === 'validityOffer') {
            if (normalized.includes('more than 365')) return 'more-than-365-days';
            const match = normalized.match(/(\d+)\s*days?/);
            return match ? `${match[1]}-days` : normalized;
        }

        return normalized;
    }

    refreshExpandedApprovalDashboards() {
        if (!this.quotes) return;

        this.quotes = this.quotes.map(quote => {
            if (!quote.isExpanded) return quote;

            const approvalDashboard = this.buildApprovalDashboard({
                warrantyApproval: quote.warrantyApproval,
                validityOfferApproval: quote.validityOfferApproval,
                totalValueApproval: quote.totalValueApproval
                // minimumOfferApproval: quote.minimumOfferApproval
            });

            return {
                ...quote,
                showApprovalDashboard: approvalDashboard.rows.length > 0,
                approvalColumns: approvalDashboard.columns,
                approvalDashboardRows: approvalDashboard.rows
            };
        });
    }

    canEditRequestedApprovalValue(type, data) {
        if (type !== 'warranty' && type !== 'validityOffer') return false;
        const config = this.getCombinedApprovalConfig(type);
        if (!config) return false;
        const levels = ['sm', 'ch', 'gs', 'bm', 'md'];

        const isFinalApprover = levels.some(level => {
            const isCurrentUser = !!data[`is${this.capitalize(level)}CurrentUser`];
            const originalStatus = data[`original${this.capitalize(level)}${config.statusSuffix}`];
            return isCurrentUser &&
                this.isFinalApproverLevel(data, level)
        });

        const isFinalApproverEditing = levels.some(level => {
            const isCurrentUser = !!data[`is${this.capitalize(level)}CurrentUser`];
            const originalStatus = data[`original${this.capitalize(level)}${config.statusSuffix}`];
            return isCurrentUser &&
                this.isFinalApproverLevel(data, level) 
                && originalStatus === 'Submitted';
        });
        if (isFinalApproverEditing) return true;

        if (this.skipSoaRestrictions && (!!data.isHigherHierarchy || isFinalApprover)) {
            const finalApproverStillPending = levels.some(level => {
                if (!this.isFinalApproverLevel(data, level)) return false;
                const originalStatus = data[`original${this.capitalize(level)}${config.statusSuffix}`];
                return originalStatus !== 'Approved' && originalStatus !== 'Rejected';
            });
            if (finalApproverStillPending) return true;
        }

        return false;
    }

    buildApprovalApprover(type, data, config, level) {
        const actualStatus = data[`${level}${config.statusSuffix}`] || '';

        const isFinalApproverForThisLevel = this.isFinalApproverLevel(data, level);
        const isBeyondFinalApprover = this.isBeyondFinalApproverLevel(data, level);

        const displayStatus = this.getDisplayStatus(
            actualStatus,
            isFinalApproverForThisLevel
        );
        const comments = data[`${level}${config.commentsSuffix}`] || '';
        const isCurrentUser = !!data[`is${this.capitalize(level)}CurrentUser`];

        // Server grants edit permission only when the original DB status was 'Submitted'.
        const serverCanEditStatus   = !!data[`can${this.capitalize(level)}EditStatus`];
        const serverCanEditComments = !!data[`can${this.capitalize(level)}EditComments`];

        // ── Skip SOA (New Behavior) ───────────────────────────────────────
        // Case 1: current user = final approver  → own row only (status + comments)
        // Case 2: current user LOWER than final  → own comments only
        // Case 3: current user HIGHER than final → only final approver's level (status + comments)
        const levelIndex = this.getApprovalLevelIndex(level);
        const finalPos   = data.finalApproverHierarchyPosition;
        const currentUserPos = data.currentUserHierarchyPosition;

        // Higher hierarchy: current user is ABOVE the final approver (higher index = higher seniority)
        const isHigherHierarchyWithSkip = this.skipSoaRestrictions && !!data.isHigherHierarchy;

        // Was this level's status already decided in the backend (not editable via Skip SOA)?
        const originalStatusKey = `original${this.capitalize(level)}${config.statusSuffix}`;
        const originalStatus = data[originalStatusKey] || '';
        const isAlreadyDecidedByBackend = originalStatus === 'Approved' || originalStatus === 'Rejected';

        // Lock entire row for everyone once the final approver has approved or rejected
        const allLevels_ = ['sm', 'ch', 'gs', 'bm', 'md'];
        const isFinalApproverDecided = allLevels_.some(lvl => {
            const origKey = `original${this.capitalize(lvl)}${config.statusSuffix}`;
            return this.isFinalApproverLevel(data, lvl) &&
                (data[origKey] === 'Approved' || data[origKey] === 'Rejected');
        });

        // Case 3: Higher hierarchy → enable ONLY the final approver's level (status + comments)
        const skipSoaHigherHierarchyFinalLevel = isHigherHierarchyWithSkip &&
            !isCurrentUser && isFinalApproverForThisLevel && !isAlreadyDecidedByBackend;

        const skipSoaShowCommentInput  = skipSoaHigherHierarchyFinalLevel;
        const skipSoaShowStatusCombobox = skipSoaHigherHierarchyFinalLevel;
        // ─────────────────────────────────────────────────────────────────

        // Case 1: Current user IS the final approver → own status + comments enabled
        const isOwnFinalLevelSkipSoa = this.skipSoaRestrictions && isCurrentUser &&
            isFinalApproverForThisLevel && !isAlreadyDecidedByBackend;

        // Case 2: Current user LOWER than final → own comments enabled
        // Also covers Case 1 comments (isOwnFinalLevelSkipSoa handles status for Case 1)
        // NOT applied for Case 3 (higher hierarchy) — higher-hierarchy users only edit the final's row
        const isOwnLevelWithSkipSoa = this.skipSoaRestrictions && isCurrentUser &&
            !isAlreadyDecidedByBackend && !isHigherHierarchyWithSkip;

        const showStatusCombobox = !isFinalApproverDecided &&
            ((isCurrentUser && serverCanEditStatus) || skipSoaShowStatusCombobox || isOwnFinalLevelSkipSoa);

        const showCommentInput = !isFinalApproverDecided &&
            ((isCurrentUser && serverCanEditComments) || skipSoaShowCommentInput || isOwnLevelWithSkipSoa);

        return {
            field: level,
            status: actualStatus,
            displayStatus,
            comments,
            dateTime: this.formatDateTime(data[`${level}${config.dateTimeSuffix}`]),
            showStatusCombobox: showStatusCombobox && !isBeyondFinalApprover,
            showCommentInput: showCommentInput && !isBeyondFinalApprover,
            statusCellClass: isBeyondFinalApprover
                ? 'approval-status-cell approval-status-datetime-cell approval-cell--not-applicable'
                : 'approval-status-cell approval-status-datetime-cell',
            commentCellClass: isBeyondFinalApprover
                ? 'approval-comment-cell approval-cell--not-applicable'
                : 'approval-comment-cell',
            isBeyondFinalApprover,
            statusBadgeClass: this.getStatusBadgeClass(displayStatus),
            statusKey: `${type}-${level}-status`,
            commentsKey: `${type}-${level}-comments`,
            dateTimeKey: `${type}-${level}-datetime`
        };
    }

    isFinalApproverLevel(data, level) {
        // finalApprover is a string like 'SM','CH','GS','BM','MD'
        if (data.finalApprover) {
            return data.finalApprover.toUpperCase() === level.toUpperCase();
        }
        // fallback: check if the level's id matches the finalWarrantyApprover / finalValidityOfferApprover / etc.
        const levelId = data[`${level}Id`];
        const finalId = data.finalWarrantyApprover || data.finalValidityOfferApprover ||
                        data.finalTotalValueApprover || data.finalMinimumOfferValueApprover;
        return !!levelId && !!finalId && levelId === finalId;
    }

    isBeyondFinalApproverLevel(data, level) {
        const levelIndex = this.getApprovalLevelIndex(level);
        const finalIndex = data.finalApproverHierarchyPosition;
        return finalIndex && levelIndex && levelIndex > finalIndex;
    }

    getApprovalLevelIndex(level) {
        const indexes = { sm: 1, ch: 2, gs: 3, bm: 4, md: 5 };
        return indexes[level] || null;
    }

    formatApprovalValue(value) {
        if (value === undefined || value === null) return '';
        return String(value);
    }

    formatDateTime(dateTime) {
        if (!dateTime) return '';
        try {
            return new Date(dateTime).toLocaleString('en-GB', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        } catch (e) {
            return '';
        }
    }

    capitalize(value) {
        return value ? value.charAt(0).toUpperCase() + value.slice(1) : '';
    }

    handleCombinedApprovalStatusChange(event) {
        this.updateCombinedApproval(
            event.target.dataset.quoteId,
            event.target.dataset.approvalType,
            event.target.dataset.field,
            'status',
            event.detail.value
        );
    }

    handleCombinedApprovalCommentChange(event) {
        this.updateCombinedApproval(
            event.target.dataset.quoteId,
            event.target.dataset.approvalType,
            event.target.dataset.field,
            'comments',
            event.target.value
        );
    }

    handleRequestedApprovalValueChange(event) {
        const quoteId = event.target.dataset.quoteId;
        const approvalType = event.target.dataset.approvalType;
        const config = this.getCombinedApprovalConfig(approvalType);
        if (!config || !config.requestedValueField) return;

        const approvalMap = this[config.mapName];
        const approval = approvalMap.get(quoteId);
        if (!approval) return;

        approval[config.requestedValueField] = event.detail.value;
        approval.updated = true;
        this[config.mapName] = new Map(approvalMap);
        this.refreshQuoteApprovalDashboard(quoteId);
    }

    updateCombinedApproval(quoteId, approvalType, field, valueType, value) {
        const config = this.getCombinedApprovalConfig(approvalType);
        if (!config) return;

        const approvalMap = this[config.mapName];
        const approval = approvalMap.get(quoteId);
        if (!approval) return;

        approval[`${field}${valueType === 'status' ? config.statusSuffix : config.commentsSuffix}`] = value;
        approval.updated = true;

        this[config.mapName] = new Map(approvalMap);

        this.refreshQuoteApprovalDashboard(quoteId); // no parameter needed now
    }

    getCombinedApprovalConfig(approvalType) {
        const configs = {
            warranty: {
                mapName: 'warrantyApprovalsMap',
                dataName: 'warrantyApproval',
                requestedValueField: 'warrantyTermsDraft',
                statusSuffix: 'WarrantyStatus',
                commentsSuffix: 'WarrantyComments'
            },
            validityOffer: {
                mapName: 'validityOfferApprovalsMap',
                dataName: 'validityOfferApproval',
                requestedValueField: 'requestedValidityOfOffer',
                statusSuffix: 'ValidityOfferStatus',
                commentsSuffix: 'ValidityOfferComments'
            },
            totalValue: {
                mapName: 'totalValueApprovalsMap',
                dataName: 'totalValueApproval',
                statusSuffix: 'ValueStatus',
                commentsSuffix: 'ValueComments'
            }
            // minimumOffer: {
            //     mapName: 'minimumOfferApprovalsMap',
            //     dataName: 'minimumOfferApproval',
            //     statusSuffix: 'MinOfferStatus',
            //     commentsSuffix: 'MinOfferComments'
            // }
        };
        return configs[approvalType];
    }

    refreshQuoteApprovalDashboard(quoteId) {
        this.quotes = this.quotes.map(quote => {
            if (quote.quoteId !== quoteId) return quote;

            const warrantyApproval      = this.warrantyApprovalsMap.get(quoteId)      || null;
            const validityOfferApproval = this.validityOfferApprovalsMap.get(quoteId) || null;
            const totalValueApproval    = this.totalValueApprovalsMap.get(quoteId)    || null;
            // const minimumOfferApproval  = this.minimumOfferApprovalsMap.get(quoteId)  || null;

            const approvalData = { warrantyApproval, validityOfferApproval, totalValueApproval /*, minimumOfferApproval*/ };
            const approvalDashboard = this.buildApprovalDashboard(approvalData);

            // Derive hasChanges directly from the maps — no parameter needed
            const hasChanges =
                !!(warrantyApproval?.updated)      ||
                !!(validityOfferApproval?.updated) ||
                !!(totalValueApproval?.updated)
                // !!(minimumOfferApproval?.updated);

            const hasDiscountChanges = this.hasDiscountChanges(quote);
            return {
                ...quote,
                ...approvalData,
                showApprovalDashboard:            quote.isExpanded && approvalDashboard.rows.length > 0,
                approvalColumns:                  approvalDashboard.columns,
                approvalDashboardRows:            approvalDashboard.rows,
                isCombinedApprovalSubmitDisabled: !hasChanges,
                isUnifiedSubmitDisabled:          !hasChanges && !hasDiscountChanges
            };
        });
    }

    handleCombinedApprovalSubmit(event) {
        const quoteId = event.target.dataset.quoteId;
        const submissions = [];

        // ── Validate all visible fields (covers Skip SOA sequential + non-Skip-SOA "all visible") ──
        const inputError = this.validateCombinedApprovalInputs(quoteId);
        if (inputError) {
            this.showToast('Error', inputError, 'error');
            return;
        }

        // ── Validate: final approver must enter comments for combined approval ──
        const combinedValidationError = this.validateCombinedFinalApproverComments(quoteId);
        if (combinedValidationError) {
            this.showToast('Error', combinedValidationError, 'error');
            return;
        }

        const skipSoa = this.skipSoaRestrictions;

        const warrantyApproval = this.warrantyApprovalsMap.get(quoteId);
        if (warrantyApproval && warrantyApproval.updated) {
            submissions.push({
                label: 'Warranty Terms',
                promise: submitWarrantyApprovalSingle({ warrantyApprovalJson: JSON.stringify({ ...warrantyApproval, skipSoaRestrictions: skipSoa }) })
            });
        }

        const totalValueApproval = this.totalValueApprovalsMap.get(quoteId);
        if (totalValueApproval && totalValueApproval.updated) {
            submissions.push({
                label: 'Total Value',
                promise: submitTotalValueApprovalSingle({ totalValueApprovalJson: JSON.stringify({ ...totalValueApproval, skipSoaRestrictions: skipSoa }) })
            });
        }

        // const minimumOfferApproval = this.minimumOfferApprovalsMap.get(quoteId);
        // if (minimumOfferApproval && minimumOfferApproval.updated) {
        //     submissions.push({
        //         label: 'Min Offer Value',
        //         promise: submitMinimumOfferApprovalSingle({ minimumOfferApprovalJson: JSON.stringify({ ...minimumOfferApproval, skipSoaRestrictions: skipSoa }) })
        //     });
        // }

        const validityOfferApproval = this.validityOfferApprovalsMap.get(quoteId);
        if (validityOfferApproval && validityOfferApproval.updated) {
            submissions.push({
                label: 'Validity Offer',
                promise: submitValidityOfferApprovalSingle({ validityOfferApprovalJson: JSON.stringify({ ...validityOfferApproval, skipSoaRestrictions: skipSoa }) })
            });
        }

        if (!submissions.length) {
            this.showToast('Warning', 'No quote approval changes to submit', 'warning');
            return;
        }

        this.isSaveDisabled = true;
        this.refreshQuoteApprovalDashboard(quoteId);

        Promise.all(submissions.map(item => item.promise.then(result => ({ ...item, result }))))
            .then(results => {
                const nonSuccess = results.find(item => item.result !== 'Success');
                if (nonSuccess) {
                    this.showToast('Info', `${nonSuccess.label}: ${nonSuccess.result}`, 'info');
                    this.isSaveDisabled = false;
                    this.refreshQuoteApprovalDashboard(quoteId);
                    return;
                }

                this.showToast('Success', 'Quote approvals submitted successfully', 'success');
                this.isSaveDisabled = false;
                this.fetchQuotes([quoteId]);
            })
            .catch(error => {
                this.isSaveDisabled = false;
                this.refreshQuoteApprovalDashboard(quoteId);
                this.showToast('Error', error.body?.message || 'An error occurred while submitting quote approvals', 'error');
            });
    }

    /**
     * Validates that the final approver (in any updated combined approval)
     * has entered comments when they change status to Approved/Rejected.
     * Returns an error message string if invalid, null if valid.
     */
    validateCombinedFinalApproverComments(quoteId) {
        const approvalConfigs = [
            {
                approval: this.warrantyApprovalsMap.get(quoteId),
                statusSuffix: 'WarrantyStatus',
                commentsSuffix: 'WarrantyComments',
                label: 'Warranty Terms'
            },
            {
                approval: this.totalValueApprovalsMap.get(quoteId),
                statusSuffix: 'ValueStatus',
                commentsSuffix: 'ValueComments',
                label: 'Total Value'
            },
            // {
            //     approval: this.minimumOfferApprovalsMap.get(quoteId),
            //     statusSuffix: 'MinOfferStatus',
            //     commentsSuffix: 'MinOfferComments',
            //     label: 'Min Offer Value'
            // },
            {
                approval: this.validityOfferApprovalsMap.get(quoteId),
                statusSuffix: 'ValidityOfferStatus',
                commentsSuffix: 'ValidityOfferComments',
                label: 'Validity Offer'
            }
        ];

        const levels = ['sm', 'ch', 'gs', 'bm', 'md'];
        for (const cfg of approvalConfigs) {
            const data = cfg.approval;
            if (!data || !data.updated) continue;

            for (const level of levels) {
                const isCurrentUser = !!data[`is${this.capitalize(level)}CurrentUser`];
                if (!isCurrentUser) continue;

                const isFinal = this.isFinalApproverLevel(data, level);
                if (!isFinal) continue;

                const status = data[`${level}${cfg.statusSuffix}`];
                const comments = data[`${level}${cfg.commentsSuffix}`];

                if ((status === 'Approved' || status === 'Rejected') && !this.hasValue(comments)) {
                    return `${cfg.label}: Final approver must enter comments before ${status === 'Rejected' ? 'rejecting' : 'approving'}.`;
                }
            }
        }
        return null;
    }

    validateCombinedApprovalInputs(quoteId) {
        // When Skip SOA is ON, use sequential validation
        if (this.skipSoaRestrictions) {
            return this.validateCombinedApprovalSequential(quoteId);
        }

        const approvalConfigs = [
            {
                approval: this.warrantyApprovalsMap.get(quoteId),
                statusSuffix: 'WarrantyStatus',
                commentsSuffix: 'WarrantyComments',
                label: 'Warranty Terms'
            },
            {
                approval: this.totalValueApprovalsMap.get(quoteId),
                statusSuffix: 'ValueStatus',
                commentsSuffix: 'ValueComments',
                label: 'Total Value'
            },
            // {
            //     approval: this.minimumOfferApprovalsMap.get(quoteId),
            //     statusSuffix: 'MinOfferStatus',
            //     commentsSuffix: 'MinOfferComments',
            //     label: 'Min Offer Value'
            // },
            {
                approval: this.validityOfferApprovalsMap.get(quoteId),
                statusSuffix: 'ValidityOfferStatus',
                commentsSuffix: 'ValidityOfferComments',
                label: 'Validity Offer'
            }
        ];

        const levels = ['sm', 'ch', 'gs', 'bm', 'md'];
        for (const cfg of approvalConfigs) {
            const data = cfg.approval;
            if (!data) continue;
            if (!levels.some(level => this.hasValue(data[`${level}${cfg.statusSuffix}`]))) continue;

            for (const level of levels) {
                const canEditStatus = !!data[`can${this.capitalize(level)}EditStatus`];
                const canEditComments = !!data[`can${this.capitalize(level)}EditComments`];
                if (!canEditStatus && !canEditComments) continue;

                const status = data[`${level}${cfg.statusSuffix}`];
                const comments = data[`${level}${cfg.commentsSuffix}`];

                if (canEditStatus && status !== 'Approved' && status !== 'Rejected') {
                    return `${cfg.label}: Select Approved or Rejected for every visible status.`;
                }
                if (canEditComments && !this.hasValue(comments)) {
                    return `${cfg.label}: Enter comments for every visible comments field.`;
                }
            }
        }
        return null;
    }

    /**
     * Sequential validation for the 1st table (combined approvals) when Skip SOA is ON.
     * Rule: comments must be filled bottom-up (no gaps). If level N has content,
     * all Skip-SOA-editable levels M < N must also have comments.
     * If a level has status set to Approved/Rejected, its comments must also be provided.
     */
    validateCombinedApprovalSequential(quoteId) {
        const approvalConfigs = [
            { approval: this.warrantyApprovalsMap.get(quoteId),      statusSuffix: 'WarrantyStatus',      commentsSuffix: 'WarrantyComments',      label: 'Warranty Terms'   },
            { approval: this.totalValueApprovalsMap.get(quoteId),    statusSuffix: 'ValueStatus',          commentsSuffix: 'ValueComments',          label: 'Total Value'      },
            // { approval: this.minimumOfferApprovalsMap.get(quoteId),  statusSuffix: 'MinOfferStatus',       commentsSuffix: 'MinOfferComments',       label: 'Min Offer Value'  },
            { approval: this.validityOfferApprovalsMap.get(quoteId), statusSuffix: 'ValidityOfferStatus',  commentsSuffix: 'ValidityOfferComments',  label: 'Validity Offer'   }
        ];
        const levels = ['sm', 'ch', 'gs', 'bm', 'md'];

        for (const cfg of approvalConfigs) {
            const data = cfg.approval;
            if (!data || !data.updated) continue;

            const finalPos       = data.finalApproverHierarchyPosition;
            const currentUserPos = data.currentUserHierarchyPosition;
            const isHigherHierarchyWithSkip = !!data.isHigherHierarchy;
            // Skip SOA applies when we can determine the user's position, or when higher hierarchy flag is set
            const hasSkipSoaRole = isHigherHierarchyWithSkip ||
                (currentUserPos != null && finalPos != null);
            if (!hasSkipSoaRole) continue;

            // Build the chain of editable levels under new Skip SOA rules, ordered ascending:
            // Case 3 (higher): only the final approver's level
            // Case 1 (= final) and Case 2 (lower): only the current user's own level
            const chain = [];
            for (const level of levels) {
                const levelIndex = this.getApprovalLevelIndex(level);
                if (!levelIndex) continue;

                const originalStatusKey  = `original${this.capitalize(level)}${cfg.statusSuffix}`;
                const originalStatus     = data[originalStatusKey] || '';
                const isAlreadyDecided   = originalStatus === 'Approved' || originalStatus === 'Rejected';
                const isCurrentUserLevel = !!data[`is${this.capitalize(level)}CurrentUser`];
                const isFinalLevel       = this.isFinalApproverLevel(data, level);

                // Case 3: Higher hierarchy → only the final approver's level is editable
                const isHigherFinalEditable = isHigherHierarchyWithSkip &&
                    !isCurrentUserLevel && isFinalLevel && !isAlreadyDecided;

                // Case 1 & 2: current user's own level is editable (not for Case 3 higher hierarchy)
                const isOwnEditable = isCurrentUserLevel && !isHigherHierarchyWithSkip &&
                    (!!data[`can${this.capitalize(level)}EditStatus`] || this.skipSoaRestrictions) &&
                    !isAlreadyDecided;

                if (!isHigherFinalEditable && !isOwnEditable) continue;

                const comments = data[`${level}${cfg.commentsSuffix}`] || '';
                const status   = data[`${level}${cfg.statusSuffix}`]   || '';

                chain.push({
                    levelIndex,
                    label:       level.toUpperCase(),
                    hasComments: this.hasValue(comments),
                    hasStatus:   status === 'Approved' || status === 'Rejected',
                    comments,
                    status
                });
            }

            if (chain.length === 0) continue;

            // Rule 1: if status is set for any level, comments at that level must be provided
            for (const entry of chain) {
                if (entry.hasStatus && !entry.hasComments) {
                    return `${cfg.label}: Enter ${entry.label} comments before approving or rejecting that row.`;
                }
            }

            // Rule 2: sequential — find highest level with any content
            let maxContentIndex = 0;
            for (const entry of chain) {
                const hasContent = entry.hasComments || entry.hasStatus;
                if (hasContent && entry.levelIndex > maxContentIndex) {
                    maxContentIndex = entry.levelIndex;
                }
            }

            if (maxContentIndex === 0) continue; // nothing changed for this approval type

            // All levels below maxContentIndex must have comments
            for (const entry of chain) {
                if (entry.levelIndex >= maxContentIndex) continue;
                if (!entry.hasComments) {
                    return `${cfg.label}: Enter ${entry.label} comments before adding comments or status for higher hierarchy levels.`;
                }
            }
        }
        return null;
    }

    /**
     * Sequential validation for the 2nd table (discount line items) when Skip SOA is ON.
     * Rule: comments must be filled bottom-up (no gaps). If level N has content,
     * all Skip-SOA-editable levels M < N must also have comments.
     */
    validateDiscountApprovalSequential(quote) {
        if (!quote) return true;

        for (const item of quote.quoteLineItems || []) {
            if (!item.skipSoaRestrictions) continue;

            const soaLevels      = this.getSoaLevels(item);
            const currentUserIdx = this.getCurrentUserHierarchyIndex(item);
            const finalLevel_    = soaLevels.find(s => s.approverId === item.finalDiscountApproverId);
            const finalIdx_      = finalLevel_ ? finalLevel_.hierarchyIndex : null;
            const isHigherThanFinal_ = currentUserIdx != null && finalIdx_ != null &&
                currentUserIdx > finalIdx_;
            const chain = [];

            for (const soa of soaLevels) {
                const soaOrigStatus = soa.originalStatus || soa.status || '';

                // Case 1: current user IS the final approver → their own row
                const isOwnFinalRow = item.isFinalDiscountApprover && !!soa.isCurrentUserRow;

                // Case 2: current user LOWER than final → their own row (comments)
                const isOwnSkipRow = !item.isFinalDiscountApprover && !!soa.isCurrentUserRow &&
                    !isHigherThanFinal_ &&
                    soaOrigStatus !== 'Approved' && soaOrigStatus !== 'Rejected';

                // Case 3: current user HIGHER than final → only the final approver's row
                const isHigherFinalRow = isHigherThanFinal_ &&
                    !soa.isCurrentUserRow &&
                    soa.approverId === item.finalDiscountApproverId &&
                    soaOrigStatus !== 'Approved' && soaOrigStatus !== 'Rejected';

                if (!isOwnFinalRow && !isOwnSkipRow && !isHigherFinalRow) continue;

                const comments = soa.commentsValue || '';
                const status   = soa.status        || '';

                chain.push({
                    hierarchyIndex: soa.hierarchyIndex,
                    label:          soa.label,
                    hasComments:    this.hasValue(comments),
                    hasStatus:      status === 'Approved' || status === 'Rejected',
                    comments,
                    status
                });
            }

            if (chain.length === 0) continue;

            // Rule 1: if status set for any level, comments at that level are required
            for (const entry of chain) {
                if (entry.hasStatus && !entry.hasComments) {
                    this.showToast('Error',
                        `Enter ${entry.label} comments before approving or rejecting that discount row.`, 'error');
                    return false;
                }
            }

            // Rule 2: find highest level with any content
            let maxContentIndex = 0;
            for (const entry of chain) {
                const hasContent = entry.hasComments || entry.hasStatus;
                if (hasContent && entry.hierarchyIndex > maxContentIndex) {
                    maxContentIndex = entry.hierarchyIndex;
                }
            }

            if (maxContentIndex === 0) continue;

            // All levels below maxContentIndex must have comments
            for (const entry of chain) {
                if (entry.hierarchyIndex >= maxContentIndex) continue;
                if (!entry.hasComments) {
                    this.showToast('Error',
                        `Enter ${entry.label} comments before adding comments or status for higher hierarchy levels.`, 'error');
                    return false;
                }
            }
        }

        return true;
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
    // handleMinimumOfferStatusChange(event) {
    //     const { quoteId, field, value } = event.detail;
    //     const minimumOffer = this.minimumOfferApprovalsMap.get(quoteId);

    //     if (minimumOffer) {
    //         minimumOffer[`${field}MinOfferStatus`] = value;
    //         minimumOffer.updated = true;
    //         this.minimumOfferApprovalsMap = new Map(this.minimumOfferApprovalsMap);

    //         this.quotes = this.quotes.map(q => {
    //             if (q.quoteId === quoteId) {
    //                 return { ...q, minimumOfferApproval: { ...minimumOffer } };
    //             }
    //             return q;
    //         });
    //     }
    // }

    // handleMinimumOfferCommentChange(event) {
    //     const { quoteId, field, value } = event.detail;
    //     const minimumOffer = this.minimumOfferApprovalsMap.get(quoteId);

    //     if (minimumOffer) {
    //         minimumOffer[`${field}MinOfferComments`] = value;
    //         minimumOffer.updated = true;
    //         this.minimumOfferApprovalsMap = new Map(this.minimumOfferApprovalsMap);

    //         this.quotes = this.quotes.map(q => {
    //             if (q.quoteId === quoteId) {
    //                 return { ...q, minimumOfferApproval: { ...minimumOffer } };
    //             }
    //             return q;
    //         });
    //     }
    // }

    // handleMinimumOfferSubmit(event) {
    //     const { minimumOfferData } = event.detail;

    //     if (!minimumOfferData || !minimumOfferData.updated) {
    //         this.showToast('Warning', 'No changes to submit for minimum offer approval', 'warning');
    //         return;
    //     }

    //     this.isSaveDisabled = true;
    //     submitMinimumOfferApprovalSingle({ minimumOfferApprovalJson: JSON.stringify(minimumOfferData) })
    //         .then(result => {
    //             if (result === 'Success') {
    //                 this.showToast('Success', 'Minimum offer approval submitted successfully', 'success');
    //                 setTimeout(() => { window.location.reload(); }, 1500);
    //             } else {
    //                 this.showToast('Info', result, 'info');
    //                 this.isSaveDisabled = false;
    //             }
    //         })
    //         .catch(error => {
    //             this.isSaveDisabled = false;
    //             this.showToast('Error', error.body?.message || 'An error occurred while submitting minimum offer approval', 'error');
    //         });
    // }

    /** Returns a CSS class string for the status badge. */
    getStatusBadgeClass(status) {
        const base = 'status-badge';
        if (!status) return `${base} status-badge--default`;
        const n = status.toLowerCase();
        if (n === 'approved')   return `${base} status-badge--approved`;
        if (n === 'rejected')   return `${base} status-badge--rejected`;
        if (n === 'submitted')  return `${base} status-badge--submitted`;
        if (n === 'pending')    return `${base} status-badge--submitted`;
        if (n === 'commented')  return `${base} status-badge--commented`;  // ← add this
        return `${base} status-badge--default`;
    }

    buildDisplayRows(lineItems) {
        const displayRows = [];
        (lineItems || []).forEach(item => {
            const allSoaLevels = this.getSoaLevels(item);

            // Hide rows whose hierarchy is above the final approver
            const finalLevel = allSoaLevels.find(soa => soa.approverId === item.finalDiscountApproverId);
            const maxHierarchyIndex = finalLevel ? finalLevel.hierarchyIndex : null;
            const soaLevels = maxHierarchyIndex
                ? allSoaLevels.filter(soa => soa.hierarchyIndex <= maxHierarchyIndex)
                : allSoaLevels;

            // Lock all rows once the final approver has approved or rejected
            const isFinalApproverDecided = !!(finalLevel &&
                (finalLevel.originalStatus === 'Approved' || finalLevel.originalStatus === 'Rejected'));

            soaLevels.forEach((soa, idx) => {
                const formattedDateTime = soa.dateTime
                    ? new Date(soa.dateTime).toLocaleString('en-GB', {
                        day: '2-digit', month: '2-digit', year: 'numeric',
                        hour: '2-digit', minute: '2-digit'
                      })
                    : '';
                // Use the persisted (original) status for all "already decided" guards so that
                // the final approver can still change their status/comment in-session via Skip SOA
                // (soa.status changes in-memory as they type, originalStatus does not).
                const soaOriginalStatus = soa.originalStatus ?? '';

                // ── Skip SOA (New Behavior) ──────────────────────────────────────────
                // Case 1: current user = final approver  → own row only (status + comments)
                // Case 2: current user LOWER than final  → own comments only
                // Case 3: current user HIGHER than final → only final approver's row (status + comments)
                const currentUserIdx_    = this.getCurrentUserHierarchyIndex(item);
                const isFinalApproverRow = soa.approverId === item.finalDiscountApproverId;
                const isHigherThanFinal_ = currentUserIdx_ != null && maxHierarchyIndex != null &&
                    currentUserIdx_ > maxHierarchyIndex;

                // Case 3: Higher hierarchy → only the final approver's row enabled
                const skipSoaHigherHierarchyFinalRow = this.skipSoaRestrictions &&
                    isHigherThanFinal_ && !soa.isCurrentUserRow && isFinalApproverRow &&
                    soaOriginalStatus !== 'Approved' && soaOriginalStatus !== 'Rejected';

                // Case 1: Current user IS the final approver → own row (status + comments)
                const isFinalApproverOwnRowWithSkip =
                    this.skipSoaRestrictions &&
                    item.isFinalDiscountApprover &&
                    soa.isCurrentUserRow &&
                    soaOriginalStatus !== 'Approved' && soaOriginalStatus !== 'Rejected';

                // Case 2: Current user LOWER than final → own comments enabled
                // NOT for Case 3 (higher hierarchy) — higher-hierarchy users only edit the final's row
                const isOwnRowWithSkipSoa = this.skipSoaRestrictions && soa.isCurrentUserRow &&
                    soaOriginalStatus !== 'Approved' && soaOriginalStatus !== 'Rejected' &&
                    !isHigherThanFinal_;
                // ────────────────────────────────────────────────────────────────────

                const showStatusCombobox = !isFinalApproverDecided && (
                    (item.isFinalDiscountApprover && soa.isCurrentUserRow && item.isEditable)
                    || isFinalApproverOwnRowWithSkip
                    || skipSoaHigherHierarchyFinalRow);

                const showCommentInput = !isFinalApproverDecided && (
                    (soa.isCurrentUserRow && item.isEditable)
                    || isFinalApproverOwnRowWithSkip
                    || isOwnRowWithSkipSoa
                    || skipSoaHigherHierarchyFinalRow);
                const actualStatus = soa.status || '';

                const soaStatus = this.getDisplayStatus(
                    actualStatus,
                    soa.approverId === item.finalDiscountApproverId
                );

                displayRows.push({
                    key:              `${item.quoteLineItemId}_${idx}`,
                    isFirstRow:       idx === 0,
                    soaCount:         soaLevels.length,
                    productName:      item.productName,
                    productCode:      item.productCode,
                    listPrice:        item.listPrice,
                    quantity:         item.quantity,
                    d1:               item.d1,
                    previousDiscount: item.previousDiscount,
                    d2:               item.d2,
                    quoteLineItemId:  item.quoteLineItemId,
                    parentId:         item.parentId,
                    approvalStatus: isFinalApproverOwnRowWithSkip ? soa.status : item.approvalStatus,
                    soaStatusField:   soa.statusField,
                    soaDisplay:       soa.name ? `${soa.label} - ${soa.name}` : '',
                    soaApproverId:    soa.approverId,
                    soaApproverName:  soa.name || '',
                    soaStatus,
                    statusBadgeClass: this.getStatusBadgeClass(soaStatus),
                    soaDateTime:      formattedDateTime,
                    prevSoaComments:  soa.previousCommentsValue || '',
                    soaComments:      soa.commentsValue || '',
                    soaCommentsField: soa.commentsField,
                    requestedComments: item.requestedComments || '',
                    showDiscountInput: idx === 0 && !isFinalApproverDecided && (
                        (item.isFinalDiscountApprover && item.isEditable) ||
                        (this.skipSoaRestrictions &&
                            maxHierarchyIndex != null &&
                            this.getCurrentUserHierarchyIndex(item) != null &&
                            this.getCurrentUserHierarchyIndex(item) > maxHierarchyIndex &&
                            finalLevel != null &&
                            (finalLevel.originalStatus || finalLevel.status || '') !== 'Approved' &&
                            (finalLevel.originalStatus || finalLevel.status || '') !== 'Rejected') ||
                            ((this.skipSoaRestrictions && item.isFinalDiscountApprover)
                            && finalLevel != null &&
                            (finalLevel.originalStatus || finalLevel.status || '') !== 'Approved' &&
                            (finalLevel.originalStatus || finalLevel.status || '') !== 'Rejected')

                    ),
                    showStatusCombobox,
                    showStatusText:   !showStatusCombobox,
                    showCommentInput,
                    soaCommentsDisabled: !(soa.isCurrentUserRow && item.isEditable) && !isFinalApproverOwnRowWithSkip && !isOwnRowWithSkipSoa && !skipSoaHigherHierarchyFinalRow,
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
                status: item.salesManagerStatus,
                originalStatus: item.origSalesManagerStatus,
                statusField: 'Sales_Manager_Status__c',
                dateTime: item.salesManagerDateTime, commentsField: 'Sales_Manager_Comments',
                commentsValue: item.Sales_Manager_Comments,
                previousCommentsValue: item.prevSalesManagerComments,
                isCurrentUserRow: !item.bcheck1, hierarchyIndex: 1
            },
            {
                label: 'CH', name: item.countryContinentSalesName, approverId: item.countryContinentSalesId,
                status: item.countryContinentSalesStatus,
                originalStatus: item.origCountryContinentSalesStatus,
                statusField: 'Country_Continent_Sales_H_LOB_Status__c',
                dateTime: item.countryHeadDateTime, commentsField: 'Country_Continent_Sales_LOB_Comments',
                commentsValue: item.Country_Continent_Sales_LOB_Comments,
                previousCommentsValue: item.prevCountryContinentSalesComments,
                isCurrentUserRow: !item.bcheck2, hierarchyIndex: 2
            },
            {
                label: 'GS', name: item.globalSalesHeadName, approverId: item.globalSalesHeadId,
                status: item.globalSalesHeadStatus,
                originalStatus: item.origGlobalSalesHeadStatus,
                statusField: 'Global_Sales_Head_Status__c',
                dateTime: item.globalSalesHeadDateTime, commentsField: 'Global_Sales_Head_Comments',
                commentsValue: item.Global_Sales_Head_Comments,
                previousCommentsValue: item.prevGlobalSalesHeadComments,
                isCurrentUserRow: !item.bcheck5, hierarchyIndex: 3
            },
            {
                label: 'BM', name: item.rotexBoardMemberName, approverId: item.rotexBoardMemberId,
                status: item.rotexBoardMemberStatus,
                originalStatus: item.origRotexBoardMemberStatus,
                statusField: 'Rotex_Board_Member_Status__c',
                dateTime: item.rotexBoardMemberDateTime, commentsField: 'Rotex_Board_Member_Comments',
                commentsValue: item.Rotex_Board_Member_Comments,
                previousCommentsValue: item.prevRotexBoardMemberComments,
                isCurrentUserRow: !item.bcheck3, hierarchyIndex: 4
            },
            {
                label: 'MD', name: item.managingDirectorName, approverId: item.managingDirectorId,
                status: item.managingDirectorStatus,
                originalStatus: item.origManagingDirectorStatus,
                statusField: 'Managing_Director_Status__c',
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
                    },
                    skipEditableStatusFields: {
                        ...(item.skipEditableStatusFields || {}),
                        ...this.getSkipEditableStatusFields(item)
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
                    const skipStatusFields = item.skipEditableStatusFields || {};
                    Object.keys(skipStatusFields).forEach(f => { if (skipStatusFields[f] === true) delete clearedItem[f]; });
                    this.getSoaLevels(item).forEach(soa => {
                        if (this.isFinalPreviousHierarchyRow(item, soa)) clearedItem.approvalStatus = null;
                    });
                    return { ...clearedItem, skipSoaRestrictions: false, skipEditableCommentFields: {}, skipEditableStatusFields: {} };
                });
                return { ...quote, quoteLineItems, displayRows: this.buildDisplayRows(quoteLineItems) };
            });
        }
        // Refresh 1st-table approval dashboards to show/hide Skip SOA fields
        this.refreshExpandedApprovalDashboards();
    }

    getSkipEditableCommentFields(item) {
        const editable = {};
        const allSoaLevels   = this.getSoaLevels(item);
        const currentUserIdx = this.getCurrentUserHierarchyIndex(item);
        const finalLevel     = allSoaLevels.find(soa => soa.approverId === item.finalDiscountApproverId);
        const finalIdx       = finalLevel ? finalLevel.hierarchyIndex : null;

        if (!currentUserIdx || !finalIdx) return editable;

        const isHigherThanFinal = currentUserIdx > finalIdx;

        if (isHigherThanFinal) {
            // Case 3: Higher hierarchy → only final approver's comment field is Skip-SOA-editable
            const origStatus = finalLevel.originalStatus || finalLevel.status || '';
            if (origStatus !== 'Approved' && origStatus !== 'Rejected') {
                editable[finalLevel.commentsField] = true;
            }
        }
        // Case 1 (= final) and Case 2 (lower): own comment field handled via getCurrentUserComment()
        return editable;
    }

    getSkipEditableStatusFields(item) {
        const editable = {};
        this.getSoaLevels(item).forEach(soa => {
            const origStatus = soa.originalStatus || soa.status || '';
            if (this.isFinalPreviousHierarchyRow(item, soa) &&
                origStatus !== 'Approved' && origStatus !== 'Rejected') {
                editable[soa.statusField] = true;
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
        specificQuote.isUnifiedSubmitDisabled = !this.hasDiscountChanges(specificQuote) && !this.hasCombinedApprovalChanges(specificQuote);
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

    hasDiscountChanges(quote) {
        if (!quote || !quote.quoteLineItems) return false;
        return quote.quoteLineItems.some(item => item.updated === true);
    }

    hasCombinedApprovalChanges(quote) {
        if (!quote) return false;
        const warrantyApproval = this.warrantyApprovalsMap.get(quote.quoteId);
        const validityOfferApproval = this.validityOfferApprovalsMap.get(quote.quoteId);
        const totalValueApproval = this.totalValueApprovalsMap.get(quote.quoteId);
        // const minimumOfferApproval = this.minimumOfferApprovalsMap.get(quote.quoteId);

        return !!(warrantyApproval?.updated) ||
               !!(validityOfferApproval?.updated) ||
               !!(totalValueApproval?.updated)
            //    !!(minimumOfferApproval?.updated);
    }

    getCurrentUserCommentValue(item) {
        if (item.bcheck1 === false) return item.Sales_Manager_Comments;
        if (item.bcheck2 === false) return item.Country_Continent_Sales_LOB_Comments;
        if (item.bcheck5 === false) return item.Global_Sales_Head_Comments;
        if (item.bcheck3 === false) return item.Rotex_Board_Member_Comments;
        if (item.bcheck4 === false) return item.Managing_Director_Comments;
        return null;
    }

    validateDiscountApprovalInputs(quote) {
        if (!quote) return true;

        for (const row of quote.displayRows || []) {
            // When Skip SOA is ON, status + comment validations are handled by the sequential check
            if (!this.skipSoaRestrictions) {
                if (row.showStatusCombobox && row.approvalStatus !== 'Approved' && row.approvalStatus !== 'Rejected') {
                    this.showToast('Error', 'Select Approved or Rejected for every visible discount status', 'error');
                    return false;
                }
                if (row.showCommentInput && !row.soaCommentsDisabled && !this.hasValue(row.soaComments)) {
                    this.showToast('Error', 'Enter comments for every visible discount comments field', 'error');
                    return false;
                }
            }
            if (row.showDiscountInput) {
                const offeredDiscount = Number(row.d2);
                const sapDiscount = Number(row.d1);
                if (!Number.isNaN(offeredDiscount) && !Number.isNaN(sapDiscount) && offeredDiscount < sapDiscount) {
                    this.showToast('Error', 'Final approver cannot enter a discount less than Disc.SAP%', 'error');
                    return false;
                }
            }
        }

        return true;
    }

    validateFinalApproverRequirements(quote) {
        if (!quote || !quote.quoteLineItems) return true;
        // When Skip SOA is ON, sequential validation covers everything
        if (this.skipSoaRestrictions) return true;

        for (const item of quote.quoteLineItems) {
            if (!item.updated || !item.isFinalDiscountApprover) continue;

            const hasFinalStatus = item.approvalStatus === 'Approved' || item.approvalStatus === 'Rejected';
            const currentComment = this.getCurrentUserCommentValue(item);
            const hasComments = this.hasValue(currentComment);
            const offeredDiscount = Number(item.d2);
            const sapDiscount = Number(item.d1);

            if (!hasFinalStatus) {
                this.showToast('Error', 'Final approver must select Approved or Rejected for every discount status', 'error');
                return false;
            }

            if (!hasComments) {
                this.showToast('Error', 'Final approver must enter comments for every discount row', 'error');
                return false;
            }

            if (!Number.isNaN(offeredDiscount) && !Number.isNaN(sapDiscount) && offeredDiscount < sapDiscount) {
                this.showToast('Error', 'Final approver cannot enter a discount less than Disc.SAP%', 'error');
                return false;
            }
        }

        return true;
    }

    handleUnifiedQuoteSubmit(event) {
        const quoteId = event.currentTarget.dataset.quoteId;
        const quote = this.quotes.find(q => q.quoteId === quoteId);

        if (!quote) {
            this.showToast('Error', 'Quote not found', 'error');
            return;
        }

        const hasDiscountChanges = this.hasDiscountChanges(quote);
        const hasCombinedChanges = this.hasCombinedApprovalChanges(quote);

        if (!this.validateDiscountApprovalInputs(quote)) {
            return;
        }

        const combinedInputError = this.validateCombinedApprovalInputs(quoteId);
        if (combinedInputError) {
            this.showToast('Error', combinedInputError, 'error');
            return;
        }

        if (!hasDiscountChanges && !hasCombinedChanges) {
            this.showToast('Warning', 'No changes to submit', 'warning');
            return;
        }

        // Validate final approver requirements for discount approvals (non-Skip-SOA path)
        if (hasDiscountChanges && !this.validateFinalApproverRequirements(quote)) {
            return;
        }

        // Skip SOA sequential validation for discount approvals
        if (hasDiscountChanges && this.skipSoaRestrictions && !this.validateDiscountApprovalSequential(quote)) {
            return;
        }

        // Validate final approver comments for combined (top table) approvals
        if (hasCombinedChanges) {
            const combinedValidationError = this.validateCombinedFinalApproverComments(quoteId);
            if (combinedValidationError) {
                this.showToast('Error', combinedValidationError, 'error');
                return;
            }
        }

        this.isSaveDisabled = true;
        this.quotes = this.quotes.map(q => {
            if (q.quoteId === quoteId) {
                return { ...q, isUnifiedSubmitDisabled: true };
            }
            return q;
        });

        const warrantyApproval = this.warrantyApprovalsMap.get(quoteId);
        const totalValueApproval = this.totalValueApprovalsMap.get(quoteId);
        // const minimumOfferApproval = this.minimumOfferApprovalsMap.get(quoteId);
        const validityOfferApproval = this.validityOfferApprovalsMap.get(quoteId);

        const skipSoa = this.skipSoaRestrictions;
        submitUnifiedQuoteApprovals({
            quotationListStringObject: hasDiscountChanges ? JSON.stringify([quote]) : null,
            warrantyApprovalJson:      warrantyApproval?.updated      ? JSON.stringify({ ...warrantyApproval,      skipSoaRestrictions: skipSoa }) : null,
            validityOfferApprovalJson: validityOfferApproval?.updated ? JSON.stringify({ ...validityOfferApproval, skipSoaRestrictions: skipSoa }) : null,
            totalValueApprovalJson:    totalValueApproval?.updated    ? JSON.stringify({ ...totalValueApproval,    skipSoaRestrictions: skipSoa }) : null
            // minimumOfferApprovalJson:  minimumOfferApproval?.updated  ? JSON.stringify({ ...minimumOfferApproval,  skipSoaRestrictions: skipSoa }) : null
        })
            .then(result => {
                if (result !== 'Success') {
                    throw new Error(result || 'Submission failed');
                }
                this.showToast('Success', 'All approvals submitted successfully', 'success');
                this.isSaveDisabled = false;
                this.fetchQuotes([quoteId]);
            })
            .catch(error => {
                this.isSaveDisabled = false;
                this.quotes = this.quotes.map(q => {
                    if (q.quoteId === quoteId) {
                        return { ...q, isUnifiedSubmitDisabled: false };
                    }
                    return q;
                });
                this.showToast('Error', error.body?.message || error.message || 'An error occurred during submission', 'error');
            });
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

    handleAddTaskClick(event) {
        event.preventDefault();
        this.taskModalApproverId   = event.currentTarget.dataset.approverId;
        this.taskModalApproverName = event.currentTarget.dataset.approverName;
        this.taskModalQuoteId      = event.currentTarget.dataset.quoteId;
        this.showTaskModal = true;
    }

    handleTaskModalClose() {
        this.showTaskModal         = false;
        this.taskModalApproverId   = null;
        this.taskModalApproverName = null;
        this.taskModalQuoteId      = null;
    }

    handleTaskCreated() {
        this.showToast('Success', 'Task created successfully for approver', 'success');
        this.handleTaskModalClose();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    showToast(title, msg, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant }));
    }
}