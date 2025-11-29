@isTest
public class DailyApiBatchTempTest {
    @isTest
    public static void isValidate(){
        DailyApiBatchTemp api = new DailyApiBatchTemp();
        database.executeBatch(api,1);
    }

}