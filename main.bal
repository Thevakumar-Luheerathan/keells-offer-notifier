import ballerina/http;

configurable string[] itemsToCheckForOffer = ?;
configurable ItemsToCheckForPrice[] itemsToCheckForPrice = ?;

final http:Client keelsEP = check new ("https://zebraliveback.keellssuper.com");

public function main() returns error? {
    http:Response guestLoginRes = check getGuestLogin();
    http:Cookie[] cookies = guestLoginRes.getCookies();
    string cookieHeader = retrieveCookieHeader(cookies);
    string userSesseionId = getUserSessionId(cookies);
    OutputItem[] itemsWithOffer = check checkItemsWithOffer(cookieHeader, userSesseionId);
    OutputItem[] itemsWithExpectedPrice = check checkItemsWithPrice(cookieHeader, userSesseionId);
    if itemsWithExpectedPrice.length() == 0 && itemsWithOffer.length() == 0 {
        return;
    }
    string content = "";
    if itemsWithOffer.length() > 0 {
        content = content + "Items with offer\n--------------------------------------\n" + 
        getOutputItemString(itemsWithOffer) + "\n";
    }
    if itemsWithExpectedPrice.length() > 0 {
        content = content + "Items with expected price\n--------------------------------------\n " + 
        getOutputItemString(itemsWithExpectedPrice) + "\n";
    }
    check sendEmail(content);
}

function getOutputItemString(OutputItem[] outputItems) returns string {
    string outputString = "";
    foreach OutputItem outItem in outputItems {
        string originalPrice = outItem.originalPrice.toString();
        string discountPrice = outItem.discountPrice.toString();
        string discountPercentage = outItem.discountPercentage.toString();
        string itemString = string `outItem.name.toUpperAscii()${"\n"}
        Original Price: ${originalPrice}${"\n"}Discount Price: ${discountPrice}
        ${"\n"}Discount Percentage: ${discountPercentage}${"\n"}${"\n"}`;
        outputString = outputString + itemString;
    }
    return outputString;
}

isolated function checkItemsWithOffer(string cookieHeader, string userSesseionId) returns OutputItem[]|error {
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
    foreach ItemsToCheckForPrice item in itemsToCheckForPrice {
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
