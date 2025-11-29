page 50449 "String List Selection"
{
    PageType = List;
    SourceTableTemporary = true;
    SourceTable = "String List Buffer";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Select a String';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Value"; Rec."Value") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OK)
            {
                Caption = 'OK';
                Image = Approve;
                trigger OnAction()
                begin
                    if Rec."Value" = '' then
                        Error('No value selected.');

                    CurrPage.Close();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        CurrPage.Update(false);
    end;

    procedure SetList(Strings: List of [Text])
    var
        TempRec: Record "String List Buffer" temporary;
        StrVal: Text;
    begin
        foreach StrVal in Strings do begin
            TempRec.Init();
            TempRec."Value" := StrVal;
            TempRec.Insert();
        end;
        CurrPage.Update(false);
    end;

    procedure GetSelected(): Text
    begin
        exit(Rec."Value");
    end;
}
