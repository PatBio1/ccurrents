public with sharing class SchedulerController {

    @AuraEnabled
    public static Center getCenter(Id centerId) {
        try {
            Account account = [
                SELECT
                    Name
                FROM
                    Account
                WHERE
                    Id = :centerId
            ];

            Center center = new Center();
            center.name = account.Name;
            center.address = '123 Main Street';
            return center;
        } catch (Exception e) {
            String message = e.getMessage() + ' -- ' + e.getStackTraceString();

            AuraHandledException ahe = new AuraHandledException(message);
            ahe.setMessage(message);
            throw ahe;
        }
    }

    @AuraEnabled
    public static List<Appointment> getAppointments(Id centerId, Date appointmentDate) {
        try {
            DateTime startTime = DateTime.newInstance(appointmentDate, Time.newInstance(0, 0, 0, 0));
            DateTime endTime = startTime.addDays(1).addSeconds(-1);

            List<Appointment__c> appointmentRecords = [
                SELECT
                    Datetime__c
                FROM
                    Appointment__c
                WHERE
                    Schedule__r.Center__c = :centerId
                AND
                    Datetime__c >= :startTime
                AND
                    Datetime__c <= :endTime
                ORDER BY
                    Datetime__c ASC
            ];

            List<Appointment> appointments = new List<Appointment>();

            for (Appointment__c appointmentRecord : appointmentRecords) {
                Appointment appointment = new Appointment();
                appointment.id = appointmentRecord.Id;
                appointment.name = appointmentRecord.Datetime__c.format('H:mm');
                appointments.add(appointment);
            }

            return appointments;
        } catch (Exception e) {
            String message = e.getMessage() + ' -- ' + e.getStackTraceString();

            AuraHandledException ahe = new AuraHandledException(message);
            ahe.setMessage(message);
            throw ahe;
        }
    }

    @AuraEnabled
    public static Id scheduleVisit(Id donorId, Id appointmentId) {
        try {
            Visit__c visit = new Visit__c();
            visit.Donor__c = donorId;
            visit.Appointment__c = appointmentId;
            visit.Status__c = 'Scheduled';
            insert visit;

            return visit.Id;
        } catch (Exception e) {
            String message = e.getMessage() + ' -- ' + e.getStackTraceString();

            AuraHandledException ahe = new AuraHandledException(message);
            ahe.setMessage(message);
            throw ahe;
        }
    }

    public class Center {

        @AuraEnabled
        public String name {get; set;}

        @AuraEnabled
        public String address {get; set;}

    }

    public class Appointment {

        @AuraEnabled
        public Id id {get; set;}

        @AuraEnabled
        public String name {get; set;}

    }

}
