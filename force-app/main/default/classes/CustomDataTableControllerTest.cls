@isTest
public class CustomDataTableControllerTest {

    @isTest
    static void testFetchData_withPaginationAndSorting() {
        List<Product2> products = new List<Product2>();
        for (Integer i = 0; i < 50; i++) {
            products.add(new Product2(Name = 'Test Product ' + i));
        }
        insert products;

        String searchKey = '%Test Product%';
        Integer pageSize = 10;
        String sortBy = 'Name';
        String sortDirection = 'ASC';
        
        List<SObject> resultsPage1 = CustomDataTableController.fetchData(searchKey, null, pageSize, sortBy, sortDirection);

        String lastRecordId = (String) resultsPage1[resultsPage1.size() - 1].get('Id');
        List<SObject> resultsPage2 = CustomDataTableController.fetchData(searchKey, lastRecordId, pageSize, sortBy, sortDirection);
    }

    @isTest
    static void testFetchData_withNoResults() {
        String searchKey = '%Nonexistent Product%';
        Integer pageSize = 10;
        String sortBy = 'Name';
        String sortDirection = 'ASC';

        List<SObject> results = CustomDataTableController.fetchData(searchKey, null, pageSize, sortBy, sortDirection);
    }

    @isTest
    static void testCountRecords() {
        List<Product2> products = new List<Product2>();
        for (Integer i = 0; i < 10; i++) {
            products.add(new Product2(Name = 'Test Product ' + i));
        }
        insert products;

        String searchKey = '%Test Product%';
        
        Integer count = CustomDataTableController.countRecords(searchKey);
    }

    @isTest
    static void testFetchData_withSortingDesc() {
        List<Product2> products = new List<Product2>();
        for (Integer i = 0; i < 10; i++) {
            products.add(new Product2(Name = 'Test Product ' + i));
        }
        insert products;

        String searchKey = '%Test Product%';
        Integer pageSize = 5;
        String sortBy = 'Name';
        String sortDirection = 'DESC';

        List<SObject> results = CustomDataTableController.fetchData(searchKey, null, pageSize, sortBy, sortDirection);
    }
}