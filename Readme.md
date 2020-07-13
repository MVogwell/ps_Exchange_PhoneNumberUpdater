# ps_Exchange_PhoneNumberUpdater.ps1

This script will search the local Active Directory telephoneNumber attribute for phone numbers starting with 0 and replace that digit with +44 (the UK international dial code). 

NOTE: It will only change the phone number if it is longer than 8 characters.

NOTE: To run this script you must be logged on with an account with privileges to change the local domain users and PowerShell must be run with elevated administrative rights.

The script will generate a log file in the %temp% folder which records the users changed, the old phone number, new number and the result as well as any error messages.


## Parameters

### TestWithNoChanges
By using the parameter no changes will be made to Active Directory but the changes that would be made will be logged in the log file.

## Examples

### Run and make changes to Active Directory

.\ps_Exchange_PhoneNumberUpdater.ps1

### Run and test only - do not make any changes to Active Directory

.\ps_Exchange_PhoneNumberUpdater.ps1 -TestWithNoChanges