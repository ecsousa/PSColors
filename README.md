# PSColors

This PowerShell provides no functions to be used. Instead it will provide some coloring for PowerShell:

* Forces background color to black
* Green prompt, without changing the actual foreground color
* If used in a ANSI console (like [ConEmu](https://github.com/Maximus5/ConEmu)), it will also provide coloring for files output

## Installing

Windows 10 users:

    Install-Module PSColors -Scope CurrentUser

Otherwise, if you have [PsGet](http://psget.net/) installed:

    Install-Module PSColors
  
Or you can install it manually copying `PSColors.psm1` to your modules folder (e.g. ` $Env:USERPROFILE\Documents\WindowsPowerShell\Modules\PSColors\`)

After installed, you will also need to explicitly load this module:

    Import-Module PSColors

It's recommended that you this command to your profile file (`$PROFILE`) in order for the prompt function to take effect.
