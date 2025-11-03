table 50400 "3PL Setup"
{
    Caption = '3PL Integration Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            DataClassification = SystemMetadata;
            Caption = 'Primary Key';
        }
        field(2; "Enabled"; Boolean)
        {
            DataClassification = SystemMetadata;
            Caption = 'Enabled';
        }
        field(3; "Validate Before Export"; Boolean)
        {
            DataClassification = SystemMetadata;
            Caption = 'Validate Before Export';
        }
        field(4; "Require Tracking No."; Boolean)
        {
            DataClassification = SystemMetadata;
            Caption = 'Require Tracking Number';
        }
        // FTP Configuration
        field(10; "FTP Server"; Text[100])
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'FTP Server';
        }
        field(11; "FTP Port"; Integer)
        {
            DataClassification = SystemMetadata;
            Caption = 'FTP Port';
            InitValue = 21;
        }
        field(12; "FTP Username"; Text[50])
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'FTP Username';
        }
        field(13; "FTP Password"; Text[50])
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'FTP Password';
            ExtendedDatatype = Masked;
        }
        field(30; "Export Path"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'Export Path';
        }
        field(31; "Import Path"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'Import Path';
        }
        field(32; "Archive Path"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'Archive Path';
        }
        // SharePoint Configuration
        field(20; "Use SharePoint"; Boolean)
        {
            DataClassification = SystemMetadata;
            Caption = 'Use SharePoint Instead of FTP';
        }
        field(21; "SharePoint Base URL"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'SharePoint Base URL';
        }
        field(22; "SharePoint Site Name"; Text[100])
        {
            DataClassification = SystemMetadata;
            Caption = 'SharePoint Site Name';
        }
        field(23; "SharePoint Library Name"; Text[100])
        {
            DataClassification = SystemMetadata;
            Caption = 'SharePoint Library Name';
        }
        field(24; "SharePoint Auth Type"; Option)
        {
            DataClassification = SystemMetadata;
            Caption = 'Authentication Type';
            OptionMembers = "OAuth", "Basic";
            OptionCaption = 'OAuth,Basic';
        }
        field(25; "SharePoint Username"; Text[100])
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'SharePoint Username';
        }
        field(26; "SharePoint Password"; Text[100])
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'SharePoint Password';
            ExtendedDatatype = Masked;
        }
        field(27; "SharePoint Library Id"; Text[100])
        {
            DataClassification = SystemMetadata;
            Caption = 'SharePoint Library Id';
        }
        field(28; "SharePoint Export Folder"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'SharePoint Export Folder';
        }
        field(29; "SharePoint Import Folder"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'SharePoint Import Folder';
        }
        // File Naming
        field(40; "Export File Prefix"; Text[20])
        {
            DataClassification = SystemMetadata;
            Caption = 'Export File Prefix';
            InitValue = 'SO_';
        }
        field(41; "Import File Prefix"; Text[20])
        {
            DataClassification = SystemMetadata;
            Caption = 'Import File Prefix';
            InitValue = 'SH_';
        }
        // Status Tracking
        field(50; "Last Export DateTime"; DateTime)
        {
            DataClassification = SystemMetadata;
            Caption = 'Last Export DateTime';
        }
        field(51; "Last Import DateTime"; DateTime)
        {
            DataClassification = SystemMetadata;
            Caption = 'Last Import DateTime';
        }
        field(52; "Location Code"; Code[10])
        {
            DataClassification = CustomerContent;
            Caption = 'Location Code';
            TableRelation = Location;
        }
        field(53; "3PL Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Code';
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
        if "Primary Key" = '' then "Primary Key":='3PL';
    end;
    trigger OnModify()
    begin
        ValidateConfiguration();
    end;
    local procedure ValidateConfiguration()
    begin
    //if "Use SharePoint" then begin
    //  if "SharePoint Base URL" = '' then
    //      Error('SharePoint Base URL must be specified when using SharePoint');
    //  if "SharePoint Site Name" = '' then
    //      Error('SharePoint Site Name must be specified');
    //end;
    end;
}
