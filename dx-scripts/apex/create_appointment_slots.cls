// create a set of appointment slots
Id centerId = [SELECT Id FROM Account WHERE Name = 'Center 1'].Id;
Date day = Date.today();
Time startTime = Time.newInstance(6, 0, 0, 0);
Time endTime = Time.newInstance(21, 0, 0, 0);
Integer incrementInMinutes = 10;
Integer slotsPerIncrement = 1;
Appointment__c[] appointments = ScheduleUtils.createDailySlots(centerId, day, startTime,endTime, 10, 1);

insert appointments;