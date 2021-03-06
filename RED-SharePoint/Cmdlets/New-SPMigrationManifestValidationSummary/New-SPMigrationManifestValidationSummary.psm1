function New-SPMigrationManifestValidationSummary
{
    [cmdletbinding(SupportsShouldProcess=$True)]
    param(
    [parameter(Mandatory=$True, position=0, HelpMessage="This should be a JSON file that was generated using New-SourceMigrationManifest")]
    [ValidateScript({
        if($_.localpath.endswith("json")){$True}else{throw "`r`n`'InputFile`' must be a JSON file"}
        if(test-path $_.localpath){$True}else{throw "`r`nFile $($_.localpath) does not exist"}
    })]
    [URI]$SourceManifest,
    [parameter(Mandatory=$False, position=1, HelpMessage="This is the output CSV file that will be generated bu this script")]
    [ValidateScript({
        if($_.localpath.endswith("json")){$True}else{throw "`r`n`'InputFile`' must be a JSON file"}
        if(!(Test-Path $_.localpath)){$True}elseif((Test-Path $_.localpath) -and ($Force)){$True}else{throw "`r`nFile $($_.localpath) already exists.  Use the -Force switch"}
    })]
    [URI]$OutputFile,
    [parameter(Mandatory=$True, position=2, HelpMessage="Used to indicate which phase of reporting we are performing")]
    [ValidateSet("Structure", "ItemCount", "Permissions", "FullReport")]
    [String]$Mode,
    [parameter(Mandatory=$False, position=2, HelpMessage="Supply a credential object to connect to SharePOint Online")]
    [System.Management.Automation.PSCredential]$Credential,
    [parameter(Mandatory=$False, position=3, HelpMessage="Use the -Force switch to overwrite the existing output file")]
    [switch]$Force,
    [parameter(Mandatory=$False, position=2, HelpMessage="Use the -GroupExclusionFile parameter to specify a text file containing a list groups that should be evaluated for exclusion.")]
    [ValidateScript({
    if($_.localpath.endswith("txt")){$True}else{throw "`r`n`'InputFile`' must be a txt file"}
    if(test-path $_.localpath){$True}else{throw "`r`nFile $($_.localpath) does not exist"}
    })]
    [URI]$GroupExclusionFile,
    [parameter(Mandatory=$False, position=1, HelpMessage="Use the -IncludeHiddenLists switch to include hidden lists in the report")]
    [switch]$IncludeHidddenLists
    )

    if([String]::IsNullOrEmpty($OutputFile.LocalPath))
    {
        $OutputDirectory = New-Object Uri($SourceManifest, ".")
        [URI]$OutputFile = Join-Path $OutputDirectory.LocalPath "\$($SourceManifest.Segments.replace("%20"," ")[($SourceManifest.Segments.Count -1)].Substring(0,($SourceManifest.Segments.replace("%20"," ")[$SourceManifest.Segments.Count -1]).LastIndexOf(".")))_$(Get-Date -Format MMddyyyy-HH_mm_ss)_ValidationSummary_$($Mode).json"
    }

    if($host.Version.Major -lt 5)
    {
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
        $jsonserial= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
        $jsonserial.MaxJsonLength = 67108864
        [System.Object]$Results = $jsonserial.DeserializeObject((Get-Content $SourceManifest.LocalPath))

        $SourceEntries = New-Object System.Collections.ArrayList
        foreach($Entry in $Results)
        {
            $CurrentEntry = New-Object PSObject -Property $Entry
            $SourceEntries.Add($CurrentEntry) | Out-Null
        }

    }
    else
    {
        $SourceEntries = (Get-Content $SourceManifest.LocalPath | Out-String | ConvertFrom-Json)
    }
    $UniqueSites = , $SourceEntries | Get-UniqueSitesFromSourceSiteMigrationManifest
    $ValidationSummary = New-Object System.Collections.Arraylist
    $ReportInfo = New-Object System.Object
    $ReportInfo | Add-Member -MemberType NoteProperty -Name "Type of Entry" -Value "ReportInfo"
    $ReportInfo | Add-Member -MemberType NoteProperty -Name "Date" -value "$(Get-Date)"
    $ReportInfo | Add-Member -MemberType NoteProperty -Name "Mode" -Value "$($Mode)"
    $ValidationSummary.Add($ReportInfo) | Out-Null
    foreach($Site in $UniqueSites)
    {
        $RelevantEntries = $SourceEntries | where-object {$_."Source Site URL" -eq $Site."Source Site URL"}
        if(($Mode -eq "Structure") -or ($Mode -eq "FullReport"))
        {
            $SiteFeatureEntries = $RelevantEntries | Where-Object {$_.'type of entry' -eq "Site Collection Feature"}
            $FeatureReport = Get-SPOSiteFeatureMigrationValidation -SiteFeatureEntries $SiteFeatureEntries -Credential $Credential
            foreach($Entry in $FeatureReport)
            {
                $ValidationSummary.Add($Entry) | Out-Null
            }
        }
        
        foreach($Entry in $RelevantEntries)
        {
            if($Entry.'Type of Entry' -eq "Site Collection")
            {
                if(($Mode -eq "Structure") -or ($Mode -eq "FullReport"))
                {
                    $SummaryInfo =  $Entry | Get-SPSiteMigrationValidation -Credential $Credential
                    if($SummaryInfo)
                    {
                        $ValidationSummary.Add($SummaryInfo) | Out-Null
                    }
                    else
                    {
                        $ErrorObject = New-Object System.Object
                        $ErrorObject | Add-Member -MemberType NoteProperty -Name "Type of Entry" -Value "Site"
                        $ErrorObject | Add-Member -MemberType NoteProperty -Name "Destination Site URL" -Value $entry.'Destination Site URL'
                        $ErrorObject | Add-Member -MemberType NoteProperty -Name "Error" -Value "Error Processing Site $($Entry.'Destination Site URL')"
                        $ValidationSummary.Add($ErrorObject) |Out-Null
                    }
                    Remove-Variable -Name SummaryInfo
                }

            }
            elseif($Entry.'Type of Entry' -eq "Web")
            {
                if(($Mode -eq "Structure") -or ($Mode -eq "FullReport") -or ($Mode -eq "ItemCount"))
                {
                    $Expression = "`$SummaryInfo = `$Entry | Get-SPOWebMigrationValidation -Credential `$Credential"
                    if($IncludeHiddenLists)
                    {
                        $Expression = "$($Expression) -IncludeHiddenLists"
                    }
                    if($Mode -eq "ItemCount")
                    {
                        $Expression = "$($Expression) -Mode `"WebPartsOnly`""
                    }
                    Invoke-Expression $Expression


                    if($SummaryInfo)
                    {
                        $ValidationSummary.Add($SummaryInfo) | Out-Null
                    }
                    else
                    {
                        $ErrorObject = New-Object System.Object
                        $ErrorObject | Add-Member -MemberType NoteProperty -Name "Type of Entry" -Value "Web"
                        $ErrorObject | Add-Member -MemberType NoteProperty -name "Destination Web URL" -Value $(($Entry.'Web URL').Replace($Entry.'Source Site URL', $Entry.'Destination Site URL'))
                        $ErrorObject | Add-Member -MemberType NoteProperty -Name "Error" -Value "Error Processing Web $(($Entry.'Web URL').Replace($Entry.'Source Site URL', $Entry.'Destination Site URL'))"
                        $ValidationSummary.Add($ErrorObject) |Out-Null
                    }
                    Remove-Variable -Name SummaryInfo
                }

            }
            elseif($Entry.'Type of Entry' -eq "List")
            {
                if(($Mode -eq "ItemCount") -or ($Mode -eq "FullReport"))
                {
                    $SummaryInfo = $Entry | Get-SPOListMigrationValidation -Credential $Credential
                    if($SummaryInfo)
                    {
                        $ValidationSummary.Add($SummaryInfo) | Out-Null
                    }
                    else
                    {
                        $ErrorObject = New-Object System.Object
                        $ErrorObject | Add-Member -MemberType NoteProperty -Name "Type of Entry" -value "List"
                        $ErrorObject | Add-Member -MemberType NoteProperty -Name "Source Web URL" -Value "$($Entry.'Web URL')"
                        $ErrorObject | Add-Member -MemberType NoteProperty -Name "Destination Web URL" -Value $(($Entry.'Web URL').Replace($Entry.'Source Site URL', $Entry.'Destination Site URL'))
                        $ErrorObject | Add-Member -MemberType NoteProperty -Name "List Title" -value $Entry.'List Title'
                        $ErrorObject | Add-Member -MemberType NoteProperty -Name "Error" -Value "Error processing list `'$($entry.'List Title')`' in web $(($Entry.'Web URL').Replace($Entry.'Source Site URL', $Entry.'Destination Site URL'))"
                        $ValidationSummary.Add($ErrorObject) | Out-Null
                    }
                    Remove-Variable -Name SummaryInfo
                }

            }
            elseif($entry.'Type of Entry' -eq "Role")
            {
                if(($Mode -eq "Permissions") -or ($Mode -eq "FullReport"))
                {
                    $SummaryInfo = $Entry | Get-SPOWebRoleValidation -Credential $Credential
                    $ValidationSummary.Add($SummaryInfo) | Out-Null
                }
            }
            elseif($Entry.'Type of Entry' -eq "Group")
            {
                if(($Mode -eq "Permissions") -or ($mode -eq "FullReport"))
                {
                    $Expression = "`$SummaryInfo = `$Entry | Get-SPOWebGroupValidation -Credential `$Credential"
                    if($GroupExclusionFile)
                    {
                        $Expression = "$($Expression) -GroupExclusionFile `"$($GroupExclusionFile.LocalPath)`""
                    }
                    Invoke-Expression $Expression
                    $ValidationSummary.Add($SummaryInfo) | Out-Null
                }
            }
            elseif($entry.'Type of Entry' -eq "Group Mapping")
            {
                if(($Mode -eq "Permissions") -or ($Mode -eq "FullReport"))
                {
                    $SummaryInfo = $Entry | Get-SPOWebGroupMappingValidation -Credential $Credential
                    $ValidationSummary.Add($SummaryInfo) | Out-Null
                }
            }
        }

    }
    if(!($OutputFile.LocalPath))
    {
        $OutputFile = Get-URIFromString $OutputFile.OriginalString
    }
    $ValidationSummary | ConvertTo-Json | Out-File $OutputFile.LocalPath
}