public class QuoteLineItemSequentialApprovalHandler {

    public static void processSequentialApprovals(List<QuoteLineItem> qliList) {
        System.debug('=== SEQUENTIAL APPROVAL HANDLER START ===');
        System.debug('QLI Input Size: ' + qliList.size());

        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem qli : qliList) {
            if (qli.QuoteId != null) quoteIds.add(qli.QuoteId);
        }
        System.debug('SEQUENTIAL: Collected ' + quoteIds.size() + ' Quote IDs');

        Map<Id, Quote> quoteMap = new Map<Id, Quote>(
            [SELECT Id, Name, Account.Name, Sales_Rep__c, Sales_Manager__c,
                    Country_Continent_Sales_Head_LOB_Head__c, Global_Sales_Head__c,
                    Rotex_Board_Member__c, Managing_Director_Country_Manager__c
             FROM Quote
             WHERE Id IN :quoteIds]
        );
        System.debug('SEQUENTIAL: Queried ' + quoteMap.size() + ' Quotes');

        List<SOA_Matrix__c> matrixList = [
            SELECT SOA_Profile__c, Min_Discount__c, Max_Discount__c
            FROM SOA_Matrix__c
        ];
        System.debug('=== SEQUENTIAL: SOA Matrix Loaded ===');
        System.debug('Total SOA Matrix Records: ' + matrixList.size());
        for (SOA_Matrix__c m : matrixList) {
            System.debug('Matrix → Profile: ' + m.SOA_Profile__c + 
                       ' | Min: ' + m.Min_Discount__c + 
                       ' | Max: ' + m.Max_Discount__c);
        }

        Map<Id, QuoteLineItem> dbMap = new Map<Id, QuoteLineItem>(
            [SELECT Id, Discount_to_be_offered__c,
                    Sales_Manager_Status__c, Country_Continent_Sales_H_LOB_Status__c,
                    Global_Sales_Head_Status__c, Rotex_Board_Member_Status__c, Managing_Director_Status__c,
                    Sales_Manager__c, Country_Continent_Sales_Head_LOB_Head__c, Global_Sales_Head__c,
                    Rotex_Board_Member__c, Managing_Director_Country_Manage__c,
                    Product2.Name, QuoteId
             FROM QuoteLineItem
             WHERE Id IN :qliList]
        );
        System.debug('SEQUENTIAL: Queried ' + dbMap.size() + ' QLIs from database');

        List<QuoteLineItem> qlisToUpdate = new List<QuoteLineItem>();

        for (QuoteLineItem qli : qliList) {
            System.debug('');
            System.debug('--- SEQUENTIAL: Processing QLI: ' + qli.Id + ' ---');
            
            QuoteLineItem dbRec = dbMap.get(qli.Id);
            if (dbRec == null) {
                System.debug('SEQUENTIAL: ERROR - Database record not found for QLI: ' + qli.Id);
                continue;
            }

            System.debug('Discount_to_be_offered__c: ' + dbRec.Discount_to_be_offered__c);
            System.debug('Sales_Manager_Status__c: ' + dbRec.Sales_Manager_Status__c);
            System.debug('Country_Continent_Sales_H_LOB_Status__c: ' + dbRec.Country_Continent_Sales_H_LOB_Status__c);
            System.debug('Global_Sales_Head_Status__c: ' + dbRec.Global_Sales_Head_Status__c);
            System.debug('Rotex_Board_Member_Status__c: ' + dbRec.Rotex_Board_Member_Status__c);
            System.debug('Managing_Director_Status__c: ' + dbRec.Managing_Director_Status__c);
            
            Decimal offeredDiscount = dbRec.Discount_to_be_offered__c;
            if (offeredDiscount == null) {
                System.debug('SEQUENTIAL: Skipping - Discount is null');
                continue;
            }

            Quote parentQuote = quoteMap.get(dbRec.QuoteId);
            if (parentQuote == null) {
                System.debug('SEQUENTIAL: ERROR - Parent Quote not found');
                continue;
            }
            System.debug('Parent Quote: ' + parentQuote.Name);

            // 🔹 1. Sales Manager Approved → move to Country/Continent
            System.debug('');
            System.debug('SEQUENTIAL: Checking Rule 1 - Sales Manager → Country/Continent');
            if (dbRec.Sales_Manager_Status__c == 'Approved' &&
                (dbRec.Country_Continent_Sales_H_LOB_Status__c == null ||
                 dbRec.Country_Continent_Sales_H_LOB_Status__c == '')) {

                System.debug('SEQUENTIAL: ✓ Sales Manager is Approved, Country/Continent status is blank');
                System.debug('Checking if discount ' + offeredDiscount + ' is in Country/Continent range');
                
                if (isDiscountInRange(offeredDiscount, 'Country / Continent Sales Head / LOB Head', matrixList)) {
                    System.debug('SEQUENTIAL: ✓✓ Discount matches Country/Continent Head range');
                    System.debug('SEQUENTIAL: Setting Country_Continent_Sales_H_LOB_Status__c = Submitted');
                    dbRec.Country_Continent_Sales_H_LOB_Status__c = 'Submitted';
                    qlisToUpdate.add(dbRec);
                    System.debug('SEQUENTIAL: Sending email to Country/Continent Head: ' + dbRec.Country_Continent_Sales_Head_LOB_Head__c);
                    sendEmail(dbRec, parentQuote, dbRec.Country_Continent_Sales_Head_LOB_Head__c);
                    continue;
                } else {
                    System.debug('SEQUENTIAL: ✗ No match for Country/Continent Head at discount ' + offeredDiscount);
                }
            } else {
                System.debug('SEQUENTIAL: Rule 1 not applicable - Sales Manager not approved or Country/Continent already has status');
            }

            // 🔹 2. Country/Continent Approved → move to Global
            System.debug('');
            System.debug('SEQUENTIAL: Checking Rule 2 - Country/Continent → Global Sales Head');
            if (dbRec.Country_Continent_Sales_H_LOB_Status__c == 'Approved' &&
                (dbRec.Global_Sales_Head_Status__c == null || dbRec.Global_Sales_Head_Status__c == '')) {

                System.debug('SEQUENTIAL: ✓ Country/Continent is Approved, Global status is blank');
                System.debug('Checking if discount ' + offeredDiscount + ' is in Global Sales Head range');
                
                if (isDiscountInRange(offeredDiscount, 'Global Sales Head', matrixList)) {
                    System.debug('SEQUENTIAL: ✓✓ Discount matches Global Sales Head range');
                    System.debug('SEQUENTIAL: Setting Global_Sales_Head_Status__c = Submitted');
                    dbRec.Global_Sales_Head_Status__c = 'Submitted';
                    qlisToUpdate.add(dbRec);
                    System.debug('SEQUENTIAL: Sending email to Global Sales Head: ' + dbRec.Global_Sales_Head__c);
                    sendEmail(dbRec, parentQuote, dbRec.Global_Sales_Head__c);
                    continue;
                } else {
                    System.debug('SEQUENTIAL: ✗ No match for Global Sales Head at discount ' + offeredDiscount);
                }
            } else {
                System.debug('SEQUENTIAL: Rule 2 not applicable - Country/Continent not approved or Global already has status');
            }

            // 🔹 3. Global Approved → move to Rotex
            System.debug('');
            System.debug('SEQUENTIAL: Checking Rule 3 - Global Sales Head → Rotex Board Member');
            if (dbRec.Global_Sales_Head_Status__c == 'Approved' &&
                (dbRec.Rotex_Board_Member_Status__c == null || dbRec.Rotex_Board_Member_Status__c == '')) {

                System.debug('SEQUENTIAL: ✓ Global Sales Head is Approved, Rotex status is blank');
                System.debug('Checking if discount ' + offeredDiscount + ' is in Rotex Board Member range');
                
                if (isDiscountInRange(offeredDiscount, 'Rotex Board Member', matrixList)) {
                    System.debug('SEQUENTIAL: ✓✓ Discount matches Rotex range');
                    System.debug('SEQUENTIAL: Setting Rotex_Board_Member_Status__c = Submitted');
                    dbRec.Rotex_Board_Member_Status__c = 'Submitted';
                    qlisToUpdate.add(dbRec);
                    System.debug('SEQUENTIAL: Sending email to Rotex Board Member: ' + dbRec.Rotex_Board_Member__c);
                    sendEmail(dbRec, parentQuote, dbRec.Rotex_Board_Member__c);
                    continue;
                } else {
                    System.debug('SEQUENTIAL: ✗ No match for Rotex Board Member at discount ' + offeredDiscount);
                }
            } else {
                System.debug('SEQUENTIAL: Rule 3 not applicable - Global not approved or Rotex already has status');
            }

            // 🔹 4. Rotex Approved → move to MD
            System.debug('');
            System.debug('SEQUENTIAL: Checking Rule 4 - Rotex Board Member → Managing Director');
            if (dbRec.Rotex_Board_Member_Status__c == 'Approved' &&
                (dbRec.Managing_Director_Status__c == null || dbRec.Managing_Director_Status__c == '')) {

                System.debug('SEQUENTIAL: ✓ Rotex Board Member is Approved, MD status is blank');
                System.debug('Checking if discount ' + offeredDiscount + ' is in MD range');
                
                if (isDiscountInRange(offeredDiscount, 'Managing Director / Country Manager', matrixList)) {
                    System.debug('SEQUENTIAL: ✓✓ Discount matches MD range');
                    System.debug('SEQUENTIAL: Setting Managing_Director_Status__c = Submitted');
                    dbRec.Managing_Director_Status__c = 'Submitted';
                    qlisToUpdate.add(dbRec);
                    System.debug('SEQUENTIAL: Sending email to Managing Director: ' + dbRec.Managing_Director_Country_Manage__c);
                    sendEmail(dbRec, parentQuote, dbRec.Managing_Director_Country_Manage__c);
                    continue;
                } else {
                    System.debug('SEQUENTIAL: ✗ No match for MD at discount ' + offeredDiscount);
                }
            } else {
                System.debug('SEQUENTIAL: Rule 4 not applicable - Rotex not approved or MD already has status');
            }
            
            System.debug('SEQUENTIAL: No further approvals needed for this QLI');
        }

        System.debug('');
        System.debug('=== SEQUENTIAL: Update Phase ===');
        if (!qlisToUpdate.isEmpty()) {
            System.debug('SEQUENTIAL: ✓ Updating ' + qlisToUpdate.size() + ' QLIs');
            for (QuoteLineItem qli : qlisToUpdate) {
                System.debug('QLI to update: ' + qli.Id);
            }
            update qlisToUpdate;
            System.debug('SEQUENTIAL: ✓ QLIs updated successfully');
        } else {
            System.debug('SEQUENTIAL: No QLIs to update');
        }
        
        System.debug('=== SEQUENTIAL APPROVAL HANDLER END ===');
    }

    // 🔹 Range helper with debug
    private static Boolean isDiscountInRange(Decimal discount, String soaProfile, List<SOA_Matrix__c> matrixList) {
        Decimal rounded = discount.setScale(2);
        System.debug('  → isDiscountInRange called for Profile: ' + soaProfile + ', Discount: ' + rounded);

        for (SOA_Matrix__c m : matrixList) {
            System.debug('    Checking Matrix → Profile: ' + m.SOA_Profile__c +
                         ' | Min: ' + m.Min_Discount__c +
                         ' | Max: ' + m.Max_Discount__c);
            if (m.SOA_Profile__c == soaProfile) {
                System.debug('    ✓ Profile matched: ' + soaProfile);
                Decimal minVal = m.Min_Discount__c != null ? m.Min_Discount__c.setScale(2) : 0;
                Decimal maxVal = m.Max_Discount__c != null ? m.Max_Discount__c.setScale(2) : 0;
                System.debug('    Comparing: ' + rounded + ' >= ' + minVal + ' && ' + rounded + ' <= ' + maxVal);
                if (rounded >= minVal && rounded <= maxVal) {
                    System.debug('    ✓✓ RANGE MATCH FOUND for ' + soaProfile);
                    return true;
                } else {
                    System.debug('    ✗ Discount out of range');
                }
            }
        }
        System.debug('  → ✗ No match found for ' + soaProfile);
        return false;
    }

    // 🔹 Email
    private static void sendEmail(QuoteLineItem qli, Quote q, Id approverId) {
        System.debug('  → sendEmail called');
        System.debug('    QLI: ' + qli.Id);
        System.debug('    Quote: ' + q.Name);
        System.debug('    Approver ID: ' + approverId);
        
        if (approverId == null) {
            System.debug('  → ⚠️ Approver missing, skipping email');
            return;
        }

        User approver = [SELECT Id, Name, Email FROM User WHERE Id = :approverId LIMIT 1];
        User owner = [SELECT Name FROM User WHERE Id = :q.Sales_Rep__c LIMIT 1];

        System.debug('    Approver: ' + approver.Name + ' (' + approver.Email + ')');
        System.debug('    Quote Owner: ' + owner.Name);

        String body =
            'Dear ' + approver.Name + ',\n\n' +
            'A new discount approval request has been submitted.\n\n' +
            'Quote: ' + q.Name + '\n' +
            'Account: ' + (q.Account != null ? q.Account.Name : 'N/A') + '\n' +
            'Quote Owner: ' + owner.Name + '\n' +
            'Product: ' + (qli.Product2 != null ? qli.Product2.Name : 'N/A') + '\n' +
            'Discount to be Offered: ' + qli.Discount_to_be_offered__c + '%\n\n' +
            'Please review and take appropriate action.\n\n' +
            'Regards,\nSalesforce System';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { approver.Email });
        mail.setSubject('Discount Approval Request - Quote ' + q.Name);
        mail.setPlainTextBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        System.debug('  → ✓ Email sent successfully to ' + approver.Email);
    }

    public static void defineNextApprover(List<QuoteLineItem> qlis, Map<Id, QuoteLineItem> oldMap) {
        System.debug('=== DEFINE NEXT APPROVER START ===');
        System.debug('Processing ' + qlis.size() + ' QLIs');
        
        for (QuoteLineItem qli : qlis) {
            QuoteLineItem oldQli = (oldMap != null) ? oldMap.get(qli.Id) : null;
            if (oldQli == null) {
                System.debug('DEFINE NEXT APPROVER: Skipping QLI ' + qli.Id + ' (no old record, must be insert)');
                continue;
            }

            System.debug('--- DEFINE NEXT APPROVER: Processing QLI: ' + qli.Id);

            // Sales Manager -> next approver
            if (qli.Sales_Manager_Status__c == 'Approved' && qli.Sales_Manager_Status__c != oldQli.Sales_Manager_Status__c) {
                System.debug('DEFINE NEXT APPROVER: Sales Manager just approved, evaluating next approver from index 1');
                evaluateAndSetNextApprover(qli, 1);
            }

            // Country / Continent Sales Head / LOB Head -> next approver
            if (qli.Country_Continent_Sales_H_LOB_Status__c == 'Approved' && qli.Country_Continent_Sales_H_LOB_Status__c != oldQli.Country_Continent_Sales_H_LOB_Status__c) {
                System.debug('DEFINE NEXT APPROVER: Country/Continent Head just approved, evaluating next approver from index 2');
                evaluateAndSetNextApprover(qli, 2);
            }

            // Global Sales Head -> next approver
            if (qli.Global_Sales_Head_Status__c == 'Approved' && qli.Global_Sales_Head_Status__c != oldQli.Global_Sales_Head_Status__c) {
                System.debug('DEFINE NEXT APPROVER: Global Sales Head just approved, evaluating next approver from index 3');
                evaluateAndSetNextApprover(qli, 3);
            }

            // Rotex Board Member -> next approver
            if (qli.Rotex_Board_Member_Status__c == 'Approved' && qli.Rotex_Board_Member_Status__c != oldQli.Rotex_Board_Member_Status__c) {
                System.debug('DEFINE NEXT APPROVER: Rotex Board Member just approved, evaluating next approver from index 4');
                evaluateAndSetNextApprover(qli, 4);
            }
        }
        
        System.debug('=== DEFINE NEXT APPROVER END ===');
    }

    private static void evaluateAndSetNextApprover(QuoteLineItem qli, Integer fromProfileIdx) {
        System.debug('  → evaluateAndSetNextApprover called with fromProfileIdx: ' + fromProfileIdx);
        
        // Approver chain in order
        final List<String> profiles = new List<String>{
            'Sales Rep',
            'Sales Manager',
            'Country / Continent Sales Head / LOB Head',
            'Global Sales Head',
            'Rotex Board Member',
            'Managing Director / Country Manager'
        };

        final List<String> lookupFields = new List<String>{
            'Sales_Manager__c',
            'Country_Continent_Sales_Head_LOB_Head__c',
            'Global_Sales_Head__c',
            'Rotex_Board_Member__c',
            'Managing_Director_Country_Manage__c'
        };

        final List<String> statusFields = new List<String>{
            'Sales_Manager_Status__c',
            'Country_Continent_Sales_H_LOB_Status__c',
            'Global_Sales_Head_Status__c',
            'Rotex_Board_Member_Status__c',
            'Managing_Director_Status__c'
        };

        if (qli == null || fromProfileIdx == null) {
            System.debug('  → ERROR: qli or fromProfileIdx is null');
            return;
        }

        Decimal offered = qli.Discount_to_be_offered__c;
        System.debug('  → Discount offered: ' + offered);
        
        if (offered == null) {
            System.debug('  → ERROR: Discount is null');
            return;
        }

        if (fromProfileIdx < 0 || fromProfileIdx >= profiles.size()) {
            System.debug('  → ERROR: Invalid fromProfileIdx: ' + fromProfileIdx);
            return;
        }
        
        System.debug('  → Looking up SOA Matrix for profile: ' + profiles[fromProfileIdx]);
        SOA_Matrix__c prevSOA = getSOAMatrixEntry(profiles[fromProfileIdx]);
        if (prevSOA == null) {
            System.debug('  → ERROR: Previous SOA Matrix entry not found for ' + profiles[fromProfileIdx]);
            return;
        }
        System.debug('  → Previous SOA Max Discount: ' + prevSOA.Max_Discount__c);

        for (Integer j = fromProfileIdx + 1; j < profiles.size(); j++) {
            Integer nextIdx = j - 1;
            String lookupField = lookupFields[nextIdx];
            
            System.debug('  → Checking profile at index ' + j + ': ' + profiles[j]);
            System.debug('    Lookup field: ' + lookupField + ', Value: ' + qli.get(lookupField));

            if (qli.get(lookupField) != null) {
                System.debug('    ✓ Next approver found: ' + profiles[j]);
                SOA_Matrix__c nextSOA = getSOAMatrixEntry(profiles[j]);
                if (nextSOA != null) {
                    System.debug('    Next SOA Min: ' + nextSOA.Min_Discount__c + ', Max: ' + nextSOA.Max_Discount__c);
                    if (offered >= prevSOA.Max_Discount__c) {
                        System.debug('    ✓ Discount (' + offered + ') >= Previous Max (' + prevSOA.Max_Discount__c + ')');
                        System.debug('    Setting ' + statusFields[nextIdx] + ' = Submitted');
                        qli.put(statusFields[nextIdx], 'Submitted');
                    } else {
                        System.debug('    ✗ Discount (' + offered + ') < Previous Max (' + prevSOA.Max_Discount__c + '), no approval needed');
                    }
                } else {
                    System.debug('    ERROR: SOA Matrix entry not found for ' + profiles[j]);
                }
                break;
            } else {
                System.debug('    ✗ No approver assigned for ' + profiles[j]);
            }
        }
    }

    private static Map<String, SOA_Matrix__c> soaMatrix;
    private static SOA_Matrix__c getSOAMatrixEntry(String soaProfile) {
        if (soaMatrix == null) {
            System.debug('  → Loading SOA Matrix (first time)');
            soaMatrix = new Map<String, SOA_Matrix__c>();
            for (SOA_Matrix__c soa : [
                SELECT Id, Name, SOA_Profile__c, Discount_on_Price_List__c, Min_Discount__c, Max_Discount__c
                FROM SOA_Matrix__c
            ]) {
                if (soa.SOA_Profile__c != null) {
                    soaMatrix.put(soa.SOA_Profile__c, soa);
                    System.debug('    Loaded: ' + soa.SOA_Profile__c + ' (Min: ' + soa.Min_Discount__c + ', Max: ' + soa.Max_Discount__c + ')');
                }
            }
        }
        return soaMatrix.get(soaProfile);
    }

    private static Map<Id, User> userMap;
    private static User getUser(Id userId) {
        if (userMap == null) {
            userMap = new Map<Id, User>();
            for (User u : [
                SELECT Id, Name, UserRoleId, UserRole.Name, SOA_Profile__c
                FROM User
                WHERE IsActive = true
            ]) {
                userMap.put(u.Id, u);
            }
        }
        return userMap.get(userId);
    }
}