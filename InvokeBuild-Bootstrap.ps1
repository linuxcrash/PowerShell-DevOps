$ErrorActionPreference = "Stop"

# Write PS Version Table
$PSVersionTable

$PSRepositoryName = 'ART-Powershell'
$PSRepositorySourceLocation = 'https://chba-artifactory.varian.com/artifactory/api/nuget/ART-Powershell'
$LocalModulesDir = "$PSScriptRoot\_PSModules\"
$InvokeBuildModuleName = "InvokeBuild"
$InvokeBuildModuleVersion = "5.8.0"
$InvokeBuildModulePath = "${LocalModulesDir}${InvokeBuildModuleName}"

# Resolve Module Paths before Importing
$PSModulePaths = @(
    $LocalModulesDir
)
foreach ($path in $PSModulePaths) {
    if (!$Env:PSModulePath.Contains($path)) {
        $Env:PSModulePath = "$Env:PSModulePath$([System.IO.Path]::PathSeparator)$path"
    }
}

if (!(Test-Path $InvokeBuildModulePath)) {

    # Register module repository in local development environment
    if (!(Get-PSRepository | Where-Object { $_.Name -eq $PSRepositoryName })) {
        Register-PSRepository `
            -Name $PSRepositoryName `
            -SourceLocation $PSRepositorySourceLocation `
            -InstallationPolicy Trusted
    }

    New-Item -ItemType Directory -Force -Path $LocalModulesDir | Out-Null

    Save-Module `
        -Name $InvokeBuildModuleName `
        -RequiredVersion $InvokeBuildModuleVersion `
        -Path $LocalModulesDir `
        -Verbose:$VerbosePreference `
        -Repository $PSRepositoryName
}

Import-Module -Name $InvokeBuildModuleName -MinimumVersion $InvokeBuildModuleVersion

try {
    Invoke-Build @args -Result Result
}
finally {
    $Result.Tasks | Sort-Object -Descending Elapsed |
        Format-Table -AutoSize Elapsed, @{
            Name = 'Task'
            Expression = {$_.Name + ' @ ' + $_.InvocationInfo.ScriptName}
        }, @{
            Name = 'Error'
            Expression = { $_.Error -replace "`r",' ' -replace "`n", ' ' -replace '\s+', ' ' }
        }
}