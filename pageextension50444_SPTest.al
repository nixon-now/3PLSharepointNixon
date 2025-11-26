pageextension 50498 "SharePoint ShowGraphEndpoint" extends "SharePoint Setup"
{
    actions
    {
        addlast(Processing)
        {
            action("Show Graph Upload Endpoint")
            {
                Caption = 'Show Graph Upload Endpoint';
                ApplicationArea = All;
                Image = View;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Displays the Microsoft Graph API endpoint for uploading files to the configured SharePoint document library and folder';

                trigger OnAction()
                var
                    FileName: Text;
                    Endpoint: Text;
                begin
                    if not ValidateSharePointSetup() then
                        exit;

                    if not GetFileName(FileName) then
                        exit;

                    Endpoint := ComposeGraphEndpoint(FileName);

                    DisplayEndpointInfo(Endpoint, FileName);
                end;
            }

            action("Show Graph Download Endpoint")
            {
                Caption = 'Show Graph Download Endpoint';
                ApplicationArea = All;
                Image = View;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Displays the Microsoft Graph API endpoint for downloading files from the configured SharePoint folder';

                trigger OnAction()
                var
                    FileName: Text;
                    Endpoint: Text;
                begin
                    if not ValidateSharePointSetup() then
                        exit;

                    if not GetFileName(FileName) then
                        exit;

                    Endpoint := ComposeGraphDownloadEndpoint(FileName);

                    DisplayDownloadEndpointInfo(Endpoint, FileName);
                end;
            }

            action("Show Graph Folder URL")
            {
                Caption = 'Show Graph Folder URL';
                ApplicationArea = All;
                Image = View;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Displays the SharePoint folder URL in Microsoft Graph (browser link)';

                trigger OnAction()
                var
                    FolderUrl: Text;
                begin
                    if not ValidateSharePointSetup() then
                        exit;

                    FolderUrl := ComposeGraphFolderUrl();

                    Message('SharePoint Folder URL (Graph):\n\n%1', FolderUrl);
                end;
            }

            action(TestSharePointConnection)
            {
                ApplicationArea = All;
                Caption = 'Test Connection';
                Image = TestFile;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Test the connection to SharePoint with current settings';

                trigger OnAction()
                var
                    SharePointMgmt: Codeunit "SharePoint Graph Connector";
                    TestResult: Boolean;
                begin
                    if not ValidateSharePointSetup() then
                        exit;

                    TestResult := SharePointMgmt.TestConnection(Rec."Primary Key");

                    if TestResult then
                        Message('SharePoint connection test successful!')
                    else
                        Error('Connection failed: %1', SharePointMgmt.GetLastError());
                end;
            }
        }
    }

    local procedure ValidateSharePointSetup(): Boolean
    begin
        if Rec."SharePoint Site Id" = '' then begin
            Error('SharePoint Site Id is not configured.');
            exit(false);
        end;

        if Rec."SharePoint Library Id" = '' then begin
            Error('SharePoint Library Id is not configured.');
            exit(false);
        end;

        exit(true);
    end;

    local procedure GetFileName(var FileName: Text): Boolean
    var
        InStream: InStream;
    begin
        if not UploadIntoStream('Select the file', '', '', FileName, InStream) then
            exit(false);
        exit(FileName <> '');
    end;

    local procedure ComposeGraphEndpoint(FileName: Text): Text
    var
        FolderPath: Text;
    begin
        FolderPath := Rec."SharePoint Export Folder";
        if FolderPath = '' then
            FolderPath := '/Shared Documents';

        if not FolderPath.StartsWith('/') then
            FolderPath := '/' + FolderPath;

        exit(StrSubstNo(
            'https://graph.microsoft.com/v1.0/sites/%1/drives/%2/root:%3/%4:/content',
            Rec."SharePoint Site Id",
            Rec."SharePoint Library Id",
            FolderPath,
            FileName));
    end;

    local procedure ComposeGraphDownloadEndpoint(FileName: Text): Text
    var
        FolderPath: Text;
    begin
        FolderPath := Rec."SharePoint Export Folder";
        if FolderPath = '' then
            FolderPath := '/Shared Documents';

        if not FolderPath.StartsWith('/') then
            FolderPath := '/' + FolderPath;

        exit(StrSubstNo(
            'https://graph.microsoft.com/v1.0/sites/%1/drives/%2/root:%3/%4:/content',
            Rec."SharePoint Site Id",
            Rec."SharePoint Library Id",
            FolderPath,
            FileName));
    end;

    local procedure ComposeGraphFolderUrl(): Text
    var
        FolderPath: Text;
    begin
        FolderPath := Rec."SharePoint Export Folder";
        if FolderPath = '' then
            FolderPath := '/Shared Documents';

        if not FolderPath.StartsWith('/') then
            FolderPath := '/' + FolderPath;

        exit(StrSubstNo(
            'https://graph.microsoft.com/v1.0/sites/%1/drives/%2/root:%3',
            Rec."SharePoint Site Id",
            Rec."SharePoint Library Id",
            FolderPath));
    end;

    local procedure DisplayEndpointInfo(Endpoint: Text; FileName: Text)
    var
        EndpointMsg: Label 'Graph API Upload Endpoint:\n\n%1\n\nSite ID: %2\nLibrary ID: %3\nFolder: %4';
        CurlExampleMsg: Label 'Example cURL command:\n\ncurl -X PUT "%1" -H "Authorization: Bearer {access_token}" -H "Content-Type: application/octet-stream" --data-binary @%2';
    begin
        Message(
            EndpointMsg,
            Endpoint,
            Rec."SharePoint Site Id",
            Rec."SharePoint Library Id",
            Rec."SharePoint Export Folder");

        if Confirm('Do you want to see an example cURL command?') then
            Message(CurlExampleMsg, Endpoint, FileName);
    end;

    local procedure DisplayDownloadEndpointInfo(Endpoint: Text; FileName: Text)
    var
        EndpointMsg: Label 'Graph API Download Endpoint:\n\n%1\n\nSite ID: %2\nLibrary ID: %3\nFolder: %4';
        CurlExampleMsg: Label 'Example cURL command:\n\ncurl -X GET "%1" -H "Authorization: Bearer {access_token}" -o %2';
    begin
        Message(
            EndpointMsg,
            Endpoint,
            Rec."SharePoint Site Id",
            Rec."SharePoint Library Id",
            Rec."SharePoint Export Folder");

        if Confirm('Do you want to see an example cURL command?') then
            Message(CurlExampleMsg, Endpoint, FileName);
    end;
}
