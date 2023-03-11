@isTest
public with sharing class PaymentServiceInjectorTest {
    
    @isTest
    static void testGetService_negative_nullPaymentMethod() {

        //PaymentServiceInjector paymentService = new PaymentServiceInjector();
        UnsupportedOperationException uoe = new UnsupportedOperationException('No service found for payment method: ');

        // Injector method call below - null payment method - will always fail, catch the Exception and assert
        try {
            Object serviceObject = PaymentServiceInjector.getService('');
        } catch (Exception e) {
            System.assertEquals(uoe.getMessage(), e.getMessage(), '');
        }

    }
}