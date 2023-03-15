public with sharing class ScheduleUtils {

    public static Schedule__c createScheduleRecord(Id centerId, Date startDate, Date endDate){

        Schedule__c[] existingSchedules = new Schedule__c[]{};
        //check for any existing schedules overlapping range
        //WHERE schedule is for this center
        //AND Start date is in between new range
        //OR End date is in between new range
        //OR is encompassed by entire range
        Boolean scheduleExists  = false;
        for(Schedule__c sched: [
            SELECT  Id
            FROM    Schedule__c
            WHERE Center__c =: centerId
            AND (
                    (Begin_Date__c <=: startDate AND End_Date__c >=: startDate)
                    OR 
                    ( Begin_Date__c <=: endDate AND End_Date__c  >=: endDate) 
                    OR
                    ( Begin_Date__c >=: startDate AND End_Date__c <=: endDate) 
            )
            LIMIT 1
        ]){
            scheduleExists = true;
        }

        if (scheduleExists == true){
            throw new ScheduleException('A Schedule exists for this center in this date range');
        }

        Schedule__c schedule = new Schedule__c(
            Center__c = centerId,
            Begin_Date__c = startDate,
            End_Date__c = endDate
        );
        return schedule;
    }


    public static Appointment__c[] scheduleRange(Id centerId, Id scheduleId, Date startDate, Date endDate, Id loyaltyTier, Integer intervalsPerHour, Integer slotsPerInterval){
        Integer incrementInMinutes = 60/intervalsPerHour;
        Appointment__c[] appointmentRecords = new Appointment__c[]{};
        Set<String> daysClosed  = new Set<String>{};
        Map<String,Business_Hours__c> dayToHours = new Map<String,Business_Hours__c>{};
        for (Business_Hours__c day : [
            SELECT  Id,
                    Name,
                    Center__c,
                    Close__c,
                    Index__c,
                    IsClosed__c,
                    Open__c
            FROM Business_Hours__c
            WHERE Center__c =: centerId
        ]){
            dayToHours.put(day.Name,day);
            if(day.IsClosed__c == true){
                daysClosed.add(day.Name);
            }
        } 
    
        //figure out clinic hours from CustomMetadata, for now assume 6AM to 9PM
        // Time startTime = Time.newInstance(6, 0, 0, 0); //6AM
        // Time endTime = Time.newInstance(21, 0, 0, 0); //9PM
        //figure out business days in range (M-F for now)
        
        Integer daysInRange = startDate.daysBetween(endDate) + 1; //add 1 to account for first day
        
        System.debug('daysInRange : ' + daysInRange);

        for(Integer i=0; i<daysInRange; i++){
            Date appDate = startDate.addDays(i);
            Datetime dt = DateTime.newInstance(appDate, Time.newInstance(0, 0, 0, 0));
            String dayOfWeek=dt.format('EEEE');
            //make sure day is a weekday/workday
            if((! daysClosed.contains(dayOfWeek)) && (dayToHours.containsKey(dayOfWeek) ) ){
                // System.debug('Day : ' + dayOfWeek);
                // System.debug('incrementInMinutes : ' + incrementInMinutes + '  slotsPerInterval: ' + slotsPerInterval);
                Time startTime = dayToHours.get(dayOfWeek).Open__c;
                Time endTime = dayToHours.get(dayOfWeek).Close__c;
                appointmentRecords.addAll(
                    createDailySlots(centerId, scheduleId, appDate, startTime, endTime, incrementInMinutes, slotsPerInterval)
                );
            }
        }

        //for each day Create Daily Slots
        return appointmentRecords;
    }
  

    public static Appointment__c[] createDailySlots(Id centerId, Id scheduleId, Date day, Time startTime, Time endTime, Integer incrementInMinutes, Integer slotsPerIncrement){
        DateTime startDT = DateTime.newInstance(day, startTime);
        DateTime endDT = DateTime.newInstance(day, endTime);
        
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
                Schedule__c = scheduleId,
                Duration__c = incrementInMinutes,
                Capacity__c = slotsPerIncrement
            )
        };
        for(Integer i=1; i< incrementsPerDay; i++){
            DateTime incrementDT = appointments[i-1].Datetime__c.addMinutes(incrementInMinutes);
            appointments.add(new Appointment__c(
                    Datetime__c = incrementDT,
                    Schedule__c = scheduleId,
                    Duration__c = incrementInMinutes,
                    Capacity__c = slotsPerIncrement
                ));
            
        }

        system.debug('Total hours per day: '+ hours);
        system.debug('Total Minutes per day: '+ minutes);
        system.debug('appointment__c per Day : '+ incrementsPerDay);
        
        Long totalSlotsCreated =  incrementsPerDay * slotsPerIncrement;
        system.debug('Slots per Day: '+ totalSlotsCreated);
        system.assertEquals(incrementsPerDay, appointments.size());
        
        return appointments;
    }

    public static String createFirstVisitCode() {
        //removed letter 'O' and number '0' for better UX
        String chars = 'ABCDEFGHIJKLMNPQRSTUVWXYZ123456789';
    
        String code = '';
        for (Integer i = 0; i < 3; i++) {
            Integer index = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            code += chars.substring(index, index+1);
        }
    
        code += '-';
        
        for (Integer i = 0; i < 3; i++) {
            Integer index = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            code += chars.substring(index, index+1);
        }
    
        return code;
    }
    
    
    public class ScheduleException extends Exception{}
}
