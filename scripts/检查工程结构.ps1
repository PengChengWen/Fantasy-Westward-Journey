#requires -Version 7.0
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

function Get-ProjectText([string]$relativePath) {
    $absolutePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "缺少文件：$relativePath"
    }
    return [System.IO.File]::ReadAllText($absolutePath, $utf8)
}

$allowedReferences = [ordered]@{
    'src/Game.Domain/Game.Domain.csproj' = @()
    'src/Game.Application/Game.Application.csproj' = @('src/Game.Domain/Game.Domain.csproj')
    'src/Game.Infrastructure/Game.Infrastructure.csproj' = @('src/Game.Application/Game.Application.csproj')
    'game/Game.Client.csproj' = @('src/Game.Application/Game.Application.csproj', 'src/Game.Infrastructure/Game.Infrastructure.csproj')
    'tools/ContentPipeline/ContentPipeline.csproj' = @('src/Game.Domain/Game.Domain.csproj')
    'tests/Game.Domain.Tests/Game.Domain.Tests.csproj' = @('src/Game.Domain/Game.Domain.csproj')
}

foreach ($relativePath in $allowedReferences.Keys) {
    [xml]$projectXml = Get-ProjectText $relativePath
    $projectDirectory = Split-Path -Parent (Join-Path $projectRoot $relativePath)
    $actualReferences = @($projectXml.SelectNodes('//ProjectReference') | ForEach-Object {
        $referencePath = [System.IO.Path]::GetFullPath((Join-Path $projectDirectory $_.Include))
        if (-not (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
            throw "项目引用不存在：$relativePath -> $($_.Include)"
        }
        [System.IO.Path]::GetRelativePath($projectRoot, $referencePath).Replace('\', '/')
    })
    $expected = @($allowedReferences[$relativePath] | Sort-Object) -join ';'
    $actual = @($actualReferences | Sort-Object) -join ';'
    if ($expected -ne $actual) {
        throw "依赖方向不符合架构：$relativePath。期望 [$expected]，实际 [$actual]"
    }
    if ($relativePath -notlike 'game/*') {
        if ($projectXml.Project.Sdk -ne 'Microsoft.NET.Sdk') {
            throw "纯 C# 项目不能使用引擎 SDK：$relativePath"
        }
        foreach ($packageReference in $projectXml.SelectNodes('//PackageReference')) {
            if ($packageReference.Include -match 'Godot|Unity|Steamworks') {
                throw "平台或引擎依赖进入核心工程：$relativePath"
            }
        }
    }
}

foreach ($solutionPath in @('Game.Core.slnx', 'Game.slnx')) {
    [xml]$solution = Get-ProjectText $solutionPath
    foreach ($project in $solution.SelectNodes('//Project')) {
        if (-not $allowedReferences.Contains($project.Path)) {
            throw "解决方案含未登记项目：$($project.Path)"
        }
    }
    if ($solutionPath -eq 'Game.Core.slnx' -and $solution.SelectNodes('//Project[@Path="game/Game.Client.csproj"]').Count -gt 0) {
        throw '核心解决方案不能依赖 Godot 客户端'
    }
}

foreach ($sourceFile in (Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') -Recurse -Filter '*.cs' -File)) {
    if ($sourceFile.FullName -match '[\\/](obj|bin)[\\/]') { continue }
    $source = [System.IO.File]::ReadAllText($sourceFile.FullName, $utf8)
    if ($source -match '\b(Godot|UnityEngine|Steamworks)\.') {
        throw "核心源码直接引用引擎或平台：$($sourceFile.FullName)"
    }
}

$bootstrap = (Get-ProjectText 'game/data/bootstrap.json') | ConvertFrom-Json
if ($bootstrap.schemaVersion -ne 1 -or $bootstrap.party.maxCharacters -ne 5 -or $bootstrap.party.maxPetsPerCharacter -ne 1) {
    throw '启动数据必须符合五角色、每角色一只宠物的当前设计'
}
$sectIds = @($bootstrap.sects | ForEach-Object { $_.id })
if ($sectIds.Count -ne 7 -or @($sectIds | Sort-Object -Unique).Count -ne 7) {
    throw '初始七门派 ID 必须完整且唯一'
}
foreach ($sect in $bootstrap.sects) {
    if ([string]::IsNullOrWhiteSpace($sect.id) -or [string]::IsNullOrWhiteSpace($sect.name)) {
        throw '门派 ID 和名称不能为空'
    }
}

$godotProject = Get-ProjectText 'game/project.godot'
$bootScene = Get-ProjectText 'game/scenes/bootstrap/Boot.tscn'
if ($godotProject -notmatch 'run/main_scene="res://scenes/bootstrap/Boot.tscn"') {
    throw 'Godot 启动场景引用缺失'
}
foreach ($resource in [regex]::Matches($bootScene, 'res://([^"\r\n]+)')) {
    $null = Get-ProjectText ('game/' + $resource.Groups[1].Value)
}

$documents = @((Join-Path $projectRoot 'Agent.md'), (Join-Path $projectRoot '项目说明.md'))
$documents += @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'docs') -Filter '*.md' -File | ForEach-Object { $_.FullName })
foreach ($documentPath in $documents) {
    $document = [System.IO.File]::ReadAllText($documentPath, $utf8)
    foreach ($link in [regex]::Matches($document, '\]\(([^):]+\.md)\)')) {
        $target = Join-Path (Split-Path -Parent $documentPath) $link.Groups[1].Value
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            throw "文档链接不存在：$documentPath -> $($link.Groups[1].Value)"
        }
    }
}

Write-Host "检查通过：$($allowedReferences.Count) 个项目依赖、解决方案、启动资源、七门派数据和中文文档链接。"
Write-Host '此检查不等于 C# 编译、单元测试或 Godot 运行验证。'
