@isTest
public with sharing class OnbePaymentServiceTest {

    @isTest
    private static void callPaymentServiceMethods_positive() {

        OnbePaymentService onbePayService = new OnbePaymentService();

        Id donorId = Id.valueOf('001xa000003DIlo');
        Decimal amount = 50.00;

        // return Service method strings and assert
        System.assertEquals('Onbe', onbePayService.getPaymentServiceName(), 'Payment Service Name did not match expected value.');
        System.assertEquals('Onbe Payment Service supports stored value card transfers.', onbePayService.getPaymentServiceDescription(), 'Payment Service Description did not match expected value.');
        System.assertEquals('Onbe Payment Service Account Setup', onbePayService.setupPaymentServiceAccount(), 'Payment Service Account did not match expected value.');
        System.assertEquals('Onbe Physical Card Link', onbePayService.linkPhysicalCard(), 'Payment Physical Card Link did not match expected value.');
        System.assertEquals('Onbe Pay', onbePayService.processPayment(donorId, amount), 'processPayment() method did not return expected value.');
        System.assertEquals('Onbe Balance', onbePayService.getBalance(), 'getBalance() method did not return expected value.');
        System.assertEquals('Onbe Transaction', onbePayService.getTransaction(), 'getTransaction() method did not return expected value.');
        System.assertEquals('Onbe Transaction History', onbePayService.getTransactionHistory(), 'getTransactionHistory() method did not return expected value.');
    }

}