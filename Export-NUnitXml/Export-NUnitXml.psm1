﻿Function Export-NUnitXml {
<#
.SYNOPSIS
    Takes results from PSScriptAnalyzer and exports them as a Pester test results file (NUnitXml format).

.DESCRIPTION
    Takes results from PSScriptAnalyzer and exports them as a Pester test results file (NUnit XML schema).
    Because the generated file in NUnit-compatible, it can be consumed and published by most continuous integration tools.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, Position=0)]
        [AllowNull()]
        [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]]$ScriptAnalyzerResult,

        [Parameter(Mandatory, Position=1)]
        [string]$Path,

        [Parameter()]
        [switch]$failOnInformation,

        [Parameter()]
        [switch]$failOnWarning,

        [Parameter()]
        [switch]$failOnError
    )

    $TotalNumber = If ($ScriptAnalyzerResult) { $ScriptAnalyzerResult.Count -as [string] } Else { '1' }
    $FailedNumber = If ($ScriptAnalyzerResult) { $ScriptAnalyzerResult.Count -as [string] } Else { '0' }
    $Now = Get-Date
    $FormattedDate = Get-Date $Now -Format 'yyyy-MM-dd'
    $FormattedTime = Get-Date $Now -Format 'T'
    $User = $env:USERNAME
    $MachineName = $env:COMPUTERNAME
    $Cwd = $pwd.Path
    $UserDomain = $env:USERDOMAIN
    $OS = Get-CimInstance -ClassName Win32_OperatingSystem
    $Platform = $OS.Caption
    $OSVersion = $OS.Version
    $ClrVersion = 'Unknown'
    $CurrentCulture = (Get-Culture).Name
    $UICulture = (Get-UICulture).Name
    
    # This has been deprecated with PS Core and is only kept for compatbility
    # See https://github.com/PowerShell/PowerShell/issues/1395
    if ($PSVersionTable.CLRVersion) {
        $ClrVersion = $PSVersionTable.CLRVersion.ToString()
    }

    Switch ($ScriptAnalyzerResult) {
        $Null { $TestResult = 'Success'; $TestSuccess = 'True'; Break}
        Default { $TestResult = 'Failure'; $TestSuccess = 'False'}
    }

    $Header = @"
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<test-results xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="nunit_schema_2.5.xsd" name="PSScriptAnalyzer" total="$TotalNumber" errors="0" failures="$FailedNumber" not-run="0" inconclusive="0" ignored="0" skipped="0" invalid="0" date="$FormattedDate" time="$FormattedTime">
  <environment user="$User" machine-name="$MachineName" cwd="$Cwd" user-domain="$UserDomain" platform="$Platform" nunit-version="2.5.8.0" os-version="$OSVersion" clr-version="$ClrVersion" />
  <culture-info current-culture="$CurrentCulture" current-uiculture="$UICulture" />
  <test-suite type="Powershell" name="PSScriptAnalyzer" executed="True" result="$TestResult" success="$TestSuccess" time="0.0" asserts="0">
    <results>
      <test-suite type="TestFixture" name="PSScriptAnalyzer" executed="True" result="$TestResult" success="$TestSuccess" time="0.0" asserts="0" description="PSScriptAnalyzer">
        <results>`n
"@

    $Footer = @"
        </results>
      </test-suite>
    </results>
  </test-suite>
</test-results>
"@

    If ( -not($ScriptAnalyzerResult) ) {

        $TestDescription = 'All PowerShell files pass the specified PSScriptAnalyzer rules'
        $TestName = "PSScriptAnalyzer.{0}" -f $TestDescription

        $Body = @"
          <test-case description="$TestDescription" name="$TestName" time="0.0" asserts="0" success="True" result="Success" executed="True" />`n
"@
    }
    Else { # $ScriptAnalyzerResult is not null
        $Body = [string]::Empty
        Foreach ( $Result in $ScriptAnalyzerResult ) {

            # Setting Line to 0 as PSSA generates output that is not specific to a line.
            if (-not $Result.Line) {
                $reportedLine = 0
            }
            else {
                $reportedLine = $Result.Line
            }

            $TestDescription = "Rule name : $($Result.RuleName)"
            $TestName = "PSScriptAnalyzer.{0} - {1} - Line {2}" -f $TestDescription, $($Result.ScriptName), $reportedLine

            # Need to Escape these otherwise we can end up with an invalid XML if the Stacktrace has non XML friendly chars like &, etc
            $Line = [System.Security.SecurityElement]::Escape($reportedLine)
            $ScriptPath = [System.Security.SecurityElement]::Escape($Result.ScriptPath)
            $Text = [System.Security.SecurityElement]::Escape($Result.Extent.Text)
            $Severity = [System.Security.SecurityElement]::Escape($Result.Severity)

            $successFlag = 'True'
            $resultFlag = 'Success'

            # Set the test case result flags appropriately
            Switch ($Severity) {
                'Information' {
                    if ($failOnInformation) {
                        $successFlag = 'False'
                        $resultFlag = 'Failure'
                    }
                    Break
                }
                'Warning' {
                    if ($failOnWarning) {
                        $successFlag = 'False'
                        $resultFlag = 'Failure'
                    }
                    Break
                }
                'Error' {
                    if ($failOnError) {
                        $successFlag = 'False'
                        $resultFlag = 'Failure'
                    }
                    Break
                }
            }

            $TestCase = @"
          <test-case description="$TestDescription" name="$TestName" time="0.0" asserts="0" success="$successFlag" result="$resultFlag" executed="True">
            <properties>
              <property name="Severity" value="$Severity" />
            </properties>`n
"@
            # Add the failure node only if we failed the test.
            if ($resultFlag -eq 'Failure') {
                $TestCase += @"
            <failure>
              <message>$($Result.Message)</message>
              <stack-trace>at line: $($Line) in $($ScriptPath)
                $($Line): $($Text)
                Rule severity : $($Severity)
              </stack-trace>
            </failure>
"@
            }
            # Add the closing node for the test case element.
            $TestCase += @"
          </test-case>`n
"@

            $Body += $TestCase
        }
    }
    $OutputXml = $Header + $Body + $Footer

    # Checking our output is a well formed XML document
    Try {
        $XmlCheck = [xml]$OutputXml
    }
    Catch {
        Throw "There was an problem when attempting to cast the output to XML : $($_.Exception.Message)"
    }
    $OutputXml | Out-File -FilePath $Path -Encoding utf8 -Force
}
