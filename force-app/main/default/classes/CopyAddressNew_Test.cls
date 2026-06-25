@isTest
public class CopyAddressNew_Test {
    
    @IsTest
    static void TestGetRecordTypeId(){
        Account acc = new Account();
        acc.Name = 'Finesse IT';
        insert acc;
        
        Address_Information__c billToAddress = new Address_Information__c(
            Account__c = acc.Id,
            Line_1_Block__c = 'Test Billing Address',
            Line_2_Building_Floor_Room__c = 'Test City',
            Line_3_Street_PO_Box__c = '12345',
            Auto_Fill_Ship_To_Address__c = true,
            Auto_Fill_Sold_To_Address__c = true,
            name = 'ship to - Test City' 
        );
        insert billToAddress;
        
      
        
        Test.startTest();
        CopyAddressNewHandler.copyAddressToRecord(new List<Address_Information__c>{billToAddress});
        CopyAddressNewHandler.copySoldAddressToRecord(new List<Address_Information__c>{billToAddress});
        Test.stopTest();
        
    }

}