table 50470 "3PL Prep Code Setup"
{
    DataClassification = CustomerContent;
    Caption = '3PL Preparation Code Setup';

    fields
    {
        field(1; "Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = 'Code';
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            DataClassification = CustomerContent;
            Caption = 'Description';
        }
        field(3; Priority; Integer)
        {
            DataClassification = CustomerContent;
            Caption = 'Priority';
        }
        field(4; "Default Code"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = 'Default Code';
        }
        field(5; Blocked; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = 'Blocked';
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
        key(Priority; Priority)
        {
        }
    }

    trigger OnInsert()
    begin
        ValidateSetup();
    end;

    trigger OnModify()
    begin
        ValidateSetup();
    end;

    local procedure ValidateSetup()
    var
        PrepCodeSetup: Record "3PL Prep Code Setup";
    begin
        if Blocked then
            TestField("Default Code", false);

        if "Default Code" then begin
            PrepCodeSetup.SetRange("Default Code", true);
            PrepCodeSetup.SetFilter(Code, '<>%1', Code);
            if not PrepCodeSetup.IsEmpty then
                Error('There can only be one default 3PL preparation code.');
        end;
    end;
}