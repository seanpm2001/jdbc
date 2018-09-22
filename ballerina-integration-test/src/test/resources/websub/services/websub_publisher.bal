import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerina/websub;

@final string WEBSUB_TOPIC_ONE = "http://one.websub.topic.com";
@final string WEBSUB_TOPIC_TWO = "http://two.websub.topic.com";
@final string WEBSUB_TOPIC_THREE = "http://three.websub.topic.com";
@final string WEBSUB_TOPIC_FOUR = "http://four.websub.topic.com";

boolean remoteTopicRegistered;

websub:WebSubHub webSubHub = startHubAndRegisterTopic();

endpoint websub:Client websubHubClientEP {
    url: webSubHub.hubUrl
};

endpoint http:Listener publisherServiceEP {
    port:8080
};

service<http:Service> publisher bind publisherServiceEP {
    @http:ResourceConfig {
        methods: ["GET", "HEAD"]
    }
    discover(endpoint caller, http:Request req) {
        http:Response response;
        // Add a link header indicating the hub and topic
        websub:addWebSubLinkHeader(response, [webSubHub.hubUrl], WEBSUB_TOPIC_ONE);
        response.statusCode = 202;
        caller->respond(response) but {
            error e => log:printError("Error responding on ordering", err = e)
        };
    }

    @http:ResourceConfig {
        methods: ["POST"]
    }
    notify(endpoint caller, http:Request req) {
        remoteRegisterTopic();
        json jsonPayload = check req.getJsonPayload();
        string mode = jsonPayload.mode.toString();
        string contentType = jsonPayload.content_type.toString();

        http:Response response;
        response.statusCode = 202;
        caller->respond(response) but {
            error e => log:printError("Error responding on notify request", err = e)
        };

        if (mode == "internal") {
            webSubHub.publishUpdate(WEBSUB_TOPIC_ONE, getPayloadContent(contentType, mode)) but {
                error e => log:printError("Error publishing update directly", err = e)
            };
        } else {
            websubHubClientEP->publishUpdate(WEBSUB_TOPIC_ONE, getPayloadContent(contentType, mode)) but {
                error e => log:printError("Error publishing update remotely", err = e)
            };
        }
    }
}

service<http:Service> publisherTwo bind publisherServiceEP {
    @http:ResourceConfig {
        methods: ["GET", "HEAD"]
    }
    discover(endpoint caller, http:Request req) {
        http:Response response;
        // Add a link header indicating the hub and topic
        websub:addWebSubLinkHeader(response, [webSubHub.hubUrl], WEBSUB_TOPIC_FOUR);
        response.statusCode = 202;
        caller->respond(response) but {
            error e => log:printError("Error responding on ordering", err = e)
        };
    }

    @http:ResourceConfig {
        methods: ["POST"]
    }
    notify(endpoint caller, http:Request req) {
        http:Response response;
        response.statusCode = 202;
        caller->respond(response) but {
            error e => log:printError("Error responding on notify request", err = e)
        };

        webSubHub.publishUpdate(WEBSUB_TOPIC_THREE, {"action":"publish","mode":"internal-hub"}) but {
            error e => log:printError("Error publishing update directly", err = e)
        };

        webSubHub.publishUpdate(WEBSUB_TOPIC_FOUR, {"action":"publish","mode":"internal-hub-two"}) but {
            error e => log:printError("Error publishing update directly", err = e)
        };
    }
}

function startHubAndRegisterTopic() returns websub:WebSubHub {
    websub:WebSubHub internalHub = websub:startHub(9191, remotePublishingEnabled = true) but {
        websub:HubStartedUpError hubStartedUpErr => hubStartedUpErr.startedUpHub
    };
    internalHub.registerTopic(WEBSUB_TOPIC_ONE) but {
        error e => log:printError("Error registering topic directly", err = e)
    };
    internalHub.registerTopic(WEBSUB_TOPIC_THREE) but {
        error e => log:printError("Error registering topic directly", err = e)
    };
    internalHub.registerTopic(WEBSUB_TOPIC_FOUR) but {
        error e => log:printError("Error registering topic directly", err = e)
    };
    return internalHub;
}

function remoteRegisterTopic()  {
    if (remoteTopicRegistered) {
        return;
    }
    websubHubClientEP->registerTopic(WEBSUB_TOPIC_TWO) but {
        error e => log:printError("Error registering topic remotely", err = e)
    };
    remoteTopicRegistered = true;
}

function getPayloadContent(string contentType, string mode) returns string|xml|json|byte[]|io:ByteChannel {
    string errorMessage = "unknown content type";
    if (contentType == "" || contentType == "json") {
        if (mode == "internal") {
            return {"action":"publish","mode":"internal-hub"};
        } else {
            return {"action":"publish","mode":"remote-hub"};
        }
    } else if (contentType == "string") {
        if (mode == "internal") {
            return "Text update for internal Hub";
        } else {
            return "Text update for remote Hub";
        }
    } else if (contentType == "xml") {
        if (mode == "internal") {
            return xml `<websub><request>Notification</request><type>Internal</type></websub>`;
        } else {
            return xml `<websub><request>Notification</request><type>Remote</type></websub>`;
        }
    } else if (contentType == "byte[]" || contentType == "io:ByteChannel") {
        errorMessage = "content type " + contentType + " not yet supported with WebSub tests";
    }
    error e = { errorMessage: errorMessage };
    throw e;
}
