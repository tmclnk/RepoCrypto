#!/usr/bin/env pwsh
<#
.SYNOPSIS
Runs the BFG Repo Cleaner, downloading it from maven central if necessary and verifying its hash.

.DESCRIPTION
The first time this script is run, it will download a copy of the bfg repo cleaner from maven central and check its hash.
If java isn't available on the PATH, an error will be thrown.

.LINK
https://rtyley.github.io/bfg-repo-cleaner/
#> 

$jarfile = "$PSScriptRoot/bfg-1.13.0.jar";
$sha256 = "BF22BAB9DD42D4682B490D6BC366AFDAD6C3DA99F97521032D3BE8BA7526C8CE"

if( Get-Command java -ErrorAction Continue) {
    if( ! (Test-Path "$PSScriptRoot/bfg-1.13.0.jar" -ErrorAction Continue) ){
        Invoke-WebRequest "http://repo1.maven.org/maven2/com/madgag/bfg/1.13.0/bfg-1.13.0.jar" -OutFile "$jarfile"
        if ($sha256 -ne (Get-FileHash "$jarfile" -Algorithm SHA256).Hash){
            Remove-Item $jarfile
            throw "SHA256 Checksum Mismatch on $jarfile"
        }
    }

    & java -jar "$jarfile" @args
} else {
    throw "BFG Repo Cleaner requires java"
}
