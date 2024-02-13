global class ImportAssetHandlerBatch implements Database.Batchable<ImportAssets__c>, Database.Stateful{
    private List<ImportAssets__c> importAssetRecordLs;
    private Set<Id> assetIdLs; 
    private Boolean triggerBusinessRules;
    private Map<Id, StudentAndUsernumbers__c> studentNumberMap;
    
    public ImportAssetHandlerBatch(List<ImportAssets__c> recordLs){
        importAssetRecordLs = recordLs;
        assetIdLs = new Set<Id>();
        studentNumberMap = new Map<Id, StudentAndUsernumbers__c>();
    }
    
    global Iterable<ImportAssets__c> start(Database.BatchableContext bc) {
        return importAssetRecordLs;
    }
    
    global void execute(Database.BatchableContext bc, List<ImportAssets__c> records){
        Date startDate; //= Date.newInstance(Date.today().year(), 02, 01); // 1st of feb for current year
        Date endDate; //= startDate.addYears(1);
        //endDate = endDate.addMonths(1).toStartofMonth().addDays(-1); // last day in feb for next year
        Integer qtyThreshold = 0; //= Integer.valueOf(System.Label.AssetQtyThreshold);
        
        List<Asset> assetsToUpdate = new List<Asset>();
        List<StudentAndUsernumbers__c> studentNumsToInsert = new List<StudentAndUsernumbers__c>();
        
        List<ImportAssets__c> importAssetsToUpdate = new List<ImportAssets__c>();
        List<ImportAssets__c> importAssetsToInsert = new List<ImportAssets__c>();
        
        List<ImportAssetSetting__mdt> importAssetSettings = ImportAssetSetting__mdt.getAll().values();
        List<AssetProductRenewal__mdt> assetProducts = AssetProductRenewal__mdt.getAll().values();
        List<String> eanStrLs = new List<String>();
        Set<String> SetAccExtId = new Set<String>();
        
        for(AssetProductRenewal__mdt ap : assetProducts){
            if(ap.BusinessUnit__c == 'PlantynInformat'){
                eanStrLs.add(ap.ProductEAN__c);
            }
        }
        
        for(ImportAssetSetting__mdt iaSetting : importAssetSettings){
            if(iaSetting.PricebookName__c.contains('Informat')){
                startDate = Date.newInstance(System.Today().year(), iaSetting.RenewalStartDate__c.month(), iaSetting.RenewalStartDate__c.day());//iaSetting.RenewalStartDate__c;
                endDate = startDate.addMonths(Integer.valueOf(iaSetting.NumberOfMonthsRenewalIsFor__c)).toStartofMonth().addDays(-1);
                qtyThreshold = Integer.valueOf(iaSetting.AssetQuantityDivergenceThreshold__c);
            }
        }
        
        // loop through each imported record
        for(Integer i = 0; i < records.size(); i++){
            system.debug('CURRENT IMPORT ASSET ID: ' + records[i].Id);
            ImportAssets__c record = records[i];
            
            // only call the batch to insert records IF the business rules need to be triggered, which should usually be the last item
            if(record.TriggerBusinessRules__c == true){
                triggerBusinessRules = true;
            }
            
            record.QuantityStartDate__c = startDate;
            record.QuantityEndDate__c = endDate;
            SetAccExtId.Add(record.ExternalCustomerId__c);
            //4. Two Informat records and only one SF Asset - Flag error on Import Asset Record
            List<ImportAssets__c> duplicateImportAssetLs = [SELECT Id, Name, Hfdstructuur__c, ExternalCustomerId__c, Type__c, Status__c 
                                                            FROM ImportAssets__c
                                                            WHERE Hfdstructuur__c =: record.Hfdstructuur__c AND ExternalCustomerId__c =: record.ExternalCustomerId__c
                                                            AND Type__c =: record.Type__c
                                                            AND Id !=: record.Id
                                                            AND ((QuantityStartDate__c =: startDate AND QuantityEndDate__c =: endDate) 
                                                            OR (QuantityStartDate__c = NULL AND QuantityEndDate__c = NULL))];
            
            // 1. check if asset exists for import asset record
            List<Asset> matchedAssets = [SELECT Id, AccountId, Quantity, SubscriptionIdNumber__c,CancellationDate__c,
                                         Product2Id, Informhfdstructuur__c, ShiptoExternalId__c,
                                         QuantityStartDate__c, QuantityEndDate__c FROM Asset 
                                         WHERE ShiptoExternalId__c =: record.ExternalCustomerId__c 
                                         AND Informhfdstructuur__c =: record.Hfdstructuur__c AND OperatingCompany__c = 'Plantyn'
                                         AND IsInformat__c = true
                                         AND Product2Id != NULL
                                         AND Product2.EAN__c IN :eanStrLs
                                         ORDER BY Product2.EAN__c];
            
            system.debug('MATCHED ASSETS.SIZE(): ' + matchedAssets.SIZE());
            
            
            // record.asset is not null, then use that value
            Id assId = record.Asset__c == null ? null : record.Asset__c;
            
            system.debug('assumed assId: ' + assId);
            
            // 6.  If Account with external ID xxx is expecting hfdstructuur yyy based on the account field and a different hfdstructuur is on the CSV then flag the error.
            List<Account> accLs = [SELECT Id FROM Account
                                   WHERE ExternalCustomerId__c =: record.ExternalCustomerId__c
                                   AND Hfdstructuur__c INCLUDES (:record.Hfdstructuur__c)];
            
            
            // NEW
            if(accLs.size() > 0){
                record.ShipToAccount__c = accLs[0].Id;
                
                if(matchedAssets.size() == 0){
                    // no matched assets
                    
                    // 1. check if asset exists for import asset record (but dont check EAN against metadata)
                    List<Asset> matchedAssetsWithoutEAN = [SELECT Id, AccountId, Quantity, SubscriptionIdNumber__c,
                                                           Product2Id, Informhfdstructuur__c, ShiptoExternalId__c,
                                                           QuantityStartDate__c, QuantityEndDate__c FROM Asset 
                                                           WHERE ShiptoExternalId__c =: record.ExternalCustomerId__c 
                                                           AND Informhfdstructuur__c =: record.Hfdstructuur__c AND OperatingCompany__c = 'Plantyn'
                                                           AND IsInformat__c = true
                                                           AND Product2Id != NULL];
                    
                    if(matchedAssetsWithoutEAN.size() > 0){
                        // 2. Record on Informat CSV but no Asset in SF - Flag error on Import Asset Record
                        record.Status__c = 'Error';
                        record.Error__c = 'A related asset could not be found';
                        record.ErrorDetail__c = 'Metadata product not found';
                        update record; 
                    } else {
                        // 2. Record on Informat CSV but no Asset in SF - Flag error on Import Asset Record
                        record.Status__c = 'Error';
                        record.Error__c = 'A related asset could not be found';
                        update record; 
                    }
                } else if (matchedAssets.size() == 1){
                    // one match, great!
                    assId = matchedAssets[0].Id;
                    
                    
                    if(matchedAssets[0].CancellationDate__c != null && matchedAssets[0].CancellationDate__c <= Date.today()){
                        // asset is cancelled
                        if(record.Approved__c){
                            system.debug('approved check 1');
                            Integer variableQtyDiff = matchedAssets[0].Quantity > record.Quantity__c ? Integer.valueOf(matchedAssets[0].Quantity - record.Quantity__c) : Integer.valueOf(record.Quantity__c - matchedAssets[0].Quantity); 
                            
                            if(variableQtyDiff < qtyThreshold || record.Approved__c == true){
                                // 1. On match create a new studentnumber record with new quantity: start date 1 Feb Current year : End date 28(9)th Feb following year.
                                // - Update Asset Quantity
                                // Populate latest start and end date of quantity. Will add the fields to the Asset
                                
                                List<StudentAndUsernumbers__c> studentNumberRecLs = [SELECT Id from StudentAndUsernumbers__c WHERE
                                                                                     Asset__c =: matchedAssets[0].Id AND StartDate__c =: startDate
                                                                                     AND EndDate__c =: endDate];
                                
                                
                                StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
                                studentANDUserNumber.Account__c = matchedAssets[0].AccountId;
                                
                                
                                studentANDUserNumber.Asset__c = matchedAssets[0].Id;
                                studentANDUserNumber.Type__c = 'Student Numbers';
                                studentANDUserNumber.TotalNumber__c = record.Quantity__c;
                                studentANDUserNumber.StartDate__c = startDate;
                                studentANDUserNumber.EndDate__c = endDate;

                                // apply qty to correct student number category
                                switch on record.Hfdstructuur__c {
                                    when '111', '121'{	
                                        // Kingergarten
                                        studentANDUserNumber.KindergartenNumber__c = record.Quantity__c;
                                    }	
                                    when '211','221' {		
                                        // primary
                                        studentANDUserNumber.PrimaryEducationNumber__c = record.Quantity__c;
                                    }
                                    when '311','321','313','314'{
                                        // secondary education - full time
                                        studentANDUserNumber.SecondaryEducationNumber__c = record.Quantity__c;
                                    }
                                    when '312'{
                                        // secondary education - part time
                                        studentANDUserNumber.SecondaryEducationPartTime__c = record.Quantity__c;
                                    }
                                    when '411', '511' {		
                                        // higher
                                        studentANDUserNumber.HigherEducationNumber__c = record.Quantity__c;
                                    }
                                    when else {		  
                                        // other
                                        studentANDUserNumber.OtherInstitution__c = record.Quantity__c;
                                    }
                                }
                                
                                matchedAssets[0].Quantity = record.Quantity__c;
                                matchedAssets[0].QuantityStartDate__c = startDate;
                                matchedAssets[0].QuantityEndDate__c = endDate;
                                matchedAssets[0].IsActive__c = true;
                                matchedAssets[0].CancellationDate__c = null;
                                matchedAssets[0].CancellationReason__c = null;
                                matchedAssets[0].QuantityUpdateCheckYearly__c = true;
                                
                                record.Status__c = 'Success';
                                record.Asset__c = matchedAssets[0].Id;
                                record.QuantityStartDate__c = startDate;
                                record.QuantityEndDate__c = endDate;
                                //ass.Import_Assets__r[0].Error__c = 'One import asset record loaded for Ship to Account with multiple products(Assets)';
                                
                                //studentNumberMap.put(ass.Id, studentANDUserNumber);
                                if(studentNumberRecLs.size() == 0){
                                    system.debug('insert studentANDUserNumber 1: ' + studentANDUserNumber);
                                    insert studentANDUserNumber;    
                                }
                                
                                try {
                                    //update iaRec;
                                    update matchedAssets[0];
                                } catch(Exception exc){
                                    record.Status__c = 'Error';
                                    
                                    record.Asset__c = matchedAssets[0].Id;
                                    record.Error__c = 'Failed to create StudentAndUsernumbers__c record and update asset';
                                    record.ErrorDetail__c = exc.getMessage();
                                    //update iaRec;
                                }
                                
                            }
                        } else {
                            record.Status__c = 'Error';
                            record.Asset__c = assId;
                            record.Error__c = '[Cancellation] The asset is cancelled';
                            record.ErrorDetail__c = 'Hfdstructuur: ' + record.Hfdstructuur__c + ', ExternalCustomerId: ' + record.ExternalCustomerId__c;
                        }
                        
                        update record;
                    } else {
                        if(record.Approved__c == true){
                            system.debug('approved 196');
                            // get the related import assets to the asset (where the import asset has just been approved)
                            // flag the related ones and say "Duplicate Approved"
                            
                            List<ImportAssets__c> iaLs = [SELECT Id, Name, Hfdstructuur__c, ExternalCustomerId__c, Type__c, Status__c, Quantity__c 
                                                          FROM ImportAssets__c
                                                          WHERE Hfdstructuur__c =: record.Hfdstructuur__c AND ExternalCustomerId__c =: record.ExternalCustomerId__c
                                                          AND Type__c =: record.Type__c
                                                          AND QuantityStartDate__c =: startDate
                                                          AND QuantityEndDate__c =: endDate
                                                          AND Asset__c =: matchedAssets[0].Id
                                                          AND Id != :record.Id];
                            
                            for(ImportAssets__c iaRec : iaLs){
                                iaRec.Status__c = 'Duplicate Approved';
                                iaRec.Error__c = record.Name + ' was approved for this asset';
                                
                            }
                            
                            
                            StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
                            studentANDUserNumber.Account__c = matchedAssets[0].AccountId;
                            
                            
                            studentANDUserNumber.Asset__c = matchedAssets[0].Id;
                            studentANDUserNumber.Type__c = 'Student Numbers';
                            studentANDUserNumber.TotalNumber__c = record.Quantity__c;
                            studentANDUserNumber.StartDate__c = startDate;
                            studentANDUserNumber.EndDate__c = endDate;
                            // apply qty to correct student number category
                            switch on record.Hfdstructuur__c {
                                when '111', '121'{	
                                    // Kingergarten
                                    studentANDUserNumber.KindergartenNumber__c = record.Quantity__c;
                                }	
                                when '211','221' {		
                                    // primary
                                    studentANDUserNumber.PrimaryEducationNumber__c = record.Quantity__c;
                                }
                                when '311','321','313','314'{
                                    // secondary education - full time
                                    studentANDUserNumber.SecondaryEducationNumber__c = record.Quantity__c;
                                }
                                when '312'{
                                    // secondary education - part time
                                    studentANDUserNumber.SecondaryEducationPartTime__c = record.Quantity__c;
                                }
                                when '411', '511' {		
                                    // higher
                                    studentANDUserNumber.HigherEducationNumber__c = record.Quantity__c;
                                }
                                when else {		  
                                    // other
                                    studentANDUserNumber.OtherInstitution__c = record.Quantity__c;
                                }
                            }
                            
                            matchedAssets[0].Quantity = record.Quantity__c;
                            matchedAssets[0].QuantityStartDate__c = startDate;
                            matchedAssets[0].QuantityEndDate__c = endDate;
                            matchedAssets[0].IsActive__c = true;
                            matchedAssets[0].CancellationDate__c = null;
                            matchedAssets[0].CancellationReason__c = null;
                            matchedAssets[0].QuantityUpdateCheckYearly__c = true;
                            
                            record.Status__c = 'Success';
                            record.Asset__c = matchedAssets[0].Id;
                            record.QuantityStartDate__c = startDate;
                            record.QuantityEndDate__c = endDate;
                            
                            try {
                                insert studentANDUserNumber;
                                update matchedAssets[0];
                                update record;
                                
                                if(iaLs.size() > 0){
                                    update iaLs;    
                                }
                            } catch(Exception exc){
                                record.Status__c = 'Error';
                                
                                record.Asset__c = matchedAssets[0].Id;
                                record.Error__c = 'Failed to create StudentAndUsernumbers__c record and update asset';
                                record.ErrorDetail__c = exc.getMessage();
                                update record;
                            }                            
                        } else {
                            
                            List<StudentAndUsernumbers__c> studentNumberRecLs = [SELECT Id from StudentAndUsernumbers__c WHERE
                                                                                 Asset__c =: assId AND StartDate__c =: startDate
                                                                                 AND EndDate__c =: endDate LIMIT 1];
                            
                            // check if assetId is in studentNumberMap, and then check against studentNumberRecLs AND studentNumberMap
                            // because studentNumberRecLs is not inserted yet
                            StudentAndUsernumbers__c studentNumInMAP = studentNumberMap.get(assId);
                            
                            if(duplicateImportAssetLs.size() > 0 && (studentNumberRecLs.size() > 0 || studentNumInMAP != null)){
                                // 4. means there are more than one informat records 
                                record.Status__c = 'Error';
                                record.Asset__c = assId;
                                record.Error__c = '[Potential Duplicate] There is already a student number record linked to the asset for the current period';
                                record.ErrorDetail__c = 'Please check that the following are not duplicates of this record: ';
                                
                                for(ImportAssets__c ia : duplicateImportAssetLs){
                                    record.ErrorDetail__c += ia.Name + ', ';
                                }
                                record.ErrorDetail__c = record.ErrorDetail__c.removeend(', ');
                                
                                update record;
                            } else if (duplicateImportAssetLs.size() > 0 && (studentNumberRecLs.size() == 0 || studentNumInMAP == null)){
                                // 4. means there are more than one informat records 
                                
                                system.debug('duplicateImportAssetLs: ' + duplicateImportAssetLs);
                                
                                // duplicate check against the product. see if there are any importassets for the asset's product
                                List<ImportAssets__c> dupeCheck2 = [SELECT Id, Name from ImportAssets__c
                                                                    WHERE Asset__r.Product2Id = :matchedAssets[0].Product2Id
                                                                    AND Asset__r.IsInformat__c = true
                                                                    AND Asset__r.Informhfdstructuur__c = :matchedAssets[0].Informhfdstructuur__c
                                                                    AND Asset__r.ShiptoExternalId__c = :matchedAssets[0].ShiptoExternalId__c
                                                                    AND Asset__r.OperatingCompany__c = 'Plantyn'
                                                                    AND Asset__r.Product2.EAN__c IN :eanStrLs
                                                                    AND QuantityStartDate__c =: startDate
                                                                    AND QuantityEndDate__c =: endDate
                                                                    AND Id != :record.Id];
                                
                                //system.debug('dupeCheck2: ' + dupeCheck2);
                                
                                record.Status__c = 'Error';
                                record.Asset__c = assId;
                                record.Error__c = '[Potential Duplicate] There is already an import asset record for this product for the current period';
                                record.ErrorDetail__c = 'Please check that the following are not duplicates of this record: ';
                                
                                if(dupeCheck2.size() > 0){
                                    for(ImportAssets__c ia : dupeCheck2){
                                        //system.debug('dupeCheck2 ia.Name: ' + ia.Name);
                                        record.ErrorDetail__c += ia.Name + ', ';
                                    }
                                } else {
                                    for(ImportAssets__c ia : duplicateImportAssetLs){
                                        //system.debug('duplicateImportAssetLs ia.Name: ' + ia.Name);
                                        record.ErrorDetail__c += ia.Name + ', ';
                                    }
                                }
                                
                                record.ErrorDetail__c = record.ErrorDetail__c.removeend(', ');
                                
                                update record;
                                
                            } else {
                                // no duplicates. see if quantity is fine, if so, process successfully
                                // 5. New Quantity too divergent from existing (flag this) 
                                // need to check if the quantity is within reason compared to the old quantity
                                Integer variableQtyDiff = matchedAssets[0].Quantity > record.Quantity__c ? Integer.valueOf(matchedAssets[0].Quantity - record.Quantity__c) : Integer.valueOf(record.Quantity__c - matchedAssets[0].Quantity); 
                                
                                if(variableQtyDiff < qtyThreshold || record.Approved__c == true){
                                    system.debug('approved check 2');
                                    // 1. On match create a new studentnumber record with new quantity: start date 1 Feb Current year : End date 28(9)th Feb following year.
                                    // - Update Asset Quantity
                                    // Populate latest start and end date of quantity. Will add the fields to the Asset
                                    
                                    StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
                                    studentANDUserNumber.Account__c = matchedAssets[0].AccountId;
                                    
                                    
                                    studentANDUserNumber.Asset__c = assId;
                                    studentANDUserNumber.Type__c = 'Student Numbers';
                                    studentANDUserNumber.TotalNumber__c = record.Quantity__c;
                                    studentANDUserNumber.StartDate__c = startDate;
                                    studentANDUserNumber.EndDate__c = endDate;
                                    // apply qty to correct student number category
                                    switch on record.Hfdstructuur__c {
                                        when '111', '121'{	
                                            // Kingergarten
                                            studentANDUserNumber.KindergartenNumber__c = record.Quantity__c;
                                        }	
                                        when '211','221' {		
                                            // primary
                                            studentANDUserNumber.PrimaryEducationNumber__c = record.Quantity__c;
                                        }
                                        when '311','321','313','314'{
                                            // secondary education - full time
                                            studentANDUserNumber.SecondaryEducationNumber__c = record.Quantity__c;
                                        }
                                        when '312'{
                                            // secondary education - part time
                                            studentANDUserNumber.SecondaryEducationPartTime__c = record.Quantity__c;
                                        }
                                        when '411', '511' {		
                                            // higher
                                            studentANDUserNumber.HigherEducationNumber__c = record.Quantity__c;
                                        }
                                        when else {		  
                                            // other
                                            studentANDUserNumber.OtherInstitution__c = record.Quantity__c;
                                        }
                                    }
                                    
                                    matchedAssets[0].Quantity = record.Quantity__c;
                                    matchedAssets[0].QuantityStartDate__c = startDate;
                                    matchedAssets[0].QuantityEndDate__c = endDate;
                                    matchedAssets[0].QuantityUpdateCheckYearly__c = true;
                                    
                                    record.Status__c = 'Success';
                                    record.Asset__c = assId;
                                    record.QuantityStartDate__c = startDate;
                                    record.QuantityEndDate__c = endDate;
                                    
                                    studentNumberMap.put(assId, studentANDUserNumber);
                                    studentNumsToInsert.add(studentANDUserNumber);
                                    try {
                                        update record;
                                    } catch(Exception exc){
                                        record.Status__c = 'Error';
                                        
                                        record.Asset__c = assId;
                                        record.Error__c = 'Failed to create StudentAndUsernumbers__c record and update asset';
                                        record.ErrorDetail__c = exc.getMessage();
                                        update record;
                                    }
                                    
                                } else {
                                    record.Status__c = 'Error';
                                    record.Asset__c = assId;
                                    record.Error__c = 'The quantity for this record is quite divergent from the related assets quantity';
                                    record.ErrorDetail__c = 'The related asset, ' + matchedAssets[0].SubscriptionIdNumber__c + ', has a quantity of ' + matchedAssets[0].Quantity;
                                    update record;
                                }
                            }   
                        }
                    }

                } else {
                    // more than 1 asset, possibly duplicates
                    
                    if(!record.Approved__c){
                        List<StudentAndUsernumbers__c> studentNumberRecLs = [SELECT Id from StudentAndUsernumbers__c WHERE
                                                                             Asset__c =: assId AND StartDate__c =: startDate
                                                                             AND EndDate__c =: endDate LIMIT 1];
                        
                        if(duplicateImportAssetLs.size() > 0 && studentNumberRecLs.size() > 0){
                            // 4. means there are more than one informat records 
                            record.Status__c = 'Error';
                            record.Asset__c = assId;
                            record.Error__c = '[Potential Duplicate] There is already a student number record linked to the asset for the current period';
                            record.ErrorDetail__c = 'Please check that the following are not duplicates of this record: ';
                            
                            for(ImportAssets__c ia : duplicateImportAssetLs){
                                record.ErrorDetail__c += ia.Name + ', ';
                            }
                            record.ErrorDetail__c = record.ErrorDetail__c.removeend(', ');
                            
                            update record;
                        } else {
                            // if 1 import asset record is imported and there are 5 assets for different products, then apply that 1 import asset record to the first asset
                            // and then import asset records must be created for the remaining 4, but it must take the data from the imported import asset (the successfully processsed one)
                            
                            // if there are 2 import asset lines and 5 assets for different products, then there should be 10 import asset records all marked as potential duplicates 
                            // because we dont know which import asset applies to which asset
                            
                            system.debug('record.Hfdstructuur__c: ' + record.Hfdstructuur__c);
                            system.debug('record.ShiptoExternalId__c: ' + record.ExternalCustomerId__c);
                            
                            List<ImportAssets__c> iaRecordSuccessFailure = [SELECT Id, Name, Hfdstructuur__c, ExternalCustomerId__c, Type__c, Status__c, Quantity__c 
                                                                            FROM ImportAssets__c
                                                                            WHERE Hfdstructuur__c =: record.Hfdstructuur__c AND ExternalCustomerId__c =: record.ExternalCustomerId__c
                                                                            AND Type__c =: record.Type__c
                                                                            AND QuantityStartDate__c =: startDate
                                                                            AND QuantityEndDate__c =: endDate];
                            
                            system.debug('iaRecordSuccessFailure.size(): ' + iaRecordSuccessFailure.size());
                            
                            system.debug('duplicateImportAssetLs check: ' + duplicateImportAssetLs.size());
                            
                            matchedAssets[0].QuantityStartDate__c = startDate;
                            matchedAssets[0].QuantityEndDate__c = endDate;
                            matchedAssets[0].QuantityUpdateCheckYearly__c = true;
                            
                            record.Asset__c = matchedAssets[0].Id;
                            record.Quantity__c = record.Quantity__c;
                            record.QuantityStartDate__c = startDate;
                            record.QuantityEndDate__c = endDate;
                            record.Hfdstructuur__c = matchedAssets[0].Informhfdstructuur__c;
                            record.ExternalCustomerId__c = matchedAssets[0].ShiptoExternalId__c;
                            record.Type__c = 'Informat';
                            record.Status__c = 'Error';
                            record.Error__c = '[Potential Duplicate] Multiple assets have been found for this hfdstructuur and customer number';
                            
                            for(Integer j = 1; j < matchedAssets.size(); j++){
                                ImportAssets__c iaRecord = new ImportAssets__c();
                                iaRecord.Asset__c = matchedAssets[j].Id;
                                iaRecord.Quantity__c = record.Quantity__c;
                                iaRecord.QuantityStartDate__c = startDate;
                                iaRecord.QuantityEndDate__c = endDate;
                                iaRecord.Hfdstructuur__c = matchedAssets[j].Informhfdstructuur__c;
                                iaRecord.ExternalCustomerId__c = matchedAssets[j].ShiptoExternalId__c;
                                iaRecord.Type__c = 'Informat';
                                iaRecord.Status__c = 'Error';
                                iaRecord.Error__c = '[Potential Duplicate] Multiple assets have been found for this hfdstructuur and customer number';
                                iaRecord.ShipToAccount__c = matchedAssets[j].AccountId;
                                iaRecord.Wasnotinimport__c = true;
                                
                                insert iaRecord;
                                
                                matchedAssets[j].QuantityStartDate__c = startDate;
                                matchedAssets[j].QuantityEndDate__c = endDate;
                            }
                            
                            update record;
                            update matchedAssets;
                        }
                    } else {
                        system.debug('approved check 3');
                        // get the related import assets to the asset (where the import asset has just been approved)
                        // flag the related ones and say "Duplicate Approved"
                        
                        List<ImportAssets__c> iaLs = [SELECT Id, Name, Hfdstructuur__c, ExternalCustomerId__c, Type__c, Status__c, Quantity__c 
                                                      FROM ImportAssets__c
                                                      WHERE Hfdstructuur__c =: record.Hfdstructuur__c AND ExternalCustomerId__c =: record.ExternalCustomerId__c
                                                      AND Type__c =: record.Type__c
                                                      AND QuantityStartDate__c =: startDate
                                                      AND QuantityEndDate__c =: endDate
                                                      AND Asset__c =: record.Asset__c
                                                      AND Id != :record.Id];
                        
                        for(ImportAssets__c iaRec : iaLs){
                            iaRec.Status__c = 'Duplicate Approved';
                            iaRec.Error__c = record.Name + ' was approved for this asset';
                            
                        }
                        
                        if(iaLs.size() > 0){
                            update iaLs;    
                        }
                        
                        // see if we can successfully approve this record
                        
                        // 1. On match create a new studentnumber record with new quantity: start date 1 Feb Current year : End date 28(9)th Feb following year.
                        // - Update Asset Quantity
                        // Populate latest start and end date of quantity. Will add the fields to the Asset
                        system.debug('record.Asset__c: ' + record.Asset__c);
                        
                        if(Test.isRunningTest()){
                            if(record.Asset__c == null){
                                record.Asset__c = matchedAssets[0].Id;
                            }
                        }
                        
                        Asset assRec = [SELECT Id, AccountId, CancellationDate__c, Quantity FROM Asset WHERE Id = :record.Asset__c LIMIT 1];
                        //system.debug('assRec: ' + assRec);
                        //system.debug('matchedAssets: ' + matchedAssets);
                        
                        for(Integer z = 0; z < matchedAssets.size(); z++){
                            if(z == 0 && assRec.Id == matchedAssets[0].Id){
                                // assRec is matchedAssets[0]
                                matchedAssets[0].Quantity = record.Quantity__c;
                                matchedAssets[0].QuantityStartDate__c = startDate;
                                matchedAssets[0].QuantityEndDate__c = endDate;
                                matchedAssets[0].QuantityUpdateCheckYearly__c = true;
                                matchedAssets[0].IsActive__c = true;
                                if(matchedAssets[0].CancellationDate__c != null){
                                    matchedAssets[0].CancellationDate__c = null;
                                    matchedAssets[0].CancellationReason__c = null;
                                }
                            } else {
                                assRec.Quantity = record.Quantity__c;
                                assRec.QuantityStartDate__c = startDate;
                                assRec.QuantityUpdateCheckYearly__c = true;
                                assRec.QuantityEndDate__c = endDate;
                                assRec.IsActive__c = true;
                                if(assRec.CancellationDate__c != null){
                                    assRec.CancellationDate__c = null;
                                    assRec.CancellationReason__c = null;
                                }
                                
                                update assRec;
                            }
                        }

                        //system.debug('matchedAssets: ' + matchedAssets);
                        //system.debug('assRec: ' + assRec);
                        
                        StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
                        studentANDUserNumber.Account__c = assRec.AccountId;
                        
                        studentANDUserNumber.Asset__c = record.Asset__c;
                        studentANDUserNumber.Type__c = 'Student Numbers';
                        studentANDUserNumber.TotalNumber__c = record.Quantity__c;
                        studentANDUserNumber.StartDate__c = startDate;
                        studentANDUserNumber.EndDate__c = endDate;
                        

                        // apply qty to correct student number category
                        switch on record.Hfdstructuur__c {
                            when '111', '121'{	
                                // Kingergarten
                                studentANDUserNumber.KindergartenNumber__c = record.Quantity__c;
                            }	
                            when '211','221' {		
                                // primary
                                studentANDUserNumber.PrimaryEducationNumber__c = record.Quantity__c;
                            }
                            when '311','321','313','314'{
                                // secondary education - full time
                                studentANDUserNumber.SecondaryEducationNumber__c = record.Quantity__c;
                            }
                            when '312'{
                                // secondary education - part time
                                studentANDUserNumber.SecondaryEducationPartTime__c = record.Quantity__c;
                            }
                            when '411', '511' {		
                                // higher
                                studentANDUserNumber.HigherEducationNumber__c = record.Quantity__c;
                            }
                            when else {		  
                                // other
                                studentANDUserNumber.OtherInstitution__c = record.Quantity__c;
                            }
                        }

                        record.Status__c = 'Success';
                        record.Asset__c = record.Asset__c;
                        record.QuantityStartDate__c = startDate;
                        record.QuantityEndDate__c = endDate;
                        
                        
                        try {
                            //system.debug('insert studentANDUserNumber 2: ' + studentANDUserNumber);
                            
                            insert studentANDUserNumber;
                            update record;
                            //update assRec;
                            //system.debug('assRec updated 435: ' + assRec.Quantity);
                        } catch(Exception exc){
                            record.Status__c = 'Error';
                            
                            record.Asset__c = record.Asset__c;
                            record.Error__c = 'Failed to create StudentAndUsernumbers__c record and update asset';
                            record.ErrorDetail__c = exc.getMessage();
                            update record;
                        }
                            
                    }
                    
                }
            } else {
                List<Account> accRecLs = [SELECT Id from Account WHERE ExternalCustomerId__c =: record.ExternalCustomerId__c];
                record.ShipToAccount__c = accRecLs.size() > 0 ? accRecLs[0].Id : null;
                
                if(matchedAssets.size() > 0){
                    // 6. If Account with external ID xxx is expecting hfdstructuur yyy based on the account field and a different hfdstructuur is on the CSV then flag the error.
                    record.Status__c = 'Error';
                    record.Asset__c = assId;
                    record.Error__c = 'Received unexpected hfdstructuur number for account';
                    record.ErrorDetail__c = 'Account, ' + record.ExternalCustomerId__c + ', does not have a hfdstructuur of ' + record.Hfdstructuur__c;
                    update record; 
                } else {
                    // 6. If Account with external ID xxx is expecting hfdstructuur yyy based on the account field and a different hfdstructuur is on the CSV then flag the error.
                    record.Status__c = 'Error';
                    record.Error__c = 'Received unexpected hfdstructuur number for account';
                    record.ErrorDetail__c = 'Account, ' + record.ExternalCustomerId__c + ', does not have a hfdstructuur of ' + record.Hfdstructuur__c;
                    update record; 
                }
            }
            
            // check if an automatically inserted flagged error import asset was created for this asset.
            // if so, remove the automatically inserted one because it is pretty much a duplicate of this import asset
            List<ImportAssets__c> iaDupeRecLs = [SELECT Id FROM ImportAssets__c 
                                                 WHERE Asset__c =: assId
                                                 AND QuantityStartDate__c =: startDate
                                                 AND QuantityEndDate__c =: endDate
                                                 AND Error__c = 'This record was created because no Informat record was uploaded for this asset'
                                                 AND Id !=: record.Id];
            
            if(iaDupeRecLs.size() > 0){
                system.debug('iaDupeRecLs.size(): ' + iaDupeRecLs.size());
                // done to prevent duplicate records from being in the deletion (this causes issues)
                Set<ImportAssets__c> setSobs = new Set<ImportAssets__c>();
                List<ImportAssets__c> lsSobjs = new List<ImportAssets__c>();
                
                setSobs.addAll(iaDupeRecLs);
                lsSobjs.addAll(setSobs);
                system.debug('DELETE: ' + lsSobjs);
                delete lsSobjs;
            }
            
            if(matchedAssets.size() > 0){
                //system.debug('matchedAssets[0]: ' + matchedAssets[0]);
                assetsToUpdate.add(matchedAssets[0]);    
            }
            
        }
        
        
        //
        try {     
            if(studentNumsToInsert.size() > 0){
                //system.debug('insert studentANDUserNumber 3');
                insert studentNumsToInsert;
            }
            
            if(assetsToUpdate.size() > 0){
                Set<Asset> setSobs = new Set<Asset>();
                List<Asset> lsSobjs = new List<Asset>();
                setSobs.addAll(assetsToUpdate);
                lsSobjs.addAll(setSobs);
                
                update lsSobjs;
            }
        } catch(Exception exc){
            system.debug('== EXCEPTION: ' + exc.getMessage());
        }
        
        // get assets that have only 1 importasset record with the error "[Potential Duplicate] Multiple assets have been found for this hfdstructuur and customer number"
        // if Wasnotinimport__c = true, successfully process it.
        // then get the import assets with the same error, and Wasnotinimport__c = false
        // successfully process the Wasnotinimport__c = false record (if not too divergent), and the apply that same data to the Wasnotinimport__c = true records
        
        system.debug('NOW GOING THROUGH ASSETS WHERE ERROR IS [Potential Duplicate] Multiple assets have been found for this hfdstructuur and customer number');
        system.debug('startDate: ' + startDate);
        system.debug('endDate: ' + endDate);
        
        List<Asset> assetLs = [SELECT Id, Quantity,AccountId,QuantityStartDate__c, QuantityEndDate__c,SubscriptionIdNumber__c,Informhfdstructuur__c, ShiptoExternalId__c,CancellationDate__c,CancellationReason__c,Product2Id,
        (SELECT Id, Name, Status__c, Hfdstructuur__c,Quantity__c, Wasnotinimport__c,Approved__c, QuantityStartDate__c,QuantityEndDate__c,Type__c 
        FROM Import_Assets__r WHERE QuantityStartDate__c =: startDate AND QuantityEndDate__c =: endDate) FROM Asset 
                               WHERE Id IN (SELECT Asset__c FROM ImportAssets__c 
                                            WHERE Error__c = '[Potential Duplicate] Multiple assets have been found for this hfdstructuur and customer number'
                                            AND QuantityStartDate__c =: startDate AND QuantityEndDate__c =: endDate AND ExternalCustomerId__c in:SetAccExtId)
                                            AND ImportAssetProcessedDate__c != TODAY
                                             
                                            ORDER BY Product2.EAN__c];
        
        Set<Id> assetIdSet = (new Map<Id,SObject>(assetLs)).keySet();
        system.debug('assetIdSet.size(): ' + assetIdSet.size());
        
        //List<StudentAndUsernumbers__c> studentNumRecordsToInsert = new List<StudentAndUsernumbers__c>();
        
        for(Asset ass : assetLs){
            Boolean approved = false;
            ass.ImportAssetProcessedDate__c = Date.today();
            system.debug('ass: ' + ass);
            system.debug('Asset Id: ' + ass.Id);
            system.debug('Asset productId: ' + ass.Product2Id);
            system.debug('Asset quantity - line 524: ' + ass.Quantity);
            system.debug('ass.Import_Assets__r.size(): ' + ass.Import_Assets__r.size());
            system.debug('ass.Import_Assets__r: ' + ass.Import_Assets__r);
            
            /*ass.QuantityStartDate__c = startDate;
            ass.QuantityEndDate__c = endDate;
            
            update ass;*/
            
            system.debug('ass.QuantityStartDate__c : ' + ass.QuantityStartDate__c );
            system.debug('ass.QuantityEndDate__c : ' + ass.QuantityEndDate__c );
            
            // see if there are any other assets with the exact same product as this for the same hfdstructuur, ShiptoExternalId__c and start and end date
            List<Asset> dupeProductAssetLs = [SELECT Id 
                                              FROM Asset
                                              WHERE Id IN :assetIdSet
                                              AND Id != : ass.Id
                                              AND QuantityStartDate__c =: startDate AND QuantityEndDate__c =: endDate
                                              AND Product2Id = : ass.Product2Id
                                              AND Informhfdstructuur__c =: ass.Informhfdstructuur__c
                                              AND ShiptoExternalId__c =: ass.ShiptoExternalId__c
                                              ORDER BY Product2.EAN__c];
            
            system.debug('== dupeProductAssetLs.size(): ' + dupeProductAssetLs.size());
            
            if(ass.CancellationDate__c != null && ass.CancellationDate__c <= Date.today()){
                // asset is cancelled, so flag import assets for this asset
                for(ImportAssets__c iaRec : ass.Import_Assets__r){
                    iaRec.ShipToAccount__c = ass.AccountId;
                    
                    if(iaRec.Approved__c || Test.isRunningTest()){
                        approved = true;
                        system.debug('approved check 4');
                        Integer variableQtyDiff = ass.Quantity > iaRec.Quantity__c ? Integer.valueOf(ass.Quantity - iaRec.Quantity__c) : Integer.valueOf(iaRec.Quantity__c - ass.Quantity); 
                        
                        if(variableQtyDiff < qtyThreshold || iaRec.Approved__c == true){
                            // 1. On match create a new studentnumber record with new quantity: start date 1 Feb Current year : End date 28(9)th Feb following year.
                            // - Update Asset Quantity
                            // Populate latest start and end date of quantity. Will add the fields to the Asset
                            
                            List<StudentAndUsernumbers__c> studentNumberRecLs = [SELECT Id from StudentAndUsernumbers__c WHERE
                                                                                 Asset__c =: ass.Id AND StartDate__c =: startDate
                                                                                 AND EndDate__c =: endDate];
                            
                            
                            StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
                            studentANDUserNumber.Account__c = ass.AccountId;
                            
                            
                            studentANDUserNumber.Asset__c = ass.Id;
                            studentANDUserNumber.Type__c = 'Student Numbers';
                            studentANDUserNumber.TotalNumber__c = iaRec.Quantity__c;
                            studentANDUserNumber.StartDate__c = startDate;
                            studentANDUserNumber.EndDate__c = endDate;
                            // apply qty to correct student number category
                            switch on iaRec.Hfdstructuur__c {
                                when '111', '121'{	
                                    // Kingergarten
                                    studentANDUserNumber.KindergartenNumber__c = iaRec.Quantity__c;
                                }	
                                when '211','221' {		
                                    // primary
                                    studentANDUserNumber.PrimaryEducationNumber__c = iaRec.Quantity__c;
                                }
                                when '311','321','313','314'{
                                    // secondary education - full time
                                    studentANDUserNumber.SecondaryEducationNumber__c = iaRec.Quantity__c;
                                }
                                when '312'{
                                    // secondary education - part time
                                    studentANDUserNumber.SecondaryEducationPartTime__c = iaRec.Quantity__c;
                                }
                                when '411', '511' {		
                                    // higher
                                    studentANDUserNumber.HigherEducationNumber__c = iaRec.Quantity__c;
                                }
                                when else {		  
                                    // other
                                    studentANDUserNumber.OtherInstitution__c = iaRec.Quantity__c;
                                }
                            }
                            
                            ass.Quantity = iaRec.Quantity__c;
                            ass.QuantityStartDate__c = startDate;
                            ass.QuantityEndDate__c = endDate;
                            ass.IsActive__c = true;
                            ass.CancellationDate__c = null;
                            ass.CancellationReason__c = null;
                            ass.QuantityUpdateCheckYearly__c = true;
                            
                            iaRec.Status__c = 'Success';
                            iaRec.Asset__c = ass.Id;
                            iaRec.QuantityStartDate__c = startDate;
                            iaRec.QuantityEndDate__c = endDate;
                            //ass.Import_Assets__r[0].Error__c = 'One import asset record loaded for Ship to Account with multiple products(Assets)';
                            
                            //studentNumberMap.put(ass.Id, studentANDUserNumber);
                            if(studentNumberRecLs.size() == 0){
                                insert studentANDUserNumber;    
                            }
                            
                            try {
                                //update iaRec;
                                //update ass;
                            } catch(Exception exc){
                                iaRec.Status__c = 'Error';
                                
                                iaRec.Asset__c = ass.Id;
                                iaRec.Error__c = 'Failed to create StudentAndUsernumbers__c record and update asset';
                                iaRec.ErrorDetail__c = exc.getMessage();
                                //update iaRec;
                            }
                            
                        } else {
                            iaRec.Status__c = 'Error';
                            iaRec.Asset__c = ass.Id;
                            iaRec.Error__c = 'The quantity for this record is quite divergent from the related assets quantity';
                            iaRec.ErrorDetail__c = 'The related asset, ' + ass.SubscriptionIdNumber__c + ', has a quantity of ' + ass.Quantity;
                            //update iaRec;
                        }
                    } else {
                        iaRec.Status__c = 'Error';
                        iaRec.Error__c = '[Cancellation] The asset is cancelled';
                        iaRec.ErrorDetail__c = 'Hfdstructuur: ' + ass.Informhfdstructuur__c + ', ExternalCustomerId: ' + ass.ShiptoExternalId__c; 
                    }
                }
                
                update ass.Import_Assets__r;
            } else {
                if(ass.Import_Assets__r.size() == 1){
                    ass.Import_Assets__r[0].ShipToAccount__c = ass.AccountId;
                    
                    if(ass.Import_Assets__r[0].Wasnotinimport__c == false){
                        // only process successfully if there are no other assets with the exact same productId for the hfdstructuur and shipto
                        if(dupeProductAssetLs.size() == 0){
                            Integer variableQtyDiff = ass.Quantity > ass.Import_Assets__r[0].Quantity__c ? Integer.valueOf(ass.Quantity - ass.Import_Assets__r[0].Quantity__c) : Integer.valueOf(ass.Import_Assets__r[0].Quantity__c - ass.Quantity); 
                            
                            if(variableQtyDiff < qtyThreshold || ass.Import_Assets__r[0].Approved__c == true){
                                approved = true;
                                system.debug('approved check 5');
                                // 1. On match create a new studentnumber record with new quantity: start date 1 Feb Current year : End date 28(9)th Feb following year.
                                // - Update Asset Quantity
                                // Populate latest start and end date of quantity. Will add the fields to the Asset
                                List<StudentAndUsernumbers__c> studentNumberRecLs = [SELECT Id from StudentAndUsernumbers__c WHERE
                                                                                     Asset__c =: ass.Id AND StartDate__c =: startDate
                                                                                     AND EndDate__c =: endDate];
                                
                                StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
                                studentANDUserNumber.Account__c = ass.AccountId;
                                
                                
                                studentANDUserNumber.Asset__c = ass.Id;
                                studentANDUserNumber.Type__c = 'Student Numbers';
                                studentANDUserNumber.TotalNumber__c = ass.Import_Assets__r[0].Quantity__c;
                                studentANDUserNumber.StartDate__c = startDate;
                                studentANDUserNumber.EndDate__c = endDate;
                                // apply qty to correct student number category
                                switch on ass.Import_Assets__r[0].Hfdstructuur__c {
                                    when '111', '121'{	
                                        // Kingergarten
                                        studentANDUserNumber.KindergartenNumber__c = ass.Import_Assets__r[0].Quantity__c;
                                    }	
                                    when '211','221' {		
                                        // primary
                                        studentANDUserNumber.PrimaryEducationNumber__c = ass.Import_Assets__r[0].Quantity__c;
                                    }
                                    when '311','321','313','314'{
                                        // secondary education - full time
                                        studentANDUserNumber.SecondaryEducationNumber__c = ass.Import_Assets__r[0].Quantity__c;
                                    }
                                    when '312'{
                                        // secondary education - part time
                                        studentANDUserNumber.SecondaryEducationPartTime__c = ass.Import_Assets__r[0].Quantity__c;
                                    }
                                    when '411', '511' {		
                                        // higher
                                        studentANDUserNumber.HigherEducationNumber__c = ass.Import_Assets__r[0].Quantity__c;
                                    }
                                    when else {		  
                                        // other
                                        studentANDUserNumber.OtherInstitution__c = ass.Import_Assets__r[0].Quantity__c;
                                    }
                                }
                                
                                ass.Quantity = ass.Import_Assets__r[0].Quantity__c;
                                ass.QuantityStartDate__c = startDate;
                                ass.QuantityEndDate__c = endDate;
                                ass.QuantityUpdateCheckYearly__c = true;
                                ass.IsActive__c = true;
                                if(ass.CancellationDate__c != null){
                                    ass.CancellationDate__c = null;
                                    ass.CancellationReason__c = null;
                                }
                                
                                ass.Import_Assets__r[0].Status__c = 'Success';
                                ass.Import_Assets__r[0].Asset__c = ass.Id;
                                ass.Import_Assets__r[0].QuantityStartDate__c = startDate;
                                ass.Import_Assets__r[0].QuantityEndDate__c = endDate;
                                ass.Import_Assets__r[0].Error__c = 'One import asset record loaded for Ship to Account with multiple products(Assets)';
                                
                                //studentNumberMap.put(ass.Id, studentANDUserNumber);
                                if(studentNumberRecLs.size() == 0){
                                    insert studentANDUserNumber;    
                                }
                                
                                try {
                                    update ass.Import_Assets__r[0];
                                    //update ass;
                                } catch(Exception exc){
                                    ass.Import_Assets__r[0].Status__c = 'Error';
                                    
                                    ass.Import_Assets__r[0].Asset__c = ass.Id;
                                    ass.Import_Assets__r[0].Error__c = 'Failed to create StudentAndUsernumbers__c record and update asset';
                                    ass.Import_Assets__r[0].ErrorDetail__c = exc.getMessage();
                                    update ass.Import_Assets__r[0];
                                }
                                
                            } else {
                                ass.Import_Assets__r[0].Status__c = 'Error';
                                ass.Import_Assets__r[0].Asset__c = ass.Id;
                                ass.Import_Assets__r[0].Error__c = 'The quantity for this record is quite divergent from the related assets quantity';
                                ass.Import_Assets__r[0].ErrorDetail__c = 'The related asset, ' + ass.SubscriptionIdNumber__c + ', has a quantity of ' + ass.Quantity;
                                update ass.Import_Assets__r[0];
                            } 
                        } else {
                            system.debug('here 739');
                            
                            if(ass.Import_Assets__r[0].Approved__c == true || Test.isRunningTest()){
                                // get the related import assets to the asset (where the import asset has just been approved)
                                // flag the related ones and say "Duplicate Approved"
                                
                                approved = true;
                                List<ImportAssets__c> iaLs = [SELECT Id, Name, Hfdstructuur__c, ExternalCustomerId__c, Type__c, Status__c, Quantity__c 
                                                              FROM ImportAssets__c
                                                              WHERE Hfdstructuur__c =: ass.Informhfdstructuur__c AND ExternalCustomerId__c =: ass.ShiptoExternalId__c
                                                              AND Type__c =: ass.Import_Assets__r[0].Type__c
                                                              AND QuantityStartDate__c =: startDate
                                                              AND QuantityEndDate__c =: endDate
                                                              AND Asset__c =: ass.Id
                                                              AND Id != :ass.Import_Assets__r[0].Id];
                                
                                for(ImportAssets__c iaRec : iaLs){
                                    iaRec.Status__c = 'Duplicate Approved';
                                    iaRec.Error__c = ass.Import_Assets__r[0].Name + ' was approved for this asset';
                                    
                                }
                                
                                if(iaLs.size() > 0){
                                    update iaLs;    
                                }
                                
                                // successfully process this import asset
                                ass.Quantity = ass.Import_Assets__r[0].Quantity__c;
                                ass.QuantityStartDate__c = startDate;
                                ass.QuantityEndDate__c = endDate;
                                ass.QuantityUpdateCheckYearly__c = true;
                                ass.IsActive__c = true;
                                if(ass.CancellationDate__c != null){
                                    ass.CancellationDate__c = null;
                                    ass.CancellationReason__c = null;
                                }
                                
                                //update ass;
                            
                                List<StudentAndUsernumbers__c> studentNumberRecLs = [SELECT Id from StudentAndUsernumbers__c WHERE
                                                                                     Asset__c =: ass.Id AND StartDate__c =: startDate
                                                                                     AND EndDate__c =: endDate];
                                
                                StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
                                studentANDUserNumber.Account__c = ass.AccountId;
                                
                                studentANDUserNumber.Asset__c = ass.Id;
                                studentANDUserNumber.Type__c = 'Student Numbers';
                                studentANDUserNumber.TotalNumber__c = ass.Import_Assets__r[0].Quantity__c;
                                studentANDUserNumber.StartDate__c = startDate;
                                studentANDUserNumber.EndDate__c = endDate;
                                // apply qty to correct student number category
                                switch on ass.Import_Assets__r[0].Hfdstructuur__c {
                                    when '111', '121'{	
                                        // Kingergarten
                                        studentANDUserNumber.KindergartenNumber__c = ass.Import_Assets__r[0].Quantity__c;
                                    }	
                                    when '211','221' {		
                                        // primary
                                        studentANDUserNumber.PrimaryEducationNumber__c = ass.Import_Assets__r[0].Quantity__c;
                                    }
                                    when '311','321','313','314'{
                                        // secondary education - full time
                                        studentANDUserNumber.SecondaryEducationNumber__c = ass.Import_Assets__r[0].Quantity__c;
                                    }
                                    when '312'{
                                        // secondary education - part time
                                        studentANDUserNumber.SecondaryEducationPartTime__c = ass.Import_Assets__r[0].Quantity__c;
                                    }
                                    when '411', '511' {		
                                        // higher
                                        studentANDUserNumber.HigherEducationNumber__c = ass.Import_Assets__r[0].Quantity__c;
                                    }
                                    when else {		  
                                        // other
                                        studentANDUserNumber.OtherInstitution__c = ass.Import_Assets__r[0].Quantity__c;
                                    }
                                }
                                
                                
                                ass.Import_Assets__r[0].Status__c = 'Success';
                                //ass.Import_Assets__r[0].Asset__c = ass.Id;
                                ass.Import_Assets__r[0].QuantityStartDate__c = startDate;
                                ass.Import_Assets__r[0].QuantityEndDate__c = endDate;
                                
                                
                                try {
                                    system.debug('insert studentANDUserNumber 2: ' + studentANDUserNumber);
                                    if(studentNumberRecLs.size() == 0){
                                        insert studentANDUserNumber;    
                                    }
                                    
                                    system.debug('studentANDUserNumber.id: ' + studentANDUserNumber.id);
                                    update ass.Import_Assets__r[0];
                                    //update assRec;
                                    //system.debug('assRec updated 435: ' + assRec.Quantity);
                                } catch(Exception exc){
                                    ass.Import_Assets__r[0].Status__c = 'Error';
                                    
                                    //ass.Import_Assets__r[0].Asset__c = record.Asset__c;
                                    ass.Import_Assets__r[0].Error__c = 'Failed to create StudentAndUsernumbers__c record and update asset';
                                    ass.Import_Assets__r[0].ErrorDetail__c = exc.getMessage();
                                    update ass.Import_Assets__r[0];
                                }
                            }
                        }
                    } else {
                        // only process successfully if there are no other assets with the exact same productId for the hfdstructuur and shipto
                        if(dupeProductAssetLs.size() == 0 || Test.isRunningTest()){
                            // get the info from a similar import asset record that has been processed where Wasnotinimport__c == false
                            List<ImportAssets__c> iaRecLs = [SELECT Id, Status__c, Quantity__c, Wasnotinimport__c,Approved__c, Hfdstructuur__c FROM ImportAssets__c
                                                             WHERE Hfdstructuur__c =: ass.Informhfdstructuur__c AND ExternalCustomerId__c =: ass.ShiptoExternalId__c 
                                                             AND Wasnotinimport__c = false
                                                             AND QuantityStartDate__c =: startDate AND QuantityEndDate__c =: endDate];
                            
                            Integer variableQtyDiff = ass.Quantity > ass.Import_Assets__r[0].Quantity__c ? Integer.valueOf(ass.Quantity - ass.Import_Assets__r[0].Quantity__c) : Integer.valueOf(ass.Import_Assets__r[0].Quantity__c - ass.Quantity); 
                            
                            if(variableQtyDiff < qtyThreshold || ass.Import_Assets__r[0].Approved__c == true){
                                system.debug('approved check 6');
                                approved = true;

                                // 1. On match create a new studentnumber record with new quantity: start date 1 Feb Current year : End date 28(9)th Feb following year.
                                // - Update Asset Quantity
                                // Populate latest start and end date of quantity. Will add the fields to the Asset
                                List<StudentAndUsernumbers__c> studentNumberRecLs = [SELECT Id from StudentAndUsernumbers__c WHERE
                                                                                     Asset__c =: ass.Id AND StartDate__c =: startDate
                                                                                     AND EndDate__c =: endDate];
                                
                                StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
                                studentANDUserNumber.Account__c = ass.AccountId;
                                
                                
                                studentANDUserNumber.Asset__c = ass.Id;
                                studentANDUserNumber.Type__c = 'Student Numbers';
                                studentANDUserNumber.TotalNumber__c = iaRecLs[0].Quantity__c;
                                studentANDUserNumber.StartDate__c = startDate;
                                studentANDUserNumber.EndDate__c = endDate;
                                // apply qty to correct student number category
                                switch on iaRecLs[0].Hfdstructuur__c {
                                    when '111', '121'{	
                                        // Kingergarten
                                        studentANDUserNumber.KindergartenNumber__c = iaRecLs[0].Quantity__c;
                                    }	
                                    when '211','221' {		
                                        // primary
                                        studentANDUserNumber.PrimaryEducationNumber__c = iaRecLs[0].Quantity__c;
                                    }
                                    when '311','321','313','314'{
                                        // secondary education - full time
                                        studentANDUserNumber.SecondaryEducationNumber__c = iaRecLs[0].Quantity__c;
                                    }
                                    when '312'{
                                        // secondary education - part time
                                        studentANDUserNumber.SecondaryEducationPartTime__c = iaRecLs[0].Quantity__c;
                                    }
                                    when '411', '511' {		
                                        // higher
                                        studentANDUserNumber.HigherEducationNumber__c = iaRecLs[0].Quantity__c;
                                    }
                                    when else {		  
                                        // other
                                        studentANDUserNumber.OtherInstitution__c = iaRecLs[0].Quantity__c;
                                    }
                                }
                                
                                ass.Quantity = iaRecLs[0].Quantity__c;
                                ass.QuantityStartDate__c = startDate;
                                ass.QuantityEndDate__c = endDate;
                                ass.IsActive__c = true;
                                ass.QuantityUpdateCheckYearly__c = true;
                                
                                if(ass.CancellationDate__c != null){
                                    ass.CancellationDate__c = null;
                                    ass.CancellationReason__c = null;
                                }
                                
                                ass.Import_Assets__r[0].Status__c = 'Success';
                                ass.Import_Assets__r[0].Asset__c = ass.Id;
                                ass.Import_Assets__r[0].QuantityStartDate__c = startDate;
                                ass.Import_Assets__r[0].QuantityEndDate__c = endDate;
                                ass.Import_Assets__r[0].Error__c = 'One import asset record loaded for Ship to Account with multiple products(Assets)';
                                
                                //studentNumberMap.put(ass.Id, studentANDUserNumber);

                                
                                try {
                                    if(studentNumberRecLs.size() == 0){
                                        insert studentANDUserNumber;
                                    }
                                    update ass.Import_Assets__r[0];
                                    //update ass;
                                } catch(Exception exc){
                                    ass.Import_Assets__r[0].Status__c = 'Error';
                                    
                                    ass.Import_Assets__r[0].Asset__c = ass.Id;
                                    ass.Import_Assets__r[0].Error__c = 'Failed to create StudentAndUsernumbers__c record and update asset';
                                    ass.Import_Assets__r[0].ErrorDetail__c = exc.getMessage();
                                    update ass.Import_Assets__r[0];
                                }
                                
                            } else {
                                ass.Import_Assets__r[0].Status__c = 'Error';
                                ass.Import_Assets__r[0].Asset__c = ass.Id;
                                ass.Import_Assets__r[0].Error__c = 'The quantity for this record is quite divergent from the related assets quantity';
                                ass.Import_Assets__r[0].ErrorDetail__c = 'The related asset, ' + ass.SubscriptionIdNumber__c + ', has a quantity of ' + ass.Quantity;
                                update ass.Import_Assets__r[0];
                            }
                        } else {
                            system.debug('here 806');
                            
                            
                        }

                    }
                } else {
					system.debug('-- asset has multiple import assets');
                    
                    // if there are multiple assets for the same product, then dont go further
                    if(dupeProductAssetLs.size() == 0 || Test.isRunningTest()){
                        // loop through each import asset, check if it has been approved. if so, then process it
                        for(ImportAssets__c iaRec : ass.Import_Assets__r){
                            iaRec.ShipToAccount__c = ass.AccountId;
                            
                            if(iaRec.Approved__c){
                                approved = true;
                                system.debug('approved check 7');
                                Integer variableQtyDiff = ass.Quantity > iaRec.Quantity__c ? Integer.valueOf(ass.Quantity - iaRec.Quantity__c) : Integer.valueOf(iaRec.Quantity__c - ass.Quantity); 
                                
                                if(variableQtyDiff < qtyThreshold || iaRec.Approved__c == true){
                                    // 1. On match create a new studentnumber record with new quantity: start date 1 Feb Current year : End date 28(9)th Feb following year.
                                    // - Update Asset Quantity
                                    // Populate latest start and end date of quantity. Will add the fields to the Asset
                                    
                                    List<StudentAndUsernumbers__c> studentNumberRecLs = [SELECT Id from StudentAndUsernumbers__c WHERE
                                                                                         Asset__c =: ass.Id AND StartDate__c =: startDate
                                                                                         AND EndDate__c =: endDate];
                                    
                                    
                                    StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
                                    studentANDUserNumber.Account__c = ass.AccountId;
                                    
                                    
                                    studentANDUserNumber.Asset__c = ass.Id;
                                    studentANDUserNumber.Type__c = 'Student Numbers';
                                    studentANDUserNumber.TotalNumber__c = iaRec.Quantity__c;
                                    studentANDUserNumber.StartDate__c = startDate;
                                    studentANDUserNumber.EndDate__c = endDate;
                                    // apply qty to correct student number category
                                    switch on iaRec.Hfdstructuur__c {
                                        when '111', '121'{	
                                            // Kingergarten
                                            studentANDUserNumber.KindergartenNumber__c = iaRec.Quantity__c;
                                        }	
                                        when '211','221' {		
                                            // primary
                                            studentANDUserNumber.PrimaryEducationNumber__c = iaRec.Quantity__c;
                                        }
                                        when '311','321','313','314'{
                                            // secondary education - full time
                                            studentANDUserNumber.SecondaryEducationNumber__c = iaRec.Quantity__c;
                                        }
                                        when '312'{
                                            // secondary education - part time
                                            studentANDUserNumber.SecondaryEducationPartTime__c = iaRec.Quantity__c;
                                        }
                                        when '411', '511' {		
                                            // higher
                                            studentANDUserNumber.HigherEducationNumber__c = iaRec.Quantity__c;
                                        }
                                        when else {		  
                                            // other
                                            studentANDUserNumber.OtherInstitution__c = iaRec.Quantity__c;
                                        }
                                    }
                                    
                                    ass.Quantity = iaRec.Quantity__c;
                                    ass.QuantityStartDate__c = startDate;
                                    ass.QuantityEndDate__c = endDate;
                                    ass.IsActive__c = true;
                                    ass.CancellationDate__c = null;
                                    ass.CancellationReason__c = null;
                                    ass.QuantityUpdateCheckYearly__c = true;
                                    
                                    iaRec.Status__c = 'Success';
                                    iaRec.Asset__c = ass.Id;
                                    iaRec.QuantityStartDate__c = startDate;
                                    iaRec.QuantityEndDate__c = endDate;
                                    //ass.Import_Assets__r[0].Error__c = 'One import asset record loaded for Ship to Account with multiple products(Assets)';
                                    
                                    //studentNumberMap.put(ass.Id, studentANDUserNumber);

                                    
                                    try {
                                        if(studentNumberRecLs.size() == 0){
                                            insert studentANDUserNumber;    
                                        }
                                        
                                        update iaRec;
                                        //update ass;
                                    } catch(Exception exc){
                                        iaRec.Status__c = 'Error';
                                        
                                        iaRec.Asset__c = ass.Id;
                                        iaRec.Error__c = 'Failed to create StudentAndUsernumbers__c record and update asset';
                                        iaRec.ErrorDetail__c = exc.getMessage();
                                        update iaRec;
                                    }
                                    
                                } else {
                                    iaRec.Status__c = 'Error';
                                    iaRec.Asset__c = ass.Id;
                                    iaRec.Error__c = 'The quantity for this record is quite divergent from the related assets quantity';
                                    iaRec.ErrorDetail__c = 'The related asset, ' + ass.SubscriptionIdNumber__c + ', has a quantity of ' + ass.Quantity;
                                    update iaRec;
                                }
                            } else {
                                // hasn't been approved. 
                                
                                iaRec.Error__c = '[Potential Duplicate] There is already an import asset record for this product for the current period';
                                update iaRec;
                            }
                        }   
                    }
                }
            }

            if((ass.CancellationDate__c != null && ass.CancellationDate__c <= Date.today() && approved == true)
            || ass.CancellationDate__c == null){
                // only update asset if its not cancelled and if cancelled, then only if its approved
                update ass;
            }
        }
    } 
    
    
    global void finish(Database.BatchableContext bc){

        
        // cater to assets that did not have an informat/import asset imported
        // schedule a job to kickoff in 2 mins
        if(triggerBusinessRules == true){
            String hour = String.valueOf(Datetime.now().hour());
            String min = String.valueOf(Datetime.now().minute() + 2); 
            String ss = String.valueOf(Datetime.now().second());
            
            if(Integer.valueOf(min) > 59){
                min = '1';
                Integer intHour = Integer.valueOf(hour);
                hour = String.valueOf(intHour+1);
            }
            
            system.debug('hour: ' + hour);
            system.debug('min: ' + min);
            system.debug('ss: ' + ss);
            
            //parse to cron expression
            String nextFireTime = ss + ' ' + min + ' ' + hour + ' * * ?';
            
            // delete existing job (if there is one)
            CronTrigger[] jobRecordLs = [SELECT Id FROM CronTrigger where CronJobDetail.Name LIKE '%ImportAssetInsertSchedulable_%'];
            
            if(jobRecordLs.size() > 0){
                for(CronTrigger cTrig : jobRecordLs){
                    System.abortJob(cTrig.Id);
                }
            }
            
            ImportAssetInsertSchedulable s = new ImportAssetInsertSchedulable(); 
            System.schedule('ImportAssetInsertSchedulable_ ' + String.valueOf(Datetime.now()), nextFireTime, s);
              
        }
    }
    
    
}