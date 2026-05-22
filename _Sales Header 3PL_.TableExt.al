tableextension 50450 "Sales Header 3PL" extends "Sales Header"
{
    fields
    {
        modify("Sell-to Customer No.")
        {
            trigger OnAfterValidate()
            var
                Customer: Record Customer;
                DefaultCode: Code[20];
            begin
                if Rec.IsTemporary() then
                    exit;
                if Rec."Sell-to Customer No." = '' then
                    exit;
                if not Customer.Get(Rec."Sell-to Customer No.") then
                    exit;

                if Customer."3PL Prep Code" <> '' then begin
                    Rec.Validate("3PL Prep Code", Customer."3PL Prep Code");
                    exit;
                end;

                DefaultCode := Rec.GetDefault3PLPrepCode();
                if DefaultCode <> '' then
                    Rec.Validate("3PL Prep Code", DefaultCode);
            end;
        }
        field(50450; "3PL Imported"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = '3PL Imported';
        }
        field(50451; "3PL Tracking No."; Code[50])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Tracking Number';
            ObsoleteState = Pending;
            ObsoleteReason = 'Use standard "Package Tracking No." instead.';
            ObsoleteTag = '2026-05';
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
            Caption = '3PL Order Exported';
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
        field(50461; "3PL Gift Wrap"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = '3PL Gift Wrap';
        }
        field(50462; "3PL Gift Message"; Text[250])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Gift Message';
        }
        field(50463; "3PL Preparation Code"; Text[250])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Preparation Code';
            ObsoleteState = Pending;
            ObsoleteReason = 'Replaced by "3PL Prep Code" (field 50469).';
            ObsoleteTag = '2026-05';
        }
        field(50467; "3PL Preparation Dimension Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Preparation Dimension Code';
            TableRelation = Dimension;
            ObsoleteState = Pending;
            ObsoleteReason = 'Replaced by "3PL Prep Code" (field 50469).';
            ObsoleteTag = '2026-05';
        }
        field(50464; "3PL Priority"; Integer)
        {
            Caption = 'Priority';
            DataClassification = CustomerContent;
        }
        field(50465; "3PL COD"; Boolean)
        {
            Caption = 'COD';
            DataClassification = CustomerContent;
        }
        field(50466; "3PL COD Amount"; Decimal)
        {
            Caption = 'COD Amount';
            DataClassification = CustomerContent;
        }
        field(50469; "3PL Prep Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Prep Code';
            TableRelation = "3PL Prep Code Setup".Code where(Blocked = const(false));

            trigger OnValidate()
            begin
                Update3PLPrepCodeDescription();
            end;
        }
        field(50470; "3PL Prep Description"; Text[100])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Prep Description';
            Editable = false;
        }
        field(50476; "3PL Skipped"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = '3PL Skipped';
        }

    }

    trigger OnAfterInsert()
    var
        DefaultPrepCode: Code[20];
    begin
        "3PL Imported" := false;
        "3PL Exported" := false;
        "Imported Pick Confirmation" := false;
        "Imported Shipped Confirmation" := false;
        "3PL Export Date" := 0D;
        "3PL Import Date" := 0D;
        "Imported Pick Conf. Date" := 0D;
        "Imported Shipped Conf. Date" := 0D;

        if "3PL Prep Code" = '' then begin
            DefaultPrepCode := GetDefault3PLPrepCode();
            if DefaultPrepCode <> '' then
                Validate("3PL Prep Code", DefaultPrepCode);
        end;
    end;

    trigger OnAfterDelete()
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

    /*
    procedure Reset3PLFields()
    begin
        "3PL Imported" := false;
        "3PL Exported" := false;
        "Imported Pick Confirmation" := false;
        "Imported Shipped Confirmation" := false;
        "3PL Export Date" := 0D;
        "3PL Import Date" := 0D;
        "Imported Pick Conf. Date" := 0D;
        "Imported Shipped Conf. Date" := 0D;
        Modify();
    end;

    procedure ClearExport3PLFields()
    begin
        "3PL Exported" := false;
        "3PL Order Exported" := false;
        "3PL COD Exported" := false;
        "3PL Export Date" := 0D;
        Modify();
    end;

    procedure ClearPickConfirmation3PLFields()
    begin
        "Imported Pick Confirmation" := false;
        "Imported Pick Conf. Date" := 0D;
        RefreshImported3PLFlag();
        Modify();
    end;

    procedure ClearShipConfirmation3PLFields()
    begin
        "Imported Shipped Confirmation" := false;
        "Imported Shipped Conf. Date" := 0D;
        RefreshImported3PLFlag();
        Modify();
    end;

    local procedure RefreshImported3PLFlag()
    begin
        if (not "Imported Pick Confirmation") and (not "Imported Shipped Confirmation") then begin
            "3PL Imported" := false;
            "3PL Import Date" := 0D;
        end;
    end;
    */

    local procedure Update3PLPrepCodeDescription()
    var
        PrepCodeSetup: Record "3PL Prep Code Setup";
    begin
        if "3PL Prep Code" = '' then begin
            "3PL Prep Description" := '';
            exit;
        end;

        if PrepCodeSetup.Get("3PL Prep Code") then
            "3PL Prep Description" := PrepCodeSetup.Description
        else
            "3PL Prep Description" := '';
    end;

    procedure GetDefault3PLPrepCode(): Code[20]
    var
        PrepCodeSetup: Record "3PL Prep Code Setup";
    begin
        PrepCodeSetup.SetRange("Default Code", true);
        if PrepCodeSetup.FindFirst() then
            exit(PrepCodeSetup.Code);

        exit('');
    end;
}


