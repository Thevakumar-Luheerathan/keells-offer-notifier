import ballerinax/googleapis.gmail;

configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshToken = ?;
configurable string[] to = ?;

// Initialize the Gmail client
gmail:ConnectionConfig gmailConfig = {
    auth: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken
    }
};
gmail:Client gmailClient = check new (gmailConfig);

function sendEmail(string content) returns error? {
    do {
        gmail:MessageRequest messageRequest = {
            to: to,
            subject: "List of Things Affordable from Keells",
            bodyInText: content
        };
        gmail:Message _ = check gmailClient->/users/me/messages/send.post(messageRequest);
    } on fail error err{
        return error("Error occured while sending email: " + err.message());
    }
}

