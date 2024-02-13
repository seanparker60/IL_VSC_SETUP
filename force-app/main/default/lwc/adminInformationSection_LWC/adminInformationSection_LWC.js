import { LightningElement, api } from 'lwc';
import getFields from '@salesforce/apex/AdminInformationSectionApex.getFields';

export default class DynamicRecordEditForm extends LightningElement {
    @api recordId; // Record Id passed from parent component or record page
    fields = []; // Array to store the fields from FieldSet

    connectedCallback() {
        // Call Apex method to get the fields from FieldSet
        getFields({ objectName: 'Account' })
            .then((result) => {
                console.log('admin info success');
                console.log('result: ' + result);
                this.fields = result;
                console.log('fields: ' + this.fields);
            })
            .catch((error) => {
                console.log('admin info error');
                console.error(error);
            });
    }
}