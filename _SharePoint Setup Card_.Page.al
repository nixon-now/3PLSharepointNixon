page 50497 "SharePoint Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "SharePoint Setup";
    Caption = '3PL Integration Setup';
    DeleteAllowed = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General Settings';
                field("Primary Key"; Rec."Primary Key") 
                { 
                    ApplicationArea = All; 
                    ToolTip = 'Specifies the primary key for this setup record.'; 
                    Visible = false; 
                }
                field(Enabled; Rec.Enabled) 
                { 
                    ApplicationArea = All; 
                    ToolTip = 'Enable or disable the SharePoint integration functionality.'; 
                    Caption = 'Enabled'; 
                }
                field("Use SharePoint"; Rec."Use SharePoint") 
                { 
                    ApplicationArea = All; 
                    ToolTip = 'Specifies whether to use SharePoint for file operations.'; 
                    Caption = 'Use SharePoint'; 
                }
                field("Require Tracking No."; Rec."Require Tracking No.") 
                { 
                    ApplicationArea = All; 
                    ToolTip = 'Specifies whether a tracking number is required for SharePoint operations.'; 
                    Caption = 'Require Tracking Number'; 
                }
            }

            group("SharePoint Connection")
            {
                Caption = 'SharePoint Connection';
                Visible = Rec."Use SharePoint";
                
               
               
                field("SharePoint Site URL"; Rec."SharePoint Site URL") 
                { 
                    ApplicationArea = All; 
                    Caption = 'SharePoint Site URL'; 
                    ToolTip = 'Full URL to your SharePoint site (e.g., https://company.sharepoint.com/sites/yoursite)'; 
                      trigger OnValidate()
    begin
        Rec.ValidateConfiguration();
    end;
                }
                
                field("SharePoint Site Name"; Rec."SharePoint Site Name")
                {
                    ApplicationArea = All;
                    Caption = 'SharePoint Site Name';
                    ToolTip = 'Name of the SharePoint site';
                }
                
                field("SharePoint Site Id"; Rec."SharePoint Site Id")
                {
                    ApplicationArea = All;
                    Caption = 'SharePoint Site ID';
                    ToolTip = 'The unique ID of your SharePoint site (found in Site Settings)';
                }
                
                field("SharePoint Library Name"; Rec."SharePoint Library Name") 
                { 
                    ApplicationArea = All; 
                    Caption = 'Document Library Name'; 
                    ToolTip = 'Name of the document library where files will be stored'; 
                }
                
                field("SharePoint Library Id"; Rec."SharePoint Library Id") 
                { 
                    ApplicationArea = All; 
                    Caption = 'Document Library ID'; 
                    ToolTip = 'The unique ID of your document library'; 
                }

                field("Token Broker URL"; Rec."Token Broker URL")
                {
                    ApplicationArea = All;
                    Caption = 'Token Broker URL';
                    ToolTip = 'URL of the token broker service for authentication';
                }

                field("Tenant ID"; Rec."Tenant ID") 
                { 
                    ApplicationArea = All; 
                    Caption = 'Azure AD Tenant ID'; 
                    ToolTip = 'Your Azure Active Directory Tenant ID'; 
                    ExtendedDatatype = Masked;
                }
                
                field("Client ID"; Rec."Client ID") 
                { 
                    ApplicationArea = All; 
                    Caption = 'Application (Client) ID'; 
                    ToolTip = 'The Application ID from your Azure AD App Registration'; 
                }
                
                field("Client Secret"; Rec."Client Secret") 
                { 
                    ApplicationArea = All; 
                    Caption = 'Client Secret'; 
                    ToolTip = 'The client secret for your registered application'; 
                    ExtendedDatatype = Masked;
                }
                
                field("SharePoint Export Folder"; Rec."SharePoint Export Folder") 
                { 
                    ApplicationArea = All; 
                    Caption = 'Export Folder Path'; 
                    ToolTip = 'Relative path for exported files (e.g., /Shared Documents/Exports)'; 
                }
                
                field("SharePoint Import Folder"; Rec."SharePoint Import Folder") 
                { 
                    ApplicationArea = All; 
                    Caption = 'Import Folder Path'; 
                    ToolTip = 'Relative path for imported files (e.g., /Shared Documents/Imports)'; 
                }
                 field("SharePoint Archive Folder"; Rec."SharePoint Archive Folder") { ApplicationArea = All; Caption = 'Archive Folder Path'; ToolTip = 'Relative path for archived files'; }
                 field("SharePoint Error Folder"; Rec."SharePoint Error Folder") { ApplicationArea = All; Caption = 'Error Folder Path'; ToolTip = 'Relative path for error files'; }
            }

           
            group("3PL Integration")
            {
                Caption = '3PL Integration Settings';
                // Add to the "SharePoint Connection" group in the page
field("Filename Chars to Parse"; Rec."Filename Chars to Parse")
{
    ApplicationArea = All;
    Caption = '# of Filename Chars to Parse';
    ToolTip = 'Number of characters to use from filename (before .xml) for matching (0 = use all)';
}
                field("3PL Code"; Rec."3PL Code") 
                { 
                    ApplicationArea = All; 
                    Caption = '3PL Provider Code'; 
                    ToolTip = 'Code identifying your 3PL provider'; 
                }
                
                field("Location Code"; Rec."Location Code") 
                { 
                    ApplicationArea = All; 
                    Caption = 'Default Location Code'; 
                    ToolTip = 'Default location code to use for 3PL operations'; 
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                Caption = 'Test Connection';
                ApplicationArea = All;
                Image = TestDatabase;
                Promoted = true;
                PromotedCategory = Process;
                
                trigger OnAction()
                var
                    SharePointGraph: Codeunit "SharePoint Graph Connector";
                    Result: Boolean;
                begin
                    Result := SharePointGraph.TestConnection(Rec."Primary Key");
                    if Result then
                        Message('SharePoint connection successful!')
                    else
                        Error('SharePoint connection failed: %1', SharePointGraph.GetLastError());
                end;
            }
             action(OpenArchive)
            {
                Caption = 'View 3PL Archive';
                ApplicationArea = All;
                Image = Archive;
                Promoted = true;
                PromotedCategory = Process;
                RunObject = Page "3PL Archive List"; // Page 50498
                ToolTip = 'View the history of all integration transactions';
            }
            
          } 
            
        }
    

    trigger OnOpenPage()
    begin
        if not Rec.Get('3PL') then begin
            Rec.Init();
            Rec.Insert(true);
        end;
    end;

   

    var
        InstructionsTxt: Label 'Configure your SharePoint integration settings below. Ensure you have registered an application in Azure AD with the appropriate permissions.';
}