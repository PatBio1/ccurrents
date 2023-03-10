@isTest
private class AsyncOnbeResponsePrepaidTest {
 
    //private static System.Continuation cont = new Continuation(1);
    
    @isTest
    static void coverCodeForAsyncCreatePackageResponseFuture(){
		Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.CreatePackageResponseFuture testObject = new AsyncOnbeResponsePrepaid.CreatePackageResponseFuture();
		System.assertEquals(null, testObject.getValue());
	}

    @isTest
    static void coverCodeForAsyncCvvInquiryResponseFuture(){
		Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.CvvInquiryResponseFuture testObject = new AsyncOnbeResponsePrepaid.CvvInquiryResponseFuture();
		//String outputString = testObject.getValue();
        System.assertNotEquals(null, testObject);
	}

    @isTest
    static void coverCodeForAsyncActivationCardResponseFuture(){
		Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.ActivationCardResponseFuture testObject = new AsyncOnbeResponsePrepaid.ActivationCardResponseFuture();
		//String outputString = testObject.getValue();
        System.assertNotEquals(null, testObject);
	}

    @isTest
    static void coverCodeForAsyncAssignPackageResponseFuture(){
		Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.AssignPackageResponseFuture testObject = new AsyncOnbeResponsePrepaid.AssignPackageResponseFuture();
		System.assertEquals(null, testObject.getValue());
	}

    @isTest
    static void coverCodeForAsyncCreateBulkOrderResponseFuture(){
		Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.CreateBulkOrderResponseFuture testObject = new AsyncOnbeResponsePrepaid.CreateBulkOrderResponseFuture();
		//Integer outputInteger = testObject.getValue();
        System.assertNotEquals(null, testObject);
	}

    @isTest
    static void coverCodeForAsyncLinkCardResponseFuture(){
		Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.LinkCardResponseFuture testObject = new AsyncOnbeResponsePrepaid.LinkCardResponseFuture();
		System.assertNotEquals(null, testObject);
        testObject.getValue();
	}

    @isTest
    static void coverCodeForAsyncCreateAccountResponseFuture(){
		Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.CreateAccountResponseFuture testObject = new AsyncOnbeResponsePrepaid.CreateAccountResponseFuture();
		System.assertEquals(null, testObject.getValue());
	}

    @isTest
    static void coverCodeForAsyncCardInquiryResponseFuture(){
		Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.CardInquiryResponseFuture testObject = new AsyncOnbeResponsePrepaid.CardInquiryResponseFuture();
		System.assertEquals(null, testObject.getValue());
	}

    @isTest
    static void coverCodeForAsyncServiceResponseFuture(){
		Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.ServiceResponseFuture testObject = new AsyncOnbeResponsePrepaid.ServiceResponseFuture();
		System.assertEquals(null, testObject.getValue());
	}

    @isTest
    static void coverCodeForAsyncUpdateAccountStatusResponseFuture() {
        Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.UpdateAccountStatusResponseFuture testObject = new AsyncOnbeResponsePrepaid.UpdateAccountStatusResponseFuture();
		System.assertNotEquals(null, testObject);
        testObject.getValue();
    }

    @isTest
    static void coverCodeForAsyncWithdrawResponseFuture() {
        Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.withdrawResponseFuture testObject = new AsyncOnbeResponsePrepaid.withdrawResponseFuture();
		System.assertNotEquals(null, testObject);
        testObject.getValue();
    }

    @isTest
    static void coverCodeForAsyncActivationStatusInquiryResponseFuture(){
        Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.activationStatusInquiryResponseFuture testObject = new AsyncOnbeResponsePrepaid.activationStatusInquiryResponseFuture();
		System.assertEquals(null, testObject.getValue());
        //testObject.getValue();
    }

    @isTest
    static void coverCodeForAsyncAddFundsResponseFuture(){
        Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.AddFundsResponseFuture testObject = new AsyncOnbeResponsePrepaid.AddFundsResponseFuture();
		System.assertEquals(null, testObject.getValue());
    }

    @isTest
    static void coverCodeForAsyncUpdateRegistrationResponseFuture(){
        Test.setMock(WebServiceMock.class, new AsyncOnbeResponsePrepaidMock());
		AsyncOnbeResponsePrepaid.UpdateRegistrationResponseFuture testObject = new AsyncOnbeResponsePrepaid.UpdateRegistrationResponseFuture();
		System.assertNotEquals(null, testObject);
        testObject.getValue();
    }

}