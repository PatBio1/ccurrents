public with sharing class CenterScheduleController {
    
    @AuraEnabled
    public static Center[] getCenters(){
        Center[] centers = new Center[]{};
        try {

            for( Account a: [
                Select Id, Name 
                FROM Account 
                WHERE RecordType.DeveloperName = 'Center'
            ]){
                centers.add(new Center(a));
            }
            return centers;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static AppointmentSlot[] getAppointments(Id centerId, Date appointmentDay){
        Appointment__c[] appointments = new Appointment__c[]{};
        Set<Id> appointmentIds = new Set<Id>{};
        Map<Id, AppointmentSlot> appMap = new Map<Id, AppointmentSlot>{};
        try {
            for(Appointment__c app: [
                SELECT  Id,
                        Name,
                        Datetime__c
                FROM Appointment__c
                WHERE Schedule__r.Center__c =: centerId
                AND Datetime__c >: appointmentDay
                AND Datetime__c <: appointmentDay + 1

            ]){
                appMap.put(app.id,new AppointmentSlot(app));
            }

            for(Visit__c visit : [
                SELECT Id,
                        Name,
                        Appointment__c,
                        Donor__c,
                        Donor__r.Name,
                        Donor__r.FirstName,
                        Donor__r.LastName,
                        Donor__r.Email
                FROM Visit__c
                WHERE Appointment__c in: appMap.keyset()
            ]){
                appMap.get(visit.Appointment__c).visits.add(new Visit(visit));
            }
            
            system.debug(appMap);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return  appMap.values();
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
        public Datetime appointmentTime {get; set;}

        @AuraEnabled
        public Visit[] visits {get;set;}

        public AppointmentSlot(Appointment__c app){
            this.Id = app.Id;
            this.appointmentTime = app.Datetime__c;
            this.visits = new Visit[]{};
        }

    }

    public class Visit {
        @AuraEnabled
        public Id visitId {get; set;}

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

        public Visit(Visit__c visit){
            this.visitId = visit.Id;
            this.donorId = visit.Donor__c;
            this.donorName = visit.Donor__r.name;
            this.firstName = visit.Donor__r.firstName;
            this.lastName = visit.Donor__r.lastName;
            this.initials = visit.Donor__r.firstName.subString(0,1) + visit.Donor__r.lastName.subString(0,1);
        }
    }
}