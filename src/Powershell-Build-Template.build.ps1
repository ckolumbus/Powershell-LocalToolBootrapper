<#

.Synopsis
    Example for a Build & package script based on Invoke-Build

.Description
    Shows :
    - how to define command line paramaters
    - how to define different tasks (OS dependent)
    - implements auto bootstrap : initializes all needed dependencies on first call

#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    $Tasks,

    [string]$Version       =  "" ,
    [string]$Configuration = "Release",
    [string]$Platform      = "AnyCPU",
    [string]$config         = ""
)

# ------------------------------------------------------
# ---- Bootstrap
# ------------------------------------------------------

# global variables pkgdir, psmdir, pkglist, psmlist
. ./_tools/helpers.ps1
Bootstrap-IB $Tasks $MyInvocation $PSBoundParameters -config $config

# ------------------------------------------------------
# build script starts here
# ------------------------------------------------------

# directory for output artifacts !! will be deleted on clean !!
$publishDir = "dist"
$outDir = "build"


Set-Alias MSBuild (Resolve-MSBuild)

$projSolution = "ProjectSolution.sln" 

# ---- Default Target  ---------------------------

task . Build

# ---- Build -------------------------------------

# Synopsis: Restore nuget packages
task Restore {
    #exec { Nuget restore $projSolution }
}

# Synopsis: Build the project
task Build Restore, {
    #exec { MSBuild $projSolution /t:Build /p:Platform=$Platform /p:Configuration=$Configuration }
}

# Synopsis: Remove build artifacts
task Clean {
    #exec { MSBuild $projSolution /t:Clean /p:Platform=$Platform /p:Configuration=$Configuration }

}

# Synopsis: Execute project tests
task Test Build, {

}

# Synopsis: package & publish package
task Publish  {

}

# if on windows enable special package generation
if ($env:OS -eq "Windows_NT") {

    # Synopsis:  publish windows package
    task PublishWinPkg { 

    }

} # / if Windows_NT
