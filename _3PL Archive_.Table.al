table 50410 "3PL Archive"
{
    Caption = '3PL Archive';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
            AutoIncrement = true;
            Caption = 'Entry No.';
        }
        field(2; "Archive DateTime"; DateTime)
        {
            DataClassification = SystemMetadata;
            Caption = 'Archive Date/Time';
        }
        field(3; "Direction"; Enum "3PL Log Direction")
        {
            DataClassification = ToBeClassified;
            Caption = 'Direction';
        }
        field(4; "Document No."; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = 'Document No.';
        }
        field(5; "External Doc No."; Code[30])
        {
            DataClassification = CustomerContent;
            Caption = 'External Document No.';
        }
        field(6; "File Name"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'File Name';
        }
        field(7; "Result"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'Result';
        }
        field(8; "Error Message"; Text[250])
        {
            DataClassification = ToBeClassified;
            Caption = 'Error Message';
        }
        field(9; "Location Code"; Code[10])
        {
            DataClassification = CustomerContent;
            Caption = 'Location Code';
            TableRelation = Location;
        }
        field(10; "3PL Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Code';
        }
        field(11; "Step"; Enum "3PL Archive Step")
        {
            DataClassification = SystemMetadata;
            Caption = 'Import/Export Step';
        }
        field(12; "User ID"; Code[50])
        {
            DataClassification = EndUserIdentifiableInformation;
            Caption = 'User ID';
            TableRelation = User."User Name";
        }
        field(13; "Integration ID"; Guid)
        {
            DataClassification = SystemMetadata;
            Caption = 'Integration ID';
        }
        field(14; "Blob Content"; Blob)
        {
            DataClassification = SystemMetadata;
            Caption = 'File Content';
            Subtype = Memo;
        }
         field(15; "Date/Time"; DateTime)
        {
            DataClassification = SystemMetadata;
            Caption = 'Date/Time';
        }
        field(16; "SharePoint Archive Folder"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'SharePoint Archive Folder';
            ToolTip = 'Path to the archived file in SharePoint';
        }
         field(17; "ResultOption"; Option)
        {
            DataClassification = SystemMetadata;
            Caption = 'Result Option';
            OptionMembers = Success,Error;
            OptionCaption = 'Success,Error';
        }
        field(18; "Archive Date/Time"; DateTime)
        {
            DataClassification = SystemMetadata;
            Caption = 'Archive Date/Time';
        }
        
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(DocNo; "Document No.")
        {
        }
        key(FileName; "File Name")
        {
        }
        key(Location; "Location Code")
        {
        }
        key(Step; "Step")
        {
        }
        key(UserID; "User ID")
        {
        }
        key("Archive DateTime"; "Archive Date/Time")
        {
        }
    }
}
