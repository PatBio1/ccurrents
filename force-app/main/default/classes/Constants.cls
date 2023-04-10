public with sharing class Constants {

    public static final Id CENTER_RECORD_TYPE_ID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Center').getRecordTypeId();

    public static final Id DONOR_RECORD_TYPE_ID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Donor').getRecordTypeId();

    public static final String ADMIN_PERMISSION_SET_NAME = 'Proesis Administrator (Salesforce License)';

    public static final String EXPERIENCE_USER_PROFILE_NAME = 'ProesisCustomerLoginMinimumAccess';

    public static final String EXPERIENCE_PERMISSION_SET_NAME = 'Proesis Community Donor';

    public static final String EXPERIENCE_GUEST_PERMISSION_SET_NAME = 'Proesis Mobile Guest User';

    public static final String ORG_WIDE_EMAIL_NAME = 'Proesis Plus';

    public static final String USERNAME_SUFFIX = '.prodx';

    public static final String VERIFICATION_RESULT_SUCCESS = 'Success';
    public static final String VERIFICATION_RESULT_INCORRECT = 'Incorrect';
    public static final String VERIFICATION_RESULT_TOO_MANY = 'Too Many';
    public static final String VERIFICATION_RESULT_TIMED_OUT = 'Timed Out';

    public static final String VISIT_STATUS_CHECKEDIN = 'Checked-In';

    public static final String VISIT_STATUS_COMPLETE = 'Complete';

    public static final String VISIT_OUTCOME_DONATION = 'Donation';

    public static final String ERRORLOG_TYPE_ERROR = 'Error';

    public static final String ERRORLOG_TYPE_WARNING = 'Warning';

    public static final String ERRORLOG_TYPE_INFORMATION = 'Information';

    public static final String SPE_ANALYSIS_TASK_SUBJECT = 'SPE Analysis';
    public static final String PHYSICAL_EXAM_TASK_SUBJECT = 'Physical Exam';
    public static final String FIRST_VISIT_CODE_TASK_SUBJECT = 'First Visit Code';

    public static final String DEFAULT_CUSTOMER_SUPPORT_CASE_SUBJECT = 'Donor Mobile App Support Request';
    public static final String DEFAULT_CUSTOMER_SUPPORT_CASE_ORIGIN = 'Donor Mobile App Submission';
    public static final String DEFAULT_CUSTOMER_SUPPORT_CASE_REASON = 'Support Request';
}