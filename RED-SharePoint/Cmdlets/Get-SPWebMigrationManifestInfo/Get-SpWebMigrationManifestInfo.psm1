<#
Author:Roger Cormier
Company:Microsoft
Description: This cmdlet will return inforamtion about an SPWeb that will be important in determining the success level of a migration to SharePoint Online
#>

function Get-SPWebMigrationManifestInfo
{
    [cmdletbinding()]
    param(
    [parameter(Mandatory=$True, position=0, HelpMessage="This parameter requires an SPWeb object to be passed", ValueFromPipeline=$True, ValueFromPipelineByPropertyName)]
    [Alias('URL')]
    [Microsoft.SharePoint.SPWeb]$SPWeb
    )

    $WebEntry = New-Object System.Object
    $WebEntry | Add-Member -MemberType NoteProperty -Name "Type of Entry" -Value "Web"
    $WebEntry | Add-Member -MemberType NoteProperty -Name "Web Title" -Value $SPWeb.Title
    $WebEntry | Add-Member -MemberType NoteProperty -Name "Web URL" -Value $SPWeb.Url
    $WebEntry | Add-Member -MemberType NoteProperty -Name "Number of Lists" -Value $SPWeb.lists.Count

    Return $WebEntry
}
