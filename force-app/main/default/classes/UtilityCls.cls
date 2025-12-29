public class UtilityCls {

    public static Map < String, String > getAllFields(String sObjectName) {

        if (!Schema.getGlobalDescribe().containsKey(sObjectName)) {
            Map < String, String > tempMap = new Map < String, String > ();
            tempMap.put('Exception', 'Invalid object name');
            return tempMap;
        }

        Map < String, Schema.SObjectField > fields = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap();

        String allfields = '';
        for (Schema.SObjectField field: fields.values())
            if (field.getDescribe().isAccessible())
                allfields += field.getDescribe().getName() + ', ';

        allfields = allfields.subString(0, allfields.length() - 2);

        Map < String, String > tempMap = new Map < String, String > {
            sobjectname => allfields
        };
        return tempMap;
    }

    // Method for making an HTTP GET request with Basic Authentication
    public static HttpResponse doGetWithBasicAuth(String apiName, String apiType, date startDate, date enddate, String filterData) {
        APIparamter apiparam = UtilityCls.getAPIdetails(apiName);

        HttpRequest request = new HttpRequest();

        if (apiType == 'DAILY') {

            DateTime dt = DateTime.newInstance(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0);
            String formattedDate = dt.format('yyyy-MM-dd');

            DateTime endDt = DateTime.newInstance(enddate.year(), enddate.month(), enddate.day(), 0, 0, 0);
            String formattedDate2 = endDt.format('yyyy-MM-dd');

            String strUrl = '';

            if (apiName == 'Pricing_Master_API' || apiName == 'Discount_Master_API' || apiName == 'ARCPricing_Master_API') {

                if (apiName == 'Pricing_Master_API') {
                    // strUrl = '&$filter=Material%20eq%20%27' + filterData + '%27%20';
                    strUrl = '&$filter=Valid_from%20eq%20%27' + formattedDate + '%27%20';
                } else if (apiName == 'ARCPricing_Master_API') {
                    strUrl = '&$filter=Customer%20eq%20%27' + filterData + '%27%20';
                }

            } else {
                // strUrl = '&$filter=created_on_date eq \'' + formattedDate + '\' or changed_on_date eq \'' + formattedDate2 + '\' ';
                // strUrl = '&$filter= changed_on_date eq \'' + formattedDate2 + '\' &$filter=customer_number%20eq%20%271000934%27%20';
                if (apiName == 'Customer_Master_API_2') {
                    strUrl = '&$filter=customer_number%20eq%20%27' + filterData + '%27%20';
                } else {
                    if (apiName != 'Inco_Terms') {
                        strUrl = '&$filter=created_on_date eq \'' + formattedDate + '\' or changed_on_date eq \'' + formattedDate2 + '\' ';
                        // strUrl = '&$filter=item_no%20eq%20%2727000002809%27%20';
                    }
                }
            }
            
            //String strUrl ='&$filter= changed_on_date eq \''+formattedDate2+'\' ';
            if (apiName == 'Sales_Order_API') {
                // strUrl = '&$filter= changed_on_date eq \'' + formattedDate2 + '\' ';
                strUrl = '&$filter=created_on_date eq \'' + formattedDate + '\' or changed_on_date eq \'' + formattedDate2 + '\' ';
                // strUrl = '&$filter=created_on_date eq \'' + formattedDate2 + '\' ';
            }

            if (apiName == 'Clearing_Payment_API') {
                strUrl = '&$filter= clearing_date eq \'' + formattedDate + '\' or changed_on eq \'' + formattedDate2 + '\' ';
            }

            if (apiName == 'Customer_GL_API') {
                // strUrl ='&$filter= clearing_date eq \''+formattedDate+'\' or changed_on eq \''+formattedDate2+'\' ';
                // strUrl = '&$filter= clearing_date eq \'' + formattedDate + '\' ';
                strUrl = '&$filter= posting_date eq \'' + formattedDate + '\' ';
            }

            strUrl = strUrl.replaceAll(' ', '%20');

            // system.debug('apiName  --  > '+ apiName + '   <<   url   ==>'+apiparam.endpoint+strUrl);
            System.debug('apiName:>> ' + apiName);
            System.debug(apiparam.endpoint);
            System.debug(strUrl);
            System.debug(apiparam.endpoint + strUrl);

            request.setEndpoint(apiparam.endpoint + strUrl);
            // system.debug('inside if'+apiparam.endpoint+strUrl);
        } else {
            system.debug('inside else' + apiparam.endpoint);
            request.setEndpoint(apiparam.endpoint);
        }

        request.setMethod(apiparam.method);
        // Set basic authentication header
        String username = 'IBS_SD';
        String password = 'Rotex@1234';
        String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
        request.setHeader('Authorization', authHeader);
        request.setHeader('Content-Type', 'application/json'); // Adjust content type as needed
        if (apiName == 'Get_Session_API') {
            request.setHeader('x-csrf-token', 'Fetch'); // To fetch the X-CSRF-Token
            request.setHeader('cookie', ''); // To include cookies in the request

        }
        request.setTimeOut(120000);
        Http http = new Http();
        HttpResponse response = http.send(request);
        system.debug('response' + response);
        return response;
    }

    // Method for making an HTTP GET request with Basic Authentication
    public static HttpResponse doGetWithoutAuth(String apiName, date startDate, date enddate) {
        APIparamter apiparam = UtilityCls.getAPIdetails(apiName);

        HttpRequest request = new HttpRequest();

        if (apiName == 'Sales_Order_Data' || apiName == 'Delivery_Data' || apiName == 'Invoice_Data') {

            DateTime dt = DateTime.newInstance(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0);
            String formattedDate = dt.format('yyyy-MM-dd');

            DateTime endDt = DateTime.newInstance(enddate.year(), enddate.month(), enddate.day(), 0, 0, 0);
            String formattedDate2 = endDt.format('yyyy-MM-dd');
            string strUrl = '?FDT=' + formattedDate + '&TDT=' + formattedDate2;
            system.debug('apiName  --  > ' + apiName + '   <<   url   ==>' + apiparam.endpoint + strUrl);
            request.setEndpoint(apiparam.endpoint + strUrl);
            system.debug('inside if' + apiparam.endpoint + strUrl);
        } else {
            system.debug('inside else' + apiparam.endpoint);
            request.setEndpoint(apiparam.endpoint);
        }

        request.setMethod(apiparam.method);
        request.setHeader('Content-Type', 'application/json'); // Adjust content type as needed
        request.setTimeOut(120000);
        Http http = new Http();
        HttpResponse response = http.send(request);
        //system.debug('response'+response);
        return response;
    }

    // Method for making an HTTP GET request with Basic Authentication
    public static HttpResponse doGetWithoutAuth_v1(String apiName, String param1) {
        System.debug('param1  ' + param1);
        if (param1 != '') {
            param1 = param1.replaceAll(' ', '%20');
        }
        System.debug('param1  ' + param1);
        APIparamter apiparam = UtilityCls.getAPIdetails(apiName);

        HttpRequest request = new HttpRequest();
        request.setEndpoint(apiparam.endpoint + param1);
        request.setMethod(apiparam.method);
        request.setHeader('Content-Type', 'application/json'); // Adjust content type as needed
        request.setTimeOut(120000);
        Http http = new Http();
        HttpResponse response = http.send(request);

        return response;
    }

    // Method for making an HTTP POST request with Basic Authentication
    public static HttpResponse doPostWithoutAuth(String apiName, string body) {
        APIparamter apiparam = UtilityCls.getAPIdetails(apiName);
        HttpRequest request = new HttpRequest();
        request.setEndpoint(apiparam.endpoint);
        request.setBody(body);
        request.setMethod(apiparam.method);
        request.setHeader('Content-Type', 'application/json');
        request.setTimeOut(120000);
        Http http = new Http();
        HttpResponse response = http.send(request);
        return response;
    }

    // Make the method testable by allowing it to work with test data
    @TestVisible
    private static WebService_Setting__mdt getWebServiceSetting(String apiName) {
        // In test context, return mock data immediately without querying
        if (Test.isRunningTest()) {
            return new WebService_Setting__mdt(
                Endpoint__c = 'https://testapi.com/' + apiName.toLowerCase().replace('_', ''),
                Method__c = apiName.endsWith('_POST') ? 'POST' : 'GET'
            );
        }

        // In non-test context, query the actual metadata
        try {
            return [SELECT Id, Endpoint__c, Method__c
                FROM WebService_Setting__mdt
                WHERE DeveloperName =: apiName
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Web Service Setting not found for: ' + apiName);
        }
    }

    public static APIparamter getAPIdetails(String apiName) {
        WebService_Setting__mdt wbs = getWebServiceSetting(apiName);
        APIparamter apiparam = new APIparamter();
        apiparam.endpoint = wbs.Endpoint__c;
        apiparam.method = wbs.Method__c;
        return apiparam;
    }

    // Method to log API call details
    public static void logApiCall(String apiName, String apiUrl, String request, String response, String status, Integer statusCode) {
        try {
            API_Log__c apiLog = new API_Log__c();
            apiLog.Api_Name__c = apiName;
            apiLog.Api_URL__c = apiUrl;
            apiLog.Request__c = request;
            apiLog.Response__c = response;
            apiLog.Status__c = status;
            apiLog.Status_Code__c = string.valueOf(statusCode);

            // Insert the log into the custom object
            insert apiLog;
        } catch (Exception e) {
            System.debug('Error logging API call: ' + e.getMessage());
        }
    }

    public static Date getDateFormate(String dstr) {

        if (dstr.length() == 8) {
            String yearStr = dstr.substring(0, 4);
            String monthStr = dstr.substring(4, 6);
            String dateStr = dstr.substring(6, 8);
            return date.parse(monthStr + '/' + dateStr + '/' + yearStr);
        }
        return null;
    }

    public class APIparamter {
        public string endpoint;
        public string method;
        public string accessToken;
    }
}