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

    public OnbePaymentService() {

    }

    public String getPaymentServiceName() {
        return 'Onbe';
    }

    public String getPaymentServiceDescription() {
        return 'Onbe Payment Service supports stored value card transfers.';
    }

    public String setupPaymentServiceAccount(String cardPackageId, Id donorId, Decimal initialAccountLoad, String initialPIN) {
        String partnerUserId = (String)donorId;

        OnbeDomainPrepaid.Load newLoad;
        if (initialAccountLoad != null && initialAccountLoad > 0) {
            newLoad = new OnbeDomainPrepaid.Load();
            newLoad.amount = (Long)initialAccountLoad;
            newLoad.comment = 'Initial Account Funds';
        }

        OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
        newLink.block = 'NONE';  // either ALL or NONE
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
        OnbeResponsePrepaid.CreateAccountResponse createActivateCardResponse = accountManagementAPI.createAccount_Http(
            PROGRAM_ID, PROMOTION_ID, donorId + '-' + String.valueOf(System.currentTimeMillis()), partnerUserId, ACCESS_LEVEL, true, null, newLoad, newLink, newReg
        );

        if (createActivateCardResponse.code != 0) {
            if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                throw new OnbeServiceException('Error received from Onbe: ' + createActivateCardResponse.code + '-' + createActivateCardResponse.sub_code);
            }
        }

        if (!String.isEmpty(createActivateCardResponse.accountNumber) && !String.isEmpty(initialPIN)) {
            OnbeResponsePrepaid.SetPinResponse setPinResponse = accountManagementAPI.setPin_Http(
                PROGRAM_ID, PROMOTION_ID, createActivateCardResponse.accountNumber, donorId + '-' + String.valueOf(System.currentTimeMillis()), initialPIN
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
        newPaymentMethod.Account_Number__c = createActivateCardResponse.accountNumber;
        newPaymentMethod.Card_Number__c = accountInquiryResponse.cardNumber4Digits;
        newPaymentMethod.Expiration__c = expirationDate;
        newPaymentMethod.Is_Active__c = true;
        newPaymentMethod.isDefault__c = true;
        newPaymentMethod.Donor__c = donorRecord.PersonContactId;
        insert newPaymentMethod;

        return '';
    }

    public void linkPhysicalCard(String cardPackageId, Id donorId, String initialPIN) {
        Id donorContactId = donorId;
        List<Payment_Method__c> existingPaymentMethods = [
            SELECT Id, Is_Active__c, isDefault__c, Account_Number__c
            FROM Payment_Method__c
            WHERE Donor__c = :donorContactId AND 
                Is_Active__c = true
        ];

        // The donor contact id is stored as a Partner Id on the Onbe side, so we need to make sure we are getting or converting it correctly
        if (donorId.getSObjectType() == Schema.Account.getSObjectType()) {
            donorContactId = [SELECT PersonContactId FROM Account WHERE Id = :donorId LIMIT 1].PersonContactId;
        } else if (donorId.getSObjectType() != Schema.Contact.getSObjectType()) {
            throw new OnbeServiceException('An invalid Onbe Donor Id was provided: ' + donorId);
        }

        OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
        newLink.block = 'ALL';
        newLink.cardPackageId = cardPackageId;

        OnbeWsPrepaid.AccountManagementApiWebServices accountManagementAPI = new OnbeWsPrepaid.AccountManagementApiWebServices();
        OnbeResponsePrepaid.LinkCardResponse linkCardResponse = accountManagementAPI.linkCard_Http(
            String.valueOf(donorContactId), PROGRAM_ID, PROMOTION_ID, String.valueOf(donorContactId) + '-' + String.valueOf(System.currentTimeMillis()), newLink
        );

        if (linkCardResponse.code != 0) {
            if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                throw new OnbeServiceException('Error received from Onbe: ' + linkCardResponse.code + '-' + linkCardResponse.sub_code);
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
        newPaymentMethod.Card_Number__c = accountInquiryResponse.cardNumber4Digits;
        newPaymentMethod.Expiration__c = expirationDate;
        newPaymentMethod.Is_Active__c = true;
        newPaymentMethod.isDefault__c = true;
        newPaymentMethod.Donor__c = donorContactId;
        insert newPaymentMethod;
    }

    public String processPayment(String accountNumber, String comment, Long amount) {
        String transactionId = accountNumber + '-' + String.valueOf(System.currentTimeMillis());
        
        OnbeDomainPrepaid.Load addFundsLoad = new OnbeDomainPrepaid.Load();
        addFundsLoad.amount = amount;
        addFundsLoad.comment = comment;
        
        OnbeWsPrepaid.AccountManagementApiWebServices accountManagementServices = new OnbeWsPrepaid.AccountManagementApiWebServices();
        OnbeResponsePrepaid.AddFundsResponse addFundsReponse = accountManagementServices.addFunds_Http(
            accountNumber, null, PROGRAM_ID, PROMOTION_ID, transactionId, addFundsLoad
        );

        if (addFundsReponse.code != 0) {
            if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                throw new OnbeServiceException('Error received from Onbe: ' + addFundsReponse.code + '-' + addFundsReponse.sub_code);
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
                SELECT Id, Donor__c, Account_Number__c
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
        String partnerUserId = targetPaymentMethod.Donor__c;

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

        String card_number ='';
        String puid = String.valueOf(donorContactId);
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