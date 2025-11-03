codeunit 50402 "SharePoint Graph Connector"
{
    Access = Public;

    var
        SharePointSetup: Record "SharePoint Setup";
        LastError: Text;
        HttpClient: HttpClient;
        TempBlob: Codeunit "Temp Blob";
        IsInitialized: Boolean;

    procedure GetLastError(): Text
    begin
        exit(LastError);
    end;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;

        if not SharePointSetup.Get('3PL') then
            Error('SharePoint Setup not found for key 3PL');

        IsInitialized := true;
    end;

    procedure TestConnection(SetupKey: Code[10]): Boolean
    begin
        if not SharePointSetup.Get(SetupKey) then begin
            LastError := StrSubstNo('Setup %1 not found', SetupKey);
            exit(false);
        end;

        if SharePointSetup."Token Broker URL" = '' then begin
            LastError := 'Token Broker URL is not configured';
            exit(false);
        end;

        exit(true);
    end;

   procedure GetAccessToken(SetupKey: Code[10]): Text
var
    ContentText: Text;
    JsonToken: JsonToken;
    JsonObject: JsonObject;
    Response: HttpResponseMessage;
    Request: HttpRequestMessage;
    RequestHeaders: HttpHeaders;
begin
    if not SharePointSetup.Get(SetupKey) then
        Error('SharePoint Setup %1 not found', SetupKey);

    if SharePointSetup."Token Broker URL" = '' then
        Error('Token Broker URL is not configured');

    Clear(HttpClient);
    Request.Method := 'GET';
    Request.SetRequestUri(SharePointSetup."Token Broker URL");
    Request.GetHeaders(RequestHeaders);
    
    if not HttpClient.Send(Request, Response) then
        Error('Failed to connect to token broker');

    if not Response.IsSuccessStatusCode() then
        Error('Token broker error: %1', Response.HttpStatusCode());

    Response.Content().ReadAs(ContentText);

    // Try to parse as JSON
    if JsonObject.ReadFrom(ContentText) then
        if JsonObject.Get('access_token', JsonToken) then
            exit(JsonToken.AsValue().AsText());

    // Otherwise return raw response
    exit(ContentText);
end;
   procedure ListFilesFromSetup(PrimaryKey: Code[10]) FileList: List of [Text]
var
    ResponseText: Text;
    JsonResponse: JsonObject;
    JsonValueToken: JsonToken;
    JsonFilesArray: JsonArray;
    JsonFile: JsonToken;
    JsonFileName: JsonToken;
    RequestHeaders: HttpHeaders;
    Response: HttpResponseMessage;
    Request: HttpRequestMessage;
begin
    if not SharePointSetup.Get(PrimaryKey) then
        Error('SharePoint Setup not found for key %1', PrimaryKey);

    if (SharePointSetup."SharePoint Site Id" = '') or 
       (SharePointSetup."SharePoint Library Id" = '') then
        Error('SharePoint Site ID or Library ID not configured');

    Request.Method := 'GET';
    Request.SetRequestUri(StrSubstNo(
        'https://graph.microsoft.com/v1.0/sites/%1/drives/%2/root:/%3:/children',
        SharePointSetup."SharePoint Site Id",
        SharePointSetup."SharePoint Library Id",
        SharePointSetup."SharePoint Import Folder"));

    Request.GetHeaders(RequestHeaders);
    RequestHeaders.Add('Authorization', StrSubstNo('Bearer %1', GetAccessToken(PrimaryKey)));

    if not HttpClient.Send(Request, Response) then
        Error('Failed to connect to SharePoint Graph API');

    if not Response.IsSuccessStatusCode() then begin
        Response.Content().ReadAs(ResponseText);
        Error('Error listing files: %1 - %2', Response.HttpStatusCode(), ResponseText);
    end;

    Response.Content().ReadAs(ResponseText);
    if not JsonResponse.ReadFrom(ResponseText) then
        Error('Invalid JSON response from SharePoint');

    // Corrected JSON parsing logic
    if not JsonResponse.Get('value', JsonValueToken) then
        exit(FileList);

    if not JsonValueToken.IsArray() then
        exit(FileList);

    JsonFilesArray := JsonValueToken.AsArray();
    foreach JsonFile in JsonFilesArray do
        if JsonFile.AsObject().Get('name', JsonFileName) then
            FileList.Add(JsonFileName.AsValue().AsText());

    exit(FileList);
end;
    procedure UploadFileFromSetup(SetupKey: Code[10]; FileName: Text; var InStr: InStream): Boolean
    var
        RequestHeaders: HttpHeaders;
        Response: HttpResponseMessage;
        Request: HttpRequestMessage;
    begin
        if not SharePointSetup.Get(SetupKey) then
            exit(false);

        Request.Method := 'PUT';
        Request.SetRequestUri(StrSubstNo(
            'https://graph.microsoft.com/v1.0/sites/%1/drives/%2/root:/%3/%4:/content',
            SharePointSetup."SharePoint Site Id",
            SharePointSetup."SharePoint Library Id",
            SharePointSetup."SharePoint Export Folder",
            FileName));

        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Authorization', StrSubstNo('Bearer %1', GetAccessToken(SetupKey)));
        Request.Content().WriteFrom(InStr);

        if not HttpClient.Send(Request, Response) then begin
            LastError := 'Failed to send upload request';
            exit(false);
        end;

        if not Response.IsSuccessStatusCode() then begin
            LastError := StrSubstNo('Upload failed: %1', Response.HttpStatusCode());
            exit(false);
        end;

        exit(true);
    end;

    procedure DownloadFileFromSetup(SetupKey: Code[10]; FileName: Text; var OutStr: OutStream): Boolean
    var
        ResponseInStream: InStream;
        RequestHeaders: HttpHeaders;
        Response: HttpResponseMessage;
        Request: HttpRequestMessage;
    begin
        if not SharePointSetup.Get(SetupKey) then
            exit(false);

        Request.Method := 'GET';
        Request.SetRequestUri(StrSubstNo(
            '%1/_api/v2.0/drives/%2/root:%3:/content',
            SharePointSetup."SharePoint Site URL",
            SharePointSetup."SharePoint Library Id",
            FileName));

        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Authorization', StrSubstNo('Bearer %1', GetAccessToken(SetupKey)));

        if not HttpClient.Send(Request, Response) then begin
            LastError := 'Failed to send download request';
            exit(false);
        end;

        if not Response.IsSuccessStatusCode() then begin
            LastError := StrSubstNo('Download failed: %1', Response.HttpStatusCode());
            exit(false);
        end;

        Response.Content().ReadAs(ResponseInStream);
        CopyStream(OutStr, ResponseInStream);
        exit(true);
    end;

    procedure MoveFileFromSetup(SetupKey: Code[10]; FileName: Text; TargetFolder: Text): Boolean
    var
        RequestBody: Text;
        JsonObject: JsonObject;
        JsonParentRef: JsonObject;
        ResponseText: Text;
        RequestHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        Response: HttpResponseMessage;
        Request: HttpRequestMessage;
        Content: HttpContent;
    begin
        if not SharePointSetup.Get(SetupKey) then
            exit(false);

        JsonParentRef.Add('driveId', SharePointSetup."SharePoint Library Id");
        JsonParentRef.Add('id', TargetFolder);
        JsonObject.Add('parentReference', JsonParentRef);
        JsonObject.Add('name', FileName);
        JsonObject.WriteTo(RequestBody);

        Content.WriteFrom(RequestBody);
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'application/json');

        Request.Method := 'PATCH';
        Request.SetRequestUri(StrSubstNo(
            'https://graph.microsoft.com/v1.0/sites/%1/drives/%2/items/%3',
            SharePointSetup."SharePoint Site Id",
            SharePointSetup."SharePoint Library Id",
            FileName));
        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Authorization', StrSubstNo('Bearer %1', GetAccessToken(SetupKey)));
        Request.Content := Content;

        if not HttpClient.Send(Request, Response) then begin
            LastError := 'Failed to send move request';
            exit(false);
        end;

        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(ResponseText);
            LastError := StrSubstNo('Move failed: %1 - %2', 
                Response.HttpStatusCode(), 
                ResponseText);
            exit(false);
        end;

        exit(true);
    end;

    [NonDebuggable]
    procedure GetSharePointAccessTokenFromBroker(SetupKey: Code[10]): Text
    begin
        exit(GetAccessToken(SetupKey));
    end;

    local procedure GetGraphFolderPath(Folder: Text): Text 
    begin
        if Folder = '' then 
            exit('');
            
        Folder := DelChr(Folder, '=', '\n\r');
        if not Folder.StartsWith('/') then 
            Folder := '/' + Folder;
        Folder := Folder.TrimEnd('/');
        exit(Folder);
    end;
}