$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here/Resolve-Tool.ps1"


Bootstrap-Tools "$here/.." -config "dev"