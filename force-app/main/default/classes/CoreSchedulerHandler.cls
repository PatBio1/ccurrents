public without sharing class CoreSchedulerHandler {
    public static void rescheduleVisit(RescheduleRequest rescheduleRequest) {
        rescheduleVisits(new RescheduleBatchRequest(new List<RescheduleRequest>{ rescheduleRequest }));
    }
    
    public static void rescheduleVisits(RescheduleBatchRequest rescheduleBatchRequest) {
        rescheduleBatchRequest.initializeRescheduleRequestData();

        List<Visit__c> visitsToUpdate = new List<Visit__c>();
        List<Visit__c> visitsToInsert = new List<Visit__c>();
        List<Task> tasksToUpdate = new List<Task>();

        for(RescheduleRequest request : rescheduleBatchRequest.rescheduleRequests) {
            visitsToInsert.add(request.createNewVisit());
        }

        if (visitsToInsert.size() > 0) {
            insert visitsToInsert;
        }

        // We need to insert the new visits before we can reparent the tasks
        for(RescheduleRequest request : rescheduleBatchRequest.rescheduleRequests) {
            tasksToUpdate.addAll(request.reparentTasksToNewVisit());
            visitsToUpdate.add(request.markOriginalVisitAsRescheduled());
        }

        if (tasksToUpdate.size() > 0) {
            update tasksToUpdate;
        }

        if (visitsToUpdate.size() > 0) {
            update visitsToUpdate;
        }
    }

    public static Visit__c createVisit(Visit__c newVisit) {
        return createVisits(new List<Visit__c> { newVisit })[0];
    }

    public static List<Visit__c> createVisits(List<Visit__c> newVisits) {
        Set<Id> appointmentIds = new Set<Id>();
        Set<Id> donorIds = new Set<Id>();

        for(Visit__c visit : newVisits) {
            appointmentIds.add(visit.Appointment__c);
            donorIds.add(visit.Donor__c);
        }

        Map<Id, Appointment__c> appointments = new Map<Id, Appointment__c>([SELECT Id, Capacity__c, Capacity_Loyalty__c FROM Appointment__c WHERE Id IN :appointmentIds]);
        Map<Id, Contact> donors = new Map<Id, Contact>([SELECT Id, Loyalty_Level__c FROM Contact WHERE Id IN :donorIds]);

        for(Visit__c visit : newVisits) {
            Appointment__c appointment = appointments.get(visit.Appointment__c);
            
            Integer donorLoyaltyLevel = LoyaltyLevelService.getLoyaltyLevel(donors.get(visit.Donor__c).Loyalty_Level__c);
            Boolean qualifiesForLoyalty = donorLoyaltyLevel > 0;

            if (appointment.Capacity__c == 0 && (!qualifiesForLoyalty || (qualifiesForLoyalty && appointment.Capacity_Loyalty__c == 0))) {
                throw new AuraHandledException('Appointment is full');
            }
        }

        insert newVisits;
        return newVisits;
    }

    public static void cancelVisit(Id visitId) {
        cancelVisits(new List<Id> { visitId });
    }

    public static void cancelVisits(List<Id> visitIds) {
        List<Visit__c> visitsToUpdate = new List<Visit__c>();

        for(Id visitId : visitIds) {
            visitsToUpdate.add(new Visit__c(
                Id = visitId,
                Status__c = 'Complete',
                Outcome__c = 'Canceled'
            ));
        }

        update visitsToUpdate;
    }

    @AuraEnabled
    public static DateTime getSoonestNextRescheduleVisitDate(Id donorId, Id visitToReschedule) {
        // Create a database savepoint and mark the visit as rescheduled in order to force recalculation
        Savepoint sp = Database.setSavepoint();
        Datetime newRescheduleDate = null;

        try {
            update new Visit__c(
                Id = visitToReschedule,
                Status__c = 'Complete',
                Outcome__c = 'Rescheduled'
            );

            newRescheduleDate = [SELECT Soonest_Next_Visit__c FROM Contact WHERE Id = :donorId LIMIT 1]?.Soonest_Next_Visit__c;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        } finally {
            Database.rollback(sp);
        }

        return newRescheduleDate;
    }

    public class RescheduleBatchRequest {
        public List<RescheduleRequest> rescheduleRequests;
    
        public RescheduleBatchRequest(List<RescheduleRequest> rescheduleRequests) {
            this.rescheduleRequests = rescheduleRequests;
        }
    
        private void initializeRescheduleRequestData() {
            // Query all the required data
            Set<Id> appointmentSlotIds = new Set<Id>();
            Set<Id> visitIds = new Set<Id>();
    
            for(RescheduleRequest request : rescheduleRequests) {
                appointmentSlotIds.add(request.newAppointmentSlotId);
                visitIds.add(request.originalVisitId);
            }
    
            Map<Id, Appointment__c> appointmentSlots = new Map<Id, Appointment__c>([SELECT Id, Booked__c, Booked_Loyalty__c, Capacity__c, Capacity_Loyalty__c FROM Appointment__c WHERE Id IN :appointmentSlotIds]);
            Map<Id, Visit__c> visits = new Map<Id, Visit__c>([
                SELECT Id, Center_Donation_Type__c, Appointment__c, Appointment__r.Booked__c, Appointment__r.Booked_Loyalty__c,
                    Appointment__r.Capacity__c, Appointment__r.Capacity_Loyalty__c, Donor__r.Loyalty_Level__c, 
                    (
                        SELECT Id 
                        FROM Tasks
                    ) 
                FROM Visit__c 
                WHERE Id IN :visitIds
            ]);
    
            for(RescheduleRequest request : rescheduleRequests) {
                request.populateData(appointmentSlots.get(request.newAppointmentSlotId), visits.get(request.originalVisitId));
            }
        }
    }
    
    public class RescheduleRequest {
        public Id originalVisitId;
        public Id newAppointmentSlotId;
    
        private Contact donor;
        private Appointment__c oldAppointmentSlot;
        private Appointment__c newAppointmentSlot;
    
        private Visit__c originalVisit;
        private Visit__c newVisit;
    
        public RescheduleRequest(Id originalVisitId, Id newAppointmentSlotId) {
            this.originalVisitId = originalVisitId;
            this.newAppointmentSlotId = newAppointmentSlotId;
        }
    
        public void populateData(Appointment__c newAppointmentSlot, Visit__c originalVisit) {
            this.donor = originalVisit.Donor__r;
            this.newAppointmentSlot = newAppointmentSlot;
            this.oldAppointmentSlot = originalVisit.Appointment__r;
            this.originalVisit = originalVisit;
        }
    
        public Visit__c createNewVisit() {
            this.newVisit = originalVisit.clone(false, true, false, false);
    
            newVisit.Rescheduled_Visit__c = originalVisit.Id;
            newVisit.Appointment__c = newAppointmentSlot.Id;
            newVisit.Status__c = 'Scheduled';
    
            return this.newVisit;
        }
    
        public List<Task> reparentTasksToNewVisit() {
            if (originalVisit.Tasks != null && originalVisit.Tasks.size() > 0) {
                for (Task task : originalVisit.Tasks) {
                    task.WhatId = newVisit.Id;
                }
            }
    
            return originalVisit.Tasks;
        }
    
        public Visit__c markOriginalVisitAsRescheduled() {
            originalVisit.Status__c = 'Complete';
            originalVisit.Outcome__c = 'Rescheduled';
    
            return originalVisit;
        }
    }
}