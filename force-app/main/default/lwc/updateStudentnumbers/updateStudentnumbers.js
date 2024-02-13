import { LightningElement, track, api } from 'lwc';
import createClassification from '@salesforce/apex/SN_updateStudentnumbersController.handleFiles';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

const columns = [
    { label: 'Account', fieldName: 'Account__c' },
    { label: 'Total number', fieldName: 'TotalNumber__c'},
    { label: 'Kindergarten Number', fieldName: 'KindergartenNumber__c'},
    { label: 'Primary Education Number', fieldName: 'PrimaryEducationNumber__c'},
    { label: 'Secondary Education Number', fieldName: 'SecondaryEducationNumber__c'},
    { label: 'Higher Education Number', fieldName: 'HigherEducationNumber__c'},
    { label: 'Vocational Education Number', fieldName: 'VocationalEducationNumber__c'},
    { label: 'Start date', fieldName: 'StartDate__c' },
    { label: 'End date', fieldName: 'EndDate__c' }
]

export default class UpdateStudentnumbers extends LightningElement {
    @api recordid;
    @track columns = columns;
    @track data;
    @track fileName = 'Please select a (UTF-8, comma seperated) CSV file to upload (in the form of: AccountId, OperatingCompany, TotalNumber, KindergartenNumber, PrimaryEducationNumber, SecondaryEducationNumber, HigherEducationNumber, VocationalEducationNumber, StartDate, EndDate)';
    @track UploadFile = 'Upload CSV File';
    @track splitterTitle = 'Data Preview';
    @track showLoadingSpinner = false;
    @track isTrue = false; // is this needed?
    selectedRecords;
    filesUploaded = [];
    file;
    fileContents;
    fileReader;
    content;
    MAX_FILE_SIZE = 1500000;


    handleFilesChange(event) {
        if (event.target.files.length > 0) {
            this.filesUploaded = event.target.files;
            this.fileName = event.target.files[0].name;
        }
    }

    handleSave() {
        if (this.filesUploaded.length > 0) {
            this.uploadHelper();
        } else {
            this.fileName = 'Please select a CSV file to Upload.';
        }
    }

    uploadHelper() {
        this.file = this.filesUploaded[0];
        if (this.file.size > this.MAX_FILE_SIZE) {
            window.console.log('File size is to big!');
            return;
        }
        this.showLoadingSpinner = true;

        this.fileReader = new FileReader();

        this.fileReader.onLoadend = (() => {
            this.fileContents = this.fileReader.result;
            this.createRecord();
        });

        this.fileReader.readAsText(this.file);
    }

    createRecord() {
        createClassification({ base64Data: JSON__c.stringify(this.fileContents), cdbId: this.recordid})
        .then(result => {
            window.console.log('result =====> ');
            window.console.log(result);

            this.data = result;

            this.fileName = this.fileName + ' - Upload Succesfull';
            this.isTrue = false;
            this.showLoadingSpinner = false;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success!',
                    message: this.fileName + ' - Uploaded successfully',
                    variant: 'success',
                }),
            );
        })
        .catch(error => {
            window.console.log(error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error while uploading File',
                    message: error.message,
                    variant: 'error,'
                }),
            );
        });
    }

}