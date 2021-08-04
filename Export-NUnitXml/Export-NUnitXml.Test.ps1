###[WIP] ThIS HAS NOT BEEN COMPLETED AT ALL
BeforeDiscovery {
    $here = Split-Path -Parent $PSCommandPath 
    Write-Host "Here Path: $here" -ForegroundColor Magenta

    $LocalModulesDir = "$($PSCommandPath | Split-Path -parent)\_PSModules\"
    Write-Host "PSModules Path: $LocalModulesDir"
    $PSRepositoryName = 'ART-Powershell'

    # Resolve Module Paths before Importing
    $PSModulePaths = @(
        $LocalModulesDir
    )
    foreach ($path in $PSModulePaths) {
        if (!$Env:PSModulePath.Contains($path)) {
            $Env:PSModulePath = "$Env:PSModulePath$([System.IO.Path]::PathSeparator)$path"
        }
    }
    New-Item -ItemType Directory -Force -Path $LocalModulesDir

    $modules = @(
        @{
            Name    = 'Export-NUnitXml'
            Version = '1.0.0'
        }
    )

    foreach ($module in $modules) {
        $modulePath = Join-Path $LocalModulesDir $module.Name
        if (!(Test-Path $modulePath)) {
            $saveModuleParams = @{
                Name            = $module.Name
                RequiredVersion = $module.Version
                Path            = $LocalModulesDir
                Repository      = $PSRepositoryName
            }
            Write-Host $saveModuleParams.Values
            Save-Module @saveModuleParams
        }
        $modulePath
        Import-Module $modulePath
    }

    # Get all Filenames
    [string[]]$moduleFiles = Get-ChildItem -Path $here -Recurse -Filter "*.ps*1" -Exclude @("*.Tests.ps1", "*.psd1") | Select-Object -ExpandProperty FullName
}
Describe "Module Tests" {
    Context 'Module Files' -Foreach $moduleFiles {
        It "<_> exist" {
            "$_" | Should -Exist
        }

        It "<_> is valid PowerShell code" {
            $psFile = Get-Content -Path "$_" -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }
    Context 'Module functions' {
        BeforeAll {
            $module = 'art.mmt'
            $functionNames = Get-ChildItem function: | Where-Object { $_.Source -eq $module }
        }
        It "Functions are available" {
            $functionNames.count | Should -BeGreaterThan 0
        }
    }
    AfterAll {
        $module = 'art.mmt'
        Remove-Module $module -ErrorAction SilentlyContinue
    }
}