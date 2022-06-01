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
function Publish-Job{
    
  #make sure settings.json is there
  $checksettings = Test-Path .\settings.json
  "Test-Path .\settings.json = $checksettings"
  if ($checksettings){

      #get config
      $cfg = Get-Content settings.json -Raw | ConvertFrom-Json
      $job = $cfg.job
      $p = $job.name
      $s = $job.server
      $d = "\\$s\c`$\jobs\$p"
      $f = $job.files -split ","
      $t = $job.teams
      $u = $job.user
      $ssh = "$u@$s"

      $sb = $null
      
      if($job.schedule -eq "every-15-minutes"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc minute /mo 15 /sd 01/01/2001 /st 00:00"}
      if($job.schedule -eq "hourly-on-the-hour"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc hourly /mo 1 /sd 01/01/2001 /st 00:00"}
      if($job.schedule -eq "hourly-on-the-15s"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc hourly /mo 1 /sd 01/01/2001 /st 00:15"}
      if($job.schedule -eq "every-6-hours"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc hourly /mo 6 /sd 01/01/2001 /st 00:00"}
      if($job.schedule -eq "daily-every-3-hours-from-545am-to-845pm"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc daily /sd 01/01/2001 /st 05:45 /du 15:00 /ri (3*60)"}
      if($job.schedule -eq "daily-at-6am-and-2pm"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc daily /sd 01/01/2001 /st 06:00 /du 10:00 /ri (8*60)"}
      if($job.schedule -eq "daily-12am"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc daily /sd 01/01/2001 /st 00:00"}
      if($job.schedule -eq "daily-3am"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc daily /sd 01/01/2001 /st 03:00"}
      if($job.schedule -eq "daily-5am"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc daily /sd 01/01/2001 /st 05:00"}
      if($job.schedule -eq "daily-230pm"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc daily /sd 01/01/2001 /st 14:30"}
      if($job.schedule -eq "daily-645pm"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc daily /sd 01/01/2001 /st 18:45"}
      if($job.schedule -eq "daily-6pm"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc daily /sd 01/01/2001 /st 18:00"}
      if($job.schedule -eq "daily-7pm"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc daily /sd 01/01/2001 /st 19:00"}
      if($job.schedule -eq "weekly-tue-10am"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc weekly /d tue /sd 01/01/2001 /st 10:00"}
      if($job.schedule -eq "every-january-first"){ $sb = "schtasks /f /create /tn '$p' /tr 'powershell c:\jobs\$p\job.ps1' /ru system /sc monthly /mo 12 /sd 01/01/2001 /st 00:00"}

      # support for pwsh, note this won't work with strictmode
      if($job.pwsh){
          $sb = $sb -replace 'powershell','C:\Progra~1\PowerShell\7\pwsh.exe'
      }

      #make sure we have a valid schedule
      if($sb){

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
          if ($job.skipnotification) {return}
          #get hash link to current commit
          $h = (git config --get remote.origin.url).replace(".git","") + "/commit/" +  (git log -n1 --format=format:"%H")

          #send publish notification to teams
          Send-Notification $p $d $s $f $sb $h $t

      }else{
          throw "no matching schedule for $($job.schedule)"
      }
  }else{
      throw "settings.json missing."
  }
  

}

function Send-Notification($p,$d,$s,$f,$sb,$h,$t){

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
                  @{"name"="Job Name:";"value"=$p},
                  @{"name"="Server:";"value"=$s},
                  @{"name"="Files:";"value"= $f -join ","},
                  @{"name"="ScriptBlock:";"value"=$sb},
                  @{"name"="Commit:";"value"=$h}
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
