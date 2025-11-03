tableextension 50412 "SalesHeaderExt3PL Free Freight" extends "Sales Header"
{
    fields
    {
        field(50412; "Free Freight"; Boolean)
        {
           Caption = 'Free Freight';
         DataClassification = CustomerContent;
            Description = 'Indicates whether this Sales Order qualifies for free freight (no shipping line added on import).';
        }
        
        field(50413; "3PL Order Exported"; Boolean)
        {
            Caption = '3PL Order Exported';
            Editable = false;
            DataClassification = CustomerContent;
            Description = 'Indicates if order was successfully exported to 3PL';
        }
    }
}
    

