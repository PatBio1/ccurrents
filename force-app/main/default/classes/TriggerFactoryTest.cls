/**
 * Recreated by Josh LeQuire on 2023-02-28.
 */

@IsTest
public with sharing class TriggerFactoryTest {

    private static TriggerFactory.Parameters params;
    private static TriggerFactorySettings__c cs = TriggerFactory.getConfiguration();

    private static void setup() {
        List<Account> triggerOld, triggerNew;
        Map<Id, Account> oldMap, newMap;
        Boolean isBefore, isAfter, isDelete, isInsert, isUpdate, isUndelete, isExecuting = true;

        isBefore = true;
        isInsert = true;
        triggerNew = new List<Account>{
                new Account()
        };

        params = new TriggerFactory.Parameters(triggerOld, triggerNew, oldMap, newMap, isBefore, isAfter, isDelete, isInsert, isUpdate, isUndelete, isExecuting);
        TriggerFactory.testContext = params;

        cs.EnableDiagnostics__c = true;
        insert cs;
        cs = TriggerFactory.getConfiguration();
    }

    /**
    * This method tests the framework using the sample account trigger.
    */
    @IsTest
    public static void testDebugInfoTrigger() {
        TriggerDebugInfo__c testRecord = new TriggerDebugInfo__c();

        insert testRecord;

        System.debug(cs);
        cs.KillList__c = 'Account';
        cs.KillSwitch__c = true;
        insert cs;

        update testRecord;

        cs.KillSwitch__c = false;
        cs.EmailDebugInfoLog__c = true;
        cs.MaxDebugInfoRecords__c = 7;
        cs.DebugInfoRecipientEmails__c = 'test@test.com';
        update cs;
        update testRecord;

        update testRecord;
        delete testRecord;
        undelete testRecord;

        BaseHandler handler = new BaseHandler('beforeInsert');

        String idPrefix = Schema.SObjectType.TriggerDebugInfo__c.getKeyPrefix();
        Map<Id, TriggerDebugInfo__c> mapForTest = new Map<Id, TriggerDebugInfo__c>(new List<TriggerDebugInfo__c>{
                new TriggerDebugInfo__c(Id = idPrefix + '000000000000')
        });

        TriggerFactory.Parameters tp = new TriggerFactory.Parameters(mapForTest.values(), mapForTest.values(), mapForTest, mapForTest,
                true, true, true,
                true, true, true, true);


        handler.execute(tp, 'beforeInsert');
    }

    @IsTest
    public static void testMissingHandler() {
        try {
            //ApexClass used as example of sobject that will not have trigger handler.
            TriggerFactory.createHandler(ApexClass.getSObjectType());
        } catch (TriggerFactory.TriggerFactoryException ex) {
            System.assertEquals('No Trigger handler registered for Object Type: ApexClass', ex.getMessage());
        }
    }


    //verifies that trigger factory calls the correct handler method. asserts are in base handler inner class.
    @IsTest
    public static void testBaseTriggerFlow() {
        setup();

        params.tEvent = TriggerFactory.TriggerEvent.beforeInsert;
        TriggerFactory.dispatchHandler(Account.SObjectType, new BaseHandler('beforeInsert'));

        params.tEvent = TriggerFactory.TriggerEvent.afterInsert;
        TriggerFactory.dispatchHandler(Account.SObjectType, new BaseHandler('afterInsert'));

        params.tEvent = TriggerFactory.TriggerEvent.beforeUpdate;
        TriggerFactory.dispatchHandler(Account.SObjectType, new BaseHandler('beforeUpdate'));

        params.tEvent = TriggerFactory.TriggerEvent.afterUpdate;
        TriggerFactory.dispatchHandler(Account.SObjectType, new BaseHandler('afterUpdate'));

        params.tEvent = TriggerFactory.TriggerEvent.beforeDelete;
        TriggerFactory.dispatchHandler(Account.SObjectType, new BaseHandler('beforeDelete'));

        params.tEvent = TriggerFactory.TriggerEvent.afterDelete;
        TriggerFactory.dispatchHandler(Account.SObjectType, new BaseHandler('afterDelete'));

        params.tEvent = TriggerFactory.TriggerEvent.afterUndelete;
        TriggerFactory.dispatchHandler(Account.SObjectType, new BaseHandler('afterUndelete'));

        List<String> curLog = TriggerFactory.currentLog().split('\n');
        System.assert(curLog[0].endsWith('beforeInsert Trigger for Account Object'));
        System.assert(curLog[1].endsWith('AccountTriggerhandler.bulkBefore'));
        System.assert(curLog[2].endsWith('AccountTriggerDispatcher.beforeInsert'));

        System.assert(curLog[3].endsWith('afterInsert Trigger for Account Object'));
        System.assert(curLog[4].endsWith('AccountTriggerhandler.bulkAfter'));
        System.assert(curLog[5].endsWith('AccountTriggerDispatcher.afterInsert'));

        System.assert(curLog[6].endsWith('beforeUpdate Trigger for Account Object'));
        System.assert(curLog[7].endsWith('AccountTriggerhandler.bulkBefore'));
        System.assert(curLog[8].endsWith('AccountTriggerDispatcher.beforeUpdate'));

        System.assert(curLog[9].endsWith('afterUpdate Trigger for Account Object'));
        System.assert(curLog[10].endsWith('AccountTriggerhandler.bulkAfter'));
        System.assert(curLog[11].endsWith('AccountTriggerDispatcher.afterUpdate'));

        System.assert(curLog[12].endsWith('beforeDelete Trigger for Account Object'));
        System.assert(curLog[13].endsWith('AccountTriggerhandler.bulkBefore'));
        System.assert(curLog[14].endsWith('AccountTriggerDispatcher.beforeDelete'));

        System.assert(curLog[15].endsWith('afterDelete Trigger for Account Object'));
        System.assert(curLog[16].endsWith('AccountTriggerhandler.bulkAfter'));
        System.assert(curLog[17].endsWith('AccountTriggerDispatcher.afterDelete'));

        System.assert(curLog[18].endsWith('afterUndelete Trigger for Account Object'));
        System.assert(curLog[19].endsWith('AccountTriggerhandler.bulkAfter'));
        System.assert(curLog[20].endsWith('AccountTriggerDispatcher.afterUndelete'));
    }

    @IsTest
    public static void testRecursiveTriggerFlow() {
        setup();

        params.tEvent = TriggerFactory.TriggerEvent.afterInsert;
        TriggerFactory.dispatchHandler(Account.SObjectType, new AccountHandler('afterInsert'));


        //another after insert (should not kick off recursion).
        params.tEvent = TriggerFactory.TriggerEvent.afterInsert;
        TriggerFactory.dispatchHandler(Account.SObjectType, new AccountHandler('afterInsert'));

        List<String> curLog = TriggerFactory.currentLog().split('\n');
        System.assert(curLog[0].endsWith('afterInsert Trigger for Account Object'));
        System.assert(curLog[1].endsWith('AccountTriggerhandler.bulkAfter'));
        System.assert(curLog[2].endsWith('AccountTriggerDispatcher.afterInsert'));
        System.assert(curLog[3].endsWith('afterInsert Trigger for Contact Object'));
        System.assert(curLog[4].endsWith('ContactTriggerhandler.bulkAfter'));
        System.assert(curLog[5].endsWith('ContactTriggerDispatcher.afterInsert'));
        System.assert(curLog[6].endsWith('afterInsert Trigger for Account Object'));
        System.assert(curLog[7].endsWith('AccountTriggerhandler.bulkAfter'));
        System.assert(curLog[8].endsWith('AccountTriggerDispatcher.afterInsertRecursion'));
        System.assert(curLog[9].endsWith('afterUpdate Trigger for Account Object'));
        System.assert(curLog[10].endsWith('AccountTriggerhandler.bulkAfter'));
        System.assert(curLog[11].endsWith('AccountTriggerDispatcher.afterUpdate'));
    }

    @IsTest
    public static void testMaxDebugLog() {
        setup();

        cs.EmailDebugInfoLog__c = true;
        cs.DebugInfoRecipientEmails__c = 'test@texample.com';
        update cs;
        cs = TriggerFactory.getConfiguration();

        List<TriggerDebugInfo__c> existingRecords = new List<TriggerDebugInfo__c>();
        for (Integer i = 0; i < 200; i++) {
            existingRecords.add(new TriggerDebugInfo__c());
        }
        insert existingRecords;

        Test.startTest();
        TriggerFactory.checkDebugInfoLog();
        Test.stopTest();

        existingRecords = [SELECT Id FROM TriggerDebugInfo__c];

        System.assertEquals(100, existingRecords.size(), 'Excepted 100 debug entries remaining which is the default maximum.');

        //scenario 3: validate that the email message with deleted debug logs is sent to the appropriate emails based on the custom setting.
    }

    @IsTest
    public static void testOldDebugLog() {
        setup();

        cs.EmailDebugInfoLog__c = true;
        cs.DebugInfoRecipientEmails__c = 'test@texample.com';
        update cs;
        cs = TriggerFactory.getConfiguration();

        TriggerDebugInfo__c di = new TriggerDebugInfo__c();
        insert di;
        Test.setCreatedDate(di.Id, Datetime.newInstance(2016, 01, 01));

        Test.startTest();
        TriggerFactory.checkDebugInfoLog();
        Test.stopTest();

        List<TriggerDebugInfo__c> existingRecords = [SELECT Id FROM TriggerDebugInfo__c];

        System.assert(existingRecords.isEmpty(), 'Debug entries greater than 365 days old should be deleted.');

        //scenario 3: validate that the email message with deleted debug logs is sent to the appropriate emails based on the custom setting.
    }

    @IsTest
    public static void testHandlerWithException() {
        setup();

        cs.EmailDebugInfoLog__c = true;
        cs.DebugInfoRecipientEmails__c = 'test@texample.com';
        update cs;
        cs = TriggerFactory.getConfiguration();


        Test.startTest();
        try {
            params.tEvent = TriggerFactory.TriggerEvent.beforeInsert;
            params.triggerObject = 'Account';
            TriggerFactory.dispatchHandler(Account.SObjectType, new ExceptionHandler());
        } catch (Exception ex) {
            System.assertEquals('Divide by 0', ex.getMessage());
        }
        Test.stopTest();

        List<TriggerDebugInfo__c> existingRecords = [SELECT Id, DebugData__c FROM TriggerDebugInfo__c];
        System.assertEquals(1, existingRecords.size());
        List<String> debugInfo = existingRecords[0].DebugData__c.split('\n');
        System.debug(debugInfo);
        System.assert(debugInfo[0].endsWith('beforeInsert Trigger for Account Object'));
        System.assert(debugInfo[1].endsWith('AccountTriggerhandler.bulkBefore'));
        System.assert(debugInfo[2].endsWith('AccountTriggerDispatcher.beforeInsert'));
        System.assert(debugInfo[3].contains('Divide by 0'));

    }


    /**
     * review uses of Test.IsRunningTest()
     * verify bulkBefore and bulkAfter
     */


    /**
    * This method tests getting the handler names.

    //TODO: implement this test method properly.
    @isTest
    public static void test_getTriggerHandlerName(){
        System.assertEquals('SL_AccountTriggerHandler', SL_Trigger_Factory.getTriggerHandler(Account));
        System.assertEquals('SL_SL_Debug_InfoTriggerHandler', SL_Trigger_Factory.getTriggerHandler(TriggerDebugInfo__c));
        String longName = 'AReallyLongObjectNameGreaterThan23Characters__c';
        String result = 'SL_'+ longName.subString(0, 23)+'TriggerHandler';
        System.assertEquals(result, SL_Trigger_Factory.getTriggerHandler(CollaborationGroupMemberRequest));
    }
    */


    //used to verify execution flow of the trigger framework.
    static Boolean runBulkBefore = false;
    static Boolean runBulkAfter = false;

    public class BaseHandler extends TriggerFactory.BaseHandler {
        private String executing;

        public BaseHandler(String methodToExecute) {
            this.executing = methodToExecute;
        }


        public override void bulkBefore() {
            runBulkBefore = true;
        }

        public override void bulkAfter() {
            runBulkAfter = true;
        }

        public override void beforeInsert(List<SObject> newList) {
            System.assertEquals('beforeInsert', executing);
        }
        public override void afterInsert(Map<Id, SObject> newMap) {
            System.assertEquals('afterInsert', executing);
        }

        public override void beforeDelete(Map<Id, SObject> oldMap) {
            System.assertEquals('beforeDelete', executing);
        }
        public override void afterDelete(Map<Id, SObject> oldMap) {
            System.assertEquals('afterDelete', executing);
        }

        public override void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
            System.assertEquals('afterUpdate', executing);
        }
        public override void beforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
            System.assertEquals('beforeUpdate', executing);
        }

        public override void afterUndelete(Map<Id, SObject> newMap) {
            System.assertEquals('afterUndelete', executing);
        }
    }

    //used to verify recursion logic of the trigger framework
    public class AccountHandler extends TriggerFactory.BaseHandler {
        private String executing;

        public AccountHandler(String methodToExecute) {
            this.executing = methodToExecute;
        }

        public override void afterInsert(Map<Id, SObject> newMap) {
            System.assertEquals('afterInsert', executing);

            //"insert" of Contact. Should NOT go into recursive method as top-level trigger is Account.
            params.tEvent = TriggerFactory.TriggerEvent.afterInsert;
            params.triggerObject = 'Contact';
            TriggerFactory.dispatchHandler(Contact.SObjectType, new BaseHandler('afterInsert'));

            //"insert" of Account. SHOULD go into recursive method.
            params.tEvent = TriggerFactory.TriggerEvent.afterInsert;
            params.triggerObject = 'Account';
            TriggerFactory.dispatchHandler(Account.SObjectType, new AccountHandler('afterInsertRecursive'));

            //"update" of Account. Should not go into Recursive as initiated DML was afterInsert.
            params.tEvent = TriggerFactory.TriggerEvent.afterUpdate;
            params.triggerObject = 'Account';
            TriggerFactory.dispatchHandler(Account.SObjectType, new AccountHandler('afterUpdate'));

        }

        public override void afterInsertRecursive(Map<Id, SObject> newMap) {
            System.assertEquals('afterInsertRecursive', executing);
        }

        public override void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
            System.assertEquals('afterUpdate', executing);
        }
    }

    public class ExceptionHandler extends TriggerFactory.BaseHandler {

        public override void beforeInsert(List<SObject> newObjects) {
            //do some stuff. throw exception
            Integer i = 1 / 0;
        }
    }
}
