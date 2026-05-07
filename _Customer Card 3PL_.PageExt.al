pageextension 50497 "Customer Card 3PL" extends "Customer Card"
{
    layout
    {
        addafter("Combine Shipments")
        {
            field("3PL Prep Code"; Rec."3PL Prep Code")
            {
                ApplicationArea = All;
            }
        }
    }
}
