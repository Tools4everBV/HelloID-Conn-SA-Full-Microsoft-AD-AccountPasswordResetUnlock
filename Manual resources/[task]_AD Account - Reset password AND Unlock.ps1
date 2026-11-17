# variables configured in form
$user = $form.gridUsers
$blnreset = if ([string]::IsNullOrWhiteSpace($form.blnreset)) { $false } else { [System.Convert]::ToBoolean($form.blnreset) }
$password = $form.password
$blnchangePasswordAtLogon = if ([string]::IsNullOrWhiteSpace($form.blnchangenextlogon)) { $false } else { [System.Convert]::ToBoolean($form.blnchangenextlogon) }
$blnunlock = if ([string]::IsNullOrWhiteSpace($form.blnunlock)) { $false } else { [System.Convert]::ToBoolean($form.blnunlock) }

# Set debug logging
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

if ($blnreset -eq $true) {
    try {
        $actionMessage = "resetting AD account password for user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]"

        Set-ADAccountPassword -Identity $user.ObjectGuid -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $password -Force)

        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = "Successfully reset password of AD account: [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]" # required (free format text) 
            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        }
        #send result back  
        Write-Information -Tags "Audit" -MessageData $log
    }
    catch {
        $ex = $PSItem
        $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
        $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    
        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = $auditMessage # required (free format text) 
            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        }
        Write-Information -Tags "Audit" -MessageData $log
        Write-Warning $warningMessage   
        Write-Error $auditMessage
        # exit # use when using multiple try/catch and the script must stop
    }
}

if ($blnchangePasswordAtLogon -eq $true) {
    try {
        $actionMessage = "setting attribute ChangePasswordAtNextLogon to [$blnchangePasswordAtLogon] for user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]"

        Set-ADUser -Identity $user.ObjectGuid -ChangePasswordAtLogon $blnchangePasswordAtLogon

        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = "Successfully set attribute ChangePasswordAtNextLogon to [$blnchangePasswordAtLogon] of AD account: [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]" # required (free format text) 
            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        }
        #send result back  
        Write-Information -Tags "Audit" -MessageData $log
    }
    catch {
        $ex = $PSItem
        $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
        $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = $auditMessage # required (free format text) 
            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        } 
        Write-Information -Tags "Audit" -MessageData $log
        Write-Warning $warningMessage   
        Write-Error $auditMessage
    }
}

if ($blnunlock -eq $true) {
    try {
        $actionMessage = "unlocking AD user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]"

        Unlock-ADAccount -Identity $user.ObjectGuid

        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = "Successfully unlocked AD account: [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]" # required (free format text) 
            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        }
        #send result back
        Write-Information -Tags "Audit" -MessageData $log
    }
    catch {
        $ex = $PSItem
        $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
        $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

        $Log = @{
            Action            = "UpdateAccount" # optional. ENUM (undefined = default) 
            System            = "ActiveDirectory" # optional (free format text) 
            Message           = $auditMessage # required (free format text) 
            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) 
            TargetDisplayName = $user.userPrincipalName # optional (free format text) 
            TargetIdentifier  = $user.ObjectGuid # optional (free format text) 
        }
        Write-Information -Tags "Audit" -MessageData $log
        Write-Warning $warningMessage   
        Write-Error $auditMessage
    }
}
