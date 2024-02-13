trigger ImportOrderTrigger on ImportOrder__c (before insert, after insert, after update) {
    if(Trigger.isAfter){
        /*Map<ImportOrder__c, ImportOrder__c> recordMap = new Map<ImportOrder__c, ImportOrder__c>();
        
        for(ImportOrder__c io : Trigger.New){
            if(Trigger.oldMap != null){
                recordMap.put(io, Trigger.oldMap.get(io.Id));
            } else {
                recordMap.put(io, null);   
            }
        }
        
        ImportOrderTriggerController batchRun = new ImportOrderTriggerController(recordMap);
        Database.executeBatch(batchRun);*/
        
        System.debug('***Trigger.new: ' + Trigger.new);
        System.debug('***Trigger.new[0].Status__c: ' + Trigger.new[0].Status__c);
        System.debug('***Trigger.oldMap: ' + Trigger.oldMap);
        if(Trigger.oldMap != null){
            System.debug('***Trigger.oldMap.get(Trigger.new[0].id).Status__c: ' + Trigger.oldMap.get(Trigger.new[0].id).Status__c);
        }
        
        if(Trigger.isInsert){
            if(Trigger.new[0].Status__c == 'Pending' || Trigger.new[0].ReadyForPrivateIndividual__c == true){
                Map<String, Object> params = new Map<String, Object>();
                params.put('recordId', Trigger.new[0].Id);
                
                System.debug('INSERT***Trigger.new[0].ReadyForPrivateIndividual__c: ' + Trigger.new[0].ReadyForPrivateIndividual__c);
                System.debug('INSERT***Trigger.new[0]: ' + Trigger.new[0]);
                System.debug('INSERT***Trigger.new[0].Id: ' + Trigger.new[0].Id);
                System.debug('INSERT***Trigger.new[0].ProductId__c: ' + Trigger.new[0].ProductId__c);
                System.debug('INSERT***params: ' + params);
                
                Flow.Interview importHandlerProcess = new Flow.Interview.ImportOrderHandler(params);
                importHandlerProcess.start();
            }
        }
        if(Trigger.isUpdate){
            if(Trigger.new[0].Status__c != Trigger.oldMap.get(Trigger.new[0].id).Status__c && Trigger.new[0].Status__c == 'Pending'){
                Map<String, Object> params = new Map<String, Object>();
                params.put('recordId', Trigger.new[0].Id);
                
                System.debug('UPDATE***Trigger.new[0].ReadyForPrivateIndividual__c: ' + Trigger.new[0].ReadyForPrivateIndividual__c);
                System.debug('UPDATE***Trigger.new[0]: ' + Trigger.new[0]);
                System.debug('UPDATE***Trigger.new[0].Id: ' + Trigger.new[0].Id);
                System.debug('UPDATE***Trigger.new[0].ProductId__c: ' + Trigger.new[0].ProductId__c);
                System.debug('UPDATE***params: ' + params);
                
                Flow.Interview importHandlerProcess = new Flow.Interview.ImportOrderHandler(params);
                importHandlerProcess.start();
            }
        }
    }
}