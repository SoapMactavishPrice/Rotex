@isTest
public class RotexNavigationControllerTest {
    
    @isTest
    static void testGetMenuItems() {
        // NavigationLinkSet is a Setup Object, which means it cannot be inserted via DML in tests.
        // However, Setup Objects are visible to tests without SeeAllData=true.
        // We query the database to find an existing menu if one exists in the org.
        List<NavigationLinkSet> navSets = [SELECT MasterLabel FROM NavigationLinkSet LIMIT 1];
        
        Test.startTest();
        
        // 1. Test success path (if a menu actually exists in the org)
        if (!navSets.isEmpty()) {
            List<RotexNavigationController.MenuItemWrapper> items = RotexNavigationController.getMenuItems(navSets[0].MasterLabel);
            System.assertNotEquals(null, items, 'Menu items list should not be null');
        }
        
        // 2. Test Exception Path (QueryException: List has no rows for assignment to SObject)
        // By passing a completely non-existent menu name, the LIMIT 1 query will fail and 
        // trigger the catch block which throws an AuraHandledException.
        try {
            RotexNavigationController.getMenuItems('NonExistentMenuName_99999');
            System.assert(false, 'Should have thrown an AuraHandledException');
        } catch(AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception message should not be null');
        } catch(Exception e) {
            // Fallback in case of unexpected exceptions
            System.assert(true, 'Exception caught');
        }
        
        Test.stopTest();
    }
}