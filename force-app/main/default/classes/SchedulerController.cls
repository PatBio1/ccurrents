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
    public static List<AppointmentGroup> getAppointments(Id centerId, Date appointmentDate) {
        User user = [SELECT Contact.Soonest_Next_Visit__c FROM User WHERE Id = :UserInfo.getUserId()];
        return getAppointmentRecords(centerId, appointmentDate, user.Contact.Soonest_Next_Visit__c.date());
    }

    @AuraEnabled
    public static List<AppointmentGroup> getRescheduleAppointments(Id centerId, Id visitToReschedule, Date appointmentDate) {
        User user = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        Datetime rescheduleSoonestNextVisit = CoreSchedulerHandler.getSoonestNextRescheduleVisitDate(user.ContactId, visitToReschedule);

        return getAppointmentRecords(centerId, appointmentDate, rescheduleSoonestNextVisit.date());
    }

    private static List<AppointmentGroup> getAppointmentRecords(Id centerId, Date appointmentDate, Date soonestNextVisit) {
        try {
            List<AppointmentGroup> appointmentGroups = new List<AppointmentGroup>{
                new AppointmentGroup('AM'),
                new AppointmentGroup('PM'),
                new AppointmentGroup('Evening')
            };

            if (appointmentDate >= Date.today()) {
                DateTime startTime = DateTime.newInstance(appointmentDate.year(), appointmentDate.month(), appointmentDate.day(), 0, 0, 0);
                DateTime endTime = startTime.addDays(1).addSeconds(-1);

                List<Appointment__c> appointmentRecords = [
                    SELECT
                        Datetime__c, Availability__c, Availability_Loyalty__c 
                    FROM
                        Appointment__c
                    WHERE
                        Schedule__r.Center__c = :centerId
                    AND 
                        Datetime__c >= :soonestNextVisit
                    AND
                        Datetime__c >= :startTime
                    AND
                        Datetime__c <= :endTime
                    ORDER BY
                        Datetime__c ASC
                ];

                DateTime elevenAM = DateTime.newInstance(appointmentDate.year(), appointmentDate.month(), appointmentDate.day(), 11, 0, 0);
                DateTime twoPM = DateTime.newInstance(appointmentDate.year(), appointmentDate.month(), appointmentDate.day(), 14, 0, 0);

                Contact targetDonor = [SELECT Id, Loyalty_Level__c FROM Contact WHERE Id IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()) LIMIT 1];
                Integer loyaltyLevel = LoyaltyLevelService.getLoyaltyLevel(targetDonor.Loyalty_Level__c);

                for (Appointment__c appointmentRecord : appointmentRecords) {
                    Appointment appointment = new Appointment();
                    appointment.id = appointmentRecord.Id;
                    appointment.name = appointmentRecord.Datetime__c.format('h:mm');

                    appointment.availability = (appointmentRecord.Availability__c == null ? 0 : appointmentRecord.Availability__c.intValue());
                    if (loyaltyLevel > 0) {
                        appointment.availability += (appointmentRecord.Availability_Loyalty__c == null ? 0 : appointmentRecord.Availability_Loyalty__c.intValue());
                    }

                    if (appointmentRecord.Datetime__c < elevenAM) {
                        appointmentGroups[0].appointments.add(appointment);
                    } else if (appointmentRecord.Datetime__c < twoPM) {
                        appointmentGroups[1].appointments.add(appointment);
                    } else {
                        appointmentGroups[2].appointments.add(appointment);
                    }
                }
            }

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
                    isFirstVisit__c, Appointment__r.Datetime__c, Status__c, Appointment__r.Schedule__r.Center__r.Name,
                    Appointment__r.Schedule__r.Center__r.BillingStreet, Donor__r.Account.First_Visit_Code__c, Outcome__c
                FROM
                    Visit__c
                WHERE
                    Donor__c = :user.ContactId
                AND
                    (Status__c = 'Scheduled' OR Status__c = 'Complete')
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
                visit.outcome = visitRecord.Outcome__c;
                visit.firstVisitCode = visitRecord.Donor__r.Account.First_Visit_Code__c;
                visit.isFirstVisit = visitRecord.isFirstVisit__c;
                visits.add(visit);
            }

            return visits;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Boolean hasFutureVisit() {
        try {
            Util.testExceptionHandling();

            User user = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];

            Integer visitCount = [
                SELECT
                    COUNT()
                FROM
                    Visit__c
                WHERE
                    Donor__c = :user.ContactId
                AND
                    Appointment__r.Datetime__c > :DateTime.now()
                AND
                    Status__c != 'Complete'
            ];

            return (visitCount > 0);
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static Id scheduleVisit(Id appointmentId) {
        try {
            Appointment__c appointment = [SELECT Schedule__r.Center__c FROM Appointment__c WHERE Id = :appointmentId LIMIT 1];

            Visit__c visit = CoreSchedulerHandler.createVisit(new Visit__c(
                Donor__c = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]?.ContactId,
                Appointment__c = appointment.Id,
                Status__c = 'Scheduled',
                Center_Donation_Type__c = [SELECT Id FROM Center_Donation_Type__c WHERE Center__c = :appointment.Schedule__r.Center__c LIMIT 1]?.Id
            ));

            return visit.Id;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static void rescheduleVisit(Id appointmentId, Id originalVisitId) {
        try {
            CoreSchedulerHandler.rescheduleVisit(new CoreSchedulerHandler.RescheduleRequest(originalVisitId, appointmentId));
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled 
    public static void cancelVisit(Id visitId) {
        try {
            CoreSchedulerHandler.cancelVisit(visitId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class AppointmentGroup {

        @AuraEnabled
        public String name {get; set;}

        @AuraEnabled
        public List<Appointment> appointments {get; set;}

        public AppointmentGroup(String name) {
            this.name = name;
            appointments = new List<Appointment>();
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

        @AuraEnabled 
        public String firstVisitCode {get; set;}

        @AuraEnabled
        public Boolean isFirstVisit {get; set;}

        @AuraEnabled
        public String outcome {get; set;}
    }

}
