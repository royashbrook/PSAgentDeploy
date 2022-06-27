<#
.SYNOPSIS
Publishes a scheduled job to an agent server

.DESCRIPTION
Publish a scheduled job to an agent server. Looks in the current directory for a settings.json for configuration information. Will also send notification to a teams channel that a deployment took place.

.EXAMPLE
Publish-Job

.NOTES
If settings.json is not found, will not work
#>
function Publish-Job {
    
    #make sure settings.json is there
    $checksettings = Test-Path .\settings.json
    "Test-Path .\settings.json = $checksettings"
    if (!$checksettings) { return }


    #get config
    $cfg = Get-Content settings.json -Raw | ConvertFrom-Json
    $job = $cfg.job
    $p = $job.name
    $s = $job.server
    $d = "\\$s\c`$\jobs\$p"
    $f = $job.files -split ","
    $t = $job.teams
    $u = $job.user
    $schedule = $job.schedule
    $ssh = "$u@$s"

    $sb = $null
      
    # note that all schedules take on the form of something like:
    # "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system SCHEDULEINFO"
    # so we will add the SCHEDULEINFO in the hash below for lookup by name
    $schedules = @{
        "every-15-minutes"                        = "/sc minute /mo 15 /sd 01/01/2001 /st 00:00"
        "hourly-on-the-hour"                      = "/sc hourly /mo 1 /sd 01/01/2001 /st 00:00"
        "hourly-on-the-15s"                       = "/sc hourly /mo 1 /sd 01/01/2001 /st 00:15"
        "every-6-hours"                           = "/sc hourly /mo 6 /sd 01/01/2001 /st 00:00"
        "every-6-hours-at-3am"                    = "/sc hourly /mo 6 /sd 01/01/2001 /st 03:00"
        "daily-every-90min-from-5am-to-6:30pm"    = "/sc daily /sd 01/01/2001 /st 05:00 /du 14:00 /ri 90"
        "daily-every-3-hours-from-545am-to-845pm" = "/sc daily /sd 01/01/2001 /st 05:45 /du 15:00 /ri (3*60)"
        "daily-at-6am-and-2pm"                    = "/sc daily /sd 01/01/2001 /st 06:00 /du 10:00 /ri (8*60)"
        "daily-12am"                              = "/sc daily /sd 01/01/2001 /st 00:00"
        "daily-3am"                               = "/sc daily /sd 01/01/2001 /st 03:00"
        "daily-5am"                               = "/sc daily /sd 01/01/2001 /st 05:00"
        "daily-9am"                               = "/sc daily /sd 01/01/2001 /st 09:00"
        "daily-10am"                              = "/sc daily /sd 01/01/2001 /st 10:00"
        "daily-230pm"                             = "/sc daily /sd 01/01/2001 /st 14:30"
        "daily-6pm"                               = "/sc daily /sd 01/01/2001 /st 18:00"
        "daily-645pm"                             = "/sc daily /sd 01/01/2001 /st 18:45"
        "daily-7pm"                               = "/sc daily /sd 01/01/2001 /st 19:00"
        "daily-9pm"                               = "/sc daily /sd 01/01/2001 /st 21:00"
        "weekly-tue-10am"                         = "/sc weekly /d tue /sd 01/01/2001 /st 10:00"
        "weekly-mon-6am"                          = "/sc weekly /d mon /sd 01/01/2001 /st 06:00"
        "every-january-first"                     = "/sc monthly /mo 12 /sd 01/01/2001 /st 00:00"
    }

    # if no schedule, exit
    if (!$schedules.$schedule) {
        "Schedule $schedule not found"
        return;
    }

    # create script block command
    $sb = "schtasks /f /create /tn '$p' /tr 'C:\Progra~1\PowerShell\7\pwsh.exe c:\jobs\$p\job.ps1' /ru system $($schedules.$schedule)"

    #create dir
    ssh $ssh mkdir -p $d

    #copy the files
    scp $f "$($ssh):$d"

    #schedule the job
    ssh $ssh $sb

    #setup paste for running job now if desired
    $runtask = "ssh $ssh schtasks /run /tn '$p'"
    Set-Clipboard $runtask; "To run job now CTRL+V or manually call: $runtask"

    #skip notification if configured
    if ($job.skipnotification) { return }
    
    #get hash link to current commit
    $h = (git config --get remote.origin.url).replace(".git", "") + "/commit/" + (git log -n1 --format=format:"%H")

    #send publish notification to teams
    Send-Notification $p $d $s $f $sb $h $t
     
}

function Send-Notification($p, $d, $s, $f, $sb, $h, $t) {

    # webhook uri for teams notification of a deployment
    $uri = $t

    #json for teams notification
    $msg = @{
        "@type"      = "MessageCard"
        "@context"   = "http://schema.org/extensions"
        "summary"    = "Publish-Job: Notification"
        "themeColor" = 'D778D7'
        "title"      = "$p was published to $d."
        "sections"   = @(
            @{
                "facts" = @(
                    @{"name" = "Job Name:"; "value" = $p },
                    @{"name" = "Server:"; "value" = $s },
                    @{"name" = "Files:"; "value" = $f -join "," },
                    @{"name" = "ScriptBlock:"; "value" = $sb },
                    @{"name" = "Commit:"; "value" = $h }
                )
                "text"  = "Job Details:"
            }
        )
    }
    $json = convertto-json $msg -depth 4
  
    #args for teams notification call
    $irmargs = @{
        "URI"         = $uri
        "Method"      = 'POST'
        "Body"        = $json
        "ContentType" = 'application/json'
    }

    Invoke-RestMethod @irmargs

}

Publish-Job
