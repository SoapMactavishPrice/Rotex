global class MockHttpResponseGenerator1 implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"d":{"results":[]}}'); // Minimal dummy JSON
        res.setStatusCode(200);
        return res;
    }
}