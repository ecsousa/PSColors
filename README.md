# PSColors

This PowerShell provides no functions to be used. Isntead it will provide some colloring for PowerShell:

* Foreces background color to black
* Green prompt, without changing the actual foreground color
* If used in a ANSI console (like [ConEmu](https://github.com/Maximus5/ConEmu)), it will also provide coloring for files output

## Installing

If you have [PsGet](http://psget.net/) installed:

    Install-Module PSColor
  
Or you can install it manually coping `PSColor.psm1` to your modules folder (e.g. ` $Env:USERPROFILE\Eduardo_Sousa\Documents\WindowsPowerShell\Modules\PSColor\`)

After installed, you will also need to explicit load this module:

    Import-Module PSColors

It's recommended to put this command to your profile file (`$PROFILE`).
