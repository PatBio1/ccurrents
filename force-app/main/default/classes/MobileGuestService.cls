/*
 * https://salesforceprofs.com/salesforce-to-salesforce-rest-api-integration/
 */
@RestResource(urlMapping='/mobile/guest/*')
global with sharing class MobileGuestService {

    public static final String ENDPOINT = 'callout:Callback/services/apexrest/mobile/guest/';
    public static final String GET_DOWNLOAD_URL_PATH = 'get-download-url';
    public static final String SET_USER_PHOTO_PATH = 'set-user-photo';

    @HttpPost
    global static void doPost() {
        String path = RestContext.request.requestURI.substring(RestContext.request.requestURI.lastIndexOf('/') + 1);
        String request = RestContext.request.requestBody.toString();
        Object response;

        System.debug('### Guest Service Path - ' + path);
        System.debug('### Guest Service Request - ' + request);

        if (path == GET_DOWNLOAD_URL_PATH) {
            GetDownloadUrlRequest getDownloadUrlRequest = (GetDownloadUrlRequest) JSON.deserialize(request, GetDownloadUrlRequest.class);
            response = getDownloadUrl(getDownloadUrlRequest);
        }

        else if (path == SET_USER_PHOTO_PATH) {
            SetUserPhotoRequest SetUserPhotoRequest = (SetUserPhotoRequest) JSON.deserialize(request, SetUserPhotoRequest.class);
            setUserPhoto(SetUserPhotoRequest);
        }

        if (response != null) {
            System.debug('### Guest Service Response - ' + JSON.serialize(response, true));

            RestContext.response.addHeader('Content-Type', 'application/json');
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(response, true));
        }
    }

    private static GetDownloadUrlResponse getDownloadUrl(GetDownloadUrlRequest request) {
        ContentDistribution contentDistribution = new ContentDistribution();
        contentDistribution.ContentVersionId = request.contentVersionId;
        contentDistribution.Name = 'Mobile Guest';
        contentDistribution.PreferencesAllowViewInBrowser = true;
        contentDistribution.PreferencesLinkLatestVersion = true;
        contentDistribution.PreferencesNotifyOnVisit = false;
        contentDistribution.PreferencesPasswordRequired = false;
        contentDistribution.PreferencesAllowOriginalDownload = true;
        insert contentDistribution;

        GetDownloadUrlResponse response = new GetDownloadUrlResponse();
        response.downloadUrl = [SELECT ContentDownloadUrl FROM ContentDistribution WHERE Id = :contentDistribution.Id].ContentDownloadUrl;
        return response;
    }

    private static void setUserPhoto(SetUserPhotoRequest request) {
        ContentVersion contentVersion = [
            SELECT
                ContentDocumentId
            FROM
                ContentVersion
            WHERE
                Id = :request.contentVersionId
        ];

        // TODO
        // remove ContentDistribution
        // change contendocument owner to new community user
        // change CDL from "user user" record to new community user

        if (!Test.isRunningTest()) {
            ConnectApi.UserProfiles.setPhoto(null, request.userId, contentVersion.ContentDocumentId, null);
        }
    }


    public class GetDownloadUrlRequest {

        public Id contentVersionId {get; set;}

    }

    public class GetDownloadUrlResponse {

        public String downloadUrl {get; set;}

    }

    public class SetUserPhotoRequest {

        public Id userId {get; set;}
        public Id contentVersionId {get; set;}

    }

}