public with sharing class ScheduleUtils {
  

    public static Appointment__c[] createDailySlots(Date day, Time startTime, Time endTime, Integer incrementInMinutes, Integer slotsPerIncrement){
        DateTime startDT = DateTime.newInstance(day, startTime);
        DateTime endDT = DateTime.newInstance(day, endTime);

        //Convert from GMT to Localtime
        Integer offset = UserInfo.getTimezone().getOffset(startDT);
        startDT = startDT.addSeconds(offset/1000);
        endDT = endDT.addSeconds(offset/1000);
        
        Long startMS = startDT.getTime();
        Long endMS = endDT.getTime();

        Long milliseconds = endMS - startMS;
        Long seconds = milliseconds / 1000;
        Long minutes = seconds / 60;
        Long hours = minutes / 60;

        Long incrementsPerDay = (minutes / incrementInMinutes) ;
        
        Appointment__c[] appointments = new Appointment__c[]{
            new Appointment__c(
                Datetime__c = startDT
            )
        };
        for(Integer i=1; i< incrementsPerDay; i++){
            DateTime incrementDT = appointments[i-1].Datetime__c.addMinutes(incrementInMinutes);
    
            for(Integer j=0;j< slotsPerIncrement; j++){
                system.debug('add slots');
                appointments.add(new Appointment__c(
                    Datetime__c = incrementDT
                ));
            }
        }

        for(Appointment__c app: appointments){
            system.debug(app);
        }
        

        system.debug('Total hours: '+ hours);
        system.debug('Total Minutes: '+ minutes);
        system.debug('Increments per Day: '+ incrementsPerDay);
       
        Long totalSlotsCreated =  incrementsPerDay * slotsPerIncrement;
        system.debug('Slots per Day: '+ totalSlotsCreated);
        system.assertEquals(totalSlotsCreated, appointments.size());

        return appointments;
    }
    
}
