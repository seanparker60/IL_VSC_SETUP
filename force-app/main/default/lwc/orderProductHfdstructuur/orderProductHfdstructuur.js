import { LightningElement, api, wire, track } from 'lwc';
import getOrderProducts from '@salesforce/apex/OrderProductHfdstructuurController.getOrderProducts';
import updateRecords from '@salesforce/apex/OrderProductHfdstructuurController.saveRecords';
import { NavigationMixin } from 'lightning/navigation';
import { FlowAttributeChangeEvent, FlowNavigationNextEvent,FlowNavigationFinishEvent  } from 'lightning/flowSupport';

export default class OrderProductHfdstructuur extends NavigationMixin(LightningElement)  {
    @api orderId;
    @api lstRecords;
    @track trackedRecords;
    @api isSaving = false;

    @wire(getOrderProducts, {orderId: '$orderId'}) 
    wiredOrderProducts ({ error, data }){
        if(data){
            let result = JSON.parse(JSON.stringify(data));

            for(var i = 0; i < result.length; i++){
                result[i].rowNumber = i+1;

                if(Object.hasOwn(result[i], 'Hfdstructuur__c') == false){
                    result[i].Hfdstructuur__c = '';
                }

                var pickLsOptions = [];

                if(result[i].ShipToAccount__r.Hfdstructuur__c != null){
                    pickLsOptions = result[i].ShipToAccount__r.Hfdstructuur__c.split(';');
                } else {
                    pickLsOptions.push('No Hfdstructuur numbers have been set up for this account');
                }
                
                console.log('picklistOptions: ', pickLsOptions);

                var formattedPicklistOptions = [];

                for(var j = 0; j < pickLsOptions.length; j++){

                    var obj;
                    if(pickLsOptions[j] != 'No Hfdstructuur numbers have been set up for this account'){
                        obj = {
                            label: pickLsOptions[j],
                            value: pickLsOptions[j]
                        }
                    } else {
                        obj = {
                            label: pickLsOptions[j],
                            value: null
                        }
                    }
                    

                    formattedPicklistOptions.push(obj);
                }

                result[i].formattedHfdstructuurOptions = formattedPicklistOptions;

                console.log( 'Options are ', JSON.stringify( result[i].formattedHfdstructuurOptions ) );

                if(result[i].formattedHfdstructuurOptions.length == 1){
                    result[i].Hfdstructuur__c = result[i].formattedHfdstructuurOptions[0].value;
                }
            }

            console.log("result", result);

            this.lstRecords = result;
            this.trackedRecords = result;
            console.log('this.trackedRecords on wire:', this.trackedRecords);
        } else if (error){
            console.log("OrderProductHfdstructuur LWC ERROR:", error);
            this.trackedRecords = [];
        }
    };    

    connectedCallback(){
        console.log("[MOUNTED]");
        console.log("orderId", this.orderId);
        console.log("wiredOrderProducts", this.wiredOrderProducts);

        this.showTable = true;
    }

    handleAttributeChange(event) {
        console.log('event.id: ', event.target.dataset.recordId);
        console.log('event.detail.value: ', JSON.parse(JSON.stringify(event.detail.value)));
        

        for(var i = 0; i < this.trackedRecords.length; i++){
            if(this.trackedRecords[i].Id == event.target.dataset.recordId){
                this.trackedRecords[i].Hfdstructuur__c = event.detail.value;
            }
        }

        console.log('this.trackedRecords after change: ', JSON.parse(JSON.stringify(this.trackedRecords)));
        /*const attributeChangeEvent = new FlowAttributeChangeEvent('lstRecords', this.trackedRecords);
        this.dispatchEvent(attributeChangeEvent);*/
    }

    redirectToOrder(){
        console.log('redirecting... ' + this.orderId);

        var navigationEvent = new FlowNavigationFinishEvent();
        this.dispatchEvent(navigationEvent);
    }

    handleClick(event){
        const buttonLabel = event.target.label;
        console.log('buttonLabel: ' + buttonLabel);

        this.isSaving = true;

        if(buttonLabel == 'Save'){
            console.log("-- SAVE", JSON.parse(JSON.stringify(this.trackedRecords)));
            var recordsToSave = [];
            var validateError = 0;

            for(var i = 0 ; i < this.trackedRecords.length; i++){
                var recObj = {
                    Id: this.trackedRecords[i].Id,
                    Hfdstructuur__c: this.trackedRecords[i].Hfdstructuur__c
                };


                if(this.trackedRecords[i].Hfdstructuur__c == "" || this.trackedRecords[i].Hfdstructuur__c == null){
                    validateError = validateError += 1;
                }

                recordsToSave.push(recObj);
            }

            console.log('SAVE RECORDS:', recordsToSave);
            updateRecords({orderProducts : recordsToSave, ordId : this.orderId, validateHfdstructuur : validateError}).then(() => {
                this.redirectToOrder();
            }).catch(err => {
                console.error("[FAILED TO SAVE RECORDS]");
            })
        } else {
            this.redirectToOrder();
        }
    }
}