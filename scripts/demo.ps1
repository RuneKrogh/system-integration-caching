$ProductServiceUrl = "http://localhost:5000/products"

function Request {
    param($Label)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-WebRequest -Uri $ProductServiceUrl -UseBasicParsing
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

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Cache Layer Demo" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# ---- Scenario 1: Cold start ----
Write-Host ""
Write-Host "Scenario 1: Cold start (all caches empty)" -ForegroundColor Green
Write-Host "------------------------------------------"
Request "Request 1"

# ---- Scenario 2: L1 memory hit ----
Write-Host ""
Write-Host "Scenario 2: L1 in-memory cache hits" -ForegroundColor Green
Write-Host "------------------------------------"
Request "Request 2"
Request "Request 3"
Request "Request 4"

# ---- Scenario 3: L2 Redis hit ----
Pause "Restart ProductService to clear L1 memory cache, then press Enter.`n  Run in another terminal: docker compose restart productservice"

Write-Host "Scenario 3: L2 Redis cache hit (L1 cleared, Redis still warm)" -ForegroundColor Green
Write-Host "---------------------------------------------------------------"
Request "Request 5"
Request "Request 6"
Request "Request 7"

# ---- Scenario 4: Cache invalidation ----
Pause "Now update a product to see cache invalidation.`n  Use Swagger at http://localhost:5000/swagger to PUT /products/1, then press Enter."

Write-Host "Scenario 4: After cache invalidation (PUT forces fresh DB fetch)" -ForegroundColor Green
Write-Host "----------------------------------------------------------------"
Request "Request 8"
Request "Request 9"
Request "Request 10"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Demo complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
