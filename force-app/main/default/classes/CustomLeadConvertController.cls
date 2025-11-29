public class CustomLeadConvertController {
    @AuraEnabled
    public static Lead getLeadRecord(String recordId) {
        try {
            String allFields = UtilityCls.getAllFields('Lead')
                .get('Lead');
            String query =
                'SELECT ' +
                allFields +
                ', ' +
                'Owner.FirstName, Owner.LastName ' +
                'FROM Lead WHERE Id =: recordId';
            return Database.query(query);
        } catch (Exception e) {
            System.debug(e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map < String, String > convertLead(Lead leadRecord, String accName, String existingAccId, Map < String, String > contactName, String existingContId, String enqName, Boolean isContactNew) {
        Savepoint sp = Database.setSavepoint();

        try {

            List < Contact > contList = new List < Contact > ();

            Contact existingContact;
            if (isContactNew == false && String.isNotBlank(existingContId)) {
                existingContact = [
                    SELECT Id, Name, Salutation, FirstName, MiddleName, LastName, Title, Fax, //Landline_Number__c, Anniversary_Date__c, Zoom_ID__c, LinkedIn__c, Twitter__c, Website__c,
                    MobilePhone, Email, BirthDate, phone
                    FROM Contact
                    WHERE Id =: existingContId
                ];
            }
                
            Contact cont = new Contact();
            if (isContactNew == false && String.isNotBlank(existingContId)) {
                cont.Id = existingContId;
            }
            cont.AccountId = existingAccId;
            if (existingContact != null) {
                cont.Salutation = String.isBlank(existingContact.Salutation) ? contactName.get('Salutation') : existingContact.Salutation;
                cont.FirstName = String.isBlank(existingContact.FirstName) ? contactName.get('FirstName') : existingContact.FirstName;
                cont.MiddleName = String.isBlank(existingContact.MiddleName) ? contactName.get('MiddleName') : existingContact.MiddleName;
                cont.LastName = String.isBlank(existingContact.LastName) ? contactName.get('LastName') : existingContact.LastName;
                cont.Title = String.isBlank(existingContact.Title) ? leadRecord.Title : existingContact.Title;
                cont.phone = String.isBlank(existingContact.phone) ? leadRecord.Phone : existingContact.phone;
                cont.MobilePhone = String.isBlank(existingContact.MobilePhone) ? leadRecord.MobilePhone : existingContact.MobilePhone;
                cont.Email = String.isBlank(existingContact.Email) ? leadRecord.Email : existingContact.Email;
            } else {
                cont.Salutation = contactName.get('Salutation');
                cont.FirstName = contactName.get('FirstName');
                cont.MiddleName = contactName.get('MiddleName');
                cont.LastName = contactName.get('LastName');
                cont.Title = leadRecord.Title;
                cont.phone = leadRecord.Phone;
                cont.MobilePhone = leadRecord.MobilePhone;
                cont.Email = leadRecord.Email;
            }

            contList.add(cont);

            upsert contList;

            Map < String, String > finalMap = new Map < String, String > ();
            finalMap.put('accountId', existingAccId);
            finalMap.put('contactId', cont.Id);

            return finalMap;

        } catch (DmlException e) {
            Database.rollback(sp);
            System.debug(e);
            System.debug(e.getLineNumber());
            System.debug(e.getStackTraceString());
            String msg;
            if (e.getNumDml() > 0) {
                msg = e.getDmlMessage(0);
            } else {
                msg = e.getMessage();
            }
            System.debug(msg);
            throw new AuraHandledException(msg);
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(e);
            System.debug(e.getLineNumber());
            System.debug(e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }

    }

}