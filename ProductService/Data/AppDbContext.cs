using Microsoft.EntityFrameworkCore;
using ProductService.Models;

namespace ProductService.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Product> Products => Set<Product>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var seed = new DateTime(2025, 1, 1, 0, 0, 0, DateTimeKind.Utc);

        modelBuilder.Entity<Product>().HasData(
            new Product { Id = 1,  Name = "Laptop Pro 15",       Category = "Electronics", Price = 1299.99m, Stock = 45,  UpdatedAt = seed },
            new Product { Id = 2,  Name = "Wireless Mouse",       Category = "Electronics", Price = 29.99m,   Stock = 200, UpdatedAt = seed },
            new Product { Id = 3,  Name = "Mechanical Keyboard",  Category = "Electronics", Price = 89.99m,   Stock = 150, UpdatedAt = seed },
            new Product { Id = 4,  Name = "USB-C Hub",            Category = "Electronics", Price = 49.99m,   Stock = 300, UpdatedAt = seed },
            new Product { Id = 5,  Name = "Monitor 27\"",         Category = "Electronics", Price = 399.99m,  Stock = 60,  UpdatedAt = seed },
            new Product { Id = 6,  Name = "Running Shoes",        Category = "Sports",      Price = 119.99m,  Stock = 80,  UpdatedAt = seed },
            new Product { Id = 7,  Name = "Yoga Mat",             Category = "Sports",      Price = 34.99m,   Stock = 120, UpdatedAt = seed },
            new Product { Id = 8,  Name = "Water Bottle",         Category = "Sports",      Price = 19.99m,   Stock = 500, UpdatedAt = seed },
            new Product { Id = 9,  Name = "Coffee Maker",         Category = "Kitchen",     Price = 79.99m,   Stock = 90,  UpdatedAt = seed },
            new Product { Id = 10, Name = "Blender Pro",          Category = "Kitchen",     Price = 59.99m,   Stock = 75,  UpdatedAt = seed }
        );
    }
}
