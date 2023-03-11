public with sharing class PaymentServiceInjector {
    public static object getService(String paymentMethod) {
        Type t;
        Map<String, String> mapServiceNameByClassName = new Map<String, String>();

        for(PaymentService__mdt service : [ select DeveloperName, ImplementationApexClass__c from PaymentService__mdt WITH SECURITY_ENFORCED ]) {
            mapServiceNameByClassName.put(service.DeveloperName, service.ImplementationApexClass__c);
        }

        String className = mapServiceNameByClassName.get(paymentMethod);
        if(className != null) {
            t = Type.forName(className);
        } else {
            t = Type.forName(mapServiceNameByClassName.get('Default'));
        }
        if (t == null) {
            throw new UnsupportedOperationException('No service found for payment method: ' + paymentMethod);
        }
        return t.newInstance();
    }

}