public class VisitDatetimeComparer implements Comparable {
    public Visit__c visitRecord;

    public VisitDatetimeComparer(Visit__c visitRecord) {
        this.visitRecord = visitRecord;
    }

    public Integer compareTo(Object compareTo) {
        VisitDatetimeComparer compareToVisit = (VisitDatetimeComparer)compareTo;

        if (visitRecord.Appointment_Datetime__c < compareToVisit.visitRecord.Appointment_Datetime__c) {
            return -1;
        }

        if (visitRecord.Appointment_Datetime__c > compareToVisit.visitRecord.Appointment_Datetime__c) {
            return 1;
        }
        
        return 0;
    }
}