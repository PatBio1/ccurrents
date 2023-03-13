trigger ErrorEventTrigger on ErrorEvent__e (after insert) {
    System.debug('Error Event Trigger Fired');
    ErrorLogService.writeErrorEvent(Trigger.new);
}