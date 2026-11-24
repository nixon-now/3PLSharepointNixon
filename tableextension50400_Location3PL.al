tableextension 50400 "Location 3PL" extends Location
{
    fields
    {
        field(50400; "3PL Location"; Boolean)
        {
            DataClassification = CustomerContent;
            Caption = '3PL Location';
            ToolTip = 'Specifies whether this location is managed by the third-party logistics (3PL) provider. Only sales lines from 3PL locations are included in the 3PL XML export.';
        }
    }
}
