@isTest
public class salesOrderPDFControllerTest {

 
  @testSetup
static void setupTestData() {
    // Get the Standard Pricebook ID
    Id standardPricebookId = Test.getStandardPricebookId();

    Pricebook2 standardPriceBook = new Pricebook2(Id = standardPricebookId, IsActive = true);
    update standardPriceBook;

    // Create a Product
    Product2 testProduct = new Product2(Name = 'Test Product', IsActive = true);
    insert testProduct;

    // Create an Account
    Account account = new Account(Name = 'Test Account');
    insert account;

    // Create an Order (Use the Standard Pricebook ID here)
    Order order = new Order(
        Name = 'Test Order',
        Status = 'Draft',
        Type='	Direct Sales Domestic',
        AccountId = account.Id,
        EffectiveDate = Date.today(),
        Pricebook2Id = standardPricebookId // Corrected field assignment
    );
    insert order;

    PricebookEntry standardPricebookEntry = [
        SELECT Id, Name, UnitPrice, IsActive, Pricebook2Id, Product2Id
        FROM PricebookEntry
        WHERE Pricebook2Id = :standardPricebookId
        AND Product2Id = :testProduct.Id
        LIMIT 1
    ];

    // Create Order Items
    OrderItem orderItem = new OrderItem(
        OrderId = order.Id,
        PricebookEntryId = standardPricebookEntry.Id,
        Quantity = 2,
        UnitPrice = 100
    );
    insert orderItem;
}

  @isTest
static void testInitialization() {
    // Test the initialization of the controller
    Test.startTest();
    ApexPages.currentPage().getParameters().put('id', [SELECT Id FROM Order LIMIT 1].Id);
    salesOrderPDFController controller = new salesOrderPDFController();
    Test.stopTest();

   // System.assertNotEquals(null, controller.orderRecord, 'Order data should be initialized');
    System.assert(controller.ordItem.size() > 0, 'Order Items should be fetched');
}


    @isTest
    static void testSave() {
        // Test the save functionality
        Test.startTest();
        ApexPages.currentPage().getParameters().put('id', [SELECT Id FROM Order LIMIT 1].Id);
        salesOrderPDFController controller = new salesOrderPDFController();
        controller.createNew = false;
        PageReference result = controller.save();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Save method should return a PageReference');
    }

   @isTest
static void testSaveAndSend() {
    // Retrieve the order created in test setup
    Order testOrder = [SELECT Id FROM Order LIMIT 1];
    
    // Set the current page parameter with the Order ID
    ApexPages.currentPage().getParameters().put('id', testOrder.Id);

    // Initialize the controller
    salesOrderPDFController controller = new salesOrderPDFController();
    controller.createNew = false;

    // Set email details
    controller.emailId = 'test@example.com';
    controller.subject = 'Test Subject';
    controller.body = 'This is a test email.';

    // Test the save and send functionality
    Test.startTest();
    PageReference result = controller.saveAndSend();
    Test.stopTest();

    // Assert that the result is not null
    System.assertNotEquals(null, result, 'Save and Send method should return a PageReference');
}


    @isTest
    static void testCancel() {
        // Test the cancel functionality
        Test.startTest();
        ApexPages.currentPage().getParameters().put('id', [SELECT Id FROM Order LIMIT 1].Id);
        salesOrderPDFController controller = new salesOrderPDFController();
        PageReference result = controller.cancel();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Cancel method should return a PageReference');
    }
}