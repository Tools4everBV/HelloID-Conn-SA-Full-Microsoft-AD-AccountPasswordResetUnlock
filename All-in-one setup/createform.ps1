# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

#HelloID variables
#Note: when running this script inside HelloID; portalUrl and API credentials are provided automatically (generate and save API credentials first in your admin panel!)
$portalUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupNames = @("") #Only unique names are supported. Groups must exist!
$delegatedFormCategories = @("User Management","Active Directory") #Only unique names are supported. Categories will be created if not exists
$script:debugLogging = $false #Default value: $false. If $true, the HelloID resource GUIDs will be shown in the logging
$script:duplicateForm = $false #Default value: $false. If $true, the HelloID resource names will be changed to import a duplicate Form
$script:duplicateFormSuffix = "_tmp" #the suffix will be added to all HelloID resource names to generate a duplicate form with different resource names

#The following HelloID Global variables are used by this form. No existing HelloID global variables will be overriden only new ones are created.
#NOTE: You can also update the HelloID Global variable values afterwards in the HelloID Admin Portal: https://<CUSTOMER>.helloid.com/admin/variablelibrary
$globalHelloIDVariables = [System.Collections.Generic.List[object]]@();

#Global variable #1 >> ADusersSearchOU
$tmpName = @'
ADusersSearchOU
'@ 
$tmpValue = @'
OU=Users,OU=enyoi,DC=enyoi,DC=local;OU=UsersLite,OU=enyoi,DC=enyoi,DC=local
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});


#make sure write-information logging is visual
$InformationPreference = "continue"

# Check for prefilled API Authorization header
if (-not [string]::IsNullOrEmpty($portalApiBasic)) {
    $script:headers = @{"authorization" = $portalApiBasic}
    Write-Information "Using prefilled API credentials"
} else {
    # Create authorization headers with HelloID API key
    $pair = "$apiKey" + ":" + "$apiSecret"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"
    $script:headers = @{"authorization" = $Key}
    Write-Information "Using manual API credentials"
}

# Check for prefilled PortalBaseURL
if (-not [string]::IsNullOrEmpty($portalBaseUrl)) {
    $script:PortalBaseUrl = $portalBaseUrl
    Write-Information "Using prefilled PortalURL: $script:PortalBaseUrl"
} else {
    $script:PortalBaseUrl = $portalUrl
    Write-Information "Using manual PortalURL: $script:PortalBaseUrl"
}

# Define specific endpoint URI
$script:PortalBaseUrl = $script:PortalBaseUrl.trim("/") + "/"  

# Make sure to reveive an empty array using PowerShell Core
function ConvertFrom-Json-WithEmptyArray([string]$jsonString) {
    # Running in PowerShell Core?
    if($IsCoreCLR -eq $true){
        $r = [Object[]]($jsonString | ConvertFrom-Json -NoEnumerate)
        return ,$r  # Force return value to be an array using a comma
    } else {
        $r = [Object[]]($jsonString | ConvertFrom-Json)
        return ,$r  # Force return value to be an array using a comma
    }
}

function Invoke-HelloIDGlobalVariable {
    param(
        [parameter(Mandatory)][String]$Name,
        [parameter(Mandatory)][String][AllowEmptyString()]$Value,
        [parameter(Mandatory)][String]$Secret
    )

    $Name = $Name + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        $uri = ($script:PortalBaseUrl + "api/v1/automation/variables/named/$Name")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false

        if ([string]::IsNullOrEmpty($response.automationVariableGuid)) {
            #Create Variable
            $body = @{
                name     = $Name;
                value    = $Value;
                secret   = $Secret;
                ItemType = 0;
            }    
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl + "api/v1/automation/variable")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $variableGuid = $response.automationVariableGuid

            Write-Information "Variable '$Name' created$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        } else {
            $variableGuid = $response.automationVariableGuid
            Write-Warning "Variable '$Name' already exists$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        }
    } catch {
        Write-Error "Variable '$Name', message: $_"
    }
}

function Invoke-HelloIDAutomationTask {
    param(
        [parameter(Mandatory)][String]$TaskName,
        [parameter(Mandatory)][String]$UseTemplate,
        [parameter(Mandatory)][String]$AutomationContainer,
        [parameter(Mandatory)][String][AllowEmptyString()]$Variables,
        [parameter(Mandatory)][String]$PowershellScript,
        [parameter()][String][AllowEmptyString()]$ObjectGuid,
        [parameter()][String][AllowEmptyString()]$ForceCreateTask,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $TaskName = $TaskName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        $uri = ($script:PortalBaseUrl +"api/v1/automationtasks?search=$TaskName&container=$AutomationContainer")
        $responseRaw = (Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false) 
        $response = $responseRaw | Where-Object -filter {$_.name -eq $TaskName}

        if([string]::IsNullOrEmpty($response.automationTaskGuid) -or $ForceCreateTask -eq $true) {
            #Create Task

            $body = @{
                name                = $TaskName;
                useTemplate         = $UseTemplate;
                powerShellScript    = $PowershellScript;
                automationContainer = $AutomationContainer;
                objectGuid          = $ObjectGuid;
                variables           = (ConvertFrom-Json-WithEmptyArray($Variables));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/automationtasks/powershell")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $taskGuid = $response.automationTaskGuid

            Write-Information "Powershell task '$TaskName' created$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        } else {
            #Get TaskGUID
            $taskGuid = $response.automationTaskGuid
            Write-Warning "Powershell task '$TaskName' already exists$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        }
    } catch {
        Write-Error "Powershell task '$TaskName', message: $_"
    }

    $returnObject.Value = $taskGuid
}

function Invoke-HelloIDDatasource {
    param(
        [parameter(Mandatory)][String]$DatasourceName,
        [parameter(Mandatory)][String]$DatasourceType,
        [parameter(Mandatory)][String][AllowEmptyString()]$DatasourceModel,
        [parameter()][String][AllowEmptyString()]$DatasourceStaticValue,
        [parameter()][String][AllowEmptyString()]$DatasourcePsScript,        
        [parameter()][String][AllowEmptyString()]$DatasourceInput,
        [parameter()][String][AllowEmptyString()]$AutomationTaskGuid,
        [parameter()][String][AllowEmptyString()]$DatasourceRunInCloud,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $DatasourceName = $DatasourceName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    $datasourceTypeName = switch($DatasourceType) { 
        "1" { "Native data source"; break} 
        "2" { "Static data source"; break} 
        "3" { "Task data source"; break} 
        "4" { "Powershell data source"; break}
    }

    try {
        $uri = ($script:PortalBaseUrl +"api/v1/datasource/named/$DatasourceName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
    
        if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
            #Create DataSource
            $body = @{
                name               = $DatasourceName;
                type               = $DatasourceType;
                model              = (ConvertFrom-Json-WithEmptyArray($DatasourceModel));
                automationTaskGUID = $AutomationTaskGuid;
                value              = (ConvertFrom-Json-WithEmptyArray($DatasourceStaticValue));
                script             = $DatasourcePsScript;
                input              = (ConvertFrom-Json-WithEmptyArray($DatasourceInput));
                runInCloud         = $DatasourceRunInCloud;
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/datasource")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            
            $datasourceGuid = $response.dataSourceGUID
            Write-Information "$datasourceTypeName '$DatasourceName' created$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        } else {
            #Get DatasourceGUID
            $datasourceGuid = $response.dataSourceGUID
            Write-Warning "$datasourceTypeName '$DatasourceName' already exists$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        }
    } catch {
        Write-Error "$datasourceTypeName '$DatasourceName', message: $_"
    }

    $returnObject.Value = $datasourceGuid
}

function Invoke-HelloIDDynamicForm {
    param(
        [parameter(Mandatory)][String]$FormName,
        [parameter(Mandatory)][String]$FormSchema,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $FormName = $FormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/forms/$FormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }

        if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true)) {
            #Create Dynamic form
            $body = @{
                Name       = $FormName;
                FormSchema = (ConvertFrom-Json-WithEmptyArray($FormSchema));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/forms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body

            $formGuid = $response.dynamicFormGUID
            Write-Information "Dynamic form '$formName' created$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        } else {
            $formGuid = $response.dynamicFormGUID
            Write-Warning "Dynamic form '$FormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        }
    } catch {
        Write-Error "Dynamic form '$FormName', message: $_"
    }

    $returnObject.Value = $formGuid
}


function Invoke-HelloIDDelegatedForm {
    param(
        [parameter(Mandatory)][String]$DelegatedFormName,
        [parameter(Mandatory)][String]$DynamicFormGuid,
        [parameter()][Array][AllowEmptyString()]$AccessGroups,
        [parameter()][String][AllowEmptyString()]$Categories,
        [parameter(Mandatory)][String]$UseFaIcon,
        [parameter()][String][AllowEmptyString()]$FaIcon,
        [parameter()][String][AllowEmptyString()]$task,
        [parameter(Mandatory)][Ref]$returnObject
    )
    $delegatedFormCreated = $false
    $DelegatedFormName = $DelegatedFormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$DelegatedFormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }

        if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
            #Create DelegatedForm
            $body = @{
                name            = $DelegatedFormName;
                dynamicFormGUID = $DynamicFormGuid;
                isEnabled       = "True";
                useFaIcon       = $UseFaIcon;
                faIcon          = $FaIcon;
                task            = ConvertFrom-Json -inputObject $task;
            }
            if(-not[String]::IsNullOrEmpty($AccessGroups)) { 
                $body += @{
                    accessGroups    = (ConvertFrom-Json-WithEmptyArray($AccessGroups));
                }
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body

            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Information "Delegated form '$DelegatedFormName' created$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
            $delegatedFormCreated = $true

            $bodyCategories = $Categories
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormGuid/categories")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $bodyCategories
            Write-Information "Delegated form '$DelegatedFormName' updated with categories"
        } else {
            #Get delegatedFormGUID
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Warning "Delegated form '$DelegatedFormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
        }
    } catch {
        Write-Error "Delegated form '$DelegatedFormName', message: $_"
    }

    $returnObject.value.guid = $delegatedFormGuid
    $returnObject.value.created = $delegatedFormCreated
}

<# Begin: HelloID Global Variables #>
foreach ($item in $globalHelloIDVariables) {
	Invoke-HelloIDGlobalVariable -Name $item.name -Value $item.value -Secret $item.secret 
}
<# End: HelloID Global Variables #>


<# Begin: HelloID Data sources #>
<# Begin: DataSource "ad-account-reset-password-unlock | Generate-Random-Password" #>
$tmpPsScript = @'
function New-GeneratedPassword {
    <#
    .SYNOPSIS
        This will generate a simple random password like "f6Tk9aqatc$x" and optionally include numbers and/or special characters
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $MinimumLength = 12,
    
        [Parameter(Mandatory = $false)]
        $MaximumLength = 16,
    
        [Parameter(Mandatory = $false)]
        $MinimumUpperCaseLetters = 1,
    
        [Parameter(Mandatory = $false)]
        $MaximumUpperCaseLetters = 2,
    
        [Parameter(Mandatory = $false)]
        $MinimumDigits = 2,
    
        [Parameter(Mandatory = $false)]
        $MaximumDigits = 3,
                    
        [Parameter(Mandatory = $false)]
        $MinimumSpecialChars = 1,
    
        [Parameter(Mandatory = $false)]
        $MaximumSpecialChars = 2,
            
        [Parameter(Mandatory = $false)]
        $AllowedLowerCaseLetters = 'abcdefghjkmnpqrstuvwxyz',
    
        [Parameter(Mandatory = $false)]
        $AllowedUpperCaseLetters = 'ABCDEFGHJKMNPQRSTUVWXYZ',
            
        [Parameter(Mandatory = $false)]
        $AllowedDigits = '23456789',
    
        [Parameter(Mandatory = $false)]
        $AllowedSpecialChars = '!#$@*?'
    )
    $lowerCaseLetters = $null
    $upperCaseLetters = $null
    $digits = $null
    $specialChars = $null
    
    # Total length of random password
    if ($MinimumLength -ne $MaximumLength) {
        $totalLength = Get-Random -Minimum $MinimumLength -Maximum $MaximumLength
    }
    else {
        $totalLength = $MaximumLength
    }
    
    <#--------- Upper case letters ---------#>
    # Total length of allowed upper case letters
    if ($MinimumUpperCaseLetters -and $MaximumUpperCaseLetters) {
        $amountOfUpperCaseLetters = Get-Random -Minimum $MinimumUpperCaseLetters -Maximum $MaximumUpperCaseLetters
    }
    elseif ($MinimumUpperCaseLetters -and !$MaximumUpperCaseLetters) {
        $amountOfUpperCaseLetters = Get-Random -Minimum $MinimumUpperCaseLetters -maximum ($MinimumUpperCaseLetters + 1)
    }
    elseif (!$MinimumUpperCaseLetters -and $MaximumUpperCaseLetters) {
        $amountOfUpperCaseLetters = Get-Random -Minimum ($MaximumUpperCaseLetters - 1) -Maximum $MaximumUpperCaseLetters
    }
    else {
        $amountOfUpperCaseLetters = 0
    }
    
    # Get random upper case letters
    if ($amountOfUpperCaseLetters -gt 0) {
        $random = 1..$amountOfUpperCaseLetters | ForEach-Object { Get-Random -Maximum $AllowedUpperCaseLetters.Length }
        $upperCaseLetters = ([String]$AllowedUpperCaseLetters[$random]).replace(" ", "")
    }
    
    <#--------- Digits ---------#>
    # Total length of allowed digits
    if ($MinimumDigits -and $MaximumDigits) {
        $amountOfDigits = Get-Random -Minimum $MinimumDigits -Maximum $MaximumDigits
    }
    elseif ($MinimumDigits -and !$MaximumDigits) {
        $amountOfDigits = Get-Random -Minimum $MinimumDigits -maximum ($MinimumDigits + 1)
    }
    elseif (!$MinimumDigits -and $MaximumDigits) {
        $amountOfDigits = Get-Random -Minimum ($MaximumDigits - 1) -Maximum $MaximumDigits
    }
    else {
        $amountOfDigits = 0
    }
    
    # Get random digits
    if ($amountOfDigits -gt 0) {
        $random = 1..$amountOfDigits | ForEach-Object { Get-Random -Maximum $AllowedDigits.Length }
        $digits = ([String]$AllowedDigits[$random]).replace(" ", "")
    }
    
    
    <#--------- Special Characters ---------#>
    # Total length of allowed special characters
    if ($MinimumSpecialChars -and $MaximumSpecialChars) {
        $amountOfSpecialChars = Get-Random -Minimum $MinimumSpecialChars -Maximum $MaximumSpecialChars
    }
    elseif ($MinimumSpecialChars -and !$MaximumSpecialChars) {
        $amountOfSpecialChars = Get-Random -Minimum $MinimumSpecialChars -maximum ($MinimumSpecialChars + 1)
    }
    elseif (!$MinimumSpecialChars -and $MaximumSpecialChars) {
        $amountOfSpecialChars = Get-Random -Minimum ($MaximumSpecialChars - 1) -Maximum $MaximumSpecialChars
    }
    else {
        $amountOfSpecialChars = 0
    }
    
    # Get random special chars
    if ($amountOfSpecialChars -gt 0) {
        $random = 1..$amountOfSpecialChars | ForEach-Object { Get-Random -Maximum $AllowedSpecialChars.Length }
        $specialChars = ([String]$AllowedSpecialChars[$random]).replace(" ", "")
    }
    
    <#--------- Lower case letters ---------#>
    # Get random lower case letters
    $amountOfLowerCaseLetters = ($totalLength - $amountOfUpperCaseLetters - $amountOfDigits - $amountOfSpecialChars)
    $random = 1..$amountOfLowerCaseLetters | ForEach-Object { Get-Random -Maximum $AllowedLowerCaseLetters.Length }
    $lowerCaseLetters = ([String]$AllowedLowerCaseLetters[$random]).replace(" ", "")
    
    # Join all generated password characters into one string
    $passwordCharacters = ($lowerCaseLetters + $upperCaseLetters + $digits + $specialChars).replace(" ", "")

    # Define the first character
    $startingCharacter = "$($lowerCaseLetters.ToCharArray() | Get-Random -Count 1)"

    # Remove the character already in $randomPassword from $passwordCharacters once
    $passwordCharacters = $passwordCharacters.Remove($passwordCharacters.IndexOf($startingCharacter), 1)

    # Scramble password characters
    $characterArray = $passwordCharacters.ToCharArray() | Get-Random -Count ($passwordCharacters.Length)

    # Generate the password
    # Set the starting character
    $randomPassword = $startingCharacter
    # Set the remain characters
    $scrambledStringArray = $characterArray
    $randomPassword += -join $scrambledStringArray

    # Output the final password
    return $randomPassword 
}
    
try {
    $params = @{
        MinimumLength           = 12
        MaximumLength           = 12
        MinimumUpperCaseLetters = 1
        MaximumUpperCaseLetters = 2
        MinimumDigits           = 2
        MaximumDigits           = 3
        MinimumSpecialChars     = 1
        MaximumSpecialChars     = 2
        AllowedUpperCaseLetters = 'ABCDEFGHJKMNPQRSTUVWXYZ'
        AllowedLowerCaseLetters = 'abcdefghjkmnpqrstuvwxyz'
        AllowedDigits           = '23456789'
        AllowedSpecialChars     = '!#$@*?'
    }
    
    $Password = New-GeneratedPassword @params

    $returnObject = @{
        password = $Password
    }
    Write-output $returnObject
    
    Write-information "Successfully generated random password"
}
catch {
    Write-error "Error generating random password. Error: $($_.Exception.Message)"
}
'@ 
$tmpModel = @'
[{"key":"password","type":0}]
'@ 
$tmpInput = @'
[]
'@ 
$dataSourceGuid_1 = [PSCustomObject]@{} 
$dataSourceGuid_1_Name = @'
ad-account-reset-password-unlock | Generate-Random-Password
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_1_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -DataSourceRunInCloud "False" -returnObject ([Ref]$dataSourceGuid_1) 
<# End: DataSource "ad-account-reset-password-unlock | Generate-Random-Password" #>

<# Begin: DataSource "ad-account-reset-password-unlock | AD-Get-All-Users-Wildcard-Name-DisplayName-UPN-Mail" #>
$tmpPsScript = @'
# Variables configured in form
$searchValue = $dataSource.searchValue
if ($searchValue -eq "*") {
    $filter = "Name -like '*'"
}
else {
    $filter = "Name -like '*$searchValue*' -or DisplayName -like '*$searchValue*' -or userPrincipalName -like '*$searchValue*' -or mail -like '*$searchValue*'"
}

# Global variables
$searchOUs = $AdUsersSearchOu

# Fixed values
$propertiesToSelect = @(
    "ObjectGuid",
    "SamAccountName",
    "DisplayName",
    "UserPrincipalName",
    "Enabled",
    "LockedOut",
    "Description", 
    "Company",
    "Department",
    "Title"
) # Properties to select from Microsoft AD, comma separated

# Set debug logging
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

try {
    #region Searching user
    $actionMessage = "querying AD account(s) matching the filter [$filter] in OU(s) [$($searchOUs)]"

    $ous = $searchOUs -split ';'
    $adUsers = [System.Collections.ArrayList]@()
    foreach ($ou in $ous) {
        $actionMessage = "querying AD account(s) matching the filter [$filter] in OU [$($ou)]"
        $getAdUsersSplatParams = @{
            Filter      = $filter
            Searchbase  = $ou
            Properties  = $propertiesToSelect
            Verbose     = $False
            ErrorAction = "Stop"
        }
        $getAdUsersResponse = Get-AdUser @getAdUsersSplatParams | Select-Object -Property $propertiesToSelect

        if ($getAdUsersResponse -is [array]) {
            [void]$adUsers.AddRange($getAdUsersResponse)
        }
        else {
            [void]$adUsers.Add($getAdUsersResponse)
        }
    }
    Write-Information "Queried AD account(s) matching the filter [$filter] in OU(s) [$($searchOUs)]. Result count: $(($adUsers | Measure-Object).Count)"

    # Sort and Send results to HelloID
    $actionMessage = "sending results to HelloID"
    $adUsers | ForEach-Object {
        Write-Output $_
    } 
}
catch {
    $ex = $PSItem
    Write-Warning "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    Write-Error "Error $($actionMessage). Error: $($ex.Exception.Message)"
    # exit # use when using multiple try/catch and the script must stop
}
'@ 
$tmpModel = @'
[{"key":"ObjectGuid","type":0},{"key":"SamAccountName","type":0},{"key":"DisplayName","type":0},{"key":"UserPrincipalName","type":0},{"key":"Enabled","type":0},{"key":"LockedOut","type":0},{"key":"Description","type":0},{"key":"Company","type":0},{"key":"Department","type":0},{"key":"Title","type":0}]
'@ 
$tmpInput = @'
[{"description":"","translateDescription":false,"inputFieldType":1,"key":"searchValue","type":0,"options":1}]
'@ 
$dataSourceGuid_0 = [PSCustomObject]@{} 
$dataSourceGuid_0_Name = @'
ad-account-reset-password-unlock | AD-Get-All-Users-Wildcard-Name-DisplayName-UPN-Mail
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_0_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -DataSourceRunInCloud "False" -returnObject ([Ref]$dataSourceGuid_0) 
<# End: DataSource "ad-account-reset-password-unlock | AD-Get-All-Users-Wildcard-Name-DisplayName-UPN-Mail" #>
<# End: HelloID Data sources #>

<# Begin: Dynamic Form "AD Account - Reset password & Unlock" #>
$tmpSchema = @"
[{"label":"Select user account","fields":[{"key":"searchValue","templateOptions":{"label":"Search (wildcard search in Name, Display name, UserPrincipalName and Mail)","placeholder":"Name, Display name, UserPrincipalName or Mail (use * to search all users)","required":true,"minLength":1},"type":"input","summaryVisibility":"Hide element","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"gridUsers","templateOptions":{"label":"select user","required":true,"grid":{"columns":[{"headerName":"DisplayName","field":"DisplayName"},{"headerName":"UserPrincipalName","field":"UserPrincipalName"},{"headerName":"Enabled","field":"Enabled"},{"headerName":"LockedOut","field":"LockedOut"},{"headerName":"Department","field":"Department"},{"headerName":"Title","field":"Title"},{"headerName":"Description","field":"Description"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_0","input":{"propertyInputs":[{"propertyName":"searchValue","otherFieldValue":{"otherFieldKey":"searchValue"}}]}},"useFilter":true,"useDefault":false,"allowCsvDownload":true},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":true}]},{"label":"Reset password","fields":[{"key":"blnreset","templateOptions":{"label":"Reset password","useSwitch":true,"checkboxLabel":" "},"type":"boolean","defaultValue":true,"summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"Password","templateOptions":{"label":"New Password","readonly":false,"useDataSource":true,"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_1","input":{"propertyInputs":[]}},"displayField":"password","required":true,"pattern":"^(?=.*[ABCDEFGHJKMNPQRSTUVWXYZ])(?=.*[abcdefghjkmnpqrstuvwxyz])(?=.*[23456789])(?=.*[!#$@*?])[ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!#$@*?]{12,}$"},"validation":{"messages":{"pattern":"Password validation failed.\n\nRequirements:\n- Minimum length: 12 characters.\n- At least one uppercase letter from: ABCDEFGHJKMNPQRSTUVWXYZ (excludes I, L, O).\n- At least one lowercase letter from: abcdefghjkmnpqrstuvwxyz (excludes i, l, o).\n- At least one digit from: 2 3 4 5 6 7 8 9 (excludes 0 and 1).\n- At least one special character from: ! # $ @ * ?"}},"hideExpression":"!model[\"blnreset\"]","type":"input","summaryVisibility":"Hide element","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"blnchangenextlogon","templateOptions":{"label":"Change password at next logon","useSwitch":true,"checkboxLabel":""},"hideExpression":"!model[\"blnreset\"]","type":"boolean","defaultValue":true,"summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"blnunlock","templateOptions":{"label":"Unlock account","useSwitch":true,"checkboxLabel":""},"type":"boolean","defaultValue":true,"summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false}]}]
"@ 

$dynamicFormGuid = [PSCustomObject]@{} 
$dynamicFormName = @'
AD Account - Reset password & Unlock
'@ 
Invoke-HelloIDDynamicForm -FormName $dynamicFormName -FormSchema $tmpSchema  -returnObject ([Ref]$dynamicFormGuid) 
<# END: Dynamic Form #>

<# Begin: Delegated Form Access Groups and Categories #>
$delegatedFormAccessGroupGuids = @()
if(-not[String]::IsNullOrEmpty($delegatedFormAccessGroupNames)){
    foreach($group in $delegatedFormAccessGroupNames) {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/groups/$group")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
            $delegatedFormAccessGroupGuid = $response.groupGuid
            $delegatedFormAccessGroupGuids += $delegatedFormAccessGroupGuid
        
            Write-Information "HelloID (access)group '$group' successfully found$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormAccessGroupGuid })"
        } catch {
            Write-Error "HelloID (access)group '$group', message: $_"
        }
    }
    if($null -ne $delegatedFormAccessGroupGuids){
        $delegatedFormAccessGroupGuids = ($delegatedFormAccessGroupGuids | Select-Object -Unique | ConvertTo-Json -Depth 100 -Compress)
    }
}

$delegatedFormCategoryGuids = @()
foreach($category in $delegatedFormCategories) {
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories/$category")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        $response = $response | Where-Object {$_.name.en -eq $category}
    
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid
    
        Write-Information "HelloID Delegated Form category '$category' successfully found$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    } catch {
        Write-Warning "HelloID Delegated Form category '$category' not found"
        $body = @{
            name = @{"en" = $category};
        }
        $body = ConvertTo-Json -InputObject $body -Depth 100

        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid

        Write-Information "HelloID Delegated Form category '$category' successfully created$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    }
}
$delegatedFormCategoryGuids = (ConvertTo-Json -InputObject $delegatedFormCategoryGuids -Depth 100 -Compress)
<# End: Delegated Form Access Groups and Categories #>

<# Begin: Delegated Form #>
$delegatedFormRef = [PSCustomObject]@{guid = $null; created = $null} 
$delegatedFormName = @'
AD Account - Reset password & Unlock
'@
$tmpTask = @'
{"name":"AD Account - Reset password & Unlock","script":"# variables configured in form\r\n$user = $form.gridUsers\r\n$blnreset = [System.Convert]::ToBoolean($form.blnreset)\r\n$password = $form.password\r\n$blnchangePasswordAtLogon = [System.Convert]::ToBoolean($form.blnchangenextlogon)\r\n$blnunlock = [System.Convert]::ToBoolean($form.blnunlock)\r\n\r\n# Set debug logging\r\n$VerbosePreference = \"SilentlyContinue\"\r\n$InformationPreference = \"Continue\"\r\n$WarningPreference = \"Continue\"\r\n\r\nif ($blnreset -eq $true) {\r\n    try {\r\n        $actionMessage = \"resetting AD account password for user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]\"\r\n\r\n        Set-ADAccountPassword -Identity $user.ObjectGuid -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $password -Force)\r\n\r\n        $Log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = \"Successfully reset password of AD account: [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]\" # required (free format text) \r\n            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n            TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n        }\r\n        #send result back  \r\n        Write-Information -Tags \"Audit\" -MessageData $log\r\n    }\r\n    catch {\r\n        $ex = $PSItem\r\n        $auditMessage = \"Error $($actionMessage). Error: $($ex.Exception.Message)\"\r\n        $warningMessage = \"Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)\"\r\n    \r\n        $Log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = $auditMessage # required (free format text) \r\n            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n            TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n        }\r\n        Write-Information -Tags \"Audit\" -MessageData $log\r\n        Write-Warning $warningMessage   \r\n        Write-Error $auditMessage\r\n        # exit # use when using multiple try/catch and the script must stop\r\n    }\r\n}\r\n\r\nif ($blnchangePasswordAtLogon -eq $true) {\r\n    try {\r\n        $actionMessage = \"setting attribute ChangePasswordAtNextLogon to [$blnchangePasswordAtLogon] for user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]\"\r\n\r\n        Set-ADUser -Identity $user.ObjectGuid -ChangePasswordAtLogon $blnchangePasswordAtLogon\r\n\r\n        $Log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = \"Successfully set attribute ChangePasswordAtNextLogon to [$blnchangePasswordAtLogon] of AD account: [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]\" # required (free format text) \r\n            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n            TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n        }\r\n        #send result back  \r\n        Write-Information -Tags \"Audit\" -MessageData $log\r\n    }\r\n    catch {\r\n        $ex = $PSItem\r\n        $auditMessage = \"Error $($actionMessage). Error: $($ex.Exception.Message)\"\r\n        $warningMessage = \"Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)\"\r\n\r\n        $Log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = $auditMessage # required (free format text) \r\n            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n            TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n        } \r\n        Write-Information -Tags \"Audit\" -MessageData $log\r\n        Write-Warning $warningMessage   \r\n        Write-Error $auditMessage\r\n    }\r\n}\r\n\r\nif ($blnunlock -eq $true) {\r\n    try {\r\n        $actionMessage = \"unlocking AD user [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]\"\r\n\r\n        Unlock-ADAccount -Identity $user.ObjectGuid\r\n\r\n        $Log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = \"Successfully unlocked AD account: [$($user.userPrincipalName)] with objectguid [$($user.ObjectGuid)]\" # required (free format text) \r\n            IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n            TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n        }\r\n        #send result back\r\n        Write-Information -Tags \"Audit\" -MessageData $log\r\n    }\r\n    catch {\r\n        $ex = $PSItem\r\n        $auditMessage = \"Error $($actionMessage). Error: $($ex.Exception.Message)\"\r\n        $warningMessage = \"Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)\"\r\n\r\n        $Log = @{\r\n            Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n            System            = \"ActiveDirectory\" # optional (free format text) \r\n            Message           = $auditMessage # required (free format text) \r\n            IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n            TargetDisplayName = $user.userPrincipalName # optional (free format text) \r\n            TargetIdentifier  = $user.ObjectGuid # optional (free format text) \r\n        }\r\n        Write-Information -Tags \"Audit\" -MessageData $log\r\n        Write-Warning $warningMessage   \r\n        Write-Error $auditMessage\r\n    }\r\n}","runInCloud":false}
'@ 

Invoke-HelloIDDelegatedForm -DelegatedFormName $delegatedFormName -DynamicFormGuid $dynamicFormGuid -AccessGroups $delegatedFormAccessGroupGuids -Categories $delegatedFormCategoryGuids -UseFaIcon "True" -FaIcon "fa fa-key" -task $tmpTask -returnObject ([Ref]$delegatedFormRef) 
<# End: Delegated Form #>

