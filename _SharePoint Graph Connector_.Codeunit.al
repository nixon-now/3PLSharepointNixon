codeunit 50402 "SharePoint Graph Connector"
{
    Access = Public;

    var
        SharePointSetup: Record "SharePoint Setup";
        TokenCache: Dictionary of [Text, Text];
        LastErrorMsg: Text;
        IsInitialized: Boolean;
        SharePointHttpClient: HttpClient;
        // TODO: Consider adding request timeout configuration later

    // ------------------------------------------------------------
    // Site/Drive discovery (used only if choose to resolve IDs)
    // ------------------------------------------------------------
    procedure ResolveSiteAndDriveIDs(SetupKey: Code[10])
    var
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Json: JsonObject;
        SiteId: Text;
        WebId: Text;
        DriveId: Text;
        Tok: JsonToken;
        ResponseText: Text;
    begin
        if not SharePointSetup.Get(SetupKey) then
            Error('Setup not found: %1', SetupKey);

        // Skip if we already have the IDs resolved
        if SharePointSetup."SharePoint Site Id" <> '' then
            exit; // Already resolved

        InitializeRequest(SetupKey, Request);
        Request.SetRequestUri('https://graph.microsoft.com/v1.0/sites/nixonnow.sharepoint.com:/sites/businesscentralchannel');
        if not ExecuteWithRetry(Request, Response, 3) then
            Error(LastErrorMsg);

        Response.Content().ReadAs(ResponseText);
        Json.ReadFrom(ResponseText);
        Json.Get('id', Tok);
        SiteId := Tok.AsValue().AsText();
        Json.Get('webId', Tok);
        WebId := Tok.AsValue().AsText();

        // Now get the drive ID from the site
        Request.SetRequestUri('https://graph.microsoft.com/v1.0/sites/' + SiteId + '/drive');
        if not ExecuteWithRetry(Request, Response, 3) then
            Error(LastErrorMsg);

        Response.Content().ReadAs(ResponseText);
        Json.ReadFrom(ResponseText);
        Json.Get('id', Tok);
        DriveId := Tok.AsValue().AsText();

        // Update the setup record with resolved IDs
        SharePointSetup."SharePoint Site Id" := SiteId;
        // FIXED: Was mapping to wrong fields before - now using correct field names
        SharePointSetup."SharePoint Web Id" := WebId;
        SharePointSetup."SharePoint Library Id" := DriveId;
        SharePointSetup.Modify();
    end;

    // ------------------------------------------
    // Path normalization & validation (folder only)
    // ------------------------------------------
    procedure NormalizeFolderPath(Path: Text): Text
    var
        pos: Integer;
    begin
        // Clean up the path input
        Path := Path.Trim();
        Path := ConvertStr(Path, '\', '/'); // Convert backslashes to forward slashes

        // Handle cases where someone pasted a full Graph URL path
        pos := StrPos(LowerCase(Path), 'root:/');
        if pos > 0 then
            Path := CopyStr(Path, pos + StrLen('root:/'));

        // Remove "Shared Documents/" prefix if present (case-insensitive)
        if StrPos(LowerCase(Path), 'shared documents/') = 1 then
            Path := CopyStr(Path, StrLen('Shared Documents/') + 1);

        // Strip leading slashes
        while (StrLen(Path) > 0) and (CopyStr(Path, 1, 1) = '/') do
            Path := CopyStr(Path, 2);

        // Strip trailing slashes
        while (StrLen(Path) > 0) and (CopyStr(Path, StrLen(Path), 1) = '/') do
            Path := CopyStr(Path, 1, StrLen(Path) - 1);

        exit(Path); // Should return something like "3PL_Jobs/CA/Test"
    end;

    local procedure ValidateSharePointPath(Path: Text): Boolean
    var
        P: Text;
    begin
        // Validate the normalized path (case-insensitive check)
        P := LowerCase(NormalizeFolderPath(Path));
        exit((P = '3pl_jobs') or (StrPos(P, '3pl_jobs/') = 1));
    end;

    // -----------------------------
    // URL helpers (drive-scoped)
    // -----------------------------
    local procedure BuildDriveUrl(Endpoint: Text): Text
    begin
        exit('https://graph.microsoft.com/v1.0/' + Endpoint);
    end;

    local procedure BuildGraphUrl(Endpoint: Text): Text
    begin
        exit('https://graph.microsoft.com/v1.0/' + Endpoint);
    end;

    procedure BuildDriveItemUrl(SetupKey: Code[10]; RelativePath: Text): Text
    var
        P: Text;
        EncodedPath: Text;
    begin
        if not SharePointSetup.Get(SetupKey) then
            Error('Setup not found: %1', SetupKey);

        if SharePointSetup."SharePoint Library Id" = '' then
            Error('SharePoint Library Id (driveId) is not configured.');

        P := NormalizeFolderPath(RelativePath);
        if not ValidateSharePointPath(P) then
            Error('Invalid folder path: %1', RelativePath);

        EncodedPath := UrlEncodePathSegmentAware(P);
        // Build the drives/{driveId}/root:/<path> URL
        exit(StrSubstNo('https://graph.microsoft.com/v1.0/drives/%1/root:/%2',
                        SharePointSetup."SharePoint Library Id",
                        EncodedPath));
    end;

    procedure BuildFileContentUrl(SetupKey: Code[10]; FolderPath: Text; FileName: Text): Text
    var
        PathNorm: Text;
        Encoded: Text;
    begin
        if not SharePointSetup.Get(SetupKey) then
            Error('Setup not found: %1', SetupKey);
        if SharePointSetup."SharePoint Library Id" = '' then
            Error('SharePoint Library Id (driveId) is not configured.');

        PathNorm := NormalizeFolderPath(FolderPath);
        if not ValidateSharePointPath(PathNorm) then
            Error('Invalid folder path. Expected "3PL_Jobs/..."');

        Encoded := UrlEncodePathSegmentAware(PathNorm + '/' + FileName);
        exit(StrSubstNo('https://graph.microsoft.com/v1.0/drives/%1/root:/%2:/content',
                        SharePointSetup."SharePoint Library Id",
                        Encoded));
    end;

    local procedure UrlEncodePathSegmentAware(Path: Text): Text
    var
        I: Integer;
        Ch: Char;
        OutText: Text;
    begin
        // Encode each character, but preserve forward slashes for path segments
        for I := 1 to StrLen(Path) do begin
            Ch := Path[I];
            case Ch of
                'A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~', '/':
                    OutText += Ch;
                ' ':
                    OutText += '%20';
                else
                    OutText += '%' + Format(Ch, 0, '<Hexadecimal,2>');
            end;
        end;
        exit(OutText);
    end;

    local procedure GetHexDigit(Value: Integer): Text[1]
    begin
        case Value of
            0..9: exit(Format(Value));
            10: exit('A'); 
            11: exit('B'); 
            12: exit('C'); 
            13: exit('D'); 
            14: exit('E'); 
            15: exit('F');
        end;
    end;

    // -----------------------------
    // Listing files (paged)
    // -----------------------------
    local procedure ProcessFileArray(JsonArray: JsonArray; var FileList: List of [Text])
    var
        Tok: JsonToken;
        NameTok: JsonToken;
    begin
        foreach Tok in JsonArray do
            if Tok.AsObject().Get('name', NameTok) then
                FileList.Add(NameTok.AsValue().AsText());
    end;

    local procedure ListFilesPage(SetupKey: Code[10]; FolderPath: Text; var FileList: List of [Text]; var NextLink: Text): Boolean
    var
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        ResponseText: Text;
        JsonResponse: JsonObject;
        JsonTok: JsonToken;
        FullUrl: Text;
    begin
        // Build URL based on whether this is first page or continuation
        if NextLink = '' then
            FullUrl := BuildDriveItemUrl(SetupKey, FolderPath) + ':/children'
        else
            FullUrl := NextLink;

        InitializeRequest(SetupKey, Request);
        Request.SetRequestUri(FullUrl);

        if not ExecuteWithRetry(Request, Response, 3) then
            Error(LastErrorMsg);

        Response.Content().ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error('Failed to list files: %1', Response.HttpStatusCode());

        if not JsonResponse.ReadFrom(ResponseText) then
            Error('Invalid JSON response');

        // Process the file list from the response
        if JsonResponse.Get('value', JsonTok) and JsonTok.IsArray() then
            ProcessFileArray(JsonTok.AsArray(), FileList);

        // Check if there are more pages
        if JsonResponse.Get('@odata.nextLink', JsonTok) then
            NextLink := JsonTok.AsValue().AsText()
        else
            NextLink := '';

        exit(NextLink <> '');
    end;

    procedure ListFilesInFolder(SetupKey: Code[10]; FolderPath: Text) FileList: List of [Text]
    var
        NextLink: Text;
        MorePages: Boolean;
        P: Text;
    begin
        // This function takes a simple relative path, normalizes it, and lists files
        P := NormalizeFolderPath(FolderPath);
        if not ValidateSharePointPath(P) then
            Error('Invalid folder path. Please use format: "3PL_Jobs/[subfolder]"');

        // Handle pagination - keep fetching until no more pages
        repeat
            MorePages := ListFilesPage(SetupKey, P, FileList, NextLink);
        until not MorePages;
    end;

    local procedure ListFilesPageByUrl(SetupKey: Code[10]; AbsoluteUrl: Text; var FileList: List of [Text]; var NextLink: Text): Boolean
    var
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        ResponseText: Text;
        JsonResponse: JsonObject;
        ValTok: JsonToken;
        Arr: JsonArray;
        Item: JsonToken;
        NameTok: JsonToken;
    begin
        InitializeRequest(SetupKey, Request);
        Request.SetRequestUri(AbsoluteUrl);

        if not ExecuteWithRetry(Request, Response, 3) then
            Error(LastErrorMsg);

        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(ResponseText);
            LogError('SP-LIST-ERROR', StrSubstNo('Error %1: %2', Response.HttpStatusCode(), ResponseText), Verbosity::Error);
            exit(false);
        end;

        Response.Content().ReadAs(ResponseText);
        if not JsonResponse.ReadFrom(ResponseText) then
            Error('Invalid JSON response: ' + ResponseText);

        if JsonResponse.Get('value', ValTok) and ValTok.IsArray() then begin
            Arr := ValTok.AsArray();
            foreach Item in Arr do
                if Item.AsObject().Get('name', NameTok) then
                    FileList.Add(SanitizeFileName(NameTok.AsValue().AsText()));
        end;

        NextLink := '';
        if JsonResponse.Get('@odata.nextLink', ValTok) then
            NextLink := ValTok.AsValue().AsText();

        exit(NextLink <> '');
    end;

    // -----------------------------
    // Download (drive-scoped)
    // -----------------------------
    procedure DownloadFile(SetupKey: Code[10]; FolderPath: Text; FileName: Text; var OutS: OutStream): Boolean
    var
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        ResponseText: Text;
        PathNorm: Text;
        FullUrl: Text;
        InS: InStream;
    begin
        // This is the main download function - builds correct Graph API URL for file content
        Clear(LastErrorMsg);

        if not SharePointSetup.Get(SetupKey) then
            exit(SetError('SharePoint setup not found'));

        if SharePointSetup."SharePoint Library Id" = '' then
            exit(SetError('SharePoint Library Id (driveId) is not configured.'));

        if not ValidateSharePointPath(FolderPath) then
            exit(SetError('Invalid folder path. Expected "3PL_Jobs/..."'));

        // Combine normalized folder path with filename and encode properly
        PathNorm := NormalizeFolderPath(FolderPath);
        PathNorm := UrlEncodePathSegmentAware(PathNorm + '/' + FileName);

        // Build the final URL: drives/{driveId}/root:/<path>/<file>:/content
        FullUrl := StrSubstNo('https://graph.microsoft.com/v1.0/drives/%1/root:/%2:/content',
                              SharePointSetup."SharePoint Library Id", PathNorm);

        InitializeRequest(SetupKey, Request);
        Request.SetRequestUri(FullUrl);

        if not ExecuteWithRetry(Request, Response, 3) then
            exit(false);

        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(ResponseText);
            LastErrorMsg := StrSubstNo('Download failed (%1) for URL %2. Error: %3', 
                Response.HttpStatusCode(), FullUrl, CopyStr(ResponseText, 1, 250));
            LogError('SP-DOWNLOAD-ERROR', LastErrorMsg, Verbosity::Error);
            exit(false);
        end;

        Response.Content().ReadAs(InS);
        CopyStream(OutS, InS);
        exit(true);
    end;

    // -----------------------------
    // Debug helpers - useful for troubleshooting
    // -----------------------------
    procedure DebugProbeFolder(SetupKey: Code[10]; FolderPath: Text)
    var
        Req: HttpRequestMessage;
        Res: HttpResponseMessage;
        Url: Text;
        Body: Text;
        D: Dictionary of [Text, Text];
        P: Text;
    begin
        if not SharePointSetup.Get(SetupKey) then
            Error('Setup not found: %1', SetupKey);

        if SharePointSetup."SharePoint Library Id" = '' then
            Error('Library (drive) Id is not configured');

        P := UrlEncodePathSegmentAware(NormalizeFolderPath(FolderPath));
        Url := BuildDriveUrl(StrSubstNo('drives/%1/root:/%2:/children', SharePointSetup."SharePoint Library Id", P));

        InitializeRequest(SetupKey, Req);
        Req.SetRequestUri(Url);

        if not SharePointHttpClient.Send(Req, Res) then
            Error('HTTP send failed');

        Res.Content().ReadAs(Body);
        Session.LogMessage('SP-DEBUG-LIST',
            StrSubstNo('GET %1 -> %2\n%3', Url, Res.HttpStatusCode(), CopyStr(Body, 1, 500)),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, D);
    end;

    procedure DebugProbeDownload(SetupKey: Code[10]; FolderPath: Text; FileName: Text)
    var
        Req: HttpRequestMessage;
        Res: HttpResponseMessage;
        Url: Text;
        Tmp: Codeunit "Temp Blob";
        OutS: OutStream;
        InS: InStream;
        D: Dictionary of [Text, Text];
        P: Text;
    begin
        if not SharePointSetup.Get(SetupKey) then
            Error('Setup not found: %1', SetupKey);

        if SharePointSetup."SharePoint Library Id" = '' then
            Error('Library (drive) Id is not configured');

        P := UrlEncodePathSegmentAware(NormalizeFolderPath(FolderPath) + '/' + FileName);
        Url := BuildDriveUrl(StrSubstNo('drives/%1/root:/%2:/content', SharePointSetup."SharePoint Library Id", P));

        InitializeRequest(SetupKey, Req);
        Req.SetRequestUri(Url);

        Tmp.CreateOutStream(OutS);
        if not SharePointHttpClient.Send(Req, Res) then
            Error('HTTP send failed');

        Session.LogMessage('SP-DEBUG-DOWNLOAD',
            StrSubstNo('GET %1 -> %2', Url, Res.HttpStatusCode()),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, D);

        if Res.IsSuccessStatusCode() then
            Res.Content().ReadAs(InS); // Successfully fetched bytes
    end;

    // -----------------------------
    // Upload & Move operations
    // -----------------------------
    procedure UploadFile(SetupKey: Code[10]; FolderPath: Text; FileName: Text; InS: InStream): Boolean
    var
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        FilePath: Text;
        FullUrl: Text;
        PathNorm: Text;
    begin
        Clear(LastErrorMsg);

        if not SharePointSetup.Get(SetupKey) then
            exit(SetError('Setup not found'));

        InitializeRequest(SetupKey, Request);
        PathNorm := NormalizeFolderPath(FolderPath);
        FilePath := UrlEncodePathSegmentAware(PathNorm + '/' + FileName);
        Request.Method := 'PUT';
        FullUrl := BuildGraphUrl(StrSubstNo('drives/%1/root:/%2:/content', SharePointSetup."SharePoint Library Id", FilePath));
        Request.SetRequestUri(FullUrl);
        Request.Content().WriteFrom(InS);

        if not ExecuteWithRetry(Request, Response, 3) then
            exit(false);

        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(LastErrorMsg);
            LastErrorMsg := StrSubstNo('Upload failed (%1) for URL %2. Error: %3', 
                Response.HttpStatusCode(), FullUrl, LastErrorMsg);
            LogError('SP-UPLOAD-ERROR', LastErrorMsg, Verbosity::Error);
            exit(false);
        end;

        exit(true);
    end;

    procedure MoveFile(SetupKey: Code[10]; SourceFolder: Text; FileName: Text; DestFolder: Text): Boolean
    var
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        PatchBody: JsonObject;
        ParentRef: JsonObject;
        JsonAsText: Text;
        Headers: HttpHeaders;
        SrcNorm: Text;
        DstNorm: Text;
        FilePath: Text;
        FullUrl: Text;
    begin
        Clear(LastErrorMsg);

        if not SharePointSetup.Get(SetupKey) then
            exit(SetError('Setup not found'));

        SrcNorm := NormalizeFolderPath(SourceFolder);
        DstNorm := NormalizeFolderPath(DestFolder);
        if (not ValidateSharePointPath(SrcNorm)) or (not ValidateSharePointPath(DstNorm)) then
            exit(SetError('Invalid folder path. Expected "3PL_Jobs/..."'));

        InitializeRequest(SetupKey, Request);
        FilePath := UrlEncodePathSegmentAware(SrcNorm + '/' + FileName);
        Request.Method := 'PATCH';
        FullUrl := BuildGraphUrl(StrSubstNo('drives/%1/root:/%2:', SharePointSetup."SharePoint Library Id", FilePath));
        Request.SetRequestUri(FullUrl);

        // Build JSON body for moving the file
        ParentRef.Add('path', '/drives/' + SharePointSetup."SharePoint Library Id" + '/root:/' + DstNorm);
        PatchBody.Add('parentReference', ParentRef);
        PatchBody.WriteTo(JsonAsText);

        Request.GetHeaders(Headers);
        Headers.Add('Content-Type', 'application/json');
        Request.Content().WriteFrom(JsonAsText);

        if not ExecuteWithRetry(Request, Response, 3) then
            exit(false);

        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(LastErrorMsg);
            LastErrorMsg := StrSubstNo('Move failed (%1) for URL %2. Error: %3', 
                Response.HttpStatusCode(), FullUrl, LastErrorMsg);
            LogError('SP-MOVE-ERROR', LastErrorMsg, Verbosity::Error);
            exit(false);
        end;

        exit(true);
    end;

    // -----------------------------
    // Token handling - authentication with external broker
    // -----------------------------
    procedure GetAccessToken(SetupKey: Code[10]): Text
    var
        SetupRec: Record "SharePoint Setup";
        CacheKey: Text;
        CachedToken: Text;
        TokenExists: Boolean;
        D: Dictionary of [Text, Text];
    begin
        if not SetupRec.Get(SetupKey) then begin
            Session.LogMessage('SP-ERROR-001', 'Setup record not found', 
                Verbosity::Error, DataClassification::SystemMetadata, 
                TelemetryScope::ExtensionPublisher, D);
            Error('SharePoint Setup %1 not found', SetupKey);
        end;

        CacheKey := GetTokenCacheKey(SetupKey);
        if CacheKey = '' then begin
            Session.LogMessage('SP-ERROR-002', 'Invalid cache key generated', 
                Verbosity::Error, DataClassification::SystemMetadata, 
                TelemetryScope::ExtensionPublisher, D);
            Error('Invalid cache key generated');
        end;

        // Check if we have a cached token that's still valid
        TokenExists := TokenCache.Get(CacheKey, CachedToken);
        if TokenExists then begin
            if ValidateToken(CachedToken) then
                exit(CachedToken)
            else
                TokenCache.Remove(CacheKey); // Remove invalid token
        end;

        // Need to get a new token
        exit(AcquireNewToken(SetupKey, CacheKey));
    end;

    local procedure GetTokenRequestUrl(SetupKey: Code[10]): Text
    var
        SetupRec: Record "SharePoint Setup";
    begin
        if not SetupRec.Get(SetupKey) then
            Error('Setup record not found');
        exit(SetupRec."Token Broker URL" + '&resource=https://graph.microsoft.com');
    end;

    local procedure AcquireNewToken(SetupKey: Code[10]; CacheKey: Text): Text
    var
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        ContentText: Text;
        J: JsonObject;
        Tok: JsonToken;
        RetryCount: Integer;
        NewToken: Text;
        D: Dictionary of [Text, Text];
    begin
        // Reset client headers for token request
        SharePointHttpClient.DefaultRequestHeaders.Clear();
        SharePointHttpClient.DefaultRequestHeaders.Add('Accept', 'application/json');

        Request.Method := 'GET';
        Request.SetRequestUri(GetTokenRequestUrl(SetupKey));

        // Retry logic for token acquisition
        for RetryCount := 1 to 3 do begin
            if not SharePointHttpClient.Send(Request, Response) then begin
                Sleep(1000 * RetryCount); // Exponential backoff
                continue;
            end;

            if not Response.IsSuccessStatusCode() then begin
                Sleep(1000 * RetryCount);
                continue;
            end;

            Response.Content().ReadAs(ContentText);
            if not J.ReadFrom(ContentText) then
                Error('Invalid token response');

            if not J.Get('access_token', Tok) then
                Error('Access token missing in response');

            NewToken := Tok.AsValue().AsText();
            if NewToken = '' then
                Error('Received empty access token');

            // Cache the new token for future use
            TokenCache.Set(CacheKey, NewToken);
            exit(NewToken);
        end;

        Session.LogMessage('SP-FATAL-001', 'All token acquisition attempts failed', 
            Verbosity::Error, DataClassification::SystemMetadata, 
            TelemetryScope::ExtensionPublisher, D);
        Error('Failed to acquire access token after 3 attempts');
    end;

    procedure RefreshToken(SetupKey: Code[10]): Boolean
    var
        CacheKey: Text;
        OldToken: Text;
    begin
        CacheKey := GetTokenCacheKey(SetupKey);

        // Remove old token from cache if it exists
        if TokenCache.Get(CacheKey, OldToken) then
            TokenCache.Remove(CacheKey);

        Clear(LastErrorMsg);
        exit(GetAccessToken(SetupKey) <> '');
    end;

    local procedure GetTokenCacheKey(SetupKey: Code[10]): Text
    var
        S: Record "SharePoint Setup";
    begin
        if not S.Get(SetupKey) then
            exit('');
        exit(StrSubstNo('SP-TKN-%1-%2', SetupKey, S."Token Broker URL"));
    end;

    local procedure ValidateToken(Token: Text): Boolean
    begin
        // Basic JWT validation - check for two dots (header.payload.signature)
        exit((Token <> '') and (StrPos(Token, '.') > 0) and 
             (StrPos(CopyStr(Token, StrPos(Token, '.') + 1), '.') > 0));
    end;

    // -----------------------------
    // Connection test & misc utilities
    // -----------------------------
    procedure TestConnection(SetupKey: Code[10]): Boolean
    var
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
    begin
        Clear(LastErrorMsg);

        if not SharePointSetup.Get(SetupKey) then
            exit(SetError('Setup not found for key ' + SetupKey));

        if (SharePointSetup."SharePoint Site Id" = '') or (SharePointSetup."SharePoint Library Id" = '') then
            exit(SetError('Site ID or Library ID is missing.'));

        InitializeRequest(SetupKey, Request);
        Request.SetRequestUri(BuildDriveUrl(StrSubstNo('sites/%1', SharePointSetup."SharePoint Site Id")));

        if not ExecuteWithRetry(Request, Response, 2) then
            exit(false);

        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(LastErrorMsg);
            exit(false);
        end;

        exit(true);
    end;

    procedure GetLastError(): Text
    begin
        exit(LastErrorMsg);
    end;

    // -----------------------------
    // HTTP plumbing & infrastructure
    // -----------------------------
    local procedure InitializeRequest(SetupKey: Code[10]; var Request: HttpRequestMessage)
    var
        Headers: HttpHeaders;
        AccessToken: Text;
    begin
        Request.Method := 'GET';
        AccessToken := GetAccessToken(SetupKey);
        Request.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', AccessToken));
        Headers.Add('Accept', 'application/json');
    end;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;
        IsInitialized := true;
        // Could add more initialization logic here if needed
    end;

    procedure GetHttpClient(): HttpClient
    begin
        if not IsInitialized then
            Initialize();
        exit(SharePointHttpClient);
    end;

    procedure FileExistsInSharePoint(FolderPath: Text; FileName: Text): Boolean
    var
        FileNames: List of [Text];
    begin
        if (FolderPath = '') or (FileName = '') then
            exit(false);
        
        // Simple existence check - list all files and see if our file is there
        FileNames := ListFilesInFolder('3PL', FolderPath);
        exit(FileNames.Contains(FileName));
    end;

    local procedure ExecuteWithRetry(var Request: HttpRequestMessage; var Response: HttpResponseMessage; MaxRetries: Integer): Boolean
    var
        RetryCount: Integer;
    begin
        repeat
            RetryCount += 1;
            if SharePointHttpClient.Send(Request, Response) then begin
                if HandleThrottling(Response) then
                    continue; // Try again after throttling delay
                exit(true);
            end;
            Sleep(1000 * RetryCount); // Wait before retry
        until RetryCount >= MaxRetries;

        LastErrorMsg := 'HTTP request failed';
        LogError('SP-HTTP-ERROR', LastErrorMsg, Verbosity::Error);
        exit(false);
    end;

    local procedure HandleThrottling(var Response: HttpResponseMessage): Boolean
    var
        RetryAfter: Integer;
        HeaderValues: List of [Text];
    begin
        // Handle 429 Too Many Requests responses
        if Response.HttpStatusCode() = 429 then begin
            if Response.Headers.Contains('Retry-After') then begin
                Response.Headers.GetValues('Retry-After', HeaderValues);
                if HeaderValues.Count() > 0 then
                    Evaluate(RetryAfter, HeaderValues.Get(1))
                else
                    RetryAfter := 5; // Default fallback
            end else
                RetryAfter := 5;

            Sleep(RetryAfter * 1000);
            exit(true);
        end;
        exit(false);
    end;

    // -----------------------------
    // Utility functions
    // -----------------------------
    local procedure HttpGetJson(Url: Text; var BodyOut: Text)
    var
        Graph: Codeunit "SharePoint Graph Connector";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        ReqHeaders: HttpHeaders;
    begin
        // Use the shared client to maintain auth consistency
        Client := Graph.GetHttpClient();

        Request.Method := 'GET';
        Request.SetRequestUri(Url);

        // Set appropriate headers for JSON requests
        Request.GetHeaders(ReqHeaders);
        ReqHeaders.Add('Accept', 'application/json');

        if not Client.Send(Request, Response) then
            Error('HTTP send failed');

        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(BodyOut);
            Error('GET %1 failed (%2): %3', Url, Response.HttpStatusCode(), CopyStr(BodyOut, 1, 250));
        end;

        Response.Content().ReadAs(BodyOut);
    end;

    procedure UrlEncode(InputText: Text): Text
    var
        I: Integer;
        C: Char;
        Code: Integer;
        EncodedText: Text;
    begin
        if InputText = '' then
            exit('');

        for I := 1 to StrLen(InputText) do begin
            C := InputText[I];
            case C of
                'A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~', '/':
                    EncodedText += C;
                ' ':
                    EncodedText += '%20';
                else begin
                    Code := C;
                    EncodedText += '%' + GetHexDigit(Code div 16) + GetHexDigit(Code mod 16);
                end;
            end;
        end;

        // Ensure leading slash if not present
        if (EncodedText <> '') and not (EncodedText[1] = '/') then
            EncodedText := '/' + EncodedText;

        exit(EncodedText);
    end;

    local procedure SanitizeFileName(FileName: Text): Text
    begin
        // Remove invalid filename characters
        FileName := DelChr(FileName, '=', '\/:*?"<>|');
        exit(FileName.Trim());
    end;

    local procedure SetError(Msg: Text): Boolean
    begin
        LastErrorMsg := Msg;
        LogError('SP-ERROR', Msg, Verbosity::Error);
        exit(false);
    end;

    local procedure LogError(ErrorCode: Text; Message: Text; Verbosity: Verbosity)
    var
        D: Dictionary of [Text, Text];
    begin
        D.Add('ErrorDetails', Message);
        Session.LogMessage(ErrorCode, Message, Verbosity, DataClassification::SystemMetadata, 
            TelemetryScope::ExtensionPublisher, D);
    end;

    // -----------------------------
    // Legacy compatibility function - marked for removal
    // -----------------------------
    [Obsolete('This function constructs an incorrect path and should not be used. Pass the relative folder path from the setup table directly to the connector functions like DownloadFile or ListFilesInFolder.', '1.0')]
    procedure BuildGraphFolderPath(): Text
    var
        SetupRec: Record "SharePoint Setup";
    begin
        // NOTE: This function was the source of original path issues
        // Keeping it here but marked obsolete to avoid breaking existing code
        // Should be removed from all calling locations
        if not SetupRec.Get('3PL') then
            exit('');
        exit(SetupRec."SharePoint Import Folder");
    end;
}