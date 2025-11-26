table 50451 "String List Buffer"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Value"; Text[250])
        {
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        key(PK; "Value")
        {
            Clustered = true;
        }
    }
}
