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

    public static final String DEFAULT_MARKETING_CONSENT_SCOPE = 'Global';
    public static final String DEFAULT_MARKETING_CONSENT_SOURCE = 'Mobile Registration';
    public static final String DEFAULT_MARKETING_CONSENT_TYPE = 'Opt-in';

    public static final String UNMARKED_DONATION_TASK_SUBJECT = 'Unmarked Donation Found';
    public static final String UNMARKED_DONATION_TASK_DESCRIPTION = 'A vist with a record donation volume was found that was not marked with an outcome of "Donation".';

    public static final String CENTER_DAY_EXCEPTION_LIMIT_ERROR = 'Center Day limit exceeded for center {0}';
    public static final String CENTER_INDIVIDUAL_EXCEPTION_LIMIT_ERROR = 'Center Individual Payment limit exceeded for center {0}';

    public static final String DONATION_PAYMENT_MESSAGE_HANDLER = 'Donation Payment';
    public static final String LOYALTY_DONATION_PAYMENT_MESSAGE_HANDLER = 'Donation with Loyalty Promotion Payment';

    public static final String MISSING_PAYMENT_METHOD_TASK_SUBJECT = 'Missing Payment Method';

    public static final String ONBE_CUSTOMER_SERVICE_SUCCESS_MESSAGE = 'OK';
    public static final String ONBE_ACCOUNT_MANAGEMENT_PROCESSING_STATUS = 'PROCESSING';
    public static final Integer ONBE_PROCESSING_ACCOUNT_MANAGEMENT = 2;

    public static final String ONBE_REISSUE_CARD_LOST_CODE = 'lost';
    public static final String ONBE_REISSUE_CARD_REVOKED_CODE = 'revoked';
    public static final String ONBE_REISSUE_CARD_STOLEN_CODE = 'stolen';

    public static final String MESSAGE_HANDLER_TYPE_DONATION = 'Donation Payment';

    public static final String REPLACE_PAYMENT_METHOD_TASK_SUBJECT = 'Renew Payment Method';
    public static final String REPLACE_PAYMENT_METHOD_TASK_DESCRIPTION = 'The existing payment method for this donor has been cancelled or is set to expire soon. Please update the donor\'s payment method.';

    public static final String CAMPAIGN_TYPE_INCENTIVE = 'Incentive';

    public static final String PAYMENTREQUEST_STATUS_NEW = 'New';
    public static final String PAYMENTREQUEST_STATUS_APPROVED = 'Approved';
    public static final String PAYMENTREQUEST_STATUS_SUBMITTED = 'Submitted';

    public static final Map<String, String> TIME_ZONE_REGIONS = new Map<String, String>{
        'America/Chicago' => 'Central',
        'America/New_York' => 'Eastern'
    };

    public static final String CANT_SCHEDULE_LOYALTY_MESSAGE = 'Can\'t schedule donor due to loyalty level.';
    public static final String CANT_SCHEDULE_SOONEST_NEXT_VISIT_MESSAGE = 'Can\'t schedule donor until {0}.';

    public static final String OVER_CAPACITY_ADD_VISIT_EXCEPTION_MESSAGE = 'The selected appointment slot is full. Please select another slot.';
    public static final String BEFORE_SOONEST_NEXT_VISIT_EXCEPTION_MESSAGE = 'The selected appointment slot is before the soonest next visit date. Please select another slot.';
}