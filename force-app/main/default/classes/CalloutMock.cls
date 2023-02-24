@isTest
public with sharing class CalloutMock implements HttpCalloutMock {

    private List<HttpResponse> httpResponses = new List<HttpResponse>();
    private Integer responseIndex = 0;

    public CalloutMock(List<HttpResponse> httpResponses) {
        httpResponses.addAll(httpResponses);
    }

    public CalloutMock(HttpResponse httpResponse) {
        addResponse(httpResponse);
    }

    public CalloutMock(String body) {
        addResponse(200, body);
    }

    public CalloutMock(Integer code, String body) {
        addResponse(code, body);
    }

    public void addResponse(HttpResponse response) {
        httpResponses.add(response);
    }

    public void addResponse(String body) {
        addResponse(200, body);
    }

    public void addResponse(Integer code, String body) {
        HttpResponse httpResponse = new HttpResponse();
        httpResponse.setBody(body);
        httpResponse.setStatusCode(code);
        httpResponses.add(httpResponse);
    }

    public HttpResponse respond(HttpRequest httpRequest) {
        return httpResponses[responseIndex++];
    }

}