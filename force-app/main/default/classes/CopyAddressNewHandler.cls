public class CopyAddressNewHandler {
    
    public static void copyAddressToRecord(List<Address_Information__c> newAddressRecords){
        ID BillTORecordTypeID = Schema.SobjectType.Address_Information__c.getRecordTypeInfosByName().get('Bill To').getRecordTypeID();
        ID ShipToRecordTypeID = schema.SObjecttype.Address_Information__c.getRecordTypeInfosByName().get('Ship To').getRecordTypeId();
        ID SoldtoRecordTypeID = Schema.SobjectType.Address_Information__c.getRecordTypeInfosByName().get('Sold To').getRecordTypeID();
        
        List<Address_Information__c> AddShiptoInfoList = new List<Address_Information__c>();
        List<Address_Information__c> AddSoldtoInfoList = new List<Address_Information__c>();
        
        
        For(Address_Information__c ShipAddress: newAddressRecords){
            if(ShipAddress.Auto_Fill_Ship_To_Address__c && ShipAddress.recordTypeId == BillTORecordTypeID  ){
                
                Address_Information__c ShipToInf = new Address_Information__c(
                    
                    Account__c = ShipAddress.Account__c,
                    Name = ShipAddress.Name,
                    RecordTypeId = ShipToRecordTypeID,
                    // Address_ID__c = ShipAddress.Address_ID__c,
                    Line_1_Block__c = ShipAddress.Line_1_Block__c,
                    Line_2_Building_Floor_Room__c = ShipAddress.Line_2_Building_Floor_Room__c,
                    Line_3_Street_PO_Box__c = ShipAddress.Line_3_Street_PO_Box__c,
                    City__c = ShipAddress.City__c,
                    Zip_Code__c = ShipAddress.Zip_Code__c,
                    State__c = ShipAddress.State__c,
                    Country__c = ShipAddress.Country__c,
                    Tax_Type__c = ShipAddress.Tax_Type__c,
                    TAX_Number__c = ShipAddress.TAX_Number__c
                );
                AddShiptoInfoList.add(ShipToInf);
            }
            insert AddShiptoInfoList;
        }        
    }
    
    
    public static void copySoldAddressToRecord(List<Address_Information__c> newSoldAddressRecords){
       
        ID BillTORecordTypeID = Schema.SobjectType.Address_Information__c.getRecordTypeInfosByName().get('Bill To').getRecordTypeID();
        ID ShipToRecordTypeID = schema.SObjecttype.Address_Information__c.getRecordTypeInfosByName().get('Ship To').getRecordTypeId();
        ID SoldtoRecordTypeID = Schema.SobjectType.Address_Information__c.getRecordTypeInfosByName().get('Sold To').getRecordTypeID();
        
       
        List<Address_Information__c> AddSoldtoInfoList = new List<Address_Information__c>();
        
        For(Address_Information__c SoldAddress: newSoldAddressRecords){
            if(SoldAddress.Auto_Fill_Sold_To_Address__c && SoldAddress.recordTypeId == BillTORecordTypeID  ){
                
                Address_Information__c SoldToInf = new Address_Information__c(
                    
                    Account__c = SoldAddress.Account__c,
                    Name = SoldAddress.Name,
                    RecordTypeId = SoldtoRecordTypeID,
                    // Address_ID__c = SoldAddress.Address_ID__c,
                    Line_1_Block__c = SoldAddress.Line_1_Block__c,
                    Line_2_Building_Floor_Room__c = SoldAddress.Line_2_Building_Floor_Room__c,
                    Line_3_Street_PO_Box__c = SoldAddress.Line_3_Street_PO_Box__c,
                    City__c = SoldAddress.City__c,
                    Zip_Code__c = SoldAddress.Zip_Code__c,
                    State__c = SoldAddress.State__c,
                    Country__c = SoldAddress.Country__c,
                    Tax_Type__c = SoldAddress.Tax_Type__c,
                    TAX_Number__c = SoldAddress.TAX_Number__c
                );
                AddSoldtoInfoList.add(SoldToInf);
            }
            insert AddSoldtoInfoList;
        }        
    }  
}