$here = Split-Path -Parent $MyInvocation.MyCommand.Path
#$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$sut = "Resolve-Tool.ps1"

. "$here\..\src\_tools\$sut"

Describe "_normalizePath" {

    It "adds base to non-rooted path" {
       _normalizePath "x" "y" | Should -Be "y\x"
    }

    It "adds path unchaged if  rooted " {
        $path = "c:\temp"
       _normalizePath $path "y" | Should -Be $path
    }
}

Describe "Resolve-Tool" {


    $nuget_url = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
    $testPath = "TestDrive:/test"

    # fake download of nuget.exe 
    Mock Download { 
       $x = "$testPath/nuget.exe"
        Set-Content $x -value "testfile"
    }

    BeforeEach {
        # clean directory
        if (Test-Path $testPath) { Remove-Item -Recurse -Force  $testPath  | Out-Null }
        New-Item -type Directory $testPath
    }

    It "finds given exe if it exists" {
        $exe = "$testPath/nuget.exe"
        Set-Content $exe -value "testfile"
        $result = Resolve-Tool $exe 
        $result | Should -Be $exe
    }

    It "dowloads nuget.exe if it does not exists in local search paths" {
        $orig_path = $env:path
        $env:path = ''
        $exe = "$testPath/nuget.exe"
        Test-Path $exe | Should -Be $false
        $result = Resolve-Tool $exe $nuget_url
        Test-Path $result | Should -Be $true
        $result | Should -Be $exe
        $env:path = $orig_path
    }

    It "finds exe in alternative search path" {
        $exe_notexist = "$testPath/nuget.exe"

        $searchPath  = "$testPath/x"
        New-Item  $searchPath -Type Directory
        $exe_in_searchpath = "$searchPath/nuget.exe"
        Set-Content $exe_in_searchpath -value "testfile"

        $result = Resolve-Tool $exe_notexist -search "$searchPath"
        Test-Path $result | Should -Be $true
    }

    It "finds standard cmd.exe in path" {
        $result = Resolve-Tool "cmd.exe"
        Test-Path $result | Should -Be $true
    }

}


Describe "readPackages" {

    Mock Test-Path { return $true  }
    Mock Get-Content {  return @"
<?xml version="1.0" encoding="utf-8"?>
<packages>
    <package id="InvokeBuild" version="5.6.0" />
    <package id="Poshstache" version="0.1.9" />
</packages>
"@}

    It "returns the correct list of packages" {
        $config = readPackagesConfig "dummy" $false
       
        $config.PSBase.Count | Should -Be 2
        $config.ContainsKey("InvokeBuild") | Should -Be $true
        $config.ContainsKey("Poshstache") | Should -Be $true
    }

    It "provides the correct versions" {
        $config = readPackagesConfig "dummy" $false
        $config.InvokeBuild.version | Should -Be "5.6.0"
        $config.Poshstache.version | Should -Be "0.1.9"
    }

    It "fills the paths for version with no base path given" {
        $config = readPackagesConfig "dummy" 
        $config.InvokeBuild.path | Should -Be "InvokeBuild.5.6.0"
        $config.Poshstache.path | Should -Be "Poshstache.0.1.9"
    }
    It "fills the paths for version with base path given" {
        $config = readPackagesConfig "dummy" "c:/temp"
        $config.InvokeBuild.path | Should -Be (Join-Path "c:/temp" "InvokeBuild.5.6.0" )
        $config.Poshstache.path  | Should -Be (Join-Path "c:/temp" "Poshstache.0.1.9" )
    }


}
