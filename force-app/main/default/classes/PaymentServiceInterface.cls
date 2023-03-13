global Interface PaymentServiceInterface {

    String getPaymentServiceName();
    String getPaymentServiceDescription();
    String setupPaymentServiceAccount();
    String linkPhysicalCard();
    String processPayment(Id donorId, Decimal amount);
    String getBalance();
    String getTransaction();
    String getTransactionHistory();

}