public with sharing class ScheduleUtil {

    /*
     * ScheduleUtil.createAppoinments('a00Dn000003cxLU', DateTime.newInstance(2023, 1, 3, 6, 0, 0), DateTime.newInstance(2023, 1, 3, 21, 0, 0), 10, 5);
     */
    public static void createAppoinments(Id scheduleId, DateTime startTime, DateTime endTime, Integer duration, Integer capacity) {
        List<Appointment__c> appointments = new List<Appointment__c>();

        DateTime appointmentTime = DateTime.newInstance(startTime.date(), startTime.time());

        while (appointmentTime <= endTime) {
            Appointment__c appointment = new Appointment__c();
            appointment.Schedule__c = scheduleId;
            appointment.Datetime__c = appointmentTime;
            appointment.Duration__c = duration;
            appointment.Capacity__c = capacity;
            appointments.add(appointment);

            appointmentTime = appointmentTime.addMinutes(duration);
        }

        insert appointments;
    }

}