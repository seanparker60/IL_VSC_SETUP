/* 
* CH - 2023/03/22 - https://dev.azure.com/infinitas/Converse/_boards/board/t/Order%20to%20Cash/Backlog%20items/?workitem=194942
* called from Import Assets flow
*/
public class ImportAssetHandler {
    
    @InvocableVariable public ImportAssets__c importAssetRecord;
    
    @InvocableMethod(label='Import Asset Handler')
    public static void handleAssetImports(List<ImportAssets__c> recordInput){
        // pass list of import assets (bulkification)
        ImportAssetHandlerBatch batchJob = new ImportAssetHandlerBatch(recordInput);
        Id batchJobId = Database.executeBatch(batchJob, 5);
    }
}