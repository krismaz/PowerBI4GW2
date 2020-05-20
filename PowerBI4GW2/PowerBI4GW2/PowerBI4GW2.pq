// This file contains your Data Connector logic
section PowerBI4GW2;

//https://docs.microsoft.com/en-us/power-query/helperfunctions#tabletonavigationtable
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

DefaultRequestHeaders = [
    Accept = "application/json",
    UserAgent = "PowerBI4GW2",
    #"Content-Type" = "application/json"
    ];



QueryRest = (url as text, page as number) as record =>
    let
        response = Web.Contents(url, [ Headers = DefaultRequestHeaders, Query = [page =  Number.ToText(page)], ApiKeyName="access_token"]), 
        body = Json.Document(response),
        metadata = Value.Metadata(response)[Headers]
    in
        [data = body, metadata = metadata, page = page];



[DataSource.Kind="PowerBI4GW2", Publish="PowerBI4GW2.Publish"]
shared PowerBI4GW2.Contents =  Value.ReplaceType(PowerBI4GW2NavTable, type function () as any);


PowerBI4GW2NavTable = () as table =>
     let
        objects = #table(
            {"Name",     "Data",                "ItemKind",     "ItemName",     "IsLeaf"},{
            {"HistoryBuys",   PaginateGW2("https://api.guildwars2.com/v2/commerce/transactions/history/buys"),   "Table",       "Table",       true},        
            {"HistorySells",   PaginateGW2("https://api.guildwars2.com/v2/commerce/transactions/history/sells"),   "Table",       "Table",       true},         
            {"CurrentBuys",   PaginateGW2("https://api.guildwars2.com/v2/commerce/transactions/current/buys"),   "Table",       "Table",       true},        
            {"CurrentSells",   PaginateGW2("https://api.guildwars2.com/v2/commerce/transactions/current/sells"),   "Table",       "Table",       true},            
            {"Silver_Items",   QueryBasicSilverData(),   "Table",       "Table",       true}          
            
            }),
        navtable = Table.ToNavigationTable(objects,{"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navtable;



PaginateGW2 = (url as text) as any =>
     let
        pages = List.Generate(
            () => QueryRest(url, 0),            
            (lastPage) =>  lastPage <> null ,    
            (lastPage) =>  
                    if
                        lastPage[page] + 1 < Number.FromText(lastPage[metadata][#"X-Page-Total"])
                    then
                        QueryRest(url, lastPage[page] + 1)
                    else 
                        null,
            (page) => page[data]
        ),
        entries = List.Combine(pages),
        table= Table.FromRecords(entries, null, MissingField.UseNull)
     in
        table;

QueryBasicSilverData = () as table =>
    let
        response = Web.Contents("https://api.silveress.ie/gw2/v1/items/json", [ Headers = DefaultRequestHeaders, Query = [beautify =  "min", fields="id,buy_price,sell_price,name,type,rarity"]]), 
        body = Json.Document(response),
        table= Table.FromRecords(body, null, MissingField.UseNull)
    in
        table;

// Data Source Kind description
PowerBI4GW2 = [
    Authentication = [
        Key = [Label = "Token", KeyLabel = "Token"]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
PowerBI4GW2.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://api.guildwars2.com/v2",
    SourceImage = PowerBI4GW2.Icons,
    SourceTypeImage = PowerBI4GW2.Icons
];

PowerBI4GW2.Icons = [
    Icon16 = { Extension.Contents("Orbit_for_PowerBI16.png"), Extension.Contents("Orbit_for_PowerBI20.png"), Extension.Contents("Orbit_for_PowerBI24.png"), Extension.Contents("Orbit_for_PowerBI32.png") },
    Icon32 = { Extension.Contents("Orbit_for_PowerBI32.png"), Extension.Contents("Orbit_for_PowerBI40.png"), Extension.Contents("Orbit_for_PowerBI48.png"), Extension.Contents("Orbit_for_PowerBI64.png") }
];
