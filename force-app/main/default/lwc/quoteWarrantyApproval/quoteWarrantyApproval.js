import { LightningElement, api, track } from 'lwc';

export default class QuoteWarrantyApproval extends LightningElement {
    @api quoteId;
    @api warrantyData;

    @track statusOptions = [
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' }
    ];

    get hasWarrantyData() {
        return this.warrantyData != null;
    }

    get isSubmitDisabled() {
        if (!this.warrantyData) return true;
        return !this.warrantyData.updated;
    }

    get approverRows() {
        if (!this.warrantyData) return [];
        const d = this.warrantyData;

        const levels = [
            { key: 'sm', label: 'SM', nameKey: 'smName', statusKey: 'smWarrantyStatus', dtKey: 'smWarrantyDateTime', commentsKey: 'smWarrantyComments', canEditStatusKey: 'canSmEditStatus', canEditCommentsKey: 'canSmEditComments' },
            { key: 'ch', label: 'CH', nameKey: 'chName', statusKey: 'chWarrantyStatus', dtKey: 'chWarrantyDateTime', commentsKey: 'chWarrantyComments', canEditStatusKey: 'canChEditStatus', canEditCommentsKey: 'canChEditComments' },
            { key: 'gs', label: 'GS', nameKey: 'gsName', statusKey: 'gsWarrantyStatus', dtKey: 'gsWarrantyDateTime', commentsKey: 'gsWarrantyComments', canEditStatusKey: 'canGsEditStatus', canEditCommentsKey: 'canGsEditComments' },
            { key: 'bm', label: 'BM', nameKey: 'bmName', statusKey: 'bmWarrantyStatus', dtKey: 'bmWarrantyDateTime', commentsKey: 'bmWarrantyComments', canEditStatusKey: 'canBmEditStatus', canEditCommentsKey: 'canBmEditComments' },
            { key: 'md', label: 'MD', nameKey: 'mdName', statusKey: 'mdWarrantyStatus', dtKey: 'mdWarrantyDateTime', commentsKey: 'mdWarrantyComments', canEditStatusKey: 'canMdEditStatus', canEditCommentsKey: 'canMdEditComments' }
        ];

        return levels
            .filter(l => d[l.nameKey])
            .map(l => {
                const status = d[l.statusKey] || '';
                // Normal flow — driven by server-computed edit flags
                const showStatusCombobox = !!d[l.canEditStatusKey];
                const showCommentInput   = !!d[l.canEditCommentsKey];

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
                warrantyData: this.warrantyData
            }
        }));
    }
}
