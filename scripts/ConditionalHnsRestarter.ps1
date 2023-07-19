param (
    [Parameter(Mandatory=$true)]
    [array] $RulesToCheck,
    # array of @{ruleRegex = ""; layerName = ""; groupName = ""}

    [Parameter(Mandatory=$false)]
    [int] $SleepIntervalMins = 5,
    # time to sleep before checking whether HNS restart is required.

    [Parameter(Mandatory=$false)]
    [int] $RuleCheckIntervalMins = 3,
    # if a rule is missing on an endpoint for more than RuleCheckIntervalMins minutes, we restart HNS

    [Parameter(Mandatory=$false)]
    [int] $MaxHnsRestarts = 2,

    [Parameter(Mandatory=$false)]
    [int] $MinRestartInterval = 5,

    [Parameter(Mandatory=$false)]
    [string] $WindowsLogsPath = "C:\k\debug\ConditionalHnsRestart_data\"
)

class RuleCheckInfo {
    [string]$ruleRegex
    [string]$layerName
    [string]$groupName
    RuleCheckInfo([string] $in_ruleRegex, [string] $in_layerName, [string] $in_groupName)
    {
        $this.ruleRegex = $in_ruleRegex
        $this.layerName = $in_layerName
        $this.groupName = $in_groupName
    }
}

class EndpointInfo {
    [string]$id
    [System.DateTime]$notedTime

    EndpointInfo([string] $inId, [System.DateTime] $inTime)
    {
        $this.id = $inId
        $this.notedTime = $inTime
    }
}

$g_scriptStartTime = get-date
$g_endpointInfoMap = @{} # key = id, value = EndpointInfo
$g_ruleCheckList = @() # array of RuleCheckInfo objects
$g_hnsRestartCount = 0
$g_lastHnsRestartTime = get-date

function RulesAreMissing() {
    $vfpPortsIdList = ((vfpctrl /list-vmswitch-port /format 1 | convertfrom-json).Ports | select id)
    # find new IDs
    foreach ($element in $vfpPortsIdList)
    {
        if ($g_endpointInfoMap.ContainsKey($element.Id) -eq $false)
        {
            $notedTime = get-date
            $g_endpointInfoMap[$element.Id] = [EndpointInfo]::New($element.Id, $notedTime)
        }
    }

    return $false
}

function ScriptSetup()
{
    foreach ($rule in $RulesToCheck)
    {
        $g_ruleCheckList += [RuleCheckInfo]::New($rule.ruleRegex, $rule.layerName, $rule.groupName)
    }
}

function CheckIfRestartRequired()
{
    $rulesMissing = RulesAreMissing
    return $false
}

function collectLogsAndRestartHns()
{
}

function myMain() {    
    while ($true) {
        restartRequired = CheckIfRestartRequired
        current_time = get-date

        if ((current_time - script_start_time).Minutes -lt $SleepIntervalMins) {
            # current_time could be just after a reboot, or just after a HNS/kube-proxy restart.
            # Let's not restart yet.
            sleep ($SleepIntervalMins * 60)
            continue
        }
        elseif ($g_hnsRestartCount -ge $MaxHnsRestarts)
        {
            # TODO: log("max HNS restarts already done. Shouldn't restart anymore.")
            sleep ($SleepIntervalMins * 60)
            continue
        }
        elseif ($g_hnsRestartCount -eq 0)
        {
            # TODO: log("")
            collectLogsAndRestartHns -LogsPath $WindowsLogsPath
            sleep ($SleepIntervalMins * 60)
            continue
        }
    }
}

myMain
