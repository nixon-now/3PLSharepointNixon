tableextension 50411 "SalesSetup Ext 3PL" extends "Sales & Receivables Setup"
{
    fields
    {
        field(50411; "G/L Freight Account No."; Code[20])
        {
            Caption = 'G/L Freight Account No.';
            DataClassification = CustomerContent;
            TableRelation = "G/L Account";
            Description = 'Specifies the default G/L Account No. to post freight charges for 3PL imports.';
        }
         
    }
}
