for(CronTrigger productionJob : [
    SELECT Id
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'Onbe - Add Funds Retry%' OR 
        CronJobDetail.Name IN ('Proesis - Donor 365 Day Count Update', 'Proesis - End of Day Visit Status Updates')
]) {
    System.abortJob(productionJob.Id);
}