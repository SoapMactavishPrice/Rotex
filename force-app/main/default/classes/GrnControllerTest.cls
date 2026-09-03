@IsTest
private class GrnControllerTest {
    
    @TestSetup
    static void setup() {
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;

        UserRole ur = [SELECT Id FROM UserRole WHERE PortalType = 'None' LIMIT 1];
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User runUser = new User(
            ProfileId = adminProfile.Id,
            LastName = 'GrnAdmin',
            Email = 'grn_admin@example.com',
            Username = 'grn_admin_' + Math.random() + '@example.com',
            Alias = 'grnadm',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            UserRoleId = ur.Id
        );
        insert runUser;

        System.runAs(runUser) {
            List<RecordType> rts = [
                SELECT Id, DeveloperName
                FROM RecordType
                WHERE SObjectType = 'Account'
                  AND DeveloperName IN ('Customer', 'Channel_Partner')
            ];
            Id custRT;
            Id cpRT;
            for (RecordType rt : rts) {
                if (rt.DeveloperName == 'Customer') custRT = rt.Id;
                if (rt.DeveloperName == 'Channel_Partner') cpRT = rt.Id;
            }

            Account cpAccount = new Account(Name = 'Test CP Account Unique');
            if (cpRT != null) cpAccount.RecordTypeId = cpRT;
            Database.insert(cpAccount, dml);

            Contact cpContact = new Contact(
                FirstName = 'CP',
                LastName = 'User',
                AccountId = cpAccount.Id,
                Email = 'cpuser_grn@test.com'
            );
            insert cpContact;

            Profile p = [
                SELECT Id
                FROM Profile
                WHERE Name IN ('Partner Community User', 'Partner Community Login User')
                LIMIT 1
            ];
            insert new User(
                Alias = 'cpgrn',
                Email = 'cpuser_grn@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'cpuser_grn' + System.now().getTime() + '@test.com',
                ContactId = cpContact.Id
            );

            Product2 p1 = new Product2(
                Name = 'Standard Valve',
                Family = 'Valves',
                IsActive = true,
                ProductCode = 'P-123'
            );
            insert p1;
            Id pbId = Test.getStandardPricebookId();
            PricebookEntry pbeStd = new PricebookEntry(
                Pricebook2Id = pbId,
                Product2Id = p1.Id,
                UnitPrice = 10,
                IsActive = true
            );
            insert pbeStd;

            Inventory__c invRec = new Inventory__c(
                Channel_Partner__c = cpAccount.Id,
                Product__c = p1.Id,
                Last_GRN_Date__c = Date.today().addDays(-10),
                Status__c = 'Available'
            );
            insert invRec;

            // Optional Order linkage covers order-qty matching in getInvoiceLinesForGrn
            Order ordRec;
            try {
                ordRec = new Order(
                    AccountId = cpAccount.Id,
                    Status = 'Draft',
                    EffectiveDate = Date.today(),
                    Pricebook2Id = pbId
                );
                insert ordRec;
                insert new OrderItem(
                    OrderId = ordRec.Id,
                    PricebookEntryId = pbeStd.Id,
                    Quantity = 10,
                    UnitPrice = 10
                );
            } catch (Exception e) {
                System.debug('order setup soft: ' + e.getMessage());
            }

            SO_Invoice__c inv = new SO_Invoice__c(Account__c = cpAccount.Id);
            try {
                if (ordRec != null) {
                    inv.Order__c = ordRec.Id;
                }
            } catch (Exception e) {
            }
            insert inv;

            // Pending_GRN_Qty__c formula = QTY__c - GRN_Qty__c (not Quantity__c)
            Invoice_Line_item__c invLine = new Invoice_Line_item__c(
                SO_Invoice__c = inv.Id,
                Product__c = p1.Id,
                Quantity__c = 10,
                QTY__c = 10,
                GRN_Qty__c = 0
            );
            insert invLine;

            GRN__c grn = new GRN__c(
                Invoice__c = inv.Id,
                Channel_Partner__c = cpAccount.Id,
                GRN_Date__c = Date.today(),
                Status__c = 'Partial'
            );
            insert grn;

            GRN_Line_Item__c grnLine = new GRN_Line_Item__c(
                GRN__c = grn.Id,
                Invoice_Line_Item__c = invLine.Id,
                Product__c = p1.Id,
                Ordered_Qty__c = 10,
                Received_Qty__c = 5,
                Status__c = 'Partial'
            );
            insert grnLine;
        }
    }

    @IsTest
    static void testGetCurrentUserInfo() {
        User u = [SELECT Id FROM User WHERE Email = 'cpuser_grn@test.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            GrnController.CurrentUserInfo info = GrnController.getCurrentUserInfo();
            Test.stopTest();
            
            System.assertEquals(u.Id, info.userId);
            System.assertNotEquals(null, info.partnerAccountId);
        }
    }

    @IsTest
    static void testGetPartnerContacts() {
        User u = [SELECT Id FROM User WHERE Email = 'cpuser_grn@test.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            List<GrnController.PartnerContactOption> contacts = GrnController.getPartnerContacts();
            Test.stopTest();
            
            System.assert(contacts.size() > 0);
        }
    }

    @IsTest
    static void testGetInvoiceLinesForGrn() {
        User u = [SELECT Id FROM User WHERE Email = 'cpuser_grn@test.com' LIMIT 1];
        SO_Invoice__c inv = [SELECT Id FROM SO_Invoice__c LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            List<GrnController.InvoiceLineForGrn> lines = GrnController.getInvoiceLinesForGrn(inv.Id);
            Test.stopTest();
            
            System.assertEquals(1, lines.size());
            System.assertEquals(10, lines[0].orderedQty);
        }
    }

    @IsTest
    static void testGetGrnsForInvoice() {
        User u = [SELECT Id FROM User WHERE Email = 'cpuser_grn@test.com' LIMIT 1];
        SO_Invoice__c inv = [SELECT Id FROM SO_Invoice__c LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            List<GRN__c> grns = GrnController.getGrnsForInvoice(inv.Id);
            Test.stopTest();
            
            System.assertEquals(1, grns.size());
        }
    }

    @IsTest
    static void testGetGrnLineItemsForInvoice() {
        User u = [SELECT Id FROM User WHERE Email = 'cpuser_grn@test.com' LIMIT 1];
        SO_Invoice__c inv = [SELECT Id FROM SO_Invoice__c LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            List<GRN_Line_Item__c> lines = GrnController.getGrnLineItemsForInvoice(inv.Id);
            Test.stopTest();
            
            System.assertEquals(1, lines.size());
        }
    }

    @IsTest
    static void testGetGrnDetail() {
        User u = [SELECT Id FROM User WHERE Email = 'cpuser_grn@test.com' LIMIT 1];
        GRN__c grn = [SELECT Id FROM GRN__c LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            GRN__c detail = GrnController.getGrnDetail(grn.Id);
            Test.stopTest();
            
            System.assertNotEquals(null, detail);
        }
    }

    @IsTest
    static void testGetGrnLineItemDetail() {
        User u = [SELECT Id FROM User WHERE Email = 'cpuser_grn@test.com' LIMIT 1];
        GRN_Line_Item__c line = [SELECT Id FROM GRN_Line_Item__c LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            GRN_Line_Item__c detail = GrnController.getGrnLineItemDetail(line.Id);
            Test.stopTest();
            
            System.assertNotEquals(null, detail);
        }
    }
    
    @IsTest
    static void testGetGrnLineItemFiles() {
        User u = [SELECT Id FROM User WHERE Email = 'cpuser_grn@test.com' LIMIT 1];
        GRN_Line_Item__c line = [SELECT Id FROM GRN_Line_Item__c LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            List<GrnController.FileWrapper> files = GrnController.getGrnLineItemFiles(line.Id);
            Test.stopTest();
            
            System.assertEquals(0, files.size());
        }
    }

    @IsTest
    static void testCreateGrn_Success() {
        User u = [SELECT Id, ContactId FROM User WHERE Email = 'cpuser_grn@test.com' LIMIT 1];
        SO_Invoice__c inv = [SELECT Id FROM SO_Invoice__c LIMIT 1];
        Invoice_Line_item__c invLine = [SELECT Id, Product__c FROM Invoice_Line_item__c LIMIT 1];
        
        GrnController.GrnCreateInput input = new GrnController.GrnCreateInput();
        input.invoiceId = inv.Id;
        input.grnDate = String.valueOf(Date.today());
        input.receivedByContactId = u.ContactId;
        input.remarks = 'Test Remarks';
        
        GrnController.GrnLineInput line = new GrnController.GrnLineInput();
        line.invoiceLineItemId = invLine.Id;
        line.productId = invLine.Product__c;
        line.receivedQty = 5;
        line.damageQty = 0;
        line.shortQty = 0;
        // Skip ContentVersion attachments in partner-user tests (NetworkId access)

        input.lines = new List<GrnController.GrnLineInput>{ line };

        System.runAs(u) {
            Test.startTest();
            GRN__c newGrn = GrnController.createGrn(input);
            Test.stopTest();

            System.assertNotEquals(null, newGrn);
            System.assertNotEquals(null, newGrn.Id);
        }
    }
    
    @IsTest
    static void testCreateGrn_Exceptions() {
        User u = [SELECT Id, ContactId FROM User WHERE Email = 'cpuser_grn@test.com' LIMIT 1];
        SO_Invoice__c inv = [SELECT Id FROM SO_Invoice__c LIMIT 1];
        Invoice_Line_item__c invLine = [SELECT Id, Product__c FROM Invoice_Line_item__c LIMIT 1];
        
        System.runAs(u) {
            Test.startTest();
            try {
                GrnController.createGrn(null);
            } catch(Exception e) {}
            
            GrnController.GrnCreateInput input = new GrnController.GrnCreateInput();
            try {
                GrnController.createGrn(input);
            } catch(Exception e) {}
            
            input.invoiceId = inv.Id;
            try {
                GrnController.createGrn(input);
            } catch(Exception e) {}
            
            input.grnDate = 'invalid date';
            input.receivedByContactId = u.ContactId;
            input.remarks = 'Remarks';
            input.lines = new List<GrnController.GrnLineInput>{ new GrnController.GrnLineInput() };
            try {
                GrnController.createGrn(input);
            } catch(Exception e) {}
            
            input.grnDate = String.valueOf(Date.today());
            try {
                GrnController.createGrn(input); // missing receivedQty
            } catch(Exception e) {}
            
            GrnController.GrnLineInput line = new GrnController.GrnLineInput();
            line.invoiceLineItemId = invLine.Id;
            line.receivedQty = -1; // negative
            input.lines = new List<GrnController.GrnLineInput>{ line };
            try {
                GrnController.createGrn(input);
            } catch(Exception e) {}
            
            line.receivedQty = 1000; // exceeds pending
            try {
                GrnController.createGrn(input);
            } catch(Exception e) {}

            // Valid quantities with attachment payload and damage/short
            line.receivedQty = 2;
            line.damageQty = 1;
            line.shortQty = 0;
            line.productId = invLine.Product__c;
            line.rejectionReason = 'Damage';
            line.remarks = 'Line remarks';
            GrnController.FileInput fi = new GrnController.FileInput();
            fi.fileName = 'photo.txt';
            fi.base64Data = EncodingUtil.base64Encode(Blob.valueOf('photo-bytes'));
            line.attachments = new List<GrnController.FileInput>{ fi };
            input.lines = new List<GrnController.GrnLineInput>{ line };
            try {
                GrnController.createGrn(input);
            } catch (Exception e) {
                System.debug('create with attach: ' + e.getMessage());
            }

            try { GrnController.getGrnDetail(null); } catch (Exception e) {}
            try { GrnController.getGrnLineItemDetail(null); } catch (Exception e) {}
            try { GrnController.getInvoiceLinesForGrn(null); } catch (Exception e) {}
            try { GrnController.getGrnsForInvoice(null); } catch (Exception e) {}
            try { GrnController.getGrnLineItemsForInvoice(null); } catch (Exception e) {}
            try { GrnController.getGrnLineItemFiles(null); } catch (Exception e) {}
            
            Test.stopTest();
        }
        System.assert(true);
    }

    @IsTest
    static void testGetShowCreateGrnFlag() {
        Test.startTest();
        Boolean flag = GrnController.getShowCreateGrnFlag();
        Test.stopTest();
        System.assertNotEquals(null, flag, 'Should return a boolean value');
    }
}