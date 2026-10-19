#requires -Version 7.0
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Read-Json([string]$relative) {
    return Get-Content -LiteralPath (Join-Path $root $relative) -Raw -Encoding utf8 | ConvertFrom-Json
}
$world = Read-Json 'docs/数据/世界地图关系.json'
$costs = Read-Json 'docs/数据/门派功法升级消耗.json'
$bootstrap = Read-Json 'game/data/bootstrap.json'
$sectDoc = Get-Content -LiteralPath (Join-Path $root 'docs/门派设计.md') -Raw -Encoding utf8
$mapDoc = Get-Content -LiteralPath (Join-Path $root 'docs/世界地图与区域设计.md') -Raw -Encoding utf8

if ($world.schemaVersion -ne 1 -or $world.characterMaxLevel -ne 175 -or
    $world.skillMaxLevel -ne 180 -or $world.tracksPerCharacter -ne 6 -or
    $world.party.characters -ne 5 -or $world.party.petsPerCharacter -ne 1) {
    throw '世界规格必须为 175／180、六轨、五人各一宠。'
}
if ($costs.schemaVersion -ne 2 -or $costs.maxLevel -ne 180 -or
    $costs.tracksPerCharacter -ne 6 -or $costs.fullPartyCharacters -ne 5) {
    throw '升级表与世界规格不一致。'
}
if ($costs.totals.oneCharacterExperience -ne 40534860 -or
    $costs.totals.oneCharacterCoins -ne 14192160 -or
    $costs.totals.fiveCharactersExperience -ne 202674300 -or
    $costs.totals.fiveCharactersCoins -ne 70960800) {
    throw '六轨总价口径错误。'
}
$ids = @($world.nodes.id)
if ($ids.Count -ne 23 -or @($ids | Sort-Object -Unique).Count -ne 23 -or $world.startNode -notin $ids) {
    throw '世界节点必须为 23 个唯一 ID，且起点存在。'
}
$knownConditions = @($world.conditions.PSObject.Properties.Name)
$edgeKeys = [Collections.Generic.HashSet[string]]::new()
foreach ($edge in $world.edges) {
    if ($edge.from -notin $ids -or $edge.to -notin $ids -or $edge.from -eq $edge.to -or $edge.bidirectional -ne $true) {
        throw '交通边引用无效、自连或未声明双向。'
    }
    $key = (@($edge.from, $edge.to) | Sort-Object) -join ':'
    if (-not $edgeKeys.Add($key)) { throw "重复交通边：$key" }
    if ($edge.condition -and $edge.condition -notin $knownConditions) { throw "未知通行条件：$($edge.condition)" }
    $fromName = ($world.nodes | Where-Object id -EQ $edge.from).name
    $toName = ($world.nodes | Where-Object id -EQ $edge.to).name
    if (-not $mapDoc.Contains("$fromName ↔ $toName")) { throw "地图表遗漏连接：$key" }
}
if ($edgeKeys.Count -ne 26) { throw '本稿交通边应为 26 条。' }
function Reachable([object[]]$edges) {
    $seen = [Collections.Generic.HashSet[string]]::new()
    $queue = [Collections.Generic.Queue[string]]::new()
    $null = $seen.Add($world.startNode)
    $queue.Enqueue($world.startNode)
    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue()
        foreach ($edge in $edges) {
            $next = if ($edge.from -eq $node) { $edge.to } elseif ($edge.to -eq $node) { $edge.from } else { $null }
            if ($next -and $seen.Add($next)) { $queue.Enqueue($next) }
        }
    }
    return ,$seen
}
$full = Reachable @($world.edges)
$initial = Reachable @($world.edges | Where-Object { -not $_.condition })
$beforeFinal = Reachable @($world.edges | Where-Object condition -NE 'final_access')
if ($full.Count -ne 23) { throw '全开放地图不连通。' }
foreach ($node in @('QH','SH','LT','TC','DJ')) {
    if (-not $initial.Contains($node)) { throw "前段闭环默认不可达：$node" }
}
if ($initial.Contains('WX') -or $beforeFinal.Contains('WX') -or $beforeFinal.Count -ne 22) {
    throw '终局条件或前置可达性异常。'
}
$finalEdges = @($world.edges | Where-Object { $_.from -eq 'WX' -or $_.to -eq 'WX' })
$entrances = @($finalEdges | ForEach-Object { if ($_.from -eq 'WX') { $_.to } else { $_.from } } | Sort-Object)
if (($entrances -join ',') -ne 'GX,HZ' -or @($finalEdges | Where-Object condition -NE 'final_access').Count -gt 0) {
    throw '终局必须保留归墟与回烛两个共用条件的入口。'
}
$sectIds = @($world.sects.id)
if ($sectIds.Count -ne 7 -or @($sectIds | Sort-Object -Unique).Count -ne 7 -or
    @($world.sects.mechanic | Sort-Object -Unique).Count -ne 7 -or
    (Compare-Object ($sectIds | Sort-Object) ($bootstrap.sects.id | Sort-Object))) {
    throw '七派 ID 或独立机制缺失，与启动数据不一致。'
}
foreach ($sect in $world.sects) {
    if ($sect.nodeId -notin $ids -or $sect.activeTracks -ne 5 -or $sect.specializationTracks -ne 1) {
        throw "门派地区或轨数无效：$($sect.id)"
    }
    if ($sect.anchor.Count -ne 2 -or $sect.sceneSize.Count -ne 2 -or $sect.entry.Count -ne 2 -or $sect.teacherPosition.Count -ne 2) {
        throw "坐标必须为二维：$($sect.id)"
    }
    foreach ($axis in 0..1) {
        if ($sect.anchor[$axis] -lt 0 -or $sect.anchor[$axis] -gt 1 -or $sect.sceneSize[$axis] -le 0 -or
            $sect.entry[$axis] -lt 0 -or $sect.entry[$axis] -ge $sect.sceneSize[$axis] -or
            $sect.teacherPosition[$axis] -lt 0 -or $sect.teacherPosition[$axis] -ge $sect.sceneSize[$axis]) {
            throw "门派坐标越界：$($sect.id)"
        }
    }
    $nodeName = ($world.nodes | Where-Object id -EQ $sect.nodeId).name
    $rowPattern = '(?m)^\| ' + [regex]::Escape($sect.name + '／' + $sect.id) + ' \|[^\r\n]*'
    $row = [regex]::Match($sectDoc, $rowPattern).Value
    if (-not $row.Contains($nodeName) -or -not $row.Contains($sect.teacher)) { throw "驻地表未同步：$($sect.id)" }
    $bootstrapName = ($bootstrap.sects | Where-Object id -EQ $sect.id).name
    if ($sect.name -cne $bootstrapName) { throw "门派中文名未同步：$($sect.id)" }
}
if ([regex]::Matches($sectDoc, '(?m)^六条研修轨：').Count -ne 7 -or
    [regex]::Matches($sectDoc, '(?m)^\| [^|\r\n]+／\d+ \|').Count -ne 35) {
    throw '门派文档必须包含七组六轨与 35 项主动术式。'
}
Write-Host "检查通过：23 节点、26 条双向边、默认可达 $($initial.Count) 区域、终局双入口、七派坐标、35 术式与六轨费用。"
Write-Host '此检查不验证任务可解性、区域碰撞、玩法平衡、美术相似性或法律结论。'
