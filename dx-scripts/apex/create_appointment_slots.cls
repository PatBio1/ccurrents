Date day = Date.today();
Time startTime = Time.newInstance(6, 0, 0, 0);
Time endTime = Time.newInstance(21, 0, 0, 0);
Integer incrementInMinutes = 10;
Integer slotsPerIncrement = 1;
ScheduleUtils.createDailySlots(day, startTime,endTime, 5, 1);
