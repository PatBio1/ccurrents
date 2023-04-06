public with sharing class CenterScheduleController {
    
    @AuraEnabled
    public static Center[] getCenters(){
        Center[] centers = new Center[]{};
        try {

            for( Account a: [
                Select Id, Name 
                FROM Account 
                WHERE RecordType.DeveloperName = 'Center' AND
                    isActive__c = true
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
                        Availability_Loyalty__c,
                        Booked__c,
                        Booked_Loyalty__c,
                        Capacity__c,
                        Capacity_Loyalty__c

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
                        isFirstVisit__c,
                        Donor__c,
                        Donor__r.Name,
                        Donor__r.FirstName,
                        Donor__r.LastName,
                        Donor__r.Account.Loyalty_Level__pr.Name,
                        Donor__r.Account.First_Visit__pc,
                        Donor__r.Email,
                        Status__c,
                        Outcome__c,
                        (
                            SELECT Id, Subject, Description
                            FROM Tasks
                        )
                FROM Visit__c
                WHERE Appointment__c =: appointmentId
                ORDER BY lastmodifieddate
            ]){
                appt.visits.add(new Visit(visit));
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return appt;
    }

    @AuraEnabled
    public static AppointmentSlot[] getAppointments(Id centerId, Date appointmentDay, String timeStart, String timeStop){
        Appointment__c[] appointments = new Appointment__c[]{};
        Set<Id> appointmentIds = new Set<Id>{};
        Map<Id, AppointmentSlot> appMap = new Map<Id, AppointmentSlot>{};
        String[] startParts = new String[]{'0','0'};
        if(!String.isBlank(timeStart)){
            startParts  = timeStart.split(':');
        }
        String[] endParts = new String[]{'23','59'};
        if(!String.isBlank(timeStop)){
            endParts  = timeStop.split(':');
        }
        Datetime beginDay = Datetime.newInstance(appointmentDay.year(), appointmentDay.month(),appointmentDay.day(), Integer.valueOf(startParts[0]),Integer.valueOf(startParts[1]),0);
        Datetime endDay = Datetime.newInstance(appointmentDay.year(), appointmentDay.month(),appointmentDay.day(), Integer.valueOf(endParts[0]),Integer.valueOf(endParts[1]),59);
        try {
            for(Appointment__c app: [
                SELECT  Id,
                        Name,
                        Datetime__c,
                        Availability__c,
                        Availability_Loyalty__c,
                        Booked__c,
                        Booked_Loyalty__c,
                        Capacity__c,
                        Capacity_Loyalty__c

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
                        isFirstVisit__c,
                        Donor__c,
                        Donor__r.Name,
                        Donor__r.FirstName,
                        Donor__r.LastName,
                        Donor__r.Account.Loyalty_Level__pr.Name,
                        Donor__r.Account.First_Visit__pc,
                        Donor__r.Email,
                        Status__c,
                        Outcome__c,
                        (
                            SELECT Id, Subject, Description
                            FROM Tasks
                        )
                FROM Visit__c
                WHERE Appointment__c in: appMap.keyset()
                ORDER BY lastmodifieddate
            ]){
                AppointmentSlot appt = appMap.get(visit.Appointment__c);
                appt.visits.add(new Visit(visit));
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
    public static void addVisit(Id donorId, Id appointmentSlotId, Id centerId) {
        Account donor = [SELECT PersonContactId, Loyalty_Level__pc FROM Account WHERE Id = :donorId LIMIT 1];
        Integer loyaltyLevel = LoyaltyLevelService.getLoyaltyLevel(donor.Loyalty_Level__pc);

        Appointment__c targetSlot = [SELECT Id, Booked__c, Booked_Loyalty__c, Capacity_Loyalty__c FROM Appointment__c WHERE Id = :appointmentSlotId LIMIT 1];
        if (loyaltyLevel > 0 && (targetSlot.Booked_Loyalty__c == null || targetSlot.Booked_Loyalty__c < targetSlot.Capacity_Loyalty__c)) {
            if (targetSlot.Booked_Loyalty__c == null) {
                targetSlot.Booked_Loyalty__c = 1;
            } else {
                targetSlot.Booked_Loyalty__c += 1;
            }
        } else {
            targetSlot.Booked__c += 1;
        }
        update targetSlot;

        Visit__c newVisit;
        try {
            newVisit = new Visit__c(
                Donor__c = donor.PersonContactId,
                Center_Donation_Type__c = [SELECT Id FROM Center_Donation_Type__c WHERE Center__c = :centerId LIMIT 1]?.Id,
                Appointment__c = appointmentSlotId,
                Status__c = 'Scheduled'
            );
            insert newVisit;
        } catch(Exception addVisitException) {
            throw Util.createAuraHandledException(addVisitException);
        }
    }

    @AuraEnabled
    public static void changeVisitAppointment(Id visitId, Id appointmentId){
        if (appointmentId == null) {
            return;
        }

        Visit__c visitDetails = [SELECT Id, Status__c, Center_Donation_Type__c, Appointment__c, Donor__r.Loyalty_Level__c FROM Visit__c WHERE Id = :visitId LIMIT 1];
        Integer loyaltyLevel = LoyaltyLevelService.getLoyaltyLevel(visitDetails.Donor__r.Loyalty_Level__c);
        
        List<Appointment__c> targetAppointments = [SELECT Id, Booked__c, Booked_Loyalty__c, Capacity_Loyalty__c FROM Appointment__c WHERE Id IN (:visitDetails.Appointment__c, :appointmentId)];
        Appointment__c oldAppointment = (targetAppointments[0].Id == visitDetails.Appointment__c) ? targetAppointments[0] : targetAppointments[1];
        Appointment__c newAppointment = (targetAppointments[0].Id == appointmentId) ? targetAppointments[0] : targetAppointments[1];

        // Updating Slot Booked/Capacity
        if (loyaltyLevel > 0 && oldAppointment.Booked_Loyalty__c != null && oldAppointment.Booked_Loyalty__c > 0) {
            oldAppointment.Booked_Loyalty__c -= 1;
        } else {
            oldAppointment.Booked__c -= 1;
        }

        if (loyaltyLevel > 0 && (newAppointment.Booked_Loyalty__c == null || newAppointment.Booked_Loyalty__c < newAppointment.Capacity_Loyalty__c)) {
            if (newAppointment.Booked_Loyalty__c == null) {
                newAppointment.Booked_Loyalty__c = 1;
            } else {
                newAppointment.Booked_Loyalty__c += 1;
            }
        } else {
            newAppointment.Booked__c += 1;
        }
        update targetAppointments;

        // Create New Visit By Cloning Old Visit
        Visit__c newVisit = visitDetails.clone(false, true, false, false);
        newVisit.Appointment__c = appointmentId;
        newVisit.Status__c = 'Scheduled';

        insert newVisit;

        // Query any Tasks associated with the old Visit, reassign them to the new Visit
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :visitId];
        if (tasks != null && tasks.size() > 0) {
            for (Task task : tasks) {
                task.WhatId = newVisit.Id;
            }
            update tasks;
        }

        // Change Old Visit to Complete/Rescheduled
        try {
            update new Visit__c(Id = visitId, Outcome__c = 'Rescheduled', Status__c = 'Complete');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled 
    public static void cancelVisit(Id visitId){
        Visit__c visitDetails = [SELECT Id, Appointment__c, Appointment__r.Booked__c, Appointment__r.Booked_Loyalty__c, Donor__r.Loyalty_Level__c FROM Visit__c WHERE Id = :visitId LIMIT 1];
        Integer loyaltyLevel = LoyaltyLevelService.getLoyaltyLevel(visitDetails.Donor__r.Loyalty_Level__c);

        Appointment__c appointmentToUpdate = new Appointment__c(Id = visitDetails.Appointment__c, Booked__c = visitDetails.Appointment__r.Booked__c, Booked_Loyalty__c = visitDetails.Appointment__r.Booked_Loyalty__c);
        if (loyaltyLevel > 0) {
            appointmentToUpdate.Booked_Loyalty__c -= 1;
        } else {
            appointmentToUpdate.Booked__c -= 1;
        }
        update appointmentToUpdate;

        try {
            visitDetails.Status__c = 'Complete';
            visitDetails.Outcome__c = 'Canceled';

            update visitDetails;
            
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

    @AuraEnabled
    public static DateTime getSoonestNextRescheduleVisitDate(Id donorId) {
        return [SELECT Id, Soonest_Next_Visit__pc FROM Account WHERE Id = :donorId LIMIT 1]?.Soonest_Next_Visit__pc;
    }

    @AuraEnabled
    public static List<RescheduleSlot> getAvailableRescheduleAppointmentRange(DateTime currentDateTime, DateTime soonestNextVisit, DateTime searchStartDateTime, DateTime searchEndDateTime, Boolean isLoyaltyDonor) {
        String appointmentQuery = 'SELECT Id, DateTime__c FROM Appointment__c WHERE DateTime__c >= :currentDateTime AND DateTime__c >= :soonestNextVisit AND DateTime__c >= :targetStartTime AND DateTime__c <= :targetEndTime';
        if (isLoyaltyDonor) {
            appointmentQuery += ' AND (Availability__c > 0 OR Availability_Loyalty__c > 0)';
        } else {
            appointmentQuery += ' AND Availability__c > 0';
        }
        appointmentQuery += ' ORDER BY DateTime__c ASC';

        List<Appointment__c> queriedAppointments = (List<Appointment__c>)Database.queryWithBinds(
            appointmentQuery,
            new Map<String, Object> {
                'currentDateTime' => currentDateTime, 
                'soonestNextVisit' => soonestNextVisit,
                'targetStartTime' => searchStartDateTime, 
                'targetEndTime' => searchEndDateTime
            }, 
            AccessLevel.USER_MODE
        );

        List<RescheduleSlot> rescheduleSlots = new List<RescheduleSlot>();
        for(Appointment__c appointment : queriedAppointments) {
            rescheduleSlots.add(new RescheduleSlot(appointment));
        }

        return rescheduleSlots;
    }

    @AuraEnabled
    public static void createSoonestNextVisitForDonor(Id donorId, Id centerId) {
        List<Appointment__c> soonestNextAvailableAppointment = [
            SELECT Id
            FROM Appointment__c
            WHERE Schedule__r.Center__c = :centerId AND
                Datetime__c >= :System.now() AND 
                Availability__c > 0
            ORDER BY Datetime__c ASC
            LIMIT 1
        ];

        if (soonestNextAvailableAppointment == null || soonestNextAvailableAppointment.size() == 0) {
            return;
        }

        addVisit(donorId, soonestNextAvailableAppointment[0].Id, centerId);
    }

    public class RescheduleSlot {
        @AuraEnabled
        public Id appointmentId;

        @AuraEnabled
        public DateTime appointmentDateTime;

        public RescheduleSlot(Appointment__c source) {
            appointmentId = source.Id;
            appointmentDateTime = source.DateTime__c;
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
        public Decimal loyaltyAvailability {get;set;}
        
        @AuraEnabled
        public Decimal booked {get;set;}
        @AuraEnabled
        public Decimal loyaltyBooked {get;set;}
        @AuraEnabled
        public Decimal totalBooked {get; set;}
        
        @AuraEnabled
        public Decimal capacity {get;set;}
        @AuraEnabled
        public Decimal loyaltyCapacity {get;set;}

        @AuraEnabled
        public Boolean isInThePast {get;set;}

        @AuraEnabled
        public Boolean filtered {get;set;}

        public AppointmentSlot(Appointment__c app){
            this.Id = app.Id;
            this.appointmentDatetime = app.Datetime__c;
            TimeZone tz =  UserInfo.getTimeZone();
            this.timeString =  this.appointmentDatetime.format('h:mm a');
            this.visits = new Visit[]{};

            this.availability = (app.Availability__c == null) ? 0 : app.Availability__c;
            this.loyaltyAvailability = (app.Availability_Loyalty__c == null) ? 0 : app.Availability_Loyalty__c;

            this.booked = (app.Booked__c == null) ? 0 : app.Booked__c;
            this.loyaltyBooked = (app.Booked_Loyalty__c == null) ? 0 : app.Booked_Loyalty__c;
            this.totalBooked = this.booked + this.loyaltyBooked;

            this.capacity = (app.Capacity__c == null) ? 0 : app.Capacity__c;
            this.loyaltyCapacity = (app.Capacity_Loyalty__c == null) ? 0 : app.Capacity_Loyalty__c;

            this.filtered = false;
            this.isInThePast = this.appointmentDatetime < DateTime.now();
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
        public String outcome {get; set;}

        @AuraEnabled
        public Boolean filtered {get;set;}

        @AuraEnabled
        public String loyaltyTierName {get;set;}

        @AuraEnabled
        public Boolean isFirstVisit {get;set;}

        @AuraEnabled
        public VisitNote[] visitNotes {get;set;}

        public Visit(Visit__c visit){
            this.visitId = visit.Id;  
            this.visitName = visit.Name;
            this.donorId = visit.Donor__c;
            this.donorName = visit.Donor__r.name;
            this.firstName = visit.Donor__r.firstName;
            this.lastName = visit.Donor__r.lastName;
            this.initials = visit.Donor__r.firstName.subString(0,1) + visit.Donor__r.lastName.subString(0,1);
            this.status = visit.Status__c;
            this.outcome = visit.Outcome__c;
            this.icon = 'standard:account';
            this.filtered = false;

            this.loyaltyTierName = visit.Donor__r.Account.Loyalty_Level__pr.Name;
            this.isFirstVisit = visit.isFirstVisit__c;

            this.visitNotes = new VisitNote[] {};
            if (visit.Tasks != null) {
                for(Task visitTask : visit.Tasks) {
                    this.visitNotes.add(new VisitNote(visitTask));
                }
            }
        }
    }

    public class VisitNote {
        @AuraEnabled
        public String visitNoteId {get;set;}

        @AuraEnabled
        public String visitNoteSubject {get;set;}

        @AuraEnabled
        public String visitNoteDescription {get;set;}

        public VisitNote(Task taskRecord) {
            this.visitNoteId = taskRecord.Id;
            this.visitNoteSubject = taskRecord.Subject;
            this.visitNoteDescription = taskRecord.Description;
        }
    }
}    