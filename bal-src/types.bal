type ItemDetailsList record {
    string name;
    string longDescription;
    decimal amount;
    boolean isPromotionApplied;
    decimal promotionDiscountValue;
};

type Result record {
    ItemDetailsList[] itemDetailsList;

};

type ErrorList record {|
    int errorType;
    string statusMessage;
    string errorMessage;
    string resourceCode;
|};

type ItemsResponse record {|
    int statusCode;
    Result result;
    ErrorList[] errorList;
|};

type OutputItem record {|
    string name;
    decimal originalPrice;
    decimal|string discountPrice = "--";
    decimal|string discountPercentage = 0;
|};

type ItemsToCheckForPrice record {|
    string name;
    decimal maxPrice;
|};
