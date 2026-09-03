import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuotePdfContext from '@salesforce/apex/DealerSalesQuotationPDFController.getQuotePdfContext';
import generatePdfPreview from '@salesforce/apex/DealerSalesQuotationPDFController.generatePdfPreview';
import saveQuotePdf from '@salesforce/apex/DealerSalesQuotationPDFController.saveQuotePdf';
import saveAndSendQuotePdf from '@salesforce/apex/DealerSalesQuotationPDFController.saveAndSendQuotePdf';

/**
 * Preview: HTML (unchanged). Save: Apex → Visualforce getContentAsPDF (no browser capture / LWS issues).
 */
export default class DealerQuotePdfModal extends LightningElement {
    @api quoteId;

    @track isLoading = false;
    @track isSaving = false;
    @track isValid = false;
    @track errors = [];
    @track emailId = '';
    @track ccAddresses = '';
    @track subject = '';
    @track body = '';
    @track pdfLoadError = '';
    @track hasPreview = false;
    @track attachedFiles = [];
    @track statusMessage = '';
    @track statusVariant = 'info';

    _previewHtml = '';
    _previewNeedsPaint = false;
    _openedAt = 0;

    connectedCallback() {
        this._openedAt = Date.now();
        this.loadContextAndPdf();
    }

    renderedCallback() {
        if (!this._previewNeedsPaint || !this._previewHtml) {
            return;
        }
        const host = this.template.querySelector('[data-preview-host]');
        if (!host) {
            return;
        }
        try {
            // Nested shadow keeps preview CSS (img.logo / body) from breaking site nav logo.
            let root = host.shadowRoot;
            if (!root) {
                root = host.attachShadow({ mode: 'open' });
            }
            root.innerHTML = this._previewHtml;
        } catch (e) {
            try {
                host.innerHTML = this.scopePreviewCss(this._previewHtml);
            } catch (e2) {
                this.pdfLoadError = 'Preview could not be rendered.';
            }
        }
        this._previewNeedsPaint = false;
    }

    get hasErrors() {
        return Array.isArray(this.errors) && this.errors.length > 0;
    }

    get hasAttachments() {
        return Array.isArray(this.attachedFiles) && this.attachedFiles.length > 0;
    }

    get canSave() {
        return this.isValid && !!this.quoteId && !this.isSaving && !this.isLoading && this.hasPreview;
    }

    get isSaveDisabled() {
        return !this.canSave;
    }

    get saveAndSendDisabled() {
        return !this.canSave || !this.emailId || !this.subject;
    }

    get statusClass() {
        return `status-box status-box-${this.statusVariant || 'info'}`;
    }

    handleClose() {
        if (this.isSaving) {
            return;
        }
        if (this._openedAt && Date.now() - this._openedAt < 400) {
            return;
        }
        this.dispatchEvent(new CustomEvent('close'));
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        if (field === 'emailId') {
            this.emailId = value;
        } else if (field === 'ccAddresses') {
            this.ccAddresses = value;
        } else if (field === 'subject') {
            this.subject = value;
        } else if (field === 'body') {
            this.body = value;
        }
    }

    handleFileChange(event) {
        const files = event.target.files;
        if (!files || files.length === 0) {
            return;
        }
        const readers = [];
        for (let i = 0; i < files.length; i++) {
            const file = files[i];
            readers.push(
                new Promise((resolve, reject) => {
                    const reader = new FileReader();
                    reader.onload = () => {
                        const result = String(reader.result || '');
                        const base64 = result.includes(',') ? result.split(',')[1] : result;
                        resolve({ name: file.name, data: base64 });
                    };
                    reader.onerror = () => reject(reader.error);
                    reader.readAsDataURL(file);
                })
            );
        }
        Promise.all(readers)
            .then((parsed) => {
                this.attachedFiles = [...this.attachedFiles, ...parsed];
            })
            .catch(() => {
                this.setStatus('Could not read one or more files.', 'error');
            });
        event.target.value = '';
    }

    handleRemoveFile(event) {
        const index = Number(event.currentTarget.dataset.index);
        this.attachedFiles = this.attachedFiles.filter((_, i) => i !== index);
    }

    getAttachmentDataJson() {
        if (!this.hasAttachments) {
            return '';
        }
        return JSON.stringify(this.attachedFiles);
    }

    async loadContextAndPdf() {
        this.isLoading = true;
        this.pdfLoadError = '';
        this.statusMessage = '';
        this.hasPreview = false;
        this._previewHtml = '';
        this._previewNeedsPaint = false;
        this.errors = [];
        this.attachedFiles = [];
        try {
            const ctx = await getQuotePdfContext({ quoteId: this.quoteId });
            this.isValid = ctx.isValid === true;
            this.errors = ctx.errors || [];
            this.emailId = ctx.emailId || '';
            this.ccAddresses = ctx.ccAddresses || '';
            this.subject = ctx.subject || '';
            this.body = this.toPlainBody(ctx.body || '');

            if (!this.isValid) {
                return;
            }

            const preview = await generatePdfPreview({ quoteId: this.quoteId });
            const html = preview?.htmlPreview;
            if (!html) {
                this.pdfLoadError = 'PDF preview content was not returned.';
                return;
            }
            this._previewHtml = html;
            this.hasPreview = true;
            this._previewNeedsPaint = true;
        } catch (e) {
            const msg = this.normalizeError(e);
            this.pdfLoadError = msg;
            this.setStatus(msg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        if (!this.quoteId) {
            this.setStatus('Quote Id is missing.', 'error');
            return;
        }
        if (!this.isValid) {
            this.setStatus(
                this.errors?.length ? this.errors[0] : 'Quote is not valid for PDF.',
                'error'
            );
            return;
        }
        if (this.isSaving) {
            return;
        }

        this.isSaving = true;
        this.setStatus('Saving PDF…', 'info');
        try {
            const result = await saveQuotePdf({
                quoteId: this.quoteId,
                attachmentData: this.getAttachmentDataJson()
            });
            const message = result?.message || 'PDF saved successfully.';
            this.downloadPdfToLaptop(result?.fileName, result?.contentDocumentId);
            this.setStatus(message + ' Download started.', 'success');
            this.toast('Success', message, 'success');
            this.dispatchEvent(new CustomEvent('pdfsaved', { detail: { quoteId: this.quoteId } }));
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this.handleClose(), 900);
        } catch (e) {
            const msg = this.normalizeError(e);
            this.setStatus(msg, 'error');
            this.toast('Error', msg, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleSaveAndSend(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        if (!this.canSave) {
            this.setStatus('Quote is not ready to save.', 'error');
            return;
        }
        if (!this.emailId || !this.subject) {
            this.setStatus('Email Id and subject are mandatory fields, please verify.', 'error');
            return;
        }

        this.isSaving = true;
        this.setStatus('Saving PDF and sending email…', 'info');
        try {
            const msg = await saveAndSendQuotePdf({
                quoteId: this.quoteId,
                emailId: this.emailId,
                ccAddresses: this.ccAddresses || '',
                subject: this.subject,
                body: this.body || '',
                attachmentData: this.getAttachmentDataJson()
            });
            this.setStatus(msg || 'PDF saved and email sent.', 'success');
            this.toast('Success', msg || 'PDF saved and email sent.', 'success');
            this.dispatchEvent(new CustomEvent('pdfsaved', { detail: { quoteId: this.quoteId } }));
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this.handleClose(), 900);
        } catch (e) {
            const msg = this.normalizeError(e);
            this.setStatus(msg, 'error');
            this.toast('Error', msg, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    downloadPdfToLaptop(fileName, contentDocumentId) {
        if (!contentDocumentId) {
            return;
        }
        const name = fileName && String(fileName).endsWith('.pdf') ? fileName : `${fileName || 'Quote'}.pdf`;
        const link = document.createElement('a');
        link.href = `/sfc/servlet.shepherd/document/download/${contentDocumentId}`;
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        link.setAttribute('download', name);
        const mount = this.template.querySelector('.modal');
        if (mount) {
            mount.appendChild(link);
            link.click();
            mount.removeChild(link);
        } else {
            link.click();
        }
    }

    setStatus(message, variant) {
        this.statusMessage = message || '';
        this.statusVariant = variant || 'info';
    }

    toPlainBody(html) {
        return String(html || '')
            .replace(/<br\s*\/?>/gi, '\n')
            .replace(/<[^>]+>/g, '');
    }

    /** Fallback if nested shadow is blocked: neutralize global preview selectors. */
    scopePreviewCss(html) {
        return String(html || '')
            .replace(/div\.header img,\s*img\.logo/g, '.quote-pdf-root div.header img, .quote-pdf-root img.logo')
            .replace(/body,\s*\.quote-pdf-root/g, '.quote-pdf-root')
            .replace(/(^|})\s*body\s*\{/g, '$1.quote-pdf-root{');
    }

    normalizeError(e) {
        if (!e) {
            return 'Unexpected error';
        }
        if (typeof e === 'string') {
            return e;
        }
        const fromAura =
            e?.body?.pageErrors?.[0]?.message ||
            e?.body?.fieldErrors?.[Object.keys(e?.body?.fieldErrors || {})[0]]?.[0]?.message ||
            e?.body?.message ||
            (Array.isArray(e?.body) ? e.body.map((x) => x?.message).filter(Boolean).join(' ') : null);
        if (fromAura) {
            return fromAura;
        }
        if (e?.message) {
            return e.message;
        }
        if (e?.statusText) {
            return e.statusText + (e.status ? ' (' + e.status + ')' : '');
        }
        try {
            const s = JSON.stringify(e);
            if (s && s !== '{}') {
                return s;
            }
        } catch (ignore) {
            /* ignore */
        }
        return String(e) !== '[object Object]' ? String(e) : 'Unexpected error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}