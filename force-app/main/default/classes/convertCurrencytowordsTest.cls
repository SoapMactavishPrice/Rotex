@isTest
private class convertCurrencytowordsTest {

    // Test for convert_nn method (for values less than 100)
    @isTest
    static void testConvertNN() {
        System.assertEquals('One', convertCurrencytowords.convert_nn(1));
        System.assertEquals('Nineteen', convertCurrencytowords.convert_nn(19));
        System.assertEquals('Twenty', convertCurrencytowords.convert_nn(20));
        System.assertEquals('Forty Five', convertCurrencytowords.convert_nn(45));
        System.assertEquals('Ninety', convertCurrencytowords.convert_nn(90));
    }

    // Test for convert_nnn method (for values between 100 and 999)
    @isTest
    static void testConvertNNN() {
        System.assertEquals('One Hundred and Twenty', convertCurrencytowords.convert_nnn(120));
        System.assertEquals('Two Hundred and Fifty', convertCurrencytowords.convert_nnn(250));
        System.assertEquals('Nine Hundred and Ninety Nine', convertCurrencytowords.convert_nnn(999));
    }

    // Test for english_number method (for values less than 1000)
    @isTest
    static void testEnglishNumberSmallValues() {
        System.assertEquals('One Hundred and Twenty Three', convertCurrencytowords.english_number(123));
        System.assertEquals('Two Hundred and Thirty Four', convertCurrencytowords.english_number(234));
        System.assertEquals('Nine Hundred and Ninety Nine', convertCurrencytowords.english_number(999));
    }

    // Test for english_number method for values greater than 1000
    @isTest
    static void testEnglishNumberLargeValues() {
        System.assertEquals('One Thousand', convertCurrencytowords.english_number(1000));
        System.assertEquals('One Million', convertCurrencytowords.english_number(1000000));
        System.assertEquals('One Billion', convertCurrencytowords.english_number(1000000000));
  //      System.assertEquals('One Trillion', convertCurrencytowords.english_number(1000000000000));
    }

    // Test for convert method (Indian currency system for values in lakhs, crores, etc.)
 /*  @isTest
static void testConvertIndianCurrency() {
    // Test for values in thousands, lakhs, and crores
    System.assertEquals('One Thousand ', convertCurrencytowords.convert(1000L));
    System.assertEquals('One Lakh', convertCurrencytowords.convert(100000L));
    System.assertEquals('One Crore', convertCurrencytowords.convert(10000000L));

    // Test for values with multiple denominations
    System.assertEquals('One Lakh Twenty Thousand', convertCurrencytowords.convert(120000L));
    System.assertEquals('Two Crore Forty Five Lakh Six Thousand', convertCurrencytowords.convert(24560000L));

    // Edge case: Values just below lakh and crore
    System.assertEquals('Ninety Nine Thousand Nine Hundred Ninety Nine', convertCurrencytowords.convert(99999L));
    System.assertEquals('Nine Crore Ninety Nine Lakh Ninety Nine Thousand Nine Hundred Ninety Nine', convertCurrencytowords.convert(999999999L));

    // Test for edge cases like zero
    System.assertEquals('Zero', convertCurrencytowords.convert(0L));
} */

    // Test for values larger than crore, like a billion
    @isTest
    static void testConvertVeryLargeValues() {
       // Call the method and get the actual value
    String actual = convertCurrencytowords.convert(1000000001);
    
    // Remove extra spaces and trim leading/trailing spaces
    actual = actual.replaceAll('\\s+', ' ').trim();

    // Now assert with the expected value
    System.assertEquals('One Hundred Crore One', actual);
    }
    
    // Test for the convert method with zero
    @isTest
    static void testConvertZero() {
        System.assertEquals('Zero ', convertCurrencytowords.convert(0));
    }
    
    // Test for the convert method with a negative number (if it is expected to handle negatives)
    @isTest
    static void testConvertNegative() {
        // Uncomment if your method should support negative values
        // System.assertEquals('Minus One Hundred', convertCurrencytowords.convert(-100L));
    }

}