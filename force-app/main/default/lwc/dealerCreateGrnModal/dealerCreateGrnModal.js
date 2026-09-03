import { LightningElement, api, track } from 'lwc';
import getCurrentUserInfo from '@salesforce/apex/GrnController.getCurrentUserInfo';
import getPartnerContacts from '@salesforce/apex/GrnController.getPartnerContacts';
import getInvoiceLinesForGrn from '@salesforce/apex/GrnController.getInvoiceLinesForGrn';
import createGrn from '@salesforce/apex/GrnController.createGrn';

const PORTAL_TOAST_DURATION_MS = 4000;

function toIsoDate(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function toNumber(value) {
    if (value === '' || value === null || value === undefined) {
        return 0;
    }
    const n = Number(value);
    return Number.isFinite(n) ? n : 0;
}

function pendingLimit(row) {
    return toNumber(row.pendingGrnQty);
}

function validateLineFields(row) {
    const pending = pendingLimit(row);
    const received = toNumber(row.receivedQty);
    const damage = toNumber(row.damageQty);
    const shortQty = toNumber(row.shortQty);
    const hasAnyQty =
        (row.receivedQty !== '' && row.receivedQty !== null && row.receivedQty !== undefined) ||
        damage > 0 ||
        shortQty > 0;

    const fieldErrors = {
        receivedQtyError: '',
        damageQtyError: '',
        shortQtyError: '',
        rejectionReasonError: ''
    };

    if (row.receivedQty !== '' && row.receivedQty !== null && row.receivedQty !== undefined) {
        if (received > pending) {
            fieldErrors.receivedQtyError = `Cannot exceed Pending GRN Qty (${pending})`;
        }
    }

    if (damage > pending) {
        fieldErrors.damageQtyError = `Cannot exceed Pending GRN Qty (${pending})`;
    }

    if (shortQty > pending) {
        fieldErrors.shortQtyError = `Cannot exceed Pending GRN Qty (${pending})`;
    }

    if (damage > 0 && !(row.rejectionReason || '').trim()) {
        fieldErrors.rejectionReasonError = 'Required when Damage Qty is entered';
    }

    return { fieldErrors, received, damage, shortQty, pending, hasAnyQty };
}

function readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
            const result = reader.result || '';
            const base64 = String(result).includes(',')
                ? String(result).split(',')[1]
                : String(result);
            resolve(base64);
        };
        reader.onerror = () => reject(new Error('Could not read file: ' + file.name));
        reader.readAsDataURL(file);
    });
}

let fileSeq = 0;

export default class DealerCreateGrnModal extends LightningElement {
    @api invoiceId;
    @api invoiceLabel = '';

    @track isLoading = true;
    @track isSaving = false;
    @track lineRows = [];
    @track partnerContacts = [];
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';
    @track errors = {
        grnDate: '',
        receivedBy: '',
        remarks: '',
        lines: ''
    };

    grnDate = toIsoDate(new Date());
    remarks = '';
    receivedByContactId = '';
    partnerAccountName = '—';
    grnNumberDisplay = 'Auto-generated on save';
    portalToastTimeout;

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        try {
            const [userInfo, contacts, lines] = await Promise.all([
                getCurrentUserInfo(),
                getPartnerContacts(),
                getInvoiceLinesForGrn({ invoiceId: this.invoiceId })
            ]);

            this.partnerAccountName = userInfo?.partnerAccountName || '—';
            this.receivedByContactId = userInfo?.contactId || '';

            this.partnerContacts = (contacts || []).map((c) => ({
                contactId: c.contactId,
                label: c.email ? `${c.name} (${c.email})` : c.name,
                isSelected: c.contactId === this.receivedByContactId
            }));

            if (
                this.receivedByContactId &&
                !this.partnerContacts.some((c) => c.contactId === this.receivedByContactId)
            ) {
                this.receivedByContactId = '';
            }

            this.lineRows = (lines || []).map((line, index) => ({
                key: line.invoiceLineItemId || `row-${index}`,
                invoiceLineItemId: line.invoiceLineItemId,
                productId: line.productId,
                productName: line.productName || '—',
                productCode: line.productCode || '—',
                orderQty: toNumber(line.orderQty),
                orderedQty: toNumber(line.orderedQty),
                pendingGrnQty: toNumber(line.pendingGrnQty),
                remainingQty: toNumber(line.pendingGrnQty),
                receivedQty: '',
                damageQty: 0,
                shortQty: 0,
                rejectionReason: '',
                remarks: '',
                attachments: [],
                include: toNumber(line.pendingGrnQty) > 0,
                receivedQtyError: '',
                damageQtyError: '',
                shortQtyError: '',
                rejectionReasonError: ''
            }));
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
            this.dispatchEvent(new CustomEvent('close'));
        } finally {
            this.isLoading = false;
        }
    }

    get modalTitle() {
        return this.invoiceLabel ? `Create GRN · ${this.invoiceLabel}` : 'Create GRN';
    }

    get hasLines() {
        return this.lineRows && this.lineRows.length > 0;
    }

    get headerStatusDisplay() {
        let hasActiveLine = false;
        let allComplete = true;
        for (const row of this.lineRows || []) {
            const received = toNumber(row.receivedQty);
            const damage = toNumber(row.damageQty);
            const shortQty = toNumber(row.shortQty);
            if (received <= 0 && damage <= 0 && shortQty <= 0) {
                continue;
            }
            hasActiveLine = true;
            const pending = pendingLimit(row);
            if (!(pending > 0 && received >= pending)) {
                allComplete = false;
            }
        }
        if (!hasActiveLine) {
            return '—';
        }
        return allComplete ? 'Complete' : 'Partial';
    }

    get lineRowsView() {
        return this.lineRows.map((row) => {
            const received = toNumber(row.receivedQty);
            const damage = toNumber(row.damageQty);
            const pendingGrn = pendingLimit(row);
            const pendingAfterReceive = Math.max(pendingGrn - received, 0);
            const accepted = Math.max(received - damage, 0);
            const status = pendingGrn > 0 && received >= pendingGrn ? 'Complete' : 'Partial';
            return {
                ...row,
                orderQtyDisplay: toNumber(row.orderQty),
                pendingGrnQtyDisplay: pendingGrn,
                pendingQtyDisplay: pendingAfterReceive,
                acceptedQtyDisplay: accepted,
                statusDisplay: received > 0 || damage > 0 || toNumber(row.shortQty) > 0 ? status : '—',
                hasAttachments: row.attachments && row.attachments.length > 0,
                hasReceivedError: !!row.receivedQtyError,
                hasDamageError: !!row.damageQtyError,
                hasShortError: !!row.shortQtyError,
                hasRejectionError: !!row.rejectionReasonError,
                receivedInputClass: row.receivedQtyError
                    ? 'form-input form-input-sm form-input-error'
                    : 'form-input form-input-sm',
                damageInputClass: row.damageQtyError
                    ? 'form-input form-input-sm form-input-error'
                    : 'form-input form-input-sm',
                shortInputClass: row.shortQtyError
                    ? 'form-input form-input-sm form-input-error'
                    : 'form-input form-input-sm',
                rejectionInputClass: row.rejectionReasonError
                    ? 'form-input form-input-sm form-input-error'
                    : 'form-input form-input-sm',
                rowClass: row.include === false ? 'grn-line-row grn-line-row--disabled' : 'grn-line-row'
            };
        });
    }

    handleHeaderChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.target.value;
        if (field === 'grnDate') {
            this.grnDate = value;
            this.errors = { ...this.errors, grnDate: '' };
        } else if (field === 'remarks') {
            this.remarks = value;
            this.errors = { ...this.errors, remarks: '' };
        } else if (field === 'receivedByContactId') {
            this.receivedByContactId = value;
            this.partnerContacts = this.partnerContacts.map((c) => ({
                ...c,
                isSelected: c.contactId === value
            }));
            this.errors = { ...this.errors, receivedBy: '' };
        }
    }

    handleLineChange(event) {
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value = event.target.value;
        this.lineRows = this.lineRows.map((row) => {
            if (row.key !== key) {
                return row;
            }
            const next = { ...row, [field]: value };
            const { fieldErrors } = validateLineFields(next);
            return { ...next, ...fieldErrors };
        });
        this.errors = { ...this.errors, lines: '' };
    }

    async handleFileChange(event) {
        const key = event.currentTarget.dataset.key;
        const files = event.target.files;
        if (!files || files.length === 0) {
            return;
        }

        try {
            const file = files[0];
            const base64Data = await readFileAsBase64(file);
            const attachment = {
                id: `f-${Date.now()}-${fileSeq++}`,
                name: file.name,
                base64Data
            };
            this.lineRows = this.lineRows.map((row) =>
                row.key === key
                    ? { ...row, attachments: [...(row.attachments || []), attachment] }
                    : row
            );
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        } finally {
            event.target.value = '';
        }
    }

    handleRemoveFile(event) {
        const key = event.currentTarget.dataset.key;
        const fileId = event.currentTarget.dataset.fileId;
        this.lineRows = this.lineRows.map((row) =>
            row.key === key
                ? {
                      ...row,
                      attachments: (row.attachments || []).filter((f) => f.id !== fileId)
                  }
                : row
        );
    }

    handleClose() {
        if (this.isSaving) {
            return;
        }
        this.dispatchEvent(new CustomEvent('close'));
    }

    async handleSave() {
        if (this.isSaving) {
            return;
        }

        const nextErrors = { grnDate: '', receivedBy: '', remarks: '', lines: '' };
        if (!this.grnDate) {
            nextErrors.grnDate = 'GRN Date is required.';
        }
        if (!this.receivedByContactId) {
            nextErrors.receivedBy = 'Received By is required.';
        }
        if (!(this.remarks || '').trim()) {
            nextErrors.remarks = 'Remarks is required.';
        }

        let hasFieldErrors = false;
        const validatedRows = this.lineRows.map((row) => {
            const { fieldErrors, received, damage, shortQty } = validateLineFields(row);
            if (
                fieldErrors.receivedQtyError ||
                fieldErrors.damageQtyError ||
                fieldErrors.shortQtyError ||
                fieldErrors.rejectionReasonError
            ) {
                hasFieldErrors = true;
            }
            return { ...row, ...fieldErrors, _received: received, _damage: damage, _shortQty: shortQty };
        });
        this.lineRows = validatedRows.map(({ _received, _damage, _shortQty, ...rest }) => rest);

        const payloadLines = [];
        for (const row of validatedRows) {
            const received = row._received;
            const damage = row._damage;
            const shortQty = row._shortQty;
            if (received <= 0 && damage <= 0 && shortQty <= 0) {
                continue;
            }
            if (received <= 0) {
                nextErrors.lines = 'Received Qty is required for each product being received.';
                break;
            }
            if (
                row.receivedQtyError ||
                row.damageQtyError ||
                row.shortQtyError ||
                row.rejectionReasonError
            ) {
                continue;
            }
            const orderedForThisGrn = toNumber(row.orderedQty);
            payloadLines.push({
                invoiceLineItemId: row.invoiceLineItemId,
                productId: row.productId,
                orderedQty: orderedForThisGrn,
                receivedQty: received,
                damageQty: damage,
                shortQty: shortQty,
                rejectionReason: row.rejectionReason || '',
                remarks: row.remarks || '',
                attachments: (row.attachments || []).map((f) => ({
                    fileName: f.name,
                    base64Data: f.base64Data
                }))
            });
        }

        if (hasFieldErrors) {
            nextErrors.lines = nextErrors.lines || 'Fix the quantity errors below before saving.';
        }

        if (!nextErrors.lines && !hasFieldErrors && payloadLines.length === 0) {
            nextErrors.lines = 'Received Qty is required for at least one product.';
        }

        this.errors = nextErrors;
        if (
            nextErrors.grnDate ||
            nextErrors.receivedBy ||
            nextErrors.remarks ||
            nextErrors.lines ||
            hasFieldErrors
        ) {
            return;
        }

        this.isSaving = true;
        try {
            const saved = await createGrn({
                input: {
                    invoiceId: this.invoiceId,
                    grnDate: this.grnDate,
                    receivedByContactId: this.receivedByContactId || null,
                    remarks: this.remarks,
                    lines: payloadLines
                }
            });
            this.dispatchEvent(
                new CustomEvent('save', {
                    detail: { grn: saved }
                })
            );
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    get portalToastClass() {
        return `portal-toast portal-toast--${this.portalToastVariant || 'info'}`;
    }

    showToast(title, message, variant) {
        if (this.portalToastTimeout) {
            window.clearTimeout(this.portalToastTimeout);
        }
        this.portalToastTitle = title || 'Info';
        this.portalToastMessage = message || '';
        this.portalToastVariant = variant || 'info';
        this.portalToastVisible = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.portalToastTimeout = window.setTimeout(() => {
            this.portalToastVisible = false;
            this.portalToastTimeout = null;
        }, PORTAL_TOAST_DURATION_MS);
    }

    extractError(error) {
        return error?.body?.message || error?.message || 'Something went wrong. Please try again.';
    }
}