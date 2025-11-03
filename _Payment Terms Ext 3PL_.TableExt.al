tableextension 50410 "Payment Terms Ext 3PL" extends "Payment Terms"
{
    fields
    {
        field(50410; "COD Payment"; Boolean)
        {
            Caption = 'COD Payment';
            DataClassification = CustomerContent;
            Description = 'Indicates if the payment term is for Cash on Delivery.';
        }
    }
}
