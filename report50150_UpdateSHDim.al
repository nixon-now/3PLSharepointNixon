report 50150 "Update Sales Order Dims"
{
    Caption = 'Update 3PL Prep Code on Sales Orders';
    ProcessingOnly = true;
    UsageCategory = Administration;
    ApplicationArea = All;

    dataset
    {
        dataitem(SalesHeader; "Sales Header")
        {
            DataItemTableView =
                sorting("Document Type", "No.")
                where("Document Type" = const(Order),
                      Status = filter(Open | Released));

            RequestFilterFields = "No.", "Sell-to Customer No.", "Location Code", "3PL Prep Code";

            trigger OnAfterGetRecord()
            var
                DimensionManagement: Codeunit DimensionManagement;
                DimensionSetEntry: Record "Dimension Set Entry";
                CurrentDimValue: Code[20];
                DimensionCode: Code[20];
            begin
                if SalesHeader."3PL Prep Code" = '' then
                    exit;

                DimensionCode := '3PL PREP CODE';
                
                // Get current dimension value
                DimensionSetEntry.SetRange("Dimension Set ID", SalesHeader."Dimension Set ID");
                DimensionSetEntry.SetRange("Dimension Code", DimensionCode);
                if DimensionSetEntry.FindFirst() then
                    CurrentDimValue := DimensionSetEntry."Dimension Value Code"
                else
                    CurrentDimValue := '';

                // Only update if different
                if CurrentDimValue <> SalesHeader."3PL Prep Code" then begin
                    SalesHeader."Dimension Set ID" := 
                        DimensionManagement.EditDimensionSet(
                            SalesHeader."Dimension Set ID",
                            StrSubstNo('%1=%2', DimensionCode, SalesHeader."3PL Prep Code"));
                    SalesHeader.Modify();
                    UpdatedRecordsCount += 1;
                end;
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(ShowSummary; ShowSummary)
                    {
                        ApplicationArea = All;
                        Caption = 'Show Summary Message';
                        ToolTip = 'If selected, a summary message will display after the report completes.';
                    }
                }
            }
        }
    }

    trigger OnPostReport()
    begin
        if ShowSummary then
            Message('%1 sales orders have been updated.', UpdatedRecordsCount);
    end;

    var
        UpdatedRecordsCount: Integer;
        ShowSummary: Boolean;
}