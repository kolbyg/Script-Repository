#Created by Kolby Graham
#Requires -Version 7.0

### Settings ###
$URI = "https://my-truenas-server.domain.com/api/v2.0"
$token = "truenas api token"
$DebugPreference = 'Continue'
$LogFile = "C:\Scripts\tnds.log"; #Log file
$SQLServerURI = "sqlserver.domain.com"
$SQLServerDB = "TrueNAS-Historical"
$SQLDatasetUsageTableName = "DatasetUsage"


### Endpoints ###
$TNDataset = "/pool/dataset"
function GetDatasetDetails($token){
    $Headers = @{
        'Authorization' = "Bearer $token";
    }
    Write-Debug "Getting data from TrueNAS"
    $Response = Invoke-RestMethod -Uri ($URI + $TNDataset) -Method Get -Headers $Headers -UseBasicParsing -SkipCertificateCheck -ContentType "application/json"
    WriteDetailsToDB($Response);
}
function WriteDetailsToDB($DatasetInfo){
    Write-Debug "Writing data to DB"
    $Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "server='$SQLServerURI';database='$SQLServerDB';trusted_connection=true;"
    $Connection.Open()
    $Command = New-Object System.Data.SQLClient.SQLCommand
    $Command.Connection = $Connection
    foreach($dataset in $DatasetInfo){
        $id = $dataset.id
        Write-Debug "Working on $id"
        $usedspace = $dataset.used.rawvalue
        Write-Debug "Used Space: $usedspace"
        $ts = get-date -Format 'yyyy-MM-dd HH:mm'
        $insertquery="
        INSERT INTO $SQLDatasetUsageTableName
            ([datasetid],[timestamp],[used])
          VALUES
            ('$id','$ts','$usedspace')"
        $Command.CommandText = $insertquery
        $Command.ExecuteNonQuery()
    }
}

try
{
    Start-Transcript -Append $LogFile
    GetDatasetDetails($token);
}
catch
{
    Write-Error $_
}
finally
{
    Stop-Transcript
}
