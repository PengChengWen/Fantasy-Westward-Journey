#requires -Version 7.0
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$documentPath = Join-Path $repositoryRoot 'docs/门派设计.md'
$dataPath = Join-Path $repositoryRoot 'docs/数据/门派功法升级消耗.json'
$encoding = [System.Text.UTF8Encoding]::new($false, $true)
$culture = [System.Globalization.CultureInfo]::InvariantCulture

function Format-Amount([long]$amount) {
    return $amount.ToString('N0', $culture)
}

$rows = [System.Collections.Generic.List[object]]::new()
$cumulativeExperience = [long]0
$cumulativeCoins = [long]0
foreach ($level in 1..180) {
    $n = [long]$level
    $experienceNumerator = [long]10000 + 1000*$n + 200*$n*$n + $n*$n*$n
    $experience = [long](10 * [math]::Floor(($experienceNumerator + 999) / 1000.0))
    $coins = [long](10 * [math]::Floor((35*$experience + 999) / 1000.0))
    $cumulativeExperience += $experience
    $cumulativeCoins += $coins
    $rows.Add([ordered]@{
        fromLevel = $level - 1
        toLevel = $level
        experience = $experience
        coins = $coins
        cumulativeExperience = $cumulativeExperience
        cumulativeCoins = $cumulativeCoins
    })
}

# Golden totals and boundaries make accidental curve changes explicit.
if ($rows.Count -ne 180 -or $rows[0].experience -ne 120 -or $rows[0].coins -ne 50 -or
    $rows[179].experience -ne 125020 -or $rows[179].coins -ne 43760 -or
    $cumulativeExperience -ne 6755810 -or $cumulativeCoins -ne 2365360) {
    throw '升级费用与已审核的曲线基线不一致，请先明确调整曲线版本和设计总额。'
}
foreach ($index in 1..179) {
    if ($rows[$index].experience -lt $rows[$index-1].experience -or $rows[$index].coins -lt $rows[$index-1].coins) {
        throw '升级费用不能随等级降低。'
    }
}

$table = [System.Text.StringBuilder]::new()
$null = $table.AppendLine('### 12.1 单条功法关键等级')
$null = $table.AppendLine()
$null = $table.AppendLine('| 目标等级 | 本级经验 | 本级铜铢 | 0→本级累计经验 | 0→本级累计铜铢 |')
$null = $table.AppendLine('| --- | --- | --- | --- | --- |')
foreach ($level in @(1,20,40,60,80,100,120,140,160,180)) {
    $row = $rows[$level-1]
    $null = $table.AppendLine("| $level | $(Format-Amount $row.experience) | $(Format-Amount $row.coins) | $(Format-Amount $row.cumulativeExperience) | $(Format-Amount $row.cumulativeCoins) |")
}

$null = $table.AppendLine()
$null = $table.AppendLine('### 12.2 分阶段投入与累计')
$null = $table.AppendLine()
$null = $table.AppendLine('| 升级区间 | 本段经验 | 本段铜铢 | 累计经验 | 累计铜铢 |')
$null = $table.AppendLine('| --- | --- | --- | --- | --- |')
foreach ($upper in @(20,40,60,80,100,120,140,160,180)) {
    $lower = $upper - 20
    $last = $rows[$upper-1]
    $previousExperience = if ($lower -eq 0) { 0L } else { $rows[$lower-1].cumulativeExperience }
    $previousCoins = if ($lower -eq 0) { 0L } else { $rows[$lower-1].cumulativeCoins }
    $null = $table.AppendLine("| $lower→$upper | $(Format-Amount ($last.cumulativeExperience-$previousExperience)) | $(Format-Amount ($last.cumulativeCoins-$previousCoins)) | $(Format-Amount $last.cumulativeExperience) | $(Format-Amount $last.cumulativeCoins) |")
}

$null = $table.AppendLine()
$null = $table.AppendLine('### 12.3 修满 180 级总价')
$null = $table.AppendLine()
$null = $table.AppendLine('| 范围 | 升级次数／条数口径 | 所需经验 | 所需铜铢 |')
$null = $table.AppendLine('| --- | --- | --- | --- |')
$null = $table.AppendLine("| 单条 0→180 | 180 次 | $(Format-Amount $cumulativeExperience) | $(Format-Amount $cumulativeCoins) |")
$null = $table.AppendLine("| 单条 1→180 | 179 次，第一点已经支付 | $(Format-Amount ($cumulativeExperience-$rows[0].experience)) | $(Format-Amount ($cumulativeCoins-$rows[0].coins)) |")
$null = $table.AppendLine("| 一个角色六轨全满 | 6 条，各 0→180 | $(Format-Amount ($cumulativeExperience*6)) | $(Format-Amount ($cumulativeCoins*6)) |")
$null = $table.AppendLine("| 五名角色六轨全满 | 30 条，各 0→180 | $(Format-Amount ($cumulativeExperience*30)) | $(Format-Amount ($cumulativeCoins*30)) |")
$null = $table.AppendLine("| 七派各培养一个角色并全满 | 42 条，各 0→180；不是一个角色同时修七派 | $(Format-Amount ($cumulativeExperience*42)) | $(Format-Amount ($cumulativeCoins*42)) |")

$null = $table.AppendLine()
$null = $table.AppendLine('### 12.4 完整逐级费用表')
$null = $table.AppendLine()
$null = $table.AppendLine('每行表示从上一等级升到目标等级；累计从 0 开始。两种资源独立检查、同时扣除。')
$null = $table.AppendLine()
$null = $table.AppendLine('| 升级 | 所需经验 | 所需铜铢 | 累计经验 | 累计铜铢 |')
$null = $table.AppendLine('| --- | --- | --- | --- | --- |')
foreach ($row in $rows) {
    $null = $table.AppendLine("| $($row.fromLevel)→$($row.toLevel) | $(Format-Amount $row.experience) | $(Format-Amount $row.coins) | $(Format-Amount $row.cumulativeExperience) | $(Format-Amount $row.cumulativeCoins) |")
}

$document = [System.IO.File]::ReadAllText($documentPath, $encoding)
$startMarker = '<!-- SKILL_COST_TABLE_START -->'
$endMarker = '<!-- SKILL_COST_TABLE_END -->'
$pattern = '(?s)' + [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker)
if ([regex]::Matches($document, $pattern).Count -ne 1) { throw '门派文档中必须有且仅有一个费用表生成区。' }
$replacement = $startMarker + "`n" + $table.ToString().Replace("`r`n", "`n").TrimEnd() + "`n" + $endMarker
$expectedDocument = [regex]::Replace($document, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement })
$data = [ordered]@{
    schemaVersion = 2
    curveId = 'sect_cultivation_v1'
    maxLevel = 180
    tracksPerCharacter = 6
    fullPartyCharacters = 5
    experienceCurrency = 'training_exp'
    moneyCurrency = 'coin'
    formula = [ordered]@{
        experience = '10 * ceil((10000 + 1000*n + 200*n*n + n*n*n) / 1000)'
        coins = '10 * ceil(35 * experience / 1000)'
        levelMeans = 'target level; n=1 is 0->1'
    }
    totals = [ordered]@{
        oneTrackExperience = $cumulativeExperience
        oneTrackCoins = $cumulativeCoins
        oneCharacterExperience = $cumulativeExperience*6
        oneCharacterCoins = $cumulativeCoins*6
        fiveCharactersExperience = $cumulativeExperience*30
        fiveCharactersCoins = $cumulativeCoins*30
    }
    levels = @($rows.ToArray())
}
$expectedData = ($data | ConvertTo-Json -Depth 8).Replace("`r`n", "`n") + "`n"

if ($Check) {
    if ($document.Replace("`r`n", "`n") -cne $expectedDocument.Replace("`r`n", "`n")) { throw '门派文档费用表未同步，请重新生成。' }
    if (-not (Test-Path -LiteralPath $dataPath)) { throw '费用 JSON 缺失。' }
    $actualData = [System.IO.File]::ReadAllText($dataPath, $encoding).Replace("`r`n", "`n")
    if ($actualData -cne $expectedData) { throw '费用 JSON 与曲线不一致。' }
    Write-Host '检查通过：180 级逐级费用、累计值、全门派／全队总额与文档一致。'
    return
}

$null = New-Item -ItemType Directory -Path (Split-Path -Parent $dataPath) -Force
[System.IO.File]::WriteAllText($dataPath, $expectedData, $encoding)
[System.IO.File]::WriteAllText($documentPath, $expectedDocument, $encoding)
Write-Host '已生成门派文档费用表及 docs/数据/门派功法升级消耗.json。'
