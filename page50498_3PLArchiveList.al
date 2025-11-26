page 50498 "3PL Archive List"
{
    PageType = List;
    SourceTable = "3PL Archive";
    ApplicationArea = All;
    UsageCategory = Administration;

    // Add this property to set the default sort order
    SourceTableView = sorting("Entry No.") order(descending);

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.") { }
                
                field("Archive Date/Time"; Rec."Archive Date/Time") { }
                field(Direction; Rec.Direction) { }
                field("Document No."; Rec."Document No.") { }
                field("External Doc No."; Rec."External Doc No.") { }
                field("File Name"; Rec."File Name") { }
                
                field("Result"; Rec."ResultOption") { }
                field("Error Message"; Rec."Error Message") { }
                field("Location Code"; Rec."Location Code") { }
                field("3PL Code"; Rec."3PL Code") { }
                field(Step; Rec.Step) { }
                field("User ID"; Rec."User ID") { }
                field("Integration ID"; Rec."Integration ID") { }
                field("Sharepoint Export Folder"; Rec."SharePoint Export Folder") { }
              
            }
        }
    }
}
