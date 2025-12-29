import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getTaskHierarchy from '@salesforce/apex/TaskController.getTaskHierarchy';

export default class TaskFollowUpTreeView extends NavigationMixin(LightningElement) {
    @api recordId;
    
    @track treeData = [];
    @track expandedRows = [];
    @track isLoading = false;
    @track errorMessage = '';
    @track emptyStateMessage = 'No Follow-up tasks available for this task.';
    
    wiredTaskResult;

    columns = [
        {
            type: 'url',
            fieldName: 'subjectUrl',
            label: 'Subject',
            initialWidth: 400,
            typeAttributes: {
                label: { fieldName: 'subject' },
                target: '_self'
            }
        },
        {
            type: 'text',
            fieldName: 'status',
            label: 'Status',
            initialWidth: 120
        },
        {
            type: 'date',
            fieldName: 'dueDate',
            label: 'Due Date',
            initialWidth: 150,
            typeAttributes: {
                day: 'numeric',
                month: 'short',
                year: 'numeric'
            }
        },
        {
            type: 'text',
            fieldName: 'priority',
            label: 'Priority',
            initialWidth: 120
        },
        {
            type: 'text',
            fieldName: 'ownerName',
            label: 'Assigned To',
            initialWidth: 150
        }
    ];

    @wire(getTaskHierarchy, { taskId: '$recordId' })
    wiredTask(result) {
        this.wiredTaskResult = result;
        this.isLoading = true;
        this.errorMessage = '';
        
        if (result.data) {
            this.isLoading = false;
            if (result.data && result.data.length > 0) {
                this.treeData = this.formatTreeData(result.data);
                this.expandAllRows();
            } else {
                this.treeData = [];
                this.expandedRows = [];
            }
        } else if (result.error) {
            this.isLoading = false;
            this.errorMessage = result.error.body?.message || 'Error loading task hierarchy';
            this.treeData = [];
            this.expandedRows = [];
        }
    }

    get showTree() {
        return !this.isLoading && !this.errorMessage && this.treeData.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && this.treeData.length === 0;
    }

    formatTreeData(tasks) {
        if (!tasks || tasks.length === 0) {
            return [];
        }

        return tasks.map(task => this.buildTreeNode(task, 0));
    }

    buildTreeNode(task, level) {
        const node = {
            taskId: task.Id,
            subject: task.Subject || '-',
            subjectUrl: `/${task.Id}`,
            status: task.Status || '-',
            dueDate: task.ActivityDate || null,
            priority: task.Priority || '-',
            ownerName: task.OwnerName || '-',
            _children: []
        };

        if (task.children && task.children.length > 0) {
            node._children = task.children.map(child => this.buildTreeNode(child, level + 1));
        }

        return node;
    }

    expandAllRows() {
        let expandedRows = [];

        const expandChildren = (items) => {
            items.forEach(item => {
                expandedRows.push(item.taskId);
                if (item._children && item._children.length > 0) {
                    expandChildren(item._children);
                }
            });
        };

        expandChildren(this.treeData);
        this.expandedRows = expandedRows;
    }

    collapseAllRows() {
        this.expandedRows = [];
    }

    handleOnToggle(event) {
        const toggledRow = event.detail.name;
        const expandedRows = [...this.expandedRows];
        const index = expandedRows.indexOf(toggledRow);

        if (index === -1) {
            expandedRows.push(toggledRow);
        } else {
            expandedRows.splice(index, 1);
        }

        this.expandedRows = expandedRows;
    }

    @api
    refreshTree() {
        this.isLoading = true;
        return refreshApex(this.wiredTaskResult);
    }
}