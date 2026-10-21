[CmdletBinding()]
param(
  [switch]$SkipUpstreamInstaller,
  [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$bundleRoot = $PSScriptRoot
$manifestPath = Join-Path $bundleRoot 'manifest.json'
$installerPath = Join-Path $bundleRoot 'CodexDreamSkin-Setup-v1.5.21.exe'
$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$engineRoot = Join-Path $stateRoot 'engine'
$resultPath = Join-Path $bundleRoot 'install-result.json'
$expectedPackageName = 'OpenAI.Codex'
$backupRoot = $null
$operationLock = $null
$managerMaintenance = $null

function Write-GoldenGateJson {
  param([string]$Path, [object]$Value)
  $json = $Value | ConvertTo-Json -Depth 8
  [System.IO.File]::WriteAllText($Path, $json + "`r`n", [System.Text.UTF8Encoding]::new($false))
}

function Get-GoldenGateSha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  $stream = [System.IO.File]::OpenRead([System.IO.Path]::GetFullPath($Path))
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([System.BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
    $stream.Dispose()
  }
}

function Assert-GoldenGateBundle {
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Golden Gate manifest.json is missing.'
  }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($manifest.schemaVersion -ne 1 -or $manifest.theme.id -cne 'preset-macos-golden-gate-amber-bridge') {
    throw 'Golden Gate bundle metadata is invalid.'
  }
  foreach ($property in $manifest.files.PSObject.Properties) {
    $relative = $property.Name.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $bundleRoot $relative))
    $rootPrefix = [System.IO.Path]::GetFullPath($bundleRoot).TrimEnd('\') + '\'
    if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      throw "Golden Gate bundle file is missing or escaped its root: $($property.Name)"
    }
    $item = Get-Item -LiteralPath $candidate -Force
    $hash = Get-GoldenGateSha256 -Path $candidate
    if ($item.Length -ne [int64]$property.Value.bytes -or $hash -cne "$($property.Value.sha256)") {
      throw "Golden Gate bundle hash mismatch: $($property.Name)"
    }
  }
  return $manifest
}

function Get-VerifiedCodexPackage {
  $packages = @(Get-AppxPackage -Name $expectedPackageName -ErrorAction Stop)
  if ($packages.Count -ne 1 -or "$($packages[0].Name)" -cne $expectedPackageName -or
    "$($packages[0].PublisherId)" -cne '2p2nqsd0c76g0') {
    throw 'The exact official OpenAI.Codex Store package was not found.'
  }
  $root = [System.IO.Path]::GetFullPath("$($packages[0].InstallLocation)")
  $executable = [System.IO.Path]::GetFullPath((Join-Path $root 'app\ChatGPT.exe'))
  if (-not (Test-Path -LiteralPath $executable -PathType Leaf) -or
    -not $executable.StartsWith($root.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The official OpenAI.Codex executable identity could not be validated.'
  }
  return [pscustomobject]@{ Package = $packages[0]; Root = $root; Executable = $executable }
}

function Stop-VerifiedCodexPackage {
  param([object]$Codex)
  $matches = @()
  foreach ($process in @(Get-Process -Name ChatGPT -ErrorAction SilentlyContinue)) {
    try {
      $path = [System.IO.Path]::GetFullPath($process.Path)
      if ($path.StartsWith($Codex.Root.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        $matches += $process
      }
    } catch {}
  }
  foreach ($process in $matches) {
    try { $null = $process.CloseMainWindow() } catch {}
  }
  if ($matches.Count -gt 0) { Start-Sleep -Seconds 3 }
  foreach ($process in $matches) {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction Stop }
  }
  $deadline = [DateTime]::UtcNow.AddSeconds(12)
  do {
    $remaining = @(Get-Process -Name ChatGPT -ErrorAction SilentlyContinue | Where-Object {
      try { $_.Path.StartsWith($Codex.Root.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase) }
      catch { $false }
    })
    if ($remaining.Count -eq 0) { return }
    Start-Sleep -Milliseconds 250
  } while ([DateTime]::UtcNow -lt $deadline)
  throw 'The verified OpenAI.Codex package did not close.'
}

function Copy-GoldenGateFile {
  param([string]$Source, [string]$Destination)
  $parent = Split-Path -Parent $Destination
  New-Item -ItemType Directory -Path $parent -Force | Out-Null
  Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
  $sourceHash = Get-GoldenGateSha256 -Path $Source
  $destinationHash = Get-GoldenGateSha256 -Path $Destination
  if ($sourceHash -cne $destinationHash) { throw "Installed file hash mismatch: $Destination" }
}

try {
  Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue
  $manifest = Assert-GoldenGateBundle
  $codex = Get-VerifiedCodexPackage
  Stop-VerifiedCodexPackage -Codex $codex

  if (-not $SkipUpstreamInstaller) {
    $installer = Start-Process -FilePath $installerPath -ArgumentList @(
      '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/TASKS=""'
    ) -Wait -PassThru
    if ($installer.ExitCode -ne 0) { throw "Codex Dream Skin installer failed with exit code $($installer.ExitCode)." }
  }

  $commonPath = Join-Path $engineRoot 'scripts\common-windows.ps1'
  $themeFunctionsPath = Join-Path $engineRoot 'scripts\theme-windows.ps1'
  if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $themeFunctionsPath -PathType Leaf)) {
    throw 'The managed Windows Dream Skin engine is incomplete after setup.'
  }
  . $commonPath
  . $themeFunctionsPath
  $operationLock = Enter-DreamSkinOperationLock
  Stop-DreamSkinTrayProcess -ScriptPaths @((Join-Path $engineRoot 'scripts\tray-dream-skin.ps1')) -RequireStopped
  Stop-DreamSkinThemeManagerProcess -StateRoot $stateRoot
  $managerMaintenance = Enter-DreamSkinThemeManagerMaintenance

  $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
  $backupRoot = Join-Path $stateRoot "golden-gate-backups\$stamp"
  New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
  foreach ($relative in @(
    'assets\dream-skin.css', 'assets\renderer-inject.js', 'assets\selectors.json',
    'scripts\injector.mjs', 'scripts\common-windows.ps1', 'scripts\install-dream-skin.ps1',
    'scripts\restore-dream-skin.ps1', 'scripts\start-dream-skin.ps1'
  )) {
    $source = Join-Path $engineRoot $relative
    if (Test-Path -LiteralPath $source -PathType Leaf) {
      $destination = Join-Path $backupRoot $relative
      New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
      Copy-Item -LiteralPath $source -Destination $destination -Force
    }
  }
  foreach ($relative in @('active-theme', 'workspace-ui.json')) {
    $source = Join-Path $stateRoot $relative
    if (Test-Path -LiteralPath $source) {
      Copy-Item -LiteralPath $source -Destination (Join-Path $backupRoot $relative) -Recurse -Force
    }
  }

  foreach ($relative in @(
    'assets\dream-skin.css', 'assets\renderer-inject.js', 'assets\selectors.json',
    'assets\workspace-preferences.mjs', 'scripts\injector.mjs', 'scripts\common-windows.ps1',
    'scripts\install-dream-skin.ps1', 'scripts\restore-dream-skin.ps1', 'scripts\start-dream-skin.ps1'
  )) {
    Copy-GoldenGateFile -Source (Join-Path $bundleRoot (Join-Path 'patch' $relative)) `
      -Destination (Join-Path $engineRoot $relative)
  }

  $themeId = 'preset-macos-golden-gate-amber-bridge'
  $activeTheme = Join-Path $stateRoot 'active-theme'
  $savedTheme = Join-Path (Join-Path $stateRoot 'themes') $themeId
  foreach ($directory in @($activeTheme, $savedTheme)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    Copy-GoldenGateFile -Source (Join-Path $bundleRoot 'theme\background.jpg') `
      -Destination (Join-Path $directory 'background.jpg')
    Copy-GoldenGateFile -Source (Join-Path $bundleRoot 'theme\theme.json') `
      -Destination (Join-Path $directory 'theme.json')
  }
  Copy-GoldenGateFile -Source (Join-Path $bundleRoot 'workspace-ui.json') `
    -Destination (Join-Path $stateRoot 'workspace-ui.json')

  $configPaths = Resolve-DreamSkinConfigPaths -StateRoot $stateRoot -BindBackup
  Install-DreamSkinBaseTheme -ConfigPath $configPaths.ConfigPath -BackupPath $configPaths.BackupPath `
    -AppearanceTheme 'dark'

  if ($null -ne $managerMaintenance) {
    $managerMaintenance.ReleaseMutex()
    $managerMaintenance.Dispose()
    $managerMaintenance = $null
  }
  if ($null -ne $operationLock) {
    Exit-DreamSkinOperationLock -Mutex $operationLock
    $operationLock = $null
  }

  $verification = 'not-run'
  if (-not $NoLaunch) {
    & (Join-Path $engineRoot 'scripts\start-dream-skin.ps1') -RestartExisting
    if ($LASTEXITCODE -ne 0) { throw "Golden Gate launch failed with exit code $LASTEXITCODE." }
    & (Join-Path $engineRoot 'scripts\verify-dream-skin.ps1')
    if ($LASTEXITCODE -ne 0) { throw "Golden Gate verification failed with exit code $LASTEXITCODE." }
    $verification = 'passed'
  }

  Write-GoldenGateJson -Path $resultPath -Value ([ordered]@{
    schemaVersion = 1
    outcome = 'success'
    rendererVersion = "$($manifest.rendererVersion)"
    themeId = "$($manifest.theme.id)"
    verification = $verification
    backup = $backupRoot
  })
  Write-Host 'Golden Gate was installed. Codex renderer verification passed.' -ForegroundColor Green
  exit 0
} catch {
  Write-GoldenGateJson -Path $resultPath -Value ([ordered]@{
    schemaVersion = 1
    outcome = 'failure'
    message = $_.Exception.Message
    backup = $backupRoot
  })
  Write-Error $_
  exit 1
} finally {
  if ($null -ne $managerMaintenance) {
    $managerMaintenance.ReleaseMutex()
    $managerMaintenance.Dispose()
  }
  if ($null -ne $operationLock) { Exit-DreamSkinOperationLock -Mutex $operationLock }
}
