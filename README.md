# PSAgentDeploy
deploy scripts for PSAgentTemplate

# ssh support
ssh was added to enable deployment from macs. assumes ssh is already configured with keys and commands can be executed with `ssh user@target "command"` format. must also add a 'user' to settings.json in the jobs section.

this process initially was for deployment from a windows machine to another windows machine, but after switching to a mac there were some changes that had to be made. there seemed to be some hoops to jump through to make remote powershell sessions work on a mac, so since the required functionality for this script was simply copying files and running a command to schedule the task, ssh support was added.

to enable this, need to see the following pages:
https://techcommunity.microsoft.com/t5/itops-talk-blog/installing-and-configuring-openssh-on-windows-server-2019/ba-p/309540

there is a video there to follow as well, but there are the following issues:
1. On the repair step, make sure you say NO when asked to give the service account read permissions
2. On the repair step, i was setting up as another id so it asked to remove inheritance and my logged in id as acccess. i said yes. you can watch the video on the link above to see what the icacls output should look like
3. when copying the authorized keys, since i was coming from a mac, i had to use / instead of \ in the scp copy path. like below:
scp ./id_rsa myid@host:C:/Users/myid/.ssh/authorized_keys

some paths and things had to be slightly modified in the deploy.ps1 since we are just running schtasks via ssh instead of using iex, but these were pretty minor.