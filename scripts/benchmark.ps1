param(
    [int]$Runs = 10
)

$GatewayUrl        = "http://localhost:8080/products"
$ProductServiceUrl = "http://localhost:5000/products"
$ComposeFile       = "$PSScriptRoot\..\docker-compose.yml"

function Measure-Request {
    param($Url = $GatewayUrl)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-WebRequest -Uri $Url -UseBasicParsing | Out-Null
    $sw.Stop()
    return $sw.ElapsedMilliseconds
}

function Reset-State {
    docker exec system-integration-caching-redis-1 redis-cli FLUSHALL | Out-Null
    docker compose -f $ComposeFile restart productservice 2>$null
    $ready = $false
    while (-not $ready) {
        try {
            Invoke-WebRequest -Uri "http://localhost:5000/swagger/index.html" -UseBasicParsing -TimeoutSec 2 | Out-Null
            $ready = $true
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    Start-Sleep -Seconds 11
}

function Wait-GatewayTtl {
    Start-Sleep -Seconds 11
}

$results = [ordered]@{
    "Cold start (Database)"   = [System.Collections.Generic.List[long]]::new()
    "Gateway cache (L3)"      = [System.Collections.Generic.List[long]]::new()
    "L1 memory cache"         = [System.Collections.Generic.List[long]]::new()
    "L2 Redis cache"          = [System.Collections.Generic.List[long]]::new()
    "After invalidation (DB)" = [System.Collections.Generic.List[long]]::new()
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ("  Cache Benchmark  [{0} runs]" -f $Runs) -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

for ($run = 1; $run -le $Runs; $run++) {

    Write-Host ("  Run {0}/{1} - resetting state..." -f $run, $Runs) -ForegroundColor Yellow
    Reset-State

    # Scenario 1: Cold start
    Write-Host -NoNewline ("`r  Run {0}/{1} - cold start...              " -f $run, $Runs)
    $results["Cold start (Database)"].Add((Measure-Request))

    # Scenario 2: Gateway cache
    Write-Host -NoNewline ("`r  Run {0}/{1} - gateway cache...           " -f $run, $Runs)
    Measure-Request | Out-Null
    $results["Gateway cache (L3)"].Add((Measure-Request))

    # Scenario 3: L1 memory
    Write-Host -NoNewline ("`r  Run {0}/{1} - waiting for L1...          " -f $run, $Runs)
    Wait-GatewayTtl
    $results["L1 memory cache"].Add((Measure-Request))

    # Scenario 4: L2 Redis
    Write-Host -NoNewline ("`r  Run {0}/{1} - restarting for L2...       " -f $run, $Runs)
    docker compose -f $ComposeFile restart productservice 2>$null
    $ready = $false
    while (-not $ready) {
        try {
            Invoke-WebRequest -Uri "http://localhost:5000/swagger/index.html" -UseBasicParsing -TimeoutSec 2 | Out-Null
            $ready = $true
        } catch { Start-Sleep -Seconds 1 }
    }
    Wait-GatewayTtl
    $results["L2 Redis cache"].Add((Measure-Request))

    # Scenario 5: Cache invalidation
    Write-Host -NoNewline ("`r  Run {0}/{1} - invalidating cache...      " -f $run, $Runs)
    $body = '{"name":"Laptop Pro 15","category":"Electronics","price":1299.99,"stock":45}'
    Invoke-WebRequest -Uri "$ProductServiceUrl/1" -Method PUT -Body $body -ContentType "application/json" -UseBasicParsing | Out-Null
    Wait-GatewayTtl
    $results["After invalidation (DB)"].Add((Measure-Request))

    Write-Host ("`r  Run {0}/{1} - done.                       " -f $run, $Runs) -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ("  Results [{0} runs]" -f $Runs) -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host ("  {0,-28} {1,10} {2,10} {3,10}" -f "Scenario", "Avg (ms)", "Min (ms)", "Max (ms)")
Write-Host ("  {0,-28} {1,10} {2,10} {3,10}" -f "--------", "--------", "--------", "--------")

foreach ($scenario in $results.Keys) {
    $values = $results[$scenario]
    $avg = [math]::Round(($values | Measure-Object -Average).Average, 1)
    $min = ($values | Measure-Object -Minimum).Minimum
    $max = ($values | Measure-Object -Maximum).Maximum
    Write-Host ("  {0,-28} {1,10} {2,10} {3,10}" -f $scenario, $avg, $min, $max)
}

Write-Host ""
Write-Host "  Note: numbers include Docker for Windows networking overhead." -ForegroundColor DarkGray
Write-Host "  Relative differences between layers reflect real-world behavior." -ForegroundColor DarkGray
Write-Host ""
