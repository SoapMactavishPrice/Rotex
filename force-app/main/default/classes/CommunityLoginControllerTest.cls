@isTest
public class CommunityLoginControllerTest {

    @isTest
    static void testBlankCredentials() {
        // Test when both username and password are blank
        Test.startTest();
        Map<String, String> result = CommunityLoginController.doLogin('', '');
        Test.stopTest();
        
        System.assertEquals('ERROR', result.get('status'), 'Status should be ERROR');
        System.assertEquals('Username and password are required.', result.get('message'), 'Message should indicate required fields');
    }
    
    @isTest
    static void testNullCredentials() {
        // Test when credentials are null
        Test.startTest();
        Map<String, String> result = CommunityLoginController.doLogin(null, null);
        Test.stopTest();
        
        System.assertEquals('ERROR', result.get('status'), 'Status should be ERROR');
    }

    @isTest
    static void testBlankUsernameOnly() {
        Test.startTest();
        Map<String, String> result = CommunityLoginController.doLogin('', 'password123');
        Test.stopTest();

        System.assertEquals('ERROR', result.get('status'));
        System.assertEquals('Username and password are required.', result.get('message'));
    }

    @isTest
    static void testBlankPasswordOnly() {
        Test.startTest();
        Map<String, String> result = CommunityLoginController.doLogin('user@example.com', '');
        Test.stopTest();

        System.assertEquals('ERROR', result.get('status'));
        System.assertEquals('Username and password are required.', result.get('message'));
    }

    @isTest
    static void testWhitespaceCredentials() {
        Test.startTest();
        Map<String, String> result = CommunityLoginController.doLogin('   ', '   ');
        Test.stopTest();

        System.assertEquals('ERROR', result.get('status'));
    }

    @isTest
    static void testSuccessfulLogin() {
        CommunityLoginController.simulateSuccessfulLogin = true;
        try {
            Test.startTest();
            Map<String, String> result = CommunityLoginController.doLogin(
                'user@example.com',
                'password123'
            );
            Test.stopTest();

            System.assertEquals('SUCCESS', result.get('status'));
            System.assertNotEquals(null, result.get('redirectUrl'));
            System.assertNotEquals(null, result.get('debug_startUrl'));
        } finally {
            CommunityLoginController.simulateSuccessfulLogin = false;
        }
    }

    @isTest
    static void testLoginAttempt() {
        // Test a login attempt with dummy credentials
        // Note: Site.login() returns null in test context, so this will either hit the 'else' block 
        // (Invalid username/password) OR the catch block if the Network 'Rotex Automation Dealer portal' doesn't exist.
        
        Test.startTest();
        Map<String, String> result = CommunityLoginController.doLogin('testuser@example.com', 'dummyPassword123');
        Test.stopTest();
        
        // Assert that we get an ERROR status back, either from the query failing or Site.login returning null.
        System.assertEquals('ERROR', result.get('status'), 'Status should be ERROR in test context');
        
        // Optional: Debug the message to see if it failed at Network query or Site.login
        System.debug('Login Attempt Result Message: ' + result.get('message'));
        System.assertNotEquals(null, result.get('message'), 'Message should not be null');
    }
}