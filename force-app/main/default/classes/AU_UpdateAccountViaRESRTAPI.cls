@RestResource(urlMapping='/Account/')
global with sharing class AU_UpdateAccountViaRESRTAPI {
    
    @HttpPost
    global static String doPost(List<String> AccIds) {
        String resp='NA';

        System.debug('AccIds ==> ' + AccIds);

        try {

            List<Account> AgodiUpdateList = new List<Account>();
            for (String accId : AccIds) {
                Account acc = new Account();
                acc.Id = accId;
                acc.AgodiUpdateInProgress__c = false;
                AgodiUpdateList.add(acc);
            }

            update AgodiUpdateList;
            resp = 'Success';

        } catch (Exception e) {
            resp = e.getMessage();
            System.debug('ACCOUNT UPDATE ERROR: ' + e.getMessage());
        }

        return resp;
    }

    public static String clearAgodiUpdateInProcess(List<Id> accIdLst) {
        JSONParser parser;
        HttpResponse res1;

        String accessToken,endPoint,DMLType,reqBody,objBody;
        
        DMLType = 'POST';
        endPoint = URL.getSalesforceBaseUrl().toExternalForm()+'/services/apexrest/Account/';
        accessToken = UserInfo.getSessionId();
        reqBody = '{"AccIds" : [';
        for (Id accId : accIdLst) {
            reqBody += '"'+ String.ValueOf(accId) + '"';
            if (accId != accIdLst[accIdLst.size()-1]) {
                reqBody += ',';
            }
        }
        reqBody += ']}';

        Http h2 = new Http();
        HttpRequest req1 = new HttpRequest();
        req1.setHeader('Authorization','Bearer ' + accessToken);
        req1.setHeader('Content-Type','application/json');
        req1.setHeader('accept','application/json');
        req1.setTimeout(120000);

        system.debug('**reqbody**'+reqbody);
        system.debug('**DMLType**'+DMLType);
        system.debug('**endPoint**'+endPoint);

        req1.setEndpoint(endPoint);
        req1.setBody(reqbody);
        req1.setMethod(DMLType);

        string result;
        if(!Test.isRunningTest()){
            res1 = h2.send(req1);
            result = res1.getbody();
        }
        else{
            result = 'failed';
        }
        
        system.debug('**result*' + result);

        if(result.contains('failed')){

            ErrorLog__c errorLog = new ErrorLog__c();
            errorLog.Errororigin__c = 'Apex';
            errorLog.ExceptionMessage__c = result;
            errorLog.ExceptionType__c = 'API Agodi account Update: AU_UpdateAccountViaRESRTAPI';
            database.insert(errorLog);
        }

        return result;
    }
}