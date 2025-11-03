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
                    EndpointMsg: Label 'Graph API endpoint to upload this file:\n\n%1\n\nSite ID: %2\nLibrary ID: %3\nFolder: %4';
                begin
                    // Validate setup configuration first
                    if not ValidateSharePointSetup() then
                        exit;

                    // Get file name from user
                    if not GetFileName(FileName) then
                        exit;

                    // Compose endpoint URL
                    Endpoint := ComposeGraphEndpoint(FileName);

                    // Display results
                    DisplayEndpointInfo(Endpoint, FileName);
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
    //FileName: Text;
    InStream: InStream;
begin
    if not UploadIntoStream('Select the file to upload', '', '', FileName, InStream) then
        exit(false);
    // Now FileName is set to the chosen filename
    // InStream contains the file content
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
}