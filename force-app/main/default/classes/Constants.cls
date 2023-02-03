public with sharing class Constants {

    public static final Id CENTER_RECORD_TYPE_ID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Center').getRecordTypeId();

    public static final Id DONOR_RECORD_TYPE_ID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Donor').getRecordTypeId();

    public static final String ADMIN_PERMISSION_SET_NAME = 'Proesis Administrator (Salesforce License)';

    public static final String EXPERIENCE_USER_PROFILE_NAME = 'ProesisCustomerLoginMinimumAccess';

    public static final String EXPERIENCE_PERMISSION_SET_NAME = 'Proesis Community Donor';

    public static final String EXPERIENCE_GUEST_PERMISSION_SET_NAME = 'Proesis Mobile Guest User';

    public static final String USERNAME_SUFFIX = '.prodx';

}