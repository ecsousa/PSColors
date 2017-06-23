$host.UI.RawUI.ForegroundColor = 'Gray'


if($host.UI.RawUI.BackgroundColor -ne 'Black') {
    $host.UI.RawUI.BackgroundColor = 'Black'
    clear
}

# Function to check wheter current Console support ANSI codes
function Test-Ansi {

    # Powershell ISE don't support ANSI, and this test will print ugly chars there
    if($host.PrivateData.ToString() -eq 'Microsoft.PowerShell.Host.ISE.ISEOptions') {
        return $false;
    }

    # To test is console supports ANSI, we will print an ANSI code
    # and check if cursor postion has changed. If it has, ANSI is not
    # supported
    $oldPos = $host.UI.RawUI.CursorPosition.X

    Write-Host -NoNewline "$([char](27))[0m" -ForegroundColor ($host.UI.RawUI.BackgroundColor);

    $pos = $host.UI.RawUI.CursorPosition.X

    if($pos -eq $oldPos) {
        return $true;
    }
    else {
        # If ANSI is not supported, let's clean up ugly ANSI escapes
        Write-Host -NoNewLine ("`b" * 4)
        return $false
    }
}

$Script:HasAnsi = Test-Ansi

if($Script:HasAnsi) {
    # If ANSI is supported, save current console mode, so we can restore it latter.
    # Some programs, like cygwin's git disables ANSI support in windows Console.
    # This it will bad side effetcts from GIT.

    $sig = '';
    $sig = $sig + '[DllImport("kernel32.dll", SetLastError = true)] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, int dwMode);';
    $sig = $sig + '[DllImport("kernel32.dll", SetLastError = true)] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, ref int nCmdShow);';
    $sig = $sig + '[DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr GetStdHandle(int nStdHandle);';
    Add-Type -MemberDefinition $sig -name PSColorsNativeMethods -namespace Win32;

    $Script:ConsoleHandle = [Win32.PSColorsNativeMethods]::GetStdHandle(-11);
    $Script:ConsoleMode = 0;
    [Win32.PSColorsNativeMethods]::GetConsoleMode($Script:ConsoleHandle, [ref] $Script:ConsoleMode);
}

function Test-Git {
    param([IO.DirectoryInfo] $dir)
    # Function to check wheter directory is in a git repository

    # If have .git dir, it's a git repo
    if(Test-Path (Join-Path $dir.FullName '.git')) {
        return $true;
    }

    # If reached root dir, we are not in a git repository
    if(($dir.Parent -eq $null) -or ($dir -eq $dir.Parent)) {
        return $false;
    }

    # Check parent dir. Let's hope PowerShell supports tail recursion
    return Test-Git ($dir.Parent.FullName)
}

# Overriding PowerShell's default prompt function!
function prompt {
    if($Script:HasAnsi) {
        # Making sure we are restoing original Console Mode in case someone (e.g. GIT) has changed it
        [Win32.PSColorsNativeMethods]::SetConsoleMode($Script:ConsoleHandle, $Script:ConsoleMode) | Out-Null
    }

    if($global:FSFormatDefaultColor) {
        [Console]::ForegroundColor = $global:FSFormatDefaultColor
    }

    $isFS = (Get-Item .).PSProvider.Name -eq 'FileSystem';

    if($isFS) {
        # PowerShell don't change CurrentDirectory when you navigate throught File Sytem
        # which causes problem when executing external programs providing relative paths
        # This will fix the issue, syncing PowerShell current localtion to Windows Environment
        [system.Environment]::CurrentDirectory = (Convert-Path ".");
    }


    #Check if current user has admin privilges so we can use a different color
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    $admin = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    $branch = $null;

    # Legancy functionality to display git branch. Recommend to use posh-git, as it has better info
    # PSColors will not use its own branching displaying if it dectects posh-git is present
    if(-not(Get-Command Write-VcsStatus -ErrorAction SilentlyContinue)) {
        if( $isFS -and (Test-Git (Convert-Path .)) -and (Get-Command git)) {
            $branch = (git branch 2>$null) | %{ ([regex] '\* (.*)').match($_) } | ? { $_.Success } | %{ $_.Groups[1].Value } | Select-Object -First 1
        }
    }

    $drive = (Get-Location).Drive

    if($drive.Root -eq "$($drive.Name):\") {
        $title = $executionContext.SessionState.Path.CurrentLocation

        if($branch) {
            $title = "[$branch] $title";
        }
    }
    else {
        $title = $drive.Name

        if($branch) {
            $title = "$title@$branch";
        }
    }

    $host.UI.RawUI.WindowTitle = $title


    # Choosing color based on admin's privileges
    if($admin) {
        $color = 'Yellow';
    }
    else {
        $color = 'Green';
    }

    Write-Host ([System.Char](10)) -NoNewLine;

    # Print git branch, if posh-git is not present
    if($branch) {
        Write-Host "[" -NoNewLine -ForegroundColor Yellow
        Write-Host "$branch" -NoNewLine -ForegroundColor Cyan
        Write-Host "] " -NoNewLine -ForegroundColor Yellow
    }

    # If we have posh-git, use it
    if(Get-Command Write-VcsStatus -ErrorAction SilentlyContinue) {
        Write-VcsStatus;
    }

    # Write prompt info
    Write-Host $executionContext.SessionState.Path.CurrentLocation -NoNewLine -ForegroundColor $color;
    Write-Host ('>' * ($nestedPromptLevel + 1)) -NoNewLine -ForegroundColor $color;

    # Prevents PowerShell default prompt printing
    if($host.Name -like 'StudioShell*') {
        return " ";
    }
    else {
        return " `b";
    }


}

# Wrapper for Get-ChildItem, that will aid PSColors.format.ps1xml detect if it's outputing to console,
# and hence use ANSI code for coloring different file types

function Get-ChildItem {
<#
.ForwardHelpTargetName Get-ChildItem 
.ForwardHelpCategory Cmdlet
#>
    [CmdletBinding(DefaultParameterSetName='Items', SupportsTransactions=$true, HelpUri='https://go.microsoft.com/fwlink/?LinkID=113308')]
    param(
        [Parameter(ParameterSetName='Items', Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]
        ${Path},

        [Parameter(ParameterSetName='LiteralItems', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('PSPath')]
        [string[]]
        ${LiteralPath},

        [Parameter(Position=1)]
        [string]
        ${Filter},

        [string[]]
        ${Include},

        [string[]]
        ${Exclude},

        [Alias('s')]
        [switch]
        ${Recurse},

        [uint32]
        ${Depth},

        [switch]
        ${Force},

        [System.IO.FileAttributes]
        ${Attributes},

        [switch]
        ${Directory},

        [switch]
        ${File},

        [switch]
        ${Hidden},

        [switch]
        ${ReadOnly},

        [switch]
        ${System},

        [switch]
        ${Name})

    dynamicparam
    {
        try {
            # Set global variable to indicates PSColors.format.ps1xml should output ANSI colors
            $global:PSColorsUseAnsi = $Script:HasAnsi -and ($MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition);

            $targetCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Management\Get-ChildItem', [System.Management.Automation.CommandTypes]::Cmdlet, $PSBoundParameters)
            $dynamicParams = @($targetCmd.Parameters.GetEnumerator() | Microsoft.PowerShell.Core\Where-Object { $_.Value.IsDynamic })
            if ($dynamicParams.Length -gt 0)
            {
                $paramDictionary = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
                foreach ($param in $dynamicParams)
                {
                    $param = $param.Value

                    if(-not $MyInvocation.MyCommand.Parameters.ContainsKey($param.Name))
                    {
                        $dynParam = [Management.Automation.RuntimeDefinedParameter]::new($param.Name, $param.ParameterType, $param.Attributes)
                        $paramDictionary.Add($param.Name, $dynParam)
                    }
                }
                return $paramDictionary
            }
        } catch {
            throw
        }
    }

    begin
    {
        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Management\Get-ChildItem', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }

    process
    {
        try {
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }

    end
    {
        try {
            # Get-ChildItem has ended. PSColors.format.ps1xml will not longer append ANSI codes
            $global:PSColorsUseAnsi = $false;
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
}

if($Script:HasAnsi) {
    # If ANSI is active, use custom PSColors.format.ps1xml for output coloring
    Update-FormatData -Prepend (Join-Path $PSScriptRoot PSColors.format.ps1xml)
}

