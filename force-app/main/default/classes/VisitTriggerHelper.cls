public with sharing class VisitTriggerHelper {
    public static void updateAppointmentDateTime(List<Visit__c> visitRecordsToUpdate) {
        Map<Id, List<Visit__c>> appointmentIdToVisitRecord = new Map<Id, List<Visit__c>>(); 
        
        for(Visit__c targetVisit : visitRecordsToUpdate) {
            if (targetVisit.Appointment__c != null) {
                List<Visit__c> existingVisits = appointmentIdToVisitRecord.get(targetVisit.Appointment__c);
                if (existingVisits == null) {
                    existingVisits = new List<Visit__c>();
                }

                existingVisits.add(targetVisit);
                appointmentIdToVisitRecord.put(targetVisit.Appointment__c, existingVisits);
            }
        }

        // No Appointment DateTimes to Link
        if (appointmentIdToVisitRecord.size() == 0) {
            return;
        }

        for (Appointment__c queriedAppointment : [
            SELECT Id, Datetime__c
            FROM Appointment__c
            WHERE Id IN :appointmentIdToVisitRecord.keyset()
        ]) {
            if (queriedAppointment.Datetime__c == null) {
                continue;
            }

            List<Visit__c> relatedVisits = appointmentIdToVisitRecord.get(queriedAppointment.Id);
            if (relatedVisits == null || relatedVisits.size() == 0) {
                continue;
            }

            for(Visit__c relatedVisit : relatedVisits) {
                relatedVisit.Appointment_Datetime__c = queriedAppointment.Datetime__c;
            }
        }
    }

    public static void updateDonorVisitDates(List<Visit__c> visits) {
        List<Id> donorIds = new List<Id>();
        List<Id> appointmentIds = new List<Id>();
    
        for (Visit__c visit : visits) {
            if (visit.Physical_Exam__c || visit.SPE_Analysis__c) {
                if (visit.Donor__c == null || visit.Appointment__c == null) {
                    continue;
                }

                donorIds.add(visit.Donor__c);
                appointmentIds.add(visit.Appointment__c);
            }
        }
        
        if (!donorIds.isEmpty()) {
            Map<Id, Contact> visitIdToDonorRecord = new Map<Id, Contact>([SELECT Id, Last_Physical_Exam_Date__c, Last_SPE_Sample_Date__c FROM Contact WHERE Id IN :donorIds]);
            Map<Id, Appointment__c> visitIdToAppointmentRecord = new Map<Id, Appointment__c>([SELECT Id, DateTime__c FROM Appointment__c WHERE Id IN :appointmentIds]);
            
            for (Visit__c visit : visits) {
                Contact donor = visitIdToDonorRecord.get(visit.Donor__c);
                Appointment__c appointment = visitIdToAppointmentRecord.get(visit.Appointment__c);
                
                if (donor != null && appointment.DateTime__c != null) {
                    if (visit.Physical_Exam__c) {
                        donor.Last_Physical_Exam_Date__c = appointment.DateTime__c.date();
                    }
                    
                    if (visit.SPE_Analysis__c) {
                        donor.Last_SPE_Sample_Date__c = appointment.DateTime__c.date();
                    }
                    
                    visitIdToDonorRecord.put(donor.Id, donor);
                }
            }
            
            update visitIdToDonorRecord.values();
        }
    }

    public static void setIsFirstVisitFlag(List<Visit__c> visits) {
        Map<Id, Visit__c> donorIdToNewVisit = new Map<Id, Visit__c>();
        for (Visit__c visit : visits) {
            if (visit.Donor__c != null) {
                donorIdToNewVisit.put(visit.Donor__c, visit);
            }
        }

        if (donorIdToNewVisit.size() != 0) {
            for(Contact donor : [SELECT Id, (SELECT Id, Appointment_Datetime__c, isFirstVisit__c FROM Visits__r) FROM Contact WHERE Id IN :donorIdToNewVisit.keyset()]) {
                donorIdToNewVisit.get(donor.Id).isFirstVisit__c = (donor.Visits__r == null || donor.Visits__r.size() == 0);
            }
        }
    }
}