// create a set of appointment slots
Date startDate = Date.today().addDays(-2);
Date endDate = Date.today().addDays(30);
Id loyaltyTier = null;
Integer intervalsPerHour = 4; //10 minutes apart
Integer slotsPerInterval = 4;

Account center1 = [SELECT Id FROM Account WHERE Name = 'Proesis Miramar'];

//scheduleRange(Id centerId, Date startDate, Date endDate, Id loyaltyTier, Integer intervalsPerHour, Integer slotsPerInterval)
Appointment__c[] appointments = ScheduleUtils.scheduleRange(center1.id,startDate,endDate,loyaltyTier,intervalsPerHour,slotsPerInterval);

insert appointments;