# Import the required modules
Import-Module Az.Accounts
Import-Module Az.Functions
Install-Module -Name Az.KeyVault -Force -Scope CurrentUser

# Define the function to send an email
function Send-Email {
    param (
        [string]$subject,
        [string]$version,
        [string]$securePassword
    )

    # Define the email parameters
    $smtpServer = "mail.smtp2go.com"
    $smtpPort = 2525
    $smtpUser = "patching@huntertech.ca"
    $from = "patching@huntertech.ca"
    $to = "matt@huntertech.ca"
    $body = "$subject, latest version is $version"

    # Create the credential object
    $credential = New-Object System.Management.Automation.PSCredential ($smtpUser, $securePassword)

    # Send the email
    Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -Credential $credential -UseSsl
}

# Main function to be triggered by the Azure Function
function Run-Function {
    param($Timer)

    Connect-AzAccount -Identity

    # Retrieve the secure password from Azure Key Vault
    $vaultName = "huntertechvault"
    $secretName = "smtp2go-secure"
    $securePassword = (Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName).SecretValue
    # Load the secure password from Azure Key Vault or a secure location
    #$securePassword = Get-Content -Path "C:\home\site\wwwroot\secure\smtp2go-secure.txt" | ConvertTo-SecureString

    $latest = (Get-AzKeyVaultSecret -VaultName $vaultName -Name "BBversion").SecretValue
    $url = "https://support.bluebeam.com/en-us/release-notes-all.html"

    # Load the HTML content from the URL
    $html = Invoke-RestMethod -Uri $url -Method Get -UseBasicParsing

    $found = $html -match '<p>Revu.+?(?=<)'

    if ($found) {
        $firstLiItem = ([string]$Matches.Values).Replace("<p>Revu ", "")
    }

    if ($latest -ne $firstLiItem) {
        $firstLiItem | Out-File -FilePath "C:\home\site\wwwroot\temp\bluebeam_version.txt" -Force
        Send-Email -subject "Bluebeam Update Released" -version $firstLiItem -securePassword $securePassword
    }
}

# Timer trigger to run the function periodically
$Timer = $null
Run-Function -Timer $Timer