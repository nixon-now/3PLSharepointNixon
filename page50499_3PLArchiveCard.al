page 50499 "3PL Archive Card"
{
    PageType = Card;
    SourceTable = "3PL Archive";
    ApplicationArea = All;
    UsageCategory = Documents;

    layout
    {
        area(content)
        {
            group("General")
            {
                field("Entry No."; Rec."Entry No.") { }
                //field("Archive DateTime"; Rec."Archive DateTime") { }
                field("Archive Date/Time"; Rec."Archive Date/Time") { }
                field(Direction; Rec.Direction) { }
                field("Document No."; Rec."Document No.") { }
                field("External Doc No."; Rec."External Doc No.") { }
                field("File Name"; Rec."File Name") { }
                //field(Result; Rec.Result) { }
                field("Result"; Rec."ResultOption") { }
                field("Error Message"; Rec."Error Message") { }
                field("Location Code"; Rec."Location Code") { }
                field("3PL Code"; Rec."3PL Code") { }
                field(Step; Rec.Step) { }
                field("User ID"; Rec."User ID") { }
                field("Integration ID"; Rec."Integration ID") { }
                field("Sharepoint Export Folder"; Rec."Sharepoint Export Folder") { }
                field("Date/Time"; Rec."Archive Date/Time") { }
            }

            group("Blob")
            {
                field("Blob Content"; Rec."Blob Content") { ApplicationArea = All; }
            }
        }
    }
}
