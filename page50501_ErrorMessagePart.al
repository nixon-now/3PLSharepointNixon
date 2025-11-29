page 50501 "Error Message Part"
{
    PageType = CardPart;
    ApplicationArea = All;
    Caption = 'Error Details';
    SourceTable = "3PL Archive";
    SourceTableTemporary = true;
    
    layout
    {
        area(Content)
        {
            field(ErrorText; Rec."Error Message")
            {
                ApplicationArea = All;
                Caption = 'Error Message';
                MultiLine = true;
                ToolTip = 'Detailed error message';
                Editable = false;
            }
        }
    }

    procedure SetError(NewErrorText: Text)
    begin
        Rec.Init();
        Rec."Error Message" := NewErrorText;
    end;
}