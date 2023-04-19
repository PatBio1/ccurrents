public without sharing class CoreSchedulerHandler {
    public static void rescheduleVisit(RescheduleRequest rescheduleRequest) {
        rescheduleVisits(new RescheduleBatchRequest(new List<RescheduleRequest>{ rescheduleRequest }));
    }
    
    public static void rescheduleVisits(RescheduleBatchRequest rescheduleBatchRequest) {
        rescheduleBatchRequest.initializeRescheduleRequestData();

        Map<Id, Appointment__c> appointmentSlotIdToRecord = new Map<Id, Appointment__c>();
        List<Visit__c> visitsToUpdate = new List<Visit__c>();
        List<Visit__c> visitsToInsert = new List<Visit__c>();
        List<Task> tasksToUpdate = new List<Task>();

        for(RescheduleRequest request : rescheduleBatchRequest.rescheduleRequests) {
            for(Appointment__c appointmentSlot : request.updateAppointmentSlotCapacities()) {
                appointmentSlotIdToRecord.put(appointmentSlot.Id, appointmentSlot);
            }
            
            visitsToInsert.add(request.createNewVisit());
        }

        if (appointmentSlotIdToRecord.size() > 0) {
            update appointmentSlotIdToRecord.values();
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
        Set<Id> donorIds = new Set<Id>();
        Set<Id> appointmentSlotIds = new Set<Id>();

        for(Visit__c newVisit : newVisits) {
            donorIds.add(newVisit.Donor__c);
            appointmentSlotIds.add(newVisit.Appointment__c);
        }

        Map<Id, Appointment__c> appointmentSlots = new Map<Id, Appointment__c>([SELECT Id, Booked__c, Booked_Loyalty__c, Capacity__c, Capacity_Loyalty__c FROM Appointment__c WHERE Id IN :appointmentSlotIds]);
        Map<Id, Integer> donorIdToLoyaltyLevel = new Map<Id, Integer>();

        for(Contact donor : [SELECT Id, Loyalty_Level__c FROM Contact WHERE Id IN :donorIds]) {
            donorIdToLoyaltyLevel.put(donor.Id, LoyaltyLevelService.getLoyaltyLevel(donor.Loyalty_Level__c));
        }

        for(Visit__c newVisit : newVisits) {
            Integer loyaltyLevel = donorIdToLoyaltyLevel.get(newVisit.Donor__c);
            Appointment__c targetAppointmentSlot = appointmentSlots.get(newVisit.Appointment__c);

            if (targetAppointmentSlot.Booked__c == null || targetAppointmentSlot.Booked__c < targetAppointmentSlot.Capacity__c) {
                if (targetAppointmentSlot.Booked__c == null) {
                    targetAppointmentSlot.Booked__c = 1;
                } else {
                    targetAppointmentSlot.Booked__c += 1;
                }
            } else if (loyaltyLevel > 0 && (targetAppointmentSlot.Booked_Loyalty__c == null || targetAppointmentSlot.Booked_Loyalty__c < targetAppointmentSlot.Capacity_Loyalty__c)) {
                if (targetAppointmentSlot.Booked_Loyalty__c == null) {
                    targetAppointmentSlot.Booked_Loyalty__c = 1;
                } else {
                    targetAppointmentSlot.Booked_Loyalty__c += 1;
                }
            }

            appointmentSlots.put(newVisit.Appointment__c, targetAppointmentSlot);
        }
    
        update appointmentSlots.values();
        insert newVisits;

        return newVisits;
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
    
        public List<Appointment__c> updateAppointmentSlotCapacities() {
            List<Appointment__c> updatedAppointments = new List<Appointment__c>();
            Integer donorLoyaltyLevel = LoyaltyLevelService.getLoyaltyLevel(originalVisit.Donor__r.Loyalty_Level__c);
    
            // Old Appointment Slot
            if (donorLoyaltyLevel > 0 && oldAppointmentSlot.Booked_Loyalty__c != null && oldAppointmentSlot.Booked_Loyalty__c > 0) {
                oldAppointmentSlot.Booked_Loyalty__c -= 1;
            } else {
                oldAppointmentSlot.Booked__c -= 1;
            }
            updatedAppointments.add(oldAppointmentSlot);
    
            // New Appointment Slot
            if (newAppointmentSlot.Booked__c == null || newAppointmentSlot.Booked__c < newAppointmentSlot.Capacity__c) {
                if (newAppointmentSlot.Booked__c == null) {
                    newAppointmentSlot.Booked__c = 1;
                } else {
                    newAppointmentSlot.Booked__c += 1;
                }
            } else if (donorLoyaltyLevel > 0 && (newAppointmentSlot.Booked_Loyalty__c == null || newAppointmentSlot.Booked_Loyalty__c < newAppointmentSlot.Capacity_Loyalty__c)) {
                if (newAppointmentSlot.Booked_Loyalty__c == null) {
                    newAppointmentSlot.Booked_Loyalty__c = 1;
                } else {
                    newAppointmentSlot.Booked_Loyalty__c += 1;
                }
            }

            updatedAppointments.add(newAppointmentSlot);
            return updatedAppointments;
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