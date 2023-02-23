public without sharing class SchedulerController {

    @AuraEnabled
    public static CenterController.Center getCenter() {
        try {
            User user = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];

            List<AccountContactRelation> relations = [
                SELECT
                    Account.Name, Account.BillingStreet
                FROM
                    AccountContactRelation
                WHERE
                    ContactId = :user.ContactId
                AND
                    Roles INCLUDES ('Donor')
            ];

            Account account = relations[0].Account;

            CenterController.Center center = new CenterController.Center();
            center.id = account.Id;
            center.name = account.Name;
            center.address = account.BillingStreet;
            return center;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    //public static List<Appointment> getAppointments(Id centerId, Date appointmentDate) {
    public static AppointmentGroups getAppointments(Id centerId, Date appointmentDate) {
        try {
            DateTime startTime = DateTime.newInstance(appointmentDate, Time.newInstance(0, 0, 0, 0));
            DateTime endTime = startTime.addDays(1).addSeconds(-1);

            List<Appointment__c> appointmentRecords = [
                SELECT
                    Datetime__c, Availability__c
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

            AppointmentGroups appointmentGroups = new AppointmentGroups();
            //List<Appointment> appointments = new List<Appointment>();

            for (Appointment__c appointmentRecord : appointmentRecords) {
                Appointment appointment = new Appointment();
                appointment.id = appointmentRecord.Id;
                appointment.name = appointmentRecord.Datetime__c.format('h:mm');
                appointment.availability = (appointmentRecord.Availability__c == null ? 0 : appointmentRecord.Availability__c.intValue());
                //appointments.add(appointment);
                if (appointmentRecord.Datetime__c.time() < Time.newInstance(12, 0, 0, 0)) {
                    appointmentGroups.morningAppointments.add(appointment);
                } else if (appointmentRecord.Datetime__c.time() < Time.newInstance(18, 0, 0, 0)) {
                    appointmentGroups.afternoonAppointments.add(appointment);
                } else {
                    appointmentGroups.eveningAppointments.add(appointment);
                }
            }

            //return appointments;
            return appointmentGroups;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static List<Visit> getVisits() {
        try {
            User user = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];

            List<Visit__c> visitRecords = [
                SELECT
                    Appointment__r.Datetime__c, Status__c, Appointment__r.Schedule__r.Center__r.Name, Appointment__r.Schedule__r.Center__r.BillingStreet
                FROM
                    Visit__c
                WHERE
                    Donor__c = :user.ContactId
                ORDER BY
                    Appointment__r.Datetime__c ASC
            ];

            List<Visit> visits = new List<Visit>();

            for (Visit__c visitRecord : visitRecords) {
                Visit visit = new Visit();
                visit.id = visitRecord.Id;
                visit.appointmentDate = visitRecord.Appointment__r.Datetime__c.format('E, d MMM ‘YY');
                visit.appointmentTime = visitRecord.Appointment__r.Datetime__c.format('h:mm a');
                visit.centerName = visitRecord.Appointment__r.Schedule__r.Center__r.Name;
                visit.centerAddress = visitRecord.Appointment__r.Schedule__r.Center__r.BillingStreet;
                visit.status = visitRecord.Status__c;
                visits.add(visit);
            }

            return visits;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Id scheduleVisit(Id appointmentId) {
        try {
            User user = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];

            Appointment__c appointment = [SELECT Schedule__r.Center__c FROM Appointment__c WHERE Id = :appointmentId];

            Center_Donation_Type__c centerDonationType = [
                SELECT Id FROM Center_Donation_Type__c WHERE Center__c = :appointment.Schedule__r.Center__c LIMIT 1
            ];

            Visit__c visit = new Visit__c();
            visit.Donor__c = user.ContactId;
            visit.Appointment__c = appointmentId;
            visit.Center_Donation_Type__c = centerDonationType.Id;
            visit.Status__c = 'Scheduled';
            insert visit;

            return visit.Id;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    public class AppointmentGroups {

        @AuraEnabled
        public List<Appointment> morningAppointments {get; set;}

        @AuraEnabled
        public List<Appointment> afternoonAppointments {get; set;}

        @AuraEnabled
        public List<Appointment> eveningAppointments {get; set;}

        public AppointmentGroups() {
            morningAppointments = new List<Appointment>();
            afternoonAppointments = new List<Appointment>();
            eveningAppointments = new List<Appointment>();
        }

    }

    public class Appointment {

        @AuraEnabled
        public Id id {get; set;}

        @AuraEnabled
        public String name {get; set;}

        @AuraEnabled
        public Integer availability {get; set;}

    }

    public class Visit {

        @AuraEnabled
        public Id id {get; set;}

        @AuraEnabled
        public String appointmentDate {get; set;}

        @AuraEnabled
        public String appointmentTime {get; set;}

        @AuraEnabled
        public String centerName {get; set;}

        @AuraEnabled
        public String centerAddress {get; set;}

        @AuraEnabled
        public String status {get; set;}

    }

}
