public without sharing class SchedulerController {

/*
Lead lead = new Lead();
lead.FirstName = 'First';
lead.LastName = 'Last';
lead.Email = 'demo@proesis.com';
insert lead;

System.debug(lead);

LeadStatus leadStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];

Database.LeadConvert leadConvert = new Database.LeadConvert();
leadConvert.setLeadId('00QDn000004EnQ7MAK');
leadConvert.setConvertedStatus(leadStatus.MasterLabel);
leadConvert.setDoNotCreateOpportunity(true);

Database.LeadConvertResult lcr = Database.convertLead(leadConvert);

System.debug(lcr);




    System.debug(userId);
*/

    @AuraEnabled
    public static Id createAccount() {
        try {
            Lead lead = new Lead();
            lead.FirstName = 'First';
            lead.LastName = 'Last';
            lead.Email = 'demo@proesis.com';
            insert lead;

            System.debug(lead);

            LeadStatus leadStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];

            Database.LeadConvert leadConvert = new Database.LeadConvert();
            leadConvert.setLeadId(lead.Id);
            leadConvert.setConvertedStatus(leadStatus.MasterLabel);
            leadConvert.setDoNotCreateOpportunity(true);

            Database.LeadConvertResult lcr = Database.convertLead(leadConvert);

            System.debug(lcr);

            return lcr.getAccountId();
        } catch (Exception e) {
            String message = e.getMessage() + ' -- ' + e.getStackTraceString();

            AuraHandledException ahe = new AuraHandledException(message);
            ahe.setMessage(message);
            throw ahe;
        }
    }

    @AuraEnabled
    public static Id createUser(Id accountId) {
        try {
            Account account = [
                SELECT
                    FirstName, LastName, PersonEmail, PersonContactId
                FROM
                    Account
                WHERE
                    Id = :accountId
            ];

            String nickname = account.FirstName.substring(0, 1) + account.LastName;
            String username = nickname + '@proesispoc.com';

            User user = new user();
            user.FirstName = account.FirstName;
            user.LastName = account.LastName;
            user.Email = account.PersonEmail;
            user.Alias = nickname.abbreviate(8); // only 8 characters
            user.Username = username;
            user.CommunityNickname = nickname.abbreviate(40);
            user.LocaleSidKey = 'en_US';
            user.TimeZoneSidKey = 'America/New_York';
            user.ProfileId = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User'].Id;
            user.LanguageLocaleKey = 'en_US';
            user.EmailEncodingKey = 'UTF-8';
            user.ContactId = account.PersonContactId;
            user.IsActive = true;

            //Id userId = Site.createExternalUser(user, account.Id, 'ccurrents', false);
            Id userId = Site.createPortalUser(user, account.Id, 'ccurrents', false);

            return userId;
        } catch (Exception e) {
            String message = e.getMessage() + ' -- ' + e.getStackTraceString();

            AuraHandledException ahe = new AuraHandledException(message);
            ahe.setMessage(message);
            throw ahe;
        }
    }

    @AuraEnabled
    public static List<Center> getCenters(Double latitude, Double longitude) {
        try {
            List<Account> accounts = [
                SELECT
                    Name, BillingStreet, Geolocation__c
                FROM
                    Account
                WHERE
                    RecordType.Name = 'Center'
                AND
                    Site != null
                ORDER BY
                    DISTANCE(Geolocation__c, GEOLOCATION(:latitude, :longitude), 'mi')
                LIMIT
                    5
            ];

            List<Center> centers = new List<Center>();

            for (Account account : accounts) {
                Center center = new Center();
                center.id = account.Id;
                center.name = account.Name;
                center.address = account.BillingStreet;
                center.distance = Decimal.valueOf(Location.getDistance(account.Geolocation__c, Location.newInstance(latitude, longitude), 'mi')).setScale(1) + ' mi';
                centers.add(center);
            }

            return centers;
        } catch (Exception e) {
            String message = e.getMessage() + ' -- ' + e.getStackTraceString();

            AuraHandledException ahe = new AuraHandledException(message);
            ahe.setMessage(message);
            throw ahe;
        }
    }

    @AuraEnabled
    public static Center getCenter() {
        try {
            User user = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];

            List<AccountContactRelation> relations = [
                SELECT
                    Account.Name, Account.BillingStreet
                FROM
                    AccountContactRelation
                WHERE
                    ContactId = :user.ContactId
            ];

            Account account = relations[0].Account;

            Center center = new Center();
            center.id = account.Id;
            center.name = account.Name;
            center.address = account.BillingStreet;
            return center;
        } catch (Exception e) {
            String message = e.getMessage() + ' -- ' + e.getStackTraceString();

            AuraHandledException ahe = new AuraHandledException(message);
            ahe.setMessage(message);
            throw ahe;
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
            String message = e.getMessage() + ' -- ' + e.getStackTraceString();

            AuraHandledException ahe = new AuraHandledException(message);
            ahe.setMessage(message);
            throw ahe;
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
            String message = e.getMessage() + ' -- ' + e.getStackTraceString();

            AuraHandledException ahe = new AuraHandledException(message);
            ahe.setMessage(message);
            throw ahe;
        }
    }

    @AuraEnabled
    public static Id scheduleVisit(Id appointmentId) {
        try {
            User user = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];

            Visit__c visit = new Visit__c();
            visit.Donor__c = user.ContactId;
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
        public Id id {get; set;}

        @AuraEnabled
        public String name {get; set;}

        @AuraEnabled
        public String address {get; set;}

        @AuraEnabled
        public String distance {get; set;}

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