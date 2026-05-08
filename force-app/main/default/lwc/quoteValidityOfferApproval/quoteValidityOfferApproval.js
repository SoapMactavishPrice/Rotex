import { LightningElement, api, track } from 'lwc';

export default class QuoteValidityOfferApproval extends LightningElement {
    @api quoteId;
    @api validityData;

    @track statusOptions = [
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' }
    ];

    get hasValidityData() {
        return this.validityData != null;
    }

    get isSubmitDisabled() {
        if (!this.validityData) return true;
        return !this.validityData.updated;
    }

    get approverRows() {
        if (!this.validityData) return [];
        const d = this.validityData;

        const levels = [
            { key: 'sm', label: 'SM', nameKey: 'smName', statusKey: 'smValidityOfferStatus', dtKey: 'smValidityOfferDateTime', commentsKey: 'smValidityOfferComments', canEditStatusKey: 'canSmEditStatus', canEditCommentsKey: 'canSmEditComments' },
            { key: 'ch', label: 'CH', nameKey: 'chName', statusKey: 'chValidityOfferStatus', dtKey: 'chValidityOfferDateTime', commentsKey: 'chValidityOfferComments', canEditStatusKey: 'canChEditStatus', canEditCommentsKey: 'canChEditComments' },
            { key: 'gs', label: 'GS', nameKey: 'gsName', statusKey: 'gsValidityOfferStatus', dtKey: 'gsValidityOfferDateTime', commentsKey: 'gsValidityOfferComments', canEditStatusKey: 'canGsEditStatus', canEditCommentsKey: 'canGsEditComments' },
            { key: 'bm', label: 'BM', nameKey: 'bmName', statusKey: 'bmValidityOfferStatus', dtKey: 'bmValidityOfferDateTime', commentsKey: 'bmValidityOfferComments', canEditStatusKey: 'canBmEditStatus', canEditCommentsKey: 'canBmEditComments' },
            { key: 'md', label: 'MD', nameKey: 'mdName', statusKey: 'mdValidityOfferStatus', dtKey: 'mdValidityOfferDateTime', commentsKey: 'mdValidityOfferComments', canEditStatusKey: 'canMdEditStatus', canEditCommentsKey: 'canMdEditComments' }
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
        
        this.dispatchEvent(new CustomEvent('validityofferstatuschange', {
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
        
        this.dispatchEvent(new CustomEvent('validityoffercommentchange', {
            detail: {
                quoteId: this.quoteId,
                field: field,
                type: 'comments',
                value: value
            }
        }));
    }

    handleSubmitValidityOffer() {
        this.dispatchEvent(new CustomEvent('validityoffersubmit', {
            detail: {
                quoteId: this.quoteId,
                validityData: this.validityData
            }
        }));
    }
}