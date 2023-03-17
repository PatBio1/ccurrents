/**
 * Created by joshlequire1 on 3/13/23.
 */

public class BroadcastActionInvocableVariable {

    // Request and Configuration Variables
    @AuraEnabled @InvocableVariable
    public String MessageType;

    @AuraEnabled @InvocableVariable
    public Datetime ClosureStartDatetime;

    @AuraEnabled @InvocableVariable
    public Datetime ReopenDatetime;

    @AuraEnabled @InvocableVariable
    public String Audience;

    @AuraEnabled @InvocableVariable
    public Date DonorScheduleStart;

    @AuraEnabled @InvocableVariable
    public Date DonorScheduleEnd;

    @AuraEnabled @InvocableVariable
    public String MessageContent;

    @AuraEnabled @InvocableVariable
    public Date MessageExpirationDate;

    @AuraEnabled @InvocableVariable
    public Id CenterAccountId;

    @AuraEnabled @InvocableVariable
    public User flowUser;

    @AuraEnabled@InvocableVariable
    public Datetime ScheduledSendDateTime;

}