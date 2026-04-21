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
            //TableRelation = "Dimension Value".Code where("Dimension Code" = field("3PL Preparation Code"));

            trigger OnValidate()
            begin
                //Update3PLPrepCodeDimension();
            end;
        }

        // Helper field to store the dimension code
        field(50467; "3PL Preparation Dimension Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Preparation Dimension Code"';
            TableRelation = Dimension;
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
        field(50471; "3PL SRO Exported"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = '3PL Return Order Exported';
        }
        field(50472; "3PL SRO Export Date"; Date)
        {
            DataClassification = CustomerContent;
            Caption = '3PL Return Order Export Date';
        }
        field(50473; "Imported SRO Confirmation"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = 'Imported Return Receipt Confirmation';
        }
        field(50474; "Imported SRO Conf. Date"; Date)
        {
            DataClassification = CustomerContent;
            Caption = 'Imported Return Receipt Conf. Date';
        }
        field(50475; "3PL SRO Reception No."; Code[30])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Return Reception No.';
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
        "3PL SRO Exported" := false;
        "3PL SRO Export Date" := 0D;
        "Imported SRO Confirmation" := false;
        "Imported SRO Conf. Date" := 0D;
        "3PL SRO Reception No." := '';
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
        "3PL SRO Exported" := false;
        "3PL SRO Export Date" := 0D;
        "Imported SRO Confirmation" := false;
        "Imported SRO Conf. Date" := 0D;
        "3PL SRO Reception No." := '';
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
        "3PL SRO Exported" := false;
        "3PL SRO Export Date" := 0D;
        "Imported SRO Confirmation" := false;
        "Imported SRO Conf. Date" := 0D;
        "3PL SRO Reception No." := '';
        Modify();
    end;

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


