# Powershell LocalToolBoostrapper

This little framework helps to bootstrap tools for local script
execution with as little prerequistes as possible and in a way, that
the global environment is unchanged.

All downloads are based on `nuget.exe`, which is used from a local
installation or can be downloaded if not found.

## Features

### Bootstrapping

* support nuget / chocolatey packages and powershell modules (tested
  with *PSGallery*
* search `nuget.exe` in Path and download a local copy if not found
* package sources are configurable to switch repos e.g. between
  development and release builds
* extra support for bootstrapping `Invoke-Build` build scripts (c.f.
  homepage).

### Tool Resolution

* helps to search for installed tools
* searches existing Path plus provided extended search paths
* allows for automatic download if a direct tool download link is
  provided

## Example

The implemnted example shows how to use this together with
`Invoke-Build`:

1. copy content of the `src` directory to your project root
2. rename `Powershell-Build-Template.build.ps` to `yourproject.build.ps1`
3. implement build steps within the powershell build script ;-) 
