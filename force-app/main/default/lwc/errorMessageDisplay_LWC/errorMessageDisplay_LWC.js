import { LightningElement, api, wire } from 'lwc';
import { getRecord } from "lightning/uiRecordApi";
import { RefreshEvent } from 'lightning/refresh';
import { FlowNavigationNextEvent, FlowNavigationFinishEvent } from 'lightning/flowSupport';
import NAME_FIELD from '@salesforce/schema/Account.Name';
import Area_FIELD from '@salesforce/schema/Account.Area__c';

export default class ErrorMessageDisplay_LWC extends LightningElement {
    fields = [NAME_FIELD, Area_FIELD];

    @api recordId;
    @api objectApiName;
    @api availableActions = [];

    @wire(getRecord, {recordId: '$recordId', fields: [NAME_FIELD]})
    wiredGetRecord(value) {
        const {data, error} = value;
        console.log("@wire function");
        console.log("data: " + data);
        console.log("error: " + error);
        if(data) {
        if(this.record) {
            console.log("Update");
            //this.handleFinish();
            //this.onRefresh();
            this.updateRecordView();
            // We're getting an update //
            // We can compare deltas to figure out what changed //
        } else {
            console.log("Initlial Load");
            // This is the first time we got data //
        }
        this.record = data;
        }
        if(error) {
            console.log("error");
        // Handle an error here //
        }
    }

    get inputVariables(){

        return[
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    handleFinish(){
        console.log("handleFinish: ");
        const navigateFinishEvent = new FlowNavigationFinishEvent ();
        this.dispatchEvent(navigateFinishEvent);
}

    onRefresh() {
        console.log("onRefresh: ");
        this.dispatchEvent(new RefreshEvent());
      }

    updateRecordView() {
        console.log("updateRecorView: ");
        setTimeout(() => {
                eval("$A.get('e.force:refreshView').fire();");
        }); 
    }

}