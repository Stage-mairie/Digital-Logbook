param(
    [string]$DeviceId = "HA1V8Z0V",
    [switch]$Seed
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$Root = $PSScriptRoot
$BackendDir = Join-Path $Root "backend"
$EnvFile = Join-Path $BackendDir ".env"
$PgData = Join-Path $env:USERPROFILE "postgres-data"

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Fail([string]$Message) {
    Write-Host "`n[ERREUR] $Message" -ForegroundColor Red
    exit 1
}

function Add-PathIfExists([string]$PathToAdd) {
    if ((Test-Path $PathToAdd) -and (($env:Path -split ';') -notcontains $PathToAdd)) {
        $env:Path = "$PathToAdd;$env:Path"
    }
}

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "Commande '$Name' introuvable. Consulte LANCEMENT_DEV.md."
    }
}

function Read-DotEnv([string]$Path) {
    $values = @{}
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $separator = $line.IndexOf('=')
        if ($separator -lt 1) { continue }

        $key = $line.Substring(0, $separator).Trim()
        $value = $line.Substring($separator + 1).Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $values[$key] = $value
    }
    return $values
}

function Get-EnvValue($Values, [string]$Key, [string]$Default = "") {
    if ($Values.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace([string]$Values[$Key])) {
        return [string]$Values[$Key]
    }
    return $Default
}

function Test-TcpPort([string]$HostName, [int]$Port) {
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(750, $false)) {
            $client.Close()
            return $false
        }
        $client.EndConnect($async)
        $client.Close()
        return $true
    } catch {
        return $false
    }
}

# -----------------------------------------------------------------------------
# 1. Outils
# -----------------------------------------------------------------------------
Write-Step "Vérification des outils"

Add-PathIfExists (Join-Path $env:USERPROFILE "develop\flutter\bin")
Add-PathIfExists (Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools")

$pgRoot = Join-Path $env:ProgramFiles "PostgreSQL"
if (Test-Path $pgRoot) {
    $pgVersionDir = Get-ChildItem -LiteralPath $pgRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending |
        Select-Object -First 1
    if ($pgVersionDir) {
        Add-PathIfExists (Join-Path $pgVersionDir.FullName "bin")
    }
}

Require-Command "flutter"
Require-Command "node"
Require-Command "npm"
Require-Command "adb"
Require-Command "pg_ctl"
Require-Command "psql"
Require-Command "initdb"
Require-Command "createdb"
Write-Ok "Flutter, Node/npm, ADB et PostgreSQL sont disponibles."

if (-not (Test-Path -LiteralPath $EnvFile)) {
    Fail "backend\.env est absent. Copie backend\.env.development.example vers backend\.env puis renseigne VAULT_SECRET et DB_PASSWORD."
}

$dotenv = Read-DotEnv $EnvFile
$dbHost = Get-EnvValue $dotenv "DB_HOST" "127.0.0.1"
$dbPort = [int](Get-EnvValue $dotenv "DB_PORT" "5432")
$dbName = Get-EnvValue $dotenv "DB_NAME" "digital_logbook"
$dbUser = Get-EnvValue $dotenv "DB_USER" "postgres"
$dbPassword = Get-EnvValue $dotenv "DB_PASSWORD" ""
$backendPort = [int](Get-EnvValue $dotenv "PORT" "3000")
$databaseUrl = Get-EnvValue $dotenv "DATABASE_URL" ""

# -----------------------------------------------------------------------------
# 2. PostgreSQL local
# -----------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($databaseUrl) -and ($dbHost -eq "127.0.0.1" -or $dbHost -eq "localhost")) {
    Write-Step "Préparation de PostgreSQL local"

    if (-not (Test-Path -LiteralPath (Join-Path $PgData "PG_VERSION"))) {
        if ([string]::IsNullOrWhiteSpace($dbPassword)) {
            Fail "DB_PASSWORD est vide dans backend\.env. Il est nécessaire pour initialiser PostgreSQL."
        }

        Write-Host "Premier lancement : initialisation de $PgData avec locale C / UTF-8..."
        New-Item -ItemType Directory -Force -Path $PgData | Out-Null

        $pwFile = Join-Path $env:TEMP ("digital-logbook-pg-" + [guid]::NewGuid().ToString("N") + ".txt")
        try {
            Set-Content -LiteralPath $pwFile -Value $dbPassword -NoNewline -Encoding ASCII
            & initdb -D $PgData -U $dbUser --pwfile=$pwFile --locale=C --encoding=UTF8 --auth=scram-sha-256
            if ($LASTEXITCODE -ne 0) { Fail "initdb a échoué." }
        } finally {
            Remove-Item -LiteralPath $pwFile -Force -ErrorAction SilentlyContinue
        }
        Write-Ok "Cluster PostgreSQL initialisé."
    }

    if (-not (Test-TcpPort $dbHost $dbPort)) {
        Write-Host "Démarrage de PostgreSQL..."
        $pgLog = Join-Path $PgData "postgres.log"
        & pg_ctl -D $PgData -l $pgLog start | Out-Host
        if ($LASTEXITCODE -ne 0) { Fail "Impossible de démarrer PostgreSQL. Consulte $pgLog" }

        $ready = $false
        for ($i = 0; $i -lt 20; $i++) {
            if (Test-TcpPort $dbHost $dbPort) { $ready = $true; break }
            Start-Sleep -Milliseconds 500
        }
        if (-not $ready) { Fail "PostgreSQL ne répond pas sur ${dbHost}:$dbPort." }
    }
    Write-Ok "PostgreSQL répond sur ${dbHost}:$dbPort."

    if (-not [string]::IsNullOrWhiteSpace($dbPassword)) {
        $env:PGPASSWORD = $dbPassword
    }

    $escapedDbName = $dbName.Replace("'", "''")
    $dbExists = (& psql -h $dbHost -p $dbPort -U $dbUser -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$escapedDbName';" 2>$null | Out-String).Trim()
    if ($dbExists -ne "1") {
        Write-Host "Création de la base '$dbName'..."
        & createdb -h $dbHost -p $dbPort -U $dbUser $dbName
        if ($LASTEXITCODE -ne 0) { Fail "Impossible de créer la base '$dbName'." }
        Write-Ok "Base '$dbName' créée."
    } else {
        Write-Ok "Base '$dbName' déjà présente."
    }
} else {
    Write-Step "Base PostgreSQL distante/configurée"
    Write-Host "Le script ne démarre pas de PostgreSQL local (DATABASE_URL ou DB_HOST distant)."
}

# -----------------------------------------------------------------------------
# 3. Backend Node
# -----------------------------------------------------------------------------
Write-Step "Préparation du backend"

if (-not (Test-Path -LiteralPath (Join-Path $BackendDir "node_modules"))) {
    Write-Host "node_modules absent : npm install..."
    Push-Location $BackendDir
    try {
        & npm install
        if ($LASTEXITCODE -ne 0) { Fail "npm install a échoué." }
    } finally {
        Pop-Location
    }
}

Push-Location $BackendDir
try {
    & npm run db:init
    if ($LASTEXITCODE -ne 0) { Fail "npm run db:init a échoué." }

    if ($Seed) {
        & npm run db:seed-demo
        if ($LASTEXITCODE -ne 0) { Fail "npm run db:seed-demo a échoué." }
    }
} finally {
    Pop-Location
}

$healthUrl = "http://127.0.0.1:$backendPort/health"
$backendReady = $false
try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $healthUrl -TimeoutSec 2
    if ($response.StatusCode -eq 200) { $backendReady = $true }
} catch {}

if (-not $backendReady) {
    Write-Host "Démarrage du backend dans un nouveau PowerShell..."
    $backendCommand = "Set-Location -LiteralPath '$($BackendDir.Replace("'", "''"))'; npm start"
    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $backendCommand) | Out-Null

    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 500
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $healthUrl -TimeoutSec 2
            if ($response.StatusCode -eq 200) { $backendReady = $true; break }
        } catch {}
    }
}

if (-not $backendReady) {
    Fail "Le backend n'a pas répondu sur $healthUrl. Regarde le terminal backend ouvert par le script."
}
Write-Ok "Backend disponible sur http://127.0.0.1:$backendPort."

# -----------------------------------------------------------------------------
# 4. Tablette Android physique + ADB reverse
# -----------------------------------------------------------------------------
Write-Step "Détection de la tablette Android"

& adb start-server | Out-Null
$deviceLines = @(& adb devices | Select-String -Pattern '^\S+\s+device$' | ForEach-Object { $_.Line })
$connectedIds = @($deviceLines | ForEach-Object { ($_ -split '\s+')[0] })

if ($connectedIds -notcontains $DeviceId) {
    if ($connectedIds.Count -eq 1) {
        Write-Host "La tablette '$DeviceId' n'est pas trouvée ; utilisation automatique de '$($connectedIds[0])'."
        $DeviceId = $connectedIds[0]
    } elseif ($connectedIds.Count -eq 0) {
        Fail "Aucune tablette Android autorisée via ADB. Branche-la, active Débogage USB et accepte l'autorisation sur la tablette."
    } else {
        Fail "La tablette '$DeviceId' n'est pas connectée. Appareils disponibles : $($connectedIds -join ', '). Relance avec -DeviceId ID."
    }
}
Write-Ok "Tablette détectée : $DeviceId"

& adb -s $DeviceId reverse "tcp:$backendPort" "tcp:$backendPort"
if ($LASTEXITCODE -ne 0) { Fail "adb reverse a échoué pour $DeviceId." }
Write-Ok "ADB reverse configuré : tablette 127.0.0.1:$backendPort -> PC 127.0.0.1:$backendPort"

# -----------------------------------------------------------------------------
# 5. Flutter
# -----------------------------------------------------------------------------
Write-Step "Préparation et lancement Flutter"
Push-Location $Root
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { Fail "flutter pub get a échoué." }

    Write-Host "`nLancement de Digital Logbook sur $DeviceId..." -ForegroundColor Yellow
    Write-Host "Ctrl+C arrête Flutter. PostgreSQL et le terminal backend restent actifs pour le développement.`n"
    & flutter run -d $DeviceId "--dart-define=API_BASE_URL=http://127.0.0.1:$backendPort"
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
