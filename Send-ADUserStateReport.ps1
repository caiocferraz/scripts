Param([switch]$Full, [string]$OverrideRecipient="", [string]$AddCarbonCopy="", [int]$Month=-1, [int]$Year=-1)

New-Variable -Name ValueSeparator -Option Constant -Value "$#$"

# Validar argumentos
if ($Month -ne -1 -and -not ($Month -ge 1 -and $Month -le 12))
{
    Write-Error "Parâmetro Month inválido."
    Exit
}
if (($Year -ne -1 -and $Month -eq -1) -or ($Year -eq -1 -and $Month -ne -1))
{
    Write-Error "Parâmetro Month e Year devem ser ambos especificados ou omiti-los completamente."
    Exit
}


$curDate = [DateTime]::Now
$curMonthName = [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR").DateTimeFormat.GetMonthName($curDate.Month)

$selectedMonthIdx = $Month
$selectedYear = $Year
if ($Month -eq -1)
{   # nenhum mês foi especificado, selecionar mês anterior a data atual
    $selectedMonthIdx = $curDate.Month - 1
    $selectedYear = $curDate.Year
    if ($selectedMonthIdx -eq 0)
    {
        $selectedMonthIdx = 12
        $selectedYear--
    }
}
$lastMonthName = [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR").DateTimeFormat.GetMonthName($selectedMonthIdx)

$MailMsgHeader     = 
<p><span style="color: red">Este é um e-mail automático, favor não responder.</span></p>
<p>Prezados,</p>
<p>Segue abaixo relação dos colaboradores que tiveram sua conta desativada no mês de <b>%MES_ANTERIOR%</b>.</p>


$MailMsgFooter     = Get-Content ".\Mensagem_Rodape.txt"
$MailMsgCss        = Get-Content ".\Mensagem_CSS.txt"
$MailMsgSubject    = "Relatório de usuários desativados: $lastMonthName/$selectedYear"
$MailMsgSender     = "ti.alert@cpflrenovaveis.com.br"
$MailMsgCc         = $AddCarbonCopy
$MailMsgRecipient  = "ti.monitoramento@cpflrenovaveis.com.br, fabio.rodrigues@cpflrenovaveis.com.br"
if ($OverrideRecipient -ne "")
{
    $MailMsgRecipient = $OverrideRecipient
}

$MailServerHost    = "smtp.office365.com"
$MailServerPort    = 587
$MailUseTLS        = $true
$MailUseDefaultCredential  = $false
[String]$MailSmtpUser      = "ti.alert@cpflrenovaveis.com.br"
[SecureString]$MailSmtpPwd = Get-Content "..\SecuStore\ti-alert-smtp.cred" | ConvertTo-SecureString

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
    $stateLog = New-Object System.Collections.SortedList
    foreach ($stateString in $accountStateLog)
    {
        $vars = $stateString.Split($ValueSeparator, [System.StringSplitOptions]::RemoveEmptyEntries)
        $dateChanged = [DateTime]::Parse($vars[0], $dateTimeFormat)
        $newState = ($vars[1] -eq "TRUE")
        $reason = $vars[2]
        $stateLog.Add($dateChanged, @($newState, $reason))
    }
    return $stateLog
}


##
## FUNÇÃO GetCPFLRMemberList
##
## Retorna uma lista de todos os usuários membros, direta ou indiretamente, do grupo principal "Colaboradores CPFL Renováveis".
##
## PARÂMETROS
##   Nenhum.
##   
## VALOR DE RETORNO
##   Uma lista com todos os usuários membros diretos e indiretos.
##
function GetCPFLRMemberList()
{
    $users = Get-ADGroupMember "Colaboradores CPFL Renováveis" -Recursive
    return $users
}

##
## FUNÇÃO TranslateBlockReason
##
## Retorna uma descrição amigável da razão pela qual um usuário foi desabilitado.
##
## PARÂMETROS
##   - reason    : literal que identifica a razão do bloqueio
##   
## VALOR DE RETORNO
##   Descrição amigável da razão pela qual um usuário foi desabilitado.
##
function TranslateBlockReason([string]$reason)
{
    if ($reason -eq "SCRIPT_BLOCK") { return "Bloqueado por ação de script de monitoramento" }
    return "Intervenção manual"
}

##
## FUNÇÃO FindUsersActiveInDate
##
## Retorna uma lista de todos os usuários CPFL-R que foram ativados ou desativados nos últimos n meses.
##
## PARÂMETROS
##   MinDate               : Data mínima em que deve ter ocorrido a mudança de estado do usuário.
##   ActiveInactive (opc.) : Marca com True se deseja exibir os usuários ativados no último mês, False se quiser os inativados.
##   BeforeDate            : Data anterior a qual os eventos deverão ter ocorrido.
##   
## VALOR DE RETORNO
##   Uma lista com todos os usuários atendendo as critérios especificados.
##
function FindUsersActiveInDate([DateTime]$MinDate, [boolean]$AtiveInactive = $false, [DateTime]$BeforeDate)
{
    # Extrair todos os usuários do AD e selecionar somente funcionários CPFL-R
    $cpflrEmployees = GetCPFLRMemberList
    $users = Get-ADUser -Filter * -Properties Enabled,cpflrEmployeeActiveTracking,mail,Department | Where-Object {$cpflrEmployees.SamAccountName -contains $_.SamAccountName}
    $userList = New-Object System.Collections.SortedList

    foreach ($u in $users)
    {
        # Obter log do último estado registrado
        $userStateLog = GetUserState -user $u
        if ($userStateLog.Count -gt 0)
        {
            $lastModifyDate = $userStateLog.Keys | Select-Object -Last 1
            $lastUserState = $userStateLog[$lastModifyDate]
            $userLastActiveState = $lastUserState[0]
            $userLastActiveReason = ""
            if ($lastUserState.Count -gt 1)
            {
                $userLastActiveReason = TranslateBlockReason $lastUserState[1]            
            }
            else
            {
                $userLastActiveReason = TranslateBlockReason ""   
            }
            if (($userLastActiveState -eq $AtiveInactive) -and ($lastModifyDate -ge $MinDate) -and ($lastModifyDate -lt $BeforeDate))
            {     
                $userObj = New-Object -TypeName PSObject
                $userObj | Add-Member -MemberType NoteProperty -Name "Nome completo" -Value $u.Name       
                $userObj | Add-Member -MemberType NoteProperty -Name "Departamento" -Value $u.Department       
                $userObj | Add-Member -MemberType NoteProperty -Name "E-mail" -Value $u.mail       
                $userObj | Add-Member -MemberType NoteProperty -Name "Usuário de rede (UPN)" -Value $u.UserPrincipalName       
                if ($Full)
                {   # Estas propriedades são adicionadas somente quando solicitado relatório completo
                    $userObj | Add-Member -MemberType NoteProperty -Name "Data do evento" -Value $lastModifyDate    
                    $userObj | Add-Member -MemberType NoteProperty -Name "Forma de bloqueio" -Value $userLastActiveReason    
                }                   
                $userList.Add($u.UserPrincipalName, $userObj)
            }
        }
    }

    return $userList
}

##
## FUNÇÃO FindUsersActiveInMonths
##
## Retorna uma lista de todos os usuários CPFL-R que foram ativados ou desativados nos últimos n meses.
##
## PARÂMETROS
##   Months                : Número de meses máximo em que deve ter ocorrido a mudança de estado do usuário.
##   ActiveInactive (opc.) : Marca com True se deseja exibir os usuários ativados no último mês, False se quiser os inativados.
##   
## VALOR DE RETORNO
##   Uma lista com todos os usuários atendendo as critérios especificados.
##
function FindUsersActiveInMonths([int]$Months, [boolean]$AtiveInactive = $false)
{
    $dateLimit = $curDate
    $dateLimit = $dateLimit.AddHours(-$dateLimit.Hour).AddMinutes(-$dateLimit.Minute).AddSeconds(-$dateLimit.Second).AddMilliseconds(-$dateLimit.Millisecond)
    $dateLimit = $dateLimit.AddMonths(-$Months)

    return FindUsersActiveInDate -MinDate $dateLimit -BeforeDate $curDate -AtiveInactive $AtiveInactive   
}

##
## FUNÇÃO FindUsersActiveInDays
##
## Retorna uma lista de todos os usuários CPFL-R que foram ativados ou desativados nos últimos n dias.
##
## PARÂMETROS
##   Days                  : Número de dias máximo em que deve ter ocorrido a mudança de estado do usuário.
##   ActiveInactive (opc.) : Marca com True se deseja exibir os usuários ativados no último mês, False se quiser os inativados.
##   
## VALOR DE RETORNO
##   Uma lista com todos os usuários atendendo as critérios especificados.
##
function FindUsersActiveInDays([int]$Days, [boolean]$AtiveInactive = $false)
{
   
    $dateLimit = $curDate
    $dateLimit = $dateLimit.AddHours(-$dateLimit.Hour).AddMinutes(-$dateLimit.Minute).AddSeconds(-$dateLimit.Second).AddMilliseconds(-$dateLimit.Millisecond)
    $dateLimit = $dateLimit.AddDays(-$Days)

    return FindUsersActiveInDate -MinDate $dateLimit -BeforeDate $curDate -AtiveInactive $AtiveInactive
}


##
## FUNÇÃO FindUsersActiveInSpecificMonth
##
## Retorna uma lista de todos os usuários CPFL-R que foram ativados ou desativados dentro do mês especificado.
##
## PARÂMETROS
##   Month                 : Número do mês que se deseja investigar os eventos.
##   Year                  : Ano em que se deseja investigar os eventos.
##   ActiveInactive (opc.) : Marca com True se deseja exibir os usuários ativados no último mês, False se quiser os inativados.
##   
## VALOR DE RETORNO
##   Uma lista com todos os usuários atendendo as critérios especificados.
##
function FindUsersActiveInSpecificMonth([int]$Month, [int]$Year, [boolean]$AtiveInactive = $false)
{
    $dateStart = New-Object System.DateTime -ArgumentList $Year,$Month,1
    $dateLimit = $dateStart.AddMonths(1)
    return FindUsersActiveInDate -MinDate $dateStart -BeforeDate $dateLimit -AtiveInactive $AtiveInactive
}


function SendMail([string]$Sender, [string]$Recipient, [string]$Subject, [string]$Body)
{
    $recs = $Recipient.Split(",")
    foreach ($r in $recs)
    {   # Disparar mensagens individuais para cada um dos destinatários especificados

        # Criar mensagem a ser enviada para o destinatário
        $msg = New-Object System.Net.Mail.MailMessage $Sender, $r.Trim()
        $msg.Subject = $Subject
        $msg.IsBodyHtml = $true
        $msg.Body = $Body
        $msg.Bcc.Add("ti.monitoramento@cpflrenovaveis.com.br")

        # adicionar destinatários em cópia
        $ccList = $AddCarbonCopy.Split(",")
        foreach ($cc in $ccList)
        {
            $msg.CC.Add($cc.Trim())
        }

        # Disparar e-mail
        $smtpClient = New-Object System.Net.Mail.SmtpClient($MailServerHost)
        $smtpClient.Port = $MailServerPort
        $smtpClient.UseDefaultCredentials = $MailUseDefaultCredential
        if (!$MailUseDefaultCredential)
        {
            $smtpCred = New-Object System.Net.NetworkCredential
            $smtpCred.UserName = $MailSmtpUser
            $smtpCred.SecurePassword = $MailSmtpPwd
            $smtpClient.Credentials = $smtpCred
        }
        $smtpClient.EnableSsl = $MailUseTLS
        $smtpClient.Send($msg)
    }
}

function TransformString([string]$TargetString, [HashTable]$Symbols)
{
    # Substituir as variáveis por valores reais
    $transform = $TargetString
    foreach ($sym in $Symbols.Keys) 
    {
        $transform = $transform.Replace("%"+$sym + "%", $Symbols.Get_Item($sym))
    }
    return $transform
}

function InitSymbols($symbols)
{
    $culture = [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR")
    $date = Get-Date
    $todayShortDate = $date.ToShortDateString()
    $todayShortDateTime = $date.ToShortDateString() + " " + $date.ToShortTimeString()
    $todayShortTime = $date.ToShortTimeString()
    $month = $culture.DateTimeFormat.GetMonthName($date.Month)
    $year = $date.Year
    $day = $date.Day
    $week = $culture.DateTimeFormat.GetDayName($date.DayOfWeek)
    $symbols.Set_Item("DATA", $todayShortDate)
    $symbols.Set_Item("HORA", $todayShortDateTime)
    $symbols.Set_Item("DATA_HORA", $todayShortDateTime)
    $symbols.Set_Item("MES", $month)
    $symbols.Set_Item("MES_ANTERIOR", $lastMonthName)
    $symbols.Set_Item("ANO", $year)
    $symbols.Set_Item("DIA", $day)
    $symbols.Set_Item("SEMANA", $weekday)
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
    # Popular lista de símbolos que podem ser usados para preencher campos na mensagem.
    $Error.Clear()
    $culture = [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR")
    $symbols = @{}
    InitSymbols $symbols

    $scriptStartTime = [DateTime]::Now    
    if ($Error.Count -gt 0)
    {
        Write-EventLog -LogName Application -Source "DisabledReportMonthly" -EventId 100 -Message ("Ocorreu um erro na etapa de inicialização do script: " + $Error[0].ErrorDetails)
        $Error.Clear()
    }

    # Validar quais usuários foram desativados neste mês
    # $users = FindUsersActiveInMonths -Months 1 -AtiveInactive $false
    $users = FindUsersActiveInSpecificMonth -Month $selectedMonthIdx -Year $selectedYear -AtiveInactive $false
#    $userData = $users.Values | Select-Object @{Name="Nome completo";Expression={$_.Name}}, 
#                                              @{Name="Departamento";Expression={$_.Department}}, 
#                                              @{Name="E-mail";Expression={$_.mail}}, 
#                                              @{Name="Usuário de rede (UPN)";Expression={$_.UserPrincipalName}}
    $userData = $users.Values
    if ($Error.Count -gt 0)
    {
        Write-EventLog -LogName Application -Source "DisabledReportMonthly" -EventId 100 -Message ("Ocorreu um erro ao obter a lista de usuários: " + $Error[0].ErrorDetails)
        $Error.Clear()
    }
    else
    {
        $numUsers = $users.Count
        Write-EventLog -LogName Application -Source "DisabledReportMonthly" -EventId 100 -Message "Foram levantados $numUsers usuários para este relatório."
    }
    $scriptEndTime = [DateTime]::Now
    $scriptDuration = $scriptEndTime - $scriptStartTime
    $symbols.Set_Item("TOTAL", $users.Values.Count)
    $symbols.Set_Item("SCRIPT_INICIO", $scriptStartTime.ToString($culture))
    $symbols.Set_Item("SCRIPT_FIM", $scriptEndTime.ToString($culture))
    $symbols.Set_Item("SCRIPT_DURACAO", $scriptDuration.ToString())
    
    $msgHeadTransform = TransformString -TargetString $MailMsgHeader -Symbols $symbols
    $msgFootTransform = TransformString -TargetString $MailMsgFooter -Symbols $symbols

    $msgBody = $userData | Sort-Object -Property Name | 
                    ConvertTo-Html -Head $MailMsgCss -PreContent $msgHeadTransform -PostContent $msgFootTransform
    SendMail -Sender $MailMsgSender -Recipient $MailMsgRecipient -Subject $MailMsgSubject -Body $msgBody
    if ($Error.Count -gt 0)
    {
        Write-EventLog -LogName Application -Source "DisabledReportMonthly" -EventId 100 -Message ("Ocorreu um erro ao enviar e-mail para $MailMsgRecipient : " + $Error[0].ErrorDetails)
        $Error.Clear()
    }
    else
    {
        $numUsers = $users.Count
        Write-EventLog -LogName Application -Source "DisabledReportMonthly" -EventId 100 -Message "E-mail enviado para $MailMsgRecipient com sucesso."
    }
}

Run