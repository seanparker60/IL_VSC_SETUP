global class ImportAssetInsertBatch implements Database.Batchable<Asset>, Database.Stateful {
    private Date startDate;
    private Date endDate;
    private List<ImportAssets__c> importAssetRecordLs;
    private List<String> eanStrLs;
    
    public ImportAssetInsertBatch(){
        List<ImportAssetSetting__mdt> importAssetSettings = ImportAssetSetting__mdt.getAll().values();
        
        for(ImportAssetSetting__mdt iaSetting : importAssetSettings){
            if(iaSetting.PricebookName__c.contains('Informat')){
                startDate = Date.newInstance(System.Today().year(), iaSetting.RenewalStartDate__c.month(), iaSetting.RenewalStartDate__c.day());//iaSetting.RenewalStartDate__c;
                endDate = startDate.addMonths(Integer.valueOf(iaSetting.NumberOfMonthsRenewalIsFor__c)).toStartofMonth().addDays(-1);
                //qtyThreshold = Integer.valueOf(iaSetting.AssetQuantityDivergenceThreshold__c);
            }
        }
        
        //startDate = Date.newInstance(Date.today().year(), 02, 01); // 1st of feb for current year
        //endDate = startDate.addYears(1);
        //endDate = endDate.addMonths(1).toStartofMonth().addDays(-1); // last day in feb for next year
        
        importAssetRecordLs = new List<ImportAssets__c>();
        
        List<AssetProductRenewal__mdt> assetProducts = AssetProductRenewal__mdt.getAll().values();
        eanStrLs = new List<String>();
        
        for(AssetProductRenewal__mdt ap : assetProducts){
            
            if(ap.BusinessUnit__c == 'PlantynInformat'){
                eanStrLs.add(ap.ProductEAN__c);
            }
        }
        
        system.debug('eanStrLs: ' + eanStrLs);
    }
    
    global Iterable<Asset> start(Database.BatchableContext bc) {
        // only get assets for products that are part of the AssetProductRenewal__mdt metadata, and if no ImportAsset was created for it, then create import asset record
        // dont create new import asset records if one already exists for the externalcustomernumber and hfdstructuur
        List<Asset> assetsWithoutInfRecs = new List<Asset>();
        assetsWithoutInfRecs = [SELECT Id, ShiptoExternalId__c,AccountId, Informhfdstructuur__c, Quantity, Product2Id FROM Asset WHERE Id NOT IN (SELECT Asset__c FROM ImportAssets__c WHERE QuantityStartDate__c =: startDate AND QuantityEndDate__c =: endDate) 
                                            AND IsInformat__c = true
                                            AND Informhfdstructuur__c != NULL
                                            AND ShiptoExternalId__c != NULL
                                            AND OperatingCompany__c = 'Plantyn'
                                            AND Product2.EAN__c IN :eanStrLs];
                                            //AND Is_mentioned_in_import_asset_errors__c = FALSE];
        
        system.debug('assetsWithoutInfRecs.size(): ' + assetsWithoutInfRecs.size());
        
        if(Test.isRunningTest()){
            assetsWithoutInfRecs = [SELECT Id, ShiptoExternalId__c,AccountId, Informhfdstructuur__c, Quantity, Product2Id FROM Asset WHERE IsInformat__c = true
                                            AND Informhfdstructuur__c != NULL
                                            AND ShiptoExternalId__c != NULL
                                            AND OperatingCompany__c = 'Plantyn'
                                            AND Product2.EAN__c IN :eanStrLs];
        }
        
        return assetsWithoutInfRecs;
    }
    
    global void execute(Database.BatchableContext bc, List<Asset> records){
        // done to prevent duplicate records from being in the deletion (this causes issues)
        Set<ImportAssets__c> setSobs = new Set<ImportAssets__c>();
        List<ImportAssets__c> importAssetsToInsert = new List<ImportAssets__c>();
        system.debug('assets that need inserting assetsWithoutInfRecs.size(): ' + records.size());
        
        Set<Id> assetIDSet = new Set<Id>();
        Set<ImportAssets__c> setImportAssetsToDel = new Set<ImportAssets__c>();
        List<ImportAssets__c> lsSobjs = new List<ImportAssets__c>();

        for(Asset ass : records){
            system.debug('ImportAssetInsertBatch ass: ' + ass);
            List<ImportAssets__c> dupeCheck1 = [SELECT Id, Name from ImportAssets__c
                                                WHERE Asset__r.Product2Id = :ass.Product2Id
                                                AND Asset__r.IsInformat__c = true
                                                AND Asset__r.Informhfdstructuur__c = :ass.Informhfdstructuur__c
                                                AND Asset__r.ShiptoExternalId__c = :ass.ShiptoExternalId__c
                                                AND Asset__r.OperatingCompany__c = 'Plantyn'
                                                AND Asset__r.Product2.EAN__c IN :eanStrLs
                                                AND QuantityStartDate__c =: startDate
                                                AND QuantityEndDate__c =: endDate];
            system.debug('dupeCheck1.size(): ' + dupeCheck1.size());
            
            if(dupeCheck1.size() == 0){
                // double check if an import asset already exists for this asset, because sometimes order of execution will insert dupes
                List<ImportAssets__c> iaLs = [SELECT Id, Error__c FROM ImportAssets__c WHERE Asset__c = :ass.Id
                                              AND QuantityStartDate__c =: startDate AND QuantityEndDate__c =: endDate
                                              AND Asset__c NOT IN :assetIDSet];
                system.debug('ImportAssetInsertBatch iaLs.size(): ' + iaLs.size());
                
                List<ImportAssets__c> iaDupeLs = [SELECT Id, Quantity__c FROM ImportAssets__c
                                                  WHERE QuantityStartDate__c =: startDate AND QuantityEndDate__c =: endDate
                                                  AND ExternalCustomerId__c =: ass.ShiptoExternalId__c 
                                                  AND Hfdstructuur__c =: ass.Informhfdstructuur__c
                                                  AND Asset__c NOT IN :assetIDSet];
                system.debug('ImportAssetInsertBatch iaDupeLs.size(): ' + iaDupeLs.size());
                assetIDSet.add(ass.Id);
                
                system.debug('ass: ' + ass.Id);
                //system.debug('dupe import assets(same hfd & shipto): ' + iaDupeLs.size());
                
                if(iaLs.size() == 0){
                    if(iaDupeLs.size() > 0){
                        // apply imported importasset record's qty to other import assets with same hfdstructuur and externalcustID
                        // so techniucally one import for a hfdstructuur & shipto are applied to all assets with that hfdstructuur and shipto
                        ImportAssets__c iaRec = new ImportAssets__c();
                        iaRec.Asset__c = ass.Id;
                        iaRec.Status__c = 'Pending';
                        iaRec.Error__c = 'This record was created because no Informat record was uploaded for this asset';
                        iaRec.Type__c = 'Informat';
                        iaRec.ExternalCustomerId__c = ass.ShiptoExternalId__c;
                        iaRec.Hfdstructuur__c = ass.Informhfdstructuur__c;
                        iaRec.Quantity__c = iaDupeLs[0].Quantity__c;
                        iaRec.QuantityStartDate__c = startDate;
                        iaRec.QuantityEndDate__c = endDate;
                        iaRec.Wasnotinimport__c = true;
                        iaRec.ShipToAccount__c = ass.AccountId;
                        
                        //system.debug('iaRec: ' + iaRec);
                        
                        //insert iaRec;
                        importAssetRecordLs.add(iaRec);  
                    } else {
                        ImportAssets__c iaRec = new ImportAssets__c();
                        iaRec.Asset__c = ass.Id;
                        iaRec.Status__c = 'Error';
                        iaRec.Error__c = 'This record was created because no Informat record was uploaded for this asset';
                        iaRec.Type__c = 'Informat';
                        iaRec.ExternalCustomerId__c = ass.ShiptoExternalId__c;
                        iaRec.Hfdstructuur__c = ass.Informhfdstructuur__c;
                        iaRec.Quantity__c = ass.Quantity;
                        iaRec.QuantityStartDate__c = startDate;
                        iaRec.QuantityEndDate__c = endDate;
                        iaRec.Wasnotinimport__c = true;
                        iaRec.ShipToAccount__c = ass.AccountId;
                        
                        //insert iaRec;
                        setSobs.add(iaRec);  
                    }
                } else {
                    for(ImportAssets__c iaRec : iaLs){
                        if(iaRec.Error__c == 'This record was created because no Informat record was uploaded for this asset'){
                            setImportAssetsToDel.add(iaRec);
                        }
                    }
                }   
            } else {
                // new
                ImportAssets__c iaRec = new ImportAssets__c();
                iaRec.Asset__c = ass.Id;
                iaRec.Status__c = 'Error';
                iaRec.Error__c = '[Potential Duplicate] There is already an import asset record for this product for the current period';
                iaRec.Type__c = 'Informat';
                iaRec.ExternalCustomerId__c = ass.ShiptoExternalId__c;
                iaRec.Hfdstructuur__c = ass.Informhfdstructuur__c;
                iaRec.Quantity__c = ass.Quantity;
                iaRec.QuantityStartDate__c = startDate;
                iaRec.QuantityEndDate__c = endDate;
                iaRec.Wasnotinimport__c = true;
                iaRec.ShipToAccount__c = ass.AccountId;
                
                iaRec.ErrorDetail__c = 'Please check that the following are not duplicates of this record: ';
                
                for(ImportAssets__c ia : dupeCheck1){
                    iaRec.ErrorDetail__c += ia.Name + ', ';
                }
                iaRec.ErrorDetail__c = iaRec.ErrorDetail__c.removeend(', ');
                
                //insert iaRec;
                setSobs.add(iaRec);  
            }
            
        }
        
        if(setImportAssetsToDel.size() > 0){
            lsSobjs.addAll(setImportAssetsToDel);
            system.debug('DELETE: ' + lsSobjs.size());
            delete lsSobjs;
        }
        
        // 3. Asset in SF but no Record on informat - Flag error on Import Asset Record (create new import assets and flag them as errors)
        if(setSobs.size() > 0){
            importAssetsToInsert.addAll(setSobs);
            insert importAssetsToInsert; 
        }
            
    } 
    
    
    global void finish(Database.BatchableContext bc){
        
        if(importAssetRecordLs.size() > 0){
            insert importAssetRecordLs;
        }
        
        // delete existing job (if there is one)
        CronTrigger[] jobRecordLs = [SELECT Id FROM CronTrigger where CronJobDetail.Name LIKE '%ImportAssetInsertSchedulable_%'];
        
        if(jobRecordLs.size() > 0){
            for(CronTrigger cTrig : jobRecordLs){
                System.abortJob(cTrig.Id);
            }
        }
    }
}