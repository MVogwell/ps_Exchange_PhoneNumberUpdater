#######################################
#
# Exchange Phone Number Updater
#
# Changes leading 0 in phone number to +44 (UK international dial code) 
# MVogwell - v1.0 - 13.Jul.2020
#
#######################################

<#

.SYNOPSIS
This script will search the local Active Directory telephoneNumber attribute for phone numbers starting with 0 and replace that digit with +44 (the UK international dial code). It will only do this is the phone number is longer than 8 characters.

NOTE: You must be logged on with an account with privileges to change the local domain users and PowerShell must be run with elevated administrative rights.

The script will generate a log file in the %temp% folder which records the users changed, the old phone number, new number and the result as well as any error messages.

.DESCRIPTION

.PARAMETER TestWithNoChanges
    By using the parameter no changes will be made to Active Directory but the changes that would be made will be logged in the log file.


.EXAMPLE

.\ps_Exchange_PhoneNumberUpdater.ps1

.EXAMPLE

.\ps_Exchange_PhoneNumberUpdater.ps1 -TestWithNoChanges


.NOTES
MVogwell - 13-Jul-2020

.LINK
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$False)][switch]$TestWithNoChanges
)

Function ps_Function_CheckRunningAsAdmin {
    [CmdletBinding()]
    param()

    # Constructor
    [bool]$bRunningAsAdmin = $False
    
    Try {
        # Attempt to check if the current powershell session is being run with admin rights
        # System.Security.Principal.WindowsIdentity -- https://msdn.microsoft.com/en-us/library/system.security.principal.windowsidentity(v=vs.110).aspx
        # Info on Well Known Security Identifiers in Windows: https://support.microsoft.com/en-gb/help/243330/well-known-security-identifiers-in-windows-operating-systems
        
        write-verbose "ps_Function_CheckRunningAsAdmin :: Checking for admin rights"
        $bRunningAsAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
    }
    Catch {
        $bRunningAsAdmin = $False
        write-verbose "ps_Function_CheckRunningAsAdmin :: ERROR Checking for admin rights in current session"
        write-verbose "ps_Function_CheckRunningAsAdmin :: Error: $($Error[0].Exception)"
    }
    Finally {}
    
    write-verbose "ps_Function_CheckRunningAsAdmin :: Result :: $bRunningAsAdmin"
    
    # Return result from function
    return $bRunningAsAdmin
    
}

#@# Main

# Setup varables
$bStartupSuccess = $True
$sTimestamp = get-date -Format "yyyyMMddHHmmss"
$sLogFile = $Env:Temp + "\" + $sTimestamp + "_ps_Exchange_PhoneNumberUpdater.log"

Write-Host "`n`n`n`n`n`n`nActive Directory Phone Number Updater" -ForegroundColor Green
Write-Host "MVogwell - 13-07-20`n" -ForegroundColor Green

# Attempt to import Active Directory module
Try {
    Write-Host "Importing PowerShell ActiveDirectory module: " -ForegroundColor Yellow -NoNewline
    
    Import-Module ActiveDirectory
    
    Write-Host "Success" -ForegroundColor Green
}
Catch {
    $bStartupSuccess = $False

    Write-Host "Failed`n" -ForegroundColor Red

    $sErrMsg = ($Error[0].Exception.Message).Replace("`r", " : ").Replace("`n", "")

    Write-Host "Error: $sErrMsg `n`n" -ForegroundColor Red

    # Endpoint
}


#@# Check running as admin
If ($bStartupSuccess -eq $True) {
    Write-Host "Confirming this is an admin account: " -ForegroundColor Yellow -NoNewline

    $bRunningAsAdmin = ps_Function_CheckRunningAsAdmin

    If ($bRunningAsAdmin -eq $True) {
        Write-Host "Yes" -ForegroundColor Green
    }
    Else {
        $bStartupSuccess = $False

        Write-Host "No - you must run this script with elevated privileges! `n`n" -ForegroundColor Red

        # Endpoint
    }
}

#@# Create the log file

If ($bStartupSuccess -eq $True) {
    Try {
        Write-Host "Creating log file: " -ForegroundColor Yellow -NoNewline

        New-Item $sLogFile -ItemType File | Out-Null

        $sLogTimestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
        $sLogMsg = "ps_Exchange_PhoneNumberUpdater - Log - " + $sLogTimestamp
        Add-Content $sLogFile -Value $sLogMsg

        Add-Content $sLogFile -Value "Name,UPN,OldPhone,NewPhone,Result,Message"

        Write-Host "Success" -ForegroundColor Green

        Write-Host "Log file location: " -ForegroundColor Yellow -NoNewline
        Write-Host "$sLogFile" -ForegroundColor Green
    }
    Catch {
        $bStartupSuccess = $False

        Write-Host "Failed!" -ForegroundColor Red

        $sErrMsg = ($Error[0].Exception.Message).Replace("`r", " : ").Replace("`n", "")

        Write-Host "Error: $sErrMsg `n `n Unable to continue`n`n" -ForegroundColor Red

        # Endpoint
    }
}

# Process user accounts
If ($bStartupSuccess -eq $True) { # only continue if the startup checks were successful
    $objUserAccs = Get-ADUser -Filter "TelephoneNumber -like '0*'" -Properties TelephoneNumber | Select-Object Name, userPrincipalName, TelephoneNumber, objectGUID

    $iUserCount = ($objUserAccs | Measure-Object).Count

    # Check that there are some user accounts to change
    If ($iUserCount -eq 0) {
        $sMsg = "No user accounts have been discovered with a phone number starting 0 - no further action will be taken `n`n"
        Write-Host "`n`n$($sMsg)" -ForegroundColor Cyan

        Add-Content $sLogFile -Value $sMsg

        # Endpoint
    }
    Else {
        Write-Host "User accounts discovered for change: " -ForegroundColor Yellow -NoNewline
        Write-Host "$($iUserCount)`n" -ForegroundColor Green

        Write-Host "Processing user accounts:`n" -ForegroundColor Yellow

        $iCountProcessedMailboxes = 1

        ForEach ($objUser in $objUserAccs) {
            $iPCentComplete = $iCountProcessedMailboxes / $iUserCount * 100
            Write-Progress -Activity "Processing phone number changes" -Status $iPCentComplete -PercentComplete $iPCentComplete
            $iCountProcessedMailboxes ++

            # Setup the required fields
            Try { 
                $sName = $objUser.Name
                $sUPN = $objUser.userPrincipalName
                $sObjectGUID = $objUser.objectGUID
                $sOldPhoneNumber = $objUser.TelephoneNumber
                $sNewPhoneNumber = ""
                $bResult = $True
                $sResult = ""
                $sLogMsg = ""

                Write-Host "$($sName): " -ForegroundColor Yellow -NoNewline

                # Validate the phone number is long enough then construct the new phone number
                If ($sOldPhoneNumber.Length -le 8) {    # Check the phone number is long enough
                    $bResult = $False
                    $sResult = $Failed
                    $sLogMsg = "The phone number is not long enough. It must be 8 characters or longer to be validated for change"

                    Write-Host "Failed" -ForegroundColor Red
                }
                Else {      # Phone number long enough - validate
                    $sNewPhoneNumber = "+44" + $sOldPhoneNumber.Substring(1) # Remove the leading 0 and replace with +44
                    $sNewPhoneNumber = $sNewPhoneNumber.Replace(" ","") # Remove any spaces in the phone number
                }
            }
            Catch {
                $bResult = $False
                $sResult = "Failed"
                $sLogMsg = "Error: " + ($Error[0].Exception.Message).Replace("`r", " : ").Replace("`n", "")

                Write-Host "Failed" -ForegroundColor Red
            }

            # Change the phone number in AD
            If ($bResult -eq $True) {       # Only attempt the change if the validation has completed successfully
                If ($TestWithNoChanges -eq $False) {    # Only attempt the change if the TestWithNoChanges flag has NOT been used
                    Try {
                        Set-ADUser -Identity $sObjectGUID -Replace @{TelephoneNumber=$sNewPhoneNumber}

                        $sResult = "Success"

                        Write-Host "Success" -ForegroundColor Green
                    }
                    Catch {
                        $sResult = "Failed"
                        $sLogMsg = "Error: " + ($Error[0].Exception.Message).Replace("`r", " : ").Replace("`n", "")
                    }
                }
                Else {
                    $sResult = "TestWithNoChanges"
                    $sLogMsg = "TestWithNoChanges enabled - no change made"

                    Write-Host "$sLogMsg" -ForegroundColor Cyan
                }
            }

            # Log result
            $sMsg = $sName + "," + $sUPN + "," + $sOldPhoneNumber + "," + $sNewPhoneNumber + "," + $sResult + "," + $sLogMsg
            Add-Content $sLogFile -Value $sMsg

            # Clear out the variables so they don't accidentally get reused
            $sName = $Null
            $sUPN = $Null
            $sObjectGUID = $Null
            $sOldPhoneNumber  = $Null
            $sNewPhoneNumber = $Null

            [System.GC]::Collect()

        }   # End of: Foreach user

        Write-Host "`n`nFinished processing all accounts`n`n" -ForegroundColor Green

    } # End of: 'Check that there are some user accounts to change' section
}
