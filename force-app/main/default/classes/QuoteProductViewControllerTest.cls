@IsTest
private class QuoteProductViewControllerTest {

    @TestSetup
    static void createTestData() {



        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'TP-001',
            IsActive = true
        );
        insert prod;

        Id standardPricebookId = Test.getStandardPricebookId();
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 1000,
            IsActive = true
        );
        insert pbe;

        // Account
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId
        );
        insert opp;

        // Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Status = 'Submitted',
            Pricebook2Id = standardPricebookId
        );
        insert q;

        // Users for approval hierarchy
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];

        User sm = new User(
            FirstName='Sales',
            LastName='Manager',
            Alias='smgr',
            Email='sm@test.com',
            Username='sm'+System.currentTimeMillis()+'@test.com',
            ProfileId=p.Id,
            TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US'
        );
        insert sm;

        User ch = new User(
            FirstName='Country',
            LastName='Head',
            Alias='chd1',
            Email='ch@test.com',
            Username='ch'+System.currentTimeMillis()+'@test.com',
            ProfileId=p.Id,
            TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US'
        );
        insert ch;

        User gs = new User(
            FirstName='Global',
            LastName='Sales',
            Alias='gsh1',
            Email='gs@test.com',
            Username='gs'+System.currentTimeMillis()+'@test.com',
            ProfileId=p.Id,
            TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US'
        );
        insert gs;

        User bm = new User(
            FirstName='Board',
            LastName='Member',
            Alias='bm01',
            Email='bm@test.com',
            Username='bm'+System.currentTimeMillis()+'@test.com',
            ProfileId=p.Id,
            TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US'
        );
        insert bm;

        User md = new User(
            FirstName='Managing',
            LastName='Director',
            Alias='md01',
            Email='md@test.com',
            Username='md'+System.currentTimeMillis()+'@test.com',
            ProfileId=p.Id,
            TimeZoneSidKey='Asia/Kolkata',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US'
        );
        insert md;

        // Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.id,
            Quantity = 2,
            UnitPrice = 900,

            Discount_as_per_SAP__c = 5,
            Previous_Discount__c = 10,
            Discount_to_be_offered__c = 15,
            Requested_Comments__c = 'Requested comment',

            Sales_Manager__c = sm.Id,
            Sales_Manager_Status__c = 'Approved',
            Sales_Manager_Comments__c = 'SM Comment',
            Sales_Manager_Date_Time__c = System.now(),
            Prev_Sales_Manager_Comments__c = 'Previous SM Comment',

            Country_Continent_Sales_Head_LOB_Head__c = ch.Id,
            Country_Continent_Sales_H_LOB_Status__c = 'Approved',
            Country_Continent_Sales_LOB_Comments__c = 'CH Comment',
            Country_Head_Date_Time__c = System.now(),
            Prev_Country_Continent_Sales_Comments__c = 'Previous CH Comment',

            Global_Sales_Head__c = gs.Id,
            Global_Sales_Head_Status__c = 'Approved',
            Global_Sales_Head_Comments__c = 'GS Comment',
            Global_Sales_Head_Date_Time__c = System.now(),
            Prev_Global_Sales_Head_Comments__c = 'Previous GS Comment',

            Rotex_Board_Member__c = bm.Id,
            Rotex_Board_Member_Status__c = 'Approved',
            Rotex_Board_Member_Comments__c = 'BM Comment',
            Rotex_Board_Member_Date_Time__c = System.now(),
            Prev_Rotex_Board_Member_Comments__c = 'Previous BM Comment',

            Managing_Director_Country_Manage__c = md.Id,
            Managing_Director_Status__c = 'Approved',
            Managing_Director_Comments__c = 'MD Comment',
            Managing_Director_Date_Time__c = System.now(),
            Prev_Managing_Director_Comments__c = 'Previous MD Comment'
        );

        insert qli;
        
        QuoteLineItem qliCheck = [
            SELECT
            Sales_Manager__c,
            Country_Continent_Sales_Head_LOB_Head__c,
            Global_Sales_Head__c,
            Rotex_Board_Member__c,
            Managing_Director_Country_Manage__c
            FROM QuoteLineItem
            LIMIT 1
        ];
        
        System.debug('SM=' + qliCheck.Sales_Manager__c);
        System.debug('CH=' + qliCheck.Country_Continent_Sales_Head_LOB_Head__c);
        System.debug('GS=' + qliCheck.Global_Sales_Head__c);
        System.debug('BM=' + qliCheck.Rotex_Board_Member__c);
        System.debug('MD=' + qliCheck.Managing_Director_Country_Manage__c);
    }

    @IsTest
    static void testGetQuoteProducts() {
        
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        
        List<QuoteProductViewController.QuoteProductWrapper> result =
            QuoteProductViewController.getQuoteProducts(q.Id);
        
        Test.stopTest();
        
        System.assertEquals(1, result.size());
        
        QuoteProductViewController.QuoteProductWrapper wrapper = result[0];
        
        System.assertNotEquals(null, wrapper.quoteLineItemId);
        
        System.assertEquals('Test Product', wrapper.productName);
        System.assertEquals('TP-001', wrapper.productCode);
        
        System.assertEquals(2, wrapper.quantity);
        System.assertEquals(1000, wrapper.listPrice);
        System.assertEquals(850, wrapper.salesPrice);
        
        System.assertEquals(5, wrapper.discountSAP);
        System.assertEquals(10, wrapper.previousDiscount);
        System.assertEquals(15, wrapper.discount);
        
        System.assertEquals('Requested comment', wrapper.requestorComments);
        
        System.assertEquals(5, wrapper.soaUsers.size());
        
        // Sales Manager
        System.assert(wrapper.soaUsers[0].approverName.startsWith('SM -'));
        System.assertEquals('Approved', wrapper.soaUsers[0].status);
        System.assertEquals('SM Comment', wrapper.soaUsers[0].comments);
        System.assertEquals('Previous SM Comment', wrapper.soaUsers[0].previousComments);
        System.assertNotEquals(null, wrapper.soaUsers[0].dateTimeData);
        
        // Country Head
        System.assert(wrapper.soaUsers[1].approverName.startsWith('CH -'));
        System.assertEquals('Approved', wrapper.soaUsers[1].status);
        System.assertEquals('CH Comment', wrapper.soaUsers[1].comments);
        System.assertEquals('Previous CH Comment', wrapper.soaUsers[1].previousComments);
        
        // Global Sales Head
        System.assert(wrapper.soaUsers[2].approverName.startsWith('GS -'));
        System.assertEquals('Approved', wrapper.soaUsers[2].status);
        System.assertEquals('GS Comment', wrapper.soaUsers[2].comments);
        System.assertEquals('Previous GS Comment', wrapper.soaUsers[2].previousComments);
        
        // Board Member
        System.assert(wrapper.soaUsers[3].approverName.startsWith('BM -'));
        System.assertEquals('Approved', wrapper.soaUsers[3].status);
        System.assertEquals('BM Comment', wrapper.soaUsers[3].comments);
        System.assertEquals('Previous BM Comment', wrapper.soaUsers[3].previousComments);
        
        // Managing Director
        System.assert(wrapper.soaUsers[4].approverName.startsWith('MD -'));
        System.assertEquals('Approved', wrapper.soaUsers[4].status);
        System.assertEquals('MD Comment', wrapper.soaUsers[4].comments);
        System.assertEquals('Previous MD Comment', wrapper.soaUsers[4].previousComments);
    }

    
}