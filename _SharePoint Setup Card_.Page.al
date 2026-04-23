page 50497 "SharePoint Setup"
{
    PageType = Card;
    SourceTable = "SharePoint Setup";
    Caption = '3PL Integration Setup';
    ApplicationArea = All;
    UsageCategory = Administration;
    DeleteAllowed = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General Settings';
                field(Enabled; Rec.Enabled) { ApplicationArea = All; }
                field("3PL Code"; Rec."3PL Code") { ApplicationArea = All; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("Require Tracking No."; Rec."Require Tracking No.") { ApplicationArea = All; }
                field("Validate Before Export"; Rec."Validate Before Export") { ApplicationArea = All; }
            }

            group(SharePoint)
            {
                Caption = 'SharePoint Settings';
                field("Use SharePoint"; Rec."Use SharePoint") { ApplicationArea = All; }
                field("SharePoint Site URL"; Rec."SharePoint Site URL") { ApplicationArea = All; }
                field("SharePoint Library Name"; Rec."SharePoint Library Name") { ApplicationArea = All; }
                field("SharePoint Library Id"; Rec."SharePoint Library Id") { ApplicationArea = All; }
                field("SharePoint Site Id"; Rec."SharePoint Site Id") { ApplicationArea = All; }
                field("SharePoint Export Folder"; Rec."SharePoint Export Folder") { ApplicationArea = All; }
                
                field("SharePoint Import Folder"; Rec."SharePoint Import Folder") { ApplicationArea = All; }
                field("SharePoint Archive Folder"; Rec."SharePoint Archive Folder") { ApplicationArea = All; }
                field("SharePoint Error Folder"; Rec."SharePoint Error Folder") { ApplicationArea = All; }
            }

            group(Authentication)
            {
                Caption = 'Authentication';
                field("Tenant ID"; Rec."Tenant ID") { ApplicationArea = All; }
                field("Client ID"; Rec."Client ID") { ApplicationArea = All; }
                field("Client Secret"; Rec."Client Secret") { ApplicationArea = All; }
                field("Token Broker URL"; Rec."Token Broker URL") { ApplicationArea = All; }
            }

            group("File Settings")
            {
                Caption = 'File Settings';
                field("Import Pick File Prefix"; Rec."Import Pick File Prefix") { ApplicationArea = All; }
                  field("Import Ship File Prefix"; Rec."Import Ship File Prefix") { ApplicationArea = All; }

                field("Import Pick File Suffix"; Rec."Import Pick File Suffix") { ApplicationArea = All; }
                 field("Import Ship File Suffix"; Rec."Import Ship File Suffix") { ApplicationArea = All; }

                               field("Filename Chars to Parse"; Rec."Filename Chars to Parse") { ApplicationArea = All; }
            }

            group(Timestamps)
            {
                Caption = 'Timestamps';
                field("Last Export DateTime"; Rec."Last Export DateTime") { ApplicationArea = All; }
                field("Last Import DateTime"; Rec."Last Import DateTime") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(Endpoints)
            {
              
               action(RefreshToken)
            {
                ApplicationArea = All;
                Caption = 'Refresh Token';
                Image = Refresh;
                ToolTip = 'Force refresh the SharePoint access token';

                trigger OnAction()
                var
                    SharePointConnector: Codeunit "SharePoint Graph Connector";
                begin
                    if Confirm('Are you sure you want to refresh the SharePoint access token?') then
                    begin
                        // FIX: Pass the Primary Key of the current record.
                        // REASON: The connector needs to know which setup configuration to use.
                        if SharePointConnector.RefreshToken(Rec."Primary Key") then
                            Message('Token refreshed successfully')
                        else
                            Error('Failed to refresh token: %1', SharePointConnector.GetLastError());
                    end;
                end;
            }
     action("Show Graph API URL (Sanity Check)")
            {
                Caption = 'Show Graph API URL (Sanity Check)';
                ApplicationArea = All;
                Image = Info;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Show the exact Graph API URL that will be used for file access, for troubleshooting and validation.';

                trigger OnAction()
                var
                    // REFACTOR: Use the connector, which has the correct logic.
                    Connector: Codeunit "SharePoint Graph Connector";
                    FileName: Text[250];
                    FullUrl: Text;
                begin
                    // This can be a fixed name for testing, or you can add a field on the page to get user input.
                    FileName := 'SO2179695_picked.xml';

                    // Validate that the required setup fields are not blank.
                    Rec.TestField("SharePoint Library Id");
                    Rec.TestField("SharePoint Import Folder");

                    // REFACTOR: Call the central function in the connector to build the URL.
                    // This guarantees that the URL shown is exactly what the system will use.
                    FullUrl :=
                      Connector.BuildFileContentUrl(
                        Rec."Primary Key", // Use the primary key consistently
                        Rec."SharePoint Import Folder",
                        FileName);

                    Message('Graph API Download URL (from Connector):\n\n%1', FullUrl);
                end;
            }





       
}

            

            group(Integration)
            {
                Caption = 'Import/Export Actions';

                action(ExportAllSalesOrders)
{
    ApplicationArea = All;
    Caption = 'Export All Sales Orders';
    Image = Export;

    trigger OnAction()
    var
        SharePointMgmt: Codeunit "3PL Order SharePoint Mgmt";
    begin
        // Empty filter => export ALL Released Sales Orders for the configured Location
        SharePointMgmt.ExportAllSalesOrders('');
        if GuiAllowed then
            Message('Export process started. Check telemetry/Archive for results.');
    end;
}
               

                action(ProcessImportFiles)
                {
                    Caption = 'Process Import Files';
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        SharepointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                    begin
                        SharepointMgmt.ProcessAll();
                    end;
                }
            }

            group(Tests)
            {
                Caption = 'Connection';

                action(TestConnection)
                {
                    Caption = 'Test connection';
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        GraphConnector: Codeunit "SharePoint Graph Connector";
                    begin
                        if GraphConnector.TestConnection(Rec."3PL Code") then
                            Message('Connection successful.')
                        else
                            Error('Connection failed. Check your settings and see error: %1', GraphConnector.GetLastError());
                    end;
                }

                action("Test SRO Export")
                {
                    Caption = 'Test SRO Export';
                    ApplicationArea = All;
                    Image = Export;
                    ToolTip = 'Generate the SRO export XML for a chosen Return Order and download it locally instead of uploading to SharePoint. Status fields and archive log are still updated, so the order will be marked as exported.';

                    trigger OnAction()
                    var
                        SharepointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                        SalesHeader: Record "Sales Header";
                        SalesReturnOrders: Page "Sales Return Order List";
                        TempBlob: Codeunit "Temp Blob";
                        InS: InStream;
                        FileName: Text;
                    begin
                        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::"Return Order");
                        SalesReturnOrders.SetTableView(SalesHeader);
                        SalesReturnOrders.LookupMode(true);
                        if SalesReturnOrders.RunModal() <> Action::LookupOK then
                            exit;
                        SalesReturnOrders.GetRecord(SalesHeader);

                        SharepointMgmt.ExportSROToSharePoint(SalesHeader, true, TempBlob);

                        TempBlob.CreateInStream(InS);
                        FileName := SalesHeader."No." + '_return.xml';
                        DownloadFromStream(InS, 'Save SRO Export', '', 'XML files (*.xml)|*.xml', FileName);
                    end;
                }

                action("Test SRO Import")
                {
                    Caption = 'Test SRO Import';
                    ApplicationArea = All;
                    Image = Import;
                    ToolTip = 'Select a local SRO confirmation XML file and run it through the standard import flow. Status fields and archive log are updated; SharePoint download and rename are skipped.';

                    trigger OnAction()
                    var
                        SharepointMgmt: Codeunit "3PL Order SharePoint Mgmt";
                        TempBlob: Codeunit "Temp Blob";
                        OutS: OutStream;
                        UploadedInS: InStream;
                        ClientFileName: Text;
                    begin
                        if not UploadIntoStream('Select SRO Confirmation XML', '', 'XML files (*.xml)|*.xml', ClientFileName, UploadedInS) then
                            exit;

                        TempBlob.CreateOutStream(OutS);
                        CopyStream(OutS, UploadedInS);

                        if SharepointMgmt.ImportSROFromStream(TempBlob, ClientFileName) then
                            Message('Test SRO import succeeded for %1.', ClientFileName)
                        else
                            Message('Test SRO import failed for %1. See archive log for details.', ClientFileName);
                    end;
                }
            }

            group(Logs)
            {
                Caption = 'Logs';

                action(ViewIntegrationLog)
                {
                    Caption = 'View Archive log';
                    ApplicationArea = All;

                    trigger OnAction()
                    var
                        LogRec: Record "3PL Archive";
                    begin
                         PAGE.Run(PAGE::"3PL Archive List", LogRec); // Assuming this page exists
                    end;
                }
            }
        }
    }
    
    local procedure SanitizeFileName(FileName: Text): Text
    begin
        exit(DelChr(DelChr(FileName, '<>', ' '), '=', ' '));
    end;
    local procedure EnsureFolderSlash(FolderPath: Text): Text
begin
    if FolderPath = '' then
        exit('');
    if FolderPath[StrLen(FolderPath)] = '/' then
        exit(FolderPath);
    exit(FolderPath + '/');
end;
}