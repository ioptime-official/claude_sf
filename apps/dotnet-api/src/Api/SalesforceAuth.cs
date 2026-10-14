using System.Net.Http.Json;
using System.Text.Json;

namespace Api;

public interface ITokenProvider
{
    /// <summary>Returns a bearer token. forceRefresh discards any cached token first.</summary>
    Task<string> GetTokenAsync(bool forceRefresh = false, CancellationToken ct = default);
}

/// <summary>Uses a pre-issued token (local debugging only). Cannot refresh.</summary>
public class StaticTokenProvider(string token) : ITokenProvider
{
    public Task<string> GetTokenAsync(bool forceRefresh = false, CancellationToken ct = default) =>
        Task.FromResult(token);
}

/// <summary>
/// OAuth 2.0 client-credentials flow against the org's My Domain. Needs a Connected /
/// External Client App with the client-credentials flow enabled and a Run-As user.
/// </summary>
public class ClientCredentialsTokenProvider(HttpClient http, string clientId, string clientSecret) : ITokenProvider
{
    private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(25);
    private readonly SemaphoreSlim gate = new(1, 1);
    private string? cached;
    private DateTimeOffset expiresAt;

    public async Task<string> GetTokenAsync(bool forceRefresh = false, CancellationToken ct = default)
    {
        await gate.WaitAsync(ct);
        try
        {
            if (!forceRefresh && cached is not null && DateTimeOffset.UtcNow < expiresAt) return cached;

            using var form = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["grant_type"] = "client_credentials",
                ["client_id"] = clientId,
                ["client_secret"] = clientSecret,
            });
            var res = await http.PostAsync("services/oauth2/token", form, ct);
            if (!res.IsSuccessStatusCode)
                throw new SalesforceException($"Token request failed with {(int)res.StatusCode}");

            var body = await res.Content.ReadFromJsonAsync<JsonElement>(ct);
            cached = body.GetProperty("access_token").GetString()
                     ?? throw new SalesforceException("Token response had no access_token");
            expiresAt = DateTimeOffset.UtcNow + Lifetime;
            return cached;
        }
        finally { gate.Release(); }
    }
}
