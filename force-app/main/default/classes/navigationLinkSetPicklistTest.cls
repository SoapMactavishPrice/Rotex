@isTest
public class navigationLinkSetPicklistTest {
    
    @isTest
    static void testPicklistMethods() {
        // Instantiate the picklist class
        navigationLinkSetPicklist picklist = new navigationLinkSetPicklist();
        
        Test.startTest();
        
        // 1. Test getDefaultValue()
        VisualEditor.DataRow defaultRow = picklist.getDefaultValue();
        System.assertNotEquals(null, defaultRow, 'Default row should not be null');
        System.assertEquals('Main Navigation', defaultRow.getValue(), 'Default value should be Main Navigation');
        System.assertEquals('Main Navigation', defaultRow.getLabel(), 'Default label should be Main Navigation');
        
        // 2. Test getValues()
        // This will query NavigationLinkSet. Even if 0 records exist in the test environment, 
        // the method will execute successfully and return an empty DynamicPickListRows object.
        VisualEditor.DynamicPickListRows rows = picklist.getValues();
        System.assertNotEquals(null, rows, 'Dynamic rows object should not be null');
        
        Test.stopTest();
    }
}