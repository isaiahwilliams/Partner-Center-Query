section PartnerCenter;

// OAuth configuration settings

authorize_uri = "https://login.microsoftonline.com/common/oauth2/authorize";
client_id = Text.FromBinary(Extension.Contents("client_id")); 
logout_uri = "https://login.microsoftonline.com/logout.srf";
redirect_uri = "https://preview.powerbi.com/views/oauthredirect.html";
token_uri = "https://login.microsoftonline.com/common/oauth2/token";

// Partner Center configuration settings

client_name = "Partner Center Query";
sdk_version = "1.1";

// Export available functions

[DataSource.Kind = "PartnerCenter"]
shared PartnerCenter.AzureRateCard = Value.ReplaceType(PC.AzureRateCard, type function () as Table.Type);

[DataSource.Kind = "PartnerCenter"]
shared PartnerCenter.AzureUsage = Value.ReplaceType(PC.AzureUsage, type function () as Table.Type);

[DataSource.Kind = "PartnerCenter", Publish = "PartnerCenter.Publish"]
shared PartnerCenter.Customers = Value.ReplaceType(PC.Customers, type function () as Table.Type);

[DataSource.Kind = "PartnerCenter"]
shared PartnerCenter.CustomersDelta = Value.ReplaceType(PC.CustomersDelta, type function () as Table.Type);

[DataSource.Kind = "PartnerCenter"]
shared PartnerCenter.Offers = Value.ReplaceType(PC.Offers, type function () as Table.Type);

[DataSource.Kind = "PartnerCenter"]
shared PartnerCenter.OrdersDelta = Value.ReplaceType(PC.OrdersDelta, type function () as Table.Type);

[DataSource.Kind = "PartnerCenter"]
shared PartnerCenter.PartnerLegalProfile = Value.ReplaceType(PC.PartnerLegalProfile, type function () as Table.Type);

[DataSource.Kind = "PartnerCenter"]
shared PartnerCenter.Subscriptions = Value.ReplaceType(PC.Subscriptions, type function () as Table.Type);

[DataSource.Kind = "PartnerCenter"]
shared PartnerCenter.SubscriptionsDelta = Value.ReplaceType(PC.SubscriptionsDelta, type function () as Table.Type);

// Data source link description

PartnerCenter = [
    Authentication = [
        OAuth = [
            FinishLogin = FinishLogin,
            Logout = Logout,
            Refresh = Refresh,
            StartLogin = StartLogin
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data source UI publishing description

PartnerCenter.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/isaiahwilliams/Partner-Center-Query/",
    SourceImage = PartnerCenter.Icons,
    SourceTypeImage = PartnerCenter.Icons
];

PartnerCenter.Icons = [
    Icon16 = { Extension.Contents("PartnerCenter16.png"), Extension.Contents("PartnerCenter20.png"), Extension.Contents("PartnerCenter24.png"), Extension.Contents("PartnerCenter32.png") },
    Icon32 = { Extension.Contents("PartnerCenter32.png"), Extension.Contents("PartnerCenter40.png"), Extension.Contents("PartnerCenter48.png"), Extension.Contents("PartnerCenter64.png") }
];

// OAuth Implementation

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code])
    in
        result;

Logout = (token) => logout_uri;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            client_id = client_id,  
            redirect_uri = redirect_uri,
            resource = "https://api.partnercenter.microsoft.com",
            state = state,
            response_type = "code",
            response_mode = "query",
            login = "login"    
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 860,
            WindowWidth = 1024,
            Context = null
        ];

TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            client_id = client_id,
            grant_type = grantType,
            redirect_uri = redirect_uri
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400, 403, 500} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

// Partner Center Audit Records

PC.AuditRecords = (filter as text) =>
    let
        endDate = DateTime.LocalNow(), 
        startDate = DateTime.LocalNow() - #duration(31, 0, 0, 0),
        
        request = PC.GetPagedResources("auditrecords?startDate=" & DateTime.ToText(startDate, "yyyy-MM-dd") & "&endDate=" & DateTime.ToText(endDate, "yyyy-MM-dd") & "&filter=" & filter),
        auditTable = Table.FromList(request, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        expandedList = Table.ExpandListColumn(auditTable, "Column1"),
        expandedRecords = Table.ExpandRecordColumn(expandedList, "Column1", {"partnerId", "customerId", "customerName", "userPrincipalName", "resourceType", "resourceNewValue", "operationType", "operationDate", "operationStatus"}, {"partnerId", "customerId", "customerName", "userPrincipalName", "resourceType", "resourceNewValue", "operationType", "operationDate", "operationStatus"}),
        addConvertedResourceValue = Table.AddColumn(expandedRecords, "Custom", each Json.Document([resourceNewValue])),
        removedResourceNewValue = Table.RemoveColumns(addConvertedResourceValue, {"resourceNewValue"})
    in
        removedResourceNewValue;

PC.CustomersDelta = () => 
    let
        records = PC.AuditRecords("{""Field"":""ResourceType"",""Value"":""Customer"",""Operator"":0}"),
        transformedDate = Table.TransformColumnTypes(records, {{"operationDate", type datetimezone}}),
        sortedRows = Table.Sort(transformedDate, {{"operationDate", Order.Ascending}})
    in 
        records;

PC.OrdersDelta = () => 
    let
        records = PC.AuditRecords("{""Field"":""ResourceType"",""Value"":""Order"",""Operator"":0}"),
        expandedResource = Table.ExpandRecordColumn(records, "Custom", {"Id", "BillingCycle", "LineItems", "CreationDate"}, {"OrderId", "BillingCycle", "LineItems", "CreationDate"}),
        expandedLineItems = Table.ExpandListColumn(expandedResource, "LineItems"),
        expandedLineItemsRecords = Table.ExpandRecordColumn(expandedLineItems, "LineItems", {"LineItemNumber", "OfferId", "SubscriptionId", "ParentSubscriptionId", "FriendlyName", "Quantity", "PartnerIdOnRecord"}, {"LineItemNumber", "OfferId", "SubscriptionId", "ParentSubscriptionId", "FriendlyName", "Quantity", "PartnerIdOnRecord"}),
        transformedDate = Table.TransformColumnTypes(expandedLineItemsRecords, {{"operationDate", type datetimezone}}),
        sortedRows = Table.Sort(transformedDate, {{"operationDate", Order.Ascending}})
    in 
        sortedRows;

PC.SubscriptionsDelta = () => 
    let
        records = PC.AuditRecords("{""Field"":""ResourceType"",""Value"":""Subscription"",""Operator"":0}"),
        expandedCustom = Table.ExpandRecordColumn(records, "Custom", {"Id", "OfferId", "OfferName", "FriendlyName", "Quantity", "UnitType", "ParentSubscriptionId", "HasPurchasableAddons", "CreationDate", "EffectiveStartDate", "CommitmentEndDate", "Status", "AutoRenewEnabled", "IsTrial", "BillingType", "BillingCycle", "SuspensionReasons", "ContractType", "OrderId"}, {"Id", "OfferId", "OfferName", "FriendlyName", "Quantity", "UnitType", "ParentSubscriptionId", "HasPurchasableAddons", "CreationDate", "EffectiveStartDate", "CommitmentEndDate", "Status", "AutoRenewEnabled", "IsTrial", "BillingType", "BillingCycle", "SuspensionReasons", "ContractType", "OrderId"}),
        transformedDate = Table.TransformColumnTypes(expandedCustom, {{"operationDate", type datetimezone}}),
        sortedRows = Table.Sort(transformedDate, {{"operationDate", Order.Ascending}})
    in 
        sortedRows;

// Partner Center Azure Resources

PC.AzureRateCard = () =>
    let
        rateCardRequest = PC.Request("ratecards/azure"),
        meters = rateCardRequest[meters],
        metersTable = Table.FromList(meters, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        metersExpanded = Table.ExpandRecordColumn(metersTable, "Column1", {"id", "name", "rates", "tags", "category", "subcategory", "region", "unit", "includedQuantity", "effectiveDate"}, {"id", "name", "rates", "tags", "category", "subcategory", "region", "unit", "includedQuantity", "effectiveDate"})
    in 
        metersExpanded;

PC.AzureUsage = () =>
    let
        GetAzureUsage = (customerId as text, subscriptionId as text, startTime as text, endTime as text) =>
            let 
                usageList = PC.GetPagedResources("customers/" & customerId & "/subscriptions/" & subscriptionId & "/utilizations/azure?start_time=" & startTime & "&end_time=" & endTime & "&granularity=daily"),
                usageTable = Table.FromList(usageList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                usageTableExpanded = Table.ExpandListColumn(usageTable, "Column1"),
                usageRecordExpanded = Table.ExpandRecordColumn(usageTableExpanded, "Column1", {"usageStartTime", "usageEndTime", "resource", "quantity", "unit", "instanceData"}, {"usageStartTime", "usageEndTime", "resource", "quantity", "unit", "instanceData"}),
                resourceExpanded = Table.ExpandRecordColumn(usageRecordExpanded, "resource", {"id", "name", "category", "subcategory", "region"}, {"id", "name", "category", "subcategory", "region"}),
                instanceDataExpanded = Table.ExpandRecordColumn(resourceExpanded, "instanceData", {"resourceUri", "location", "partNumber", "orderNumber", "tags"}, {"resourceUri", "location", "partNumber", "orderNumber", "tags"})
            in
                instanceDataExpanded,
    
        endTime = DateTime.LocalNow(), 
        startTime = DateTime.LocalNow() - #duration(90, 0, 0, 0),
        rateCard = PC.AzureRateCard(),
        subscriptions = PC.Subscriptions(), 
        azureSubscriptions = Table.SelectRows(subscriptions, each ([billingType] = "usage") and ([status] = "active")),
        narrowed = Table.SelectColumns(azureSubscriptions, {"subscriptionId","tenantId"}),
        usage = Table.AddColumn(narrowed, "Custom", each GetAzureUsage([tenantId], [subscriptionId], DateTime.ToText(startTime, "yyyy-MM-ddTHH:mm:ssZ"), DateTime.ToText(endTime, "yyyy-MM-ddTHH:mm:ssZ"))),
        usageExpanded = Table.ExpandTableColumn(usage, "Custom", {"usageStartTime", "usageEndTime", "id", "name", "category", "subcategory", "region", "quantity", "unit", "resourceUri", "location", "partNumber", "orderNumber", "tags"}, {"usageStartTime", "usageEndTime", "id", "name", "category", "subcategory", "region", "quantity", "unit", "resourceUri", "location", "partNumber", "orderNumber", "tags"}),
        removeRowsWithNoUsage = Table.SelectRows(usageExpanded, each [usageStartTime] <> null),
        usageAndMeterTable = Table.NestedJoin(removeRowsWithNoUsage, {"id"}, rateCard, {"id"}, "Meter", JoinKind.LeftOuter),
        removeRowsWith1Core = Table.SelectRows(usageAndMeterTable, each not Text.Contains([id], "core")),
        meterColumnExpanded = Table.ExpandTableColumn(removeRowsWith1Core, "Meter", {"rates", "includedQuantity", "effectiveDate"}, {"rates", "includedQuantity", "effectiveDate"}),
        quantityConversion = Table.TransformColumnTypes(meterColumnExpanded, {{"quantity", type number}}),
        includePrice = Table.AddColumn(quantityConversion, "price", each [quantity] * Double.From([rates][0])),
        typeConversion = Table.TransformColumnTypes(includePrice,{{"usageEndTime", type datetimezone}, {"usageStartTime", type datetimezone}, {"price", Currency.Type}})
    in
        typeConversion;

// Partner Center Customers

PC.Customers = () =>
    let
        customersList = PC.GetPagedResources("customers"), 
        customersListTable = Table.FromList(customersList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        customersRecordTable = Table.ExpandListColumn(customersListTable, "Column1"),
        customersTable = Table.ExpandRecordColumn(customersRecordTable, "Column1", {"companyProfile", "relationshipToPartner"}, {"companyProfile", "relationshipToPartner"}),
        customersInfoTable = Table.ExpandRecordColumn(customersTable, "companyProfile", {"tenantId", "domain", "companyName"}, {"tenantId", "domain", "companyName"})
    in
        customersInfoTable;

// Partner Center Offers

PC.Offers = () =>
    let 
        profile = PC.PartnerLegalProfile(), 
        offers = PC.Request("offers?country=" & profile{0}[country]),
        items = offers[items],
        convertedTable = Table.FromList(items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        expandedColumn = Table.ExpandRecordColumn(convertedTable, "Column1", {"id", "name", "description", "minimumQuantity", "maximumQuantity", "rank", "uri", "locale", "country", "category", "prerequisiteOffers", "isAddOn", "hasAddOns", "isAvailableForPurchase", "billing", "supportedBillingCycles", "isAutoRenewable", "isInternal", "conversionTargetOffers", "reselleeQualifications", "resellerQualifications", "salesGroupId", "isTrial", "acquisitionType", "supportedCatalogTypes", "product", "unitType", "upgradeTargetOffers"}, {"id", "name", "description", "minimumQuantity", "maximumQuantity", "rank", "uri", "locale", "country", "category", "prerequisiteOffers", "isAddOn", "hasAddOns", "isAvailableForPurchase", "billing", "supportedBillingCycles", "isAutoRenewable", "isInternal", "conversionTargetOffers", "reselleeQualifications", "resellerQualifications", "salesGroupId", "isTrial", "acquisitionType", "supportedCatalogTypes", "product", "unitType", "upgradeTargetOffers"})
    in 
        expandedColumn;
        
// Partner Center Partner Details

PC.PartnerLegalProfile = () => 
    let 
        rawProfile = PC.Request("profiles/legalbusiness?vettingVersion=Current"),
        profile = #table({"CompanyName", "Address"}, {{rawProfile[companyName], rawProfile[address]}}),
        expandedAddress = Table.ExpandRecordColumn(profile, "Address", {"country", "city", "state", "addressLine1", "addressLine2", "postalCode", "firstName", "lastName", "phoneNumber"}, {"country", "city", "state", "addressLine1", "addressLine2", "postalCode", "firstName", "lastName", "phoneNumber"})
    in 
        expandedAddress;

// Partner Center Requests

PC.ContinuationRequest = (relativePath as text, continuationToken as text) =>
    let 
        source = Json.Document(Web.Contents("https://api.partnercenter.microsoft.com/v1/",
            [
                Headers = [
                    #"Accept" = "application/json",
                    #"MS-ContinuationToken" = continuationToken,
                    #"MS-PartnerCenter-Client" = client_name,
                    #"MS-SdkVersion" = sdk_version
                ], 
                RelativePath = relativePath
            ]
        ))
    in 
        source;

PC.GetPagedResources = (relativePath as text) => 
    let
        GetResources = 
            (relativePath as text) as record =>
            let
                data = PC.Request(relativePath),
                items = try data[items] otherwise null, 
                next = try data[links][next] otherwise null,
                res = [Items = items, Next = next]
            in 
                res,

        GetResourcesContinuation = 
            (nextData) as record =>
            let
                relativePath = nextData[uri],
                data = PC.ContinuationRequest(relativePath, nextData[headers]{0}[value]),
                items = try data[items] otherwise null, 
                next = try data[links][next] otherwise null,
                res = [Items = items, Next = next]
            in 
                res,

        resourcesList = 
            List.Generate(
                () => [result = GetResources(relativePath)], 
                each [result][Items] <> null, 
                each [result = GetResourcesContinuation([result][Next])],
                each [result][Items])
    in
        resourcesList;

PC.Request = (relativePath as text) =>
    let 
        source = Json.Document(Web.Contents("https://api.partnercenter.microsoft.com/v1/",
            [
                Headers = [
                    #"Accept" = "application/json",
                    #"MS-PartnerCenter-Client" = client_name,
                    #"MS-SdkVersion" = sdk_version
                ], 
                ManualStatusHandling = {400, 403, 500},
                RelativePath = relativePath
            ]
        ))
    in 
        source;

// Partner Center Subscriptions

PC.Subscriptions = () => 
    let
        customers = PC.Customers(), 

        GetSubscriptions = (customerId as text) => 
            let
                subscriptionsRequest = PC.Request("customers/" & customerId & "/subscriptions"),
                items = subscriptionsRequest[items],
                subscriptions = Table.FromList(items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                subscriptionsExpanded = Table.ExpandRecordColumn(subscriptions, "Column1", {"id", "offerId", "offerName", "friendlyName", "quantity", "unitType", "creationDate", "effectiveStartDate", "commitmentEndDate", "status", "autoRenewEnabled", "billingType", "suspensionReasons", "contractType", "orderId", "isTrial", "hasPurchasableAddons", "actions"}, {"subscriptionId", "offerId", "offerName", "friendlyName", "quantity", "unitType", "creationDate", "effectiveStartDate", "commitmentEndDate", "status", "autoRenewEnabled", "billingType", "suspensionReasons", "contractType", "orderId", "isTrial", "hasPurchasableAddons", "actions"}),
                subscriptionsFiltered = Table.RemoveRowsWithErrors(subscriptionsExpanded, "{Column1"),    
                subscriptionsRemoved  = Table.SelectRows(subscriptionsExpanded, each [subscriptionId] <> null),
                subscriptionsAppended = Table.AddColumn(subscriptionsRemoved, "tenantId", each customerId)
            in
                subscriptionsAppended, 

        customersSubscriptions = Table.AddColumn(customers, "Custom", each try GetSubscriptions([tenantId]) otherwise null),
        removeNoSubErrors = Table.RemoveRowsWithErrors(customersSubscriptions, {"Custom"}),
        customExpand = Table.ExpandListColumn(removeNoSubErrors, "Custom"),
        expanded = Table.ExpandRecordColumn(customExpand, "Custom", {"subscriptionId", "offerId", "offerName", "friendlyName", "quantity", "unitType", "creationDate", "effectiveStartDate", "commitmentEndDate", "status", "autoRenewEnabled", "billingType", "suspensionReasons", "contractType", "orderId", "isTrial", "hasPurchasableAddons", "actions"}, {"subscriptionId", "offerId", "offerName", "friendlyName", "quantity", "unitType", "creationDate", "effectiveStartDate", "commitmentEndDate", "status", "autoRenewEnabled", "billingType", "suspensionReasons", "contractType", "orderId", "isTrial", "hasPurchasableAddons", "actions"})
    in
        expanded;