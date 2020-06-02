# Synopsis: Execute Tests

task . Clean, Test

task Test {
    Import-Module Pester
    Invoke-Pester "test/Bootstrap-Tooling.Tests.ps1"
}

task Clean {
    Remove-Item "src/_tools/nuget.exe" -ErrorAction SilentlyContinue
    Remove-Item "src/_tools/pkg/*" -Recurse -Exclude packages.config 
    Remove-Item "src/_tools/psm/*" -Recurse -Exclude packages.config 
}