import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getMyCases from '@salesforce/apex/ComplaintController.getMyCases';
import getShowComplaintListUiFlag from '@salesforce/apex/ComplaintController.getShowComplaintListUiFlag';
import getCaseComments from '@salesforce/apex/ComplaintController.getCaseComments';
import getCaseNotes from '@salesforce/apex/ComplaintController.getCaseNotes';
import getCaseFiles from '@salesforce/apex/ComplaintController.getCaseFiles';
import addCaseNote from '@salesforce/apex/ComplaintController.addCaseNote';
import saveCaseAttachment from '@salesforce/apex/ComplaintController.saveCaseAttachment';

export default class DealerComplaint extends NavigationMixin(LightningElement) {
    @track cases = [];
    @track showCaseList = true;
    @track selectedCase = null;
    @track activeTab = 'details';
    @track showNewComplaintModal = false;
    /** From Feature_Setting__mdt — search / export / list table */
    @track showComplaintListUi = false;
    
    @track caseComments = [];
    @track isLoadingComments = false;
    @track selectedCommentId = null;
    @track caseNotes = [];
    @track caseFiles = [];
    @track previewFile = null;

    searchKey = '';
    noteText = '';
    wiredCasesResult;

    connectedCallback() {
        this._boundShowList = () => this.backToList();
        window.addEventListener('portalshowlist', this._boundShowList);
        this.loadComplaintListUiFlag();
    }

    async loadComplaintListUiFlag() {
        try {
            this.showComplaintListUi = await getShowComplaintListUiFlag();
        } catch (e) {
            this.showComplaintListUi = false;
        }
    }

    disconnectedCallback() {
        if (this._boundShowList) {
            window.removeEventListener('portalshowlist', this._boundShowList);
        }
    }

    @wire(getMyCases)
    wiredCases(result) {
        this.wiredCasesResult = result;
        if (result.data) {
            this.cases = (result.data || []).map((o) => this.mapCase(o));
        } else if (result.error) {
            this.cases = [];
            this.showToast('Error', this.extractErrorMessage(result.error), 'error');
        }
    }

    mapCase(o) {
        const accountName = o.Account?.Name || '—';
        const contactName = o.Contact?.Name || '—';

        let lookupValue = '—';
        if (o.Category__c) {
            const cat = o.Category__c.toLowerCase();
            if (cat === 'customer' && o.Customer__r) lookupValue = o.Customer__r.Name;
            else if (cat === 'quote' && o.Quote__r) lookupValue = o.Quote__r.QuoteNumber + (o.Quote__r.Name ? ' - ' + o.Quote__r.Name : '');
            else if (cat === 'order' && o.Order__r) lookupValue = o.Order__r.OrderNumber + (o.Order__r.SO_No__c ? ' - ' + o.Order__r.SO_No__c : (o.Order__r.Name ? ' - ' + o.Order__r.Name : ''));
            else if (cat === 'invoice' && o.Invoice__r) lookupValue = o.Invoice__r.Bill_Doc_No__c || o.Invoice__r.Name;
            else if (cat === 'grn' && o.GRN__r) lookupValue = o.GRN__r.Name;
            else if (cat === 'product' && o.Product__r) lookupValue = o.Product__r.Name;
            else if (cat === 'other' && o.Other_Reference__c) lookupValue = o.Other_Reference__c;
        }

        return {
            ...o,
            accountDisplay: accountName,
            contactDisplay: contactName,
            ownerName: this.formatOwnerName(o.Owner),
            createdDate: this.formatDateDisplay(o.CreatedDate, false),
            
            caseNumberDisplay: this.displayOrNotSet(o.CaseNumber),
            subjectDisplay: this.displayOrNotSet(o.Subject),
            descriptionDisplay: this.displayOrNotSet(o.Description),
            priorityDisplay: this.displayOrNotSet(o.Priority),

            statusDisplay: this.displayOrNotSet(o.Status),
            statusBadgeClass: this.statusBadgeClass(o.Status),
            
            ticketTypeDisplay: this.displayOrNotSet(o.Ticket_Type__c),
            categoryDisplay: this.displayOrNotSet(o.Category__c),
            lookupDisplay: lookupValue || '—',
            lookupLabelDisplay: (o.Category__c && o.Category__c.trim() !== '') ? o.Category__c : 'Lookup Reference',

            resolutionDisplay: this.displayOrNotSet(o.Resolution__c),
            rootCauseDisplay: this.displayOrNotSet(o.Root_Cause__c),
            remarksDisplay: this.displayOrNotSet(o.Remarks__c),
            openedDateDisplay: this.formatDateDisplay(o.CreatedDate, false),
            closedDateDisplay: this.formatDateDisplay(o.ClosedDate, false),
            csatDisplay: this.displayOrNotSet(o.Customer_Satisfaction__c)
        };
    }

    formatOwnerName(owner) {
        if (!owner) {
            return '—';
        }
        const firstLast = [owner.FirstName, owner.LastName]
            .filter((part) => part && String(part).trim())
            .join(' ')
            .trim();
        if (firstLast) {
            return firstLast;
        }
        const name = owner.Name ? String(owner.Name).trim() : '';
        if (name && !/^User\d{8,}$/i.test(name)) {
            return name;
        }
        if (owner.Email && String(owner.Email).trim()) {
            return owner.Email;
        }
        return name || '—';
    }

    displayOrNotSet(value) {
        return value !== null && value !== undefined && String(value).trim() !== '' ? value : 'Not set';
    }

    formatDateDisplay(value, emptyAsNotSet = true) {
        if (!value) {
            return emptyAsNotSet ? 'Not set' : '—';
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

    formatDateTimeDisplay(value) {
        if (!value) {
            return '—';
        }
        try {
            return new Date(value).toLocaleString('en-GB', {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            });
        } catch (e) {
            return String(value);
        }
    }

    get isDetailsTab() {
        return this.activeTab === 'details';
    }

    get isCommentsTab() {
        return this.activeTab === 'comments';
    }

    get detailsTabClass() {
        return this.isDetailsTab ? 'quote-tab quote-tab-active' : 'quote-tab';
    }

    get commentsTabClass() {
        return this.isCommentsTab ? 'quote-tab quote-tab-active' : 'quote-tab';
    }

    get showCommentListView() {
        return this.selectedCommentId == null;
    }

    get showCommentDetailView() {
        return this.selectedCommentId != null;
    }

    get selectedComment() {
        if (!this.selectedCommentId) return null;
        return this.caseComments.find((t) => t.id === this.selectedCommentId);
    }

    get hasComments() {
        return this.caseComments && this.caseComments.length > 0;
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        this.selectedCommentId = null;
        if (this.activeTab === 'comments') {
            this.loadComments();
        }
    }

    async loadComments() {
        if (!this.selectedCase?.Id) {
            this.caseComments = [];
            return;
        }
        this.isLoadingComments = true;
        try {
            const result = await getCaseComments({ caseId: this.selectedCase.Id });
            const mapped = (result || []).map(t => ({
                id: t.Id,
                createdDateMs: t.CreatedDate ? new Date(t.CreatedDate).getTime() : 0,
                createdDateDisplay: this.formatDateTimeDisplay(t.CreatedDate),
                commentBodyDisplay: this.displayOrNotSet(t.CommentBody),
                createdByNameDisplay: this.displayOrNotSet(t.CreatedBy?.Name)
            }));
            
            mapped.sort((a, b) => {
                const byCreated = (b.createdDateMs || 0) - (a.createdDateMs || 0);
                return byCreated;
            });
            this.caseComments = mapped;
        } catch (error) {
            this.caseComments = [];
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoadingComments = false;
        }
    }

    handleCommentClick(event) {
        this.selectedCommentId = event.currentTarget.dataset.id;
    }

    handleBackToComments() {
        this.selectedCommentId = null;
    }

    statusBadgeClass(status) {
        const s = (status || '').toLowerCase();
        if (s === 'new' || s === 'open' || s === 'working') {
            return 'grn-status grn-status-partial';
        }
        if (s === 'closed' || s === 'resolved') {
            return 'grn-status grn-status-complete';
        }
        return 'grn-status';
    }

    get filteredCases() {
        const key = (this.searchKey || '').trim().toLowerCase();
        if (!key) {
            return this.cases;
        }
        return this.cases.filter((o) => {
            return (
                (o.CaseNumber || '').toLowerCase().includes(key) ||
                (o.accountDisplay || '').toLowerCase().includes(key) ||
                (o.subjectDisplay || '').toLowerCase().includes(key) ||
                (o.priorityDisplay || '').toLowerCase().includes(key) ||
                (o.statusDisplay || '').toLowerCase().includes(key)
            );
        });
    }

    get hasCases() {
        return this.filteredCases && this.filteredCases.length > 0;
    }

    handleSearch(event) {
        this.searchKey = event.target.value || '';
    }

    async refreshSelectedCase() {
        if (this.wiredCasesResult) {
            await refreshApex(this.wiredCasesResult);
        }
        if (this.selectedCase) {
            const found = this.cases.find((o) => o.Id === this.selectedCase.Id);
            if (found) {
                this.selectedCase = found;
            }
        }
    }

    async openCaseDetail(event) {
        const id = event.currentTarget.dataset.id;
        if (this.wiredCasesResult) {
            await refreshApex(this.wiredCasesResult);
        }
        const found = this.cases.find((o) => o.Id === id);
        if (found) {
            this.selectedCase = found;
            this.resetSidebarState();
            this.loadCaseSidebar(found.Id);
        }
    }

    backToList() {
        this.showCaseList = true;
        this.selectedCase = null;
        this.resetSidebarState();
    }

    resetSidebarState() {
        this.activeTab = 'details';
        this.selectedCommentId = null;
        this.caseComments = [];
        this.caseNotes = [];
        this.caseFiles = [];
        this.noteText = '';
        this.previewFile = null;
    }

    loadCaseSidebar(caseId) {
        this.loadCaseNotes(caseId);
        this.loadCaseFiles(caseId);
    }

    handleNoteChange(event) {
        this.noteText = event.target.value;
    }

    handleAddNote() {
        if (!this.noteText || !this.noteText.trim() || !this.selectedCase) {
            return;
        }

        const caseId = this.selectedCase.Id;
        const bodyText = this.noteText.trim();
        this.noteText = '';

        addCaseNote({ caseId, noteBody: bodyText })
            .then((newNote) => {
                if (newNote && newNote.id) {
                    this.caseNotes = [newNote, ...this.caseNotes];
                } else {
                    this.loadCaseNotes(caseId);
                }
            })
            .catch((error) => {
                this.noteText = bodyText;
                this.showToast('Error', this.extractErrorMessage(error), 'error');
            });
    }

    loadCaseNotes(caseId) {
        getCaseNotes({ caseId })
            .then((data) => {
                this.caseNotes = data || [];
            })
            .catch((error) => {
                console.error(error);
            });
    }

    get hasNotes() {
        return this.caseNotes && this.caseNotes.length > 0;
    }

    loadCaseFiles(caseId) {
        getCaseFiles({ caseId })
            .then((data) => {
                this.caseFiles = data || [];
            })
            .catch((error) => {
                console.error(error);
            });
    }

    get hasFiles() {
        return this.caseFiles && this.caseFiles.length > 0;
    }

    handleFilePreview(event) {
        const fileId = event.currentTarget.dataset.id;
        const file = this.caseFiles.find((item) => item.id === fileId);
        if (!file || !file.versionId) {
            return;
        }

        const downloadUrl = '/sfc/servlet.shepherd/version/download/' + file.versionId;
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

    get hasFilePreview() {
        return this.previewFile !== null;
    }

    handleFileInputChange(event) {
        const files = event.target.files;
        if (!files || files.length === 0) {
            return;
        }

        Array.from(files).forEach((file) => {
            this.uploadFile(file);
        });
        event.target.value = '';
    }

    uploadFile(file) {
        if (!this.selectedCase) {
            return;
        }

        const caseId = this.selectedCase.Id;
        const reader = new FileReader();

        reader.onload = () => {
            const base64Data = reader.result.split(',')[1];
            saveCaseAttachment({
                caseId,
                fileName: file.name,
                base64Data
            })
                .then((newFile) => {
                    this.caseFiles = [newFile, ...this.caseFiles];
                })
                .catch((error) => {
                    this.showToast('Error', this.extractErrorMessage(error), 'error');
                });
        };

        reader.onerror = () => {
            this.showToast('Error', 'Could not read file: ' + file.name, 'error');
        };

        reader.readAsDataURL(file);
    }

    handleAddComplaint() {
        // Public fillable form — open in new tab so portal stays on Complaints
        window.open(
            'https://docs.google.com/forms/d/1zSo0eUJTIxF7tscM9RBkaXyVELobhGuueNHsXSBMQJE/viewform',
            '_blank',
            'noopener,noreferrer'
        );
    }

    handleModalClose() {
        this.showNewComplaintModal = false;
    }

    stopModalBubble(event) {
        event.stopPropagation();
    }

    async handleComplaintCreated() {
        this.showNewComplaintModal = false;

        // Standard Salesforce Toast from parent
        this.showToast('Success', 'Complaint created successfully', 'success');
        
        if (this.wiredCasesResult) {
            await refreshApex(this.wiredCasesResult);
        }
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

    @track portalToastVisible = false;
    @track portalToastTitle = '';
    @track portalToastMessage = '';
    @track portalToastVariant = 'info';
    portalToastTimeout;

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
        }, 4000);
    }
}