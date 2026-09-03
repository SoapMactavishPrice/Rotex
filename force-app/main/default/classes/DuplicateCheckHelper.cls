/**
 * GST + Pin duplicate rules for Customer registration (portal):
 *
 * - Non ROTEX: always allowed to register even with the same GST + Pin.
 * - ROTEX / BOTH:
 *   - Allowed if any existing same GST+Pin is only Pending (or Rejected / not Approved).
 *   - Blocked only when an existing Customer with the same GST + Pin is Approved
 *     and that customer's business line is ROTEX or BOTH (or BOTH overlaps).
 * - Pure ROTEX vs pure Non ROTEX never block each other.
 */
public without sharing class DuplicateCheckHelper {

    public static Account findGstPinDuplicate(String gstNo, String pinCode, Id excludeId) {
        return findGstPinDuplicate(gstNo, pinCode, 'BOTH', null, excludeId);
    }

    public static Account findGstPinDuplicate(
        String gstNo,
        String pinCode,
        String businessType,
        Id excludeId
    ) {
        return findGstPinDuplicate(gstNo, pinCode, businessType, null, excludeId);
    }

    public static Account findGstPinDuplicate(
        String gstNo,
        String pinCode,
        String businessType,
        Id dealerAccountId,
        Id excludeId
    ) {
        if (String.isBlank(gstNo) || String.isBlank(pinCode)) {
            return null;
        }

        // Non ROTEX registrations are never blocked by GST + Pin matches
        if (isPureNonRotex(businessType)) {
            return null;
        }

        // Only ROTEX / BOTH can be blocked; blank treated as full overlap for safety
        if (!involvesRotex(businessType) && String.isNotBlank(businessType)) {
            return null;
        }

        String pinField = getPinCodeFieldApiName();
        String gst = gstNo.trim();
        String pin = pinCode.trim();

        String query =
            'SELECT Id, Name, Business_type__c, Approval_Status__c, ' +
            'Channel_Partner_Name__c, Channel_Partner_Name__r.Name ' +
            'FROM Account ' +
            'WHERE GST_No__c = :gst ' +
            'AND ' + pinField + ' = :pin ' +
            'AND RecordType.DeveloperName = \'Customer\'';

        if (excludeId != null) {
            query += ' AND Id != :excludeId';
        }

        query += ' ORDER BY CreatedDate DESC LIMIT 200';

        List<Account> candidates = Database.query(query);
        if (candidates.isEmpty()) {
            return null;
        }

        for (Account existing : candidates) {
            // Only Approved blocks a new ROTEX / BOTH registration
            if (!isApproved(existing.Approval_Status__c)) {
                continue;
            }
            // Only Approved ROTEX / BOTH records block (pure Non ROTEX approved may coexist)
            if (!involvesRotex(existing.Business_type__c)) {
                continue;
            }
            return existing;
        }
        return null;
    }

    @TestVisible
    private static Boolean isPureNonRotex(String businessType) {
        if (String.isBlank(businessType)) {
            return false;
        }
        String v = businessType.trim().toUpperCase();
        return v == 'NON ROTEX' || v == 'NON-ROTEX' || v == 'NONROTEX';
    }

    @TestVisible
    private static Boolean businessLinesOverlap(String leftType, String rightType) {
        Boolean leftRotex = involvesRotex(leftType);
        Boolean leftNon = involvesNonRotex(leftType);
        Boolean rightRotex = involvesRotex(rightType);
        Boolean rightNon = involvesNonRotex(rightType);

        if (!leftRotex && !leftNon) {
            leftRotex = true;
            leftNon = true;
        }
        if (!rightRotex && !rightNon) {
            rightRotex = true;
            rightNon = true;
        }

        return (leftRotex && rightRotex) || (leftNon && rightNon);
    }

    @TestVisible
    private static Boolean involvesRotex(String businessType) {
        if (String.isBlank(businessType)) {
            return false;
        }
        String v = businessType.trim().toUpperCase();
        return v == 'ROTEX' || v == 'BOTH';
    }

    @TestVisible
    private static Boolean involvesNonRotex(String businessType) {
        if (String.isBlank(businessType)) {
            return false;
        }
        String v = businessType.trim().toUpperCase();
        return v == 'NON ROTEX' || v == 'NON-ROTEX' || v == 'NONROTEX' || v == 'BOTH';
    }

    @TestVisible
    private static Boolean isApproved(String approvalStatus) {
        return String.isNotBlank(approvalStatus)
            && approvalStatus.trim().equalsIgnoreCase('Approved');
    }

    private static String getPinCodeFieldApiName() {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();

        if (fieldMap.containsKey('Postal_Code__c')) {
            return 'Postal_Code__c';
        }

        return 'Pin_Code__c';
    }
}