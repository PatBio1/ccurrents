
// OnbePaymentServiceImpl  // for 'Default'
Object serviceObject = PaymentServiceInjector.getService('Default');

OnbePaymentService newService = (OnbePaymentService)serviceObject;

System.debug('PaymentServiceInjector returned class instance: ' + serviceObject);

System.debug('Payment Service Name: ' + newService.getPaymentServiceName());
System.debug('Payment Service Description: ' + newService.getPaymentServiceDescription());
System.debug('Payment Service Physical Card: ' + newService.linkPhysicalCard());
System.debug('Payment Service Account: ' + newService.setupPaymentServiceAccount());
System.debug('Payment Service Balance: ' + newService.getBalance());
System.debug('Payment Service Transaction: ' + newService.getTransaction());
System.debug('Payment Service Transaction History: ' + newService.getTransactionHistory());
//System.debug('Payment processPayment(): ' + newService.processPayment(donorId, amount)());

