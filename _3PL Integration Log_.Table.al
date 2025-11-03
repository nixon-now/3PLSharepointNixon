table 50401 "3PL Integration Log"
{
    Caption = '3PL Integration Log';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
        }
        field(2; "Activity Type"; Option)
        {
            Caption = 'Activity Type';
            OptionMembers = Export, Import;
            DataClassification = SystemMetadata;
        }
        field(3; "Document Type"; Option)
        {
            Caption = 'Document Type';
            OptionMembers = Quote, Order, Invoice, CreditMemo, BlanketOrder, ReturnOrder;
            DataClassification = SystemMetadata;
        }
        field(4; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            DataClassification = CustomerContent;
        }
        field(5; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            DataClassification = CustomerContent;
        }
        field(6; "File Name"; Text[250])
        {
            Caption = 'File Name';
            DataClassification = SystemMetadata;
        }
        field(7; "Record Count"; Integer)
        {
            Caption = 'Record Count';
            DataClassification = SystemMetadata;
        }
        field(8; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = SystemMetadata;
        }
        field(9; "Date"; DateTime)
        {
            Caption = 'Timestamp';
            DataClassification = SystemMetadata;
        }
        field(10; "Success"; Boolean)
        {
            Caption = 'Success';
            DataClassification = SystemMetadata;
        }
    }
    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}
