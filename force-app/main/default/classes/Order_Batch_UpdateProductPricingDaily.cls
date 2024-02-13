global with sharing class Order_Batch_UpdateProductPricingDaily implements Database.Batchable<sObject>,Schedulable{
    
    global Database.QueryLocator start(Database.BatchableContext BC){  
           
        PricingBatchTriggerRules__mdt[] PricingBatchTriggerRules = [Select CustomDate__c,	IsActive__c from PricingBatchTriggerRules__mdt where IsActive__c =: true   limit 1];

        Date CustomDate;

        if(PricingBatchTriggerRules.size()>0){
            CustomDate = PricingBatchTriggerRules[0].CustomDate__c;
        }
        else{
            CustomDate  = system.today();
        }

        return Database.getQueryLocator([SELECT IsActive__c,RetriggerPricing__c from Pricing__c  where ProductComponent__c =:null AND StartDate__c <=: CustomDate AND EndDate__c >=: CustomDate AND IsActive__c =:true]  ); // WHERE ACCOUNT HAS ACTIVE ASSET
    }
    
    global void execute(Database.BatchableContext BC, List<Pricing__c> scope){
       
        for (Pricing__c price : scope) {
            price.RetriggerPricing__c = true;
        }
       
       update scope;
    }
    global void finish(Database.BatchableContext BC){

      

    }
    
    global void execute(SchedulableContext sc)
    {
        Order_Batch_UpdateProductPricingDaily  Pricing = new Order_Batch_UpdateProductPricingDaily();
        database.executebatch(Pricing ,10);
    }



}