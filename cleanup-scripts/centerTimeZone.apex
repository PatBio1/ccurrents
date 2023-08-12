List<Appointment__c> appointments = [
    SELECT
        Datetime__c, Schedule__r.Center__r.Center_Timezone__c
    FROM
        Appointment__c
    WHERE
        Datetime__c != null
    AND
        (Date_Center__c = null OR Time_Center__c = null)
    LIMIT
        100
];

if (appointments.size() > 0) {
    for (Appointment__c appointment : appointments) {
        appointment.Date_Center__c = Util.getTimeZoneDate(appointment.Datetime__c, appointment.Schedule__r.Center__r.Center_Timezone__c);
        appointment.Time_Center__c = Util.getTimeZoneTime(appointment.Datetime__c, appointment.Schedule__r.Center__r.Center_Timezone__c);
    }

    update appointments;
}