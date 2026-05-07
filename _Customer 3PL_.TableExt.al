tableextension 50413 "Customer 3PL" extends Customer
{
    fields
    {
        field(50469; "3PL Prep Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = '3PL Prep Code';
            TableRelation = "3PL Prep Code Setup".Code where(Blocked = const(false));
        }
    }
}
