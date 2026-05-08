import { LightningElement, api, track } from 'lwc';

export default class QuoteMinimumOfferApproval extends LightningElement {
    @api quoteId;
    @api minimumOfferData;

    @track statusOptions = [
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' }
    ];

    get hasMinimumOfferData() {
        return this.minimumOfferData != null;
    }

    get isSubmitDisabled() {
        if (!this.minimumOfferData) return true;
        return !this.minimumOfferData.updated;
    }

    get approverRows() {
        if (!this.minimumOfferData) return [];
        const d = this.minimumOfferData;

        const levels = [
            { key: 'gs', label: 'GS', nameKey: 'gsName', statusKey: 'gsMinOfferStatus', dtKey: 'gsMinOfferDateTime', commentsKey: 'gsMinOfferComments', canEditStatusKey: 'canGsEditStatus', canEditCommentsKey: 'canGsEditComments' },
            { key: 'bm', label: 'BM', nameKey: 'bmName', statusKey: 'bmMinOfferStatus', dtKey: 'bmMinOfferDateTime', commentsKey: 'bmMinOfferComments', canEditStatusKey: 'canBmEditStatus', canEditCommentsKey: 'canBmEditComments' },
            { key: 'md', label: 'MD', nameKey: 'mdName', statusKey: 'mdMinOfferStatus', dtKey: 'mdMinOfferDateTime', commentsKey: 'mdMinOfferComments', canEditStatusKey: 'canMdEditStatus', canEditCommentsKey: 'canMdEditComments' }
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
        this.dispatchEvent(new CustomEvent('minimumofferstatuschange', {
            detail: {
                quoteId: this.quoteId,
                field: event.target.dataset.field,
                type: 'status',
                value: event.detail.value
            }
        }));
    }

    handleCommentChange(event) {
        this.dispatchEvent(new CustomEvent('minimumoffercommentchange', {
            detail: {
                quoteId: this.quoteId,
                field: event.target.dataset.field,
                type: 'comments',
                value: event.target.value
            }
        }));
    }

    handleSubmitMinimumOffer() {
        this.dispatchEvent(new CustomEvent('minimumoffersubmit', {
            detail: {
                quoteId: this.quoteId,
                minimumOfferData: this.minimumOfferData
            }
        }));
    }
}
