public with sharing class OnbePaymentService implements PaymentServiceInterface {
    
    public OnbePaymentService() {

    }

    public String getPaymentServiceName() {
        return 'Onbe';
    }

    public String getPaymentServiceDescription() {
        return 'Onbe Payment Service supports stored value card transfers.';
    }

    public String setupPaymentServiceAccount() {
        return 'Onbe Payment Service Account Setup';
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

}