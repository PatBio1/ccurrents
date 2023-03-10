public without sharing class ErrorLogService {

    public static ErrorLog__c createErrorLog(String recordId, String origin, String type, String shortMessage, String longMessage) {
        ErrorLog__c errorLog = new ErrorLog__c();

        errorLog.RecordId__c = recordId;
        errorLog.ErrorDate__c = Datetime.now();
        errorLog.Origin__c = origin;
        errorLog.ShortMessage__c = (shortMessage.length() > 3000) ? shortMessage.substring(0, 3000) : shortMessage;
        errorLog.LongMessage__c = (longMessage.length() > 32700) ? longMessage.substring(0, 32700) : longMessage;
        errorLog.Type__c = type;

        return errorLog;
    }

    public static ErrorLog__c createErrorLogFromException(String recordId, String origin, String type, Exception e) {
        ErrorLog__c errorLog = new ErrorLog__c();

        errorLog.RecordId__c = recordId;
        errorLog.ErrorDate__c = Datetime.now();
        errorLog.Origin__c = origin;
        errorLog.ShortMessage__c = (e.getMessage().length() > 3000) ? e.getMessage().substring(0, 3000) : e.getMessage();
        errorLog.LongMessage__c = (e.getStackTraceString().length() > 32700) ? e.getStackTraceString().substring(0, 32700) : e.getStackTraceString();
        errorLog.Type__c = type;

        return errorLog;
    }


    public static void logError(String recordId, String origin, String shortMessage, String longMessage, String additionalInfo) {
        ErrorEvent__e errorEvent = new ErrorEvent__e();
        errorEvent.RecordId__c = recordId;
        errorEvent.Origin__c = origin;
        errorEvent.ShortMessage__c = (shortMessage.length() > 3000) ? shortMessage.substring(0, 3000) : shortMessage;
        errorEvent.LongMessage__c = (longMessage.length() > 32700) ? longMessage.substring(0, 32700) : longMessage;
        errorEvent.Type__c = CONSTANTS.ERRORLOG_TYPE_ERROR;
        errorEvent.AdditionalInfo__c = additionalInfo;
        publishError(errorEvent);
    }

    public static void logErrorFromException(String recordId, String origin, Exception e, String additionalInfo) {
        ErrorEvent__e errorEvent = new ErrorEvent__e();
        errorEvent.RecordId__c = recordId;
        errorEvent.Origin__c = origin;
        errorEvent.ShortMessage__c = (e.getMessage().length() > 3000) ? e.getMessage().substring(0, 3000) : e.getMessage();
        errorEvent.LongMessage__c = (e.getStackTraceString().length() > 32700) ? e.getStackTraceString().substring(0, 32700) : e.getStackTraceString();
        errorEvent.Type__c = CONSTANTS.ERRORLOG_TYPE_ERROR;
        errorEvent.AdditionalInfo__c = additionalInfo;
        publishError(errorEvent);
    }

    private static void publishError(ErrorEvent__e ee) {
        EventBus.publish(ee);
    }

    private static ErrorLog__c createErrorLogFromErrorEvent(ErrorEvent__e ee) {
        ErrorLog__c errorLog = new ErrorLog__c();

        errorLog.RecordId__c = ee.RecordId__c;
        errorLog.ErrorDate__c = Datetime.now();
        errorLog.Origin__c = ee.Origin__c;
        errorLog.ShortMessage__c = ee.ShortMessage__c;
        errorLog.LongMessage__c = ee.LongMessage__c;
        errorLog.Type__c = ee.Type__c;
        errorLog.AdditionalInfo__c = ee.AdditionalInfo__c;
        return errorLog;
    }

    public static void writeErrorEvent(List<ErrorEvent__e> errorEvents) {
        List<ErrorLog__c> errorLogs = new List<ErrorLog__c>();
        for (ErrorEvent__e ee : errorEvents) {
            errorLogs.add(createErrorLogFromErrorEvent(ee));
        }
        insert errorLogs;
    }
}