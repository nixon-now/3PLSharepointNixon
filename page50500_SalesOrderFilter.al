page 50500 "3PL Export Orders Filter"
{
    PageType = StandardDialog;
    ApplicationArea = All;
    UsageCategory = Tasks;
    Caption = 'Select Orders to Export';

    layout
    {
        area(Content)
        {
            group(Options)
            {
                Caption = 'Export Options';
                field(LocationFilter; LocationFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Location Code';
                    TableRelation = Location;
                    ToolTip = 'Filter by specific location';
                }
                field(StatusFilter; StatusFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    OptionCaption = 'Open,Released';
                    ToolTip = 'Filter by order status';
                }
                field(DateFilter; DateFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Created After';
                    ToolTip = 'Only orders created after this date';
                }
                field(ExportedFilter; ExportedFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Export Status';
                    OptionCaption = 'All,Not Exported,Exported';
                    ToolTip = 'Filter by export status';
                }
            }
        }
    }

    var
        LocationFilter: Code[10];
        StatusFilter: Option Open,Released;
        DateFilter: Date;
        ExportedFilter: Option All,NotExported,Exported;
         var
        

        procedure GetStatusFilter(): Option Open,Released
        begin
            exit(StatusFilter);
        end;

        procedure GetLocationFilter(): Code[10]
        begin
            exit(LocationFilter);
        end;

        procedure GetDateFilter(): Date
        begin
            exit(DateFilter);
        end;

        procedure GetExportedFilter(): Option All,NotExported,Exported
        begin
            exit(ExportedFilter);
        end;
    }
