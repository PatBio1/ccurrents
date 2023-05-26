// Set to run at the start of each day
String donorBatchableJobId = System.schedule('Proesis - Donor 365 Day Count Update', '0 0 0 ? * *', new DonorBatchable());
String endOfDayVisitBatchJobId = System.schedule('Proesis - End of Day Visit Status Updates', '0 0 23 ? * *', new EndOfDayVisitBatchable());