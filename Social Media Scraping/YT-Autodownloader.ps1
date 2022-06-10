#Created by Kolby Graham
#Built for PS7
#Requires -Version 7.0

##### Settings #####
### Paths ###
$DownloadPath = "D:\Hydrus Media\Youtube\Media"; #Download Path - The destination for yt-dlp to use as a cache
$MetadataPath = "D:\Hydrus Media\Youtube\Metadata"; #Metadata Archive Path - Metadata will be moved here after processing
$HistoryFile = "D:\Hydrus Media\Youtube\yt.history"; #The history file
$InputList = "C:\Scripts\YT-ChannelList.txt"; #Newline separated list to be processed by yt-dlp
$LogFile = "C:\Scripts\yt.log"; #Log file
$YTDLPBin = "C:\Apps\Youtube-DL\yt-dlp.exe"; #Location of yt-dlp
$FFMpegBin = "C:\Apps\FFmpeg\ffmpeg.exe"; #Location of ffmpeg

### Options ###
$DoHydrusImport = $true; #Enable importing to Hydrus
$DoYoutubeDL = $false; #Enable youtube downloading
$DeleteSourceFiles = $true #Enable the deletion of the files after successful import into Hydrus
$HydrusAPIKey = "APIKEY"; #Your Hydrus API key
$HydrusURI = "http://127.0.0.1:45869"; #Your Hydrus URI
$DownloadAllMetadata = $true; #Changing this will break the Hydrus import portion of the script
$OutputFileName = "[%(id)s].%(ext)s"; #Changing this will break the Hydrus import portion of the script
### Hydrus Endpoints ###
$HydrusAddEndpoint = "/add_files/add_file"; 
$HydrusAddTagsEndpoint = "/add_tags/add_tags";
$HydrusAddURLEndpoint = "/add_urls/associate_url";

##### Script #####
### Functions ###
function TrimSpecialChars($SourceString)
{
    $pattern = '[^a-zA-Z0-9#? !/:,\.\-_\(\)]'
    $ReturnString = $SourceString -replace $pattern, '' 
    return [String]$ReturnString
}
function ConvertToHex($InputString)
{
    Write-Debug "Hex Conversion Input: $InputString"
    $HexArr = $InputString | Format-Hex
    $HexString = ""
    foreach ($HexItem in $HexArr.HexBytes) { $HexString += $HexItem }
    $ReturnString = $HexString.Replace(" ", "")
    Write-Debug "Hex Conversion Output: $ReturnString"
    return $ReturnString
}
function ValidatePaths()
{
    Write-Debug "Begining path validation"
    if (!(Test-Path -Path $DownloadPath)) { New-Item -ItemType Directory -Path $DownloadPath }
    if (!(Test-Path -Path $MetadataPath)) { New-Item -ItemType Directory -Path $MetadataPath }
    if (!(Test-Path -Path $InputList)) { throw [System.IO.FileNotFoundException] "input list cannot be found at the specified location" }
    if (!(Test-Path -Path $YTDLPBin)) { throw [System.IO.FileNotFoundException] "yt-dlp cannot be found at the specified location" }
    if (!(Test-Path -Path $FFMpegBin)) { throw [System.IO.FileNotFoundException] "FFmpeg cannot be found at the specified location" }
    Write-Debug "Validation Completed"
}
function DownloadYTList()
{
    Write-Debug "Begining YT downloads"
    foreach ($line in Get-Content $InputList)
    {
        Write-Debug "Working on $line"
        $DLURL = $line.Remove($line.IndexOf(' '))
        Write-Debug "Parsed URL to $DLURL"
        #Build arguments
        $DLPArgs = "";
        $DLPArgs += "-P `"$DownloadPath`" -f bestvideo+bestaudio/best -ciw --ffmpeg-location `"$FFMpegBin`" --download-archive `"$HistoryFile`" -o $OutputFileName";
        if ($DownloadAllMetadata)
        {
            $DLPArgs += " --write-info-json --write-playlist-metafiles";
        }
        $DLPArgs += " --parse-metadata `"title:%(meta_title)s`" --parse-metadata `"uploader:%(meta_artist)s`" --add-metadata --write-sub --embed-subs --all-subs --convert-subs=srt --merge-output-format mkv"
        $DLPArgs += " $DLURL"
        Write-Debug "Passing Arg to DLP: $DLPArgs";
        Start-Process -NoNewWindow -FilePath $YTDLPBin -ArgumentList $DLPArgs -Wait
    }
    Write-Debug "YT DL Completed"
}
function HydrusImportAll()
{
    Write-Debug "Beginning Hydrus Import"
    foreach ($item in Get-ChildItem $DownloadPath)
    {
        if ($item.Name.EndsWith(".json")) { Continue };
        if ($item.Name.EndsWith(".part")) { Continue };
        if ($item.Name.EndsWith(".ytdl")) { Continue };
        if ($item.Name.EndsWith(".temp.mkv")) { Continue };
        if ($item.Name.EndsWith(".srt")) { Continue };
        Write-Debug "Working on:"
        Write-Debug $item
        $Response = HydrusImportFile($item)
        Write-Debug $Response
        HydrusAddMetadata -FileHash $Response.hash -file $item
        
    }
    Write-Debug "Hydrus Import Completed"
}

function HydrusAddMetadata()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$FileHash,
        [Parameter(Mandatory)]
        $file
    )
    $Headers = @{
        'Hydrus-Client-API-Access-Key' = $HydrusAPIKey;
    }
    Write-Debug "Getting Tags From JSON"
    $JSONName = $file.Name.Remove($file.Name.LastIndexOf("]") + 1);
    Write-Debug $JSONName;
    $JSONPath = "$DownloadPath\$JSONName.info.json"
    if (!(Test-Path -LiteralPath $JSONPath)) { Write-Warning "File $JSONPath does not exist. Corresponding file will not be tagged."; Continue }
    $JSONData = Get-Content -Raw -LiteralPath $JSONPath | ConvertFrom-Json
    $tagTitle = TrimSpecialChars($JSONData.title)
    Write-Debug "Title: $tagTitle"
    $tagUploader = TrimSpecialChars($JSONData.uploader)
    Write-Debug "Uploader: $tagUploader"
    $tagUploaderID = ConvertToHex($JSONData.uploader_id)
    Write-Debug "Uploader ID: $tagUploaderID"
    $tagChannelID = ConvertToHex($JSONData.channel_id)
    Write-Debug "Channel ID: $tagChannelID"
    $tagChannel = TrimSpecialChars($JSONData.channel)
    Write-Debug "Channel: $tagChannel"
    $tagDescription = TrimSpecialChars($JSONData.description)
    Write-Debug "Description: $tagDescription"
    #$otherTags = TrimSpecialChars($JSONData.tags)
    #Write-Debug $otherTags"
    $tagID = ConvertToHex($JSONData.id)
    Write-Debug "ID: $tagID"
    $fileURL = $JSONData.webpage_url
    Write-Debug "URL: $fileURL"
    Write-Debug $FileHash
    Write-Debug "Tagging File"
    $Body = "{`"hash`" : `"$FileHash`",
`"service_names_to_tags`" : {
    `"my tags`" : [ `"title:$tagTitle`", `"ytuploader:$tagUploader`", `"ytuploaderid:$tagUploaderID`", 
    `"ytchannel:$tagChannel`", `"ytchannelid:$tagChannelID`", `"description:$tagDescription`", `"ytid:$tagID`", `"source:yt`" ]
    }}"
    $Response = Invoke-RestMethod -Uri ($HydrusURI + $HydrusAddTagsEndpoint) -Body $Body -Method Post -Headers $Headers -UseBasicParsing -ContentType "application/json"
    Write-Debug $Response;

    Write-Debug "Adding URL to file"
    $Body = "{`"hash`" : `"$FileHash`",
`"url_to_add`" : `"$fileURL`" }"
    $Response = Invoke-RestMethod -Uri ($HydrusURI + $HydrusAddURLEndpoint) -Body $Body -Method Post -Headers $Headers -UseBasicParsing -ContentType "application/json"
    Write-Debug $Response;
    if ($DeleteSourceFiles)
    {
        Write-Debug "Deleting Original File"
        Remove-Item -LiteralPath $file.FullName
        Write-Debug "Moving JSON"
        Move-Item -LiteralPath $JSONPath -Destination ("$MetadataPath\$JSONName.info.json")
    }
}

function HydrusImportFile($file)
{
    $Headers = @{
        'Hydrus-Client-API-Access-Key' = $HydrusAPIKey;
    }

    Write-Debug "Importing file into Hydrus"
    $FullPath = $file.FullName.Replace("\", "\\")
    $Name = $file.Name
    $Body = "{`"path`" : `"$FullPath`"}"
    $Response = Invoke-RestMethod -Uri ($HydrusURI + $HydrusAddEndpoint) -Body $Body -Method Post -Headers $Headers -UseBasicParsing -ContentType "application/json"
    [string]$ImportStatus = $Response.status
    if ($ImportStatus -eq "1") { Write-Debug "$Name was successfully imported" }
    elseif ($ImportStatus -eq "2") { Write-Debug "$Name was already found in the database and has been skipped" }
    elseif ($ImportStatus -eq "3") { Write-Debug "$Name was previously deleted and has been skipped" }
    elseif ($ImportStatus -eq "4") { Write-Error "$Name failed to import"; throw "Hydrus file failed to import" }
    elseif ($ImportStatus -eq "7") { Write-Debug "$Name was vetoed by a rule and has been skipped" }
    else { throw "Invalid hydrus import code received" }
    return $Response;
}

### Run ###
try
{
    $DebugPreference = 'Continue'
    Start-Transcript -Append $LogFile
    ValidatePaths;
    if ($DoYoutubeDL)
    {
        DownloadYTList;
    }
    if ($DoHydrusImport)
    {
        HydrusImportAll;
    }
}
catch
{
    Write-Error $_
}
finally
{
    Stop-Transcript
}