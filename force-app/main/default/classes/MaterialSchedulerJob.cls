global class MaterialSchedulerJob implements Schedulable {
    global void execute(SchedulableContext sc) {
        System.enqueueJob(new AllScheduler('getMaterialMaster'));
    }
}