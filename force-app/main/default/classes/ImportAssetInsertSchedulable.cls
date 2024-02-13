global class ImportAssetInsertSchedulable implements Schedulable{
    global void execute(SchedulableContext sc)
    {
        callBatch();
    }
    
    public void callBatch()
    {
        ImportAssetInsertBatch batchJob2 = new ImportAssetInsertBatch();
        Id batchJob2Id = Database.executeBatch(batchJob2, 25);   
    }
}