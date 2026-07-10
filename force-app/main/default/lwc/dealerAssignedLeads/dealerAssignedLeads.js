import { LightningElement, track, wire } from 'lwc';

import USER_ID from '@salesforce/user/Id';

import { getRecord }
from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';


import NAME_FIELD
from '@salesforce/schema/User.Name';
import updateLeadStatus
from '@salesforce/apex/DealerLeadController.updateLeadStatus';

import getLeadsByDealerAccount
from '@salesforce/apex/DealerLeadController.getLeadsByDealerAccount';

export default class DealerAssignedLeads
extends LightningElement {

    @track leads = [];

    @track filteredLeads = [];

    @track selectedLead;

    @track currentUserName = '';

    @track userInitials = '';

    currentTime;

    searchKey = '';
    selectedStatus = 'All';
    wiredLeadResult;
    showDropdown = false;

    noteText = '';


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

        this.updateTime();

        setInterval(() => {

            this.updateTime();

        }, 1000);
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

                    statusClass:
                        this.getStatusClass(
                            item.Status
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

                (item.Product_Interested__c || '')
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

    openLeadDetail(event) {

        const leadId =
            event.currentTarget.dataset.id;

        this.selectedLead =
            this.leads.find(
                item =>
                    item.Id === leadId
            );
    }

    backToList() {

        this.selectedLead = null;
    }

    /* =========================
       STATUS DROPDOWN
    ========================== */

    toggleDropdown() {

        this.showDropdown =
            !this.showDropdown;
    }

updateStatus(event) {

    const newStatus =
        event.target
            .closest('.dropdown-item')
            .dataset.status;

    updateLeadStatus({

        leadId:
            this.selectedLead.Id,

        newStatus:
            newStatus
    })

    .then(() => {

        const existingHistory =
            this.selectedLead
            ?.activityHistory || [];

        const newActivity = {

            id: Date.now(),

            message:
                `Status changed to ${newStatus}`,

            date:
                new Date().toLocaleString(
                    'en-IN',
                    {
                        day: '2-digit',
                        month: 'short',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    }
                )
        };

        const updatedLead = {

            ...this.selectedLead,

            Status: newStatus,

            statusClass:
                this.getStatusClass(
                    newStatus
                ),

            activityHistory: [

                newActivity,

                ...existingHistory
            ]
        };

        this.selectedLead =
            updatedLead;

        this.leads =
            this.leads.map(item => {

                if (
                    item.Id === updatedLead.Id
                ) {

                    return updatedLead;
                }

                return item;
            });

        this.applyFilters();

        this.showDropdown = false;
    })

    .catch(error => {

        console.error(error);
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

    if (!this.noteText) {
        return;
    }

    const existingNote =
        this.selectedLead
        .Requirement__c || '';

    this.selectedLead = {

        ...this.selectedLead,

        Requirement__c:
            existingNote
            ? existingNote + '\n• ' + this.noteText
            : '• ' + this.noteText,

        activityText:
            'New note added',

        activityUpdatedDate:
            new Date().toLocaleDateString(
                'en-IN',
                {
                    day: '2-digit',
                    month: 'short'
                }
            )
    };

    this.noteText = '';
}

    /* =========================
       DYNAMIC ACTIVITY
    ========================== */

    get ownerInitials() {

        if (
            !this.selectedLead
            ?.Owner?.Name
        ) {

            return 'NA';
        }

        return this.selectedLead
            .Owner.Name
            .split(' ')
            .map(word => word[0])
            .join('')
            .substring(0, 2)
            .toUpperCase();
    }

    get activityMessage() {

    return this.selectedLead
        ?.activityText
        || 'Lead assigned';
}

get activityDate() {

    return this.selectedLead
        ?.activityUpdatedDate
        || this.selectedLead?.createdDate;
}

    /* =========================
       COUNTS
    ========================== */

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
    get activityList() {

    const history =
        this.selectedLead
        ?.activityHistory || [];

    if (history.length) {

        return history.map(
            (item, index) => {

                return {

                    ...item,

                    isLast:
                        index ===
                        history.length - 1
                };
            }
        );
    }

    return [
        {
            id: 1,
            message:
                'Lead assigned',
            date:
                this.selectedLead
                ?.createdDate,
            isLast: true
        }
    ];
}
}