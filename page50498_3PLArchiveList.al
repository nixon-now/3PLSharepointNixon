page 50498 "3PL Archive List"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = History;
    SourceTable = "3PL Archive";
    SourceTableView = sorting("Archive Date/Time") order(descending);
    Caption = '3PL Integration Archive';
    Editable = false;
    CardPageId = "3PL Archive Card";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Archive Date/Time"; Rec."Archive Date/Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date and time of the integration event.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Sales document number related to this event.';
                }
                field(Direction; Rec.Direction)
                {
                    ApplicationArea = All;
                    ToolTip = 'Direction of integration (Export/Import).';
                }
                field(Result; Rec.Result)
                {
                    ApplicationArea = All;
                    ToolTip = 'Result of the operation (Success/Error).';
                }
                field("File Name"; Rec."File Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Name of the file processed.';
                }
            }
        }
        area(FactBoxes)
        {
            part(ErrorDetails; "Error Message Part")
            {
                ApplicationArea = All;
                SubPageLink = "Entry No." = FIELD("Entry No.");
                Visible = ShowErrorFactBox;
            }
        }
    }

    var
        ShowErrorFactBox: Boolean;

    trigger OnAfterGetRecord()
    begin
        ShowErrorFactBox := Rec.ResultOption = Rec.ResultOption::Error;
    end;
}
