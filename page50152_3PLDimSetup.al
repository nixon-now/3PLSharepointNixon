page 50152 "3PL Dimension Setup"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = '3PL Dimension Setup';

    layout
    {
        area(Content)
        {
            group(Setup)
            {
                Caption = 'Dimension Setup';
                field(Info; SetupInfo)
                {
                    ApplicationArea = All;
                    Caption = 'Information';
                    MultiLine = true;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateDimensionValues)
            {
                ApplicationArea = All;
                Caption = 'Create Missing 3PL Dimension Values';
                Image = Setup;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    DimensionHelper: Codeunit "3PL Dimension Helper";
                begin
                    DimensionHelper.CreateMissing3PLDimensionValues();
                end;
            }
        }
    }

    var
        SetupInfo: Text;

    trigger OnOpenPage()
    begin
        SetupInfo := 'Use this page to create missing 3PL dimension values. ' +
                     'This will ensure all 3PL PREP Codes exist as valid dimension values. ' +
                     'Run this before using the "Update Sales Order Dims" report.';
    end;
}