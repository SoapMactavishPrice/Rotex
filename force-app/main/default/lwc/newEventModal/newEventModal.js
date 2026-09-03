import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';

import createVisitEvent from '@salesforce/apex/DealerLeadController.createVisitEvent';
import getActivityDetail from '@salesforce/apex/DealerLeadController.getActivityDetail';
import saveActivityDetail from '@salesforce/apex/DealerLeadController.saveActivityDetail';
import searchUsers from '@salesforce/apex/ActivityController.searchUsers';
import searchWho from '@salesforce/apex/ActivityController.searchWho';
import searchWhat from '@salesforce/apex/ActivityController.searchWhat';
import getMyChannelPartnerAccountId from '@salesforce/apex/ActivityController.getMyChannelPartnerAccountId';

const PORTAL_TOAST_DURATION_MS = 4000;

const SUBJECT_OPTIONS = [
    { label: 'Call', value: 'Call' },
    { label: 'Email', value: 'Email' },
    { label: 'Meeting', value: 'Meeting' },
    { label: 'Send Letter/Quote', value: 'Send Letter/Quote' },
    { label: 'Other', value: 'Other' },
    { label: 'Weekly off', value: 'Weekly off' },
    { label: 'On leave', value: 'On leave' },
    { label: 'C-Off', value: 'C-Off' },
    { label: 'Public Holiday', value: 'Public Holiday' },
    { label: 'Traveling', value: 'Traveling' }
];

const VISIT_STATUS_OPTIONS = [
    { label: 'Scheduled', value: 'Scheduled' },
    { label: 'Completed', value: 'Completed' }
];

const VISIT_TYPE_OPTIONS = [
    { label: 'Offline', value: 'Offline' },
    { label: 'Virtual', value: 'Virtual' }
];

const NEXT_ACTION_APPLICABLE_OPTIONS = [
    { label: 'Yes', value: 'Yes' },
    { label: 'No', value: 'No' }
];

export default class NewEventModal extends LightningElement {
    @api leadId;
    @api leadName;
    @api quoteId;
    @api quoteName;
    @api relatedContactId;
    @api relatedContactName;
    @api relatedAccountId;
    @api relatedAccountName;
    @api partnerAccountId;
    /** When set (with mode=edit), form loads this Event for editing */
    @api eventId;
    /** 'edit' | omit for create — string is reliable across LWC boolean attr quirks */
    @api mode;

    resolvedPartnerAccountId = null;
    isLoadingEdit = false;

    @track form = this.buildEmptyForm();
    @track errors = {};
    @track subjectOptions = [...SUBJECT_OPTIONS];
    @track visitStatusOptions = [...VISIT_STATUS_OPTIONS];
    @track visitTypeOptions = [...VISIT_TYPE_OPTIONS];
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';
    showSubjectDropdown = false;

    @track assignedToResults = [];
    @track whoResults = [];
    @track whatResults = [];

    portalToastTimeout;
    assignedToSearch = '';
    whoSearch = '';
    whatSearch = '';

    showAssignedToResults = false;
    showWhoResults = false;
    showWhatResults = false;

    searchingAssignedTo = false;
    searchingWho = false;
    searchingWhat = false;

    whoObjectType = '';

    isSaving = false;

    assignedToTimeout;
    whoTimeout;
    whatTimeout;

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME_FIELD] })
    wiredUser({ data }) {
        if (data && data.fields && data.fields.Name) {
            this.form = {
                ...this.form,
                ownerId: USER_ID,
                ownerName: data.fields.Name.value
            };
        }
    }

    connectedCallback() {
        this.resolvePartnerAccount();
        if (this.isEditMode) {
            this.loadEventForEdit();
        } else {
            this.bootstrap();
        }
    }

    get isEditMode() {
        return this.mode === 'edit' || !!(this.eventId);
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Event' : 'New Event';
    }

    async loadEventForEdit() {
        this.isLoadingEdit = true;
        try {
            const d = await getActivityDetail({ recordId: this.eventId });
            const points =
                d.nextActionPoints === 'N/A' ? '' : d.nextActionPoints || '';
            this.form = {
                ...this.buildEmptyForm(),
                subject: d.subject || '',
                ownerId: d.ownerId || USER_ID || null,
                ownerName: d.ownerName || '',
                startDateTime: d.startDateTimeIso || '',
                endDateTime: d.endDateTimeIso || '',
                location: d.location || '',
                description: d.description || '',
                visitStatus: d.visitStatus || 'Scheduled',
                visitType: d.visitType || 'Offline',
                whatId: d.whatId || null,
                whatName: d.whatName || '',
                whoId: d.whoId || null,
                whoName: d.whoName || '',
                mom: d.mom || '',
                nextActionPoints: points,
                nextActionApplicable: d.nextActionApplicable || '',
                nextActionDate: d.nextActionDateIso || '',
                reminder: d.reminderSet === true,
                reminderMinutes:
                    d.reminderMinutes != null && d.reminderMinutes !== undefined
                        ? String(d.reminderMinutes)
                        : '15'
            };
            this.errors = {};
        } catch (e) {
            this.showToast('Error', this.extractError(e), 'error');
        } finally {
            this.isLoadingEdit = false;
        }
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

    get effectivePartnerAccountId() {
        return this.partnerAccountId || this.resolvedPartnerAccountId || null;
    }

    mapLookupResults(rows) {
        return (rows || []).map((row) => ({
            id: row.id,
            label: row.label || row.name,
            subtitle: row.subtitle,
            objectType: row.objectType || 'Contact',
            iconName:
                row.objectType === 'Account'
                    ? 'standard:account'
                    : row.objectType === 'Lead'
                      ? 'standard:lead'
                      : 'standard:contact'
        }));
    }

    buildEmptyForm() {
        return {
            subject: 'Meeting',
            ownerId: USER_ID || null,
            ownerName: '',
            startDateTime: '',
            endDateTime: '',
            location: '',
            description: '',
            visitStatus: 'Scheduled',
            visitType: 'Offline',
            whatId: null,
            whatName: '',
            whoId: null,
            whoName: '',
            mom: '',
            nextActionPoints: '',
            nextActionApplicable: '',
            nextActionDate: '',
             reminder: false,
    reminderMinutes: '15'
        };
    }

    bootstrap() {
        const now = new Date();
        now.setMinutes(0, 0, 0);
        now.setHours(now.getHours() + 1);
        const end = new Date(now.getTime() + 60 * 60 * 1000);

        this.subjectOptions = [...SUBJECT_OPTIONS];
        this.visitStatusOptions = [...VISIT_STATUS_OPTIONS];
        this.visitTypeOptions = [...VISIT_TYPE_OPTIONS];

        this.form = {
            ...this.buildEmptyForm(),
            subject: 'Meeting',
            ownerId: this.form.ownerId || USER_ID,
            ownerName: this.form.ownerName || '',
            startDateTime: this.toLocalInputValue(now),
            endDateTime: this.toLocalInputValue(end),
            visitStatus: 'Scheduled',
            visitType: 'Offline'
        };
        if (this.quoteId) {
            this.form = {
                ...this.form,
                whatId: this.quoteId,
                whatName: this.quoteName || ''
            };
        } else if (this.relatedAccountId) {
            this.form = {
                ...this.form,
                whatId: this.relatedAccountId,
                whatName: this.relatedAccountName || ''
            };
        }
        if (this.relatedContactId) {
            this.form = {
                ...this.form,
                whoId: this.relatedContactId,
                whoName: this.relatedContactName || ''
            };
        }
        this.errors = {};
    }

    get subjectSelectOptions() {
        return (this.subjectOptions || []).map((opt) => ({
            label: opt.label,
            value: opt.value,
            selected: opt.value === this.form.subject
        }));
    }

    get filteredSubjectOptions() {
        const term = (this.form.subject || '').toLowerCase().trim();
        const opts = this.subjectOptions || SUBJECT_OPTIONS;
        if (!term) {
            return opts;
        }
        return opts.filter(
            (opt) =>
                (opt.label || '').toLowerCase().includes(term) ||
                (opt.value || '').toLowerCase().includes(term)
        );
    }

    get hasFilteredSubjects() {
        return (this.filteredSubjectOptions || []).length > 0;
    }

    get customSubjectValue() {
        return (this.form.subject || '').trim();
    }

    get showUseCustomSubject() {
        const val = this.customSubjectValue;
        if (!val) {
            return false;
        }
        const opts = this.subjectOptions || SUBJECT_OPTIONS;
        const exact = opts.some(
            (opt) => (opt.value || '').toLowerCase() === val.toLowerCase()
        );
        return !exact;
    }

    get showNoSubjectMatches() {
        return (
            !this.hasFilteredSubjects &&
            !this.showUseCustomSubject &&
            !(this.form.subject || '').trim()
        );
    }

    get visitStatusSelectOptions() {
        // Create: Completed cannot be selected (disabled). Edit: both choices enabled.
        return (this.visitStatusOptions || VISIT_STATUS_OPTIONS).map((opt) => {
            const isCompleted = opt.value === 'Completed';
            return {
                label: opt.label,
                value: opt.value,
                selected: opt.value === this.form.visitStatus,
                // true only on create for Completed — never true in edit
                isDisabled: !this.isEditMode && isCompleted,
                isEnabled: this.isEditMode || !isCompleted
            };
        });
    }

    get visitTypeSelectOptions() {
        return (this.visitTypeOptions || []).map((opt) => ({
            label: opt.label,
            value: opt.value,
            selected: opt.value === this.form.visitType
        }));
    }

    get nextActionApplicableSelectOptions() {
        return NEXT_ACTION_APPLICABLE_OPTIONS.map((opt) => ({
            label: opt.label,
            value: opt.value,
            selected: opt.value === this.form.nextActionApplicable
        }));
    }

    get reminderMinuteSelectOptions() {
        const options = [
            { value: '0', label: '0 minutes' },
            { value: '5', label: '5 minutes' },
            { value: '10', label: '10 minutes' },
            { value: '15', label: '15 minutes' },
            { value: '30', label: '30 minutes' },
            { value: '60', label: '1 hour' },
            { value: '120', label: '2 hours' },
            { value: '180', label: '3 hours' },
            { value: '240', label: '4 hours' },
            { value: '300', label: '5 hours' },
            { value: '360', label: '6 hours' },
            { value: '420', label: '7 hours' },
            { value: '480', label: '8 hours' },
            { value: '540', label: '9 hours' },
            { value: '600', label: '10 hours' },
            { value: '660', label: '11 hours' },
            { value: '720', label: '12 hours' },
            { value: '1080', label: '18 hours' },
            { value: '1440', label: '1 day' },
            { value: '2880', label: '2 days' }
        ];
        const cur = String(this.form.reminderMinutes != null ? this.form.reminderMinutes : '15');
        return options.map((opt) => ({
            ...opt,
            selected: opt.value === cur
        }));
    }

    get isVisitCompleted() {
        return this.form.visitStatus === 'Completed';
    }

    get showNextActionPoints() {
        return (
            this.form.visitStatus === 'Completed' &&
            this.form.nextActionApplicable === 'Yes'
        );
    }

    get showNextActionDate() {
        return (
            this.form.visitStatus === 'Completed' &&
            this.form.nextActionApplicable === 'Yes'
        );
    }

    get relatedToDisabled() {
        return !!this.quoteId || !!this.relatedAccountId;
    }

    get relatedToHint() {
        if (this.quoteId) {
            return 'Linked to this quotation.';
        }
        if (this.relatedAccountId) {
            return 'Linked to this contact\'s customer.';
        }
        return '';
    }

    get nameDisabled() {
        return (
            (!this.hasSelectedWhat && !this.quoteId && !this.relatedAccountId) ||
            !!this.relatedContactId
        );
    }

    get nameHint() {
        if (this.relatedContactId) {
            return 'Linked to the quote contact.';
        }
        return this.nameDisabled
            ? 'Select a Customer account in Related To first.'
            : '';
    }

    toLocalInputValue(date) {
        const pad = (n) => String(n).padStart(2, '0');
        return (
            date.getFullYear() +
            '-' +
            pad(date.getMonth() + 1) +
            '-' +
            pad(date.getDate()) +
            'T' +
            pad(date.getHours()) +
            ':' +
            pad(date.getMinutes())
        );
    }

    handleInput(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        let value =
            event.target.type === 'checkbox'
                ? event.target.checked
                : event.target.value;

        // Create only: Completed is not allowed
        if (
            !this.isEditMode &&
            field === 'visitStatus' &&
            value === 'Completed'
        ) {
            value = 'Scheduled';
        }

        this.form = { ...this.form, [field]: value };

        if (field === 'visitStatus' && value !== 'Completed') {
            this.form = {
                ...this.form,
                mom: '',
                nextActionPoints: '',
                nextActionApplicable: '',
                nextActionDate: ''
            };
        }

        if (field === 'nextActionApplicable' && value !== 'Yes') {
            this.form = {
                ...this.form,
                nextActionPoints: '',
                nextActionDate: ''
            };
            if (this.errors.nextActionPoints || this.errors.nextActionDate) {
                this.errors = {
                    ...this.errors,
                    nextActionPoints: null,
                    nextActionDate: null
                };
            }
        }

        if (this.errors[field]) {
            this.errors = { ...this.errors, [field]: null };
        }
    }

    handleSubjectInput(event) {
        const value = event.target.value;
        this.form = { ...this.form, subject: value };
        this.showSubjectDropdown = true;
        if (this.errors.subject) {
            this.errors = { ...this.errors, subject: null };
        }
    }

    handleSubjectFocus() {
        this.showSubjectDropdown = true;
    }

    handleSubjectBlur() {
        // Delay so option mousedown can run first
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this.showSubjectDropdown = false;
        }, 150);
    }

    selectSubject(event) {
        event.preventDefault();
        const value = event.currentTarget.dataset.value || '';
        this.form = { ...this.form, subject: value };
        this.showSubjectDropdown = false;
        if (this.errors.subject) {
            this.errors = { ...this.errors, subject: null };
        }
    }

    /* ================= ASSIGNED TO ================= */

    handleAssignedToFocus() {
        this.showAssignedToResults = true;
        this.runAssignedToSearch(this.assignedToSearch || '');
    }

    handleAssignedToSearch(event) {
        this.assignedToSearch = event.target.value;
        this.showAssignedToResults = true;
        window.clearTimeout(this.assignedToTimeout);
        this.assignedToTimeout = window.setTimeout(() => {
            this.runAssignedToSearch(this.assignedToSearch);
        }, 200);
    }

    async runAssignedToSearch(term) {
        this.searchingAssignedTo = true;
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
            this.showToast('Error', this.extractError(error), 'error');
        } finally {
            this.searchingAssignedTo = false;
        }
    }

    selectAssignedTo(event) {
        event.preventDefault();
        this.form = {
            ...this.form,
            ownerId: event.currentTarget.dataset.id,
            ownerName: event.currentTarget.dataset.label
        };
        this.assignedToSearch = '';
        this.assignedToResults = [];
        this.showAssignedToResults = false;
        if (this.errors.ownerId) {
            this.errors = { ...this.errors, ownerId: null };
        }
    }

    clearAssignedTo(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.form = { ...this.form, ownerId: null, ownerName: '' };
        this.assignedToSearch = '';
        this.assignedToResults = [];
        this.showAssignedToResults = false;
    }

    /* ================= NAME ================= */

    handleWhoFocus() {
        if (this.nameDisabled) {
            return;
        }
        this.showWhoResults = true;
        this.runWhoSearch(this.whoSearch || '');
    }

    handleWhoSearch(event) {
        if (this.nameDisabled) {
            return;
        }
        this.whoSearch = event.target.value;
        this.showWhoResults = true;
        window.clearTimeout(this.whoTimeout);
        this.whoTimeout = window.setTimeout(() => {
            this.runWhoSearch(this.whoSearch);
        }, 200);
    }

    async runWhoSearch(term) {
        if (!this.form.whatId) {
            this.whoResults = [];
            return;
        }
        this.searchingWho = true;
        try {
            const data =
                (await searchWho({
                    searchText: term || '',
                    accountId: this.form.whatId,
                    leadId: this.leadId || null,
                    partnerAccountId: this.effectivePartnerAccountId
                })) || [];
            this.whoResults = this.mapLookupResults(data);
            this.showWhoResults = true;
        } catch (error) {
            this.whoResults = [];
            this.showToast('Error searching Name', this.extractError(error), 'error');
        } finally {
            this.searchingWho = false;
        }
    }

    selectWho(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.label;
        this.whoObjectType = 'Contact';
        this.form = { ...this.form, whoId: id, whoName: name };
        this.whoSearch = '';
        this.whoResults = [];
        this.showWhoResults = false;
        if (this.errors.whoId) {
            this.errors = { ...this.errors, whoId: null };
        }
    }

    clearWho(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.form = { ...this.form, whoId: null, whoName: '' };
        this.whoObjectType = '';
        this.whoSearch = '';
        this.whoResults = [];
        this.showWhoResults = false;
    }

    /* ================= RELATED TO ================= */

    handleWhatFocus() {
        this.showWhatResults = true;
        this.runWhatSearch(this.whatSearch || '');
    }

    handleWhatSearch(event) {
        this.whatSearch = event.target.value;
        this.showWhatResults = true;

        // Clearing Related To also clears Name
        this.form = { ...this.form, whatId: null, whatName: '', whoId: null, whoName: '' };
        this.whoObjectType = '';
        this.whoResults = [];
        this.showWhoResults = false;

        window.clearTimeout(this.whatTimeout);
        this.whatTimeout = window.setTimeout(() => {
            this.runWhatSearch(this.whatSearch);
        }, 200);
    }

    async runWhatSearch(term) {
        this.searchingWhat = true;
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
            this.showToast(
                'Error searching Related To',
                this.extractError(error),
                'error'
            );
        } finally {
            this.searchingWhat = false;
        }
    }

    selectWhat(event) {
        event.preventDefault();
        this.form = {
            ...this.form,
            whatId: event.currentTarget.dataset.id,
            whatName: event.currentTarget.dataset.label,
            whoId: null,
            whoName: ''
        };
        this.whoObjectType = '';
        this.whoSearch = '';
        this.whoResults = [];
        this.whatSearch = '';
        this.whatResults = [];
        this.showWhatResults = false;
        if (this.errors.whatId || this.errors.whoId) {
            this.errors = { ...this.errors, whatId: null, whoId: null };
        }
    }

    clearWhat(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.form = {
            ...this.form,
            whatId: null,
            whatName: '',
            whoId: null,
            whoName: ''
        };
        this.whoObjectType = '';
        this.whatSearch = '';
        this.whatResults = [];
        this.showWhatResults = false;
        this.whoSearch = '';
        this.whoResults = [];
        this.showWhoResults = false;
    }

    get whoIconName() {
        return this.whoObjectType === 'Lead'
            ? 'standard:lead'
            : 'standard:contact';
    }

    get whatIconName() {
        return 'standard:account';
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
    get hasSelectedAssignedTo() {
        return !!this.form.ownerId && !!this.form.ownerName;
    }
    get hasSelectedWho() {
        return !!this.form.whoId && !!this.form.whoName;
    }
    get hasSelectedWhat() {
        return (
            (!!this.form.whatId && !!this.form.whatName) ||
            !!this.quoteId ||
            !!this.relatedAccountId
        );
    }

    validate() {
        const next = {};
        if (!this.form.subject || !this.form.subject.trim()) {
            next.subject = 'Subject is required.';
        }
        if (!this.form.ownerId) {
            next.ownerId = 'Assigned To is required.';
        }
        if (!this.form.startDateTime) {
            next.startDateTime = 'Start is required.';
        }
        if (!this.form.endDateTime) {
            next.endDateTime = 'End is required.';
        }
        if (
            this.form.startDateTime &&
            this.form.endDateTime &&
            new Date(this.form.endDateTime) <= new Date(this.form.startDateTime)
        ) {
            next.endDateTime = 'End must be after Start.';
        }
        if (!this.form.location || !this.form.location.trim()) {
            next.location = 'Location is required.';
        }
        if (!this.form.visitStatus) {
            next.visitStatus = 'Visit Status is required.';
        }
        if (!this.form.visitType) {
            next.visitType = 'Visit Type is required.';
        }
        if (!this.form.description || !this.form.description.trim()) {
            next.description = 'Visit Description is required.';
        } else if (
            !this.isEditMode &&
            this.form.description.trim().length < 100
        ) {
            next.description =
                'Visit Description must be at least 100 characters.';
        }
        if (this.form.visitStatus === 'Completed') {
            if (!this.form.mom || !this.form.mom.trim()) {
                next.mom = 'MOM is required.';
            }
            if (!this.form.nextActionApplicable) {
                next.nextActionApplicable = 'Next Action Applicable is required.';
            }
            if (
                this.form.nextActionApplicable === 'Yes' &&
                (!this.form.nextActionPoints || !this.form.nextActionPoints.trim())
            ) {
                next.nextActionPoints = 'Next Action Points is required.';
            }
            if (
                this.form.nextActionApplicable === 'Yes' &&
                !this.form.nextActionDate
            ) {
                next.nextActionDate = 'Next Action Date is required.';
            }
        }
        if (!this.form.whatId && !this.quoteId && !this.relatedAccountId) {
            next.whatId = 'Related To is required.';
        }
        if (!this.form.whoId) {
            next.whoId = 'Name is required.';
        }
        this.errors = next;
        return Object.keys(next).length === 0;
    }

    async handleSave() {
        // Sync select values from DOM in case LWC didn't keep form in sync
        this.syncFormFromDom();

        if (!this.validate() || this.isSaving) {
            return;
        }

        this.isSaving = true;
        try {
            if (this.isEditMode) {
                const isCompleted = this.form.visitStatus === 'Completed';
                const input = {
                    subject: (this.form.subject || '').trim(),
                    ownerId: this.form.ownerId,
                    startDateTimeIso: this.form.startDateTime || null,
                    endDateTimeIso: this.form.endDateTime || null,
                    location: this.form.location || null,
                    description: this.form.description || null,
                    visitStatus: this.form.visitStatus || null,
                    visitType: this.form.visitType || null,
                    whatId: this.form.whatId || null,
                    whoId: this.form.whoId || null,
                    reminderSet: !!this.form.reminder,
                    reminderMinutes: parseInt(this.form.reminderMinutes, 10) || 15,
                    mom: isCompleted ? this.form.mom || null : null,
                    nextActionPoints:
                        isCompleted && this.form.nextActionApplicable === 'Yes'
                            ? this.form.nextActionPoints || null
                            : null,
                    nextActionApplicable: isCompleted
                        ? this.form.nextActionApplicable || null
                        : null,
                    nextActionDateIso:
                        isCompleted &&
                        this.form.nextActionApplicable === 'Yes' &&
                        this.form.nextActionDate
                            ? this.form.nextActionDate
                            : null
                };
                const updated = await saveActivityDetail({
                    recordId: this.eventId,
                    input
                });
                this.showToast('Success', 'Event updated successfully.', 'success');
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.setTimeout(() => {
                    this.dispatchEvent(
                        new CustomEvent('save', { detail: updated || { id: this.eventId } })
                    );
                    this.dispatchEvent(new CustomEvent('close'));
                }, 1200);
                return;
            }

            // Create: Completed is disabled
            const visitStatus =
                this.form.visitStatus === 'Completed'
                    ? 'Scheduled'
                    : this.form.visitStatus || null;
            const isCompleted = false;
            const payload = {
                subject: (this.form.subject || '').trim(),
                ownerId: this.form.ownerId,
                startDateTime: new Date(this.form.startDateTime).toISOString(),
                endDateTime: new Date(this.form.endDateTime).toISOString(),
                location: this.form.location || null,
                description: this.form.description || null,
                visitStatus,
                visitType: this.form.visitType || null,
                whatId: this.form.whatId || this.quoteId || this.relatedAccountId || null,
                whoId: this.form.whoId || null,
                reminder: !!this.form.reminder,
                reminderMinutes: parseInt(this.form.reminderMinutes, 10) || 15,
                mom: isCompleted ? this.form.mom || null : null,
                nextActionPoints:
                    isCompleted && this.form.nextActionApplicable === 'Yes'
                        ? this.form.nextActionPoints || null
                        : null,
                nextActionApplicable: isCompleted
                    ? this.form.nextActionApplicable || null
                    : null,
                nextActionDate:
                    isCompleted &&
                    this.form.nextActionApplicable === 'Yes' &&
                    this.form.nextActionDate
                        ? this.form.nextActionDate
                        : null
            };

            const summary = await createVisitEvent({ wrapper: payload });

            this.showToast('Success', 'Event created successfully.', 'success');
            // Keep modal open briefly so the portal toast is visible
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            window.setTimeout(() => {
                this.dispatchEvent(new CustomEvent('save', { detail: summary }));
                this.dispatchEvent(new CustomEvent('close'));
            }, 2000);
        } catch (error) {
            this.showToast('Error', this.extractError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    syncFormFromDom() {
        const fields = [
            'subject',
            'visitStatus',
            'visitType',
            'startDateTime',
            'endDateTime',
            'location',
            'reminderMinutes',
            'nextActionApplicable'
        ];
        const updates = {};
        fields.forEach((field) => {
            const el = this.template.querySelector(`[data-field="${field}"]`);
            if (el && typeof el.value === 'string') {
                updates[field] = el.value;
            }
        });
        const reminderEl = this.template.querySelector('[data-field="reminder"]');
        if (reminderEl) {
            updates.reminder = !!reminderEl.checked;
        }
        if (Object.keys(updates).length) {
            this.form = { ...this.form, ...updates };
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleBackdropClick() {
        this.handleClose();
    }

    stopPropagation(event) {
        event.stopPropagation();
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
        return (
            (error && error.body && error.body.message) ||
            (error && error.message) ||
            'An unexpected error occurred.'
        );
    }
}