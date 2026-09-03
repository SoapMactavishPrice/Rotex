@IsTest
private class DealerDataExportControllerTest {
    @IsTest
    static void previewAndExport_handlesInvalidObject() {
        Boolean threw = false;
        try {
            DealerDataExportController.getExportPreview(
                'Unknown',
                Date.today().addDays(-7),
                Date.today(),
                'All',
                'All',
                '',
                ''
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Unsupported object should throw');
    }

    @IsTest
    static void preview_validatesDateOrder() {
        Boolean threw = false;
        try {
            DealerDataExportController.getExportPreview(
                'Quote',
                Date.today(),
                Date.today().addDays(-1),
                'All',
                'All',
                '',
                ''
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Invalid date order should throw');
    }

    @IsTest
    static void preview_quote_withFilters_runs() {
        Test.startTest();
        DealerDataExportController.PreviewResult preview =
            DealerDataExportController.getExportPreview(
                'Quote',
                Date.today().addDays(-30),
                Date.today(),
                'Draft',
                'Self',
                '',
                ''
            );
        List<DealerDataExportController.AccountOption> accounts =
            DealerDataExportController.getExportAccounts('Quote');
        List<DealerDataExportController.AccountOption> productAccounts =
            DealerDataExportController.getExportAccounts('Product');
        Test.stopTest();
        System.assertNotEquals(null, preview);
        System.assertEquals('Quotes', preview.objectLabel);
        System.assert(preview.recordCount >= 0);
        System.assert(!accounts.isEmpty(), 'Quote export should return account options');
        System.assertEquals(0, productAccounts.size(), 'Product export should not use account filter');
    }

    @IsTest
    static void previewAndExport_allObjectKeys_run() {
        Date fromDate = Date.today().addDays(-30);
        Date toDate = Date.today();
        List<String> keys = new List<String>{
            'Lead',
            'Event',
            'Task',
            'Customer',
            'Contact',
            'Product',
            'Inventory',
            'Quote',
            'Order',
            'Invoice',
            'Case',
            'Picklist'
        };

        Test.startTest();
        for (String key : keys) {
            DealerDataExportController.PreviewResult preview =
                DealerDataExportController.getExportPreview(
                    key,
                    fromDate,
                    toDate,
                    statusFor(key),
                    typeFor(key),
                    'a',
                    ''
                );
            System.assertNotEquals(null, preview, 'Preview null for ' + key);
            System.assert(preview.recordCount >= 0, 'Count for ' + key);

            DealerDataExportController.ExportResult exp =
                DealerDataExportController.exportData(
                    key,
                    fromDate,
                    toDate,
                    statusFor(key),
                    typeFor(key),
                    '',
                    ''
                );
            System.assertNotEquals(null, exp, 'Export null for ' + key);
            System.assertNotEquals(null, exp.fileName, 'Filename for ' + key);
            System.assertNotEquals(null, exp.csvContent, 'Content for ' + key);
            System.assert(exp.csvContent.contains('Workbook'), 'Excel XML for ' + key);
        }
        DealerDataExportController.getExportAccounts('Order');
        DealerDataExportController.getExportAccounts('Contact');
        DealerDataExportController.getExportAccounts('Complaint');
        DealerDataExportController.getExportAccounts('Picklist');
        Test.stopTest();
    }

    @IsTest
    static void preview_rejectsMissingDates() {
        Boolean threw = false;
        try {
            DealerDataExportController.getExportPreview(
                'Lead',
                null,
                Date.today(),
                'All',
                'All',
                '',
                ''
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Missing dates should throw');
    }

    @IsTest
    static void preview_rejectsRangeOver366() {
        Boolean threw = false;
        try {
            DealerDataExportController.getExportPreview(
                'Lead',
                Date.today().addDays(-400),
                Date.today(),
                'All',
                'All',
                '',
                ''
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Range > 366 days should throw');
    }

    private static String statusFor(String key) {
        if (key == 'Quote') {
            return 'Draft';
        }
        if (key == 'Contact' || key == 'Product') {
            return 'Active';
        }
        if (key == 'Customer') {
            return 'Pending Approval';
        }
        return 'All';
    }

    private static String typeFor(String key) {
        if (key == 'Quote') {
            return 'Self';
        }
        if (key == 'Customer') {
            return 'ROTEX';
        }
        return 'All';
    }
}