pageextension 50496 SalesOrderCard3PLExt extends "Sales Order"
{
    layout
    {
        addlast(General)
        {
            group(ThreePLInfo)
            {
                Caption = '3PL Integration';

                field("3PL Skipped"; Rec."3PL Skipped")
                {
                    ApplicationArea = All;
                    Caption = '3PL Skipped';
                    ToolTip = 'Exclude this order from the 3PL integration.';
                }
                field("3PL Prep Code"; Rec."3PL Prep Code")
                {
                    ApplicationArea = All;
                }
                field("3PL Prep Description"; Rec."3PL Prep Description")
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("3PL Exported"; Rec."3PL Exported")
                {
                    ApplicationArea = All;
                    Caption = '3PL Order Exported';
                    Editable = false;
                }
                field("3PL Export Date"; Rec."3PL Export Date")
                {
                    ApplicationArea = All;
                    Caption = '3PL Export Date';
                    Editable = false;
                }
                field("3PL COD Exported"; Rec."3PL COD Exported")
                {
                    ApplicationArea = All;
                    Caption = '3PL COD Exported';
                    Editable = false;
                }

                field("Imported Pick Confirmation"; Rec."Imported Pick Confirmation")
                {
                    ApplicationArea = All;
                    Caption = 'Imported Pick Confirmation';
                    Editable = false;
                }
                field("Imported Pick Conf. Date"; Rec."Imported Pick Conf. Date")
                {
                    ApplicationArea = All;
                    Caption = 'Imported Pick Conf. Date';
                    Editable = false;
                }

                field("Imported Shipped Confirmation"; Rec."Imported Shipped Confirmation")
                {
                    ApplicationArea = All;
                    Caption = 'Imported Shipped Confirmation';
                    Editable = false;
                }
                field("Imported Shipped Conf. Date"; Rec."Imported Shipped Conf. Date")
                {
                    ApplicationArea = All;
                    Caption = 'Imported Shipped Conf. Date';
                    Editable = false;
                }

                field("3PL Tracking No."; Rec."3PL Tracking No.")
                {
                    ApplicationArea = All;
                    Caption = '3PL Tracking No.';
                    Visible = false;
                    ObsoleteState = Pending;
                    ObsoleteReason = 'Use standard "Package Tracking No." instead.';
                    ObsoleteTag = '2026-05';
                }
            }
        }
    }
}
