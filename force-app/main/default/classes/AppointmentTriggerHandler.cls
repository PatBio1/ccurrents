public without sharing class AppointmentTriggerHandler extends TriggerFactory.BaseHandler {

    public override void beforeInsert(List<SObject> newList) {
        setCenterDateAndTime((List<Appointment__c>) newList, new Map<Id, Appointment__c>());
    }

    public override void beforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        setCenterDateAndTime((List<Appointment__c>) newMap.values(), (Map<Id, Appointment__c>) oldMap);
    }

    private static void setCenterDateAndTime(List<Appointment__c> appointments, Map<Id, Appointment__c> oldAppointments) {
        List<Appointment__c> appointmentsToProcess = new List<Appointment__c>();
        Set<Id> scheduleIds = new Set<Id>();

        for (Appointment__c appointment : appointments) {
            if (!oldAppointments.containsKey(appointment.Id) || appointment.Datetime__c != oldAppointments.get(appointment.Id).Datetime__c) {
                appointmentsToProcess.add(appointment);
                scheduleIds.add(appointment.Schedule__c);
            }
        }

        if (appointmentsToProcess.size() > 0) {
            Map<Id, Schedule__c> schedules = new Map<Id, Schedule__c>([
                SELECT
                    Center__r.Center_Timezone__c
                FROM
                    Schedule__c
                WHERE
                    Id IN :scheduleIds
            ]);

            for (Appointment__c appointment : appointments) {
                Schedule__c schedule = schedules.get(appointment.Schedule__c);

                appointment.Date_Center__c = Util.getTimeZoneDate(appointment.Datetime__c, schedule.Center__r.Center_Timezone__c);
                appointment.Time_Center__c = Util.getTimeZoneTime(appointment.Datetime__c, schedule.Center__r.Center_Timezone__c);
            }
        }
    }

}