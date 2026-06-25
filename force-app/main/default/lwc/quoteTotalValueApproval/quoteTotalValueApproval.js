import { LightningElement, api, track } from 'lwc';

export default class QuoteTotalValueApproval extends LightningElement {
    @api quoteId;
    @api totalValueData;

    @track statusOptions = [
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' }
    ];

    get hasTotalValueData() {
        return this.totalValueData != null;
    }

    get isSubmitDisabled() {
        if (!this.totalValueData) return true;
        return !this.totalValueData.updated;
    }

    get approverRows() {
        if (!this.totalValueData) return [];
        const d = this.totalValueData;

        const levels = [
            { key: 'sm', label: 'SM', nameKey: 'smName', statusKey: 'smValueStatus', dtKey: 'smValueDateTime', commentsKey: 'smValueComments', canEditStatusKey: 'canSmEditStatus', canEditCommentsKey: 'canSmEditComments' },
            { key: 'ch', label: 'CH', nameKey: 'chName', statusKey: 'chValueStatus', dtKey: 'chValueDateTime', commentsKey: 'chValueComments', canEditStatusKey: 'canChEditStatus', canEditCommentsKey: 'canChEditComments' },
            { key: 'gs', label: 'GS', nameKey: 'gsName', statusKey: 'gsValueStatus', dtKey: 'gsValueDateTime', commentsKey: 'gsValueComments', canEditStatusKey: 'canGsEditStatus', canEditCommentsKey: 'canGsEditComments' },
            { key: 'bm', label: 'BM', nameKey: 'bmName', statusKey: 'bmValueStatus', dtKey: 'bmValueDateTime', commentsKey: 'bmValueComments', canEditStatusKey: 'canBmEditStatus', canEditCommentsKey: 'canBmEditComments' },
            { key: 'md', label: 'MD', nameKey: 'mdName', statusKey: 'mdValueStatus', dtKey: 'mdValueDateTime', commentsKey: 'mdValueComments', canEditStatusKey: 'canMdEditStatus', canEditCommentsKey: 'canMdEditComments' }
        ];

        return levels
            .filter(l => d[l.nameKey])
            .map(l => {
                const status = d[l.statusKey] || '';
                return {
                    key: l.key,
                    label: l.label,
                    name: d[l.nameKey],
                    status,
                    statusBadgeClass: this.getStatusBadgeClass(status),
                    dateTime: this.formatDateTime(d[l.dtKey]),
                    comments: d[l.commentsKey] || '',
                    showStatusCombobox: !!d[l.canEditStatusKey],
                    showCommentInput: !!d[l.canEditCommentsKey],
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
        this.dispatchEvent(new CustomEvent('totalvaluestatuschange', {
            detail: {
                quoteId: this.quoteId,
                field: event.target.dataset.field,
                type: 'status',
                value: event.detail.value
            }
        }));
    }

    handleCommentChange(event) {
        this.dispatchEvent(new CustomEvent('totalvaluecommentchange', {
            detail: {
                quoteId: this.quoteId,
                field: event.target.dataset.field,
                type: 'comments',
                value: event.target.value
            }
        }));
    }

    handleSubmitTotalValue() {
        this.dispatchEvent(new CustomEvent('totalvaluesubmit', {
            detail: {
                quoteId: this.quoteId,
                totalValueData: this.totalValueData
            }
        }));
    }
}