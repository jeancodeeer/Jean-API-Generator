<#
.SYNOPSIS
    Generador de APIs Jean v0.7 por terminal - todo local, nada en GitHub.

.DESCRIPTION
    Descarga los modelos del repo PUBLICO de HuggingFace (JeanCoder/jean-models,
    base de Fenix desde unsloth) y levanta un llama-server compatible con OpenAI
    en 127.0.0.1. NO contiene URLs ni claves: cada API se genera con SU PROPIA
    clave (auto-generada si no se pasa --api-key).

.EXAMPLE
    .\jean-api-generator.ps1 -Model grey                 # clave auto-generada
    .\jean-api-generator.ps1 -Model marvel -Port 8889 -ApiKey "mi-clave"
    .\jean-api-generator.ps1 -Model fenix                # archivo UNICO mergeado
    .\jean-api-generator.ps1 -Model fenix -Lora          # modo ligero base+LoRA
    .\jean-api-generator.ps1 -Status                     # APIs corriendo
    .\jean-api-generator.ps1 -Stop -Port 8888            # detener una API
    .\jean-api-generator.ps1 -List                       # modelos disponibles
#>

param(
    [ValidateSet("grey", "marvel", "fenix")]
    [string]$Model = "grey",

    [int]$Port = 0,                    # 0 = puerto por defecto del modelo

    [string]$ApiKey = "",              # vacio = se genera una aleatoria

    [ValidateRange(1, 16)]
    [int]$Threads = 4,

    [int]$Ctx = 0,                     # 0 = default del modelo

    [string]$HfToken = "",             # opcional; el repo ya es publico

    [switch]$Lora,                     # fenix: base+LoRA en vez del merge unico

    [switch]$Stop,

    [switch]$Status,

    [switch]$List
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CacheDir  = Join-Path $ScriptDir "gguf"
$DownDir   = Join-Path $ScriptDir "down"
$LogDir    = Join-Path $ScriptDir "logs"

# ---------------------------------------------------------------------------
# Catalogo de modelos (todo PUBLICO en HF ahora)
# ---------------------------------------------------------------------------
$MODELS = @{
    grey = @{
        file = "jean-grey-v0.7.Q4_K_M.gguf";   gb = 2.52; ctx = 131072; port = 8888
        repo = "JeanCoder/jean-models"
    }
    marvel = @{
        file = "jean-marvel-v0.7.Q4_K_M.gguf"; gb = 4.06; ctx = 131072;  port = 8889
        repo = "JeanCoder/jean-models"
    }
    fenix = @{
        # por defecto: archivo UNICO mergeado (17.7 GB)
        file = "jean-fenix-v0.7.Q4_K_M.gguf";  gb = 16.5; ctx = 4096;  port = 8890
        repo = "JeanCoder/jean-models"
        # modo -Lora: base publica + adapter ligero
        baseRepo = "unsloth/Qwen3.5-27B-GGUF"
        baseFile = "Qwen3.5-27B-Q4_K_M.gguf"
        loraFile = "jean-fenix-v0.7.lora.gguf"
    }
}

function Log([string]$Msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] $Msg"
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    Add-Content -Path (Join-Path $LogDir "generator.log") -Value "$ts $Msg" -Encoding UTF8
}

function Get-ServerProc {
    Get-CimInstance Win32_Process -Filter "Name='llama-server.exe'" -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- acciones ---
if ($List) {
    Write-Host "modelos disponibles (HF publico JeanCoder/jean-models):"
    foreach ($k in @("grey", "marvel", "fenix")) {
        $m = $MODELS[$k]
        $nota = ""
        if ($k -eq "fenix") { $nota = "  (RAM >= 32 GB obligatoria; -Lora = variante ligera)" }
        Write-Host ("  {0,-7} {1,6:N2} GB  ctx {2,6}  puerto {3}{4}" -f $k, $m.gb, $m.ctx, $m.port, $nota)
    }
    return
}

if ($Status) {
    $procs = Get-ServerProc
    if (-not $procs) { Write-Host "no hay APIs Jean corriendo"; return }
    foreach ($p in $procs) {
        $prt = "?"; $mdl = "?"
        if ($p.CommandLine -match "--port (\d+)") { $prt = $Matches[1] }
        if ($p.CommandLine -match "--alias jean-(\w+)") { $mdl = $Matches[1] }
        Write-Host ("PID {0}  puerto {1}  jean-{2}" -f $p.ProcessId, $prt, $mdl)
    }
    return
}

if ($Stop) {
    if ($Port -eq 0) { throw "indica el puerto: -Stop -Port 8888" }
    $procs = Get-ServerProc | Where-Object { $_.CommandLine -match "--port $Port\b" }
    if (-not $procs) { Write-Host "no hay proceso en el puerto $Port"; return }
    foreach ($p in $procs) {
        Stop-Process -Id $p.ProcessId -Force
        Log "detenida API en puerto $Port (PID $($p.ProcessId))"
    }
    return
}

# ---------------------------------------------------------------- descarga ---
function Get-HfFile {
    param([string]$Repo, [string]$File, [string]$Dest, [string]$Token)
    if ((Test-Path $Dest) -and ((Get-Item $Dest).Length -gt 1MB)) {
        Log "cache: $File ya esta en $Dest"
        return
    }
    $url = "https://huggingface.co/$Repo/resolve/main/$File"
    Log "descargando $Repo/$File ..."
    $auth = @()
    if ($Token) { $auth = @("-H", "Authorization: Bearer $Token") }
    $tmp = "$Dest.part"
    & curl.exe -fL --retry 3 --retry-delay 2 -C - @auth $url -o $tmp
    if ($LASTEXITCODE -ne 0) {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        throw "descarga fallo: $url"
    }
    Move-Item $tmp $Dest -Force
}

function Get-LlamaServer {
    # 1) binario ya presente en el PC (ruta conocida o busqueda)
    $known = "D:\jean-work\fenix-gguf\llama-b12032\llama-server.exe"
    if (Test-Path $known) { Log "llama-server local: $known"; return $known }
    foreach ($root in @("D:\jean-work", "G:\LIFE IN DANGER\tools\llama.cpp", "$env:USERPROFILE\llama")) {
        if (Test-Path $root) {
            $hit = Get-ChildItem $root -Filter "llama-server.exe" -Recurse -File `
                   -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hit) { Log "llama-server local: $($hit.FullName)"; return $hit.FullName }
        }
    }
    # 2) release oficial de Windows (CPU)
    Log "no hay llama-server local; descargando release win-cpu-x64 ..."
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=5"
    $asset = $null
    foreach ($r in $rel) {
        $asset = $r.assets | Where-Object { $_.name -match "bin-win-cpu-x64\.zip$" } | Select-Object -First 1
        if ($asset) { break }
    }
    if (-not $asset) { throw "no encontre binario win-cpu-x64 en los releases" }
    if (-not (Test-Path $DownDir)) { New-Item -ItemType Directory -Path $DownDir -Force | Out-Null }
    $zip = Join-Path $DownDir $asset.name
    if (-not (Test-Path $zip)) {
        & curl.exe -fL --retry 3 $asset.browser_download_url -o $zip
        if ($LASTEXITCODE -ne 0) { throw "descarga de llama.cpp fallo" }
    }
    $destDir = Join-Path $env:USERPROFILE "llama\win-cpu"
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Expand-Archive -Path $zip -DestinationPath $destDir -Force
    }
    $exe = Get-ChildItem $destDir -Filter "llama-server.exe" -Recurse -File | Select-Object -First 1
    if (-not $exe) { throw "llama-server.exe no aparecio tras expandir" }
    return $exe.FullName
}

# ------------------------------------------------------------------- main ----
$m = $MODELS[$Model]
if ($Port -eq 0) { $Port = $m.port }
if ($Ctx  -eq 0) { $Ctx  = $m.ctx }

# contexto RAM-aware: 128k solo con RAM de sobra (KV q8_0 ~2 GiB a 128k)
if ($Model -ne "fenix" -and $Ctx -ge 131072) {
    $ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    if ($ramGb -lt 12) { $Ctx = 8192 }
    elseif ($ramGb -lt 20) { $Ctx = 65536 }
}

if ($Model -eq "fenix") {
    $ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    if ($ramGb -lt 30) {
        throw ("Fenix (27B) necesita >= 32 GB de RAM; este PC tiene {0} GB. " -f $ramGb +
               "Usa grey o marvel aqui; Fenix corre en una maquina grande " +
               "(o un Codespace premiumLinux de 32 GB).")
    }
}

if (-not $ApiKey) {
    # clave aleatoria propia de ESTA instancia (nada compartido)
    $b = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($b)
    $rng.Dispose()
    $ApiKey = [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '').Replace('/', '')
    Log "API key auto-generada para esta instancia"
}

foreach ($d in @($CacheDir, $DownDir, $LogDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$exe = Get-LlamaServer

# descargas
$loraPath = $null
if ($Model -eq "fenix" -and $Lora) {
    $basePath = Join-Path $CacheDir $m.baseFile
    Get-HfFile -Repo $m.baseRepo -File $m.baseFile -Dest $basePath -Token ""
    $loraPath = Join-Path $CacheDir $m.loraFile
    Get-HfFile -Repo "JeanCoder/jean-models" -File $m.loraFile -Dest $loraPath -Token $HfToken
    $modelPath = $basePath
} else {
    $modelPath = Join-Path $CacheDir $m.file
    Get-HfFile -Repo $m.repo -File $m.file -Dest $modelPath -Token $HfToken
}

# clave persistida junto al resto de artefactos locales (no se sube a ningun repo)
$keyFile = Join-Path $ScriptDir ("key-{0}.txt" -f $Port)
[IO.File]::WriteAllText($keyFile, $ApiKey)

# lanzar servidor (solo localhost: la API es de quien la genera)
$serverArgs = @(
    "-m", $modelPath,
    "--host", "127.0.0.1",
    "--port", "$Port",
    "--alias", "jean-$Model",
    "-c", "$Ctx",
    "--threads", "$Threads",
    "-ctk", "q8_0", "-ctv", "q8_0",
    "--temp", "0.2",
    "--top-p", "0.9",
    "--api-key", $ApiKey
)
if ($loraPath) { $serverArgs += @("--lora", $loraPath) }

$outLog = Join-Path $LogDir ("jean-{0}-{1}.out.log" -f $Model, $Port)
$errLog = Join-Path $LogDir ("jean-{0}-{1}.err.log" -f $Model, $Port)

Log ("lanzando jean-{0} en http://127.0.0.1:{1} (ctx {2}, {3} hilos)" -f $Model, $Port, $Ctx, $Threads)
$proc = Start-Process -FilePath $exe -ArgumentList $serverArgs -NoNewWindow `
        -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
Start-Sleep -Seconds 2
try { $proc.PriorityClass = 'BelowNormal' } catch { }

# esperar a que cargue
Log "esperando a que el modelo cargue ..."
$ok = $false
for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 5
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:$Port/v1/models" `
            -Headers @{ Authorization = "Bearer $ApiKey" } -TimeoutSec 5 | Out-Null
        $ok = $true
        break
    } catch { }
}
if (-not $ok) {
    Log "el servidor no respondio; mira $errLog"
    throw "no se pudo levantar la API en el puerto $Port"
}

Write-Host ""
Write-Host "=== API Jean-$Model LISTA ==="
Write-Host "  URL     : http://127.0.0.1:$Port/v1"
Write-Host "  API key : $ApiKey   (guardada en $keyFile)"
Write-Host "  PID     : $($proc.Id)  (prioridad baja)"
Write-Host ""
$curlEj = 'curl http://127.0.0.1:' + $Port + '/v1/chat/completions -H "Authorization: Bearer <clave>"' + ' -H "Content-Type: application/json" -d ''{"model":"jean-' + $Model + '","messages":[{"role":"user","content":"hola"}]}'''
Write-Host "prueba:"
Write-Host "  $curlEj"
Write-Host ""
Write-Host "detener:  .\jean-api-generator.ps1 -Stop -Port $Port"
