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
    decimal discountPrice?;
    decimal discountPercentage?;
|};

type ItemsToCheckForPrice record {|
    string name;
    decimal maxPrice;
|};
