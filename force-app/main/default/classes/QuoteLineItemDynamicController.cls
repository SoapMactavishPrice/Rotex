public with sharing class QuoteLineItemDynamicController {

    public class FieldWrapper {

        @AuraEnabled
        public String fieldAPI;

        @AuraEnabled
        public String label;

        @AuraEnabled
        public Object value;

        @AuraEnabled
        public String type;
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldWrapper> getQuoteLineItem(Id recordId){

        List<FieldWrapper> results = new List<FieldWrapper>();

        Schema.DescribeSObjectResult describe =
            QuoteLineItem.SObjectType.getDescribe();
        
        Map<String, Schema.FieldSet> fieldSets =
            QuoteLineItem.SObjectType.getDescribe().fieldSets.getMap();
        
        if(!fieldSets.containsKey('LWC_View')){
            throw new AuraHandledException('Field Set LWC_View not found.');
        }
        
        Schema.FieldSet fieldSet = fieldSets.get('LWC_View');
        
        List<Schema.FieldSetMember> members = fieldSet.getFields();
        
        if(members.isEmpty()){
            return new List<FieldWrapper>();
        }

        List<String> fieldNames = new List<String>();

        for(Schema.FieldSetMember f : members){

            fieldNames.add(f.getFieldPath());

        }

        String soql =
            'SELECT ' +
            String.join(fieldNames, ',') +
            ' FROM QuoteLineItem WHERE Id=:recordId';

        QuoteLineItem qli =
            Database.query(soql);

        for(Schema.FieldSetMember f : members){

            FieldWrapper wrap = new FieldWrapper();

            wrap.fieldAPI = f.getFieldPath();

            wrap.label = f.getLabel();

            wrap.value = qli.get(f.getFieldPath());

            wrap.type = String.valueOf(f.getType());

            results.add(wrap);

        }

        return results;

    }

}