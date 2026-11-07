<#
.SYNOPSIS
  Control de la Jean API alojada en GitHub Codespaces.

.EXAMPLE
  .\jean-api.ps1 start     # arranca el codespace, publica puertos y da la URL
  .\jean-api.ps1 urls      # solo consulta las URLs actuales
  .\jean-api.ps1 stop      # para el codespace (deja de gastar cuota)
  .\jean-api.ps1 test      # prueba /v1/models y una inferencia en cada modelo
#>
param(
  [Parameter(Position = 0)]
  [ValidateSet("start", "stop", "urls", "test", "status", "fenix-mode", "standard-mode")]
  [string]$Action = "urls"
)

$ErrorActionPreference = "Stop"
if (-not $env:GH_TOKEN) {
  throw "define \$env:GH_TOKEN con tu PAT antes de usar este script (el token no se guarda en repos)"
}
$gh = "G:\LIFE IN DANGER\tools\bin\gh.exe"
$Repo = "jeancodeeeer/jean-api"
$KeyFile = "D:\jean-work\jean_api_key.txt"

function Get-CodespaceName {
  $list = & $gh codespace list --repo $Repo --json name,state 2>$null | ConvertFrom-Json
  if (-not $list) { throw "no hay codespaces para $Repo" }
  return $list[0].name
}

function Get-ApiKey {
  if (Test-Path $KeyFile) { return (Get-Content $KeyFile -Raw).Trim() }
  throw "falta la API key en $KeyFile"
}

function Wait-State($name, $want, $maxSec = 300) {
  for ($i = 0; $i -lt ($maxSec / 5); $i++) {
    $s = (& $gh codespace view --codespace $name --json state 2>$null | ConvertFrom-Json).state
    if ($s -eq $want) { return $s }
    Start-Sleep 5
  }
  return $s
}

function Set-PortsPublic($name) {
  # Tras cada reinicio los puertos vuelven a "private" y SOLO se registran
  # al conectar por SSH (sin cliente VS Code). El ping SSH los despierta.
  & $gh codespace ssh -c $name -- "true" 2>&1 | Out-Null
  & $gh codespace ports visibility 8888:public 8889:public -c $name 2>&1 | Out-Null
}

function Get-Urls($name) {
  $ports = & $gh codespace ports -c $name --json sourcePort,browseUrl,visibility 2>$null | ConvertFrom-Json
  $out = @{}
  foreach ($p in $ports) {
    if ($p.sourcePort -eq 8888) { $out["grey"] = "$($p.browseUrl)/v1" }
    if ($p.sourcePort -eq 8889) { $out["marvel"] = "$($p.browseUrl)/v1" }
  }
  return $out
}

$name = $null
switch ($Action) {
  "start" {
    $name = Get-CodespaceName
    Write-Host "codespace: $name"
    $state = (& $gh codespace view --codespace $name --json state | ConvertFrom-Json).state
    if ($state -ne "Available") {
      Write-Host "arrancando (esto tarda ~1-2 min) ..."
      Invoke-RestMethod -Uri "https://api.github.com/user/codespaces/$name/start" -Method Post `
        -Headers @{ Authorization = "Bearer $env:GH_TOKEN"; Accept = "application/vnd.github+json" } `
        -Body '{}' -ContentType "application/json" | Out-Null
      Wait-State $name "Available" | Out-Null
    }
    # los modelos tardan: esperamos a que respondan
    Write-Host "esperando a que los modelos carguen ..."
    $key = Get-ApiKey
    $urls = @{}
    for ($i = 0; $i -lt 60; $i++) {
      Set-PortsPublic $name
      $urls = Get-Urls $name
      if ($urls["grey"]) {
        try {
          $r = Invoke-RestMethod -Uri "$($urls['grey'])/models" -Headers @{ Authorization = "Bearer $key" } -TimeoutSec 15
          if ($r.data) { break }
        } catch { }
      }
      Start-Sleep 10
    }
    Write-Host ""
    Write-Host "grey   : $($urls['grey'])"
    if ($urls["marvel"]) { Write-Host "marvel : $($urls['marvel'])" }
    Write-Host "clave  : $KeyFile"
  }
  "stop" {
    $name = Get-CodespaceName
    Invoke-RestMethod -Uri "https://api.github.com/user/codespaces/$name/stop" -Method Post `
      -Headers @{ Authorization = "Bearer $env:GH_TOKEN"; Accept = "application/vnd.github+json" } `
      -Body '{}' -ContentType "application/json" | Out-Null
    Write-Host "parando $name ... (deja de consumir cuota)"
  }
  "urls" {
    $name = Get-CodespaceName
    Set-PortsPublic $name
    $urls = Get-Urls $name
    $urls.GetEnumerator() | ForEach-Object { "$($_.Key) = $($_.Value)" }
  }
  "status" {
    $name = Get-CodespaceName
    & $gh codespace list --repo $Repo
  }
  "test" {
    $name = Get-CodespaceName
    Set-PortsPublic $name
    $urls = Get-Urls $name
    $key = Get-ApiKey
    foreach ($m in @("grey", "marvel")) {
      if (-not $urls[$m]) { Write-Host "$m : (sin puerto registrado)"; continue }
      try {
        $r = Invoke-RestMethod -Uri "$($urls[$m])/models" -Headers @{ Authorization = "Bearer $key" } -TimeoutSec 30
        $id = ($r.data | ForEach-Object { $_.id }) -join ", "
        $body = @{ model = "jean-$m"; messages = @(@{ role = "user"; content = "Responde solo: ok" }); max_tokens = 200 } | ConvertTo-Json -Depth 5
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $c = Invoke-RestMethod -Uri "$($urls[$m])/chat/completions" -Method Post `
          -Headers @{ Authorization = "Bearer $key"; "Content-Type" = "application/json" } `
          -Body $body -TimeoutSec 240
        $sw.Stop()
        Write-Host ("{0,-7} OK  modelo={1}  respuesta='{2}'  {3}s" -f $m, $id, $c.choices[0].message.content.Trim(), [math]::Round($sw.Elapsed.TotalSeconds, 1))
      } catch {
        Write-Host ("{0,-7} ERR {1}" -f $m, $_.Exception.Message)
      }
    }
    # sin clave debe dar 401
    try {
      Invoke-RestMethod -Uri "$($urls['grey'])/models" -TimeoutSec 15 | Out-Null
      Write-Host "SEGURIDAD: responde sin clave (mal)"
    } catch {
      Write-Host "seguridad: sin Bearer -> $($_.Exception.Response.StatusCode.value__) (401 esperado)"
    }
  }
  "fenix-mode" {
    $name = Get-CodespaceName
    Set-PortsPublic $name
    & $gh codespace ssh -c $name -- "curl -fsSL -H 'Authorization: Bearer `$GH_PAT' https://raw.githubusercontent.com/$Repo/main/.devcontainer/mode-fenix.sh | bash" 2>&1 | Select-Object -Last 2
    Write-Host "FENIX-LITE lanzando en :8890 (primera vez: descarga ~13.6 GiB)"
    Write-Host "URL: usa .\jean-api.ps1 urls (puerto 8890) | volver: .\jean-api.ps1 standard-mode"
  }
  "standard-mode" {
    $name = Get-CodespaceName
    Set-PortsPublic $name
    & $gh codespace ssh -c $name -- "curl -fsSL -H 'Authorization: Bearer `$GH_PAT' https://raw.githubusercontent.com/$Repo/main/.devcontainer/mode-standard.sh | bash" 2>&1 | Select-Object -Last 2
    Write-Host "grey + marvel de vuelta (modo estandar)"
  }
}
