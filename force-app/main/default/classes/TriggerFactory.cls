/**
 * Recreated by Josh LeQuire on 2023-02-28, adapted from previous libraries.
 * This factory creates the correct handler and dispatches the trigger event(s) to the appropriate
 * event handler(s). The handlers are automatically created using the Type API, hence handler
 * registration is not required for each handler.
 */

public with sharing class TriggerFactory {

    /**===BEGIN trigger factory===**/
    /**
    * @description Creates a trigger handler from either the object type or the class passed from the trigger.
    */
    public static void createHandler(Schema.SObjectType soType) {
        TriggerFactoryInterface handler = getTriggerHandler(soType);

        dispatchHandler(soType, handler);
    }

    /**
    * @description Creates the appropriate handler and dispatches the trigger event to the handler's event handler method.
    * @param Schema.sObjectType Object type to process (SObject.sObjectType)
    */
	public static void dispatchHandler(Schema.SObjectType soType, TriggerFactoryInterface handler) {
		String soTypeName = soType.getDescribe().getName();

		if(killSwitchEnabled) {
			System.debug('bypassing Trigger Handler for ' + soTypeName + ' because of KillSwitch...');
			return;
		}

		if (String.isNotBlank(killList)) {
			try {
				Set<String> deactivatedObjects = new Set<String>(killList.split('\n'));
				Set<String> deactivatedObjectsNoWhitespace = new Set<String>();
				for (String s : deactivatedObjects) {
					deactivatedObjectsNoWhitespace.add(s.deleteWhitespace());
				}
				if(deactivatedObjectsNoWhitespace.contains(soTypeName)) {
					System.debug('bypassing Trigger Handler for ' + soTypeName + ' because of KillList...');
					return;
				}
			}
			catch(Exception ex) {
				System.debug('TriggerFactory.dispatchHandler Error: (' + ex.getLineNumber() +  ') - ' + ex.getMessage() + ': ' + ex.getStackTraceString());
			}
		}

		if(String.isNotBlank(userKillList)) {
			try {
				Set<String> deactivatedUserIds = new Set<String>(userKillList.split('\n'));
				String curUserId = String.valueOf(UserInfo.getUserId());

				if(deactivatedUserIds.contains(curUserId)) {
					System.debug('bypassing Trigger Handler for ' + soTypeName + ' because of UserKillList...');
					return;
				}
			}
			catch(Exception ex) {
				System.debug('TriggerFactory.dispatchHandler Error: (' + ex.getLineNumber() +  ') - ' + ex.getMessage() + ': ' + ex.getStackTraceString());
			}
		}

		//nothing killed it, process handler!
		try {
			if (handler == null) throw new TriggerFactoryException('No Trigger handler registered for Object Type: ' + soType);
			execute(handler, soTypeName);
			// Final Pop from Diagnostic Log
			pop();
		} catch (Exception ex) {
			debugException(ex);
			popAll();
			//GG: should always throw exception.
			throw ex;
		}
	}
    /**
    * @description Dispatches to the handler's event handlers.
    * @param ITriggerhandler A Trigger handler that dispatches to the appropriate handlers
    */
    @TestVisible
    private static Parameters testContext; //used to set trigger context variables in test methods.

    private static void execute(TriggerFactoryInterface handler, String soTypeName) {
        Parameters tp;
        if (Trigger.isExecuting) {
            tp = new Parameters(
                    Trigger.old, Trigger.new, Trigger.oldMap, Trigger.newMap, Trigger.isBefore, Trigger.isAfter,
                    Trigger.isDelete, Trigger.isInsert, Trigger.isUpdate, Trigger.isUndelete, Trigger.isExecuting);
        }
        //GG: should only be called from trigger framework tests.
        else {
            System.assert(testContext != null, 'trigger parameters must be specified in test framework tests.');
            tp = testContext;
        }

        String context = tp.tEvent.name();
        push(context + ' Trigger for ' + soTypeName + ' Object');

        // Handle before trigger events
        if (tp.tEvent.name().startsWith('before')) {
            push(soTypeName + 'Triggerhandler.bulkBefore');
            handler.bulkBefore();
            pop();
        }
        // Handle after trigger events
        else {
            push(soTypeName + 'Triggerhandler.bulkAfter');
            handler.bulkAfter();
            pop();
        }

        handler.execute(tp, context);
    }

    /**
    * @description Gets the appropriate handler based on the SObject. It constructs the instance of the handler
    *               dynamically using the Type API. The name of the handler has to follow this format:
    *               <ObjectName>Triggerhandler. For e.g. for the Account object, the handler has to be named
    *               as AccountTriggerhandler. For the custom object Custom__c, the name should be CustomTriggerhandler.
    * @param Schema.sObjectType Object type to create the handler
    * @return TriggerFactoryInterface A trigger handler if one exists, otherwise null.
    */
    private static TriggerFactoryInterface getTriggerHandler(Schema.SObjectType soType) {
        String originalTypeName = soType.getDescribe().getName();
        String handlerTypeName = null;
        String handlerName;

        if (originalTypeName.toLowerCase().endsWith('__c')) {
            Integer index = originalTypeName.toLowerCase().indexOf('__c');
            handlerName = originalTypeName.substring(0, index);
        } else {
            handlerName = originalTypeName;
        }

        if (handlerName.length() > 23) {
            handlerName = handlerName.substring(0, 23);
        }

        handlerTypeName = 'TCIO_' + handlerName + 'TriggerHandler';

        Type obType = Type.forName(handlerTypeName);

        TriggerFactoryInterface handler = (obType == null) ? null : (TriggerFactoryInterface) obType.newInstance();

        return handler;
    }

    /**===END trigger factory===**/

    /**===BEGIN Parameters===**/
    /**
    * @description This class holds the trigger parameters.
    */
    public Enum TriggerEvent {
        beforeInsert, beforeUpdate, beforeDelete, afterInsert, afterUpdate, afterDelete, afterUndelete
    }

    public class Parameters {

        @TestVisible public List<SObject> oldList { get; private set; }
        @TestVisible public List<SObject> newList { get; private set; }
        @TestVisible public Map<Id, SObject> oldMap { get; private set; }
        @TestVisible public Map<Id, SObject> newMap { get; private set; }
        @TestVisible public String triggerObject { get; private set; }
        @TestVisible public Boolean isExecuting { get; private set; }

        public TriggerEvent tEvent;

        /**
        * @date 11/9/2014
        * @description Constructs the TriggerParameter object.
        * @param List<SObject> A list of records with the state of 'before' event.
        * @param List<SObject> A list of records with the state of 'after' event.
        * @param Map<Id, SObject> A map of records with the state of 'before' event.
        * @param Map<Id, SObject> A map of records with the state of 'after' event.
        * @param Boolean A flag to indicate 'isBefore' event.
        * @param Boolean A flag to indicate 'isAfter' event.
        * @param Boolean A flag to indicate 'isDelete' event.
        * @param Boolean A flag to indicate 'isInsert' event.
        * @param Boolean A flag to indicate 'isUpdate' event.
        * @param Boolean A flag to indicate 'isUnDelete' event.
        * @param Boolean A flag to indicate 'isExecuting'.
        */
        public Parameters(List<SObject> oldList, List<SObject> newList, Map<Id, SObject> oldMap, Map<Id, SObject> newMap,
                Boolean isBefore, Boolean isAfter, Boolean isDelete, Boolean isInert, Boolean isUpdate, Boolean isUndelete, Boolean isExecuting) {

            this.oldList = oldList;
            this.newList = newList;
            this.oldMap = oldMap;
            this.newMap = newMap;

            this.triggerObject = ((this.oldList != null && this.oldList.size() > 0) ? this.oldList[0] : this.newList[0]).getSObjectType().getDescribe().getName();

            if (isBefore) {
                if (isInert) {
                    tEvent = TriggerEvent.beforeInsert;
                } else if (isUpdate) {
                    tEvent = TriggerEvent.beforeUpdate;
                } else if (isDelete) {
                    tEvent = TriggerEvent.beforeDelete;
                }
            } else if (isAfter) {
                if (isInert) {
                    tEvent = TriggerEvent.afterInsert;
                } else if (isUpdate) {
                    tEvent = TriggerEvent.afterUpdate;
                } else if (isDelete) {
                    tEvent = TriggerEvent.afterDelete;
                } else if (isUndelete) {
                    tEvent = TriggerEvent.afterUndelete;
                }
            }
            this.isExecuting = isExecuting;
        }
    }
    /**===END Parameters===**/


    /**===BEGIN TRIGGER SETTINGS SUPPORT===**/

    /**
    * @description Called to lazy load config options for the execution context via the TriggerFactory_Settings custom setting.
    */
    @TestVisible
    public static TriggerFactorySettings__c getConfiguration() {

        TriggerFactorySettings__c orgDefaults = TriggerFactorySettings__c.getOrgDefaults();

        if (orgDefaults == null) {
            orgDefaults = new TriggerFactorySettings__c();
        }

        if (orgDefaults.Id == null) {
            orgDefaults.EnableDiagnostics__c = false;
            orgDefaults.KillSwitch__c = false;
            orgDefaults.KillList__c = '';
            orgDefaults.EmailDebugInfoLog__c = false;
            orgDefaults.DebugInfoRecipientEmails__c = '';
        }

        Boolean missingDefaults = false;
        if (orgDefaults.MaxDebugInfoRecords__c == null) {
            orgDefaults.MaxDebugInfoRecords__c = 100;
            missingDefaults = true;
        }

        if (orgDefaults.MaxDebugInfoAge__c == null) {
            orgDefaults.MaxDebugInfoAge__c = 365; //store for a maximum of 365 days.
            missingDefaults = true;
        }

        if (orgDefaults.Id == null) {
            Database.insert(orgDefaults);
        } else if (missingDefaults) {
            Database.update(orgDefaults);
        }

        return TriggerFactorySettings__c.getInstance();
    }

    public static Boolean diagnosticsEnabled {
        get {
            return getConfiguration().EnableDiagnostics__c;
        }
    }

    public static Boolean killSwitchEnabled {
        get {
            return getConfiguration().KillSwitch__c;
        }
    }

    public static String killList {
        get {
            return getConfiguration().KillList__c;
        }
    }

    public static String userKillList{
        get {
            return getConfiguration().UserKillList__c;
        }
    }

    public static Boolean emailDebugInfoEnabled {
        get {
            return getConfiguration().EmailDebugInfoLog__c;
        }
    }

    public static String debugInfoEmailRecipients {
        get {
            return getConfiguration().DebugInfoRecipientEmails__c;
        }
    }

    public static Integer debugInfoMaxNum {
        get {
            return (Integer) getConfiguration().MaxDebugInfoRecords__c;
        }
    }

    public static Integer debugInfoMaxAge {
        get {
            return (Integer) getConfiguration().MaxDebugInfoAge__c;
        }
    }
    /**===END TRIGGER SETTINGS SUPPORT===**/


    /**===BEGIN TriggerFactory_DiagnosticsInstrumentation===**/
    /**
    * @description This class implements diagnostics for the application
    */

    private static List<DiagnosticEntry> diagnosticLog;
    private static Integer currentLevel = 0;
    private static List<String> stackTrace = new List<String>();

    private class DiagnosticEntry {
        Integer level;
        String description;

        private DiagnosticEntry(String entryDescription) {
            level = currentLevel;

            description = '[' + System.now().format('HH:mm:ss.SSS') + '] {' + UserInfo.getName() + '} ' + entryDescription;
        }
    }

    /**
    * @description Should be called at the start of every function to increment and update the current execution context level.
    */
    public static void push(String functionName) {
        debug(functionName);
        currentLevel += 1;

        stackTrace.add(functionName);
    }

    /**
    * @description Adds new diagnostic entry to the diagnostic log (if diagnostics are enabled)
    */
    private static void debug(String debugString) {
        if (!diagnosticsEnabled && !emailDebugInfoEnabled) {
            return;
        }

        if (diagnosticLog == null) {
            diagnosticLog = new List<DiagnosticEntry>();
        }

        diagnosticLog.add(new DiagnosticEntry(debugString));
    }

    /**
    * @description Called prior to PopAll to add exception info to diagnostic log and object
    */
    private static void debugException(Exception ex) {
        if (!diagnosticsEnabled && !emailDebugInfoEnabled) {
            return;
        }

        String exceptionTrace = ' Exception occurred line ' + ex.getLineNumber() + ' - ' + ex.getMessage();
        String exceptionInfo = exceptionTrace + ' stack: ' + ex.getStackTraceString();

        debug(exceptionInfo);

        TriggerDebugInfo__c dbg = new TriggerDebugInfo__c(DebugData__c = currentLog());
        for (String st : stackTrace) {
            exceptionTrace += ' | ' + st;
        }
        exceptionTrace += ' |\n ';

        if (diagnosticsEnabled) {
            insert dbg;

            if (debugInfoMaxNum != null || debugInfoMaxAge != null) {
                checkDebugInfoLog();
            }
        }
        if (emailDebugInfoEnabled && debugInfoEmailRecipients != null && debugInfoEmailRecipients != '') {
            emailDebugInfoLog(new List<TriggerDebugInfo__c>{
                    dbg
            }, 'The following exception occurred, see attached CSV:\n' + dbg.DebugData__c);
        }
    }

    /**
    * @description Should be called on the exit of every function to decrement and update the current execution context level.
    */
    public static void pop() {
        if (currentLevel > 0) {
            currentLevel -= 1;
        }

        if (currentLevel == 0 && diagnosticsEnabled) {
            System.debug(LoggingLevel.INFO, 'Diagnostic Log\n' + currentLog());
        }

        if (stackTrace.size() > 0) {
            stackTrace.remove(stackTrace.size() - 1);
        }
    }

    /**
    * @description Used for exception handling
    */
    private static void popAll() {
        currentLevel = 0;

        pop();
    }

    /**
    * @description Returns multi-line string representation of diagnostic log
    */
    @TestVisible
    private static String currentLog() {
        if (diagnosticLog == null) {
            return null;
        }

        String spaces = '                                                                        ';

        String result = '';
        for (DiagnosticEntry de : diagnosticLog) {
            Integer endindex = 3 * de.level;

            if (endindex >= spaces.length()) {
                endindex = spaces.length() - 1;
            }

            result += spaces.substring(0, endindex) + de.description + '\n';
        }

        return result;
    }

    /**
    * @description Checks if DebugInfo log needs clearing
    */
    @TestVisible
    private static void checkDebugInfoLog() {
        List<TriggerDebugInfo__c> debugInfoLog = [
                SELECT
                        Id,
                        CreatedDate,
                        Name,
                        DebugData__c
                FROM TriggerDebugInfo__c
                ORDER BY CreatedDate ASC
                limit 100
        ];

        if (!debugInfoLog.isEmpty() && debugInfoMaxNum != null && debugInfoLog.size() >= debugInfoMaxNum) {
            clearDebugInfoLog(debugInfoLog);
        }

        //TODO: update this to use the new ability to set CreatedDate in tests and take out Test.isRunningTest().
        if (!debugInfoLog.isEmpty() && debugInfoMaxAge != null && (debugInfoLog[0].CreatedDate <= System.now().addDays(-1 * debugInfoMaxAge))) {
            List<TriggerDebugInfo__c> debugInfoToDelete = new List<TriggerDebugInfo__c>();

            Datetime maxAge = System.now().addDays(-1 * debugInfoMaxAge);

            for (TriggerDebugInfo__c di : debugInfoLog) {
                if (di.CreatedDate <= maxAge) {
                    debugInfoToDelete.add(di);
                }
            }
            clearDebugInfoLog(debugInfoToDelete);
        }
    }

    /**
    * @description Deletes DebugInfo log records
    * @param List<TriggerDebugInfo__c> List of debug info records to be deleted
    */
    private static void clearDebugInfoLog(List<TriggerDebugInfo__c> expiredDebugInfoLog) {
        if (emailDebugInfoEnabled && debugInfoEmailRecipients != null && debugInfoEmailRecipients != '') {
            emailDebugInfoLog(expiredDebugInfoLog);
        }

        delete expiredDebugInfoLog;
    }

    private static void emailDebugInfoLog(List<TriggerDebugInfo__c> debugInfoLog) {
        emailDebugInfoLog(debugInfoLog, 'Attached is the DebugInfo log that was cleared for ' + UserInfo.getOrganizationName() + '(' + UserInfo.getOrganizationId() + ')');
    }


    private static Boolean getCanSendEmails() {
        // An attempt to reserve some email capacity is the only means available for determining permissions
        // or limits issues. In the case of a lack of permissions, System.NoAccessException is thrown. If
        // limits are exhausted then System.HandledException is thrown
        try {
            Messaging.reserveSingleEmailCapacity(1);
        } catch (Exception e) {
            return false;
        }
        return true;
    }

    /**
    * @description Emails DebugInfo log
    * @param List<TriggerDebugInfo__c> List of debug info records to be emailed
    */
    private static void emailDebugInfoLog(List<TriggerDebugInfo__c> debugInfoLog, String emailMessage) {
        //Define email settings
        Messaging.SingleEmailMessage debugInfoEmail = new Messaging.SingleEmailMessage();
        debugInfoEmail.setToAddresses(debugInfoEmailRecipients.split(';'));
        debugInfoEmail.setSubject('DebugInfo Log for ' + UserInfo.getOrganizationName() + '(' + UserInfo.getOrganizationId() + ')');
        debugInfoEmail.setPlainTextBody(emailMessage);
        debugInfoEmail.setHtmlBody(emailMessage);

        //Generate attachment
        String csvString = new DebugInfoLogAttachment().generate(debugInfoLog);

        transient Blob csvAttachment = Blob.valueOf(csvString);

        transient Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setBody(csvAttachment);
        efa.setContentType('text/csv');
        efa.setFileName(System.today().format() + '_' + UserInfo.getOrganizationName() + '_DebugInfoLog.csv');
        efa.setInline(false);

        debugInfoEmail.setFileAttachments(new List<Messaging.EmailFileAttachment>{
                efa
        });

        //Send email
        if (getCanSendEmails()) {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{
                    debugInfoEmail
            });
        }

    }

    private class DebugInfoLogAttachment {

        private String generate(List<TriggerDebugInfo__c> diLog) {
            String s = line(new List<String>{
                    format('DebugInfo Entry'),
                    format('Created Date'),
                    format('Debug Data')
            });

            for (TriggerDebugInfo__c di : diLog) {
                s += line(new List<String>{
                        format(di.Name),
                        format(di.CreatedDate),
                        format(di.DebugData__c)
                });
            }
            return s;
        }

        private String line(List<String> cells) {
            return String.join(cells, ',') + '\n';
        }

        private String format(Datetime dt) {
            return dt != null ? '"' + dt.format().escapeCsv() + '"' : '""';
        }

        private String format(String s) {
            return s != null ? '"' + s.escapeCsv() + '"' : '""';
        }
    }
    /**===END TriggerFactory_DiagnosticsInstrumentation===**/


    /**===BEGIN base trigger handler===**/
    /**
    * @description This class implements the ITriggerDispatcher and acts as an adapter to avoid implementing all the
    *				ITriggerDispatcher methods.
    */
    private static Map<String, Boolean> isProcessing = new Map<String, Boolean>();

    public abstract class BaseHandler implements TriggerFactoryInterface {
        /**
        * @description This method is called prior to execution of a before trigger event. If you want
        *				to load any lookup data or cache the data, then this is the place that you need
        *				to put your code.
        */
        public virtual void bulkBefore() {
        }

        /**
        * @description This method is called prior to execution of an after trigger event.
        */
        public virtual void bulkAfter() {
        }

        /**
        * @description These methods correspond to each of the various DML operations.
        * NOTE: Make sure to override all methods for DML operations trigger is running on.
        */
        public virtual void beforeInsert(List<SObject> newList) {
            System.assert(false, unimplementedDMLMessage('beforeInsert'));
        }
        public virtual void afterInsert(Map<Id, SObject> newMap) {
            System.assert(false, unimplementedDMLMessage('afterInsert'));
        }
        public virtual void beforeDelete(Map<Id, SObject> oldMap) {
            System.assert(false, unimplementedDMLMessage('beforeDelete'));
        }
        public virtual void afterDelete(Map<Id, SObject> oldMap) {
            System.assert(false, unimplementedDMLMessage('afterDelete'));
        }
        public virtual void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
            System.assert(false, unimplementedDMLMessage('afterUpdate'));
        }
        public virtual void beforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
            System.assert(false, unimplementedDMLMessage('beforeUpdate'));
        }
        public virtual void afterUndelete(Map<Id, SObject> newMap) {
            System.assert(false, unimplementedDMLMessage('afterUndelete'));
        }

        /**
        * @description optional. Allows you to define custom handlers if DML operation is being run recursively.
        */
        public virtual void beforeInsertRecursive(List<SObject> newList) {
            beforeInsert(newList);
        }
        public virtual void afterInsertRecursive(Map<Id, SObject> newMap) {
            afterInsert(newMap);
        }
        public virtual void beforeUpdateRecursive(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
            beforeUpdate(oldMap, newMap);
        }
        public virtual void afterUpdateRecursive(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
            afterUpdate(oldMap, newMap);
        }
        public virtual void beforeDeleteRecursive(Map<Id, SObject> oldMap) {
            beforeDelete(oldMap);
        }
        public virtual void afterDeleteRecursive(Map<Id, SObject> oldMap) {
            afterDelete (oldMap);
        }
        public virtual void afterUndeleteRecursive(Map<Id, SObject> newMap) {
            afterUndelete (newMap);
        }

        /**
        * @description Called by the event handlers. If this is the first call in the context, then this method will create a new
        *				instance of the appropriate handler and execute the mainEntry method. If there is an existing call runing
        *				on the same context, then this method will use the existing handler instance created by the original call
        *				and execute the inProgressEntry method.
        * @param TriggerFactoryInterface The trigger handler instance. The dispatcher need to pass an instance of the trigger handler, such
        *							as AccountAfterInsertTriggerHandler if this is the first call in a given context. If it is retry,
        *							then the dispatcher will need to pass null.
        * @param TriggerFactory_Parameters The trigger parameters passed by the framework.
        * @param TriggerFactory_Parameters.TriggerEvent The trigger event.
        */
        public void execute(TriggerFactory.Parameters tp, String context) {
            Boolean inProgress = isProcessing.get(tp.triggerObject + context);

            // Standard Entry
            if (inProgress != true) {
                isProcessing.put(tp.triggerObject + context, true);

                TriggerFactory.Push(tp.triggerObject + 'TriggerDispatcher.' + context);
                if (context == 'beforeInsert') {
                    beforeInsert(tp.newList);
                } else if (context == 'beforeUpdate') {
                    beforeUpdate(tp.oldMap, tp.newMap);
                } else if (context == 'beforeDelete') {
                    beforeDelete(tp.oldMap);
                } else if (context == 'afterInsert') {
                    afterInsert(tp.newMap);
                } else if (context == 'afterUpdate') {
                    afterUpdate(tp.oldMap, tp.newMap);
                } else if (context == 'afterDelete') {
                    afterDelete(tp.oldMap);
                } else if (context == 'afterUndelete') {
                    afterUndelete(tp.newMap);
                }

                TriggerFactory.pop();
                isProcessing.put(tp.triggerObject + context, false);
            } else {
                // Recursive Entry
                TriggerFactory.push(tp.triggerObject + 'TriggerDispatcher.' + context + 'Recursion');

                if (context == 'beforeInsert') {
                    beforeInsertRecursive(tp.newList);
                } else if (context == 'beforeUpdate') {
                    beforeUpdateRecursive(tp.oldMap, tp.newMap);
                } else if (context == 'beforeDelete') {
                    beforeDeleteRecursive(tp.oldMap);
                } else if (context == 'afterInsert') {
                    afterInsertRecursive(tp.newMap);
                } else if (context == 'afterUpdate') {
                    afterUpdateRecursive(tp.oldMap, tp.newMap);
                } else if (context == 'afterDelete') {
                    afterDeleteRecursive(tp.oldMap);
                } else if (context == 'afterUndelete') {
                    afterUndeleteRecursive(tp.newMap);
                }
                TriggerFactory.pop();
            }
        }

        private String unimplementedDMLMessage(String dmlOperation) {
            return String.format('This trigger runs on {0} but the trigger handler has not implemented {0} method.', new List<String>{
                    dmlOperation
            });
        }
    }
    /**===END base trigger handler===**/

    public class TriggerFactoryException extends Exception {
    }

}