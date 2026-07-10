public without sharing class CommunityLoginController {

    @TestVisible
    private static Boolean simulateSuccessfulLogin = false;

    @AuraEnabled(cacheable=false)
    public static Map<String, String> doLogin(String username, String password) {
        
        Map<String, String> result = new Map<String, String>();
        
        try {
            if (String.isBlank(username) || String.isBlank(password)) {
                result.put('status', 'ERROR');
                result.put('message', 'Username and password are required.');
                return result;
            }

            Network n = [
                SELECT UrlPathPrefix 
                FROM Network 
                WHERE Name = 'Rotex Automation Dealer portal' 
                LIMIT 1
            ];

            String startUrl = '/' + n.UrlPathPrefix + '/';
            PageReference pageRef;
            if (Test.isRunningTest() && simulateSuccessfulLogin) {
                pageRef = new PageReference(startUrl);
            } else {
                pageRef = Site.login(username, password, startUrl);
            }

            if (pageRef != null) {
                // ✅ Build full absolute URL
                String baseUrl = Site.getBaseRequestUrl();
                String redirectUrl = pageRef.getUrl();
                
                // Debug what we got
                result.put('debug_baseUrl', baseUrl);
                result.put('debug_redirectUrl', redirectUrl);
                result.put('debug_startUrl', startUrl);
                
                // Build full URL if relative
                if (redirectUrl.startsWith('/')) {
                    redirectUrl = baseUrl + redirectUrl;
                }
                
                result.put('status', 'SUCCESS');
                result.put('redirectUrl', redirectUrl);
            } else {
                result.put('status', 'ERROR');
                result.put('message', 'Invalid username or password.');
            }

        } catch (Exception e) {
            result.put('status', 'ERROR');
            result.put('message', e.getMessage());
        }

        return result;
    }
}