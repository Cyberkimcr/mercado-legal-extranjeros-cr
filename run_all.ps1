# =====================================================================================
# run_all.ps1: reconstruye todo en Windows (extracción -> validación -> PostgreSQL)
# Uso (desde la carpeta del proyecto, en PowerShell):
#   powershell -ExecutionPolicy Bypass -File .\run_all.ps1
#   powershell -ExecutionPolicy Bypass -File .\run_all.ps1 -Db mi_base -User postgres
# =====================================================================================
param(
    [string]$Db   = "mercado_legal",
    [string]$User = "postgres"
)
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot
$env:PYTHONUTF8 = "1"          # evita problemas de acentos en la consola de Windows
$env:PGCLIENTENCODING = "UTF8"

# Verifica que psql esté disponible (viene con el instalador de PostgreSQL)
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    Write-Host "No encuentro 'psql'. Agrega la carpeta bin de PostgreSQL al PATH, por ejemplo:" -ForegroundColor Yellow
    Write-Host '  $env:Path += ";C:\Program Files\PostgreSQL\16\bin"' -ForegroundColor Yellow
    exit 1
}

# Pide la contraseña del usuario de PostgreSQL una sola vez
$sec = Read-Host "Contraseña de PostgreSQL para el usuario '$User'" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$env:PGUSER = $User

function Run($cmd, $argList) {
    & $cmd @argList
    if ($LASTEXITCODE -ne 0) { throw "Falló: $cmd $($argList -join ' ')" }
}

Write-Host "== Extracción y validación (Python)" -ForegroundColor Cyan
Run python @("scripts/extract_ict.py")
Run python @("scripts/extract_dgme.py")
Run python @("scripts/build_paises.py")

Write-Host "== Base de datos '$Db'" -ForegroundColor Cyan
& createdb $Db 2>$null   # si ya existe, sigue adelante

foreach ($f in @("sql/01_schema.sql", "sql/02_load.sql", "sql/03_transform.sql", "sql/04_quality_checks.sql", "sql/05_views.sql")) {
    Write-Host "== $f" -ForegroundColor Cyan
    Run psql @("-q", "-v", "ON_ERROR_STOP=1", "-d", $Db, "-f", $f)
}

Remove-Item Env:PGPASSWORD
Write-Host "Listo. Consultas de negocio:  psql -U $User -d $Db -f sql/06_analysis.sql" -ForegroundColor Green
