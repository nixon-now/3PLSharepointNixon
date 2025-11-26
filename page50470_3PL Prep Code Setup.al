page 50470 "3PL Prep Code Setup"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = '3PL Preparation Code Setup';
    SourceTable = "3PL Prep Code Setup";
    SourceTableView = order(ascending);

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the 3PL preparation code.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the description for this preparation code.';
                }
                field(Priority; Rec.Priority)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the display priority (sort order).';
                }
                field("Default Code"; Rec."Default Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies if this is the default preparation code.';
                }
                field(Blocked; Rec.Blocked)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies if this preparation code is blocked from use.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SetDefaults)
            {
                ApplicationArea = All;
                Caption = 'Set Default Values';
                Image = Setup;
                Promoted = true;
                PromotedCategory = Process;
                ToolTip = 'Set up default 3PL preparation codes.';

                trigger OnAction()
                begin
                    InsertDefaultValues();
                end;
            }
        }
    }

    local procedure InsertDefaultValues()
    var
        PrepCodeSetup: Record "3PL Prep Code Setup";
    begin
        if not Confirm('This will insert default 3PL preparation codes. Continue?') then
            exit;

        InsertPrepCode('1A', '1ST PRIORITY-OTHER MP 24 HR', 1);
        InsertPrepCode('2', '2nd PRIORITY - DTC - 24 HR', 2);
        InsertPrepCode('3', '3rd PRIORITY, W-SALE - 48 HR', 3);
        InsertPrepCode('4', '4th PRIORITY, SER/PROMO 48 HR', 4);
        InsertPrepCode('5', '5th PRIORITY TRANSFERS - 48-72', 5);

        Message('Default 3PL preparation codes have been created.');
    end;

    local procedure InsertPrepCode(Code: Code[20]; Description: Text[100]; Priority: Integer)
    var
        PrepCodeSetup: Record "3PL Prep Code Setup";
    begin
        if not PrepCodeSetup.Get(Code) then begin
            PrepCodeSetup.Init();
            PrepCodeSetup.Code := Code;
            PrepCodeSetup.Description := Description;
            PrepCodeSetup.Priority := Priority;
            PrepCodeSetup.Insert();
        end;
    end;
}