public with sharing class ScheduleUtils {


    public static Appointment__c[] scheduleRange(Id centerId, Date startDate, Date endDate, Id loyaltyTier, Integer intervalsPerHour, Integer slotsPerInterval){
        Integer incrementInMinutes = 60/intervalsPerHour;
        Appointment__c[] appointmentRecords = new Appointment__c[]{};
    
        //figure out clinic hours from CustomMetadata, for now assume 6AM to 9PM
        Time startTime = Time.newInstance(6, 0, 0, 0); //6AM
        Time endTime = Time.newInstance(21, 0, 0, 0); //9PM
        //figure out business days in range (M-F for now)
        Set<String> daysClosed  = new Set<String>{'Saturday','Sunday'};
        Integer daysInRange = startDate.daysBetween(endDate);

        for(Integer i=0; i<daysInRange; i++){
            Date appDate = startDate.addDays(i);
            Datetime dt = DateTime.newInstance(appDate, Time.newInstance(0, 0, 0, 0));
            String dayOfWeek=dt.format('EEEE');
            //make sure day is a weekday/workday
            if(! daysClosed.contains(dayOfWeek)){
                System.debug('Day : ' + dayOfWeek);
                System.debug('incrementInMinutes : ' + incrementInMinutes + '  slotsPerInterval: ' + slotsPerInterval);
                appointmentRecords.addAll(
                    createDailySlots(centerId, appDate, startTime, endTime, incrementInMinutes, slotsPerInterval)
                );
            }
        }

        //for each day Create Daily Slots
        return appointmentRecords;
    }
  

    public static Appointment__c[] createDailySlots(Id centerId, Date day, Time startTime, Time endTime, Integer incrementInMinutes, Integer slotsPerIncrement){
        DateTime startDT = DateTime.newInstance(day, startTime);
        DateTime endDT = DateTime.newInstance(day, endTime);

        Schedule__c schedule = [
            SELECT id 
            FROM Schedule__c
            WHERE Center__c =: centerId
            AND Begin_Date__c <=: day
            AND End_Date__c >=: day
        ];
        // system.debug('schedule' + schedule);
        
        Long startMS = startDT.getTime();
        Long endMS = endDT.getTime();

        Long milliseconds = endMS - startMS;
        Long seconds = milliseconds / 1000;
        Long minutes = seconds / 60;
        Long hours = minutes / 60;

        Long incrementsPerDay = (minutes / incrementInMinutes) ;
        
        Appointment__c[] appointments = new Appointment__c[]{
            new Appointment__c(
                Datetime__c = startDT,
                Schedule__c = schedule.Id,
                Duration__c = incrementInMinutes
            )
        };
        for(Integer i=1; i< incrementsPerDay; i++){
            DateTime incrementDT = appointments[i-1].Datetime__c.addMinutes(incrementInMinutes);
    
            for(Integer j=0;j< slotsPerIncrement; j++){
                // system.debug('add slots');
                appointments.add(new Appointment__c(
                    Datetime__c = incrementDT,
                    Schedule__c = schedule.Id,
                    Duration__c = incrementInMinutes
                ));
            }
        }

        system.debug('Total hours: '+ hours);
        system.debug('Total Minutes: '+ minutes);
        system.debug('Increments per Day: '+ incrementsPerDay);
       
        Long totalSlotsCreated =  incrementsPerDay * slotsPerIncrement;
        system.debug('Slots per Day: '+ totalSlotsCreated);
        system.assertEquals(totalSlotsCreated, appointments.size());
        for (Appointment__c app: appointments){
            system.debug(app.Schedule__c);
        }
        
        return appointments;
    }
    
}
