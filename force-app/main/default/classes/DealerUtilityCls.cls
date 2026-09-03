public without sharing class DealerUtilityCls {

    public class APIparamter {
        public String endpoint;
        public String method;
        public String accessToken;
    }

    // Method for making an HTTP GET request with Basic Authentication
    public static HttpResponse doGetWithBasicAuth(
        String apiName,
        String apiType,
        Date startDate,
        Date enddate,
        String filterData
    ) {
        APIparamter apiparam = getAPIdetails(apiName);

        HttpRequest request = new HttpRequest();

        if (apiType == 'DAILY') {
            DateTime dt = DateTime.newInstance(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0);
            String formattedDate = dt.format('yyyy-MM-dd');

            DateTime endDt = DateTime.newInstance(enddate.year(), enddate.month(), enddate.day(), 0, 0, 0);
            String formattedDate2 = endDt.format('yyyy-MM-dd');

            String strUrl = '';

            if (apiName == 'Pricing_Master_API' || apiName == 'Discount_Master_API' || apiName == 'ARCPricing_Master_API') {
                if (apiName == 'Pricing_Master_API') {
                    strUrl = '&$filter=Material%20eq%20%27' + filterData + '%27%20';
                } else if (apiName == 'ARCPricing_Master_API') {
                    strUrl = '&$filter=Customer%20eq%20%27' + filterData + '%27%20';
                }
            } else {
                if ((apiName == 'Customer_Master_API' || apiName == 'Customer_Master_API_2')
                    && String.isNotBlank(filterData)) {
                    strUrl = '&$filter=customer_number%20eq%20%27' + filterData + '%27%20';
                } else if (apiName == 'Material_Master_API' && String.isNotBlank(filterData)) {
                    strUrl = '&$filter=item_no%20eq%20%27' + filterData + '%27%20';
                } else {
                    if (apiName != 'Inco_Terms') {
                        strUrl =
                            '&$filter=created_on_date eq \'' +
                            formattedDate +
                            '\' or changed_on_date eq \'' +
                            formattedDate2 +
                            '\' ';
                    }
                }
            }

            if (apiName == 'Sales_Order_API') {
                strUrl =
                    '&$filter=created_on_date eq \'' +
                    formattedDate +
                    '\' or changed_on_date eq \'' +
                    formattedDate2 +
                    '\' ';
            }

            if (apiName == 'Clearing_Payment_API') {
                strUrl =
                    '&$filter= clearing_date eq \'' +
                    formattedDate +
                    '\' or changed_on eq \'' +
                    formattedDate2 +
                    '\' ';
            }

            if (apiName == 'Customer_GL_API') {
                strUrl = '&$filter= posting_date eq \'' + formattedDate + '\' ';
            }

            strUrl = strUrl.replaceAll(' ', '%20');
            request.setEndpoint(apiparam.endpoint + strUrl);
        } else {
            request.setEndpoint(apiparam.endpoint);
        }

        request.setMethod(apiparam.method);

        String username = 'IBS_SD';
        String password = 'Rotex@1234';
        String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));
        request.setHeader('Authorization', authHeader);
        request.setHeader('Content-Type', 'application/json');

        if (apiName == 'Get_Session_API') {
            request.setHeader('x-csrf-token', 'Fetch');
            request.setHeader('cookie', '');
        }

        request.setTimeout(120000);
        Http http = new Http();
        return http.send(request);
    }

    public static HttpResponse doPostWithBasicAuth(String apiName, String requestBody) {
        APIparamter apiparam = getAPIdetails(apiName);

        HttpRequest request = new HttpRequest();
        request.setEndpoint(apiparam.endpoint);
        request.setMethod(apiparam.method);

        String username = 'IBS_SD';
        String password = 'Rotex@1234';
        String authHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(username + ':' + password));

        request.setHeader('Authorization', authHeader);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setHeader('X-CSRF-Token', 'Fetch');
        request.setBody(requestBody);
        request.setTimeout(120000);

        Http http = new Http();
        return http.send(request);
    }

    @TestVisible
    private static WebService_Setting__mdt getWebServiceSetting(String apiName) {
        if (Test.isRunningTest()) {
            return new WebService_Setting__mdt(
                Endpoint__c = 'https://testapi.com/' + apiName.toLowerCase().replace('_', ''),
                Method__c = apiName.endsWith('_POST') ? 'POST' : 'GET'
            );
        }

        try {
            return [
                SELECT Id, Endpoint__c, Method__c
                FROM WebService_Setting__mdt
                WHERE DeveloperName = :apiName
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

    public static void logApiCall(
        String apiName,
        String apiUrl,
        String request,
        String response,
        String status,
        Integer statusCode
    ) {
        logApiCall(apiName, apiUrl, request, response, status, statusCode, null);
    }

    public static void logApiCall(
        String apiName,
        String apiUrl,
        String request,
        String response,
        String status,
        Integer statusCode,
        Id quoteId
    ) {
        try {
            API_Log__c apiLog = new API_Log__c();
            apiLog.Api_Name__c = apiName;
            apiLog.Api_URL__c = apiUrl;
            apiLog.Request__c = request;
            apiLog.Response__c = response;
            apiLog.Status__c = status;
            apiLog.Status_Code__c = String.valueOf(statusCode);
            apiLog.Quote__c = quoteId;
            insert apiLog;
        } catch (Exception e) {
            System.debug('Error logging API call: ' + e.getMessage());
        }
    }
}