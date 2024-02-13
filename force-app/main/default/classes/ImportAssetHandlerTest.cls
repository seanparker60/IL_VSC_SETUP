@isTest
public class ImportAssetHandlerTest {
    @testSetup
    public static void makeData(){
        List<Account> lstAccount = TestDataFactory.insertAccountsSubsidiary(2, 'Plantyn',true,false); 
        lstAccount[0].RenewalAssetToday__c = true;
        lstAccount[0].ExternalCustomerId__c = 'zonc_100';
        lstAccount[0].Hfdstructuur__c = '311;321;411;111;221;312';

        lstAccount[1].RenewalAssetToday__c = true;
        lstAccount[1].ExternalCustomerId__c = 'zonc_ext';
        lstAccount[1].Hfdstructuur__c = '311';
        insert lstAccount;
        
        // more than one asset account
        List<Account> lstDupeAccs = new List<Account>();
        Account Acc = new Account();
        Acc.Name = 'School10';
        Acc.LegalName__c = Acc.Name;
        Acc.LegalName2__c = Acc.Name;
        Acc.OperatingCompany__c =  'Plantyn';
        Acc.CustomerCategory__c = 'Educational Institution';
        Acc.CustomerDiscountGroup__c ='Educational Institution';
        Acc.NetsuiteInternalId__c = 'dupe_test_1';
        Acc.NetsuiteCustomerNumber__c = 'dupe_test_1';
        Acc.TypeOfAccount__c = 'Sales';
        Acc.NumberofStudents__c = 222;
        Acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('B2BEducational').getRecordTypeId();
        Acc.isHigherEducation__c = true;
        Acc.ShippingCity = 'Amsterdam';
        Acc.ShippingCountry = 'Netherlands';
        Acc.ShippingPostalCode = '1224AM';
        Acc.ShippingStreet = 'DePijp22'; 
        Acc.BillingReminderEmail__c ='test@test.com';
        Acc.BillingReminderEmail2__c ='test2@test.com';
        Acc.DigitalActivationEmail__c ='test@test.com';
        Acc.InvoicingEmail__c ='test@test.com';
        Acc.InvoiceEmail2__c ='test2@test.com';
        Acc.OrderNotificationEmail__c ='test@test.com';
        Acc.Area__c = 'Dutch';
        Acc.RenewalAssetToday__c = true;
        Acc.ExternalCustomerId__c = 'dupe_test_1';
        Acc.Hfdstructuur__c = '311;321;411';
        insert Acc;
        
        lstDupeAccs.add(acc);
        
        List<Product2> lstProduct = TestDataFactory.insertProducts(1,true);
        for(Product2 prod : lstProduct){
            prod.EAN__c = '9781130148015';
        }
        update lstProduct;
        
        List<Product2> lstProduct2 = TestDataFactory.insertProducts(1,true);
        
        Pricebook2 standardPricebook = TestDataFactory.insertPricebook();
        Pricebook2 customPricebook = TestDataFactory.insertPricebookCustom('Plantyn - Informat');
		customPricebook.Name = 'Plantyn - Informat';
        update customPricebook;
        
        List<PricebookEntry> lstPricebookEntry = TestDataFactory.insertPricebookEntry(standardPricebook.id ,lstProduct,true);
        List<PricebookEntry> lstPricebookEntry2 = TestDataFactory.insertPricebookEntry(customPricebook.id ,lstProduct,true);
        List<PricebookEntry> lstPricebookEntry3 = TestDataFactory.insertPricebookEntry(standardPricebook.id ,lstProduct2,true);
        List<PricebookEntry> lstPricebookEntry4 = TestDataFactory.insertPricebookEntry(customPricebook.id ,lstProduct2,true);
        
        List<Asset>lst_Asset = TestDataFactory.insertAsset(customPricebook.id ,lstProduct,lstAccount, lstAccount,false);
        lst_Asset[0].Informhfdstructuur__c = '311';
        lst_Asset[0].OperatingCompany__c = 'Plantyn';
        lst_Asset[0].Quantity = 0;
        Insert lst_Asset;
        
        List<Asset>lst_Asset2 = TestDataFactory.insertAsset(customPricebook.id ,lstProduct,lstAccount, lstAccount,false);
        lst_Asset2[0].Informhfdstructuur__c = '321';
        lst_Asset2[0].OperatingCompany__c = 'Plantyn';
        lst_Asset2[0].Quantity = 100;
        Insert lst_Asset2;
        
        List<Asset>lst_Asset4 = TestDataFactory.insertAsset(customPricebook.id ,lstProduct2,lstAccount, lstAccount,false);
        lst_Asset4[1].Informhfdstructuur__c = '311';
        lst_Asset4[1].OperatingCompany__c = 'Plantyn';
        lst_Asset4[1].Quantity = 1000;
        Insert lst_Asset4;
        
        List<Asset>lst_Asset3 = TestDataFactory.insertAsset(customPricebook.id ,lstProduct,lstAccount, lstAccount,false);
        lst_Asset3[0].Informhfdstructuur__c = '411';
        lst_Asset3[0].OperatingCompany__c = 'Plantyn';
        lst_Asset3[0].Quantity = 950;
        lst_Asset3[0].CancellationDate__c = Date.today().addDays(-5);
        lst_Asset3[0].CancellationReason__c = 'Unknown';
        lst_Asset3[0].IsActive__c = false;
        Insert lst_Asset3;
        
        
		// dupe assets
        List<Asset>dupeAssts = TestDataFactory.insertAsset(customPricebook.id ,lstProduct,lstDupeAccs, lstDupeAccs,false);
        dupeAssts[0].Informhfdstructuur__c = '311';
        dupeAssts[0].OperatingCompany__c = 'Plantyn';
        dupeAssts[0].Quantity = 100;
        Insert dupeAssts;
        
        List<Asset>dupeAssts2 = TestDataFactory.insertAsset(customPricebook.id ,lstProduct,lstDupeAccs, lstDupeAccs,false);
        dupeAssts2[0].Informhfdstructuur__c = '311';
        dupeAssts2[0].OperatingCompany__c = 'Plantyn';
        dupeAssts2[0].Quantity = 101;
        Insert dupeAssts2;
        
        ImportAssets__c ia1 = new ImportAssets__c();
        ia1.ExternalCustomerId__c = 'zonc_100';
        ia1.Hfdstructuur__c = '311';
        ia1.Quantity__c = 100;
        insert ia1;
        
        
    }
    
    @isTest
    public static void testData1(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 100;
        insert ia2;
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testData2(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '321';
        ia2.Quantity__c = 1000;
        ia2.Approved__c = true;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testData3(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_ext';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 1000;
        ia2.Approved__c = true;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testData4(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '321';
        ia2.Quantity__c = 1000;
        insert ia2;
        
        ImportAssets__c ia3 = new ImportAssets__c();
        ia3.ExternalCustomerId__c = 'zonc_100';
        ia3.Hfdstructuur__c = '321';
        ia3.Quantity__c = 1000;
        insert ia3;
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        iaLs.add(ia3);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testData5(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '321';
        ia2.Quantity__c = 100;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testData6(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '321';
        ia2.Quantity__c = 10000;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    
    @isTest
    public static void testData7(){
        List<Asset> assetLs = [SELECT Id, Informhfdstructuur__c from Asset];
        for(Asset ass : assetLs){
            ass.Informhfdstructuur__c = '411'; // 311;321;411;111;221;312
        }
        
        update assetLs;
        
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '411';
        ia2.Quantity__c = 100;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testData8(){
        List<Asset> assetLs = [SELECT Id, Informhfdstructuur__c from Asset];
        for(Asset ass : assetLs){
            ass.Informhfdstructuur__c = '111'; // 311;321;411;111;221;312
        }
        
        update assetLs;
        
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '111';
        ia2.Quantity__c = 100;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testData9(){
        List<Asset> assetLs = [SELECT Id, Informhfdstructuur__c from Asset];
        for(Asset ass : assetLs){
            ass.Informhfdstructuur__c = '221'; // 311;321;411;111;221;312
        }
        
        update assetLs;
        
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '221';
        ia2.Quantity__c = 100;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testData10(){
        List<Asset> assetLs = [SELECT Id, Informhfdstructuur__c from Asset];
        for(Asset ass : assetLs){
            ass.Informhfdstructuur__c = '312'; // 311;321;411;111;221;312
        }
        
        update assetLs;
        
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '312';
        ia2.Quantity__c = 100;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    
    @isTest
    public static void testDataNoHfdstructuur(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '321000';
        ia2.Quantity__c = 100;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    
    @isTest
    public static void testMultiAssets(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'dupe_test_1';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 100;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testMultiAssetsAndStudentNum(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'dupe_test_1';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 100;
        insert ia2;
        
        ImportAssets__c ia3 = new ImportAssets__c();
        ia3.ExternalCustomerId__c = 'dupe_test_1';
        ia3.Hfdstructuur__c = '311';
        ia3.Quantity__c = 100;
        insert ia3;
        
        List<Asset> assLs = [Select Id, AccountId from Asset where Informhfdstructuur__c = '311' AND ShiptoExternalId__c = 'dupe_test_1'];
        
        List<StudentAndUsernumbers__c> studentANDUserNumberLs = new List<StudentAndUsernumbers__c>();
        for(Asset ass : AssLs){
            StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
            studentANDUserNumber.Account__c = ass.AccountId;
            
            studentANDUserNumber.Asset__c = ass.Id;
            studentANDUserNumber.Type__c = 'User Numbers';
            studentANDUserNumber.TotalNumber__c = 100;
            studentANDUserNumber.StartDate__c = Date.newInstance(System.Today().year(), 02, 01);
            studentANDUserNumber.EndDate__c = Date.newInstance(System.Today().year()+1, 01, 31);
            
            studentANDUserNumberLs.add(studentANDUserNumber);
        }
        
        insert studentANDUserNumberLs;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        iaLs.add(ia3);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testMultiAssetsAndStudentNum2(){
        List<Asset> assLs = [Select Id, AccountId from Asset where Informhfdstructuur__c = '311' AND ShiptoExternalId__c = 'dupe_test_1'];
        
        List<StudentAndUsernumbers__c> studentANDUserNumberLs = new List<StudentAndUsernumbers__c>();
        for(Asset ass : AssLs){
            StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
            studentANDUserNumber.Account__c = ass.AccountId;
            
            studentANDUserNumber.Asset__c = ass.Id;
            studentANDUserNumber.Type__c = 'User Numbers';
            studentANDUserNumber.TotalNumber__c = 100;
            studentANDUserNumber.StartDate__c = Date.newInstance(System.Today().year(), 02, 01);
            studentANDUserNumber.EndDate__c = Date.newInstance(System.Today().year()+1, 01, 31);
            
            studentANDUserNumberLs.add(studentANDUserNumber);
        }
        
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'dupe_test_1';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 100;
        ia2.Approved__c = true;
        ia2.Asset__c = assLs[0].Id;
        insert ia2;
        
        insert studentANDUserNumberLs;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testMultiAssetsAndStudentNum3(){

        
        ImportAssets__c ia3 = new ImportAssets__c();
        ia3.ExternalCustomerId__c = 'dupe_test_1';
        ia3.Hfdstructuur__c = '311';
        ia3.Quantity__c = 100;
        insert ia3;
        
        List<Asset> assLs = [Select Id, AccountId from Asset where Informhfdstructuur__c = '311' AND ShiptoExternalId__c = 'dupe_test_1'];
        
        List<StudentAndUsernumbers__c> studentANDUserNumberLs = new List<StudentAndUsernumbers__c>();
        for(Asset ass : AssLs){
            ass.CancellationDate__c = Date.today().addDays(-5);
            ass.CancellationReason__c = 'Unknown';
            ass.IsActive__c = false;
            
            StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
            studentANDUserNumber.Account__c = ass.AccountId;
            
            studentANDUserNumber.Asset__c = ass.Id;
            studentANDUserNumber.Type__c = 'User Numbers';
            studentANDUserNumber.TotalNumber__c = 100;
            studentANDUserNumber.StartDate__c = Date.newInstance(System.Today().year(), 02, 01);
            studentANDUserNumber.EndDate__c = Date.newInstance(System.Today().year()+1, 01, 31);
            
            studentANDUserNumberLs.add(studentANDUserNumber);
        }
        update AssLs;
        
        insert studentANDUserNumberLs;
        
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'dupe_test_1';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 100;
        ia2.Approved__c = true;
        ia2.Asset__c = assLs[0].Id;
        insert ia2;
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testMultiAssetsAndStudentNum4(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'dupe_test_1';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 100;
        ia2.Approved__c = true;
        insert ia2;
        
        ImportAssets__c ia3 = new ImportAssets__c();
        ia3.ExternalCustomerId__c = 'dupe_test_1';
        ia3.Hfdstructuur__c = '311';
        ia3.Quantity__c = 100;
        //ia3.Approved__c = true;
        insert ia3;
        
        List<Asset> assLs = [Select Id, AccountId from Asset where Informhfdstructuur__c = '311' AND ShiptoExternalId__c = 'dupe_test_1'];
        
        List<StudentAndUsernumbers__c> studentANDUserNumberLs = new List<StudentAndUsernumbers__c>();
        for(Asset ass : AssLs){
            ass.CancellationDate__c = Date.today().addDays(-5);
            ass.CancellationReason__c = 'Unknown';
            ass.IsActive__c = false;
            
            StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
            studentANDUserNumber.Account__c = ass.AccountId;
            
            studentANDUserNumber.Asset__c = ass.Id;
            studentANDUserNumber.Type__c = 'User Numbers';
            studentANDUserNumber.TotalNumber__c = 100;
            studentANDUserNumber.StartDate__c = Date.newInstance(System.Today().year(), 02, 01);
            studentANDUserNumber.EndDate__c = Date.newInstance(System.Today().year()+1, 01, 31);
            
            studentANDUserNumberLs.add(studentANDUserNumber);
        }
        update assLs;
        insert studentANDUserNumberLs;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        iaLs.add(ia3);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testMultiAssetsAndStudentNum5(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'dupe_test_1';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 100;
        ia2.Approved__c = true;
        insert ia2;
        
        List<Asset> assLs = [Select Id, AccountId from Asset where Informhfdstructuur__c = '311' AND ShiptoExternalId__c = 'dupe_test_1'];
        
        List<StudentAndUsernumbers__c> studentANDUserNumberLs = new List<StudentAndUsernumbers__c>();
        for(Asset ass : AssLs){
            ass.CancellationDate__c = Date.today().addDays(-5);
            ass.CancellationReason__c = 'Unknown';
            ass.IsActive__c = false;
            
            StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
            studentANDUserNumber.Account__c = ass.AccountId;
            
            studentANDUserNumber.Asset__c = ass.Id;
            studentANDUserNumber.Type__c = 'User Numbers';
            studentANDUserNumber.TotalNumber__c = 100;
            studentANDUserNumber.StartDate__c = Date.newInstance(System.Today().year(), 02, 01);
            studentANDUserNumber.EndDate__c = Date.newInstance(System.Today().year()+1, 01, 31);
            
            studentANDUserNumberLs.add(studentANDUserNumber);
        }
        update assLs;
        insert studentANDUserNumberLs;
        
        ImportAssets__c ia3 = new ImportAssets__c();
        ia3.ExternalCustomerId__c = 'dupe_test_1';
        ia3.Hfdstructuur__c = '311';
        ia3.Quantity__c = 100;
        ia3.Asset__c = assLs[0].Id;
        insert ia3;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        iaLs.add(ia3);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testMultiAssetsAndStudentNum6(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'dupe_test_1';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 100;
        ia2.Approved__c = true;
        insert ia2;
        
        List<Asset> assLs = [Select Id, AccountId, Product2Id from Asset where Informhfdstructuur__c = '311' AND ShiptoExternalId__c = 'dupe_test_1'];
        delete assLs[0];
        assLs = [Select Id, AccountId, Product2Id from Asset where Informhfdstructuur__c = '311' AND ShiptoExternalId__c = 'dupe_test_1'];
        system.debug('testMultiAssetsAndStudentNum6 assLs: ' + assLs);
        
        
        List<StudentAndUsernumbers__c> studentANDUserNumberLs = new List<StudentAndUsernumbers__c>();
        for(Asset ass : AssLs){
            ass.CancellationDate__c = Date.today().addDays(-5);
            ass.CancellationReason__c = 'Unknown';
            ass.IsActive__c = false;
            
            StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
            studentANDUserNumber.Account__c = ass.AccountId;
            
            studentANDUserNumber.Asset__c = ass.Id;
            studentANDUserNumber.Type__c = 'User Numbers';
            studentANDUserNumber.TotalNumber__c = 100;
            studentANDUserNumber.StartDate__c = Date.newInstance(System.Today().year(), 02, 01);
            studentANDUserNumber.EndDate__c = Date.newInstance(System.Today().year()+1, 01, 31);
            
            studentANDUserNumberLs.add(studentANDUserNumber);
        }
        update assLs;
        insert studentANDUserNumberLs;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testMultiAssetsAndStudentNum7(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'dupe_test_1';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 100;
        ia2.Approved__c = true;
        ia2.Error__c = '[Potential Duplicate] Multiple assets have been found for this hfdstructuur and customer number';
        insert ia2;
        
        List<Asset> assLs = [Select Id, AccountId, Product2Id from Asset where Informhfdstructuur__c = '311' AND ShiptoExternalId__c = 'dupe_test_1'];
        delete assLs[0];
        assLs = [Select Id, AccountId, Product2Id from Asset where Informhfdstructuur__c = '311' AND ShiptoExternalId__c = 'dupe_test_1'];
        system.debug('testMultiAssetsAndStudentNum7 assLs: ' + assLs);
        
        
        List<StudentAndUsernumbers__c> studentANDUserNumberLs = new List<StudentAndUsernumbers__c>();
        for(Asset ass : AssLs){
            ass.CancellationDate__c = Date.today().addDays(-5);
            ass.CancellationReason__c = 'Unknown';
            ass.IsActive__c = false;
            
            StudentAndUsernumbers__c studentANDUserNumber = new StudentAndUsernumbers__c();
            studentANDUserNumber.Account__c = ass.AccountId;
            
            studentANDUserNumber.Asset__c = ass.Id;
            studentANDUserNumber.Type__c = 'User Numbers';
            studentANDUserNumber.TotalNumber__c = 100;
            studentANDUserNumber.StartDate__c = Date.newInstance(System.Today().year(), 02, 01);
            studentANDUserNumber.EndDate__c = Date.newInstance(System.Today().year()+1, 01, 31);
            
            studentANDUserNumberLs.add(studentANDUserNumber);
        }
        update assLs;
        insert studentANDUserNumberLs;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testCancelledApprovedAsset(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '411';
        ia2.Quantity__c = 1000;
        ia2.Approved__c = true;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }

    @isTest
    public static void testCancelledApprovedAsset2(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '411';
        ia2.Quantity__c = 10000;
        ia2.Approved__c = true;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testCancelledApprovedAsset3(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '411';
        ia2.Quantity__c = 10000;
        //ia2.Approved__c = true;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
    
    @isTest
    public static void testInsertBatchDupes(){
        List<Asset> assLs = [SELECT Id, QuantityStartDate__c, QuantityEndDate__c,
                                                IsInformat__c,
                                                Informhfdstructuur__c,
                                                ShiptoExternalId__c,
                                                OperatingCompany__c
                                                from Asset WHERE Product2.EAN__c = '9781130148015'];
        system.debug('tests assLs: ' + assLs);
        /*ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '311';
        ia2.Quantity__c = 100;
        ia2.Asset__c = assLs[0].Id;
        ia2.QuantityStartDate__c = Date.newInstance(System.Today().year(), 02, 01);
        ia2.QuantityEndDate__c = Date.newInstance(System.Today().year()+1, 01, 31);
        insert ia2;*/
        
        
        test.startTest();
        ImportAssetInsertBatch batchJob2 = new ImportAssetInsertBatch();
        Id batchJob2Id = Database.executeBatch(batchJob2, 25);
        test.stopTest();
    }
    
    @isTest
    public static void testInsertBatchDupes2(){
        Date startDate = Date.newInstance(System.Today().year(), 02, 01); 
        Date endDate = Date.newInstance(System.Today().year()+1, 01, 31);
        
List<Asset> assetsWithoutInfRecs = [SELECT Id, ShiptoExternalId__c,AccountId, Informhfdstructuur__c, Quantity, Product2Id, OperatingCompany__c, PriceBook__c FROM Asset WHERE Id NOT IN (SELECT Asset__c FROM ImportAssets__c WHERE QuantityStartDate__c =: startDate AND QuantityEndDate__c =: endDate) 
                                            AND IsInformat__c = true
                                            AND Informhfdstructuur__c != NULL
                                            AND ShiptoExternalId__c != NULL
                                            AND OperatingCompany__c = 'Plantyn'
                                            AND Product2.EAN__c = '9781130148015'];
        
        system.debug('tests assetsWithoutInfRecs: ' + assetsWithoutInfRecs);
        
        Asset asstest = new Asset();
        //asstest.ShiptoExternalId__c = assetsWithoutInfRecs[0].ShiptoExternalId__c;
        asstest.AccountId = assetsWithoutInfRecs[0].AccountId;
        asstest.Informhfdstructuur__c = assetsWithoutInfRecs[0].Informhfdstructuur__c;
        asstest.Quantity = assetsWithoutInfRecs[0].Quantity;
        asstest.Product2Id = assetsWithoutInfRecs[0].Product2Id;
        asstest.OperatingCompany__c = assetsWithoutInfRecs[0].OperatingCompany__c;
        asstest.PriceBook__c = assetsWithoutInfRecs[0].PriceBook__c;
        asstest.name = 'test';
        insert asstest;
        
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = assetsWithoutInfRecs[0].ShiptoExternalId__c;
        ia2.Hfdstructuur__c = assetsWithoutInfRecs[0].Informhfdstructuur__c;
        ia2.Quantity__c = assetsWithoutInfRecs[0].Quantity;
        ia2.Asset__c = assetsWithoutInfRecs[0].Id;
        ia2.QuantityStartDate__c = startDate;
        ia2.QuantityEndDate__c = endDate;
        insert ia2;
        
        /*ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = assetsWithoutInfRecs[0].ShiptoExternalId__c;
        ia2.Hfdstructuur__c = assetsWithoutInfRecs[0].Informhfdstructuur__c;
        ia2.Quantity__c = assetsWithoutInfRecs[0].Quantity;
        ia2.Asset__c = assetsWithoutInfRecs[0].Id;
        ia2.QuantityStartDate__c = startDate;
        ia2.QuantityEndDate__c = endDate;
        ia2.Status__c = 'Pending';
        insert ia2;*/
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);

        test.stopTest();
    }
    
    @isTest
    public static void testBusinessRules(){
        ImportAssets__c ia2 = new ImportAssets__c();
        ia2.ExternalCustomerId__c = 'zonc_100';
        ia2.Hfdstructuur__c = '411';
        ia2.Quantity__c = 10000;
        ia2.TriggerBusinessRules__c = true;
        //ia2.Approved__c = true;
        insert ia2;
        
        
        List<ImportAssets__c> iaLs = new List<ImportAssets__c>();
        iaLs.add(ia2);
        
        test.startTest();
        ImportAssetHandler.handleAssetImports(iaLs);
        test.stopTest();
    }
}