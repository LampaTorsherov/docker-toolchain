$ErrorActionPreference = 'Stop'
$bin = 'C:\pgsql\bin'
$data = $env:PGDATA
$user = $env:POSTGRES_USER
$db = $env:POSTGRES_DB
if ([string]::IsNullOrWhiteSpace($data)) { throw 'PGDATA is required' }
if ([string]::IsNullOrWhiteSpace($user)) { $user = 'postgres' }
if ([string]::IsNullOrWhiteSpace($db)) { $db = $user }
$serverArgs = @($args)
$major = ($env:PG_VERSION -split '\.')[0]
$versionFile = Join-Path $data 'PG_VERSION'

function Invoke-Pg {
    param([string] $Exe, [string[]] $ArgList)
    & (Join-Path $bin $Exe) @ArgList
    if ($LASTEXITCODE -ne 0) { throw "$Exe failed (exit $LASTEXITCODE)" }
}

# Put the marker outside PGDATA so initdb sees an empty directory.
$marker = "$data.docker-init-in-progress"
if (Test-Path -LiteralPath $marker) {
    throw "An earlier initialization was interrupted. Inspect $data and $marker before retrying. No data will be removed automatically."
}

if (Test-Path -LiteralPath $versionFile -PathType Leaf) {
    $existing = (Get-Content -LiteralPath $versionFile -Raw).Trim()
    if ($existing -ne $major) { throw "PGDATA contains PostgreSQL $existing, image is $major" }
} else {
    if ([string]::IsNullOrEmpty($env:POSTGRES_PASSWORD)) { throw 'POSTGRES_PASSWORD is required for initialization' }
    if ($env:POSTGRES_PASSWORD -match '[\r\n]') { throw 'POSTGRES_PASSWORD must not contain a newline' }
    New-Item -ItemType Directory -Path $data -Force | Out-Null
    if (@(Get-ChildItem -LiteralPath $data -Force).Count -ne 0) { throw "PGDATA is not empty and has no PG_VERSION: $data" }
    New-Item -ItemType File -Path $marker | Out-Null
    $pwFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($pwFile, $env:POSTGRES_PASSWORD, (New-Object System.Text.UTF8Encoding($false)))
        Invoke-Pg 'initdb.exe' @('-D', $data, '-U', $user, '--encoding=UTF8', '--locale=C', '--auth=scram-sha-256', "--pwfile=$pwFile")
    } finally { Remove-Item -LiteralPath $pwFile -Force }

    if ($db -cnotin @('postgres', 'template0', 'template1')) {
        $tempLog = [System.IO.Path]::GetTempFileName()
        $savedPassword = $env:PGPASSWORD
        $started = $false
        try {
            Invoke-Pg 'pg_ctl.exe' @('start', '-D', $data, '-w', '-t', '60', '-l', $tempLog, '-o', '-h 127.0.0.1 -p 5432')
            $started = $true
            $env:PGPASSWORD = $env:POSTGRES_PASSWORD
            Invoke-Pg 'createdb.exe' @('-h', '127.0.0.1', '-p', '5432', '-U', $user, '--maintenance-db=postgres', '--', $db)
        } finally {
            $env:PGPASSWORD = $savedPassword
            if ($started) { Invoke-Pg 'pg_ctl.exe' @('stop', '-D', $data, '-m', 'fast', '-w', '-t', '60') }
            if (Test-Path -LiteralPath $tempLog) {
                Get-Content -LiteralPath $tempLog
                Remove-Item -LiteralPath $tempLog -Force
            }
        }
    }
    Add-Content -LiteralPath (Join-Path $data 'pg_hba.conf') -Encoding ASCII -Value "`r`nhost all all all scram-sha-256"
    Remove-Item -LiteralPath $marker -Force
}

& (Join-Path $bin 'postgres.exe') '-D' $data '-c' 'listen_addresses=*' @serverArgs
exit $LASTEXITCODE
