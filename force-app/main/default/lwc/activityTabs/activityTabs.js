import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord, deleteRecord } from 'lightning/uiRecordApi';

import getUpcomingActivities from '@salesforce/apex/DealerLeadController.getUpcomingActivities';
import getPastActivities from '@salesforce/apex/DealerLeadController.getPastActivities';
import getActivityDetail from '@salesforce/apex/DealerLeadController.getActivityDetail';
import saveActivityDetail from '@salesforce/apex/DealerLeadController.saveActivityDetail';

const TABS = { EVENTS: 'events', TASKS: 'tasks' };

const EVENT_SUBJECT_OPTIONS = [
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

const TASK_SUBJECT_OPTIONS = [
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

const TASK_STATUS_OPTIONS = [
    { label: 'Not Started', value: 'Not Started' },
    { label: 'Open', value: 'Open' },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Completed', value: 'Completed' }
];

const TASK_PRIORITY_OPTIONS = [
    { label: 'High', value: 'High' },
    { label: 'Normal', value: 'Normal' },
    { label: 'Low', value: 'Low' }
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

export default class ActivityTabs extends LightningElement {
    @api recordId;

    activeTab = TABS.EVENTS;
    searchTerm = '';

    @track allUpcoming = [];
    @track allPast = [];
    @track selectedActivity = null;
    @track editForm = {};
    @track editLocks = {};
    @track editErrors = {};

    isLoading = false;
    showEditModal = false;
    isSaving = false;
    showPastEvents = false;
    showPastTasks = false;
    showEventModal = false;
    showTaskModal = false;
    showSubjectDropdown = false;
    /** Open create modal form in edit mode for events */
    showEditEventModal = false;
    editEventId = null;
    showEditTaskModal = false;
    editTaskId = null;

    connectedCallback() {
        this._boundShowList = () => this.handleBack();
        window.addEventListener('portalshowlist', this._boundShowList);
        this.loadActivities();
    }

    disconnectedCallback() {
        if (this._boundShowList) {
            window.removeEventListener('portalshowlist', this._boundShowList);
        }
    }

    async loadActivities() {
        this.isLoading = true;
        try {
            const [upcoming, past] = await Promise.all([
                getUpcomingActivities({ leadId: this.recordId || null }),
                getPastActivities({ leadId: this.recordId || null })
            ]);
            this.allUpcoming = upcoming || [];
            this.allPast = past || [];
            await this.openActivityFromNotification();
        } catch (error) {
            this.showErrorToast('Error loading activities', error);
        } finally {
            this.isLoading = false;
        }
    }

    async openActivityFromNotification() {
        // Only handle portal notification deep-links on the standalone Activity page
        if (this.recordId) {
            return;
        }
        let activityId;
        try {
            activityId = sessionStorage.getItem('portalOpenActivityId');
            if (activityId) {
                sessionStorage.removeItem('portalOpenActivityId');
            }
        } catch (e) {
            return;
        }
        if (!activityId) {
            return;
        }
        try {
            const detail = await getActivityDetail({ recordId: activityId });
            this.exitEditMode();
            this.selectedActivity = detail;
            if (detail && detail.objectType === 'Event') {
                this.activeTab = TABS.EVENTS;
            } else if (detail && detail.objectType === 'Task') {
                this.activeTab = TABS.TASKS;
            }
        } catch (error) {
            this.showErrorToast('Unable to open activity', error);
        }
    }

    exitEditMode() {
        this.showEditModal = false;
        this.showEditEventModal = false;
        this.editEventId = null;
        this.showEditTaskModal = false;
        this.editTaskId = null;
        this.editForm = {};
        this.editLocks = {};
        this.editErrors = {};
        this.isSaving = false;
    }

    /* ================= TAB / SEARCH ================= */

    get isEventsTab() {
        return this.activeTab === TABS.EVENTS;
    }
    get isTasksTab() {
        return this.activeTab === TABS.TASKS;
    }

    get activityExportObjectKey() {
        return this.isEventsTab ? 'Event' : 'Task';
    }

    get eventsTabClass() {
        return this.isEventsTab ? 'pill-tab pill-tab_active' : 'pill-tab';
    }
    get tasksTabClass() {
        return this.isTasksTab ? 'pill-tab pill-tab_active' : 'pill-tab';
    }

    handleTabClick(event) {
        event.preventDefault();
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
    }

    matchesSearch(item) {
        const term = (this.searchTerm || '').trim().toLowerCase();
        if (!term) {
            return true;
        }
        return (item.subject || '').toLowerCase().includes(term);
    }

    /* ================= CREATE MODALS ================= */

    handleCreateVisit() {
        this.showEventModal = true;
    }

    closeEventModal() {
        this.showEventModal = false;
    }

    handleEventSaved() {
        this.showEventModal = false;
        this.loadActivities();
    }

    handleCreateTask() {
        this.showTaskModal = true;
    }

    closeTaskModal() {
        this.showTaskModal = false;
    }

    handleTaskSaved() {
        this.showTaskModal = false;
        this.loadActivities();
    }

    /* ================= IN-APP DETAIL ================= */

    get showDetail() {
        return !!this.selectedActivity;
    }

    get isEventDetail() {
        return this.selectedActivity && this.selectedActivity.objectType === 'Event';
    }

    get isTaskDetail() {
        return this.selectedActivity && this.selectedActivity.objectType === 'Task';
    }

    get isEventEdit() {
        return this.editForm && this.editForm.objectType === 'Event';
    }

    get isTaskEdit() {
        return this.editForm && this.editForm.objectType === 'Task';
    }

    get editModalTitle() {
        if (this.isEventEdit) {
            return 'Edit Event';
        }
        if (this.isTaskEdit) {
            return 'Edit Task';
        }
        return 'Edit';
    }

    get isEditVisitCompleted() {
        return this.editForm && this.editForm.visitStatus === 'Completed';
    }

    get showEditNextActionExtras() {
        return (
            this.isEditVisitCompleted &&
            this.editForm.nextActionApplicable === 'Yes'
        );
    }

    hasFilledValue(value) {
        return value != null && String(value).trim() !== '';
    }

    isFieldLocked(fieldName) {
        // All fields are editable on the Edit modal
        return false;
    }

    inputClass(fieldName) {
        return 'act-edit-control';
    }

    textareaClass(fieldName) {
        return 'act-edit-control act-edit-control--textarea';
    }

    get filteredEditSubjectOptions() {
        const term = (this.editForm.subject || '').toLowerCase().trim();
        if (!term) {
            return EVENT_SUBJECT_OPTIONS;
        }
        return EVENT_SUBJECT_OPTIONS.filter(
            (opt) =>
                (opt.label || '').toLowerCase().includes(term) ||
                (opt.value || '').toLowerCase().includes(term)
        );
    }

    get hasFilteredEditSubjects() {
        return (this.filteredEditSubjectOptions || []).length > 0;
    }

    get customEditSubjectValue() {
        return (this.editForm.subject || '').trim();
    }

    get showUseCustomEditSubject() {
        const val = this.customEditSubjectValue;
        if (!val) {
            return false;
        }
        return !EVENT_SUBJECT_OPTIONS.some(
            (opt) => (opt.value || '').toLowerCase() === val.toLowerCase()
        );
    }

    get showNoEditSubjectMatches() {
        return (
            !this.hasFilteredEditSubjects &&
            !this.showUseCustomEditSubject &&
            !this.customEditSubjectValue
        );
    }

    handleSubjectInput(event) {
        const value = event.target.value;
        this.editForm = { ...this.editForm, subject: value };
        this.showSubjectDropdown = true;
    }

    handleSubjectFocus() {
        this.showSubjectDropdown = true;
    }

    handleSubjectBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            this.showSubjectDropdown = false;
        }, 150);
    }

    selectEditSubject(event) {
        event.preventDefault();
        const value = event.currentTarget.dataset.value || '';
        this.editForm = { ...this.editForm, subject: value };
        this.showSubjectDropdown = false;
    }

    get subjectDisabled() {
        return false;
    }
    get statusDisabled() {
        return false;
    }
    get priorityDisabled() {
        return false;
    }
    get dueDateDisabled() {
        return false;
    }
    get descriptionDisabled() {
        return false;
    }
    get startDisabled() {
        return false;
    }
    get endDisabled() {
        return false;
    }
    get locationDisabled() {
        return false;
    }
    get visitStatusDisabled() {
        return false;
    }
    get visitTypeDisabled() {
        return false;
    }
    get momDisabled() {
        return false;
    }
    get nextActionPointsDisabled() {
        return false;
    }
    get nextActionApplicableDisabled() {
        return false;
    }
    get nextActionDateDisabled() {
        return false;
    }

    get subjectInputClass() {
        return this.inputClass('subject');
    }
    get statusInputClass() {
        return this.inputClass('status');
    }
    get priorityInputClass() {
        return this.inputClass('priority');
    }
    get dueDateInputClass() {
        return this.inputClass('dueDateIso');
    }
    get descriptionInputClass() {
        return this.textareaClass('description');
    }
    get startInputClass() {
        return this.inputClass('startDateTimeIso');
    }
    get endInputClass() {
        return this.inputClass('endDateTimeIso');
    }
    get locationInputClass() {
        return this.inputClass('location');
    }
    get visitStatusInputClass() {
        return 'act-edit-control';
    }
    get visitTypeInputClass() {
        return this.inputClass('visitType');
    }
    get momInputClass() {
        return this.textareaClass('mom');
    }
    get nextActionPointsInputClass() {
        return this.textareaClass('nextActionPoints');
    }
    get nextActionApplicableInputClass() {
        return this.inputClass('nextActionApplicable');
    }
    get nextActionDateInputClass() {
        return this.inputClass('nextActionDateIso');
    }

    mapSelectOptions(options, selectedValue) {
        const val = selectedValue != null ? String(selectedValue) : '';
        const list = [...(options || [])];
        // Keep current record value visible even if it's not in the standard list
        if (val && !list.some((opt) => opt.value === val)) {
            list.unshift({ label: val, value: val });
        }
        return list.map((opt) => ({
            label: opt.label,
            value: opt.value,
            selected: opt.value === val
        }));
    }

    isBlankSelected(value) {
        return !this.hasFilledValue(value);
    }

    get subjectBlankSelected() {
        return this.isBlankSelected(this.editForm.subject);
    }
    get statusBlankSelected() {
        return this.isBlankSelected(this.editForm.status);
    }
    get priorityBlankSelected() {
        return this.isBlankSelected(this.editForm.priority);
    }
    get visitStatusBlankSelected() {
        return this.isBlankSelected(this.editForm.visitStatus);
    }
    get visitTypeBlankSelected() {
        return this.isBlankSelected(this.editForm.visitType);
    }
    get nextActionApplicableBlankSelected() {
        return this.isBlankSelected(this.editForm.nextActionApplicable);
    }

    get eventSubjectSelectOptions() {
        return this.mapSelectOptions(EVENT_SUBJECT_OPTIONS, this.editForm.subject);
    }
    get taskSubjectSelectOptions() {
        return this.mapSelectOptions(TASK_SUBJECT_OPTIONS, this.editForm.subject);
    }
    get taskStatusSelectOptions() {
        return this.mapSelectOptions(TASK_STATUS_OPTIONS, this.editForm.status);
    }
    get taskPrioritySelectOptions() {
        return this.mapSelectOptions(TASK_PRIORITY_OPTIONS, this.editForm.priority);
    }
    get visitStatusSelectOptions() {
        return this.mapSelectOptions(VISIT_STATUS_OPTIONS, this.editForm.visitStatus);
    }
    get visitTypeSelectOptions() {
        return this.mapSelectOptions(VISIT_TYPE_OPTIONS, this.editForm.visitType);
    }
    get nextActionApplicableSelectOptions() {
        return this.mapSelectOptions(
            NEXT_ACTION_APPLICABLE_OPTIONS,
            this.editForm.nextActionApplicable
        );
    }

    beginEditMode() {
        const a = this.selectedActivity || {};
        this.editForm = {
            id: a.id || a.Id || '',
            objectType: a.objectType || '',
            subject: a.subject || '',
            status: a.status || '',
            priority: a.priority || '',
            dueDateIso: a.dueDateIso || '',
            description: a.description || '',
            startDateTimeIso: a.startDateTimeIso || '',
            endDateTimeIso: a.endDateTimeIso || '',
            location: a.location || '',
            visitStatus: a.visitStatus || '',
            visitType: a.visitType || '',
            mom: a.mom || '',
            nextActionPoints:
                a.nextActionPoints === 'N/A' ? '' : a.nextActionPoints || '',
            nextActionApplicable: a.nextActionApplicable || '',
            nextActionDateIso: a.nextActionDateIso || ''
        };
        this.editLocks = {};
        this.editErrors = {};
        this.showSubjectDropdown = false;
        this.showEditModal = true;
    }

    handleEditClick() {
        const a = this.selectedActivity || {};
        const objectType = a.objectType || '';
        const id = a.id || a.Id || null;
        if (objectType === 'Event' && id) {
            // Same New Event UI/fields/layout; Visit Status remains fully editable (incl. Completed)
            this.editEventId = id;
            this.showEditEventModal = true;
            return;
        }
        if (objectType === 'Task' && id) {
            // Same New Task UI/fields/layout; all fields editable
            this.editTaskId = id;
            this.showEditTaskModal = true;
            return;
        }
        this.beginEditMode();
    }

    closeEditEventModal() {
        this.showEditEventModal = false;
        this.editEventId = null;
    }

    closeEditTaskModal() {
        this.showEditTaskModal = false;
        this.editTaskId = null;
    }

    async handleEditEventSaved(event) {
        const id =
            event?.detail?.id ||
            this.editEventId ||
            this.selectedActivity?.id ||
            this.selectedActivity?.Id;
        this.closeEditEventModal();
        this.showSuccessToast('Event updated');
        if (id) {
            try {
                this.selectedActivity = await getActivityDetail({ recordId: id });
            } catch (e) {
                /* list refresh still happens */
            }
        }
        await this.loadActivities();
    }

    async handleEditTaskSaved(event) {
        const id =
            event?.detail?.id ||
            this.editTaskId ||
            this.selectedActivity?.id ||
            this.selectedActivity?.Id;
        this.closeEditTaskModal();
        this.showSuccessToast('Task updated');
        if (id) {
            try {
                this.selectedActivity = await getActivityDetail({ recordId: id });
            } catch (e) {
                /* list refresh still happens */
            }
        }
        await this.loadActivities();
    }

    handleCancelEdit() {
        this.exitEditMode();
    }

    handleEditFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        const value = event.target.value;
        this.editForm = { ...this.editForm, [field]: value };
        if (this.editErrors[field]) {
            const nextErrors = { ...this.editErrors };
            delete nextErrors[field];
            this.editErrors = nextErrors;
        }
        if (field === 'visitStatus' && value !== 'Completed') {
            this.editForm = {
                ...this.editForm,
                mom: '',
                nextActionPoints: '',
                nextActionApplicable: '',
                nextActionDateIso: ''
            };
            this.editErrors = {};
        }
        if (field === 'nextActionApplicable' && value !== 'Yes') {
            this.editForm = {
                ...this.editForm,
                nextActionPoints: '',
                nextActionDateIso: ''
            };
            const nextErrors = { ...this.editErrors };
            delete nextErrors.nextActionPoints;
            delete nextErrors.nextActionDateIso;
            this.editErrors = nextErrors;
        }
    }

    /**
     * When Visit Status is Completed: MOM + Next Action Applicable required.
     * When Applicable is Yes: Next Action Points + Date required as well.
     * Visibility rules unchanged.
     */
    validateEditForm() {
        const next = {};
        if (
            this.editForm.objectType === 'Event' &&
            this.editForm.visitStatus === 'Completed'
        ) {
            if (!this.hasFilledValue(this.editForm.mom)) {
                next.mom = 'MOM is required.';
            }
            if (!this.hasFilledValue(this.editForm.nextActionApplicable)) {
                next.nextActionApplicable = 'Next Action Applicable is required.';
            }
            if (this.editForm.nextActionApplicable === 'Yes') {
                if (!this.hasFilledValue(this.editForm.nextActionPoints)) {
                    next.nextActionPoints = 'Next Action Points is required.';
                }
                if (!this.hasFilledValue(this.editForm.nextActionDateIso)) {
                    next.nextActionDateIso = 'Next Action Date is required.';
                }
            }
        }
        this.editErrors = next;
        return Object.keys(next).length === 0;
    }

    get momError() {
        return this.editErrors.mom || '';
    }
    get nextActionApplicableError() {
        return this.editErrors.nextActionApplicable || '';
    }
    get nextActionPointsError() {
        return this.editErrors.nextActionPoints || '';
    }
    get nextActionDateError() {
        return this.editErrors.nextActionDateIso || '';
    }

    async handleSaveEdit() {
        if (!this.selectedActivity || this.isSaving) {
            return;
        }
        if (!this.validateEditForm()) {
            this.showErrorToast('Unable to save changes', {
                message: 'Please fill all required fields under Status & Description.'
            });
            return;
        }
        const recordId =
            this.editForm?.id ||
            this.selectedActivity?.id ||
            this.selectedActivity?.Id ||
            null;
        if (!recordId) {
            this.showErrorToast(
                'Unable to save changes',
                { message: 'Record Id is missing. Please close and open the record again.' }
            );
            return;
        }
        this.isSaving = true;
        this.isLoading = true;
        try {
            const isEvent =
                this.editForm.objectType === 'Event' ||
                this.selectedActivity.objectType === 'Event';
            const payload = {
                objectType: this.editForm.objectType || this.selectedActivity.objectType,
                subject: this.editForm.subject,
                status: this.editForm.status,
                priority: this.editForm.priority,
                dueDateIso: this.editForm.dueDateIso,
                description: this.editForm.description,
                startDateTimeIso: this.editForm.startDateTimeIso,
                endDateTimeIso: this.editForm.endDateTimeIso,
                location: this.editForm.location,
                visitStatus: this.editForm.visitStatus,
                visitType: this.editForm.visitType,
                mom: this.editForm.mom,
                nextActionPoints: this.editForm.nextActionPoints,
                nextActionApplicable: this.editForm.nextActionApplicable,
                nextActionDateIso: this.editForm.nextActionDateIso
            };
            const updated = await saveActivityDetail({ recordId, input: payload });
            // Prefer full re-fetch so detail cards always show latest DB values
            try {
                this.selectedActivity = await getActivityDetail({ recordId });
            } catch (refreshError) {
                this.selectedActivity = updated;
            }
            this.exitEditMode();
            this.showSuccessToast(isEvent ? 'Event updated' : 'Task updated');
            await this.loadActivities();
        } catch (error) {
            this.showErrorToast('Unable to save changes', error);
        } finally {
            this.isSaving = false;
            this.isLoading = false;
        }
    }

    get detailEyebrow() {
        if (this.isEventDetail) {
            const status = this.selectedActivity.visitStatus || 'Visit';
            return `Event · ${status}`;
        }
        const status = this.selectedActivity?.status || 'Task';
        return `Task · ${status}`;
    }

    get backLabel() {
        return this.isEventDetail ? 'Back to Events' : 'Back to Tasks';
    }

    get detailInitials() {
        const subject = (this.selectedActivity && this.selectedActivity.subject) || '';
        const parts = subject.trim().split(/\s+/).filter(Boolean);
        if (parts.length >= 2) {
            return (parts[0][0] + parts[1][0]).toUpperCase();
        }
        return subject.substring(0, 2).toUpperCase() || (this.isEventDetail ? 'EV' : 'TK');
    }

    displayOrDash(value) {
        return value && String(value).trim() ? value : '—';
    }

    get subjectDisplay() {
        return this.displayOrDash(this.selectedActivity?.subject);
    }
    get assignedToDisplay() {
        return this.displayOrDash(this.selectedActivity?.ownerName);
    }
    get relatedToDisplay() {
        return this.displayOrDash(this.selectedActivity?.whatName);
    }
    get nameDisplay() {
        return this.displayOrDash(this.selectedActivity?.whoName);
    }
    get createdDateDisplay() {
        return this.displayOrDash(this.selectedActivity?.createdDate);
    }
    get startDisplay() {
        return this.displayOrDash(this.selectedActivity?.startDateTime);
    }
    get endDisplay() {
        return this.displayOrDash(this.selectedActivity?.endDateTime);
    }
    get locationDisplay() {
        return this.displayOrDash(this.selectedActivity?.location);
    }
    get visitStatusDisplay() {
        return this.displayOrDash(this.selectedActivity?.visitStatus);
    }
    get visitTypeDisplay() {
        return this.displayOrDash(this.selectedActivity?.visitType);
    }
    get statusDisplay() {
        return this.displayOrDash(this.selectedActivity?.status);
    }
    get priorityDisplay() {
        return this.displayOrDash(this.selectedActivity?.priority);
    }
    get dueDateDisplay() {
        return this.displayOrDash(this.selectedActivity?.dueDate);
    }
    get momDisplay() {
        return this.displayOrDash(this.selectedActivity?.mom);
    }
    get nextActionPointsDisplay() {
        return this.displayOrDash(this.selectedActivity?.nextActionPoints);
    }
    get nextActionApplicableDisplay() {
        return this.displayOrDash(this.selectedActivity?.nextActionApplicable);
    }
    get nextActionDateDisplay() {
        return this.displayOrDash(this.selectedActivity?.nextActionDate);
    }
    get reminderDateTimeDisplay() {
        return this.displayOrDash(this.selectedActivity?.reminderDateTime);
    }
    get hasReminderDateTime() {
        return !!(
            this.selectedActivity &&
            this.selectedActivity.reminderSet &&
            this.selectedActivity.reminderDateTime
        );
    }

    get reminderLabel() {
        if (!this.selectedActivity) {
            return '—';
        }
        return this.selectedActivity.reminderSet ? 'Yes' : 'No reminder is set';
    }

    get descriptionDisplay() {
        return this.displayOrDash(this.selectedActivity?.description);
    }

    async handleRecordClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (!recordId) {
            return;
        }
        this.isLoading = true;
        try {
            const detail = await getActivityDetail({ recordId });
            this.exitEditMode();
            this.selectedActivity = detail;
            if (detail && detail.objectType === 'Event') {
                this.activeTab = TABS.EVENTS;
            } else if (detail && detail.objectType === 'Task') {
                this.activeTab = TABS.TASKS;
            }
        } catch (error) {
            this.showErrorToast('Unable to open activity', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleBack() {
        this.exitEditMode();
        this.selectedActivity = null;
    }

    stopRowClick(event) {
        event.stopPropagation();
    }

    /* ================= FILTERING ================= */

    get upcomingEvents() {
        return this.allUpcoming
            .filter((a) => a.type === 'Event')
            .filter((a) => this.matchesSearch(a));
    }
    get pastEvents() {
        return this.allPast
            .filter((a) => a.type === 'Event')
            .filter((a) => this.matchesSearch(a));
    }
    get upcomingTasks() {
        return this.allUpcoming
            .filter((a) => a.type !== 'Event')
            .filter((a) => this.matchesSearch(a));
    }
    get pastTasks() {
        return this.allPast
            .filter((a) => a.type !== 'Event')
            .filter((a) => this.matchesSearch(a));
    }

    get hasUpcomingEvents() {
        return this.upcomingEvents.length > 0;
    }
    get hasPastEvents() {
        return this.pastEvents.length > 0;
    }
    get hasUpcomingTasks() {
        return this.upcomingTasks.length > 0;
    }
    get hasPastTasks() {
        return this.pastTasks.length > 0;
    }

    get pastEventsToggleLabel() {
        return this.showPastEvents
            ? 'Hide Past Events'
            : `Show Past Events (${this.pastEvents.length})`;
    }
    get pastTasksToggleLabel() {
        return this.showPastTasks
            ? 'Hide Past Tasks'
            : `Show Past Tasks (${this.pastTasks.length})`;
    }

    togglePastEvents() {
        this.showPastEvents = !this.showPastEvents;
    }
    togglePastTasks() {
        this.showPastTasks = !this.showPastTasks;
    }

    /* ================= COMPLETE / DELETE ================= */

    async handleCompleteTask(event) {
        event.stopPropagation();
        const taskId = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await updateRecord({ fields: { Id: taskId, Status: 'Completed' } });
            this.showSuccessToast('Task marked complete');
            await this.loadActivities();
        } catch (error) {
            this.showErrorToast('Error updating task', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDelete(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.isLoading = true;
        try {
            await deleteRecord(id);
            this.showSuccessToast('Activity deleted');
            if (this.selectedActivity && this.selectedActivity.id === id) {
                this.exitEditMode();
                this.selectedActivity = null;
            }
            await this.loadActivities();
        } catch (error) {
            this.showErrorToast('Error deleting activity', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadActivities();
    }

    showSuccessToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({ title: 'Success', message, variant: 'success' })
        );
    }

    showErrorToast(title, error) {
        const message =
            (error && error.body && error.body.message) ||
            (error && error.message) ||
            'An unknown error occurred.';
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant: 'error' })
        );
    }
}