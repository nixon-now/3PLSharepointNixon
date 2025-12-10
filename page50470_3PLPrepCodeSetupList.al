page 50470 "3PL Prep Code Setup List"
{
    PageType = List;
    ApplicationArea = All;
    SourceTable = "3PL Prep Code Setup";
    Caption = '3PL Prep Code Setup';
    UsageCategory = Administration;
    Editable = true;
    CardPageId = "3PL Prep Code Setup Card";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Code; Rec.Code)
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field(Priority; Rec.Priority)
                {
                    ApplicationArea = All;
                }
                field("Default Code"; Rec."Default Code")
                {
                    ApplicationArea = All;
                }
                field(Blocked; Rec.Blocked)
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
