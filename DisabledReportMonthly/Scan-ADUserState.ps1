
New-Variable -Name ValueSeparator -Option Constant -Value "$#$"
$scriptName = $MyInvocation.MyCommand.Name
$scriptName = $scriptName.Substring(0, $scriptName.IndexOf("."))
New-EventLog -LogName Application -Source $scriptName -ErrorAction SilentlyContinue

##
## FUNÇÃO GetUserState
##
## Retorna o log de alterações de estado de ativação da conta no AD. O log de modificação é
## recuperado a partir do atributo cpflrEmployeeActiveTracking conforme modificado no schema.
##
## PARÂMETROS
##   - user    : usuário do qual o log será recuperado.
##   
## VALOR DE RETORNO
##   Um objeto System.Collections.SortedList com o par (Data de modificação, estado) contendo
##   como entradas as modificações registradas no usuário.
##
function GetUserState([Microsoft.ActiveDirectory.Management.ADUser]$user)
{
    $dateTimeFormat = [System.Globalization.CultureInfo]::InvariantCulture.DateTimeFormat
    $accountStateLog = $user.cpflrEmployeeActiveTracking
    $stateLog = @{} # New-Object System.Collections.SortedList
    foreach ($stateString in $accountStateLog)
    {
        $vars = $stateString.Split($ValueSeparator, [System.StringSplitOptions]::RemoveEmptyEntries)
        $dateChanged = [DateTime]::Parse($vars[0], $dateTimeFormat)
        $newState = ($vars[1] -eq "TRUE")
        $stateLog.Add($dateChanged, $newState)
    }
    return $stateLog
}

##
## FUNÇÃO ShouldUpdateUserState
##
## Retorna se, para um usuário do AD, o seu log de modificação precisa ser atualizado para refletir o
## seu estado atual.
##
## PARÂMETROS
##   - user     : usuário do qual o log será recuperado.
##   - stateLog : log de alterações do usuário especificado no parâmetro 'user'.
##   
## VALOR DE RETORNO
##   True se o log precisa ser modificado, False do contrário.
##
function ShouldUpdateUserState([Microsoft.ActiveDirectory.Management.ADUser]$user, [System.Collections.Hashtable]$stateLog)
{
    $accountState = $user.Enabled

    # Obter última modificação
    if ($stateLog.Count -gt 0)
    {
        $lastModifyDate = $stateLog.Keys | Sort | Select-Object -Last 1
        $lastState = $stateLog[$lastModifyDate]
        return ($user.Enabled -ne $lastState)
    }
    return $true
}

##
## FUNÇÃO UpdateUserState
##
## Atualiza o log de modificações do usuário para que nele seja incluso o registro de seu 
## estado atual de ativação (atributo Enabled).
##
## PARÂMETROS
##   - user     : usuário do qual o log será atualizado.
##   
## VALOR DE RETORNO
##   Nenhum.
##
function UpdateUserState([Microsoft.ActiveDirectory.Management.ADUser]$user)
{
    ..\Common\Update-ADUserState.ps1 -UserName $user.SamAccountName -State $user.Enabled 
}

##
## FUNÇÃO ScanUsers
##
## Atualiza o log de modificações de todos os usuários no AD.
##
## PARÂMETROS
##   Nenhum.
##   
## VALOR DE RETORNO
##   Nenhum.
##
function ScanUsers()
{
    $startTime = [DateTime]::Now
    $changesDetected = 0
    $usersChanged = New-Object System.Collections.Queue
    $users = Get-ADUser -Filter * -Properties Enabled,cpflrEmployeeActiveTracking 
    $totalUsers = $users.Count
    $Error.Clear()
    foreach ($u in $users)
    {
        $userName = $u.SAMAccountName
        $state = GetUserState -user $u
        if ($Error.Count -gt 0)
        {
            Write-EventLog -LogName Application -Source $scriptName -EventId 901 -EntryType Error -Message ("Erro ao tentar obter informações do usuário $userName : " + $Error[0].ToString())
            $Error.Clear()
        }
        if (ShouldUpdateUserState -user $u -stateLog $state)
        {            
            UpdateUserState -user $u
            if ($Error.Count -gt 0)
            {
                Write-EventLog -LogName Application -Source $scriptName -EventId 901 -EntryType Error -Message ("Erro ao tentar atualizar informações do usuário $userName : " + $Error[0].ToString())
                $Error.Clear()
            }
            $changesDetected++
            $usersChanged.Enqueue($userName)
        }
    }
    $endTime = [DateTime]::Now
    $totalSeconds = ($endTime - $startTime).TotalSeconds
    $usersChanged = $usersChanged | Sort
    $msg = "Varredura de estado dos usuários concluída em $totalSeconds segundos. Alterações detectadas desde a última varredura: $changesDetected num universo de $totalUsers usuários.`n`nPrimeiros 10 usuários com estado alterado desde a última varredura:`n"
    $count = 0
    foreach ($u in $usersChanged)
    {
        $msg += $u + "`n"
        $count++
        if ($count -eq 10)
        {
            break
        }
    }
    Write-EventLog -LogName Application -Source $scriptName -EventId 100 -EntryType Information -Message $msg
}

##
## FUNÇÃO Run
##
## Sub-rotina principal do script.
##
## PARÂMETROS
##   Nenhum.
##   
## VALOR DE RETORNO
##   Nenhum.
##
function Run()
{
    $scriptStartTime = [DateTime]::Now    
    # Atualizar o rastreamento de estado para todos os usuários
    ScanUsers
}

Run