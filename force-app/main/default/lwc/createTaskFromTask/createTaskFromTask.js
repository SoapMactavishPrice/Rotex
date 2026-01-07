import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getTaskDetails from '@salesforce/apex/TaskController.getTaskDetails';
import createTask from '@salesforce/apex/TaskController.createTask';
import getRelatedToObjects from '@salesforce/apex/TaskController.getRelatedToObjects';
import getObjectInfoFromId from '@salesforce/apex/TaskController.getObjectInfoFromId';

export default class CreateTaskFromTask extends NavigationMixin(LightningElement) {
    @api recordId;

    @track subject = '';
    @track priority = '';
    @track status = 'Open';
    @track dueDate = '';
    @track ownerId = '';
    @track nameType = '';
    @track whoId = '';
    @track whatId = '';
    @track relatedToType = '';
    @track relatedToLabel = '';
    @track disableRelatedTo = false;
    @track description = '';

    @track isLoading = false;
    @track errorMessage = '';
    @track minDate = '';
    @track relatedToOptions = [];
    @track relatedToObjectsMap = new Map();

    priorityOptions = [
        { label: 'High', value: 'High' },
        { label: 'Normal', value: 'Normal' }
    ];

    statusOptions = [
        { label: 'Open', value: 'Open' },
        { label: 'Completed', value: 'Completed' }
    ];

    nameTypeOptions = [
        { label: 'Contact', value: 'Contact' },
        { label: 'Lead', value: 'Lead' }
    ];

    get whoObjectApiName() {
        return this.nameType || 'Contact';
    }

    get nameLabel() {
        return this.nameType === 'Lead' ? 'Lead' : 'Contact';
    }

    get isLead() {
        return this.nameType === 'Lead';
    }

    get isContact() {
        return this.nameType === 'Contact';
    }

    get relatedToObjectApiName() {
        return this.relatedToType;
    }

    get relatedToRecordLabel() {
        return this.relatedToLabel ? `Select ${this.relatedToLabel}` : 'Select Record';
    }

    connectedCallback() {
        this.minDate = new Date().toISOString().split('T')[0];
        this.loadRelatedToObjects();
    }

    loadRelatedToObjects() {
        this.isLoading = true;
        
        getRelatedToObjects()
            .then(result => {
                this.relatedToOptions = result.map(obj => {
                    this.relatedToObjectsMap.set(obj.apiName, obj.label);
                    return {
                        label: obj.label,
                        value: obj.apiName
                    };
                });
                
                this.loadTaskDetails();
            })
            .catch(error => {
                this.errorMessage = error.body?.message || 'Error loading related objects';
                this.showToast('Error', this.errorMessage, 'error');
                this.isLoading = false;
            });
    }

    loadTaskDetails() {
        getTaskDetails({ taskId: this.recordId })
            .then(result => {
                this.subject = result.Subject || '';
                this.priority = result.Priority || '';
                this.ownerId = result.OwnerId || '';
                this.whoId = result.WhoId || '';
                this.whatId = result.WhatId || '';
                // this.description = result.Description || '';
                this.status = 'Open';

                this.determineNameType(result.WhoId);
                
                if (result.WhatId) {
                    this.determineRelatedToType(result.WhatId);
                } else {
                    this.isLoading = false;
                }
            })
            .catch(error => {
                this.errorMessage = error.body?.message || 'Error loading task details';
                this.showToast('Error', this.errorMessage, 'error');
                this.isLoading = false;
            });
    }

    determineNameType(whoId) {
        if (!whoId) {
            this.nameType = '';
            return;
        }

        const prefix = whoId.substring(0, 3);
        if (prefix === '003') {
            this.nameType = 'Contact';
        } else if (prefix === '00Q') {
            this.nameType = 'Lead';
        }
    }

    determineRelatedToType(whatId) {
        getObjectInfoFromId({ recordId: whatId })
            .then(result => {
                if (result) {
                    this.relatedToType = result.apiName;
                    this.relatedToLabel = result.label;
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error determining Related To type:', error);
                this.isLoading = false;
            });
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
        this.errorMessage = '';
    }

    handlePriorityChange(event) {
        this.priority = event.detail.value;
        this.errorMessage = '';
    }

    handleStatusChange(event) {
        this.status = event.detail.value;
        this.errorMessage = '';
    }

    handleDueDateChange(event) {
        this.dueDate = event.target.value;
        this.errorMessage = '';
    }

    handleOwnerChange(event) {
        this.ownerId = event.detail.recordId;
    }

    handleNameTypeChange(event) {
        this.nameType = event.detail.value;
        if (this.nameType == 'Lead') {
            this.disableRelatedTo = true;
            this.whatId = null;
            this.relatedToType = null;
            this.whoId = null;
        }
        else if (this.nameType == 'Contact') {
            this.disableRelatedTo = false;
        }
        this.whoId = null;
        this.errorMessage = null;
    }

    handleWhoIdChange(event) {
        this.whoId = event.detail.recordId;
    }

    handleRelatedToTypeChange(event) {
        this.relatedToType = event.detail.value;
        this.relatedToLabel = this.relatedToObjectsMap.get(this.relatedToType) || '';
        this.whatId = '';
        this.errorMessage = '';
    }

    handleWhatIdChange(event) {
        this.whatId = event.detail.recordId;
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
        this.errorMessage = '';
    }

    handleCancel() {
        this.resetState();
        this.navigateToTask(this.recordId);
    }

    resetState() {
        this.subject = '';
        this.priority = '';
        this.status = 'Open';
        this.dueDate = '';
        this.ownerId = '';
        this.nameType = '';
        this.whoId = '';
        this.whatId = '';
        this.relatedToType = '';
        this.relatedToLabel = '';
        this.disableRelatedTo = false;
        this.description = '';
        this.errorMessage = '';
        this.isLoading = false;
    }


    handleSave() {
        if (!this.validateForm()) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        const newTask = {
            Subject: this.subject,
            Priority: this.priority,
            Status: this.status,
            ActivityDate: this.dueDate || null,
            OwnerId: this.ownerId,
            WhoId: this.whoId || null,
            WhatId: this.whatId || null,
            Description: this.description || null
        };

        createTask({ newTask: newTask, parentTaskId: this.recordId })
            .then(taskId => {
                this.showToast('Success', 'Task created successfully', 'success');
                this.navigateToTask(taskId);
                this.closeQuickAction();
            })
            .catch(error => {
                this.errorMessage = error.body?.message || 'Error creating task';
                this.showToast('Error', this.errorMessage, 'error');
                this.isLoading = false;
            });
    }

    validateForm() {
        this.errorMessage = '';

        if (!this.subject || this.subject.trim() === '') {
            this.errorMessage = 'Subject is required';
            return false;
        }

        if (!this.priority) {
            this.errorMessage = 'Priority is required';
            return false;
        }

        if (!this.status) {
            this.errorMessage = 'Status is required';
            return false;
        }

        if (!this.dueDate) {
            this.errorMessage = 'Due Date is required'
            return false;
        }

        if (this.dueDate) {
            const selectedDate = new Date(this.dueDate);
            const today = new Date();
            today.setHours(0, 0, 0, 0);

            if (selectedDate < today) {
                this.errorMessage = 'Due Date must be today or in the future';
                return false;
            }
        }

        return true;
    }

    navigateToTask(taskId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: taskId,
                objectApiName: 'Task',
                actionName: 'view'
            }
        });
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}