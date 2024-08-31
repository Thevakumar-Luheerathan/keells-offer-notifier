import ballerina/http;
import ballerinax/googleapis.gmail;
import ballerinax/googleapis.sheets as sheets;

configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshToken = ?;
configurable string[] to = ?;
configurable string sheetId = ?;

// Initialize the Gmail client
gmail:ConnectionConfig gmailConfig = {
    auth: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken
    }
};

sheets:ConnectionConfig spreadsheetConfig = {
    auth: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshUrl: "https://accounts.google.com/o/oauth2/token",
        refreshToken: refreshToken
    }
};
final gmail:Client gmailClient = check new (gmailConfig);
final sheets:Client spreadsheetClient = check new (spreadsheetConfig);

isolated function sendEmail(string content) returns error? {
    do {
        gmail:MessageRequest messageRequest = {
            to: to,
            subject: "LIST OF THINGS AFFORDABLE FROM KEELLS",
            bodyInHtml: content
        };
        gmail:Message _ = check gmailClient->/users/me/messages/send.post(messageRequest);
    } on fail error err {
        return error("Error occured while sending email: " + err.message());
    }
}

isolated function getItemsWithOffer() returns string[]|error {
    do {
        sheets:Column itemsColumn = check spreadsheetClient->getColumn(sheetId, "with-offer", "A");
        return from string|int|decimal item in itemsColumn.values 
            select <string>item;
    } on fail error err {
        return error(string `Error occured while retrieving items with offer: ${err.message()}`);
    }
}

isolated function getItemsWithExpPrice() returns ItemsToCheckForPrice[]|error {
    do {
        sheets:Column itemsColumn = check spreadsheetClient->getColumn(sheetId, "with-exp-price", "A");
        sheets:Column itemsExpPrice = check spreadsheetClient->getColumn(sheetId, "with-exp-price", "B");
        ItemsToCheckForPrice[] itemsToCheckForPrice = [];
        foreach int i in 0 ... itemsExpPrice.values.length()-1 {
            itemsToCheckForPrice.push({name: itemsColumn.values[i].toString(), maxPrice: check decimal:fromString(<string>itemsExpPrice.values[i])});
        }
        return itemsToCheckForPrice;
    } on fail error err {
        return error(string `Error occured while retrieving items with expected price: ${err.message()}`);
    }
}

isolated function getOutputItemHtml(OutputItem[] outputItems) returns string {
    string outputString = "";
    foreach OutputItem outItem in outputItems {
        string originalPrice = outItem.originalPrice.toString();
        string discountPrice = outItem.discountPrice.toString();
        string discountPercentage = outItem.discountPercentage.toString();
        string itemString = string `<tr>
                                        <td>${outItem.name.toUpperAscii()}</td>
                                        <td>${originalPrice}</td>
                                        <td class="discount">${discountPrice}</td>
                                        <td>${discountPercentage}%</td>
                                    </tr>`;
        outputString = outputString + itemString;
    }
    return outputString;
}

isolated function checkItemsWithOffer(string cookieHeader, string userSesseionId) returns OutputItem[]|error {
    string[] itemsToCheckForOffer = check getItemsWithOffer();
    OutputItem[] outputItems = [];
    foreach string item in itemsToCheckForOffer {
        ItemsResponse itemsRes = check getItemDetails(userSesseionId, cookieHeader, item);
        foreach ItemDetailsList itemDetail in itemsRes.result.itemDetailsList {
            if itemDetail.isPromotionApplied {
                decimal discountPrice = itemDetail.amount - itemDetail.promotionDiscountValue;
                decimal discountPercentage = (itemDetail.promotionDiscountValue / itemDetail.amount) * 100;
                outputItems.push({name: itemDetail.name, originalPrice: itemDetail.amount, discountPrice: discountPrice, discountPercentage: discountPercentage});
            }
        }
    }
    return outputItems;
}

isolated function checkItemsWithPrice(string cookieHeader, string userSesseionId) returns OutputItem[]|error {
    OutputItem[] outputItems = [];
    foreach ItemsToCheckForPrice item in check getItemsWithExpPrice() {
        ItemsResponse itemsRes = check getItemDetails(userSesseionId, cookieHeader, item.name);
        foreach ItemDetailsList itemDetail in itemsRes.result.itemDetailsList {
            decimal actualSellingPrice = itemDetail.amount;
            OutputItem outputItem = {name: itemDetail.name, originalPrice: itemDetail.amount};
            if itemDetail.isPromotionApplied {
                actualSellingPrice = itemDetail.amount - itemDetail.promotionDiscountValue;
                outputItem.discountPrice = actualSellingPrice;
                outputItem.discountPercentage = (itemDetail.promotionDiscountValue / itemDetail.amount) * 100;
            }
            if actualSellingPrice <= item.maxPrice {
                outputItems.push(outputItem);
            }
        }
    }
    return outputItems;
}

isolated function retrieveCookieHeader(http:Cookie[] cookies) returns string {
    string cookieHeader = "";
    foreach http:Cookie cookie in cookies {
        string cookieStrVal = cookie.toStringValue();
        int? semicolonPlace = cookieStrVal.indexOf(";");
        if semicolonPlace == () {
            cookieHeader = cookieHeader + cookieStrVal + ";";
        } else {
            cookieHeader = cookieHeader + cookieStrVal.substring(0, semicolonPlace) + ";";
        }
    }
    return cookieHeader;
}

isolated function getItemDetails(string userSesseionId, string cookieHeader, string item) returns ItemsResponse|error {
    do {
        decimal epVersion = 2.0;
        http:Response offerResponse = check keelsEP->/[epVersion]/Web/GetItemDetails.get({"usersessionid": userSesseionId, "Cookie": cookieHeader},
            fromCount = 0, toCount = 50, outletCode = "SCDR", itemDescription = item,
            itemPricefrom = 0, itemPriceTo = 5000, isPromotionOnly = false, sortBy = "default"
        );
        if offerResponse.statusCode == 200 {
            return check (check offerResponse.getJsonPayload()).cloneWithType(ItemsResponse);
        }
        return error(string `Error occured while retrieving offered items: status code ${offerResponse.statusCode}`);
    } on fail error err {
        return error(string `Error occured while retrieving offered items: ${err.message()}`);
    }
}

isolated function getUserSessionId(http:Cookie[] cookies) returns string {
    from http:Cookie cookie in cookies
    do {
        if cookie.name.includes("auth_cookie_") {
            return cookie.name.substring(12);
        }
    };
    return "";
}

isolated function getGuestLogin() returns http:Response|error {
    http:Request guestLoginReq = new;
    guestLoginReq.setPayload("");
    decimal epVersion = 1.0;
    http:Response|error guestLoginRes = check keelsEP->/[epVersion]/Login/GuestLogin.post(guestLoginReq);
    if guestLoginRes is error {
        return error(string `Error occured during guest session creation ${guestLoginRes.message()}`);
    }
    return guestLoginRes;
}

