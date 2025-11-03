table 50497 "SharePoint Setup"
{
    DataClassification = SystemMetadata;
    Caption = '3PL Intgration Setup';

    fields
    {
        field(1; "Primary Key"; Code[10]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Primary Key';
        }
        field(2; "SharePoint Site URL"; Text[250]) 
        { 
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'SharePoint Site URL';
            ToolTip = 'Full URL to your SharePoint site (e.g., https://company.sharepoint.com/sites/yoursite)';
        }
        field(3; "Client ID"; Text[100]) 
        { 
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'Client ID';
            ToolTip = 'Application (Client) ID from Azure AD App Registration';
        }
        field(4; "Client Secret"; Text[150]) 
        { 
            DataClassification = EndUserIdentifiableInformation; 
            ExtendedDatatype = Masked;
            Caption = 'Client Secret';
            ToolTip = 'Client secret for your registered application';
        }
        field(5; "Tenant ID"; Text[100]) 
        { 
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'Tenant ID';
            ToolTip = 'Your Azure Active Directory Tenant ID';
        }
        field(6; "3PL Code"; Text[100]) 
        { 
            DataClassification = EndUserIdentifiableInformation;
            Caption = '3PL Code';
            ToolTip = 'Code identifying your 3PL provider';
        }
        field(7; "Location Code"; Code[100])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Location Code';
            ToolTip = 'Default location code to use for 3PL operations';
            TableRelation = Location;
        }
        field(9; "Require Tracking No."; Boolean) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Require Tracking Number';
            ToolTip = 'Specifies whether a tracking number is required for SharePoint operations';
        }

        // FTP settings
        field(10; "FTP Server"; Text[100]) 
        { 
            DataClassification = EndUserIdentifiableInformation; 
            Caption = 'FTP Server';
            ToolTip = 'FTP server address for file transfers';
        }
        field(11; "FTP Port"; Integer) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'FTP Port'; 
            InitValue = 21;
            ToolTip = 'Port number for FTP connections (default 21)';
        }
        field(12; "FTP Username"; Text[50]) 
        { 
            DataClassification = EndUserIdentifiableInformation; 
            Caption = 'FTP Username';
            ToolTip = 'Username for FTP authentication';
        }
        field(13; "FTP Password"; Text[50]) 
        { 
            DataClassification = EndUserIdentifiableInformation; 
            Caption = 'FTP Password';
            ToolTip = 'Password for FTP authentication';
            ExtendedDatatype = Masked;
        }

        field(14; "Enabled"; Boolean) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Enabled';
            ToolTip = 'Enable or disable the integration functionality';
        }
        field(15; "Validate Before Export"; Boolean) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Validate Before Export';
            ToolTip = 'Specifies whether to validate data before exporting';
        }
        field(16; "Token Broker URL"; Text[250])
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'Token Broker URL';
            ToolTip = 'URL of the token broker service for authentication';
        }

        // SharePoint settings
        field(20; "Use SharePoint"; Boolean) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Use SharePoint Instead of FTP';
            ToolTip = 'Specifies whether to use SharePoint for file operations';
        }
        field(21; "SharePoint Base URL"; Text[250]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'SharePoint Host Name';
            ToolTip = 'Base URL for SharePoint (e.g., https://company.sharepoint.com)';
        }
        field(22; "SharePoint Site Name"; Text[100]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'SharePoint Site Name';
            ToolTip = 'Name of the SharePoint site';
        }
        field(23; "SharePoint Library Name"; Text[100]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'SharePoint Library Name';
            ToolTip = 'Name of the document library where files will be stored';
        }
        field(27; "SharePoint Library Id"; Text[100]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'SharePoint Library Id';
            ToolTip = 'The unique ID of your document library';
        }
        field(28; "SharePoint Export Folder"; Text[250]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'SharePoint Export Folder';
            ToolTip = 'Relative path for exported files (e.g., /Shared Documents/Exports)';
        }
        field(29; "SharePoint Import Folder"; Text[250]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'SharePoint Import Folder';
            ToolTip = 'Relative path for imported files (e.g., /Shared Documents/Imports)';
        }
         field(99; "SharePoint Error Folder"; Text[250]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'SharePoint Import Folder';
            ToolTip = 'Relative path for imported files (e.g., /Shared Documents/Imports)';
        }
        field(1000; "SharePoint Site Id"; Text[200]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'SharePoint Site Id';
            ToolTip = 'The unique ID of your SharePoint site';
        }
        
        // File path settings
        field(30; "Export Path"; Text[250]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Export Path';
            ToolTip = 'Local path for exported files';
        }
        field(31; "Import Path"; Text[250]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Import Path';
            ToolTip = 'Local path for imported files';
        }
        field(32; "Archive Path"; Text[250]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Archive Path';
            ToolTip = 'Local path for archived files';
        }

        // File naming
        field(40; "Export File Prefix"; Text[20]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Export File Prefix';
            ToolTip = 'Prefix for exported files';
            InitValue = 'SO_';
        }
        field(41; "Import File Prefix"; Text[20]) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Import File Prefix';
            ToolTip = 'Prefix for imported files';
            InitValue = 'SH_';
        }
        field(1001; "Filename Chars to Parse"; Integer)
        {
            DataClassification = SystemMetadata;
            Caption = '# of Filename Chars to Parse';
            ToolTip = 'Number of characters to use from filename (before .xml) for document matching';
            MinValue = 0;
        }

        // Timestamps
        field(50; "Last Export DateTime"; DateTime) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Last Export DateTime';
            ToolTip = 'Date and time of last successful export';
        }
        field(51; "Last Import DateTime"; DateTime) 
        { 
            DataClassification = SystemMetadata; 
            Caption = 'Last Import DateTime';
            ToolTip = 'Date and time of last successful import';
        }
    
        // --- OAuth/Certificate Legacy Fields ---
        field(9000; "Certificate"; Blob)
        {
            ObsoleteState = Removed;
            ObsoleteReason = 'No longer used in REST model.';
            DataClassification = SystemMetadata;
        }
        field(9001; "Certificate Password"; Text[250])
        {
            ObsoleteState = Removed;
            ObsoleteReason = 'No longer used in REST model.';
            DataClassification = SystemMetadata;
        }
        field(9002; "Azure Auth URL"; Text[250])
        {
            ObsoleteState = Removed;
            ObsoleteReason = 'No longer used in REST model.';
            DataClassification = SystemMetadata;
        }
        field(9003; "Azure Auth Path"; Text[250])
        {
            ObsoleteState = Removed;
            ObsoleteReason = 'No longer used in REST model.';
            DataClassification = SystemMetadata;
        }
        field(9004; "Authorization Type"; Option)
        {
            ObsoleteState = Removed;
            ObsoleteReason = 'No longer used in REST model.';
            OptionMembers = None, OAuth2, Certificate, UsernamePassword;
            DataClassification = SystemMetadata;
        }
        field(9005; "Token Expiration DT"; DateTime)
        {
            ObsoleteState = Removed;
            ObsoleteReason = 'No longer used in REST model.';
            DataClassification = SystemMetadata;
        }
        field(9006; "Timeout (seconds)"; Integer)
        {
            ObsoleteState = Removed;
            ObsoleteReason = 'No longer used in REST model.';
            DataClassification = SystemMetadata;
        }
        field(9007; "Max Retry Attempts"; Integer)
        {
            ObsoleteState = Removed;
            ObsoleteReason = 'No longer used in REST model.';
            DataClassification = SystemMetadata;
        }
         field(33; "SharePoint Archive Folder"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'SharePoint Archive Folder';
            ToolTip = 'Relative path for archived files (e.g., /Shared Documents/Archive)';
    }
    

    }

    keys
    {
        key(PK; "Primary Key") 
        { 
            Clustered = true; 
        }
    }

    trigger OnInsert()
    begin
        if "Primary Key" = '' then
            "Primary Key" := '3PL';
    end;

    trigger OnModify()
    begin
        ValidateConfiguration();
    end;

    procedure ValidateConfiguration()
    begin
        // Only validate if Enabled is true
        if "Enabled" then begin
            if "Use SharePoint" then begin
                if ("SharePoint Site URL" = '') or
                   ("SharePoint Export Folder" = '') or
                   ("SharePoint Import Folder" = '') or
                   ("Client ID" = '') or
                   ("Client Secret" = '') or
                   ("Tenant ID" = '') then
                    Error('All SharePoint connection fields must be filled out when SharePoint is enabled and this record is enabled.');

                if not IsValidSharePointUrl("SharePoint Site URL") then
                    Error('Invalid SharePoint Site URL format. Expected: https://[tenant].sharepoint.com/sites/[sitename]');
            end else begin
                if ("FTP Server" = '') or
                   ("FTP Username" = '') or
                   ("FTP Password" = '') then
                    Error('All FTP connection fields must be filled out when FTP is enabled and this record is enabled.');
            end;

            if "Filename Chars to Parse" < 0 then
                Error('# of characters to parse cannot be negative');
        end;
    end;

    local procedure IsValidSharePointUrl(Url: Text): Boolean
    var
        CleanUrl: Text;
        ProtocolPos: Integer;
    begin
        if Url.Trim() = '' then
            exit(false);

        CleanUrl := Url.Trim().ToLower();
        ProtocolPos := StrPos(CleanUrl, '://');
        
        if ProtocolPos > 0 then
            CleanUrl := CopyStr(CleanUrl, ProtocolPos + 3);
        
        CleanUrl := DelChr(CleanUrl, '>', '/');
        
        // Basic validation for SharePoint URL pattern
        exit(StrPos(CleanUrl, '.sharepoint.com') > 0);
    end;
}