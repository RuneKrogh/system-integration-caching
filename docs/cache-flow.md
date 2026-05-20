# Cache Flow Diagrams

Each diagram shows exactly which components are involved for a given cache state.

---

## Scenario 1: Cold start

All caches are empty. The request travels all the way through every layer down to PostgreSQL.

```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gateway (L3, 10s)
    participant P as ProductService
    participant R as Redis (L2, 5min)
    participant DB as PostgreSQL

    C->>G: GET /products
    G->>G: Miss (cold)
    G->>P: Forward request
    P->>P: L1 miss (cold)
    P->>R: GET products:all
    R->>P: Miss (cold)
    P->>DB: SELECT * FROM Products
    DB->>P: 10 rows (~45ms)
    P->>P: Store in L1 (30s TTL)
    P->>R: Store in Redis (5min TTL)
    P->>G: 200 OK  X-Cache-Layer: Database
    G->>G: Store in output cache (10s TTL)
    G->>C: 200 OK
```

---

## Scenario 2: Gateway cache hit

A request comes in within 10 seconds of the previous one. The gateway returns its cached response without involving ProductService at all.

```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gateway (L3, 10s)
    participant P as ProductService
    participant R as Redis (L2, 5min)
    participant DB as PostgreSQL

    C->>G: GET /products
    G->>G: Hit! (~0.2ms)
    G->>C: 200 OK (cached)

    note over P,DB: ProductService, Redis and PostgreSQL are never involved
```

---

## Scenario 3: L1 memory cache hit

The gateway TTL has expired (10s passed) but ProductService still has the data in memory (within 30s). The request reaches ProductService but stops there.

```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gateway (L3, 10s)
    participant P as ProductService
    participant R as Redis (L2, 5min)
    participant DB as PostgreSQL

    C->>G: GET /products
    G->>G: Miss (TTL expired)
    G->>P: Forward request
    P->>P: L1 hit! (~0.5ms)
    P->>G: 200 OK  X-Cache-Layer: L1-Memory
    G->>G: Store in output cache (10s TTL)
    G->>C: 200 OK

    note over R,DB: Redis and PostgreSQL are never involved
```

---

## Scenario 4: L2 Redis cache hit

L1 memory has expired (30s passed) but Redis still has the data (within 5min). ProductService repopulates L1 from Redis, no database call needed.

```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gateway (L3, 10s)
    participant P as ProductService
    participant R as Redis (L2, 5min)
    participant DB as PostgreSQL

    C->>G: GET /products
    G->>G: Miss (TTL expired)
    G->>P: Forward request
    P->>P: L1 miss (TTL expired)
    P->>R: GET products:all
    R->>P: Hit! (~3ms)
    P->>P: Repopulate L1 (30s TTL)
    P->>G: 200 OK  X-Cache-Layer: L2-Redis
    G->>G: Store in output cache (10s TTL)
    G->>C: 200 OK

    note over DB: PostgreSQL is never involved
```

---

## Cache invalidation on update

When a product is updated via PUT, both L1 and L2 are invalidated immediately so the next request gets fresh data.

```mermaid
sequenceDiagram
    participant C as Client
    participant P as ProductService
    participant R as Redis (L2, 5min)
    participant DB as PostgreSQL

    C->>P: PUT /products/1
    P->>DB: UPDATE Products SET ...
    DB->>P: OK
    P->>P: Remove product:1 and products:all from L1
    P->>R: Remove product:1 and products:all from Redis
    P->>P: Store updated product in L1 (30s TTL)
    P->>R: Store updated product in Redis (5min TTL)
    P->>C: 200 OK (updated product)
```
