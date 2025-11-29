import { LightningElement,track } from 'lwc';
import getAccounts from '@salesforce/apex/TargetModuleNew.getAccounts';
import saveTargetModuleRecords from '@salesforce/apex/TargetModuleNew.saveTargetModuleRecords';
import getExistingTargetModules from '@salesforce/apex/TargetModuleNew.getExistingTargetModules';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDefaultFilterValues from '@salesforce/apex/TargetModuleNew.getDefaultFilterValues';

export default class TargetModuleNew extends LightningElement {
      @track accounts = [];
    lastRecordId = null;
    batchSize = 50;
    isLoading = false;
    allDataLoaded = false;
    targetModuleMap = new Map(); // AccountId -> Target__c

    connectedCallback() {
        this.getDefaultFilterValues1();
        this.loadMoreData();
        
    }
    @track fiscId = '';

getDefaultFilterValues1() {
                getDefaultFilterValues()
                    .then((data) => {
                        this.filters = JSON.parse(data);
                        this.fiscId = this.filters.Fiscal_Year__c;
                    })
              
}

   loadMoreData() {
    if (this.isLoading || this.allDataLoaded) return;
    this.isLoading = true;

    getAccounts({ lastRecordId: this.lastRecordId, limitSize: this.batchSize })
        .then(result => {
            if (result.length < this.batchSize) this.allDataLoaded = true;

            if (result.length > 0) {
                this.lastRecordId = result[result.length - 1].Id;
                const accountIds = result.map(acc => acc.Id);

                // Fetch existing Target__c records
                getExistingTargetModules({ accountIds ,fiscalId:this.fiscId})
                    .then(existingMap => {
                        let newData = result.map(acc => {
                            const existing = existingMap ? existingMap[acc.Id] : null;
                            const ownerName = acc.Owner?.Name || '';
                            const managerName = acc.Owner?.Manager?.Name || '';
                            const managerId = acc.Owner?.ManagerId || null;
                            const ownerId = acc.OwnerId || null;

                            // --- Store in map for saving later ---
                            this.targetModuleMap.set(
                                acc.Id,
                                existing
                                    ? { ...existing }
                                    : {
                                          Customer_Name__c: acc.Id,
                                          Fiscal_Year__c: this.fiscId,
                                          Total_Target__c:0,
                                          Total_Actual__c:0,
                                          Reporting_Manager__c: managerId,
                                          Sales_Rep__c: ownerId,
                                          Qtr_1_Target__c: 0,
                                          Qtr_2_Target__c: 0,
                                          Qtr_3_Target__c: 0,
                                          Qtr_4_Target__c: 0,
                                          Qtr_1_Actual__c: 0,
                                          Qtr_2_Actual__c: 0,
                                          Qtr_3_Actual__c: 0,
                                          Qtr_4_Actual__c: 0,
                                          Total_Visits_Per_Year__c: 0,
                                          Actual_Visits_Per_Year__c: 0
                                      }
                            );

                            // --- Prepare for UI display ---
                            return {
                                ...acc,
                                OwnerName: ownerName,
                                Fiscal_Year__c: this.fiscId,
                                Reporting_Manager: existing
                                    ? existing.Reporting_Manager__r?.Name
                                    : managerName,
                                Reporting_Manager__c: existing
                                    ? existing.Reporting_Manager__c
                                    : managerId,
                                Sales_Rep__c: existing
                                    ? existing.Sales_Rep__c
                                    : ownerId,
                                Qtr_1_Target__c: existing
                                    ? existing.Qtr_1_Target__c
                                    : 0,
                                Qtr_2_Target__c: existing
                                    ? existing.Qtr_2_Target__c
                                    : 0,
                                Qtr_3_Target__c: existing
                                    ? existing.Qtr_3_Target__c
                                    : 0,
                                Qtr_4_Target__c: existing
                                    ? existing.Qtr_4_Target__c
                                    : 0,
                                Qtr_1_Actual__c: existing
                                    ? existing.Qtr_1_Actual__c
                                    : 0,
                                Qtr_2_Actual__c: existing
                                    ? existing.Qtr_2_Actual__c
                                    : 0,
                                Qtr_3_Actual__c: existing
                                    ? existing.Qtr_3_Actual__c
                                    : 0,
                                Qtr_4_Actual__c: existing
                                    ? existing.Qtr_4_Actual__c
                                    : 0,
                                Total_Visits_Per_Year__c: existing
                                    ? existing.Total_Visits_Per_Year__c
                                    : 0,
                                Actual_Visits_Per_Year__c: existing
                                    ? existing.Actual_Visits_Per_Year__c
                                    : 0,

                                    Total_Target__c: existing
                                    ? existing.Total_Target__c
                                    : 0
,
                                          Total_Actual__c: existing
                                    ? existing.Total_Target__c
                                    : 0
,
                            };
                        });

                        this.accounts = [...this.accounts, ...newData];
                    })
                    .finally(() => (this.isLoading = false));
            } else {
                this.isLoading = false;
            }
        })
        .catch(error => {
            console.error('Error loading data: ', error);
            this.isLoading = false;
        });
}


    handleScroll(event){
        const div = event.target;
        if(div.scrollTop + div.clientHeight >= div.scrollHeight - 50){
            this.loadMoreData();
        }
    }

    handleTargetChange(event) {
    const index = event.target.dataset.index;
    const field = event.target.dataset.field; // e.g. Qtr_1_Target__c
    const value = parseFloat(event.target.value) || 0;

    // Get account from list
    const acc = this.accounts[index];
    acc[field] = value;

    // Recalculate total target (sum of all quarters)
    const total =
        (parseFloat(acc.Qtr_1_Target__c) || 0) +
        (parseFloat(acc.Qtr_2_Target__c) || 0) +
        (parseFloat(acc.Qtr_3_Target__c) || 0) +
        (parseFloat(acc.Qtr_4_Target__c) || 0);

    acc.Total_Target__c = total;

    // Update the target module map (for saving later)
    let tm = this.targetModuleMap.get(acc.Id) || {};
    tm[field] = value;
    tm.Total_Target__c = total;

    this.targetModuleMap.set(acc.Id, tm);

    // Optional: update UI immediately
    this.accounts = [...this.accounts];
}


   saveRecords() {
    // Filter only records with at least one quarter > 0
    const recordsToSave = Array.from(this.targetModuleMap.values()).filter(rec =>
        rec.Qtr_1_Target__c > 0 ||
        rec.Qtr_2_Target__c > 0 ||
        rec.Qtr_3_Target__c > 0 ||
        rec.Qtr_4_Target__c > 0
    );

    if (recordsToSave.length === 0) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Warning',
                message: 'Please enter at least one quarter value before saving.',
                variant: 'warning'
            })
        );
        return; // stop save
    }

    // Save only filtered records
    saveTargetModuleRecords({ records: recordsToSave })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Targets saved successfully',
                    variant: 'success'
                })
            );
        })
        .catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                })
            );
        });
}

}