public without sharing class ReturnHfdStrucuutChoices {
    public class FlowInputs{
        @InvocableVariable public String picklistOptions;
    }
    
    @InvocableMethod(label='Return HfdStructuur Options') 
    public static FlowOutput[] returnPicklistOptions(List<FlowInputs> ParameterList){ 
        FlowOutput[] response = new List<FlowOutput>();
        
        for(FlowInputs input : ParameterList){
            List<String> pickLs = new List<String>(); 
            pickLs = input.picklistOptions.split(';');
            
            response.add(new FlowOutput(pickLs));
        }
        
        return response;
    }
    
    public class FlowOutput{
        @InvocableVariable public List<String> picklistOptionsLs;
        public FlowOutput(List<String> picklsOptions) {this.picklistOptionsLs = picklsOptions;}
    }
}