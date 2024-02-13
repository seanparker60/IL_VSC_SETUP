@isTest
public with sharing class Order_AssetRenewal_InvocableTEST {
    
    public static testMethod void testOrder_AssetRenewal_Invocable(){
        test.startTest();
        Order_AssetRenewal_Invocable.invokeAssetRenewal();
        test.stopTest();
    }
}