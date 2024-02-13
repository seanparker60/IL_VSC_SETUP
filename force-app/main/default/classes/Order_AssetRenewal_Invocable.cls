public with sharing class Order_AssetRenewal_Invocable {
    @InvocableMethod(label='Invoke Asset Renewal' description='Invoke Asset Renewal')
    public static void invokeAssetRenewal() {
        //Order_AssetRenewal.RenewAssets();

        Order_Batch_AccountswithRenwalAssets  AssetRenewal = new Order_Batch_AccountswithRenwalAssets();
        database.executebatch(AssetRenewal ,500); 
    }
}