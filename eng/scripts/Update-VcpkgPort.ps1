param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $SourceDirectory,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $DestinationDirectory,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $VcpkgPortName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ChangelogLocation,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PackageVersion,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $GitCommitParameters,

    [switch] $PerformFinalCommit = $false 
)

# Load functions for operations on CHANGELOG.md
."$PSScriptRoot/../common/scripts/ChangeLog-Operations.ps1"

# Clean out the folder so that template files removed are not inadvertently 
# re-added
if (Test-Path $DestinationDirectory) {
    Remove-Item -v -r $DestinationDirectory
}

New-Item -Type Directory $DestinationDirectory
Copy-Item `
    -Verbose `
    "$SourceDirectory/*" `
    $DestinationDirectory

# Show artifacts copied into ports folder for PR
Write-Host "Files in destination directory:" 
Get-ChildItem -Recurse $DestinationDirectory | Out-String | Write-Host

$commitMessageFile = New-TemporaryFile
$chagelogEntry = Get-ChangeLogEntryAsString `
    -ChangeLogLocation $ChangelogLocation `
    -VersionString $PackageVersion
"[$VcpkgPortName] Update to $PackageVersion`n$chagelogEntry" | Set-Content $commitMessageFile

Write-Host "Commit Message:"
Write-host (Get-Content $commitMessageFile -Raw)

Write-Host "git status"
git status

# Commit changes
Write-Host "git add -A"
git add -A
Write-Host "git $GitCommitParameters commit --file $commitMessageFile"
"git $GitCommitParameters commit --file $commitMessageFile" | Invoke-Expression -Verbose | Write-Host


Write-Host "./bootstrap-vcpkg.bat"
./bootstrap-vcpkg.bat

if ($LASTEXITCODE -ne 0) { 
    Write-Error "Failed to run bootstrap-vcpkg.bat"
    exit 1
}

Write-Host "./vcpkg.exe x-add-version $VcpkgPortName"
./vcpkg.exe x-add-version $VcpkgPortName

if ($LASTEXITCODE -ne 0) { 
    Write-Error "Failed to run vcpkg x-add-version $VcpkgPortName"
    exit 1
}

Write-Host "git reset HEAD^"
git reset HEAD^

if ($PerformFinalCommit) {
    Write-Host "git $GitCommitParameters commit -m `"Update vcpkg version metadata for $VcpkgPortName`""
    . "git $GitCommitParameters commit  -m `"Update vcpkg version metadata for $VcpkgPortName`""
}