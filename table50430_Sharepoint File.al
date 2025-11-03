table 50403 "SP File"
{
    TableType = Temporary;
    
    fields
    {
        field(1; Name; Text[250])
        {
            Caption = 'Name';
        }
        field(2; "Last Modified DateTime"; DateTime)
        {
            Caption = 'Last Modified';
        }
        field(3; Size; Decimal)
        {
            Caption = 'Size (Bytes)';
        }
        field(4; "Web Url"; Text[2048])
        {
            Caption = 'Web URL';
        }
    }
    
    keys
    {
        key(PK; Name)
        {
            Clustered = true;
        }
    }
}