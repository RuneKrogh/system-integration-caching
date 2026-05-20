# System Integration — Edge Caching and Performance

A .NET 8 microservices demo showing multi-layer caching in a product catalogue system.

## Projects

| Project | Description |
|---------|-------------|
| `ProductService` | ASP.NET Core Web API serving product data |
| `ApiGateway` | YARP reverse proxy with L3 output cache in front of ProductService |

## Running

```bash
docker compose up --build
```

| Endpoint | URL |
|----------|-----|
| Swagger UI | http://localhost:5000/swagger |
| Gateway | http://localhost:8080/products |

## Cache layers

| Layer | Technology | TTL |
|-------|-----------|-----|
| L3 | YARP Output Cache (ApiGateway) | 10 s |
| L1 | ASP.NET Core IMemoryCache (ProductService) | 30 s |
| L2 | Redis IDistributedCache (ProductService) | 5 min |
| Database | PostgreSQL | source of truth |

## Cache observability

GET responses include an `X-Cache-Layer` header showing which layer served the request: `L1-Memory`, `L2-Redis`, or `Database`.
