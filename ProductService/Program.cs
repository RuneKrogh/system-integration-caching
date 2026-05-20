using Microsoft.EntityFrameworkCore;
using ProductService.Data;
using ProductService.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseNpgsql(builder.Configuration.GetConnectionString("Postgres")));

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    db.Database.EnsureCreated();  // creates tables and applies seed data if not present
}

app.UseSwagger();
app.UseSwaggerUI();

app.MapGet("/products", async (AppDbContext db) =>
{
    var products = await db.Products.OrderBy(p => p.Id).ToListAsync();
    return Results.Ok(products);
});

app.MapGet("/products/{id}", async (int id, AppDbContext db) =>
{
    var product = await db.Products.FindAsync(id);
    return product is null ? Results.NotFound() : Results.Ok(product);
});

app.MapPost("/products", async (Product product, AppDbContext db) =>
{
    product.UpdatedAt = DateTime.UtcNow;
    db.Products.Add(product);
    await db.SaveChangesAsync();
    return Results.Created($"/products/{product.Id}", product);
});

app.MapPut("/products/{id}", async (int id, Product updated, AppDbContext db) =>
{
    var product = await db.Products.FindAsync(id);
    if (product is null) return Results.NotFound();

    product.Name = updated.Name;
    product.Category = updated.Category;
    product.Price = updated.Price;
    product.Stock = updated.Stock;
    product.UpdatedAt = DateTime.UtcNow;

    await db.SaveChangesAsync();
    return Results.Ok(product);
});

app.Run();
