param()

Set-StrictMode -Version Latest
$ProgressPreferenceBackup = $ProgressPreference

$script:version = '1.0.0'
$script:rootDirectory = $null
$script:distDir = Join-Path -Path $PSScriptRoot -ChildPath "\_dist\"

Enter-Build {
    $global:ProgressPreference = 'SilentlyContinue'
    $script:rootDirectory = $PSScriptRoot

    if ([string]::IsNullOrEmpty($script:rootDirectory)) {
        $script:rootDirectory = $PWD
    }

    Write-Build Magenta $script:rootDirectory
}

Exit-Build {
    $global:ProgressPreference = $ProgressPreferenceBackup
}

task Prepare {
    New-Item -ItemType Directory -Force -Path $LocalModulesDir

    $modules = @(
        # @{
        #     Name    = 'RequiredModuleName'
        #     Version = '0.0.1'
        # }
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
    Write-build -Color Magenta "Checking dotnet.exe command..."
    if ((Get-Command "dotnet.exe" -ErrorAction SilentlyContinue) -eq $null) { 
        exec {
            Invoke-WebRequest 'https://dot.net/v1/dotnet-install.ps1' -OutFile 'dotnet-install.ps1';
            Write-build -Color Magenta "Installing dotnet.exe command...Execute Setup Script"
            ./dotnet-install.ps1
            Write-build -Color Magenta "Installing dotnet.exe command...Execute Setup Script done."
        }
    }
}

task PackageExportNUnitXml Prepare, {
    $ModuleCSProjFile = Join-Path $script:rootDirectory -ChildPath "Export-NUnitXml.csproj"

    exec {
        Write-Build Magenta "Packaging $ModuleCSProjFile $script:version to $script:distDir"
        & dotnet pack $ModuleCSProjFile `
            -p:PackageVersion=$script:version `
            --output $script:distDir `
            --verbosity minimal
    }
}

task Clean {
    foreach ($folderName in @($script:distDir)) { remove ${folderName} }
}

task . Prepare, PackageExportNUnitXml