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
        try {
            CoreSchedulerHandler.createVisit(new Visit__c(
                Donor__c = [SELECT PersonContactId FROM Account WHERE Id = :donorId LIMIT 1 FOR UPDATE]?.PersonContactId,
                Center_Donation_Type__c = [SELECT Id FROM Center_Donation_Type__c WHERE Center__c = :centerId LIMIT 1]?.Id,
                Appointment__c = appointmentSlotId,
                Status__c = 'Scheduled'
            ));
        } catch(Exception addVisitException) {
            throw Util.createAuraHandledException(addVisitException);
        }
    }

    @AuraEnabled
    public static void changeVisitAppointment(Id visitId, Id appointmentId){
        CoreSchedulerHandler.rescheduleVisit(new CoreSchedulerHandler.RescheduleRequest(visitId, appointmentId));
    }

    @AuraEnabled 
    public static void cancelVisit(Id visitId) {
        try {
            CoreSchedulerHandler.cancelVisit(visitId);
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
    public static List<RescheduleSlot> getAvailableRescheduleAppointmentRange(Id centerId, DateTime currentDateTime, DateTime soonestNextVisit, DateTime searchStartDateTime, DateTime searchEndDateTime, Boolean isLoyaltyDonor) {
        String appointmentQuery = 'SELECT Id, DateTime__c FROM Appointment__c WHERE Schedule__r.Center__c = :centerId AND  DateTime__c >= :currentDateTime AND DateTime__c >= :soonestNextVisit AND DateTime__c >= :targetStartTime AND DateTime__c <= :targetEndTime';
        if (isLoyaltyDonor) {
            appointmentQuery += ' AND (Availability__c > 0 OR Availability_Loyalty__c > 0)';
        } else {
            appointmentQuery += ' AND Availability__c > 0';
        }
        appointmentQuery += ' ORDER BY DateTime__c ASC';

        List<Appointment__c> queriedAppointments = (List<Appointment__c>)Database.queryWithBinds(
            appointmentQuery,
            new Map<String, Object> {
                'centerId' => centerId,
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

    @AuraEnabled
    public static void linkPaymentCard(String cardId, Id donorId, String initalPIN) {
        // We can assume that if the donor has a payment method record, even if it's inactive, that an account has been created
        Integer existingPaymentMethodCount = [SELECT count() FROM Payment_Method__c WHERE Donor__c = :donorId];
        Boolean hasPaymentAccount = existingPaymentMethodCount > 0;
        
        OnbePaymentService linkPaymentCardService = new OnbePaymentService();
        if (hasPaymentAccount) {
            try {
                linkPaymentCardService.linkPhysicalCard(cardId, donorId, initalPIN);
            } catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }
        } else {
            try {
                linkPaymentCardService.setupPaymentServiceAccount(cardId, donorId, 0, initalPIN);
            } catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }
        }
    }

    @AuraEnabled
    public static UpdateCapacityResult updateAppointmentSlotCapacity(Id appointmentId, Decimal capacityChange) {
        Appointment__c targetAppointmentSlot;

        try {
            targetAppointmentSlot = [
                SELECT Id, Schedule__r.Center__c, Capacity__c, Booked__c, Booked_Loyalty__c, Datetime__c, (
                    SELECT Id, Donor__c, Donor__r.Loyalty_Level__c 
                    FROM Appointments__r
                    WHERE Status__c IN ('New', 'Scheduled') AND Outcome__c = null
                    ORDER BY Donor__r.Total_Visits_365d__c ASC NULLS FIRST, Donor__r.CreatedDate DESC
                ) 
                FROM Appointment__c 
                WHERE Id = :appointmentId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        targetAppointmentSlot.Capacity__c += capacityChange;
        if (targetAppointmentSlot.Capacity__c < 0) {
            targetAppointmentSlot.Capacity__c = 0;
        }

        Decimal bookedValue = (targetAppointmentSlot.Booked__c != null) ? targetAppointmentSlot.Booked__c : 0;
        Decimal bookedLoyaltyValue = (targetAppointmentSlot.Booked_Loyalty__c != null) ? targetAppointmentSlot.Booked_Loyalty__c : 0;
        Decimal capacityValue = (targetAppointmentSlot.Capacity__c != null) ? targetAppointmentSlot.Capacity__c : 0;

        List<CoreSchedulerHandler.RescheduleRequest> rescheduleRequests = new List<CoreSchedulerHandler.RescheduleRequest>();
        List<Id> appointmentSlotsRescheduledTo = new List<Id>();
        Decimal capacityVsBookedDiff = capacityValue - (bookedValue + bookedLoyaltyValue);
        Boolean shouldRescheduleDonors = capacityVsBookedDiff < 0;

        if (shouldRescheduleDonors) {
            Decimal amountOfVisitsToReschedule = capacityVsBookedDiff * -1;

            List<Visit__c> visitsToReschedule = new List<Visit__c>();
            Boolean areLoyaltyDonorsIncluded = false;

            for (Visit__c visit : targetAppointmentSlot.Appointments__r) {
                if (amountOfVisitsToReschedule == 0) {
                    break;
                }

                visitsToReschedule.add(visit);
                amountOfVisitsToReschedule--;

                if (!areLoyaltyDonorsIncluded && LoyaltyLevelService.getLoyaltyLevel(visit.Donor__r.Loyalty_Level__c) > 0) {
                    areLoyaltyDonorsIncluded = true;
                }
            }

            List<Appointment__c> appointmentsToRescheduleTo;
            if (areLoyaltyDonorsIncluded) {
                appointmentsToRescheduleTo = [
                    SELECT Id, Availability__c, Availability_Loyalty__c
                    FROM Appointment__c
                    WHERE (Availability__c > 0 OR Availability_Loyalty__c > 0) AND
                        Datetime__c > :targetAppointmentSlot.Datetime__c AND 
                        Schedule__r.Center__c = :targetAppointmentSlot.Schedule__r.Center__c
                    ORDER BY Datetime__c ASC
                    LIMIT :visitsToReschedule.size()
                ];
            } else {
                appointmentsToRescheduleTo = [
                    SELECT Id, Availability__c, Availability_Loyalty__c
                    FROM Appointment__c
                    WHERE Availability__c > 0 AND 
                        Datetime__c > :targetAppointmentSlot.Datetime__c AND
                        Schedule__r.Center__c = :targetAppointmentSlot.Schedule__r.Center__c
                    ORDER BY Datetime__c ASC
                    LIMIT :visitsToReschedule.size()
                ];
            }
            
            if (appointmentsToRescheduleTo.size() == 0) {
                throw new AuraHandledException('There are no available appointments to reschedule overflow donors to.');
            }

            Map<Id, Decimal> appointmentIdToAdjustedAvailability = new Map<Id, Decimal>();
            Map<Id, Decimal> appointmentIdToAdjustedLoyaltyAvailability = new Map<Id, Decimal>();

            for (Integer i = 0; i < visitsToReschedule.size(); i++) {
                Appointment__c targetAppointment;

                for(Appointment__c appointment : appointmentsToRescheduleTo) {
                    // Since formula fields aren't writeable and we aren't updating the slots (reschedule function does that), we need to locally track the adjusted availability
                    Decimal adjustedAvailability = appointmentIdToAdjustedAvailability.get(appointment.Id);
                    if (adjustedAvailability == null) {
                        adjustedAvailability = appointment.Availability__c;
                    }

                    Decimal adjustedLoyaltyAvailability = appointmentIdToAdjustedLoyaltyAvailability.get(appointment.Id);
                    if (adjustedLoyaltyAvailability == null) {
                        adjustedLoyaltyAvailability = appointment.Availability_Loyalty__c;
                    }

                    if (adjustedAvailability > 0) {
                        targetAppointment = appointment;
                        appointmentIdToAdjustedAvailability.put(appointment.Id, adjustedAvailability - 1);

                        break;
                    } else if (LoyaltyLevelService.getLoyaltyLevel(visitsToReschedule[i].Donor__r.Loyalty_Level__c) > 0 && adjustedLoyaltyAvailability > 0) {
                        targetAppointment = appointment;
                        appointmentIdToAdjustedLoyaltyAvailability.put(appointment.Id, adjustedLoyaltyAvailability - 1);

                        break;
                    }
                }

                if (targetAppointment == null) {
                    throw new AuraHandledException('There are not enough appointments to reschedule overflow donors to.');
                }

                appointmentSlotsRescheduledTo.add(targetAppointment.Id);
                rescheduleRequests.add(new CoreSchedulerHandler.RescheduleRequest(visitsToReschedule[i].Id, targetAppointment.Id));
            }
        }

        try {
            update targetAppointmentSlot;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        if (rescheduleRequests.size() > 0) {
            CoreSchedulerHandler.rescheduleVisits(new CoreSchedulerHandler.RescheduleBatchRequest(rescheduleRequests));
        }

        return new UpdateCapacityResult(shouldRescheduleDonors, appointmentSlotsRescheduledTo);
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

    public class UpdateCapacityResult {
        @AuraEnabled
        public Boolean wasDonorRescheduled {get;set;}

        @AuraEnabled
        public List<Id> appointmentSlotsRescheduledTo {get;set;}

        public UpdateCapacityResult(Boolean wasDonorRescheduled, List<Id> appointmentSlotsRescheduledTo) {
            this.wasDonorRescheduled = wasDonorRescheduled;
            this.appointmentSlotsRescheduledTo = appointmentSlotsRescheduledTo;
        }
    }
}