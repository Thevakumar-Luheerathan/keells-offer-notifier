import ballerina/http;

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
    string itemsWithExpPriceHtml = "";
    string itemsWithOfferHtml = "";

    if itemsWithOffer.length() > 0 {
        itemsWithOfferHtml =string `<h2>Items with Offer</h2>
                                            <table>
                                                <thead>
                                                    <tr>
                                                        <th>Item Name</th>
                                                        <th>Original Price</th>
                                                        <th>Discount Price</th>
                                                        <th>Discount Percentage</th>
                                                    </tr>
                                                </thead>
                                                <tbody>${getOutputItemHtml(itemsWithOffer)}
                                                </tbody>
                                            </table>` ;

    }
    if itemsWithExpectedPrice.length() > 0 {
                itemsWithExpPriceHtml =string `<h2>Items with Offer</h2>
                                            <table>
                                                <thead>
                                                    <tr>
                                                        <th>Item Name</th>
                                                        <th>Original Price</th>
                                                        <th>Discount Price</th>
                                                        <th>Discount Percentage</th>
                                                    </tr>
                                                </thead>
                                                <tbody>${getOutputItemHtml(itemsWithExpectedPrice)}
                                                </tbody>
                                            </table>` ;
    }
    content = string `<!DOCTYPE html>
                        <html lang="en">
                        <head>
                            <meta charset="UTF-8">
                            <meta name="viewport" content="width=device-width, initial-scale=1.0">
                            <title>Product Offers and Expected Prices</title>
                            <style>
                                body {
                                    font-family: Arial, sans-serif;
                                    margin: 0;
                                    padding: 0;
                                    background-color: #f5f5f5;
                                }
                                .container {
                                    width: 100%;
                                    max-width: 600px;
                                    margin: 20px auto;
                                    background-color: #ffffff;
                                    border-radius: 8px;
                                    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
                                    padding: 20px;
                                }
                                h2 {
                                    color: #333;
                                }
                                table {
                                    width: 100%;
                                    border-collapse: collapse;
                                    margin-bottom: 20px;
                                }
                                th, td {
                                    text-align: left;
                                    padding: 10px;
                                    border-bottom: 1px solid #ddd;
                                }
                                th {
                                    background-color: #4CAF50;
                                    color: white;
                                }
                                .discount {
                                    color: #e74c3c;
                                }
                                .expected {
                                    color: #2980b9;
                                }
                            </style>
                        </head>
                        <body>
                            <div class="container">${itemsWithOfferHtml}${itemsWithExpPriceHtml}</div>
                        </body>
                        </html>`;
    check sendEmail(content);
}
