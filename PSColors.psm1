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

function Out-File { 
    
    [CmdletBinding(DefaultParameterSetName='ByPath', SupportsShouldProcess=$true, ConfirmImpact='Medium', HelpUri='http://go.microsoft.com/fwlink/?LinkID=113363')]
    param(

        [Parameter(ParameterSetName='ByPath', Mandatory=$true, Position=0)]
        [string]
        ${FilePath},

        [Parameter(ParameterSetName='ByLiteralPath', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('PSPath')]
        [string]
        ${LiteralPath},

        [Parameter(Position=1)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('unknown','string','unicode','bigendianunicode','utf8','utf7','utf32','ascii','default','oem')]
        [string]
        ${Encoding},

        [switch]
        ${Append},

        [switch]
        ${Force},

        [Alias('NoOverwrite')]
        [switch]
        ${NoClobber},

        [ValidateRange(2, 2147483647)]
        [int]
        ${Width},

        [Parameter(ValueFromPipeline=$true)]
        [psobject]
        ${InputObject}
    )
    begin
    {
       try {
           
     
           ## Access the REAL Foreach-Object command, so that command
           ## wrappers do not interfere with this script
           $foreachObject = $executionContext.InvokeCommand.GetCmdlet(
               "Microsoft.PowerShell.Core\Foreach-Object")
     
           $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand(
               'Out-File',
               [System.Management.Automation.CommandTypes]::Cmdlet)
     
           ## TargetParameters represents the hashtable of parameters that
           ## we will pass along to the wrapped command
           $targetParameters = @{}
           $PSBoundParameters.GetEnumerator() |
               & $foreachObject {
                   if($command.Parameters.ContainsKey($_.Key))
                   {
                       $targetParameters.Add($_.Key, $_.Value)
                   }
               }
     
           ## finalPipeline represents the pipeline we wil ultimately run
           $newPipeline = { & $wrappedCmd @targetParameters }
           $finalPipeline = $newPipeline.ToString()
     
           
     
           $steppablePipeline = [ScriptBlock]::Create(
               $finalPipeline).GetSteppablePipeline()
           $global:SuppresPSUtilsColoring = $true;
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
           $global:SuppresPSUtilsColoring = $false;
       } catch {
           throw
       }
    }
     
    dynamicparam
    {
       ## Access the REAL Get-Command, Foreach-Object, and Where-Object
       ## commands, so that command wrappers do not interfere with this script
       $getCommand = $executionContext.InvokeCommand.GetCmdlet(
           "Microsoft.PowerShell.Core\Get-Command")
       $foreachObject = $executionContext.InvokeCommand.GetCmdlet(
           "Microsoft.PowerShell.Core\Foreach-Object")
       $whereObject = $executionContext.InvokeCommand.GetCmdlet(
           "Microsoft.PowerShell.Core\Where-Object")
     
       ## Find the parameters of the original command, and remove everything
       ## else from the bound parameter list so we hide parameters the wrapped
       ## command does not recognize.
       $command = & $getCommand Out-File -Type Cmdlet
       $targetParameters = @{}
       $PSBoundParameters.GetEnumerator() |
           & $foreachObject {
               if($command.Parameters.ContainsKey($_.Key))
               {
                   $targetParameters.Add($_.Key, $_.Value)
               }
           }
     
       ## Get the argumment list as it would be passed to the target command
       $argList = @($targetParameters.GetEnumerator() |
           Foreach-Object { "-$($_.Key)"; $_.Value })
     
       ## Get the dynamic parameters of the wrapped command, based on the
       ## arguments to this command
       $command = $null
       try
       {
           $command = & $getCommand Out-File -Type Cmdlet `
               -ArgumentList $argList
       }
       catch
       {
     
       }
     
       $dynamicParams = @($command.Parameters.GetEnumerator() |
           & $whereObject { $_.Value.IsDynamic })
     
       ## For each of the dynamic parameters, add them to the dynamic
       ## parameters that we return.
       if ($dynamicParams.Length -gt 0)
       {
           $paramDictionary = `
               New-Object Management.Automation.RuntimeDefinedParameterDictionary
           foreach ($param in $dynamicParams)
           {
               $param = $param.Value
               $arguments = $param.Name, $param.ParameterType, $param.Attributes
               $newParameter = `
                   New-Object Management.Automation.RuntimeDefinedParameter `
                   $arguments
               $paramDictionary.Add($param.Name, $newParameter)
           }
           return $paramDictionary
       }
    }
     
<#
 
.ForwardHelpTargetName Out-File
.ForwardHelpCategory Cmdlet
 
#>
}

if(Test-Ansi) {
    Update-FormatData -Prepend (Join-Path $PSScriptRoot PSColors.format.ps1xml)
}

