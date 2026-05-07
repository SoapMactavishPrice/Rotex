import { LightningElement, api, track } from 'lwc';

export default class QuoteWarrantyApproval extends LightningElement {
    @api quoteId;
    @api warrantyData;
    @api skipSoaRestrictions = false;

    @track statusOptions = [
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' }
    ];

    get hasWarrantyData() {
        return this.warrantyData != null;
    }

    get isSubmitDisabled() {
        return false;
    }

    get isReadOnlyView() {
        if (!this.warrantyData) return false;
        // Read-only if higher hierarchy and Skip SOA is OFF
        return this.warrantyData.isHigherHierarchy && !this.skipSoaRestrictions;
    }

    get approverRows() {
        if (!this.warrantyData) return [];
        const d = this.warrantyData;
        const isHigherSkip         = d.isHigherHierarchy && this.skipSoaRestrictions;
        const isFinalApproverSkip  = d.isFinalApproverWithPendingLower && this.skipSoaRestrictions;
        const finalPos             = d.finalApproverHierarchyPosition;

        const levels = [
            { key: 'sm', label: 'SM', nameKey: 'smName', statusKey: 'smWarrantyStatus', dtKey: 'smWarrantyDateTime', commentsKey: 'smWarrantyComments', canEditStatusKey: 'canSmEditStatus', canEditCommentsKey: 'canSmEditComments', pos: 1 },
            { key: 'ch', label: 'CH', nameKey: 'chName', statusKey: 'chWarrantyStatus', dtKey: 'chWarrantyDateTime', commentsKey: 'chWarrantyComments', canEditStatusKey: 'canChEditStatus', canEditCommentsKey: 'canChEditComments', pos: 2 },
            { key: 'gs', label: 'GS', nameKey: 'gsName', statusKey: 'gsWarrantyStatus', dtKey: 'gsWarrantyDateTime', commentsKey: 'gsWarrantyComments', canEditStatusKey: 'canGsEditStatus', canEditCommentsKey: 'canGsEditComments', pos: 3 },
            { key: 'bm', label: 'BM', nameKey: 'bmName', statusKey: 'bmWarrantyStatus', dtKey: 'bmWarrantyDateTime', commentsKey: 'bmWarrantyComments', canEditStatusKey: 'canBmEditStatus', canEditCommentsKey: 'canBmEditComments', pos: 4 },
            { key: 'md', label: 'MD', nameKey: 'mdName', statusKey: 'mdWarrantyStatus', dtKey: 'mdWarrantyDateTime', commentsKey: 'mdWarrantyComments', canEditStatusKey: 'canMdEditStatus', canEditCommentsKey: 'canMdEditComments', pos: 5 }
        ];

        return levels
            .filter(l => d[l.nameKey])
            .map(l => {
                const status = d[l.statusKey] || '';
                let showStatusCombobox = false;
                let showCommentInput   = false;

                if (isHigherSkip) {
                    // Higher hierarchy with Skip SOA: rows below final get comment, final row gets status+comment
                    if (l.pos === finalPos)    { showStatusCombobox = true; showCommentInput = true; }
                    else if (l.pos < finalPos) { showCommentInput = true; }

                } else if (isFinalApproverSkip) {
                    // Final approver with Skip SOA: rows below final get comment, own row gets status+comment
                    if (l.pos === finalPos)    { showStatusCombobox = true; showCommentInput = true; }
                    else if (l.pos < finalPos) { showCommentInput = true; }

                } else if (!d.isHigherHierarchy) {
                    // Normal flow — driven by server-computed edit flags
                    showStatusCombobox = !!d[l.canEditStatusKey];
                    showCommentInput   = !!d[l.canEditCommentsKey];
                }
                // isHigherHierarchy && !skipSoaRestrictions → all read-only

                return {
                    key: l.key, label: l.label,
                    name: d[l.nameKey], status,
                    statusBadgeClass: this.getStatusBadgeClass(status),
                    dateTime: this.formatDateTime(d[l.dtKey]),
                    comments: d[l.commentsKey] || '',
                    showStatusCombobox, showCommentInput,
                    field: l.key
                };
            });
    }
    getStatusBadgeClass(status) {
        const base = 'status-badge';
        if (!status) return `${base} status-badge--default`;
        const normalized = status.toLowerCase();
        if (normalized === 'approved') return `${base} status-badge--approved`;
        if (normalized === 'rejected') return `${base} status-badge--rejected`;
        if (normalized === 'submitted') return `${base} status-badge--submitted`;
        return `${base} status-badge--default`;
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

    handleStatusChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail.value;
        
        this.dispatchEvent(new CustomEvent('warrantystatuschange', {
            detail: {
                quoteId: this.quoteId,
                field: field,
                type: 'status',
                value: value
            }
        }));
    }

    handleCommentChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        this.dispatchEvent(new CustomEvent('warrantycommentchange', {
            detail: {
                quoteId: this.quoteId,
                field: field,
                type: 'comments',
                value: value
            }
        }));
    }

    handleSubmitWarranty() {
        this.dispatchEvent(new CustomEvent('warrantysubmit', {
            detail: {
                quoteId: this.quoteId,
                // bake skipSoaRestrictions into the data so Apex can act on it
                warrantyData: { ...this.warrantyData, skipSoaRestrictions: this.skipSoaRestrictions }
            }
        }));
    }

    hasCurrentUserComment(d) {
        if (d.isSmCurrentUser && d.smWarrantyStatus === 'Submitted') return this.hasNonBlank(d.smWarrantyComments);
        if (d.isChCurrentUser && d.chWarrantyStatus === 'Submitted') return this.hasNonBlank(d.chWarrantyComments);
        if (d.isGsCurrentUser && d.gsWarrantyStatus === 'Submitted') return this.hasNonBlank(d.gsWarrantyComments);
        if (d.isBmCurrentUser && d.bmWarrantyStatus === 'Submitted') return this.hasNonBlank(d.bmWarrantyComments);
        if (d.isMdCurrentUser && d.mdWarrantyStatus === 'Submitted') return this.hasNonBlank(d.mdWarrantyComments);
        return false;
    }

    hasFinalApproverComment(d) {
        const map = [null, d.smWarrantyComments, d.chWarrantyComments, d.gsWarrantyComments, d.bmWarrantyComments, d.mdWarrantyComments];
        return this.hasNonBlank(map[d.finalApproverHierarchyPosition]);
    }

    hasNonBlank(v) {
        return v !== undefined && v !== null && String(v).trim() !== '';
    }
}
