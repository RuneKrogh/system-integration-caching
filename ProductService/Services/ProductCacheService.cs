using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.Memory;
using ProductService.Data;
using ProductService.Models;

namespace ProductService.Services;

public class ProductCacheService(IMemoryCache memoryCache, IDistributedCache redisCache, AppDbContext db)
{
    private static readonly TimeSpan L1Ttl = TimeSpan.FromSeconds(30);
    private static readonly TimeSpan L2Ttl = TimeSpan.FromMinutes(5);

    private const string AllProductsKey = "products:all";
    private static string ProductKey(int id) => $"products:{id}";

    public async Task<(List<Product> Products, string Source)> GetAllAsync()
    {
        if (memoryCache.TryGetValue(AllProductsKey, out List<Product>? products) && products is not null)
            return (products, "L1-Memory");

        var cached = await redisCache.GetStringAsync(AllProductsKey);
        if (cached is not null)
        {
            products = JsonSerializer.Deserialize<List<Product>>(cached)!;
            memoryCache.Set(AllProductsKey, products, L1Ttl);
            return (products, "L2-Redis");
        }

        products = await db.Products.OrderBy(p => p.Id).ToListAsync();
        await SetInBothCachesAsync(AllProductsKey, products);

        return (products, "Database");
    }

    public async Task<(Product? Product, string Source)> GetByIdAsync(int id)
    {
        var key = ProductKey(id);

        if (memoryCache.TryGetValue(key, out Product? product) && product is not null)
            return (product, "L1-Memory");

        var cached = await redisCache.GetStringAsync(key);
        if (cached is not null)
        {
            product = JsonSerializer.Deserialize<Product>(cached)!;
            memoryCache.Set(key, product, L1Ttl);
            return (product, "L2-Redis");
        }

        product = await db.Products.FindAsync(id);
        if (product is not null)
            await SetInBothCachesAsync(key, product);

        return (product, "Database");
    }

    public async Task<Product> CreateAsync(Product product)
    {
        product.UpdatedAt = DateTime.UtcNow;
        db.Products.Add(product);
        await db.SaveChangesAsync();

        await InvalidateAllAsync();
        await SetInBothCachesAsync(ProductKey(product.Id), product);

        return product;
    }

    public async Task<Product?> UpdateAsync(int id, Product updated)
    {
        var product = await db.Products.FindAsync(id);
        if (product is null) return null;

        product.Name = updated.Name;
        product.Category = updated.Category;
        product.Price = updated.Price;
        product.Stock = updated.Stock;
        product.UpdatedAt = DateTime.UtcNow;

        await db.SaveChangesAsync();

        memoryCache.Remove(ProductKey(id));
        await redisCache.RemoveAsync(ProductKey(id));
        await InvalidateAllAsync();
        await SetInBothCachesAsync(ProductKey(id), product);

        return product;
    }

    private async Task SetInBothCachesAsync<T>(string key, T value)
    {
        memoryCache.Set(key, value, L1Ttl);
        await redisCache.SetStringAsync(key, JsonSerializer.Serialize(value), new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = L2Ttl
        });
    }

    private async Task InvalidateAllAsync()
    {
        memoryCache.Remove(AllProductsKey);
        await redisCache.RemoveAsync(AllProductsKey);
    }
}
