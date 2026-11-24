pageextension 50400 "Location Card 3PL" extends "Location Card"
{
    layout
    {
        addlast(General)
        {
            field("3PL Location"; Rec."3PL Location")
            {
                ApplicationArea = All;
            }
        }
    }
}
