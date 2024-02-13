public without sharing class OrderProductHfdstructuurController {
    @AuraEnabled(cacheable=true)
    public static List<OrderItem> getOrderProducts(Id orderId){
        system.debug('ORDERID: ' + orderId);
        
        List<AssetProductRenewal__mdt> assetProducts = AssetProductRenewal__mdt.getAll().values();
        List<String> eanStrLs = new List<String>();
        
        for(AssetProductRenewal__mdt ap : assetProducts){
            
            if(ap.BusinessUnit__c == 'PlantynInformat'){
                eanStrLs.add(ap.ProductEAN__c);
            }
        }
        
        List<OrderItem> retVal = [SELECT Id, ProductName__c, ProductEAN__c, ProductType__c, Quantity, Hfdstructuur__c, ShipToAccount__r.Hfdstructuur__c 
                                  FROM OrderItem WHERE OrderId =: orderId AND ProductEAN__c IN :eanStrLs];
        system.debug('Order Items - retVal: ' + retVal);
        
        return retVal;
    }
    
    @AuraEnabled(cacheable=false)
    public static void saveRecords(List<OrderItem> orderProducts, Id ordId, Integer validateHfdstructuur){
        system.debug('orderProducts: ' + orderProducts);
        update orderProducts;
        
        system.debug('validateHfdstructuur: ' + validateHfdstructuur);
        
        Order ord = new Order();
        ord.Id = ordId;
        ord.ValidateItemHfdstructuur__c = validateHfdstructuur;
        update ord;
    }
}