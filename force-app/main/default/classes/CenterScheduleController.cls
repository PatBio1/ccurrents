public with sharing class CenterScheduleController {
    
    @AuraEnabled
    public static Center[] getCenters(){
        Center[] centers = new Center[]{};
        try {

            for( Account a: [
                Select Id, Name 
                FROM Account 
                WHERE RecordType.DeveloperName = 'Center'
                WITH SECURITY_ENFORCED
            ]){
                centers.add(new Center(a));
            }
            return centers;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static AppointmentSlot getAppointmentSlot(Id appointmentId){
        AppointmentSlot appt;
        try {
            
            for (Appointment__c appointment: [
                SELECT  Id,
                        Name,
                        Datetime__c,
                        Availability__c,
                        Booked__c,
                        Capacity__c

                FROM Appointment__c
                WHERE Id =: appointmentId
                WITH SECURITY_ENFORCED
            ]){
                appt = new AppointmentSlot(appointment);
            }
            for(Visit__c visit : [
                SELECT Id,
                        Name,
                        Appointment__c,
                        Donor__c,
                        Donor__r.Name,
                        Donor__r.FirstName,
                        Donor__r.LastName,
                        Donor__r.Email,
                        Status__c
                FROM Visit__c
                WHERE Appointment__c =: appointmentId
                ORDER BY lastmodifieddate
            ]){
                appt.visits.add(new Visit(visit));

                appt.booked = appt.visits.size();
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return appt;
    }

    @AuraEnabled
    public static AppointmentSlot[] getAppointments(Id centerId, Date appointmentDay){
        Appointment__c[] appointments = new Appointment__c[]{};
        Set<Id> appointmentIds = new Set<Id>{};
        Map<Id, AppointmentSlot> appMap = new Map<Id, AppointmentSlot>{};
        Datetime beginDay = Datetime.newInstance(appointmentDay.year(), appointmentDay.month(),appointmentDay.day(), 0,0,0);
        Datetime endDay = Datetime.newInstance(appointmentDay.year(), appointmentDay.month(),appointmentDay.day(), 23,59,59);
        try {
            for(Appointment__c app: [
                SELECT  Id,
                        Name,
                        Datetime__c,
                        Availability__c,
                        Booked__c,
                        Capacity__c

                FROM Appointment__c
                WHERE Schedule__r.Center__c =: centerId
                AND Datetime__c >=: beginDay
                AND Datetime__c <=: endDay 
                WITH SECURITY_ENFORCED
                ORDER BY Datetime__c ASC
                
            ]){
                AppointmentSlot appt = new AppointmentSlot(app);
                appMap.put(app.id,appt);
            }

            for(Visit__c visit : [
                SELECT Id,
                        Name,
                        Appointment__c,
                        Donor__c,
                        Donor__r.Name,
                        Donor__r.FirstName,
                        Donor__r.LastName,
                        Donor__r.Email,
                        Status__c
                FROM Visit__c
                WHERE Appointment__c in: appMap.keyset()
                ORDER BY lastmodifieddate
            ]){
                AppointmentSlot appt = appMap.get(visit.Appointment__c);
                appt.visits.add(new Visit(visit));

                appt.booked = appt.visits.size();
            }
            
            system.debug(appMap);
        } catch(System.QueryException qe){
            throw new AuraHandledException(qe.getMessage() + qe.getStackTraceString());
        } catch (Exception e) {
            
            throw new AuraHandledException(e.getMessage() + e.getStackTraceString());
        }
        return  appMap.values();
    }

    @AuraEnabled
    public static void changeVisitAppointment(Id visitId, Id appointmentId){
        try {
            if(appointmentId != null){
                Visit__c visit = new Visit__c(
                    Appointment__c = appointmentId
                );
                visit.Id = visitId;
                update visit;
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Appointment__c[]  createAppointmentSlots(Id centerId, Date startDate, Date endDate, Integer intervalsPerHour, Integer slotsPerInterval, Id loyaltyTier){
        try {
            system.debug('' + centerId + startDate + endDate + loyaltyTier + intervalsPerHour + slotsPerInterval);

            //create the schedule record
            Schedule__c schedule = ScheduleUtils.createScheduleRecord(centerId, startDate, endDate);
            insert schedule;

            //attach appointments to the new schedule
            Appointment__c[] appointments = ScheduleUtils.scheduleRange(centerId,schedule.Id,startDate,endDate,loyaltyTier,intervalsPerHour,slotsPerInterval);
            insert appointments;
            return appointments;

        } catch (ScheduleUtils.ScheduleException se) {
            throw new AuraHandledException(se.getMessage());
        }catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class Center {

        @AuraEnabled
        public Id value {get; set;}

        @AuraEnabled
        public String label {get; set;}

        public Center(Account a){
            this.value = a.id;
            this.label = a.name;
        }
    }

    public class AppointmentSlot{
        @AuraEnabled
        public Id Id {get; set;}

        @AuraEnabled
        public Datetime appointmentDatetime {get; set;}

        @AuraEnabled
        public Time appointmentTime {get; set;}

        @AuraEnabled
        public String timeString {get; set;}

        @AuraEnabled
        public Visit[] visits {get;set;}

        @AuraEnabled
        public Decimal availability {get;set;}
        
        @AuraEnabled
        public Decimal booked {get;set;}
        
        @AuraEnabled
        public Decimal capacity {get;set;}

        @AuraEnabled
        public Boolean filtered {get;set;}

        public AppointmentSlot(Appointment__c app){
            this.Id = app.Id;
            this.appointmentDatetime = app.Datetime__c;
            TimeZone tz =  UserInfo.getTimeZone();
            this.timeString =  this.appointmentDatetime.format('h:mm a');
            this.visits = new Visit[]{};
            this.availability = app.Availability__c;
            this.booked = app.Booked__c;
            this.capacity = app.Capacity__c;
            this.filtered = false;
        }

    }

    public class Visit {
        @AuraEnabled
        public Id visitId {get; set;}

        @AuraEnabled
        public String visitName {get; set;}

        @AuraEnabled
        public String donorName {get; set;}

        @AuraEnabled
        public String firstName {get; set;}

        @AuraEnabled
        public String lastName {get; set;}

        @AuraEnabled
        public String initials {get; set;}

        @AuraEnabled
        public Id donorId {get; set;}

        @AuraEnabled
        public String visitType {get;set;}

        @AuraEnabled
        public String icon {get;set;}

        @AuraEnabled
        public String status {get;set;}

        @AuraEnabled
        public Boolean filtered {get;set;}
        

        public Visit(Visit__c visit){
            this.visitId = visit.Id;  
            this.visitName = visit.Name;
            this.donorId = visit.Donor__c;
            this.donorName = visit.Donor__r.name;
            this.firstName = visit.Donor__r.firstName;
            this.lastName = visit.Donor__r.lastName;
            this.initials = visit.Donor__r.firstName.subString(0,1) + visit.Donor__r.lastName.subString(0,1);
            this.status = visit.Status__c;
            this.icon = 'standard:account';
            this.filtered = false;
        }
    }

}    