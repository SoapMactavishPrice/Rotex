public class QuoteLineItemSequentialApprovalHandler {

    public static void processSequentialApprovals(List<QuoteLineItem> qliList) {
        System.debug('=== Sequential Approval START ===');
        System.debug('QLI Input Size: ' + qliList.size());

        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem qli : qliList) {
            if (qli.QuoteId != null) quoteIds.add(qli.QuoteId);
        }

        Map<Id, Quote> quoteMap = new Map<Id, Quote>(
            [SELECT Id, Name, Account.Name, Sales_Rep__c, Sales_Manager__c,
                    Country_Continent_Sales_Head_LOB_Head__c, Global_Sales_Head__c,
                    Rotex_Board_Member__c, Managing_Director_Country_Manager__c
             FROM Quote
             WHERE Id IN :quoteIds]
        );

        List<SOA_Matrix__c> matrixList = [
            SELECT SOA_Profile__c, Min_Discount__c, Max_Discount__c
            FROM SOA_Matrix__c
        ];
        System.debug('=== SOA Matrix Loaded: ' + matrixList);

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

        List<QuoteLineItem> qlisToUpdate = new List<QuoteLineItem>();

        for (QuoteLineItem qli : qliList) {
            QuoteLineItem dbRec = dbMap.get(qli.Id);
            if (dbRec == null) continue;

            System.debug('--- Processing QLI: ' + dbRec.Id + ' Discount: ' + dbRec.Discount_to_be_offered__c);
            Decimal offeredDiscount = dbRec.Discount_to_be_offered__c;
            if (offeredDiscount == null) continue;

            Quote parentQuote = quoteMap.get(dbRec.QuoteId);
            if (parentQuote == null) continue;

            // 🔹 1. Sales Manager Approved → move to Country/Continent
            if (dbRec.Sales_Manager_Status__c == 'Approved' &&
                (dbRec.Country_Continent_Sales_H_LOB_Status__c == null ||
                 dbRec.Country_Continent_Sales_H_LOB_Status__c == '')) {

                System.debug('Checking Country/Continent for discount ' + offeredDiscount);
                if (isDiscountInRange(offeredDiscount, 'Country / Continent Sales Head / LOB Head', matrixList)) {
                    System.debug('Matched Country/Continent Head range');
                    dbRec.Country_Continent_Sales_H_LOB_Status__c = 'Submitted';
                    qlisToUpdate.add(dbRec);
                    sendEmail(dbRec, parentQuote, dbRec.Country_Continent_Sales_Head_LOB_Head__c);
                    continue;
                } else {
                    System.debug('❌ No match for Country/Continent Head at ' + offeredDiscount);
                }
            }

            // 🔹 2. Country/Continent Approved → move to Global
            if (dbRec.Country_Continent_Sales_H_LOB_Status__c == 'Approved' &&
                (dbRec.Global_Sales_Head_Status__c == null || dbRec.Global_Sales_Head_Status__c == '')) {

                System.debug('Checking Global Sales Head for discount ' + offeredDiscount);
                if (isDiscountInRange(offeredDiscount, 'Global Sales Head', matrixList)) {
                    System.debug('Matched Global Sales Head range');
                    dbRec.Global_Sales_Head_Status__c = 'Submitted';
                    qlisToUpdate.add(dbRec);
                    sendEmail(dbRec, parentQuote, dbRec.Global_Sales_Head__c);
                    continue;
                } else {
                    System.debug('❌ No match for Global Sales Head at ' + offeredDiscount);
                }
            }

            // 🔹 3. Global Approved → move to Rotex
            if (dbRec.Global_Sales_Head_Status__c == 'Approved' &&
                (dbRec.Rotex_Board_Member_Status__c == null || dbRec.Rotex_Board_Member_Status__c == '')) {

                System.debug('Checking Rotex Board Member for discount ' + offeredDiscount);
                if (isDiscountInRange(offeredDiscount, 'Rotex Board Member', matrixList)) {
                    System.debug('Matched Rotex range');
                    dbRec.Rotex_Board_Member_Status__c = 'Submitted';
                    qlisToUpdate.add(dbRec);
                    sendEmail(dbRec, parentQuote, dbRec.Rotex_Board_Member__c);
                    continue;
                } else {
                    System.debug('❌ No match for Rotex Board Member at ' + offeredDiscount);
                }
            }

            // 🔹 4. Rotex Approved → move to MD
            if (dbRec.Rotex_Board_Member_Status__c == 'Approved' &&
                (dbRec.Managing_Director_Status__c == null || dbRec.Managing_Director_Status__c == '')) {

                System.debug('Checking MD for discount ' + offeredDiscount);
                if (isDiscountInRange(offeredDiscount, 'Managing Director / Country Manager', matrixList)) {
                    System.debug('Matched MD range');
                    dbRec.Managing_Director_Status__c = 'Submitted';
                    qlisToUpdate.add(dbRec);
                    sendEmail(dbRec, parentQuote, dbRec.Managing_Director_Country_Manage__c);
                    continue;
                } else {
                    System.debug('❌ No match for MD at ' + offeredDiscount);
                }
            }
        }

        if (!qlisToUpdate.isEmpty()) {
            System.debug('=== Updating ' + qlisToUpdate.size() + ' QLIs ===');
            update qlisToUpdate;
        } else {
            System.debug('=== No QLIs to update ===');
        }
    }

    // 🔹 Range helper with debug
    private static Boolean isDiscountInRange(Decimal discount, String soaProfile, List<SOA_Matrix__c> matrixList) {
        Decimal rounded = discount.setScale(2);
        System.debug('Checking SOA Profile: ' + soaProfile + ' for Discount: ' + rounded);

        for (SOA_Matrix__c m : matrixList) {
            System.debug('Matrix Row → Profile: ' + m.SOA_Profile__c +
                         ' | Min: ' + m.Min_Discount__c +
                         ' | Max: ' + m.Max_Discount__c);
            if (m.SOA_Profile__c == soaProfile) {
                Decimal minVal = m.Min_Discount__c != null ? m.Min_Discount__c.setScale(2) : 0;
                Decimal maxVal = m.Max_Discount__c != null ? m.Max_Discount__c.setScale(2) : 0;
                if (rounded >= minVal && rounded <= maxVal) {
                    System.debug('✅ Match Found → ' + soaProfile);
                    return true;
                }
            }
        }
        System.debug('❌ No match found for ' + soaProfile);
        return false;
    }

    // 🔹 Email
    private static void sendEmail(QuoteLineItem qli, Quote q, Id approverId) {
        if (approverId == null) {
            System.debug('⚠️ Approver missing, skipping email.');
            return;
        }

        User approver = [SELECT Id, Name, Email FROM User WHERE Id = :approverId LIMIT 1];
        User owner = [SELECT Name FROM User WHERE Id = :q.Sales_Rep__c LIMIT 1];

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
        System.debug('✅ Email sent to ' + approver.Email);
    }


    /*
    public static void defineApproversDependingOnDiscount(List<QuoteLineItem> qlis, Map<Id, QuoteLineItem> oldMap) {
        if (oldMap == null) {
            oldMap = new Map<Id, QuoteLineItem>();
        }

        Set<Id> qliIds = new Set<Id>();
        for(QuoteLineItem qli : qlis) {
            if(oldMap.containsKey(qli.Id)) {
                if(qli.Discount_to_be_offered__c != oldMap.get(qli.Id).Discount_to_be_offered__c) {
                    qliIds.add(qli.Id);
                }
            }
            else {
                qliIds.add(qli.Id);
            }
        }

        if (qliIds.isEmpty()) {
            return;
        }



        List<SOA_Matrix__c> soaMatrixRecords = [
            SELECT Id, Name, SOA_Profile__c, Discount_on_Price_List__c, Min_Discount__c, Max_Discount__c
            FROM SOA_Matrix__c
        ];
        Map<String, SOA_Matrix__c> mapSOAMatrix = new Map<String, SOA_Matrix__c>();
        for(SOA_Matrix__c soa : soaMatrixRecords) {
            mapSOAMatrix.put(soa.SOA_Profile__c, soa);
        }



        List<User> users = [
            SELECT Id, Name, UserRoleId, UserRole.Name
            FROM User
            WHERE IsActive = true
        ];
        Map<Id, User> mapIdUser = new Map<Id, User>();
        Map<String, List<User>> mapRoleIdListOfUsers = new Map<String, List<User>>();

        for(User u : users) {
            mapIdUser.put(u.Id, u);

            if(String.isNotBlank(u.UserRoleId)) {
                if(mapRoleIdListOfUsers.containsKey(u.UserRole.Name)) {
                    mapRoleIdListOfUsers.get(u.UserRole.Name).add(u);
                } else {
                    mapRoleIdListOfUsers.put(u.UserRole.Name, new List<User> {u});
                }
            }
        }



        List<UserRole> userRoles = [select Id, Name, ParentRoleId from UserRole];
        Map<Id, UserRole> mapUserRoles = new Map<Id, UserRole>();
        Map<Id, Id> mapUserRoleAndParentUserRole = new Map<Id, Id>();
        for(UserRole userRole : userRoles) {
            mapUserRoleAndParentUserRole.put(userRole.Id, userRole.ParentRoleId);
            mapUserRoles.put(userRole.Id, userRole);
        }


        for(QuoteLineItem qli : qlis) {
            List<Id> parentUserIds = new List<Id>();
            List<Id> approverIds = new List<Id>();

            Map<Id, Id> tempMap = new Map<Id, Id>();
            for(Integer i=0; i<users.size(); i++) {
                if(parentUserIds.size() == 0) {
                    parentUserIds.add(tempMap.get(qli.Owner_Id__c));
                }
                else if(tempMap.containsKey(parentUserIds[parentUserIds.size()-1])) {
                    parentUserIds.add(tempMap.get(parentUserIds[parentUserIds.size()-1]));
                }
            }

            String currentRole = qli.Owner_Role__c;
            if(String.isBlank(currentRole)) {
                if(!Test.isRunningTest()) {
                    qli.addError('Please verify admin have assigned you a role or not');
                }
                return;
            }


            Decimal previousUpperLimit;
            if(mapSOAMatrix.containsKey(currentRole)) {
                SOA_Matrix__c soa = mapSOAMatrix.get(currentRole);
                previousUpperLimit = soa.Max_Discount__c;

                if(qli.Discount_to_be_offered__c <= soa.Max_Discount__c) {
                    qli.Approval_Status__c = 'Approved';
                    continue;
                }
                if(qli.Discount_to_be_offered__c >= soa.Min_Discount__c && qli.Discount_to_be_offered__c <= soa.Max_Discount__c) {
                    qli.Approval_Status__c = 'Approved';
                    continue;
                }
            }

            while(true) {
                if(mapSOAMatrix.containsKey(currentRole)) {
                    SOA_Matrix__c soa = mapSOAMatrix.get(currentRole);
                    // if(qp.Actual_Discount_Percentage__c > previousUpperLimit) {
                    if(qli.Discount_to_be_offered__c > previousUpperLimit) {
                        if(mapRoleIdListOfUsers.containsKey(soa.SOA_Profile__c)) {
                            for(User u: mapRoleIdListOfUsers.get(soa.SOA_Profile__c)) {
                                System.debug(parentUserIds.contains(u.Id) + '    u -> ' + u);
                                if(parentUserIds.contains(u.Id)) {
                                    approverIds.add(u.Id);
                                    previousUpperLimit = soa.Max_Discount__c;
                                    break;
                                }
                            }
                        }
                        else {
                            break;
                        }
                    }
                }
                if(mapUserRoles.get(currentRole).ParentRoleId != null) {
                    currentRole = mapUserRoles.get(currentRole).ParentRoleId;
                }
                else {
                    break;
                }
            }

            Integer index = 1;
            for(String str : approverIds) {
                System.debug('Approver_' + index + ' -> ' + str + ' ' + mapIdUser.get(str).Name);
                index++;
            }

        }
    }
    */


    public static void defineNextApprover(List<QuoteLineItem> qlis, Map<Id, QuoteLineItem> oldMap) {
        for (QuoteLineItem qli : qlis) {
            QuoteLineItem oldQli = (oldMap != null) ? oldMap.get(qli.Id) : null;
            if (oldQli == null) {
                continue;
            }

            // String[] approverList = new String[] {'Sales_Rep__c', 'Sales_Manager__c', 'Country_Continent_Sales_Head_LOB_Head__c', 'Global_Sales_Head__c', 'Rotex_Board_Member__c', 'Managing_Director_Country_Manage__c'};
            // String[] approverStatusList = new String[] {'Sales_Rep_Status__c', 'Sales_Manager_Status__c', 'Country_Continent_Sales_H_LOB_Status__c', 'Global_Sales_Head_Status__c', 'Rotex_Board_Member_Status__c', 'Managing_Director_Status__c'};
            // String[] soaProfiles = new String[] {'Sales Rep', 'Sales Manager', 'Country / Continent Sales Head / LOB Head', 'Global Sales Head', 'Rotex Board Member', 'Managing Director / Country Manager'};

            // Sales Rep -> next approver
            // if (qli.Sales_Rep_Status__c == 'Approved' && qli.Sales_Rep_Status__c != oldQli.Sales_Rep_Status__c) {
            //     evaluateAndSetNextApprover(qli, 0);
            // }

            // Sales Manager -> next approver
            if (qli.Sales_Manager_Status__c == 'Approved' && qli.Sales_Manager_Status__c != oldQli.Sales_Manager_Status__c) {
                evaluateAndSetNextApprover(qli, 1);
            }

            // Country / Continent Sales Head / LOB Head -> next approver
            if (qli.Country_Continent_Sales_H_LOB_Status__c == 'Approved' && qli.Country_Continent_Sales_H_LOB_Status__c != oldQli.Country_Continent_Sales_H_LOB_Status__c) {
                evaluateAndSetNextApprover(qli, 2);
            }

            // Global Sales Head -> next approver
            if (qli.Global_Sales_Head_Status__c == 'Approved' && qli.Global_Sales_Head_Status__c != oldQli.Global_Sales_Head_Status__c) {
                evaluateAndSetNextApprover(qli, 3);
            }

            // Rotex Board Member -> next approver
            if (qli.Rotex_Board_Member_Status__c == 'Approved' && qli.Rotex_Board_Member_Status__c != oldQli.Rotex_Board_Member_Status__c) {
                evaluateAndSetNextApprover(qli, 4);
            }
        }
    }

    private static void evaluateAndSetNextApprover(QuoteLineItem qli, Integer fromProfileIdx) {
        // Approver chain in order
        // Index 0..5: Profiles
        final List<String> profiles = new List<String>{
            'Sales Rep',
            'Sales Manager',
            'Country / Continent Sales Head / LOB Head',
            'Global Sales Head',
            'Rotex Board Member',
            'Managing Director / Country Manager'
        };

        // Index 0..4: Lookup fields that correspond to profiles[1..5]
        final List<String> lookupFields = new List<String>{
            'Sales_Manager__c',
            'Country_Continent_Sales_Head_LOB_Head__c',
            'Global_Sales_Head__c',
            'Rotex_Board_Member__c',
            'Managing_Director_Country_Manage__c'
        };

        // Index 0..4: Status fields that correspond to profiles[1..5]
        final List<String> statusFields = new List<String>{
            'Sales_Manager_Status__c',
            'Country_Continent_Sales_H_LOB_Status__c',
            'Global_Sales_Head_Status__c',
            'Rotex_Board_Member_Status__c',
            'Managing_Director_Status__c'
        };

        if (qli == null || fromProfileIdx == null) {
            return;
        }

        Decimal offered = qli.Discount_to_be_offered__c;
        if (offered == null) {
            return;
        }

        if (fromProfileIdx < 0 || fromProfileIdx >= profiles.size()) {
            return;
        }
        SOA_Matrix__c prevSOA = getSOAMatrixEntry(profiles[fromProfileIdx]);
        if (prevSOA == null) {
            return;
        }

        for (Integer j = fromProfileIdx + 1; j < profiles.size(); j++) {
            Integer nextIdx = j - 1; // aligns to lookup/status arrays
            String lookupField = lookupFields[nextIdx];

            if (qli.get(lookupField) != null) {
                SOA_Matrix__c nextSOA = getSOAMatrixEntry(profiles[j]);
                if (nextSOA != null && offered >= prevSOA.Max_Discount__c) {
                    qli.put(statusFields[nextIdx], 'Submitted');
                }
                break;
            }
        }
    }

    private static void submitIfInRange(QuoteLineItem qli, SOA_Matrix__c prevSOA, String nextProfile) {
        // Guard against missing SOA entries or discount value
        SOA_Matrix__c nextSOA = getSOAMatrixEntry(nextProfile);
        Decimal offered = qli.Discount_to_be_offered__c;
        if (prevSOA == null || nextSOA == null || offered == null) {
            return;
        }
        if (offered >= prevSOA.Max_Discount__c && offered <= nextSOA.Max_Discount__c) {
            qli.Approval_Status__c = 'Submitted';
        }
    }

    private static Map<String, SOA_Matrix__c> soaMatrix;
    private static SOA_Matrix__c getSOAMatrixEntry(String soaProfile) {
        if (soaMatrix == null) {
            soaMatrix = new Map<String, SOA_Matrix__c>();
            for (SOA_Matrix__c soa : [
                SELECT Id, Name, SOA_Profile__c, Discount_on_Price_List__c, Min_Discount__c, Max_Discount__c
                FROM SOA_Matrix__c
            ]) {
                if (soa.SOA_Profile__c != null) {
                    soaMatrix.put(soa.SOA_Profile__c, soa);
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