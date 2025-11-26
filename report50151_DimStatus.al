report 50155 "3PL Dimension Diagnostic"
{
    Caption = '3PL Dimension Diagnostic';
    ProcessingOnly = false;
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;

    dataset
    {
        dataitem(SalesHeader; "Sales Header")
        {
            DataItemTableView =
                sorting("Document Type", "No.")
                where("Document Type" = const(Order),
                      Status = filter(Open | Released));

            column(Document_No; "No.")
            {
            }
            column(Sell_to_Customer_No; "Sell-to Customer No.")
            {
            }
            column(Status; Status)
            {
            }
            column(Preparation_Code; "3PL PREP Code")
            {
                Caption = '3PL PREP Code';
            }
            column(Dimension_Set_ID; "Dimension Set ID")
            {
            }
            column(Current_Dim_Value; CurrentDimValue)
            {
                Caption = 'Current 3PL PREP CODE Dim';
            }
            column(Needs_Update; NeedsUpdate)
            {
                Caption = 'Needs Update';
            }

            trigger OnAfterGetRecord()
            var
                DimensionSetEntry: Record "Dimension Set Entry";
                DimensionCode: Code[20];
            begin
                DimensionCode := '3PL PREP CODE';

                // Get current dimension value
                DimensionSetEntry.SetRange("Dimension Set ID", "Dimension Set ID");
                DimensionSetEntry.SetRange("Dimension Code", DimensionCode);
                if DimensionSetEntry.FindFirst() then
                    CurrentDimValue := DimensionSetEntry."Dimension Value Code"
                else
                    CurrentDimValue := '';

                // Check if update needed
                NeedsUpdate := ("3PL PREP Code" <> '') and (CurrentDimValue <> "3PL PREP Code");
            end;
        }
    }

    var
        CurrentDimValue: Code[20];
        NeedsUpdate: Boolean;
}