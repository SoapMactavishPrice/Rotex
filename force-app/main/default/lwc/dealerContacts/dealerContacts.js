import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';

import getMyContacts from '@salesforce/apex/ContactController.getMyContacts';
import getMyChannelPartnerAccountId from '@salesforce/apex/ContactController.getMyChannelPartnerAccountId';
import getUpcomingActivities from '@salesforce/apex/ContactController.getUpcomingActivities';
import getContactNotes from '@salesforce/apex/ContactController.getContactNotes';
import addContactNote from '@salesforce/apex/ContactController.addContactNote';
import getContactFiles from '@salesforce/apex/ContactController.getContactFiles';
import saveContactAttachment from '@salesforce/apex/ContactController.saveContactAttachment';

const PORTAL_TOAST_DURATION_MS = 4000;

export default class DealerContacts extends LightningElement {
    @track contacts = [];
    @track selectedContact = null;
    @track editingContact = null;
    @track showContactModal = false;
    @track partnerAccountId = null;
    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';

    @track upcomingActivities = [];
    @track contactNotes = [];
    @track contactFiles = [];
    @track showTaskModal = false;
    @track showEventModal = false;
    @track previewFile = null;

    portalToastTimeout;    noteText = '';

    searchKey = '';
    selectedStatus = 'All';
    wiredContactsResult;

    connectedCallback() {
        this._boundShowList = () => this.backToList();
        window.addEventListener('portalshowlist', this._boundShowList);
    }

    disconnectedCallback() {
        if (this._boundShowList) {
            window.removeEventListener('portalshowlist', this._boundShowList);
        }
    }

    @wire(getMyChannelPartnerAccountId)
    wiredPartner({ data }) {
        if (data) {
            this.partnerAccountId = data;
        }
    }

    @wire(getMyContacts)
    wiredContacts(result) {
        this.wiredContactsResult = result;
        if (result.data) {
            this.contacts = (result.data || []).map((c) => this.mapContact(c));
        } else if (result.error) {
            this.contacts = [];
            this.showToast('Error', this.extractErrorMessage(result.error), 'error');
        }
    }

    mapContact(c) {
        const locationParts = [c.MailingCity, c.MailingState].filter(Boolean);
        const status = c.Status__c || '';
        return {
            ...c,
            accountName: c.Account?.Name || '—',
            designation: c.Contact_Person_Designation__c || '',
            statusValue: status,
            statusDisplay: status || 'Not set',
            statusBadgeClass: this.statusBadgeClass(status),
            locationLabel: locationParts.length ? locationParts.join(', ') : '—',
            createdDate: c.CreatedDate
                ? new Date(c.CreatedDate).toLocaleDateString('en-GB', {
                      day: '2-digit',
                      month: 'short',
                      year: 'numeric'
                  })
                : '—',
            designationDisplay: this.displayOrNotSet(c.Contact_Person_Designation__c),
            emailDisplay: this.displayOrNotSet(c.Email),
            mobileDisplay: this.displayOrNotSet(c.MobilePhone),
            dobDisplay: this.formatDateDisplay(c.DOB__c),
            anniversaryDisplay: this.formatDateDisplay(c.Anniversary__c),
            streetDisplay: this.displayOrNotSet(c.MailingStreet),
            cityDisplay: this.displayOrNotSet(c.MailingCity),
            stateDisplay: this.displayOrNotSet(c.MailingState),
            postalDisplay: this.displayOrNotSet(c.MailingPostalCode),
            countryDisplay: this.displayOrNotSet(c.MailingCountry),
            designationClass: this.valueClass(c.Contact_Person_Designation__c),
            emailClass: this.valueClass(c.Email),
            mobileClass: this.valueClass(c.MobilePhone),
            dobClass: this.valueClass(c.DOB__c),
            anniversaryClass: this.valueClass(c.Anniversary__c),
            streetClass: this.valueClass(c.MailingStreet),
            cityClass: this.valueClass(c.MailingCity),
            stateClass: this.valueClass(c.MailingState),
            postalClass: this.valueClass(c.MailingPostalCode),
            countryClass: this.valueClass(c.MailingCountry)
        };
    }

    statusBadgeClass(status) {
        if (status === 'Active') {
            return 'status-badge status-active';
        }
        if (status === 'Inactive') {
            return 'status-badge status-inactive';
        }
        return 'status-badge status-unset';
    }

    displayOrNotSet(value) {
        return value && String(value).trim() ? value : 'Not set';
    }

    valueClass(value) {
        return value && String(value).trim()
            ? 'info-row-value'
            : 'info-row-value value-empty';
    }

    formatDateDisplay(value) {
        if (!value) {
            return 'Not set';
        }
        try {
            return new Date(value).toLocaleDateString('en-GB', {
                day: '2-digit',
                month: 'short',
                year: 'numeric'
            });
        } catch (e) {
            return String(value);
        }
    }

    get filteredContacts() {
        const key = (this.searchKey || '').trim().toLowerCase();
        return this.contacts.filter((c) => {
            const matchesStatus =
                this.selectedStatus === 'All' ||
                c.statusValue === this.selectedStatus;

            if (!matchesStatus) {
                return false;
            }

            if (!key) {
                return true;
            }

            return (
                (c.Name || '').toLowerCase().includes(key) ||
                (c.accountName || '').toLowerCase().includes(key) ||
                (c.Email || '').toLowerCase().includes(key) ||
                (c.MobilePhone || '').toLowerCase().includes(key) ||
                (c.designation || '').toLowerCase().includes(key) ||
                (c.statusValue || '').toLowerCase().includes(key) ||
                (c.locationLabel || '').toLowerCase().includes(key)
            );
        });
    }

    get hasContacts() {
        return this.filteredContacts && this.filteredContacts.length > 0;
    }

    get totalCount() {
        return this.contacts.length;
    }

    get activeCount() {
        return this.contacts.filter((c) => c.statusValue === 'Active').length;
    }

    get inactiveCount() {
        return this.contacts.filter((c) => c.statusValue === 'Inactive').length;
    }

    get allTabClass() {
        return this.selectedStatus === 'All' ? 'tab active' : 'tab';
    }

    get activeTabClass() {
        return this.selectedStatus === 'Active' ? 'tab active' : 'tab';
    }

    get inactiveTabClass() {
        return this.selectedStatus === 'Inactive' ? 'tab active' : 'tab';
    }

    get contactInitials() {
        if (!this.selectedContact || !this.selectedContact.Name) {
            return 'C';
        }
        const parts = this.selectedContact.Name.trim().split(/\s+/);
        if (parts.length >= 2) {
            return (parts[0][0] + parts[1][0]).toUpperCase();
        }
        return this.selectedContact.Name.substring(0, 2).toUpperCase();
    }

    get hasUpcomingActivities() {
        return this.upcomingActivities && this.upcomingActivities.length > 0;
    }

    get hasNotes() {
        return this.contactNotes && this.contactNotes.length > 0;
    }

    get hasFiles() {
        return this.contactFiles && this.contactFiles.length > 0;
    }

    get hasFilePreview() {
        return this.previewFile !== null;
    }

    handleSearch(event) {
        this.searchKey = event.target.value || '';
    }

    handleStatusFilter(event) {
        this.selectedStatus = event.currentTarget.dataset.status || 'All';
    }

    handleCreateContact() {
        this.editingContact = null;
        this.showContactModal = true;
    }

    handleEditContact() {
        if (!this.selectedContact) {
            return;
        }
        this.editingContact = this.selectedContact;
        this.showContactModal = true;
    }

    closeContactModal() {
        this.showContactModal = false;
        this.editingContact = null;
    }

    stopContactModalBubble(event) {
        event.stopPropagation();
    }

    handleContactSaved(event) {
        const wasEdit = !!this.editingContact;
        this.showContactModal = false;
        this.editingContact = null;
        this.showToast(
            'Success',
            wasEdit ? 'Contact updated successfully.' : 'Contact created successfully.',
            'success'
        );
        const saved = event?.detail;
        if (saved?.Id && this.selectedContact?.Id === saved.Id) {
            this.selectedContact = this.mapContact(saved);
        }
        if (this.wiredContactsResult) {
            refreshApex(this.wiredContactsResult).then(() => {
                if (saved?.Id) {
                    const found = this.contacts.find((c) => c.Id === saved.Id);
                    if (found) {
                        this.selectedContact = found;
                    }
                }
            });
        }
    }

    openContactDetail(event) {
        const id = event.currentTarget.dataset.id;
        const found = this.contacts.find((c) => c.Id === id);
        if (!found) {
            return;
        }

        this.selectedContact = found;
        this.upcomingActivities = [];
        this.contactNotes = [];
        this.contactFiles = [];
        this.previewFile = null;
        this.noteText = '';

        this.loadUpcomingActivities(id);
        this.loadContactNotes(id);
        this.loadContactFiles(id);
    }

    backToList() {
        this.selectedContact = null;
        this.upcomingActivities = [];
        this.contactNotes = [];
        this.contactFiles = [];
        this.previewFile = null;
        this.noteText = '';
        this.showTaskModal = false;
        this.showEventModal = false;
    }

    loadUpcomingActivities(contactId) {
        getUpcomingActivities({ contactId })
            .then((data) => {
                this.upcomingActivities = data || [];
            })
            .catch((error) => {
                console.error(error);
            });
    }

    loadContactNotes(contactId) {
        getContactNotes({ contactId })
            .then((data) => {
                this.contactNotes = data || [];
            })
            .catch((error) => {
                console.error(error);
            });
    }

    loadContactFiles(contactId) {
        getContactFiles({ contactId })
            .then((data) => {
                this.contactFiles = data || [];
            })
            .catch((error) => {
                console.error(error);
            });
    }

    handleNewTask() {
        if (!this.selectedContact) {
            return;
        }
        this.showTaskModal = true;
    }

    closeTaskModal() {
        this.showTaskModal = false;
    }

    handleTaskSaved(event) {
        const summary = event.detail;
        if (summary) {
            this.upcomingActivities = [...this.upcomingActivities, summary];
        } else if (this.selectedContact) {
            this.loadUpcomingActivities(this.selectedContact.Id);
        }
        this.showTaskModal = false;
    }

    handleNewEvent() {
        if (!this.selectedContact) {
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
            this.upcomingActivities = [...this.upcomingActivities, summary];
        } else if (this.selectedContact) {
            this.loadUpcomingActivities(this.selectedContact.Id);
        }
        this.showEventModal = false;
    }

    handleNoteChange(event) {
        this.noteText = event.target.value;
    }

    handleAddNote() {
        if (!this.noteText || !this.noteText.trim() || !this.selectedContact) {
            return;
        }

        const contactId = this.selectedContact.Id;
        const bodyText = this.noteText.trim();
        this.noteText = '';

        addContactNote({ contactId, noteBody: bodyText })
            .then((newNote) => {
                if (newNote && newNote.id) {
                    this.contactNotes = [newNote, ...this.contactNotes];
                } else {
                    this.loadContactNotes(contactId);
                }
            })
            .catch((error) => {
                console.error(error);
                this.noteText = bodyText;
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    handleFilePreview(event) {
        const fileId = event.currentTarget.dataset.id;
        const file = this.contactFiles.find((item) => item.id === fileId);
        if (!file || !file.versionId) {
            return;
        }

        const downloadUrl =
            '/sfc/servlet.shepherd/version/download/' + file.versionId;
        const type = (file.fileType || '').toUpperCase();
        const imageTypes = ['PNG', 'JPG', 'JPEG', 'GIF', 'WEBP', 'BMP', 'SVG'];

        this.previewFile = {
            title: file.title,
            url: downloadUrl,
            isImage: imageTypes.includes(type),
            isPdf: type === 'PDF'
        };
    }

    closeFilePreview() {
        this.previewFile = null;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleFileInputChange(event) {
        const files = event.target.files;
        if (!files || files.length === 0) {
            return;
        }
        Array.from(files).forEach((file) => this.uploadFile(file));
        event.target.value = '';
    }

    uploadFile(file) {
        if (!this.selectedContact) {
            return;
        }

        const contactId = this.selectedContact.Id;
        const reader = new FileReader();

        reader.onload = () => {
            const base64Data = reader.result.split(',')[1];
            saveContactAttachment({
                contactId,
                fileName: file.name,
                base64Data
            })
                .then((newFile) => {
                    this.contactFiles = [newFile, ...this.contactFiles];
                })
                .catch((error) => {
                    console.error(error);
                    this.showToast('Error', this.extractErrorMessage(error), 'error');
                });
        };

        reader.onerror = () => {
            this.showToast('Error', 'Could not read file: ' + file.name, 'error');
        };

        reader.readAsDataURL(file);
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