using Microsoft.EntityFrameworkCore;
using ProductService.Data;
using ProductService.Models;
using ProductService.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseNpgsql(builder.Configuration.GetConnectionString("Postgres")));

builder.Services.AddMemoryCache();
builder.Services.AddStackExchangeRedisCache(opt =>
    opt.Configuration = builder.Configuration["Redis:ConnectionString"]);
builder.Services.AddScoped<ProductCacheService>();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();  // creates tables and applies seed data if not present
}

app.UseSwagger();
app.UseSwaggerUI();

app.MapGet("/products", async (ProductCacheService cache, HttpContext http) =>
{
    var (products, source) = await cache.GetAllAsync();

    var etag = $"\"{products.Max(p => p.UpdatedAt.Ticks)}\"";
    if (http.Request.Headers.IfNoneMatch == etag)
        return Results.StatusCode(304);

    http.Response.Headers.ETag = etag;
    http.Response.Headers.CacheControl = "public, max-age=30";
    http.Response.Headers["X-Cache-Layer"] = source;

    return Results.Ok(products);
});

app.MapGet("/products/{id}", async (int id, ProductCacheService cache, HttpContext http) =>
{
    var (product, source) = await cache.GetByIdAsync(id);
    if (product is null) return Results.NotFound();

    var etag = $"\"{product.UpdatedAt.Ticks}\"";
    if (http.Request.Headers.IfNoneMatch == etag)
        return Results.StatusCode(304);

    http.Response.Headers.ETag = etag;
    http.Response.Headers.CacheControl = "public, max-age=30";
    http.Response.Headers["X-Cache-Layer"] = source;

    return Results.Ok(product);
});

app.MapPost("/products", async (Product product, ProductCacheService cache) =>
{
    var created = await cache.CreateAsync(product);
    return Results.Created($"/products/{created.Id}", created);
});

app.MapPut("/products/{id}", async (int id, Product updated, ProductCacheService cache) =>
{
    var product = await cache.UpdateAsync(id, updated);
    return product is null ? Results.NotFound() : Results.Ok(product);
});

app.Run();
