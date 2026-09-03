import { LightningElement, api, track, wire } from 'lwc';

import searchUsers from '@salesforce/apex/ActivityController.searchUsers';
import searchWho from '@salesforce/apex/ActivityController.searchWho';
import searchWhat from '@salesforce/apex/ActivityController.searchWhat';
import createTask from '@salesforce/apex/ActivityController.createTask';
import getTaskSubjects from '@salesforce/apex/ActivityController.getTaskSubjects';
import getTaskPriorityValues from '@salesforce/apex/ActivityController.getTaskPriorityValues';
import getMyChannelPartnerAccountId from '@salesforce/apex/ActivityController.getMyChannelPartnerAccountId';
import debugPartnerContext from '@salesforce/apex/ActivityController.debugPartnerContext';
import getActivityDetail from '@salesforce/apex/DealerLeadController.getActivityDetail';
import saveActivityDetail from '@salesforce/apex/DealerLeadController.saveActivityDetail';
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';

const PORTAL_TOAST_DURATION_MS = 4000;

const SUBJECT_OPTIONS = [
    { label: 'Call', value: 'Call' },
    { label: 'Send Letter', value: 'Send Letter' },
    { label: 'Send Quote', value: 'Send Quote' },
    { label: 'Delegation Task', value: 'Delegation Task' },
    { label: 'Checklist Task', value: 'Checklist Task' },
    { label: 'Help Ticket', value: 'Help Ticket' },
    { label: 'Reminder', value: 'Reminder' },
    { label: 'Follow-up Task', value: 'Follow-up Task' },
    { label: 'Other', value: 'Other' }
];

const PRIORITY_OPTIONS = [
    { label: 'High', value: 'High' },
    { label: 'Normal', value: 'Normal' },
    { label: 'Low', value: 'Low' }
];

const STATUS_OPTIONS = [
    { label: 'Open', value: 'Open' },
    { label: 'Completed', value: 'Completed' }
];

export default class NewTaskModal extends LightningElement {
    @api leadId;
    @api leadName;
    @api quoteId;
    @api quoteName;
    @api relatedContactId;
    @api relatedContactName;
    @api partnerAccountId;
    /** When set, modal opens in edit mode with create layout */
    @api taskId;

    resolvedPartnerAccountId = null;
    @track partnerDebugMessage = '';
    isLoadingEdit = false;

    @track subjectOptions = [...SUBJECT_OPTIONS];
    @track priorityOptions = [...PRIORITY_OPTIONS];
    @track statusOptions = [...STATUS_OPTIONS];
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';

    portalToastTimeout;
    subject = '';
    priority = 'Normal';
    status = 'Open';
    dueDate = '';
    description = '';
    reminder = true;
    completedDateTime = '';
    @track errors = {};

    assignedToId = null;
    assignedToTerm = '';
    @track assignedToResults = [];
    showAssignedToResults = false;
    assignedToTimeout;

    whoId = null;
    whoTerm = '';
    whoObjectType = '';
    @track whoResults = [];
    showWhoResults = false;
    whoTimeout;

    whatId = null;
    whatTerm = '';
    @track whatResults = [];
    showWhatResults = false;
    whatTimeout;

    isSaving = false;

    get isEditMode() {
        return !!this.taskId;
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Task' : 'New Task';
    }

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME_FIELD] })
    wiredUser({ data }) {
        if (data && data.fields && data.fields.Name && !this.isEditMode && !this.assignedToId) {
            this.assignedToId = USER_ID;
            this.assignedToTerm = data.fields.Name.value || '';
        }
    }

    connectedCallback() {
        this.initPartnerContext();
        if (this.isEditMode) {
            this.loadTaskForEdit();
            return;
        }
        if (this.quoteId) {
            this.whatId = this.quoteId;
            this.whatTerm = this.quoteName || '';
        }
        if (this.relatedContactId) {
            this.whoId = this.relatedContactId;
            this.whoTerm = this.relatedContactName || '';
        }
    }

    async loadTaskForEdit() {
        this.isLoadingEdit = true;
        try {
            const d = await getActivityDetail({ recordId: this.taskId });
            this.subject = d.subject || '';
            this.priority = d.priority || 'Normal';
            this.status = d.status || 'Open';
            this.dueDate = d.dueDateIso || '';
            this.description = d.description || '';
            this.reminder = d.reminderSet === true;
            this.completedDateTime = d.reminderDateTimeIso || '';
            this.assignedToId = d.ownerId || USER_ID || null;
            this.assignedToTerm = d.ownerName || '';
            this.whoId = d.whoId || null;
            this.whoTerm = d.whoName || '';
            this.whatId = d.whatId || null;
            this.whatTerm = d.whatName || '';
            // Keep current values in dropdowns even if not standard
            this.ensureOption(this.subjectOptions, this.subject);
            this.ensureOption(this.priorityOptions, this.priority);
            this.ensureOption(this.statusOptions, this.status);
            this.errors = {};
        } catch (e) {
            this.showToast('Error', this.extractErrorMessage(e), 'error');
        } finally {
            this.isLoadingEdit = false;
        }
    }

    ensureOption(list, value) {
        if (!value || !list) {
            return;
        }
        if (!list.some((opt) => opt.value === value)) {
            list.unshift({ label: value, value });
        }
    }

    async initPartnerContext() {
        await this.resolvePartnerAccount();
        await this.loadPartnerDebug();
    }

    async resolvePartnerAccount() {
        if (this.partnerAccountId) {
            this.resolvedPartnerAccountId = this.partnerAccountId;
            return;
        }
        try {
            const id = await getMyChannelPartnerAccountId();
            if (id) {
                this.resolvedPartnerAccountId = id;
            }
        } catch (e) {
            console.error(e);
        }
    }

    async loadPartnerDebug() {
        try {
            const info = await debugPartnerContext({
                leadId: this.leadId || null,
                partnerAccountId:
                    this.partnerAccountId || this.resolvedPartnerAccountId || null
            });
            if (info) {
                this.partnerDebugMessage = info.message || '';
                if (info.resolvedPartnerId) {
                    this.resolvedPartnerAccountId = info.resolvedPartnerId;
                }
            }
        } catch (e) {
            this.partnerDebugMessage =
                e?.body?.message || e?.message || 'Partner debug failed';
            console.error(e);
        }
    }

    get effectivePartnerAccountId() {
        return this.partnerAccountId || this.resolvedPartnerAccountId || null;
    }

    get showPartnerDebug() {
        return !!this.partnerDebugMessage;
    }

    @wire(getTaskSubjects)
    wiredSubjects({ data, error }) {
        if (data && data.length > 0) {
            this.subjectOptions = data;
        } else if (error) {
            this.subjectOptions = [...SUBJECT_OPTIONS];
        }
    }

    @wire(getTaskPriorityValues)
    wiredPriorities({ data, error }) {
        if (data && data.length > 0) {
            this.priorityOptions = data;
            if (!this.priority) {
                this.priority = data[0].value;
            }
        } else if (error) {
            this.priorityOptions = [...PRIORITY_OPTIONS];
        }
    }

    get subjectSelectOptions() {
        return (this.subjectOptions || []).map((opt) => ({
            label: opt.label,
            value: opt.value,
            selected: opt.value === this.subject
        }));
    }

    get prioritySelectOptions() {
        return (this.priorityOptions || []).map((opt) => ({
            label: opt.label,
            value: opt.value,
            selected: opt.value === this.priority
        }));
    }

    get statusSelectOptions() {
        return (this.statusOptions || []).map((opt) => ({
            label: opt.label,
            value: opt.value,
            selected: opt.value === this.status
        }));
    }

    get hasSelectedAssignedTo() {
        return !!this.assignedToId && !!this.assignedToTerm;
    }

    get hasSelectedWho() {
        return !!this.whoId && !!this.whoTerm;
    }

    get hasSelectedWhat() {
        return (!!this.whatId && !!this.whatTerm) || !!this.quoteId;
    }

    get nameDisabled() {
        return !this.hasSelectedWhat && !this.quoteId;
    }

    get relatedToDisabled() {
        return !!this.quoteId;
    }

    get nameHint() {
        return this.nameDisabled
            ? 'Select a Customer account in Related To first.'
            : '';
    }

    get showAssignedToDropdown() {
        return this.showAssignedToResults && !this.hasSelectedAssignedTo;
    }

    get showWhoDropdown() {
        return (
            this.showWhoResults &&
            !this.hasSelectedWho &&
            !this.nameDisabled
        );
    }

    get showWhatDropdown() {
        return this.showWhatResults && !this.hasSelectedWhat;
    }

    get hasAssignedToResults() {
        return this.assignedToResults && this.assignedToResults.length > 0;
    }

    get hasWhoResults() {
        return this.whoResults && this.whoResults.length > 0;
    }

    get hasWhatResults() {
        return this.whatResults && this.whatResults.length > 0;
    }

    mapLookupResults(rows) {
        return (rows || []).map((row) => ({
            id: row.id,
            label: row.label || row.name,
            subtitle: row.subtitle,
            objectType: row.objectType
        }));
    }

    /* =========================
       FIELD HANDLERS
    ========================== */

    handleSubjectChange(event) {
        this.subject = event.target.value;
        this.clearError('subject');
    }

    handlePriorityChange(event) {
        this.priority = event.target.value;
        this.clearError('priority');
    }

    handleStatusChange(event) {
        this.status = event.target.value;
        this.clearError('status');
    }

    handleDueDateChange(event) {
        this.dueDate = event.target.value;
        this.clearError('dueDate');
        this.syncReminderDateTimeFromDueDate();
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
        this.clearError('description');
    }

    handleReminderChange(event) {
        this.reminder = event.target.checked;
        if (!this.reminder) {
            this.completedDateTime = '';
            return;
        }
        this.syncReminderDateTimeFromDueDate();
    }

    handleCompletedDateTimeChange(event) {
        this.completedDateTime = event.target.value;
    }

    /** Reminder date = Task Due Date; time = 9:00 AM, or now+1h if due date is today. */
    syncReminderDateTimeFromDueDate() {
        if (!this.reminder || !this.dueDate) {
            return;
        }
        if (this.dueDate === this.getTodayDateString()) {
            const inOneHour = new Date(Date.now() + 60 * 60 * 1000);
            this.completedDateTime = this.formatLocalDateTime(inOneHour);
            return;
        }
        this.completedDateTime = `${this.dueDate}T09:00`;
    }

    getTodayDateString() {
        return this.formatDateOnly(new Date());
    }

    formatDateOnly(date) {
        const pad = (n) => String(n).padStart(2, '0');
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    }

    formatLocalDateTime(date) {
        const pad = (n) => String(n).padStart(2, '0');
        return `${this.formatDateOnly(date)}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
    }

    clearError(field) {
        if (this.errors[field]) {
            this.errors = { ...this.errors, [field]: null };
        }
    }

    /* =========================
       ASSIGNED TO (User)
    ========================== */

    handleAssignedToFocus() {
        this.showAssignedToResults = true;
        this.runAssignedToSearch(this.assignedToTerm || '');
    }

    handleAssignedToSearch(event) {
        this.assignedToTerm = event.target.value;
        this.assignedToId = null;
        this.showAssignedToResults = true;

        window.clearTimeout(this.assignedToTimeout);
        this.assignedToTimeout = window.setTimeout(() => {
            this.runAssignedToSearch(this.assignedToTerm);
        }, 200);
    }

    async runAssignedToSearch(term) {
        try {
            const data =
                (await searchUsers({
                    searchText: term || '',
                    leadId: this.leadId || null,
                    partnerAccountId: this.effectivePartnerAccountId
                })) || [];
            this.assignedToResults = this.mapLookupResults(data);
            this.showAssignedToResults = true;
        } catch (error) {
            this.assignedToResults = [];
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        }
    }

    selectAssignedTo(event) {
        event.preventDefault();
        this.assignedToId = event.currentTarget.dataset.id;
        this.assignedToTerm = event.currentTarget.dataset.label;
        this.assignedToResults = [];
        this.showAssignedToResults = false;
        this.clearError('assignedToId');
    }

    clearAssignedTo(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.assignedToId = null;
        this.assignedToTerm = '';
        this.assignedToResults = [];
        this.showAssignedToResults = false;
    }

    /* =========================
       RELATED TO (Customer Account under login Channel Partner)
    ========================== */

    handleWhatFocus() {
        this.showWhatResults = true;
        this.runWhatSearch(this.whatTerm || '');
    }

    handleWhatSearch(event) {
        this.whatTerm = event.target.value;
        this.whatId = null;
        this.showWhatResults = true;

        // Clearing Related To also clears Name (contacts are account-scoped)
        this.whoId = null;
        this.whoTerm = '';
        this.whoObjectType = '';
        this.whoResults = [];
        this.showWhoResults = false;

        window.clearTimeout(this.whatTimeout);
        this.whatTimeout = window.setTimeout(() => {
            this.runWhatSearch(this.whatTerm);
        }, 200);
    }

    async runWhatSearch(term) {
        try {
            const data =
                (await searchWhat({
                    searchText: term || '',
                    leadId: this.leadId || null,
                    partnerAccountId: this.effectivePartnerAccountId
                })) || [];
            this.whatResults = this.mapLookupResults(data);
            this.showWhatResults = true;
        } catch (error) {
            this.whatResults = [];
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        }
    }

    selectWhat(event) {
        event.preventDefault();
        this.whatId = event.currentTarget.dataset.id;
        this.whatTerm = event.currentTarget.dataset.label;
        this.whatResults = [];
        this.showWhatResults = false;

        // Contacts depend on the selected Customer account
        this.whoId = null;
        this.whoTerm = '';
        this.whoObjectType = '';
        this.whoResults = [];
        this.showWhoResults = false;
        this.clearError('whatId');
        this.clearError('whoId');
    }

    clearWhat(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.whatId = null;
        this.whatTerm = '';
        this.whatResults = [];
        this.showWhatResults = false;

        this.whoId = null;
        this.whoTerm = '';
        this.whoObjectType = '';
        this.whoResults = [];
        this.showWhoResults = false;
    }

    /* =========================
       NAME (Contact of selected Customer)
    ========================== */

    handleWhoFocus() {
        if (this.nameDisabled) {
            return;
        }
        this.showWhoResults = true;
        this.runWhoSearch(this.whoTerm || '');
    }

    handleWhoSearch(event) {
        if (this.nameDisabled) {
            return;
        }
        this.whoTerm = event.target.value;
        this.whoId = null;
        this.whoObjectType = '';
        this.showWhoResults = true;

        window.clearTimeout(this.whoTimeout);
        this.whoTimeout = window.setTimeout(() => {
            this.runWhoSearch(this.whoTerm);
        }, 200);
    }

    async runWhoSearch(term) {
        if (!this.whatId) {
            this.whoResults = [];
            return;
        }
        try {
            const data =
                (await searchWho({
                    searchText: term || '',
                    accountId: this.whatId,
                    leadId: this.leadId || null,
                    partnerAccountId: this.effectivePartnerAccountId
                })) || [];
            this.whoResults = this.mapLookupResults(data);
            this.showWhoResults = true;
        } catch (error) {
            this.whoResults = [];
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        }
    }

    selectWho(event) {
        event.preventDefault();
        this.whoId = event.currentTarget.dataset.id;
        this.whoTerm = event.currentTarget.dataset.label;
        this.whoObjectType =
            event.currentTarget.dataset.type || 'Contact';
        this.whoResults = [];
        this.showWhoResults = false;
        this.clearError('whoId');
    }

    clearWho(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.whoId = null;
        this.whoTerm = '';
        this.whoObjectType = '';
        this.whoResults = [];
        this.showWhoResults = false;
    }

    /* =========================
       CLOSE / SAVE
    ========================== */

    handleClose() {
        if (this.isSaving) {
            return;
        }
        this.dispatchEvent(new CustomEvent('close'));
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleSave() {
        const next = {};
        if (!this.subject) {
            next.subject = 'Subject is required.';
        }
        if (!this.assignedToId) {
            next.assignedToId = 'Assigned To is required.';
        }
        if (!this.priority) {
            next.priority = 'Priority is required.';
        }
        if (!this.dueDate) {
            next.dueDate = 'Task Due Date is required.';
        }
        if (!this.status) {
            next.status = 'Task Status is required.';
        }
        if (!this.whatId && !this.quoteId) {
            next.whatId = 'Related To is required.';
        }
        if (!this.whoId) {
            next.whoId = 'Name is required.';
        }
        if (!this.description || !this.description.trim()) {
            next.description = 'Task Description is required.';
        }

        this.errors = next;
        if (Object.keys(next).length > 0 || this.isSaving) {
            return;
        }

        this.isSaving = true;

        if (this.isEditMode) {
            const input = {
                subject: this.subject,
                priority: this.priority,
                status: this.status,
                dueDateIso: this.dueDate || null,
                ownerId: this.assignedToId || null,
                description: this.description,
                whoId: this.whoId || null,
                whatId: this.whatId || this.quoteId || null,
                reminderSet: !!this.reminder,
                reminderDateTimeIso:
                    this.reminder && this.completedDateTime
                        ? this.completedDateTime
                        : null
            };
            saveActivityDetail({ recordId: this.taskId, input })
                .then((updated) => {
                    this.isSaving = false;
                    this.showToast('Success', 'Task updated successfully.', 'success');
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    window.setTimeout(() => {
                        this.dispatchEvent(
                            new CustomEvent('save', {
                                detail: updated || { id: this.taskId }
                            })
                        );
                        this.dispatchEvent(new CustomEvent('close'));
                    }, 1200);
                })
                .catch((error) => {
                    this.isSaving = false;
                    console.error(error);
                    this.showToast('Error', this.extractErrorMessage(error), 'error');
                });
            return;
        }

        let reminderDateTimeIso = null;
        if (this.reminder && this.completedDateTime) {
            const parsed = new Date(this.completedDateTime);
            if (!Number.isNaN(parsed.getTime())) {
                reminderDateTimeIso = parsed.toISOString();
            }
        }

        createTask({
            wrapper: {
                subject: this.subject,
                priority: this.priority,
                status: this.status,
                dueDate: this.dueDate || null,
                assignedToId: this.assignedToId || null,
                description: this.description,
                whoId: this.whoId || null,
                whatId: this.whatId || this.quoteId || null,
                reminderSet: !!this.reminder,
                reminderDateTime: reminderDateTimeIso,
                completedDateTime: this.reminder ? this.completedDateTime || null : null,
                leadId: this.leadId || null,
                quoteId: this.quoteId || null,
                partnerAccountId: this.effectivePartnerAccountId || null
            }
        })
            .then((summary) => {
                this.isSaving = false;
                this.showToast('Success', 'Task created successfully.', 'success');
                // Keep modal open briefly so the portal toast is visible
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.setTimeout(() => {
                    this.dispatchEvent(new CustomEvent('save', { detail: summary }));
                }, 2000);
            })
            .catch((error) => {
                this.isSaving = false;
                console.error(error);
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
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

    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong. Please try again.';
    }
}