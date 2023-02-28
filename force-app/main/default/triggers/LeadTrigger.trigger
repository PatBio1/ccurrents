/**
 * Created by joshlequire1 on 2/28/23.
 */

trigger LeadTrigger on Lead (after update) {
    TriggerFactory.dispatchHandler(Lead.SObjectType, new LeadTriggerHandler());
}