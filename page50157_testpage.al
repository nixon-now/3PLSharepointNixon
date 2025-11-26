page 50155 "3PL Dimension Diagnostic"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = '3PL Dimension Diagnostic';
    SourceTable = "Sales Header";
    SourceTableView = where("Document Type" = const(Order),
                           Status = filter(Open | Released));

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                }
                field("Sell-to Customer No."; Rec."Sell-to Customer No.")
                {
                    ApplicationArea = All;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                }
                field("3PL PREP Code"; Rec."3PL PREP Code")
                {
                    ApplicationArea = All;
                    Style = Strong;
                    StyleExpr = NeedsUpdate;
                }
                field(CurrentDimValue; CurrentDimValue)
                {
                    ApplicationArea = All;
                    Caption = 'Current 3PL PREP CODE';
                    Editable = false;
                }
                field(NeedsUpdate; NeedsUpdate)
                {
                    ApplicationArea = All;
                    Caption = 'Needs Update';
                    Editable = false;
                }
                field(DimensionStatus; DimensionStatus)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    Editable = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        DimensionSetEntry: Record "Dimension Set Entry";
    begin
        // Get current dimension value for 3PL PREP CODE
        DimensionSetEntry.SetRange("Dimension Set ID", Rec."Dimension Set ID");
        DimensionSetEntry.SetRange("Dimension Code", '3PL PREP CODE');
        if DimensionSetEntry.FindFirst() then
            CurrentDimValue := DimensionSetEntry."Dimension Value Code"
        else
            CurrentDimValue := '';

        // Check if update needed
        NeedsUpdate := (Rec."3PL PREP Code" <> '') and (CurrentDimValue <> Rec."3PL PREP Code");

        // Set status text
        if Rec."3PL PREP Code" = '' then
            DimensionStatus := 'No Prep Code'
        else if CurrentDimValue = Rec."3PL PREP Code" then
            DimensionStatus := 'Match'
        else if CurrentDimValue = '' then
            DimensionStatus := 'Missing Dimension'
        else
            DimensionStatus := 'Mismatch';
    end;

    var
        CurrentDimValue: Code[20];
        NeedsUpdate: Boolean;
        DimensionStatus: Text[20];
}
page 50156 "3PL Test Page"
{
    PageType = Card;
    ApplicationArea = All;

    actions
    {
        area(Processing)
        {
            action(TestSingleOrder)
            {
                ApplicationArea = All;
                Caption = 'Test Single Order';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                    DimensionManagement: Codeunit DimensionManagement;
                    DimensionSetEntry: Record "Dimension Set Entry";
                    NewDimensionSetID: Integer;
                    DimensionCode: Code[20];
                begin
                    // Test with a specific order number
                    if SalesHeader.Get(SalesHeader."Document Type"::Order, 'YOUR-ORDER-NO') then begin
                        DimensionCode := '3PL PREP CODE';

                        Message('Order: %1\\3PL Prep Code: %2\\Dimension Set ID: %3',
                                SalesHeader."No.", SalesHeader."3PL PREP Code", SalesHeader."Dimension Set ID");

                        // Check current dimension
                        DimensionSetEntry.SetRange("Dimension Set ID", SalesHeader."Dimension Set ID");
                        DimensionSetEntry.SetRange("Dimension Code", DimensionCode);
                        if DimensionSetEntry.FindFirst() then
                            Message('Current dimension: %1=%2', DimensionSetEntry."Dimension Code", DimensionSetEntry."Dimension Value Code")
                        else
                            Message('No current dimension found for %1', DimensionCode);

                        // Try to update
                        NewDimensionSetID :=
                            DimensionManagement.EditDimensionSet(
                                SalesHeader."Dimension Set ID",
                                StrSubstNo('%1=%2', DimensionCode, SalesHeader."3PL PREP Code"));

                        Message('New Dimension Set ID: %1', NewDimensionSetID);
                    end;
                end;
            }
        }
    }
}