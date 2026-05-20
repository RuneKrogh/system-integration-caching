using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using ProductService.Data;
using ProductService.Models;

namespace ProductService.Services;

public class ProductCacheService(IMemoryCache memoryCache, AppDbContext db)
{
    private static readonly TimeSpan L1Ttl = TimeSpan.FromSeconds(30);

    private const string AllProductsKey = "products:all";
    private static string ProductKey(int id) => $"products:{id}";

    public async Task<(List<Product> Products, string Source)> GetAllAsync()
    {
        if (memoryCache.TryGetValue(AllProductsKey, out List<Product>? products) && products is not null)
            return (products, "L1-Memory");

        products = await db.Products.OrderBy(p => p.Id).ToListAsync();
        memoryCache.Set(AllProductsKey, products, L1Ttl);

        return (products, "Database");
    }

    public async Task<(Product? Product, string Source)> GetByIdAsync(int id)
    {
        var key = ProductKey(id);

        if (memoryCache.TryGetValue(key, out Product? product) && product is not null)
            return (product, "L1-Memory");

        product = await db.Products.FindAsync(id);

        if (product is not null)
            memoryCache.Set(key, product, L1Ttl);

        return (product, "Database");
    }

    public async Task<Product> CreateAsync(Product product)
    {
        product.UpdatedAt = DateTime.UtcNow;
        db.Products.Add(product);
        await db.SaveChangesAsync();

        memoryCache.Remove(AllProductsKey);
        memoryCache.Set(ProductKey(product.Id), product, L1Ttl);

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
        memoryCache.Remove(AllProductsKey);
        memoryCache.Set(ProductKey(id), product, L1Ttl);

        return product;
    }
}
