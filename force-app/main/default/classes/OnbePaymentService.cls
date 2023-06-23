public without sharing class OnbePaymentService implements PaymentServiceInterface {
    
    // Customer Service Static Values
    private static final String CUSTOMER_SERVICE_APPLICATION_ID;

    // Account Management Static Values
    private static final String PROGRAM_ID;
    private static final String PROMOTION_ID = '2';
    private static final String ACCESS_LEVEL = '02';

    static {
        Proesis_Settings__c orgSettings = Proesis_Settings__c.getOrgDefaults();
        if (orgSettings.OnbePaymentService_AcctMgmtProgramID__c != null) {
            PROGRAM_ID = orgSettings.OnbePaymentService_AcctMgmtProgramID__c;
        } else {
            PROGRAM_ID = '04011223';
        }

        if (orgSettings.OnbePaymentService_CustSvcAppID__c != null) {
            CUSTOMER_SERVICE_APPLICATION_ID = orgSettings.OnbePaymentService_CustSvcAppID__c;
        } else {
            CUSTOMER_SERVICE_APPLICATION_ID = '3037c66b967c3d338751f95d2cdac566';
        }
    }

    public String getPaymentServiceName() {
        return 'Onbe';
    }

    public String getPaymentServiceDescription() {
        return 'Onbe Payment Service supports stored value card transfers.';
    }

    public String setupPaymentServiceAccount(String cardPackageId, Id donorId, Decimal initialAccountLoad, String initialPIN, Boolean blockCards) {
        String partnerUserId = (String)donorId;

        OnbeDomainPrepaid.Load newLoad;
        if (initialAccountLoad != null && initialAccountLoad > 0) {
            newLoad = new OnbeDomainPrepaid.Load();
            newLoad.amount = (Long)initialAccountLoad;
            newLoad.comment = 'Initial Account Funds';
        }

        OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
        newLink.block = (blockCards) ? 'ALL' : 'NONE';  // either ALL or NONE
        newLink.cardPackageId = cardPackageId;

        Account donorRecord;
        try {
            donorRecord = [
                SELECT Id, FirstName, LastName, PersonContactId, PersonMailingStreet,
                    PersonMailingCity, PersonMailingState, PersonMailingPostalCode, PersonMailingCountry, PersonMobilePhone 
                FROM Account 
                WHERE Id IN (SELECT AccountId FROM Contact WHERE Id = :donorId)
                LIMIT 1
            ];
        } catch(Exception e) {
            System.debug(e.getMessage());
            return 'error';
        }

        OnbeDomainPrepaid.Registration newReg = new OnbeDomainPrepaid.Registration();
        newReg.firstName = donorRecord.FirstName;
        newReg.lastName = donorRecord.LastName;
        newReg.address1 = donorRecord.PersonMailingStreet;
        newReg.city = donorRecord.PersonMailingCity;
        newReg.state = donorRecord.PersonMailingState;
        newReg.postal = donorRecord.PersonMailingPostalCode;
        newReg.country = donorRecord.PersonMailingCountry;

        if (!String.isEmpty(donorRecord.PersonMobilePhone)) {
            // Collect all phone number digits, and reconstruct the number using the expected format (xxx-xxx-xxxx)
            String phoneDigits = donorRecord.PersonMobilePhone.replaceAll('[^0-9]', '');
            if (phoneDigits.length() == 10) {
                newReg.homePhone = phoneDigits.substring(0, 3) + '-' + phoneDigits.substring(3, 6) + '-' + phoneDigits.substring(6, 10);
            } else if (phoneDigits.length() == 11 && phoneDigits.substring(0, 1) == '1') {
                newReg.homePhone = phoneDigits.substring(1, 4) + '-' + phoneDigits.substring(4, 7) + '-' + phoneDigits.substring(7, 11);
            } else {
                throw new OnbeServiceException('Invalid phone number format: ' + donorRecord.PersonMobilePhone);
            }
        } else {
            newReg.homePhone = '';
        }
        

        OnbeWsPrepaid.AccountManagementApiWebServices accountManagementAPI = new OnbeWsPrepaid.AccountManagementApiWebServices();
        String transactionId = String.valueOf(donorId) + '-' + String.valueOf(System.currentTimeMillis());

        OnbeResponsePrepaid.CreateAccountResponse processedCreateAccountResponse;
        Integer maxSyncAttempts = 5, currentSyncAttemptCount = 0;

        while(processedCreateAccountResponse == null && (currentSyncAttemptCount < maxSyncAttempts)) {
            OnbeResponsePrepaid.CreateAccountResponse createActivateCardResponse = accountManagementAPI.createAccount_Http(
                PROGRAM_ID, PROMOTION_ID, transactionId, partnerUserId, ACCESS_LEVEL, true, null, newLoad, newLink, newReg
            );

            if (createActivateCardResponse.code == Constants.ONBE_PROCESSING_ACCOUNT_MANAGEMENT) {
                // This is a code that is returned when the transaction is still being processed by Onbe, so we need to wait and try again
                currentSyncAttemptCount++;
                continue;
            } else {
                processedCreateAccountResponse = createActivateCardResponse;
            }
        }

        if (processedCreateAccountResponse == null) {
            // Create a Payment Method with the transaction id for a manual retry later
            Payment_Method__c newPaymentMethod = new Payment_Method__c();
            newPaymentMethod.Name = PaymentService__mdt.getInstance('OnbePaymentService').PaymentServiceLabel__c;
            newPaymentMethod.Account_Token__c = cardPackageId;
            newPaymentMethod.Account_Number__c = '0000000000000000'; // Enter a bogus number that can be edited later
            newPaymentMethod.Partner_User_Id__c = partnerUserId;
            newPaymentMethod.Onbe_Transaction_Id__c = transactionId;
            newPaymentMethod.Donor__c = donorId;
            newPaymentMethod.Is_Active__c = false;
            newPaymentMethod.isDefault__c = false;
            insert newPaymentMethod;

            return 'Processing';
        } else if (processedCreateAccountResponse.code != 0) {
            if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                throw new OnbeServiceException('Error received from Onbe: ' + processedCreateAccountResponse.code + '-' + processedCreateAccountResponse.sub_code);
            }
        }

        if (!String.isEmpty(processedCreateAccountResponse.accountNumber) && !String.isEmpty(initialPIN)) {
            OnbeResponsePrepaid.SetPinResponse setPinResponse = accountManagementAPI.setPin_Http(
                PROGRAM_ID, PROMOTION_ID, processedCreateAccountResponse.accountNumber, donorId + '-' + String.valueOf(System.currentTimeMillis()), initialPIN
            );

            if (setPinResponse.code != 0) {
                if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                    throw new OnbeServiceException('Error received from Onbe: ' + setPinResponse.code + '-' + setPinResponse.sub_code);
                }
            }
        }

        // Make an account inquiry call to get the card number/expiration
        OnbeWsManageCard.AccountInquiryResponse accountInquiryResponse = executeAccountInquiry(donorId);

        String expirationDateMMYYYY = accountInquiryResponse.expirationMMYYYY;
        Date expirationDate;

        if (!String.isEmpty(expirationDateMMYYYY)) {
            List<String> expirationMMYYParts = expirationDateMMYYYY.split('/');

            Integer expirationMonth = Integer.valueOf(expirationMMYYParts[0]);
            Integer expirationYear = Integer.valueOf(expirationMMYYParts[1]);

            expirationDate = Date.newInstance(expirationYear, expirationMonth, 1);
        } else {
            expirationDate = Date.today().addYears(1);
        }

        Payment_Method__c newPaymentMethod = new Payment_Method__c();
        newPaymentMethod.Name = PaymentService__mdt.getInstance('OnbePaymentService').PaymentServiceLabel__c;
        newPaymentMethod.Account_Token__c = cardPackageId;
        newPaymentMethod.Account_Number__c = processedCreateAccountResponse.accountNumber;
        newPaymentMethod.Partner_User_Id__c = partnerUserId;
        newPaymentMethod.Card_Number__c = accountInquiryResponse.cardNumber4Digits;
        newPaymentMethod.Expiration__c = expirationDate;
        newPaymentMethod.Is_Active__c = true;
        newPaymentMethod.isDefault__c = true;
        newPaymentMethod.Donor__c = donorRecord.PersonContactId;
        insert newPaymentMethod;

        return '';
    }

    public Boolean linkPhysicalCard(String cardPackageId, Id donorId, String initialPIN, Boolean blockCards) {
        Id donorContactId = donorId;

        // The donor contact id is stored as a Partner Id on the Onbe side, so we need to make sure we are getting or converting it correctly
        if (donorId.getSObjectType() == Schema.Account.getSObjectType()) {
            donorContactId = [SELECT PersonContactId FROM Account WHERE Id = :donorId LIMIT 1].PersonContactId;
        } else if (donorId.getSObjectType() != Schema.Contact.getSObjectType()) {
            throw new OnbeServiceException('An invalid Onbe Donor Id was provided: ' + donorId);
        }

        List<Payment_Method__c> existingPaymentMethods = [
            SELECT Id, Is_Active__c, isDefault__c, Account_Number__c, Partner_User_Id__c
            FROM Payment_Method__c
            WHERE Donor__c = :donorContactId AND 
                Is_Active__c = true
        ];

        String existingPartnerUserId = !existingPaymentMethods.isEmpty() ? existingPaymentMethods[0].Partner_User_Id__c : String.valueOf(donorContactId);

        OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
        newLink.block = (blockCards) ? 'ALL' : 'NONE';
        newLink.cardPackageId = cardPackageId;

        OnbeWsPrepaid.AccountManagementApiWebServices accountManagementAPI = new OnbeWsPrepaid.AccountManagementApiWebServices();
        String transactionId = String.valueOf(donorContactId) + '-' + String.valueOf(System.currentTimeMillis());
        Integer maxSyncAttempts = 5, currentSyncAttemptCount = 0;

        OnbeResponsePrepaid.LinkCardResponse processedLinkCardResponse;
        while(processedLinkCardResponse == null && (currentSyncAttemptCount < maxSyncAttempts)) {
            OnbeResponsePrepaid.LinkCardResponse linkCardResponse = accountManagementAPI.linkCard_Http(
                existingPartnerUserId, PROGRAM_ID, PROMOTION_ID, transactionId, newLink
            );

            if (linkCardResponse.code == Constants.ONBE_PROCESSING_ACCOUNT_MANAGEMENT) {
                // This is a code that is returned when the transaction is still being processed by Onbe, so we need to wait and try again
                currentSyncAttemptCount++;
                continue;
            } else {
                processedLinkCardResponse = linkCardResponse;
            }
        }

        if (processedLinkCardResponse == null) {
            // Create a Payment Method with the transaction id for a manual retry later
            Payment_Method__c newPaymentMethod = new Payment_Method__c();
            newPaymentMethod.Name = PaymentService__mdt.getInstance('OnbePaymentService').PaymentServiceLabel__c;
            newPaymentMethod.Account_Token__c = cardPackageId;
            newPaymentMethod.Account_Number__c = '0000000000000000'; // Enter a bogus number that can be edited later
            newPaymentMethod.Partner_User_Id__c = existingPartnerUserId;
            newPaymentMethod.Onbe_Transaction_Id__c = transactionId;
            newPaymentMethod.Donor__c = donorContactId;
            newPaymentMethod.Is_Active__c = false;
            newPaymentMethod.isDefault__c = false;
            insert newPaymentMethod;

            return false;
        } else if (processedLinkCardResponse.code != 0) {
            if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                throw new OnbeServiceException('Error received from Onbe: ' + processedLinkCardResponse.code + '-' + processedLinkCardResponse.sub_code);
            }
        }

        // Set the pin for the new payment method
        String accountNumber = existingPaymentMethods[0].Account_Number__c;

        if (!String.isEmpty(accountNumber) && !String.isEmpty(initialPIN)) {
            OnbeResponsePrepaid.SetPinResponse setPinResponse = accountManagementAPI.setPin_Http(
                PROGRAM_ID, PROMOTION_ID, accountNumber, donorId + '-' + String.valueOf(System.currentTimeMillis()), initialPIN
            );

            if (setPinResponse.code != 0) {
                if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                    throw new OnbeServiceException('Error received from Onbe: ' + setPinResponse.code + '-' + setPinResponse.sub_code);
                }
            }
        }

        // Get the new card number/expiration
        OnbeWsManageCard.AccountInquiryResponse accountInquiryResponse = executeAccountInquiry(donorId);

        // Get existing payment methods for this donor and mark them as inactive
        for (Payment_Method__c existingPaymentMethod : existingPaymentMethods) {
            existingPaymentMethod.Is_Active__c = false;
            existingPaymentMethod.isDefault__c = false;
        }

        update existingPaymentMethods;

        
        // Save the new information to a new payment method
        String expirationDateMMYYYY = accountInquiryResponse.expirationMMYYYY;
        
        Date expirationDate;
        if (!String.isEmpty(expirationDateMMYYYY)) {
            List<String> expirationMMYYParts = expirationDateMMYYYY.split('/');

            Integer expirationMonth = Integer.valueOf(expirationMMYYParts[0]);
            Integer expirationYear = Integer.valueOf(expirationMMYYParts[1]);

            expirationDate = Date.newInstance(expirationYear, expirationMonth, 1);
        } else {
            expirationDate = Date.today().addYears(1);
        }

        Payment_Method__c newPaymentMethod = new Payment_Method__c();
        newPaymentMethod.Name = PaymentService__mdt.getInstance('OnbePaymentService').PaymentServiceLabel__c;
        newPaymentMethod.Account_Token__c = cardPackageId;
        newPaymentMethod.Account_Number__c = accountNumber;
        newPaymentMethod.Partner_User_Id__c = existingPartnerUserId;
        newPaymentMethod.Card_Number__c = accountInquiryResponse.cardNumber4Digits;
        newPaymentMethod.Expiration__c = expirationDate;
        newPaymentMethod.Is_Active__c = true;
        newPaymentMethod.isDefault__c = true;
        newPaymentMethod.Donor__c = donorContactId;
        insert newPaymentMethod;

        return true;
    }

    public String processPayment(String accountNumber, String comment, Long amount, String onbeTransactionId) {
        OnbeDomainPrepaid.Load addFundsLoad = new OnbeDomainPrepaid.Load();
        addFundsLoad.amount = amount;
        addFundsLoad.comment = comment;
        
        OnbeWsPrepaid.AccountManagementApiWebServices accountManagementServices = new OnbeWsPrepaid.AccountManagementApiWebServices();
        OnbeResponsePrepaid.AddFundsResponse addFundsResponse = accountManagementServices.addFunds_Http(
            accountNumber, null, PROGRAM_ID, PROMOTION_ID, onbeTransactionId, addFundsLoad
        );

        if (addFundsResponse.code != 0) {
            if (addFundsResponse.code == Constants.ONBE_PROCESSING_ACCOUNT_MANAGEMENT) {
                // This is a code that is returned when the transaction is still being processed by Onbe, so we need to wait and try again
                return Constants.ONBE_ACCOUNT_MANAGEMENT_PROCESSING_STATUS;
            }

            if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                throw new OnbeServiceException('Error received from Onbe: ' + addFundsResponse.code + '-' + addFundsResponse.sub_code);
            }
        }

        return '';
    }
    
    public Decimal getBalance(Id donorId) {
        OnbeWsManageCard.AccountInquiryResponse accountInquiryResponse = executeAccountInquiry(donorId);
        return accountInquiryResponse.balance;
    }

    public String getTransaction() {
        return 'Onbe Transaction';
    }

    public String getTransactionHistory() {
        return 'Onbe Transaction History';
    }

    public OnbeWsManageCard.ReissueCardResponse reissueCard(String paymentMethodId, String blockCode) {
        Payment_Method__c targetPaymentMethod;

        try {
            targetPaymentMethod = [
                SELECT Id, Donor__c, Account_Number__c, Partner_User_Id__c
                FROM Payment_Method__c
                WHERE Id = :paymentMethodId
                LIMIT 1
            ];
        } catch(Exception e) {
            throw new OnbeServiceException('Error while retrieving active/default payment method ' + paymentMethodId + ' - ' + e.getMessage());
        }

        Set<String> validBlockCodes = new Set<String>{ 
            Constants.ONBE_REISSUE_CARD_LOST_CODE, Constants.ONBE_REISSUE_CARD_STOLEN_CODE, Constants.ONBE_REISSUE_CARD_REVOKED_CODE 
        };

        if (!validBlockCodes.contains(blockCode)) {
            throw new OnbeServiceException('Invalid block code: ' + blockCode);
        }

        OnbeWsManageCard.AccountManagement onbeManageCardBaseObject = new OnbeWsManageCard.AccountManagement();
        String partnerUserId = targetPaymentMethod.Partner_User_Id__c;

        return onbeManageCardBaseObject.reissueCard_Http(CUSTOMER_SERVICE_APPLICATION_ID, partnerUserId, blockCode);
    }

    public String updateAccountStatus(String paymentMethodId, String newAccountStatus) {
        Payment_Method__c targetPaymentMethod;

        try {
            targetPaymentMethod = [
                SELECT Id, Donor__c, Account_Number__c
                FROM Payment_Method__c
                WHERE Id = :paymentMethodId
                LIMIT 1
            ];
        } catch(Exception e) {
            throw new AuraHandledException('Error while retrieving active/default payment method ' + paymentMethodId + ' - ' + e.getMessage());
        }

        OnbeWsPrepaid.AccountManagementApiWebServices updateAccountStatusRequest = new OnbeWsPrepaid.AccountManagementApiWebServices();
        String transactionId = targetPaymentMethod.Donor__c + '-' + String.valueOf(System.currentTimeMillis());

        OnbeResponsePrepaid.UpdateAccountStatusResponse updateAccountStatusResponse = updateAccountStatusRequest.updateAccountStatus_Http(
            targetPaymentMethod.Account_Number__c, PROGRAM_ID, PROMOTION_ID, transactionId, newAccountStatus
        );

        if (updateAccountStatusResponse.code != 0) {
            if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                throw new OnbeServiceException('Error received from Onbe: ' + updateAccountStatusResponse.code + '-' + updateAccountStatusResponse.sub_code);
            }
        }

        return '';
    }
    
    private OnbeWsManageCard.AccountInquiryResponse executeAccountInquiry(Id donorId) {
        Id donorContactId = donorId;
        
        // The donor contact id is stored as a Partner Id on the Onbe side, so we need to make sure we are getting or converting it correctly
        if (donorId.getSObjectType() == Schema.Account.getSObjectType()) {
            donorContactId = [SELECT PersonContactId FROM Account WHERE Id = :donorId LIMIT 1].PersonContactId;
        } else if (donorId.getSObjectType() != Schema.Contact.getSObjectType()) {
            throw new OnbeServiceException('An invalid Onbe Donor Id was provided: ' + donorId);
        }

        List<Payment_Method__c> paymentMethodWithPUID;
        try {
            paymentMethodWithPUID = [SELECT Id, Partner_User_Id__c FROM Payment_Method__c WHERE Donor__c = :donorContactId AND Partner_User_Id__c != null LIMIT 1];
        } catch(Exception e) {
            throw new OnbeServiceException('Error while retrieving active/default payment method for donor: ' + donorContactId + ' - ' + e.getMessage());
        }

        if (paymentMethodWithPUID.size() > 0 && String.isEmpty(paymentMethodWithPUID[0].Partner_User_Id__c)) {
            throw new OnbeServiceException('Onbe Partner User Id wasn\'t found for donor: ' + donorContactId);
        }

        String card_number ='';
        String puid = !paymentMethodWithPUID.isEmpty() ? paymentMethodWithPUID[0].Partner_User_Id__c : String.valueOf(donorContactId);
        String ppd = ''; // We are unsure of what this property is, we asked Onbe but they couldn't provide an answer. Leave blank for now.
        String mobile_phone = '';
        Integer balance_detail = 1;
        Integer journal_detail = 0;
        Integer registration_detail = 0;
        Integer start_date = 0;
        Integer end_date = 0;
        Integer max_items = 20;

        OnbeWsManageCard.AccountManagement onbeManageCardBaseObject = new OnbeWsManageCard.AccountManagement();
        OnbeWsManageCard.AccountInquiryResponse accountInquiryResponse = onbeManageCardBaseObject.accountInquiry_Http(
            CUSTOMER_SERVICE_APPLICATION_ID, card_number, puid, ppd,
            mobile_phone, balance_detail, journal_detail, registration_detail, 
            start_date, end_date, max_items
        );

        if (
            (accountInquiryResponse.code != null && accountInquiryResponse.code != 0) || 
            (accountInquiryResponse.message != null && accountInquiryResponse.message != Constants.ONBE_CUSTOMER_SERVICE_SUCCESS_MESSAGE)
        ) {
            if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                throw new OnbeServiceException('Error received from Onbe: ' + accountInquiryResponse.code + '-' + accountInquiryResponse.message);
            }
        }

        return accountInquiryResponse;
    }

    public class OnbeServiceException extends Exception {}
}