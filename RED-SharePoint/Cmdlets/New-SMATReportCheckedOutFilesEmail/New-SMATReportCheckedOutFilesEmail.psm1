function New-SMATReportCheckedOutFilesEmail
{
    [cmdletbinding()]
    param(
    [parameter(Mandatory=$True, Position=0)]
    [String]$SMTPServer,
    [parameter(Mandatory=$True, Position=1)]
    [String]$SMTPMailSubject,
    [parameter(Mandatory=$True, Position=2)]
    [String]$SMTPToAddress,
    [parameter(Mandatory=$True, Position=3)]
    [String]$SMTPFromAddress,
    [parameter(Mandatory=$True, Position=4)]
    [String]$SMTPReplyToAddress,
    [parameter(Mandatory=$False, Position=5)]
    [String]$SMTPCCAddress,
    [parameter(Mandatory=$True, Position=6)]
    [URI]$SMTPBodyFile,
    [parameter(Mandatory=$True, Position=7)]
    [URI]$AttachmentFile
    )

    $SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer)
    $Email = New-Object Net.Mail.MailMessage
    $Email.From = $SMTPFromAddress
    $Email.ReplyTo = $SMTPReplyToAddress
    $Email.To.Add($SMTPToAddress)
    if(-not ([String]::IsNullOrEmpty($SMTPCCAddress)))
    {
        $Email.CC.Add($SMTPCCAddress)
    }
    $Email.Subject = $SMTPMailSubject
    $Email.Body = Get-Content -Path $SMTPBodyFile.localpath
    $Email.IsBodyHtml = $true
    $Attachment = new-object Net.Mail.Attachment($AttachmentFile.LocalPath)
    $Email.Attachments.Add($Attachment)
    $SMTPClient.Send($Email)
}

