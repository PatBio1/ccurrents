public with sharing class OnbePaymentService implements PaymentServiceInterface {
    
    private static final String PROGRAM_ID = '04011223';
    private static final String PROMOTION_ID = '2';
    private static final String ACCESS_LEVEL = '02';

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
        
        OnbeDomainPrepaid.Card newCard = new OnbeDomainPrepaid.Card();
        newCard.cardAccessLevel = ACCESS_LEVEL;

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
        newReg.homePhone = donorRecord.PersonMobilePhone;

        OnbeWsPrepaid.AccountManagementApiWebServices accountManagementAPI = new OnbeWsPrepaid.AccountManagementApiWebServices();
        OnbeResponsePrepaid.CreateAccountResponse createActivateCardResponse = accountManagementAPI.createAccount_Http(
            PROGRAM_ID, PROMOTION_ID, donorId + '-' + String.valueOf(System.currentTimeMillis()), partnerUserId, ACCESS_LEVEL, true, newCard, newLoad, newLink, newReg
        );

        if (createActivateCardResponse.code != 0) {
            if (!Test.isRunningTest() || Test.isRunningTest() && TestUtil.throwException) {
                throw new OnbeServiceException('Error received from Onbe: ' + createActivateCardResponse.code + '-' + createActivateCardResponse.sub_code);
            }
        }

        if (!String.isEmpty(createActivateCardResponse.accountNumber) && !String.isEmpty(initialPIN)) {
            accountManagementAPI.setPin_Http(
                PROGRAM_ID, PROMOTION_ID, createActivateCardResponse.accountNumber, donorId + '-' + String.valueOf(System.currentTimeMillis()), initialPIN
            );
        }

        String expirationMMYY = createActivateCardResponse.cardExpiryDateMMYY;
        Date expirationDate;

        if (!String.isEmpty(expirationMMYY)) {
            Integer expirationMonth = Integer.valueOf(expirationMMYY.substring(0, 2));
            Integer expirationYear = Integer.valueOf(expirationMMYY.substring(2, 4));

            expirationDate = Date.newInstance(expirationYear, expirationMonth, 1);
        } else {
            expirationDate = Date.today().addYears(1);
        }

        Payment_Method__c newPaymentMethod = new Payment_Method__c();
        newPaymentMethod.Name = PaymentService__mdt.getInstance('OnbePaymentService').PaymentServiceLabel__c;
        newPaymentMethod.Account_Number__c = createActivateCardResponse.accountNumber;
        newPaymentMethod.Card_Number__c = !String.isEmpty(createActivateCardResponse.accountNumber) ? createActivateCardResponse.accountNumber.right(4) : null;
        newPaymentMethod.Expiration__c = expirationDate;
        newPaymentMethod.Is_Active__c = true;
        newPaymentMethod.isDefault__c = true;
        newPaymentMethod.Donor__c = donorRecord.PersonContactId;
        insert newPaymentMethod;

        return '';
    }

    public String linkPhysicalCard() {
        return 'Onbe Physical Card Link';
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
    
    public String getBalance() {
        

        return 'Onbe Balance';
    }

    public String getTransaction() {
        return 'Onbe Transaction';
    }

    public String getTransactionHistory() {
        return 'Onbe Transaction History';
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

    public class OnbeServiceException extends Exception {}
}