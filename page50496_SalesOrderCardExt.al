pageextension 50496 SalesOrderCard3PLExt extends "Sales Order"
{
    layout
    {
        addlast(General)
        {
            group(ThreePLInfo)
            {
                Caption = '3PL Integration';

                field("3PL Imported"; Rec."3PL Imported")
                {
                    ApplicationArea = All;
                    Caption = '3PL Imported';
                }
                field("3PL Exported"; Rec."3PL Exported")
                {
                    ApplicationArea = All;
                    Caption = '3PL Exported';
                }
                field("3PL Tracking No."; Rec."3PL Tracking No.")
                {
                    ApplicationArea = All;
                    Caption = '3PL Tracking No.';
                }
                field("3PL Export Date"; Rec."3PL Export Date")
                {
                    ApplicationArea = All;
                    Caption = '3PL Export Date';
                }
                field("3PL Import Date"; Rec."3PL Import Date")
                {
                    ApplicationArea = All;
                    Caption = '3PL Import Date';
                }
                field("Imported Pick Confirmation"; Rec."Imported Pick Confirmation")
                {
                    ApplicationArea = All;
                    Caption = 'Imported Pick Confirmation';
                }
                field("Imported Pick Conf. Date"; Rec."Imported Pick Conf. Date")
                {
                    ApplicationArea = All;
                    Caption = 'Imported Pick Conf. Date';
                }
                field("Imported Shipped Confirmation"; Rec."Imported Shipped Confirmation")
                {
                    ApplicationArea = All;
                    Caption = 'Imported Shipped Confirmation';
                }
                field("Imported Shipped Conf. Date"; Rec."Imported Shipped Conf. Date")
                {
                    ApplicationArea = All;
                    Caption = 'Imported Shipped Conf. Date';
                }
            }
        }
    }
}
