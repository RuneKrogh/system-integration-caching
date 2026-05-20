var builder = WebApplication.CreateBuilder(args);

builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

builder.Services.AddOutputCache(options =>
{
    options.AddPolicy("gateway-cache", policy =>
        policy.Expire(TimeSpan.FromSeconds(10)));
});

var app = builder.Build();

app.UseOutputCache();

app.MapReverseProxy().CacheOutput("gateway-cache");

app.Run();
