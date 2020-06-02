function _ensureDir ($dir)  {
    Write-Verbose -Message "_ensurDir '$dir'"
    if ( -not (Test-Path $dir) )  {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
}
function _normalizePath ($p, $base) {
    Write-Verbose -Message "_normalizePath '$dir' base '$base'"
    # normalize relativ paths
    if (-not [System.IO.Path]::IsPathRooted( $p)) {
        $p = Join-Path $base $p 
    }
    return $p
}

function GetProxyEnabledWebClient
{
    $wc = New-Object System.Net.WebClient
    $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    $proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials        
    $wc.Proxy = $proxy
    return $wc
}

Function Download( $url, $target) {
    Write-Verbose -Message "Download '$url' to '$target'"
    # need to make download target absolut
    if (-not [System.IO.Path]::IsPathRooted( $target)) {
        $target = Join-Path $pwd $target
    } 
    $wc = GetProxyEnabledWebClient
    $wc.DownloadFile($url, $target)

}
function Resolve-Tool($exe, $downloadLink = "", $search = "") 
{
    #$exedir  = Split-Path $exe
    $exename = [io.path]::GetFileName($exe)

    # If not exist at given exe path, try find in path
    if (!(Test-Path $exe)) {
        Write-Verbose -Message "$exe does not exist! Trying to find $exename in PATH..."
        $existingPaths = $Env:Path+";$search" -Split ';' | Where-Object { (![string]::IsNullOrEmpty($_)) -and (Test-Path $_ -PathType Container) }

        $exe_in_path = Get-ChildItem -Path $existingPaths -Filter $exename | Select-Object -First 1
        if ($null -ne $exe_in_path -and (Test-Path $exe_in_path.FullName)) {
            Write-Verbose -Message "Found in PATH at $($exe_in_path.FullName)."
            $exe = $exe_in_path.FullName
        } else {
            Write-Verbose -Message "$exename not found in PATH. "
        }
    }

    # if not found in path, try download  (if link exists)
    if (!(Test-Path $exe) -and ("" -ne $downloadLink )) {
        Write-Verbose -Message "Downloading $exe  from $downloadLink"
        Download $downloadLink $exe
    }

    # check results
    if (!(Test-Path $exe)) 
    {
        throw "$exe not found."
    }

    return $exe
}

Function readPackagesConfig ($pkgconfig_path, $basedir="")
{
    $pkgconfig = @{}
    if ( Test-Path $pkgconfig_path ) {
        ([xml](Get-Content $pkgconfig_path)).SelectNodes("//packages/package") | 
            ForEach-Object { 
                $i = $_.id
                $v = $_.version
                $path = "$i.$v"
                if ("" -ne $basedir) {
                    $path = Join-Path $basedir $path
                }
                $pkgconfig[$_.id] = @{ version=$_.version; path=$path }
            }
    }

    return $pkgconfig
}

Function Bootstrap-Tools {
<#
.SYNOPSIS
    Bootstrap Invoke-Buid base powershell build script

.DESCRIPTION
    provides common boostrap code that can be easily called from the

.PARAMETER basedir
    basedir of calling script, reference for all other directory operations

.PARAMETER toolsdir
    the directory for local nuget/choco package configuration & installation.
    Can be relative to  basedir or absolute path
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
    Call the script

        BootStrap-Tools "." -config "dev"

     Global Variables injected by Restore-Tool: (any ideas to improve this?)
        pkgdir   : directory where nuget packages are stored
        pkglist  : list of nuget packages with version and restore path
        psmdir   : directory where powershell modules are stored
        psmlist  : list of powershell modules with version and restore path
    
#>
    Param (
        $basedir,
        [string]$toolsdir = "./_tools",  # relative to build script!!
        [string]$config = ""
    ) 

    Begin {
        # mandatory build module
        $toolsdir  = _normalizePath $toolsdir $basedir

        # nuget setup
        $NUGET_EXE = Join-Path $toolsdir "nuget.exe"
        $NUGET_URL = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"

        # ---------------------------------------------------------------------------------
        # set nuget/choco package path
        $script:pkgdir  = Join-Path $toolsdir "pkg"
        $pkgconfig      = Join-Path $pkgdir "packages.config"
        $script:pkglist = readPackagesConfig $pkgconfig $pkgdir

        $nugetconf_pkg=""
        # check env varialbe if parameter not given
        if ( "" -ne $config) {
            $nugetconf_pkg = "nuget.$config.config"
        } elseif ( Test-Path variable:global:NUGET_PKG_CONFIG )  {
            $nugetconf_pkg = $NUGET_PKG_CONFIG
        }

        # if nugetconfig is set, set command line argument for nuget executeion
        if ( "" -ne $nugetconf_pkg) {
            $nugetconf_pkg = _normalizePath $nugetconf_pkg $toolsdir
            $nugetconf_pkg_arg =@("-ConfigFile", $nugetconf_pkg )
        } else {
            $nugetconf_pkg_arg = ""
        }

        # ---------------------------------------------------------------------------------
        # set powershell modules path
        $script:psmdir  = Join-Path $toolsdir "psm"
        $psmconfig      = Join-Path $psmdir "packages.config"
        $script:psmlist = readPackagesConfig $psmconfig $psmdir

        $nugetconf_psm = ""
        # check env varialbe if parameter not given
        if ( "" -ne $config) {
            $nugetconf_psm = "psm.$config.config"
        } elseif ( Test-Path variable:global:NUGET_PSM_CONFIG)  {
            $nugetconf_psm = $NUGET_PSM_CONFIG
        }

        # if nugetconfig is set, set command line argument for nuget executeion
        if ( "" -ne $nugetconf_psm) {
            $nugetconf_psm = _normalizePath $nugetconf_psm $toolsdir
            $nugetconf_psm_arg =@("-ConfigFile", $nugetconf_psm )
        } else {
            $nugetconf_psm_arg = ""
        }

        # ---------------------------------------------------------------------------------

        # invoke build script to call after bootstrapping
        $ib = [io.Path]::Combine("$psmdir", $psmlist.InvokeBuild.path, "Invoke-Build.ps1")
    }

    Process {

        $ErrorActionPreference = 'Stop'


        $NUGET_EXE = Resolve-Tool $NUGET_EXE $NUGET_URL
        # Save nuget.exe path to environment to be available to child processed
        $ENV:NUGET_EXE = $NUGET_EXE

#        # install PS Modules via `Save-Module` (see nuget version below)
#        function _installPSModule ($modname, $modver) {
#            $modpath = Join-Path $psmdir $modname
#
#            if (!(Test-Path -LiteralPath (Join-Path $modpath $modver))) {
#                #Write-Output "... $modname $modver"
#                Find-Module -Name $modname -RequiredVersion $modver | Save-Module -Path $psmdir
#            }
#        }
#
#        # install local powershell modules
#        Write-Output 'Checking powershell dependencies ...'
#        foreach ($modname in $psmlist.Keys) {
#            _ensureDir $psmdir
#            $modversion = $($psmlist.Item($modname)).version
#            _installPSModule $modname $modversion
#        }

        # install PS Modules via nuget
        if ( Test-Path $psmconfig ) {

            Write-Output 'Checking psmodules dependencies ...'
            # switch directory use specific nuget.config in $toolsdir
            Push-Location $toolsdir
            & $NUGET_EXE install $psmconfig  @nugetconf_psm_arg `
                    -OutputDirectory $psmdir  `
                    -DirectDownload -NoCache -Verbosity quiet #-ExcludeVersion 
            Pop-Location
            if ($LASTEXITCODE) {throw "nuget install exit code: $LASTEXITCODE"}
        }

        # install normal nuget packages
        if ( Test-Path $pkgconfig ) {

            Write-Output 'Checking nuget dependencies ...'
            # switch directory use specific nuget.config in $toolsdir
            Push-Location $toolsdir
            & $NUGET_EXE install $pkgconfig  @nugetconf_pkg_arg `
                    -OutputDirectory $pkgdir `
                    -DirectDownload -NoCache -Verbosity quiet #-ExcludeVersion 
            Pop-Location
            if ($LASTEXITCODE) {throw "nuget install exit code: $LASTEXITCODE"}
        }
    }
}
