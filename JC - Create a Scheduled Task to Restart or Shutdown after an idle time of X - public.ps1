<# 
- Create a scheduled task that reboots or shuts down the computer after a specified number of hours of idle time.
- The task runs invisibly and whether or not users are logged on.
- The task is created to run only when the computer is idle.
- The task is created to run as the SYSTEM account.
- The task is created to run with the highest privileges.
- The task is created to run the action in a PowerShell process that is not visible to users, and doesn't load the user's profile.
- The task is created to run the action in a PowerShell process that does not require user confirmation/interaction/input/output/prompts.
#>


# Specify the number of hours of idle time after which the reboot or shutdown should occur:
$idleTimeoutHours = 1
# Specify the task name to your liking:
$taskName = 'RebootAfterIdling'

# Create the reboot or shutdown action.
# Note: Passing -Force to Restart-Computer is the only way to ensure that the
#       computer will reboot. This result in data loss if the user has unsaved data:
$action = New-ScheduledTaskAction -Execute powershell.exe -Argument @"
  -NoProfile -Command "Start-Sleep $((New-TimeSpan -Hours $idleTimeoutHours).TotalSeconds); Restart-Computer -Force"
"@

# If you want to shutdown instead of a reboot, replace Restart-Computer with Stop-Computer:
# $action = New-ScheduledTaskAction -Execute powershell.exe -Argument @"
#  -NoProfile -Command "Start-Sleep $((New-TimeSpan -Hours $idleTimeoutHours).TotalSeconds); Stop-Computer -Force"
# "@

# Specify the user identity for the scheduled task:
# Using NT AUTHORITY\SYSTEM, so that the tasks runs invisibly and whether or not users are logged on.
$principal = New-ScheduledTaskPrincipal -UserID 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount

# Create a settings set that activates the condition to run only when idle.
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfIdle

# New-ScheduledTaskTrigger does NOT support creating on-idle triggers, but you can use the relevant CIM class directly, courtesy of this excellent blog post:
# https://www.ctrl.blog/entry/idle-task-scheduler-powershell.html
$trigger = Get-CimClass -ClassName MSFT_TaskIdleTrigger -Namespace Root/Microsoft/Windows/TaskScheduler  

# Create and register the task with the specified action, principal, settings, and trigger:
Register-ScheduledTask $taskName -Action $action -Principal $principal -Settings $settings -Trigger $trigger -Force
