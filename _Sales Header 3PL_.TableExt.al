tableextension 50450 "Sales Header 3PL" extends "Sales Header"
{
    fields
    {
        field(50450; "3PL Imported"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = '3PL Imported';
        }
        field(50451; "3PL Tracking No."; Code[50])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Tracking Number';
        }
        field(50452; "3PL Export Date"; Date)
        {
            DataClassification = CustomerContent;
            Caption = '3PL Export Date';
        }
        field(50453; "3PL Import Date"; Date)
        {
            DataClassification = CustomerContent;
            Caption = '3PL Import Date';
        }
        field(50455; "3PL Exported"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = '3PL Exported';
        }
        field(50456; "Imported Pick Confirmation"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = 'Imported Pick Confirmation';
        }
        field(50457; "Imported Pick Conf. Date"; Date)
        {
            DataClassification = CustomerContent;
            Caption = 'Imported Pick Conf. Date';
        }
        field(50458; "Imported Shipped Confirmation"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = 'Imported Shipped Confirmation';
        }
        field(50459; "Imported Shipped Conf. Date"; Date)
        {
            DataClassification = CustomerContent;
            Caption = 'Imported Shipped Conf. Date';
        }
         field(50460; "3PL COD Exported"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = 'Exported COD to 3PL';
        }
    }

    trigger OnAfterInsert()
    begin
        "3PL Imported" := false;
        "3PL Exported" := false;
        "Imported Pick Confirmation" := false;
        "Imported Shipped Confirmation" := false;
        "3PL Export Date" := 0D;
        "3PL Import Date" := 0D;
        "Imported Pick Conf. Date" := 0D;
        "Imported Shipped Conf. Date" := 0D;
    end;

    trigger OnAfterModify()
    begin
        if "3PL Imported" then
            "3PL Import Date" := Today
        else
            "3PL Import Date" := 0D;
        if "Imported Pick Confirmation" then
            "Imported Pick Conf. Date" := Today
        else
            "Imported Pick Conf. Date" := 0D;
        if "Imported Shipped Confirmation" then
            "Imported Shipped Conf. Date" := Today
        else
            "Imported Shipped Conf. Date" := 0D;
    end;

    trigger OnAfterDelete()
    begin
        "3PL Imported" := false;
        "3PL Exported" := false;
        "Imported Pick Confirmation" := false;
        "Imported Shipped Confirmation" := false;
        "3PL Tracking No." := '';
        "3PL Export Date" := 0D;
        "3PL Import Date" := 0D;
        "Imported Pick Conf. Date" := 0D;
        "Imported Shipped Conf. Date" := 0D;
    end;

    procedure Reset3PLFields()
    begin
        "3PL Imported" := false;
        "3PL Exported" := false;
        "Imported Pick Confirmation" := false;
        "Imported Shipped Confirmation" := false;
        "3PL Tracking No." := '';
        "3PL Export Date" := 0D;
        "3PL Import Date" := 0D;
        "Imported Pick Conf. Date" := 0D;
        "Imported Shipped Conf. Date" := 0D;
        Modify();
    end;
}
