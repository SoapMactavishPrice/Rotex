import { LightningElement, track, api } from "lwc";
import findRecords from "@salesforce/apex/EnhancedCustomLookup.findRecords";
import fetchDefaultRecord from "@salesforce/apex/EnhancedCustomLookup.fetchDefaultRecord";

export default class EnhancedCustomLookup extends LightningElement {
    @track recordsList;
    @track searchKey = "";
    @api selectedValue;
    @api selectedData = {};
    @api selectedRecordId;
    @api objectApiName;
    @api returnFields;
    @api displayFields;
    @api queryFields = null;
    @api filter = '';
    @api sortColumn = '';
    @api maxResults = '';
    @api iconName;
    @api lookupLabel;
    @track message;
    @api recdataid;
    @api rowid;
    @api index;
    @api index_x;
    @api index_y;
    @api defaultRecordId = '';
    @api disabled = false;
    @track displayFieldsList = [];

    connectedCallback() {
        console.log('connectedCallback');

        if (this.displayFields != null && this.displayFields != '') {
            this.displayFieldsList = this.displayFields.split(',');
        }

        if (this.defaultRecordId != '') {
            console.log('fetchDefaultRecord',
                'this._defaultRecordId ->', this.defaultRecordId, this.objectApiName, this.returnFields);
            fetchDefaultRecord({ recordId: this.defaultRecordId, sObjectApiName: this.objectApiName, returnFields: this.returnFields })
                .then((result) => {
                    if (result != null) {
                        console.log('result : ', JSON.stringify(result));
                        if (result.CaseNumber) {
                            result.Name = result.CaseNumber;
                        }
                        //this.selectedRecord = result;
                        this.selectedRecordId = result.Id;
                        this.selectedValue = result.Name;
                        this.selectedData = JSON.parse(JSON.stringify(result));
                        this.searchKey = "";
                        this.onSeletedRecordUpdate();
                        //this.handelSelectRecordHelper(); // helper function to show/hide lookup result container on UI
                    }
                })
                .catch((error) => {
                    this.error = error;
                    this.selectedRecord = {};
                });
        } else {
            console.log('blank else connected');
            this.removeRecordOnLookup();
        }
    }

    // render(){
    //   console.log('I am child render');
    // }

    @api
    showMessage(strString) {
        //alert(strString.toUpperCase());
        console.log('showmessage');
        this.defaultRecordId = strString;
        console.log('defaultRecordId', this.defaultRecordId);
        this.connectedCallback();
    }

    renderedCallback() {
        console.log('This is From child component rendered callback');
    }

    onLeave(event) {
        setTimeout(() => {
            this.searchKey = "";
            this.recordsList = null;
        }, 300);
    }

    onRecordSelection(event) {
        this.selectedRecordId = event.target.dataset.key;
        this.selectedValue = event.target.dataset.name;
        this.selectedData = this.recordsList.filter(function (item) { return item.Id == event.target.dataset.key; })[0];
        this.searchKey = "";
        // console.log('selectedRecordId', this.selectedRecordId);
        // console.log('selectedValue', this.selectedValue);
        // console.log('selectedData', this.selectedData);
        this.onSeletedRecordUpdate();
    }

    handleKeyChange(event) {
        const searchKey = event.target.value;
        this.searchKey = searchKey;
        this.getLookupResult();
    }

    removeRecordOnLookup(event) {
        this.searchKey = "";
        this.selectedValue = null;
        this.selectedRecordId = null;
        this.selectedData = null;
        this.recordsList = null;
        this.onSeletedRecordUpdate();
    }

    getLookupResult() {
        clearTimeout(this.searchTimeout);

        this.searchTimeout = setTimeout(() => {
            // console.log('this.searchKey ',this.searchKey);
            findRecords({ searchKey: this.searchKey, objectName: this.objectApiName, recdataid: this.recdataid, returnFields: this.returnFields, queryFields: this.queryFields, displayFields: this.displayFields, filter: this.filter, sortColumn: this.sortColumn, maxResults: this.maxResults })
                .then(result => {
                    if (result.length === 0) {
                        this.recordsList = [];
                        this.message = "No Records Found";
                    } else {

                        let vData = JSON.parse(JSON.stringify(result));
                        console.log('vData', vData);
                        for (let i = 0; i < vData.length; i++) {
                            if (vData[i].CaseNumber) {
                                vData[i].Name = vData[i].CaseNumber;
                            }
                        }

                        if (this.displayFields != null && this.displayFields != '') {
                            let vDf = this.displayFields.split(',').map(e => e.trim());
                            vData.forEach((e, i) => {
                                e.c__col1 = e[vDf[0]];
                                e.c__col2 = e[vDf[1]];
                                e.c__col3 = e[vDf[2]];
                                e.c__col4 = e[vDf[3]];
                                e.c__col5 = e[vDf[4]];
                            });
                        }

                        this.recordsList = vData; //JSON.stringify(this.recordsList);
                        this.message = "";
                    }
                    this.error = undefined;
                })
                .catch(error => {
                    this.error = error;
                    this.recordsList = undefined;
                });
        }, 500);
    }

    onSeletedRecordUpdate() {
        const passEventr = new CustomEvent("recordselection", {
            detail: {
                selectedRecordId: this.selectedRecordId,
                selectedValue: this.selectedValue,
                selectedData: this.selectedData,
                rowid: this.rowid,
                index: this.index,
                index_x: this.index_x,
                index_y: this.index_y
            }
        });
        this.dispatchEvent(passEventr);
    }
}