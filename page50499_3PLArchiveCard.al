page 50499 "3PL Archive Card"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "3PL Archive";
    Caption = '3PL Archive Details';
    Editable = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field("Archive Date/Time"; Rec."Archive Date/Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date and time of the integration event';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Sales document number related to this event';
                }
                field("External Doc No."; Rec."External Doc No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'External document reference number';
                }
                field(Direction; Rec.Direction)
                {
                    ApplicationArea = All;
                    ToolTip = 'Direction of integration (Export/Import)';
                }
                field(Step; Rec.Step)
                {
                    ApplicationArea = All;
                    ToolTip = 'Which integration step was performed';
                }
                field(Result; Rec.Result)
                {
                    ApplicationArea = All;
                    ToolTip = 'Result of the operation (Success/Error)';
                }
                field("File Name"; Rec."File Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Name of the file processed';
                }
            }
            group(Details)
            {
                field("Sharepoint Archive Folder"; Rec."Sharepoint Archive Folder")
                {
                    ApplicationArea = All;
                    ToolTip = 'Archive folder path in SharePoint';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Location code for this transaction';
                }
                field("3PL Code"; Rec."3PL Code")
                {
                    ApplicationArea = All;
                    ToolTip = '3PL provider code';
                }
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'User who performed the action';
                }
                field("Integration ID"; Rec."Integration ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unique identifier for this integration event';
                }
            }
            group(Error)
            {
                Caption = 'Error Details';
                Visible = Rec.ResultOption = Rec.ResultOption::Error;
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Detailed error message';
                    MultiLine = true;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenDocument)
            {
                ApplicationArea = All;
                Caption = 'Open Document';
                Image = Document;
                ToolTip = 'Open the related sales document';
                Enabled = Rec."Document No." <> '';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    if Rec."Document No." <> '' then
                    begin
                        SalesHeader.SetRange("No.", Rec."Document No.");
                        if SalesHeader.FindFirst() then
                            PAGE.Run(PAGE::"Sales Order", SalesHeader);
                    end;
                end;
            }
        }
    }
}