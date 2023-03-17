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
}