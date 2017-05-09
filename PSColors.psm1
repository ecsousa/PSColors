$host.UI.RawUI.ForegroundColor = 'Gray'


if($host.UI.RawUI.BackgroundColor -ne 'Black') {
    $host.UI.RawUI.BackgroundColor = 'Black'
    clear
}

function Test-Ansi {

    if($host.PrivateData.ToString() -eq 'Microsoft.PowerShell.Host.ISE.ISEOptions') {
        return $false;
    }

    $oldPos = $host.UI.RawUI.CursorPosition.X

    Write-Host -NoNewline "$([char](27))[0m" -ForegroundColor ($host.UI.RawUI.BackgroundColor);

    $pos = $host.UI.RawUI.CursorPosition.X

    if($pos -eq $oldPos) {
        return $true;
    }
    else {
        Write-Host -NoNewLine ("`b" * 4)
        return $false
    }
}

$Script:HasAnsi = Test-Ansi

if($Script:HasAnsi) {
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

    if(Test-Path (Join-Path $dir.FullName '.git')) {
        return $true;
    }

    if(($dir.Parent -eq $null) -or ($dir -eq $dir.Parent)) {
        return $false;
    }

    return Test-Git ($dir.Parent.FullName)
}

function prompt {
    if($Script:HasAnsi) {
        [Win32.PSColorsNativeMethods]::SetConsoleMode($Script:ConsoleHandle, $Script:ConsoleMode) | Out-Null
    }

    if($global:FSFormatDefaultColor) {
        [Console]::ForegroundColor = $global:FSFormatDefaultColor
    }

    $isFS = (gi .).PSProvider.Name -eq 'FileSystem';

    if($isFS) {
        [system.Environment]::CurrentDirectory = (convert-path ".");
    }


    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    $admin = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    $branch = $null;

    if(-not(Get-Command Write-VcsStatus -ErrorAction SilentlyContinue)) {
        if( $isFS -and (Test-Git (cvpa .)) -and (Get-Command git)) {
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


    if($admin) {
        $color = 'Yellow';
    }
    else {
        $color = 'Green';
    }

    Write-Host ([System.Char](10)) -NoNewLine;

    if($branch) {
        Write-Host "[" -NoNewLine -ForegroundColor Yellow
        Write-Host "$branch" -NoNewLine -ForegroundColor Cyan
        Write-Host "] " -NoNewLine -ForegroundColor Yellow
    }

    if(Get-Command Write-VcsStatus -ErrorAction SilentlyContinue) {
        Write-VcsStatus;
    }

    Write-Host $executionContext.SessionState.Path.CurrentLocation -NoNewLine -ForegroundColor $color;
    Write-Host ('>' * ($nestedPromptLevel + 1)) -NoNewLine -ForegroundColor $color;

    if($host.Name -like 'StudioShell*') {
        return " ";
    }
    else {
        return " `b";
    }


}

function Get-ChildItem {
<#
.ForwardHelpTargetName Get-ChildItem 
.ForwardHelpCategory Cmdlet
#>
    [CmdletBinding(DefaultParameterSetName=’Items’, SupportsTransactions=$true)] 
    param( 
        [Parameter(ParameterSetName=’Items’, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)] 
        [System.String[]] 
        ${Path},

        [Parameter(ParameterSetName=’LiteralItems’, Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)] 
        [Alias(‘PSPath’)] 
        [System.String[]] 
        ${LiteralPath},

        [Parameter(Position=1)] 
        [System.String] 
        ${Filter},

        [System.String[]] 
        ${Include},

        [System.String[]] 
        ${Exclude},

        [Switch] 
        ${Recurse},

        [Switch] 
        ${Force},

        [Switch] 
        ${Name})

    begin 
    { 
        try { 
            $global:PSColorsUseAnsi = $Script:HasAnsi -and ($MyInvocation.PipelineLength -eq $MyInvocation.PipelinePosition);
            $outBuffer = $null 
            if ($PSBoundParameters.TryGetValue(‘OutBuffer’, [ref]$outBuffer)) 
            { 
                $PSBoundParameters[‘OutBuffer’] = 1 
            } 
            Write-Host $outBuffer
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand(‘Get-ChildItem’, [System.Management.Automation.CommandTypes]::Cmdlet) 
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
            $steppablePipeline.End() 
        } catch { 
            throw 
        } 
    } 
}

if($Script:HasAnsi) {
    Update-FormatData -Prepend (Join-Path $PSScriptRoot PSColors.format.ps1xml)
}

