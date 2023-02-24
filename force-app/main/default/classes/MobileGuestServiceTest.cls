@isTest
public with sharing class MobileGuestServiceTest {

    @isTest
    static void testGetDownloadUrl() {
        System.runAs(TestUtil.createAdminUser()) {
            ContentVersion contentVersion = TestUtil.createContentVersion();
            insert contentVersion;

            MobileGuestService.GetDownloadUrlRequest getDownloadUrlRequest = new MobileGuestService.GetDownloadUrlRequest();
            getDownloadUrlRequest.contentVersionId = contentVersion.Id;

            RestContext.request = new RestRequest();
            RestContext.request.requestUri = MobileGuestService.ENDPOINT + MobileGuestService.GET_DOWNLOAD_URL_PATH;
            RestContext.request.requestBody = Blob.valueof(JSON.serialize(getDownloadUrlRequest, true));

            RestContext.response = new RestResponse();

            MobileGuestService.doPost();

            MobileGuestService.GetDownloadUrlResponse getDownloadUrlResponse = (MobileGuestService.GetDownloadUrlResponse) JSON.deserialize(RestContext.response.responseBody.toString(), MobileGuestService.GetDownloadUrlResponse.class);

            System.assertNotEquals(null, getDownloadUrlResponse.downloadUrl);
        }
    }

    @isTest
    static void testSetUserPhoto() {
        System.runAs(TestUtil.createAdminUser()) {
            ContentVersion contentVersion = TestUtil.createContentVersion();
            insert contentVersion;

            MobileGuestService.SetUserPhotoRequest setUserPhotoRequest = new MobileGuestService.SetUserPhotoRequest();
            setUserPhotoRequest.userId = UserInfo.getUserId();
            setUserPhotoRequest.contentVersionId = contentVersion.Id;

            RestContext.request = new RestRequest();
            RestContext.request.requestUri = MobileGuestService.ENDPOINT + MobileGuestService.SET_USER_PHOTO_PATH;
            RestContext.request.requestBody = Blob.valueof(JSON.serialize(setUserPhotoRequest, true));

            RestContext.response = new RestResponse();

            MobileGuestService.doPost();
        }
    }

}