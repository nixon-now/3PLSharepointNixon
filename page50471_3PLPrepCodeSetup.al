page 50471 "3PL Prep Code Setup Card"
{
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "3PL Prep Code Setup";
    Caption = '3PL Prep Code Setup';
    Editable = true;

    layout
    {
        area(content)
        {
            group(General)
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
