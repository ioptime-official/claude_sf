using Api;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.WithOrigins(builder.Configuration["AllowedOrigin"] ?? "http://localhost:5173")
     .AllowAnyHeader().AllowAnyMethod()));

// Salesforce settings come from environment variables or a secret store, never source:
//   SF_INSTANCE_URL (My Domain), and either SF_CLIENT_ID + SF_CLIENT_SECRET (preferred)
//   or SF_ACCESS_TOKEN (local debugging only).
var instanceUrl = new Uri(builder.Configuration["SF_INSTANCE_URL"] ?? "https://salesforce.invalid/");

builder.Services.AddSingleton<ITokenProvider>(_ =>
{
    var clientId = builder.Configuration["SF_CLIENT_ID"];
    var clientSecret = builder.Configuration["SF_CLIENT_SECRET"];
    if (!string.IsNullOrEmpty(clientId) && !string.IsNullOrEmpty(clientSecret))
        return new ClientCredentialsTokenProvider(new HttpClient { BaseAddress = instanceUrl }, clientId, clientSecret);

    return new StaticTokenProvider(builder.Configuration["SF_ACCESS_TOKEN"] ?? "");
});
builder.Services.AddHttpClient<ISalesforceClient, SalesforceClient>(c => c.BaseAddress = instanceUrl);

var app = builder.Build();
app.UseCors();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapGet("/api/rating", (decimal revenue) =>
    revenue < 0
        ? Results.BadRequest(new { error = "revenue must be >= 0" })
        : Results.Ok(new { revenue, rating = RatingService.Rate(revenue) }));

app.MapPost("/api/accounts", async (CreateAccountRequest request, ISalesforceClient salesforce, CancellationToken ct) =>
{
    var errors = AccountValidation.Validate(request);
    if (errors.Count > 0) return Results.BadRequest(new { errors });

    try
    {
        var created = await salesforce.CreateAccountAsync(request, ct);
        return Results.Created($"/api/accounts/{created.Id}", created);
    }
    catch (SalesforceException ex)
    {
        return Results.Problem(ex.Message, statusCode: StatusCodes.Status502BadGateway);
    }
});

app.Run();

public partial class Program;
