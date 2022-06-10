param(
    [Parameter(Mandatory=$true)][string]$file
    )
$Cert = Get-PfxCertificate -FilePath "C:\Scripts\Signing\Current.pfx"
$TS = "http://timestamp.comodoca.com"
Set-AuthenticodeSignature -FilePath $file -Certificate $Cert -TimestampServer $TS