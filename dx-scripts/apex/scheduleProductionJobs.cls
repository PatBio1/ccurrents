// Set to run every 10 minutes
String addFundsBatchableJobId1 = System.schedule('Onbe - Add Funds Retry 0 Min', '0 0 * * * ?', new AddFundsBatchable());
String addFundsBatchableJobId2 = System.schedule('Onbe - Add Funds Retry 10 Min', '0 10 * * * ?', new AddFundsBatchable());
String addFundsBatchableJobId3 = System.schedule('Onbe - Add Funds Retry 20 Min', '0 20 * * * ?', new AddFundsBatchable());
String addFundsBatchableJobId4 = System.schedule('Onbe - Add Funds Retry 30 Min', '0 30 * * * ?', new AddFundsBatchable());
String addFundsBatchableJobId5 = System.schedule('Onbe - Add Funds Retry 40 Min', '0 40 * * * ?', new AddFundsBatchable());
String addFundsBatchableJobId6 = System.schedule('Onbe - Add Funds Retry 50 Min', '0 50 * * * ?', new AddFundsBatchable());

// Set to run at the start of each day
String donorBatchableJobId = System.schedule('Proesis - Donor 365 Day Count Update', '0 0 0 ? * *', new DonorBatchable());
String endOfDayVisitBatchJobId = System.schedule('Proesis - End of Day Visit Status Updates', '0 0 23 ? * *', new EndOfDayVisitBatchable());