import { LightningElement, api, track } from 'lwc';

export default class CloneRecordWithRelated extends LightningElement {
    @api relatedObjectLs;
    @track visible; //used to hide/show modal

    connectedCallback(){
        console.log("relatedObjectLs: ", this.relatedObjectLs);

        this.visible = true;
    }

    handleClick(event){
        console.log("event.detail", event.detail);

        if(event.detail.status === 'confirm') {
            //do something
        } else if(event.detail.status === 'cancel'){
            //do something else
            this.visible = false;
        }
    }
}