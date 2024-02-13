@isTest
public class ReturnHfdStrucuutChoices_TEST {
    public static testMethod void testReturnHfdStrucuutChoices(){
        
        test.startTest();
        List<ReturnHfdStrucuutChoices.FlowInputs> flowInpLs = new List<ReturnHfdStrucuutChoices.FlowInputs>();
        ReturnHfdStrucuutChoices.FlowInputs flowInps = new ReturnHfdStrucuutChoices.FlowInputs();
        
        flowInps.picklistOptions = 'abc;xyz';
        flowInpLs.add(flowInps);
        ReturnHfdStrucuutChoices.returnPicklistOptions(flowInpLs);
        test.stopTest();
    }
}