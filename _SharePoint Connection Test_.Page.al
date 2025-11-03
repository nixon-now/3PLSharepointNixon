page 50450 "SharePoint Connection Test"
{
    PageType = Card;
    ApplicationArea = All;
    Caption = '3PL SharePoint Connector Test';

    layout
    {
        area(content)
        {
            group("Test Parameters")
            {
                field("Library ID"; LibraryId)
                {
                    ApplicationArea = All;
                }
                field("Folder Path"; FolderPath)
                {
                    ApplicationArea = All;
                }
                field("File Name"; FileName)
                {
                    ApplicationArea = All;
                }
                field("File Content"; FileContent)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                }
            }
        }
    }
    actions
    {
        area(processing)
        {
            action("Upload File")
            {
                ApplicationArea = All;

                trigger OnAction()
                var
                    SPConnector: Codeunit "SharePoint EFQ";
                    TempBlob: Codeunit "Temp Blob";
                    OutStr: OutStream;
                    InStr: InStream;
                    FullPath: Text;
                    Success: Boolean;
                begin
                    TempBlob.CreateOutStream(OutStr);
                    OutStr.WriteText(FileContent);
                    TempBlob.CreateInStream(InStr);
                    FullPath:=FolderPath + '/' + FileName;
                    Success:=SPConnector.UploadFile(LibraryId, InStr, FullPath);
                    if Success then Message('Upload succeeded: %1', FullPath)
                    else
                        Error('Upload failed for file: %1', FullPath);
                end;
            }
            action("Download File")
            {
                ApplicationArea = All;

                trigger OnAction()
                var
                    SPConnector: Codeunit "SharePoint EFQ";
                    TempBlob: Codeunit "Temp Blob";
                    InStr: InStream;
                    OutStr: OutStream;
                    DownloadedText: Text;
                    FullPath: Text;
                    Success: Boolean;
                begin
                    FullPath:=FolderPath + '/' + FileName;
                    Success:=SPConnector.DownloadFile(LibraryId, FullPath, InStr);
                    if Success then begin
                        // Copy stream into temp blob to read as text
                        TempBlob.CreateOutStream(OutStr);
                        CopyStream(OutStr, InStr);
                        TempBlob.CreateInStream(InStr);
                        InStr.ReadText(DownloadedText);
                        Message('Download succeeded. Content:\n%1', DownloadedText);
                    end
                    else
                        Error('Download failed for file: %1', FullPath);
                end;
            }
        }
    }
    var LibraryId: Text;
    FolderPath: Text;
    FileName: Text;
    FileContent: Text;
}
