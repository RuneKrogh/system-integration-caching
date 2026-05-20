$GatewayUrl = "http://localhost:8080/products"

function Request {
    param($Label)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-WebRequest -Uri $GatewayUrl -UseBasicParsing
    $sw.Stop()
    $layer = $response.Headers['X-Cache-Layer']
    Write-Host ("  {0,-12} {1,6}ms   Layer: {2}" -f $Label, $sw.ElapsedMilliseconds, $layer)
}

function Pause {
    param($Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    Read-Host "  Press Enter to continue"
    Write-Host ""
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
Pause "Restart ProductService to clear L1, then press Enter.`n  Run in another terminal: docker compose restart productservice"
Countdown 10 "Waiting for gateway TTL (10s) to expire..."

Write-Host "Scenario 4: L2 Redis cache hit (gateway miss, L1 cleared, Redis still warm)" -ForegroundColor Green
Write-Host "----------------------------------------------------------------------------"
Request "Request 7"
Request "Request 8"

# ---- Scenario 5: Cache invalidation ----
Pause "Update a product to trigger cache invalidation.`n  Use Swagger at http://localhost:5000/swagger to PUT /products/1, then press Enter."
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
