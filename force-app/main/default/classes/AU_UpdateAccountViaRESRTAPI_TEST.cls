@IsTest
public class AU_UpdateAccountViaRESRTAPI_TEST {
    
    @TestSetup
    static void makeData(){
        List<Account> accLst = AU_TestDataFactory.createMultipleAccounts(10, false);
        for (Account acc : accLst) {
            acc.AgodiUpdateInProgress__c = true;
        }
        insert accLst;
    }

    @IsTest
    static void methodName(){
        
        List<Account> accLst = [SELECT Id FROM Account];
        List<Id> AccIds = new List<Id>();
        for (Account acc : accLst) {
            AccIds.add(acc.Id);
        }

        Test.startTest();
            AU_UpdateAccountViaRESRTAPI.doPost(AccIds);
        Test.stopTest();
        
    }
}