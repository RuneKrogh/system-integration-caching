$GatewayUrl        = "http://localhost:8080/products"
$ProductServiceUrl = "http://localhost:5000/products"

function Request {
    param($Label)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-WebRequest -Uri $GatewayUrl -UseBasicParsing
    $sw.Stop()
    $layer = $response.Headers['X-Cache-Layer']
    Write-Host ("  {0,-12} {1,6}ms   Layer: {2}" -f $Label, $sw.ElapsedMilliseconds, $layer)
}

function Countdown {
    param($Seconds, $Message)
    Write-Host ""
    Write-Host "  $Message" -ForegroundColor Yellow
    for ($i = $Seconds; $i -gt 0; $i--) {
        Write-Host -NoNewline "`r  Waiting... $i seconds remaining   "
        Start-Sleep -Seconds 1
    }
    Write-Host "`r  Done.                              "
    Write-Host ""
}

function WaitForProductService {
    Write-Host "  Waiting for ProductService to come back up..." -ForegroundColor Yellow
    $ready = $false
    while (-not $ready) {
        try {
            Invoke-WebRequest -Uri "http://localhost:5000/swagger/index.html" -UseBasicParsing -TimeoutSec 2 | Out-Null
            $ready = $true
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    Write-Host "  ProductService is ready." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Cache Layer Demo  (all requests via gateway :8080)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# ---- Scenario 1: Cold start ----
Write-Host ""
Write-Host "Scenario 1: Cold start (all caches empty)" -ForegroundColor Green
Write-Host "------------------------------------------"
Request "Request 1"

# ---- Scenario 2: L3 gateway cache ----
Write-Host ""
Write-Host "Scenario 2: L3 gateway cache hits (within 10s)" -ForegroundColor Green
Write-Host "-----------------------------------------------"
Write-Host "  Note: header shows what ProductService used on the first fetch." -ForegroundColor DarkGray
Write-Host "        Latency drop shows the gateway is now serving from its cache." -ForegroundColor DarkGray
Request "Request 2"
Request "Request 3"
Request "Request 4"

# ---- Scenario 3: L1 memory hit ----
Countdown 10 "Waiting for gateway TTL (10s) to expire..."

Write-Host "Scenario 3: L1 in-memory cache hit (gateway miss, ProductService L1 hit)" -ForegroundColor Green
Write-Host "---------------------------------------------------------------------------"
Request "Request 5"
Request "Request 6"

# ---- Scenario 4: L2 Redis hit ----
Write-Host ""
Write-Host "  Restarting ProductService to clear L1 memory cache..." -ForegroundColor Yellow
docker compose -f "$PSScriptRoot\..\docker-compose.yml" restart productservice 2>$null
WaitForProductService
Countdown 10 "Waiting for gateway TTL (10s) to expire..."

Write-Host "Scenario 4: L2 Redis cache hit (gateway miss, L1 cleared, Redis still warm)" -ForegroundColor Green
Write-Host "----------------------------------------------------------------------------"
Request "Request 7"
Request "Request 8"

# ---- Scenario 5: Cache invalidation ----
Write-Host ""
Write-Host "  Updating product 1 to trigger cache invalidation..." -ForegroundColor Yellow
$body = '{"name":"Laptop Pro 15 (updated)","category":"Electronics","price":1199.99,"stock":40}'
Invoke-WebRequest -Uri "$ProductServiceUrl/1" -Method PUT -Body $body -ContentType "application/json" -UseBasicParsing | Out-Null
Write-Host "  Product 1 updated." -ForegroundColor DarkGray
Countdown 10 "Waiting for gateway TTL (10s) to expire..."

Write-Host "Scenario 5: After cache invalidation (PUT forces a fresh database fetch)" -ForegroundColor Green
Write-Host "--------------------------------------------------------------------------"
Request "Request 9"
Request "Request 10"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Demo complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
