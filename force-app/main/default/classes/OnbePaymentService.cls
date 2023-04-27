public with sharing class OnbePaymentService implements PaymentServiceInterface {
    
    private static final String PROGRAM_ID = '04011223';
    private static final String PARTNER_USER_ID = '0012';
    private static final String PROMOTION_ID = '2';
    private static final String ACCESS_LEVEL = '01';

    public OnbePaymentService() {

    }

    public String getPaymentServiceName() {
        return 'Onbe';
    }

    public String getPaymentServiceDescription() {
        return 'Onbe Payment Service supports stored value card transfers.';
    }

    public String setupPaymentServiceAccount(String cardPackageId, Id donorId) {
        OnbeDomainPrepaid.Card newCard = new OnbeDomainPrepaid.Card();
        newCard.cardAccessLevel = ACCESS_LEVEL;

        OnbeDomainPrepaid.Load newLoad = new OnbeDomainPrepaid.Load();
        newLoad.amount = 200;
        newLoad.comment = 'Add funds';

        OnbeDomainPrepaid.Link newLink = new OnbeDomainPrepaid.Link();
        newLink.block = 'NONE';  // either ALL or NONE
        newLink.cardPackageId = cardPackageId;

        Account donorContactRecord;
        try {
            donorContactRecord = [
                SELECT Id, FirstName, LastName, PersonMailingStreet, PersonMailingCity, PersonMailingState, PersonMailingPostalCode, PersonMailingCountry, PersonMobilePhone 
                FROM Account 
                WHERE Id IN (SELECT AccountId FROM Contact WHERE Id = :donorId)
                LIMIT 1
            ];
        } catch(Exception e) {
            System.debug(e.getMessage());
            return 'error';
        }

        OnbeDomainPrepaid.Registration newReg = new OnbeDomainPrepaid.Registration();
        newReg.firstName = donorContactRecord.FirstName;
        newReg.lastName = donorContactRecord.LastName;
        newReg.address1 = donorContactRecord.PersonMailingStreet;
        newReg.city = donorContactRecord.PersonMailingCity;
        newReg.state = donorContactRecord.PersonMailingState;
        newReg.postal = donorContactRecord.PersonMailingPostalCode;
        newReg.country = donorContactRecord.PersonMailingCountry;
        newReg.homePhone = donorContactRecord.PersonMobilePhone;

        OnbeWsPrepaid.AccountManagementApiWebServices createActivateCardRequest = new OnbeWsPrepaid.AccountManagementApiWebServices();
        OnbeResponsePrepaid.CreateAccountResponse createActivateCardResponse = createActivateCardRequest.createAccount_Http(
            PROGRAM_ID, PROMOTION_ID, donorId, PARTNER_USER_ID, ACCESS_LEVEL, true, newCard, newLoad, newLink, newReg
        );

        System.debug(createActivateCardResponse.code);
        System.debug(createActivateCardResponse.sub_code);
        return '';
    }

    public String linkPhysicalCard() {
        return 'Onbe Physical Card Link';
    }

    public String processPayment(Id donorId, Decimal amount) {
        return 'Onbe Pay';
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

    public String updateAccountStatus(String newAccountStatus) {
        OnbeWsPrepaid.AccountManagementApiWebServices updateAccountStatusRequest = new OnbeWsPrepaid.AccountManagementApiWebServices();
        updateAccountStatusRequest.updateAccountStatus_Http(newAccountStatus);

        return '';
    }
}