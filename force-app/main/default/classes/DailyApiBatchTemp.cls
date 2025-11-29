global class DailyApiBatchTemp implements Database.Batchable<Date>, Database.AllowsCallouts {

    // STEP 1: Create list of dates to iterate over
    global Iterable<Date> start(Database.BatchableContext bc) {
        List<Date> dateList = new List<Date>();
        Date startDate = Date.newInstance(2024, 1, 1);
        Date endDate = Date.newInstance(2024, 12, 31);
        // Date endDate = Date.today();

        if(test.isRunningTest()){
            startDate =  date.today();
            endDate =  date.today();
        }
        while (startDate <= endDate) {
            dateList.add(startDate);
            startDate = startDate.addDays(1);
        }

        return dateList;
    }

    // STEP 2: For each batch of dates, call the API
    global void execute(Database.BatchableContext bc, List<Date> scope) {
        for (Date dateParam : scope) {
            try {
                // IntegrationHandler.getMaterialMaster();
                // IntegrationHandler.getCustomerMaster(dateParam);
            } catch (Exception e) {
                System.debug('Error for date ' + dateParam + ': ' + e.getMessage());
                // Optionally log to a custom object or use Platform Events
            }
        }
    }

    // STEP 3: Optional finish logic
    global void finish(Database.BatchableContext bc) {
        // Send email or log batch completion
        System.debug('DailyApiBatchTemp completed.');
    }
}