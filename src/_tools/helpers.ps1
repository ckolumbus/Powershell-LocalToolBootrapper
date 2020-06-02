$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. $here/Resolve-Tool.ps1

Function Bootstrap-IB {
<#
.SYNOPSIS
    Bootstrap Invoke-Buid base powershell build script

.DESCRIPTION
    provides common boostrap code that can be easily called from the
    main build script

.PARAMETER tasks
    the first positional script parameter containing the build task

.PARAMETER invoke
    the $MyInvocation object from the main script 

.PARAMETER params
    the $PSBoundParameter object from the main script

.PARAMETER toolsdir
    the directory for local nuget/choco package configuration & installation.
    Can be relative to build script or absolute path
    Default: ./_tools

.PARAMETER config
    Configuration selector  (e.g. 'dev' or 'release').
    Controls which nuget & psmodule configs are read.

    If empty: system default values are used (which might not work for 
       restoreing ps modules)

    if set: "nuget.<config>.config" and "psm.<config>.config" are used as 
        config file for nuget restore of the respective package type

    Can also be set via "NUGET_PKG_CONFIG" and "NUGET_PSM_CONFIG" environment variables

.EXAMPLE
    in the main script `Project.build.ps1` the first lines looks like this

    ```
        [CmdletBinding()]
        param(
            [Parameter(Position=0)]
            $Tasks,

            [string]$Version       =  "",  , # example for other build parameters
            [String]$Config = ''
        )

        # load and execute bootstraper code
        . .\_tools\helpers.ps1
        BootStrap-IB $Tasks $MyInvocation $PSBoundParameters -config $Config

        # here starts the normal Invoke-Build code
        #
        # Global Variables injected by Restore-Tool: (any ideas to improve this?)
        #    pkgdir   : directory where nuget packages are stored
        #    pkglist  : list of nuget packages with version and restore path
        #    psmdir   : directory where powershell modules are stored
        #    psmlist  : list of powershell modules with version and restore path
        #
        # [...]
    ```

#>
    Param (
        $tasks,
        $invoke,
        $params,
        [string]$toolsdir = "./_tools",  # relative to build script!!
        [string]$config = ""
    ) 

    if ($invoke.ScriptName -notlike '*Invoke-Build.ps1') {

        $ErrorActionPreference = 'Stop'

        Bootstrap-Tools (Split-Path -Parent $invoke.MyCommand.Path) $toolsdir $config
        $ib = [io.Path]::Combine($psmlist.InvokeBuild.path, "Invoke-Build.ps1")

        ## call Invoke-Build after auto-bootstrap
        & $ib -Task $tasks -File $invoke.MyCommand.Path @params
        exit
    }
}
