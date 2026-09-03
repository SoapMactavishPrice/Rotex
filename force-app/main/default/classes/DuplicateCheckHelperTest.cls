@isTest
public class DuplicateCheckHelperTest {

    private static Id getCustomerRecordTypeId() {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
              AND DeveloperName = 'Customer'
            LIMIT 1
        ].Id;
    }

    private static void setPin(Account acc, String pin) {
        if (Schema.SObjectType.Account.fields.getMap().containsKey('Postal_Code__c')) {
            acc.put('Postal_Code__c', pin);
        } else {
            acc.put('Pin_Code__c', pin);
        }
    }

    private static Account insertDealer(String name) {
        Account d = new Account(Name = name + ' ' + Crypto.getRandomInteger());
        insert d;
        return d;
    }

    private static Account insertCustomer(
        Id dealerId,
        String name,
        String gst,
        String pin,
        String businessType,
        String approvalStatus
    ) {
        Account acc = new Account(
            Name = name + ' ' + Crypto.getRandomInteger(),
            RecordTypeId = getCustomerRecordTypeId(),
            GST_No__c = gst,
            Business_type__c = businessType,
            Approval_Status__c = approvalStatus,
            Channel_Partner_Name__c = dealerId
        );
        setPin(acc, pin);
        insert acc;
        return acc;
    }

    @isTest
    static void testPendingAllowsSameGstPinRotex() {
        Account dealer = insertDealer('CP Pending');
        Account existing = insertCustomer(
            dealer.Id, 'Pending Rotex', '22AAAAA0000A1Z5', '110001',
            'ROTEX', 'Pending Approval'
        );

        Test.startTest();
        Account sameCpPending = DuplicateCheckHelper.findGstPinDuplicate(
            '22AAAAA0000A1Z5', '110001', 'ROTEX', dealer.Id, null
        );
        Account bothPendingOk = DuplicateCheckHelper.findGstPinDuplicate(
            '22AAAAA0000A1Z5', '110001', 'BOTH', dealer.Id, null
        );
        Account nonRotexOk = DuplicateCheckHelper.findGstPinDuplicate(
            '22AAAAA0000A1Z5', '110001', 'Non ROTEX', dealer.Id, null
        );
        Account selfExcluded = DuplicateCheckHelper.findGstPinDuplicate(
            '22AAAAA0000A1Z5', '110001', 'ROTEX', dealer.Id, existing.Id
        );
        Test.stopTest();

        System.assertEquals(null, sameCpPending, 'Pending ROTEX must not block new ROTEX');
        System.assertEquals(null, bothPendingOk, 'Pending must not block BOTH');
        System.assertEquals(null, nonRotexOk, 'Non ROTEX always allowed');
        System.assertEquals(null, selfExcluded);
    }

    @isTest
    static void testApprovedRotexBlocksRotexAndBoth() {
        Account dealer = insertDealer('CP Approved');
        insertCustomer(
            dealer.Id, 'Approved Rotex', '22BBBBB0000B1Z5', '110002',
            'ROTEX', 'Approved'
        );

        Account otherDealer = insertDealer('CP Other');
        Test.startTest();
        Account sameCpRotex = DuplicateCheckHelper.findGstPinDuplicate(
            '22BBBBB0000B1Z5', '110002', 'ROTEX', dealer.Id, null
        );
        Account otherCpRotex = DuplicateCheckHelper.findGstPinDuplicate(
            '22BBBBB0000B1Z5', '110002', 'ROTEX', otherDealer.Id, null
        );
        Account bothBlocked = DuplicateCheckHelper.findGstPinDuplicate(
            '22BBBBB0000B1Z5', '110002', 'BOTH', otherDealer.Id, null
        );
        Account nonRotexOk = DuplicateCheckHelper.findGstPinDuplicate(
            '22BBBBB0000B1Z5', '110002', 'Non ROTEX', otherDealer.Id, null
        );
        Test.stopTest();

        System.assertNotEquals(null, sameCpRotex, 'Approved ROTEX blocks ROTEX');
        System.assertNotEquals(null, otherCpRotex, 'Approved ROTEX blocks other CP ROTEX');
        System.assertNotEquals(null, bothBlocked, 'Approved ROTEX blocks BOTH');
        System.assertEquals(null, nonRotexOk, 'Non ROTEX can reuse GST+pin');
    }

    @isTest
    static void testApprovedNonRotexDoesNotBlockRotex() {
        Account dealer = insertDealer('CP NonRotex');
        insertCustomer(
            dealer.Id, 'Approved Non', '22CCCCC0000C1Z5', '110003',
            'Non ROTEX', 'Approved'
        );

        Test.startTest();
        Account rotexOk = DuplicateCheckHelper.findGstPinDuplicate(
            '22CCCCC0000C1Z5', '110003', 'ROTEX', dealer.Id, null
        );
        Account nonRotexOk = DuplicateCheckHelper.findGstPinDuplicate(
            '22CCCCC0000C1Z5', '110003', 'Non ROTEX', dealer.Id, null
        );
        Test.stopTest();

        System.assertEquals(null, rotexOk);
        System.assertEquals(null, nonRotexOk);
    }

    @isTest
    static void testNotFoundAndOverloads() {
        System.assertEquals(
            null,
            DuplicateCheckHelper.findGstPinDuplicate(
                '00XXXXX0000X0X0', '999999', 'ROTEX', null, null
            )
        );
        System.assertEquals(
            null,
            DuplicateCheckHelper.findGstPinDuplicate(
                null, '110001', null
            )
        );
        System.assertEquals(
            null,
            DuplicateCheckHelper.findGstPinDuplicate(
                '22DDDDD0000D1Z5', '110004', 'ROTEX', null
            )
        );
        System.assertEquals(
            null,
            DuplicateCheckHelper.findGstPinDuplicate(
                '22DDDDD0000D1Z5', '110004', null
            )
        );
        System.assertEquals(true, DuplicateCheckHelper.businessLinesOverlap('ROTEX', 'BOTH'));
        System.assertEquals(true, DuplicateCheckHelper.involvesRotex('both'));
        System.assertEquals(true, DuplicateCheckHelper.involvesNonRotex('Non ROTEX'));
        System.assertEquals(true, DuplicateCheckHelper.isApproved('Approved'));
        System.assertEquals(false, DuplicateCheckHelper.isApproved('Pending Approval'));
    }

    @isTest
    static void testApprovedBothBlocks() {
        Account dealer = insertDealer('CP Both');
        insertCustomer(
            dealer.Id, 'Approved Both', '22EEEEE0000E1Z5', '110005',
            'BOTH', 'Approved'
        );
        Test.startTest();
        Account blocked = DuplicateCheckHelper.findGstPinDuplicate(
            '22EEEEE0000E1Z5', '110005', 'ROTEX', dealer.Id, null
        );
        Test.stopTest();
        System.assertNotEquals(null, blocked);
    }
}