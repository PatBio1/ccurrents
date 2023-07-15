public without sharing class SchedulerController {

    @AuraEnabled
    public static CenterController.Center getCenter() {
        try {
            User user = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];

            List<AccountContactRelation> relations = [
                SELECT
                    Account.Name, Account.BillingStreet, Account.Center_Timezone__c
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
            center.timeZone = Constants.TIME_ZONE_REGIONS.get(account.Center_Timezone__c);
            return center;
        } catch (Exception e) {
            throw Util.createAuraHandledException(e);
        }
    }

    @AuraEnabled
    public static List<AppointmentGroup> getAppointments(Id centerId, Date appointmentDate) {
        return getAppointmentRecords(centerId, appointmentDate);
    }

    @AuraEnabled
    public static List<AppointmentGroup> getRescheduleAppointments(Id centerId, Id visitToReschedule, Date appointmentDate) {
        // Temporarily cancel the passed in visit in order to correctly calculate the availability
        Savepoint savepoint = Database.setSavepoint();
        update new Visit__c(
            Id = visitToReschedule,
            Status__c = 'Complete',
            Outcome__c = 'Rescheduled'
        );

        List<AppointmentGroup> rescheduleAppointmentGroups = getAppointmentRecords(centerId, appointmentDate);
        Database.rollback(savepoint);

        return rescheduleAppointmentGroups;
    }

    private static List<AppointmentGroup> getAppointmentRecords(Id centerId, Date appointmentDate) {
        try {
            List<AppointmentGroup> appointmentGroups = new List<AppointmentGroup>{
                new AppointmentGroup('AM'),
                new AppointmentGroup('PM'),
                new AppointmentGroup('Evening')
            };

            if (appointmentDate >= Date.today()) {
                Account center = [SELECT Center_Timezone__c FROM Account WHERE Id = :centerId];

                DateTime startTime = Util.getTimeZoneDateTime(appointmentDate, Time.newInstance(0, 0, 0, 0), center.Center_Timezone__c);
                DateTime endTime = startTime.addDays(1).addSeconds(-1);

                List<Appointment__c> appointmentRecords = [
                    SELECT
                        Datetime__c, Availability__c, Availability_Loyalty__c 
                    FROM
                        Appointment__c
                    WHERE
                        Schedule__r.Center__c = :centerId
                    AND
                        Datetime__c > :DateTime.now()
                    AND
                        Datetime__c >= :startTime
                    AND
                        Datetime__c <= :endTime
                    ORDER BY
                        Datetime__c ASC
                ];

                DateTime elevenAM = Util.getTimeZoneDateTime(appointmentDate, Time.newInstance(11, 0, 0, 0), center.Center_Timezone__c);
                DateTime twoPM = Util.getTimeZoneDateTime(appointmentDate, Time.newInstance(14, 0, 0, 0), center.Center_Timezone__c);

                Contact targetDonor = [SELECT Loyalty_Level__c FROM Contact WHERE Id IN (SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()) LIMIT 1];
                Integer loyaltyLevel = LoyaltyLevelService.getLoyaltyLevel(targetDonor.Loyalty_Level__c);

                List<FdaVisitValidator.FdaValidationRequest> validationRequests = new List<FdaVisitValidator.FdaValidationRequest>();
                Map<Id, Appointment> appointmentIdToAppointmentWrapper = new Map<Id, Appointment>(); 
                Center_Donation_Type__c donationType = [SELECT Id FROM Center_Donation_Type__c WHERE Center__c = :centerId AND Donation_Type__r.Name = 'Normal Source Plasma' LIMIT 1];

                for (Appointment__c appointmentRecord : appointmentRecords) {
                    Appointment appointment = new Appointment();
                    appointment.id = appointmentRecord.Id;
                    appointment.name = appointmentRecord.Datetime__c.format('h:mm', center.Center_Timezone__c);

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

                    appointmentIdToAppointmentWrapper.put(appointmentRecord.Id, appointment);
                    validationRequests.add(new FdaVisitValidator.FdaValidationRequest(appointmentRecord.Id, targetDonor.Id, donationType.Id));
                }

                FdaVisitValidator validatorInstance = new FdaVisitValidator(validationRequests, true);
                validationRequests = validatorInstance.validateCreateVisitRequests();

                for (FdaVisitValidator.FdaValidationRequest validationRequest : validationRequests) {
                    Appointment appointment = appointmentIdToAppointmentWrapper.get(validationRequest.appointmentId);
                    appointment.isValid = validationRequest.validationResult != null ? validationRequest.validationResult.isValid : true;
                    appointment.validationError = validationRequest.validationResult != null ? validationRequest.validationResult.errorMessage : '';
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
                    Appointment__r.Schedule__r.Center__r.BillingStreet, Appointment__r.Schedule__r.Center__r.Center_Timezone__c,
                    Donor__r.Account.First_Visit_Code__c, Outcome__c,
                    (
                        SELECT
                            Amount_Points__c, Amount_Currency__c, Type__c, SubType__c
                        FROM
                            Transactions__r
                    )
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
                visit.appointmentDate = visitRecord.Appointment__r.Datetime__c.format('E, d MMM ‘YY', visitRecord.Appointment__r.Schedule__r.Center__r.Center_Timezone__c);
                visit.appointmentTime = visitRecord.Appointment__r.Datetime__c.format('h:mm a', visitRecord.Appointment__r.Schedule__r.Center__r.Center_Timezone__c);
                visit.centerName = visitRecord.Appointment__r.Schedule__r.Center__r.Name;
                visit.centerAddress = visitRecord.Appointment__r.Schedule__r.Center__r.BillingStreet;
                visit.status = visitRecord.Status__c;
                visit.outcome = visitRecord.Outcome__c;
                visit.firstVisitCode = visitRecord.Donor__r.Account.First_Visit_Code__c;
                visit.isFirstVisit = visitRecord.isFirstVisit__c;

                Decimal totalPointReward = 0;
                Decimal totalCurrencyReward = 0;

                for (Transaction__c transactionRecord : visitRecord.Transactions__r) {
                    if (transactionRecord.Amount_Points__c != null && transactionRecord.Type__c == 'Credit' && transactionRecord.SubType__c != 'Point Redemption') {
                        totalPointReward += transactionRecord.Amount_Points__c;
                    }

                    if (transactionRecord.Amount_Currency__c != null && transactionRecord.Type__c == 'Debit') {
                        totalCurrencyReward += transactionRecord.Amount_Currency__c;
                    }
                }

                visit.totalPointReward = totalPointReward;
                visit.totalCurrencyReward = totalCurrencyReward;
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

        @AuraEnabled 
        public Boolean isValid {get; set;}

        @AuraEnabled 
        public String validationError {get; set;}
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

        @AuraEnabled 
        public Decimal totalCurrencyReward { get; set; }

        @AuraEnabled
        public Decimal totalPointReward { get; set; }
    }

}
