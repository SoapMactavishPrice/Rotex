import { LightningElement, track, wire } from 'lwc';

import USER_ID from '@salesforce/user/Id';

import { getRecord }
from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';

import convertLeadFull
from '@salesforce/apex/DealerLeadController.convertLeadFull';
import searchAccounts
from '@salesforce/apex/DealerLeadController.searchAccounts';
import searchContacts
from '@salesforce/apex/DealerLeadController.searchContacts';
import getContactsForAccount
from '@salesforce/apex/DealerLeadController.getContactsForAccount';
import searchOpportunities
from '@salesforce/apex/DealerLeadController.searchOpportunities';
import getOpportunitiesForAccount
from '@salesforce/apex/DealerLeadController.getOpportunitiesForAccount';
import NAME_FIELD
from '@salesforce/schema/User.Name';
import updateLeadStatus
from '@salesforce/apex/DealerLeadController.updateLeadStatus';
import saveLeadContactedInfo
from '@salesforce/apex/DealerLeadController.saveLeadContactedInfo';
import getLeadContactedInfo
from '@salesforce/apex/DealerLeadController.getLeadContactedInfo';
import saveLeadRegret
from '@salesforce/apex/DealerLeadController.saveLeadRegret';
import getRegretReasonOptions
from '@salesforce/apex/DealerLeadController.getRegretReasonOptions';

import getLeadsByDealerAccount
from '@salesforce/apex/DealerLeadController.getLeadsByDealerAccount';

import getUpcomingActivities
from '@salesforce/apex/DealerLeadController.getUpcomingActivities';

import getLeadNotes
from '@salesforce/apex/DealerLeadController.getLeadNotes';

import getLeadFiles
from '@salesforce/apex/DealerLeadController.getLeadFiles';

import addLeadNoteApex
from '@salesforce/apex/DealerLeadController.addLeadNote';

import createTask
from '@salesforce/apex/DealerLeadController.createTask';

import saveLeadAttachment
from '@salesforce/apex/DealerLeadController.saveLeadAttachment';

const PORTAL_TOAST_DURATION_MS = 4000;

export default class DealerAssignedLeads
extends LightningElement {

    @track leads = [];
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';

    portalToastTimeout;
    @track filteredLeads = [];

    @track selectedLead;

    @track currentUserName = '';

    @track userInitials = '';

    @track upcomingActivities = [];

    @track leadNotes = [];
    @track showTaskModal = false;
    @track showLeadModal = false;
    @track leadModalEditRecord = null;
    @track leadFiles = [];

    @track previewFile = null;

    currentTime;

    searchKey = '';
    selectedStatus = 'All';
    wiredLeadResult;


    noteText = '';

    /* =========================
       NEW EVENT MODAL STATE
    ========================== */

    @track showEventModal = false;

    /* =========================
       CONTACTED PATH MODAL
    ========================== */
    @track showContactedModal = false;
    @track isSavingContacted = false;
    @track contactedInfoData = null;
    contactedForm = {
        contactPersonName: '',
        designation: '',
        emailId: '',
        mom: ''
    };
    @track contactedErrors = {};

    /* =========================
       REGRET PATH MODAL
    ========================== */
    @track showRegretModal = false;
    @track isSavingRegret = false;
    @track regretReasonOptions = [];
    regretForm = {
        regretReason: '',
        otherRegretReason: ''
    };
    @track regretErrors = {};

    /* =========================
       CONVERT LEAD MODAL STATE
    ========================== */

    @track showConvertModal = false;
    @track isConverting = false;

    accountOption = 'new';          // 'new' | 'existing'
    newAccountName = '';
    accountSearchTerm = '';
    @track accountSearchResults = [];
    accountSearchPerformed = false; // whether an existing-account search has actually run (drives the "X Account Matches" label)
    selectedAccountId = null;
    selectedAccountName = '';
    accountSearchTimeout;

    contactOption = 'new';          // 'new' | 'existing'
    contactSalutation = '';
    contactFirstName = '';
    contactMiddleName = '';
    contactLastName = '';
    contactDesignation = '';
    contactSearchTerm = '';
    @track contactSearchResults = [];
    selectedContactId = null;
    selectedContactName = '';
    contactSearchTimeout;

    opportunityOption = 'create';   // 'create' | 'existing'
    doNotCreateOpportunity = false; // checkbox override, matches standard Convert Lead screen
    opportunityName = '';
    opportunityCloseDate = '';
    opportunitySearchTerm = '';
    @track opportunitySearchResults = [];
    selectedOpportunityId = null;
    selectedOpportunityName = '';
    opportunitySearchTimeout;


    /* =========================
       USER
    ========================== */

    @wire(getRecord, {
        recordId: USER_ID,
        fields: [NAME_FIELD]
    })
    wiredUser({ data }) {

        if (data) {

            this.currentUserName =
                data.fields.Name.value;

            this.userInitials =
                this.currentUserName
                .split(' ')
                .map(word => word[0])
                .join('')
                .substring(0, 2)
                .toUpperCase();
        }
    }

    /* =========================
       TIME
    ========================== */

    connectedCallback() {
        this._boundShowList = () => this.backToList();
        window.addEventListener('portalshowlist', this._boundShowList);

        this.updateTime();

        setInterval(() => {

            this.updateTime();

        }, 1000);
    }

    disconnectedCallback() {
        if (this._boundShowList) {
            window.removeEventListener('portalshowlist', this._boundShowList);
        }
    }

    updateTime() {

        this.currentTime =
            new Date().toLocaleTimeString(
                'en-IN',
                {
                    hour: '2-digit',
                    minute: '2-digit'
                }
            ) + ' IST';
    }

    /* =========================
       LEADS
    ========================== */

 @wire(getLeadsByDealerAccount)
wiredLeads(result) {

    this.wiredLeadResult = result;

    const { data, error } = result;

        if (data) {

            this.leads = data.map((item, index) => {

                return {

                    ...item,
                    Status: item.Dealer_Status__c || item.Status,
                    Dealer_Status__c: item.Dealer_Status__c || item.Status,
                    statusClass:
                        this.getStatusClass(
                            item.Dealer_Status__c || item.Status
                        ),

                    createdDate:
                        new Date(
                            item.CreatedDate
                        ).toLocaleDateString(
                            'en-IN',
                            {
                                day: '2-digit',
                                month: 'short'
                            }
                        ),

                    ownerInitials:
                        item.Owner?.Name
                            ? item.Owner.Name
                                .split(' ')
                                .map(word => word[0])
                                .join('')
                                .substring(0, 2)
                                .toUpperCase()
                            : 'NA'
                };
            });

           this.applyFilters();
           this.openPendingLeadFromNotification();
        }

        else if (error) {

            console.error(error);
        }
    }

    /* =========================
       STATUS CLASS
    ========================== */

   getStatusClass(status) {

    let statusClass =
        'status-badge';

    if (status === 'New') {

        statusClass += ' new';
    }

    else if (
        status === 'Qualified'
    ) {

        statusClass += ' qualified';
    }

    else if (
        status === 'Regret'
    ) {

        statusClass += ' disqualified';
    }

    else {

        statusClass += ' progress';
    }

    return statusClass;
}
    /* =========================
       SEARCH
    ========================== */

   handleSearch(event) {

    this.searchKey =
        event.target.value
        .toLowerCase();

    this.applyFilters();
}
handleStatusFilter(event) {

    this.selectedStatus =
        event.currentTarget.dataset.status;

    this.applyFilters();
}
applyFilters() {

    this.filteredLeads =
        this.leads.filter(item => {

            const matchesSearch =

                (item.Name || '')
                .toLowerCase()
                .includes(this.searchKey)

                ||

                (item.Company || '')
                .toLowerCase()
                .includes(this.searchKey)

                ||

                (item.Title || '')
                .toLowerCase()
                .includes(this.searchKey)

                ||

                (item.City || '')
                .toLowerCase()
                .includes(this.searchKey);

            const matchesStatus =

                this.selectedStatus === 'All'
                ||

                item.Status === this.selectedStatus;

            return (
                matchesSearch &&
                matchesStatus
            );
        });
}
get allTabClass() {

    return this.selectedStatus === 'All'
        ? 'tab active'
        : 'tab';
}

get newTabClass() {

    return this.selectedStatus === 'New'
        ? 'tab active'
        : 'tab';
}

get progressTabClass() {

    return this.selectedStatus === 'Work In Progress'
        ? 'tab active'
        : 'tab';
}
get qualifiedTabClass() {

    return this.selectedStatus === 'Qualified'
        ? 'tab active'
        : 'tab';
}

get disqualifiedTabClass() {

    return this.selectedStatus === 'Regret'
        ? 'tab active'
        : 'tab';
}
    /* =========================
       OPEN DETAIL
    ========================== */

    async openLeadDetail(event) {
        const leadId = event.currentTarget.dataset.id;
        if (!leadId) {
            return;
        }
        await this.openLeadDetailById(leadId);
    }

    openPendingLeadFromNotification() {
        let leadId = null;
        try {
            leadId = sessionStorage.getItem('portalOpenLeadId');
            if (leadId) {
                sessionStorage.removeItem('portalOpenLeadId');
            }
        } catch (e) {
            leadId = null;
        }
        if (!leadId) {
            return;
        }
        this.openLeadDetailById(leadId);
    }

    async openLeadDetailById(leadId) {
        if (!leadId) {
            return;
        }

        // Always refresh from CRM so portal shows latest lead updates
        if (this.wiredLeadResult) {
            await refreshApex(this.wiredLeadResult);
        }

        this.selectedLead = this.leads.find((item) => item.Id === leadId) || null;
        if (!this.selectedLead) {
            return;
        }

        // reset sidebar data before loading fresh data for this lead
        this.upcomingActivities = [];
        this.leadNotes = [];
        this.leadFiles = [];
        this.previewFile = null;
        this.contactedInfoData = null;

        this.loadUpcomingActivities(leadId);
        this.loadLeadNotes(leadId);
        this.loadLeadFiles(leadId);
        this.loadLeadContactedInfo(leadId);
    }

    async backToList() {
        this.selectedLead = null;
        if (this.wiredLeadResult) {
            await refreshApex(this.wiredLeadResult);
        }
    }

    /* =========================
       STATUS DROPDOWN
    ========================== */
get statusPathItems() {

    const order = [
        'New',
        'Contacted',
        'Work In Progress',
        'Future Prospect',
        'Qualified',
        'Regret'
    ];

    const currentStatus =
        this.selectedLead
            ? this.selectedLead.Status
            : null;

    const currentIndex =
        order.indexOf(currentStatus);

    return order.map((status, index) => {

        let itemClass = 'path-item';

        if (status === 'Regret') {
            itemClass += ' regret';
        }

        if (status === currentStatus) {
            itemClass += ' current';
        }
        else if (currentIndex !== -1 && index < currentIndex) {
            itemClass += ' complete';
        }
        else {
            itemClass += ' future';
        }

        return {
            value: status,
            label: status,
            itemClass: itemClass,
            isComplete: currentIndex !== -1 && index < currentIndex
        };
    });
}

updateStatus(event) {

    const newStatus =
        event.currentTarget.dataset.status;

    if (newStatus === 'Contacted') {
        this.openContactedModal();
        return;
    }

    if (newStatus === 'Regret') {
        this.openRegretModal();
        return;
    }

    updateLeadStatus({
        leadId: this.selectedLead.Id,
        newStatus: newStatus
    })
    .then(() => {
        const updatedLead = {
            ...this.selectedLead,
            Status: newStatus,
            Dealer_Status__c: newStatus,
            statusClass: this.getStatusClass(newStatus)
        };
        this.selectedLead = updatedLead;
        this.leads = this.leads.map(item => {
            if (item.Id === updatedLead.Id) {
                return updatedLead;
            }
            return item;
        });
        this.applyFilters();
    })
    .catch(error => {
        console.error(error);
        this.showToast(
            'Error',
            error?.body?.message || error?.message || 'Unable to update status.',
            'error'
        );
    });
}

    openContactedModal() {
        if (!this.selectedLead) {
            return;
        }
        const saved = this.contactedInfoData || {};
        this.contactedForm = {
            contactPersonName: saved.contactPersonName || '',
            designation: saved.designation || '',
            emailId: saved.emailId || this.selectedLead.Email || '',
            mom: saved.mom || ''
        };
        this.contactedErrors = {};
        this.isSavingContacted = false;
        this.showContactedModal = true;
    }

    closeContactedModal() {
        this.showContactedModal = false;
        this.isSavingContacted = false;
        this.contactedErrors = {};
    }

    handleContactedInput(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.target.value;
        this.contactedForm = {
            ...this.contactedForm,
            [field]: value
        };
        if (this.contactedErrors[field]) {
            const next = { ...this.contactedErrors };
            delete next[field];
            this.contactedErrors = next;
        }
    }

    validateContactedForm() {
        const e = {};
        const f = this.contactedForm || {};
        if (!f.contactPersonName?.trim()) {
            e.contactPersonName = 'Contact Person Name is required.';
        }
        if (!f.designation?.trim()) {
            e.designation = 'Designation is required.';
        }
        if (!f.emailId?.trim()) {
            e.emailId = 'Email ID is required.';
        } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.emailId.trim())) {
            e.emailId = 'Enter a valid email address.';
        }
        if (!f.mom?.trim()) {
            e.mom = 'MOM is required.';
        }
        this.contactedErrors = e;
        return Object.keys(e).length === 0;
    }

    async handleSaveContacted() {
        if (!this.selectedLead || !this.validateContactedForm()) {
            return;
        }
        this.isSavingContacted = true;
        try {
            const result = await saveLeadContactedInfo({
                input: {
                    leadId: this.selectedLead.Id,
                    contactPersonName: this.contactedForm.contactPersonName.trim(),
                    designation: this.contactedForm.designation.trim(),
                    emailId: this.contactedForm.emailId.trim(),
                    mom: this.contactedForm.mom.trim()
                }
            });

            this.contactedInfoData = {
                contactPersonName: result.contactPersonName,
                designation: result.designation,
                emailId: result.emailId,
                mom: result.mom || ''
            };

            const updatedLead = {
                ...this.selectedLead,
                Status: result.status || 'Contacted',
                Dealer_Status__c: result.status || 'Contacted',
                statusClass: this.getStatusClass(result.status || 'Contacted')
            };
            this.selectedLead = updatedLead;
            this.leads = this.leads.map(item =>
                item.Id === updatedLead.Id ? updatedLead : item
            );
            this.applyFilters();
            this.showContactedModal = false;
            this.showToast('Success', 'Contacted details saved for this lead.', 'success');
        } catch (error) {
            this.showToast(
                'Error',
                error?.body?.message || error?.message || 'Unable to save contacted details.',
                'error'
            );
        } finally {
            this.isSavingContacted = false;
        }
    }

    loadLeadContactedInfo(leadId) {
        if (!leadId) {
            this.contactedInfoData = null;
            return;
        }
        getLeadContactedInfo({ leadId })
            .then((result) => {
                if (
                    result &&
                    (result.contactPersonName ||
                        result.designation ||
                        result.emailId ||
                        result.mom)
                ) {
                    this.contactedInfoData = {
                        contactPersonName: result.contactPersonName || '',
                        designation: result.designation || '',
                        emailId: result.emailId || '',
                        mom: result.mom || ''
                    };
                } else {
                    this.contactedInfoData = null;
                }
            })
            .catch(() => {
                this.contactedInfoData = null;
            });
    }

    get hasContactedInfo() {
        const d = this.contactedInfoData;
        if (!d) return false;
        return !!(
            d.contactPersonName ||
            d.designation ||
            d.emailId ||
            d.mom
        );
    }

    get contactedInfo() {
        const d = this.contactedInfoData || {};
        return {
            contactPersonName: d.contactPersonName || '—',
            designation: d.designation || '—',
            emailId: d.emailId || '—',
            mom: d.mom || '—'
        };
    }

    get contactedSaveLabel() {
        return this.isSavingContacted ? 'Saving…' : 'Save';
    }

    /* =========================
       REGRET PATH MODAL
    ========================== */

    openRegretModal() {
        if (!this.selectedLead) {
            return;
        }
        this.regretForm = {
            regretReason: this.selectedLead.Regret_Reason1__c || '',
            otherRegretReason: this.selectedLead.Regret_Reason__c || ''
        };
        this.regretErrors = {};
        this.isSavingRegret = false;
        this.showRegretModal = true;
        this.loadRegretReasonOptions();
    }

    closeRegretModal() {
        this.showRegretModal = false;
        this.isSavingRegret = false;
        this.regretErrors = {};
    }

    loadRegretReasonOptions() {
        if (this.regretReasonOptions && this.regretReasonOptions.length) {
            return;
        }
        getRegretReasonOptions()
            .then((opts) => {
                this.regretReasonOptions = (opts || []).map((o) => ({
                    label: o.label,
                    value: o.value
                }));
            })
            .catch(() => {
                this.regretReasonOptions = [
                    { label: 'Lost to Competitor', value: 'Lost to Competitor' },
                    { label: 'Price', value: 'Price' },
                    { label: 'Duplicate', value: 'Duplicate' },
                    { label: 'Other', value: 'Other' }
                ];
            });
    }

    get showOtherRegretReason() {
        return (this.regretForm?.regretReason || '') === 'Other';
    }

    get regretReasonSelectOptions() {
        const opts = this.regretReasonOptions || [];
        return [
            { label: '-- Select Regret Reason --', value: '' },
            ...opts.map((o) => ({
                label: o.label,
                value: o.value
            }))
        ];
    }

    handleRegretInput(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.target.value;
        this.regretForm = {
            ...this.regretForm,
            [field]: value
        };
        if (field === 'regretReason' && value !== 'Other') {
            this.regretForm = {
                ...this.regretForm,
                otherRegretReason: ''
            };
        }
        if (this.regretErrors[field]) {
            const next = { ...this.regretErrors };
            delete next[field];
            if (field === 'regretReason') {
                delete next.otherRegretReason;
            }
            this.regretErrors = next;
        }
    }

    validateRegretForm() {
        const e = {};
        const f = this.regretForm || {};
        if (!f.regretReason?.trim()) {
            e.regretReason = 'Regret Reason is required.';
        }
        if (f.regretReason === 'Other' && !f.otherRegretReason?.trim()) {
            e.otherRegretReason = 'Other Regret Reason is required.';
        }
        this.regretErrors = e;
        return Object.keys(e).length === 0;
    }

    async handleSaveRegret() {
        if (!this.selectedLead || !this.validateRegretForm()) {
            return;
        }
        this.isSavingRegret = true;
        try {
            const result = await saveLeadRegret({
                input: {
                    leadId: this.selectedLead.Id,
                    regretReason: this.regretForm.regretReason.trim(),
                    otherRegretReason:
                        this.regretForm.regretReason === 'Other'
                            ? (this.regretForm.otherRegretReason || '').trim()
                            : null
                }
            });

            const updatedLead = {
                ...this.selectedLead,
                Status: result.status || 'Regret',
                Dealer_Status__c: result.status || 'Regret',
                statusClass: this.getStatusClass(result.status || 'Regret'),
                Regret_Reason1__c: result.regretReason || '',
                Regret_Reason__c: result.otherRegretReason || ''
            };
            this.selectedLead = updatedLead;
            this.leads = this.leads.map((item) =>
                item.Id === updatedLead.Id ? updatedLead : item
            );
            this.applyFilters();
            this.showRegretModal = false;
            this.showToast('Success', 'Lead marked as Regret.', 'success');
        } catch (error) {
            this.showToast(
                'Error',
                error?.body?.message || error?.message || 'Unable to save regret details.',
                'error'
            );
        } finally {
            this.isSavingRegret = false;
        }
    }

    get showRegretFieldsInLeadInfo() {
        return this.selectedLead && this.selectedLead.Status === 'Regret';
    }

    get showConvertLeadButton() {
        return this.selectedLead && this.selectedLead.Status === 'Qualified';
    }

    get hasRegretInfo() {
        return this.showRegretFieldsInLeadInfo;
    }

    get regretInfo() {
        const lead = this.selectedLead || {};
        return {
            regretReason: lead.Regret_Reason1__c || '—',
            otherRegretReason: lead.Regret_Reason__c || '—',
            showOther: (lead.Regret_Reason1__c || '') === 'Other' && !!lead.Regret_Reason__c
        };
    }

    get regretSaveLabel() {
        return this.isSavingRegret ? 'Saving…' : 'Save';
    }

    /* =========================
       CONVERT LEAD (custom modal
       replicating the standard
       Salesforce Convert screen)
    ========================== */

    handleConvertLead() {

        if (!this.selectedLead) {
            return;
        }

        // Reset + prime defaults from the selected Lead every time it opens
        this.accountOption = 'new';
        this.newAccountName = this.selectedLead.Company || '';
        this.accountSearchTerm = '';
        this.accountSearchResults = [];
        this.accountSearchPerformed = false;
        this.selectedAccountId = null;
        this.selectedAccountName = '';

        this.contactOption = 'new';

        // Prefer the Lead's own name fields; fall back to splitting Name
        // if they weren't queried for some reason.
        if (this.selectedLead.FirstName || this.selectedLead.LastName) {
            this.contactSalutation = this.selectedLead.Salutation || '';
            this.contactFirstName = this.selectedLead.FirstName || '';
            this.contactMiddleName = this.selectedLead.MiddleName || '';
            this.contactLastName = this.selectedLead.LastName || '';
            this.contactDesignation = this.selectedLead.Title || '';
        } else {
            const nameParts = (this.selectedLead.Name || '').trim().split(' ');
            this.contactSalutation = '';
            this.contactFirstName = nameParts.length > 1 ? nameParts.slice(0, -1).join(' ') : '';
            this.contactMiddleName = '';
            this.contactLastName = nameParts.length > 0 ? nameParts[nameParts.length - 1] : '';
            this.contactDesignation = this.selectedLead.Title || '';
        }

        this.contactSearchTerm = '';
        this.contactSearchResults = [];
        this.selectedContactId = null;
        this.selectedContactName = '';

        this.opportunityOption = 'create';
        this.doNotCreateOpportunity = false;
        this.opportunitySearchTerm = '';
        this.opportunitySearchResults = [];
        this.selectedOpportunityId = null;
        this.selectedOpportunityName = '';

        this.setDefaultOpportunityName();

        const defaultClose = new Date(Date.now() + (30 * 24 * 60 * 60 * 1000));
        this.opportunityCloseDate = defaultClose.toISOString().slice(0, 10);

        this.showConvertModal = true;
    }

    closeConvertModal() {

        if (this.isConverting) {
            return;
        }

        this.showConvertModal = false;
    }

    get isNewAccount() {
        return this.accountOption === 'new';
    }

    get isExistingAccount() {
        return this.accountOption === 'existing';
    }

    get accountNewPaneClass() {
        return this.isNewAccount
            ? 'convert-pane convert-pane-left is-active'
            : 'convert-pane convert-pane-left is-inactive';
    }

    get accountExistingPaneClass() {
        return this.isExistingAccount
            ? 'convert-pane convert-pane-right is-active'
            : 'convert-pane convert-pane-right is-inactive';
    }

    get contactNewPaneClass() {
        return this.isNewContact
            ? 'convert-pane convert-pane-left is-active'
            : 'convert-pane convert-pane-left is-inactive';
    }

    get contactExistingPaneClass() {
        return this.isExistingContact
            ? 'convert-pane convert-pane-right is-active'
            : 'convert-pane convert-pane-right is-inactive';
    }

    get opportunityCreatePaneClass() {
        return this.createOpportunity
            ? 'convert-pane convert-pane-left is-active'
            : 'convert-pane convert-pane-left is-inactive';
    }

    get opportunityExistingPaneClass() {
        return this.existingOpportunity
            ? 'convert-pane convert-pane-right is-active'
            : 'convert-pane convert-pane-right is-inactive';
    }

    get opportunityCreateFieldsDisabled() {
        return this.existingOpportunity || this.doNotCreateOpportunity;
    }

    get opportunityExistingSearchDisabled() {
        return this.createOpportunity || this.opportunitySearchDisabled;
    }

    // Standard Convert Lead default: "<Account Name>-"
    setDefaultOpportunityName() {

        const accountName =
            (this.accountOption === 'existing' && this.selectedAccountName)
                ? this.selectedAccountName
                : (this.newAccountName || (this.selectedLead ? this.selectedLead.Company : '') || 'New');

        this.opportunityName = accountName + '-';
    }

    handleAccountOptionChange(event) {

        this.accountOption = event.target.value;
        this.setDefaultOpportunityName();

        // Mirror the standard Convert Lead screen: switching to "Choose
        // Existing Account" immediately runs a match search (by the
        // company/account name already on hand) instead of waiting for
        // the dealer to type something first.
        if (this.accountOption === 'existing' && !this.accountSearchPerformed) {
            const defaultTerm = this.newAccountName || (this.selectedLead ? this.selectedLead.Company : '');
            this.accountSearchTerm = defaultTerm;
            this.runAccountSearch(defaultTerm);
        }
    }

    handleNewAccountNameChange(event) {
        this.newAccountName = event.target.value;
        this.setDefaultOpportunityName();
    }

    handleAccountSearch(event) {

        const term = event.target.value;
        this.accountSearchTerm = term;

        window.clearTimeout(this.accountSearchTimeout);

        this.accountSearchTimeout = window.setTimeout(() => {
            this.runAccountSearch(term);
        }, 300);
    }

    runAccountSearch(term) {

        if (!term || term.length < 2) {
            this.accountSearchResults = [];
            this.accountSearchPerformed = false;
            return;
        }

        searchAccounts({ searchTerm: term })
            .then(data => {
                this.accountSearchResults = data.map(acc => ({
                    ...acc,
                    subtitle: acc.AccountNumber ? acc.AccountNumber : '(----)'
                }));
                this.accountSearchPerformed = true;
            })
            .catch(error => {
                console.error(error);
            });
    }

    get hasAccountResults() {
        return this.accountSearchResults && this.accountSearchResults.length > 0;
    }

    // "X Account Matches" label shown under the results list, same as the
    // standard Convert Lead screen.
    get accountSearched() {
        return this.accountOption === 'existing' && this.accountSearchPerformed;
    }

    get accountMatchesLabel() {
        const count = this.accountSearchResults ? this.accountSearchResults.length : 0;
        return count + (count === 1 ? ' Account Match' : ' Account Matches');
    }

    selectAccount(event) {

        this.selectedAccountId = event.currentTarget.dataset.id;
        this.selectedAccountName = event.currentTarget.dataset.name;
        this.accountSearchResults = [];
        this.accountSearchTerm = this.selectedAccountName;
        this.setDefaultOpportunityName();

        // Once an Account is chosen, immediately surface the Contacts and
        // Opportunities that already belong to it - matching the standard
        // Convert Lead screen's "related to that account" behaviour.
        this.loadContactsForAccount(this.selectedAccountId);
        this.loadOpportunitiesForAccount(this.selectedAccountId);
    }

    loadContactsForAccount(accountId) {

        getContactsForAccount({ accountId })
            .then(data => {
                this.contactSearchResults = data;
            })
            .catch(error => {
                console.error(error);
            });
    }

    loadOpportunitiesForAccount(accountId) {

        getOpportunitiesForAccount({ accountId })
            .then(data => {
                this.opportunitySearchResults = data;
            })
            .catch(error => {
                console.error(error);
            });
    }

    get isNewContact() {
        return this.contactOption === 'new';
    }

    get isExistingContact() {
        return this.contactOption === 'existing';
    }

    get salutationOptions() {
        return [
            { label: '--None--', value: '' },
            { label: 'Mr.', value: 'Mr.' },
            { label: 'Ms.', value: 'Ms.' },
            { label: 'Mrs.', value: 'Mrs.' },
            { label: 'Dr.', value: 'Dr.' },
            { label: 'Prof.', value: 'Prof.' }
        ];
    }

    handleContactOptionChange(event) {

        this.contactOption = event.target.value;

        // If an Account is already selected, show its Contacts right away
        if (this.contactOption === 'existing'
            && this.accountOption === 'existing'
            && this.selectedAccountId
            && this.contactSearchResults.length === 0) {

            this.loadContactsForAccount(this.selectedAccountId);
        }
    }

    handleContactSalutationChange(event) {
        this.contactSalutation = event.target.value;
    }

    handleContactFirstNameChange(event) {
        this.contactFirstName = event.target.value;
    }

    handleContactMiddleNameChange(event) {
        this.contactMiddleName = event.target.value;
    }

    handleContactLastNameChange(event) {
        this.contactLastName = event.target.value;
    }

    handleContactDesignationChange(event) {
        this.contactDesignation = event.target.value;
    }

    handleContactSearch(event) {

        const term = event.target.value;
        this.contactSearchTerm = term;

        window.clearTimeout(this.contactSearchTimeout);

        if (!term || term.length < 2) {
            this.contactSearchResults = [];
            return;
        }

        this.contactSearchTimeout = window.setTimeout(() => {

            searchContacts({
                searchTerm: term,
                // Scope to the chosen Account (if any), same as the
                // standard screen restricting matches to that account
                accountId: this.accountOption === 'existing' ? this.selectedAccountId : null
            })
                .then(data => {
                    this.contactSearchResults = data;
                })
                .catch(error => {
                    console.error(error);
                });

        }, 300);
    }

    get hasContactResults() {
        return this.contactSearchResults && this.contactSearchResults.length > 0;
    }

    selectContact(event) {

        this.selectedContactId = event.currentTarget.dataset.id;
        this.selectedContactName = event.currentTarget.dataset.name;
        this.contactSearchResults = [];
        this.contactSearchTerm = this.selectedContactName;
    }

    get createOpportunity() {
        return this.opportunityOption === 'create';
    }

    get existingOpportunity() {
        return this.opportunityOption === 'existing';
    }

    // Existing Opportunity search only makes sense once an existing Account
    // has been chosen (new Accounts can't already have Opportunities) -
    // matches the standard screen's "To find opportunity, choose an
    // existing account" placeholder/disabled state.
    get canSearchOpportunity() {
        return this.accountOption === 'existing' && !!this.selectedAccountId;
    }

    get opportunitySearchDisabled() {
        return !this.canSearchOpportunity;
    }

    get opportunitySearchPlaceholder() {
        return this.canSearchOpportunity
            ? 'Search for matching opportunities'
            : 'To find opportunity, choose an existing account';
    }

    get hasOpportunityResults() {
        return this.opportunitySearchResults && this.opportunitySearchResults.length > 0;
    }

    handleOpportunityOptionChange(event) {

        this.opportunityOption = event.target.value;

        if (this.opportunityOption === 'existing'
            && this.canSearchOpportunity
            && this.opportunitySearchResults.length === 0) {

            this.loadOpportunitiesForAccount(this.selectedAccountId);
        }
    }

    handleDoNotCreateOpportunityChange(event) {
        this.doNotCreateOpportunity = event.target.checked;
    }

    handleOpportunityNameChange(event) {
        this.opportunityName = event.target.value;
    }

    handleOpportunityCloseDateChange(event) {
        this.opportunityCloseDate = event.target.value;
    }

    handleOpportunitySearch(event) {

        const term = event.target.value;
        this.opportunitySearchTerm = term;

        window.clearTimeout(this.opportunitySearchTimeout);

        if (!this.canSearchOpportunity || !term || term.length < 2) {
            return;
        }

        this.opportunitySearchTimeout = window.setTimeout(() => {

            searchOpportunities({
                searchTerm: term,
                accountId: this.selectedAccountId
            })
                .then(data => {
                    this.opportunitySearchResults = data;
                })
                .catch(error => {
                    console.error(error);
                });

        }, 300);
    }

    selectOpportunity(event) {

        this.selectedOpportunityId = event.currentTarget.dataset.id;
        this.selectedOpportunityName = event.currentTarget.dataset.name;
        this.opportunitySearchResults = [];
        this.opportunitySearchTerm = this.selectedOpportunityName;
    }

    handleConfirmConvert() {

        if (!this.selectedLead || this.isConverting) {
            return;
        }

        if (this.accountOption === 'existing' && !this.selectedAccountId) {
            this.showToast('Error', 'Please select an existing account, or switch to "Create New Account".', 'error');
            return;
        }

        if (this.contactOption === 'existing' && !this.selectedContactId) {
            this.showToast('Error', 'Please select an existing contact, or switch to "Create New Contact".', 'error');
            return;
        }

        if (this.contactOption === 'new' && !this.contactLastName) {
            this.showToast('Error', 'Last Name is required for the new contact.', 'error');
            return;
        }

        if (this.opportunityOption === 'existing' && !this.selectedOpportunityId) {
            this.showToast('Error', 'Please select an existing opportunity, or switch to "Create New Opportunity".', 'error');
            return;
        }

        const willCreateOpportunity =
            this.opportunityOption === 'create' && !this.doNotCreateOpportunity;

        if (willCreateOpportunity && !this.opportunityCloseDate) {
            this.showToast('Error', 'Close Date is required for the new opportunity.', 'error');
            return;
        }

        this.isConverting = true;

        const leadId = this.selectedLead.Id;

        // "Don't create an opportunity upon conversion" overrides "create",
        // same as the standard screen's checkbox
        const resolvedOpportunityOption =
            this.opportunityOption === 'existing'
                ? 'existing'
                : (willCreateOpportunity ? 'create' : 'skip');

        convertLeadFull({

            leadId: leadId,
            accountOption: this.accountOption,
            existingAccountId: this.accountOption === 'existing' ? this.selectedAccountId : null,
            newAccountName: this.newAccountName,
            contactOption: this.contactOption,
            existingContactId: this.contactOption === 'existing' ? this.selectedContactId : null,
            contactSalutation: null,
            contactFirstName: this.contactOption === 'new' ? this.contactFirstName : null,
            contactMiddleName: null,
            contactLastName: this.contactOption === 'new' ? this.contactLastName : null,
            contactDesignation: this.contactOption === 'new' ? this.contactDesignation : null,
            opportunityOption: resolvedOpportunityOption,
            existingOpportunityId: this.opportunityOption === 'existing' ? this.selectedOpportunityId : null,
            opportunityName: willCreateOpportunity ? this.opportunityName : null,
            opportunityCloseDate: willCreateOpportunity ? this.opportunityCloseDate : null
        })

            .then(() => {

                this.showToast(
                    'Success',
                    'Lead converted successfully.',
                    'success'
                );

                // converted leads no longer show in the working list
                this.leads = this.leads.filter(
                    item => item.Id !== leadId
                );

                this.applyFilters();

                this.isConverting = false;
                this.showConvertModal = false;

                this.backToList();
            })

            .catch(error => {

                console.error(error);

                this.isConverting = false;

                this.showToast(
                    'Error',
                    this.extractErrorMessage(error),
                    'error'
                );
            });
    }

    /* =========================
       NOTES
    ========================== */

    handleNoteChange(event) {

        this.noteText =
            event.target.value;
    }

   handleAddNote() {

    if (!this.noteText || !this.noteText.trim() || !this.selectedLead) {
        return;
    }

    const leadId = this.selectedLead.Id;
    const bodyText = this.noteText.trim();

    this.noteText = '';

    addLeadNoteApex({
        leadId: leadId,
        noteBody: bodyText
    })
    .then(newNote => {
        if (newNote && newNote.id) {
            this.leadNotes = [newNote, ...this.leadNotes];
        } else {
            this.loadLeadNotes(leadId);
        }
    })
    .catch(error => {
        console.error(error);
        this.noteText = bodyText;
        this.showToast(
            'Error',
            this.extractErrorMessage(error),
            'error'
        );
    });
}

    /* =========================
       ACTIVITY: TASKS & EVENTS
    ========================== */

    loadUpcomingActivities(leadId) {

        getUpcomingActivities({ leadId })

            .then(data => {

                this.upcomingActivities = data;
            })

            .catch(error => {

                console.error(error);
            });
    }

    get hasUpcomingActivities() {

        return (
            this.upcomingActivities &&
            this.upcomingActivities.length > 0
        );
    }

   handleNewTask() {

    if (!this.selectedLead) {
        return;
    }

    this.showTaskModal = true;
}

handleCreateLead(event) {
    if (event) {
        event.preventDefault();
        event.stopPropagation();
    }
    this.leadModalEditRecord = null;
    this.showLeadModal = true;
}

handleEditLead(event) {
    if (event) {
        event.preventDefault();
        event.stopPropagation();
    }
    if (!this.selectedLead || !this.selectedLead.Id) {
        return;
    }
    // Pass a shallow copy so modal always gets a fresh object for prefills
    this.leadModalEditRecord = { ...this.selectedLead };
    this.showLeadModal = true;
}

closeLeadModal() {
    this.showLeadModal = false;
    this.leadModalEditRecord = null;
}

stopLeadModalBubble(event) {
    event.stopPropagation();
}

async handleLeadSaved(event) {
    this.showLeadModal = false;
    this.leadModalEditRecord = null;

    const detail = event.detail || {};
    const savedLead = detail.lead || detail;
    const isEdit = detail.isEdit === true;
    const savedId = savedLead && savedLead.Id ? savedLead.Id : null;

    this.showToast(
        'Success',
        isEdit ? 'Lead updated successfully.' : 'Lead created successfully.',
        'success'
    );

    if (this.wiredLeadResult) {
        await refreshApex(this.wiredLeadResult);
        // After wire remaps leads, keep detail open on the same lead
        if (isEdit && savedId) {
            const refreshed = (this.leads || []).find(l => l.Id === savedId);
            if (refreshed) {
                this.selectedLead = refreshed;
            }
        }
        this.applyFilters();
        return;
    }

    // Fallback if wire is not available
    if (savedLead && savedId) {
        const mapped = {
            ...savedLead,
            statusClass: this.getStatusClass(savedLead.Dealer_Status__c || savedLead.Status),
            createdDate: savedLead.CreatedDate
                ? new Date(savedLead.CreatedDate).toLocaleDateString('en-IN', {
                    day: '2-digit',
                    month: 'short'
                })
                : '',
            ownerInitials: savedLead.Owner?.Name
                ? savedLead.Owner.Name.split(' ')
                      .map(word => word[0])
                      .join('')
                      .substring(0, 2)
                      .toUpperCase()
                : 'NA'
        };
        if (isEdit) {
            this.leads = (this.leads || []).map(l =>
                l.Id === savedId ? { ...l, ...mapped } : l
            );
            if (this.selectedLead && this.selectedLead.Id === savedId) {
                this.selectedLead = { ...this.selectedLead, ...mapped };
            }
        } else {
            this.leads = [mapped, ...(this.leads || [])];
        }
        this.applyFilters();
    }
}

closeTaskModal() {
    this.showTaskModal = false;
}

handleTaskSaved(event) {

    const summary = event.detail;

    if (summary) {
        this.upcomingActivities = [
            ...this.upcomingActivities,
            summary
        ];
    }

    this.showTaskModal = false;
}

    handleNewEvent() {
        if (!this.selectedLead) {
            return;
        }
        this.showEventModal = true;
    }

    closeEventModal() {
        this.showEventModal = false;
    }

    handleEventSaved(event) {
        const summary = event.detail;
        if (summary) {
            this.upcomingActivities = [
                ...this.upcomingActivities,
                summary
            ];
        }
        this.showEventModal = false;
    }

    /* =========================
       NOTES: LOAD
    ========================== */

    loadLeadNotes(leadId) {

        getLeadNotes({ leadId })

            .then(data => {

                this.leadNotes = data;
            })

            .catch(error => {

                console.error(error);
            });
    }

    get hasNotes() {

        return (
            this.leadNotes &&
            this.leadNotes.length > 0
        );
    }

    /* =========================
       FILES: LOAD + UPLOAD
    ========================== */

    loadLeadFiles(leadId) {

        getLeadFiles({ leadId })

            .then(data => {

                this.leadFiles = data;
            })

            .catch(error => {

                console.error(error);
            });
    }

    get hasFiles() {

        return (
            this.leadFiles &&
            this.leadFiles.length > 0
        );
    }

    handleFilePreview(event) {

        const fileId =
            event.currentTarget.dataset.id;

        const file =
            this.leadFiles.find(
                item => item.id === fileId
            );

        if (!file || !file.versionId) {
            return;
        }

        const downloadUrl =
            '/sfc/servlet.shepherd/version/download/' +
            file.versionId;

        const type = (file.fileType || '').toUpperCase();

        const imageTypes =
            ['PNG', 'JPG', 'JPEG', 'GIF', 'WEBP', 'BMP', 'SVG'];

        this.previewFile = {

            title:
                file.title,

            url:
                downloadUrl,

            isImage:
                imageTypes.includes(type),

            isPdf:
                type === 'PDF'
        };
    }

    closeFilePreview() {

        this.previewFile = null;
    }

    stopPropagation(event) {

        event.stopPropagation();
    }

    get hasFilePreview() {

        return this.previewFile !== null;
    }

    handleFileInputChange(event) {

        const files = event.target.files;

        if (!files || files.length === 0) {
            return;
        }

        Array.from(files).forEach(file => {

            this.uploadFile(file);
        });

        // reset the input so selecting the same file again still fires 'change'
        event.target.value = '';
    }

    uploadFile(file) {

        if (!this.selectedLead) {
            return;
        }

        const leadId = this.selectedLead.Id;

        const reader = new FileReader();

        reader.onload = () => {

            // reader.result looks like "data:<mime>;base64,<data>"
            const base64Data =
                reader.result.split(',')[1];

            saveLeadAttachment({

                leadId:
                    leadId,

                fileName:
                    file.name,

                base64Data:
                    base64Data
            })

            .then(newFile => {

                // instant update: prepend without waiting on a reload
                this.leadFiles = [
                    newFile,
                    ...this.leadFiles
                ];
            })

            .catch(error => {

                console.error(error);

                this.showToast(
                    'Error',
                    this.extractErrorMessage(error),
                    'error'
                );
            });
        };

        reader.onerror = () => {

            console.error('Error reading file: ' + file.name);

            this.showToast(
                'Error',
                'Could not read file: ' + file.name,
                'error'
            );
        };

        reader.readAsDataURL(file);
    }

    /* =========================
       DYNAMIC ACTIVITY
    ========================== */

   get leadInitials() {
    if (!this.selectedLead?.Name) {
        return '';
    }

    return this.selectedLead.Name
        .trim()
        .split(/\s+/)
        .map(word => word.charAt(0))
        .join('')
        .substring(0, 2)
        .toUpperCase();
}


    /* =========================
       COUNTS
    ========================== */

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

    get totalCount() {

        return this.leads.length;
    }

    get newCount() {

        return this.leads.filter(
            item =>
                item.Status === 'New'
        ).length;
    }

  get progressCount() {

    return this.leads.filter(
        item =>
            item.Status ===
            'Work In Progress'
    ).length;
}

    get qualifiedCount() {

        return this.leads.filter(
            item =>
                item.Status ===
                'Qualified'
        ).length;
    }

 get disqualifiedCount() {

    return this.leads.filter(
        item =>
            item.Status ===
            'Regret'
    ).length;
}
}