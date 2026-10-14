using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace Api;

public record CreateAccountRequest(string? Name, decimal AnnualRevenue);
public record CreateAccountResult(string Id);

public class SalesforceException(string message) : Exception(message);

public interface ISalesforceClient
{
    Task<CreateAccountResult> CreateAccountAsync(CreateAccountRequest request, CancellationToken ct = default);
}

/// <summary>Creates Accounts through the Salesforce REST API, refreshing the token once on 401.</summary>
public class SalesforceClient(HttpClient http, ITokenProvider tokens) : ISalesforceClient
{
    public const string ApiVersion = "v62.0";

    // Salesforce field API names are PascalCase (Name, AnnualRevenue); do not camel-case them.
    private static readonly JsonSerializerOptions SalesforceJson = new() { PropertyNamingPolicy = null };

    public async Task<CreateAccountResult> CreateAccountAsync(CreateAccountRequest request, CancellationToken ct = default)
    {
        var res = await PostAccountAsync(request, forceRefresh: false, ct);
        if (res.StatusCode == HttpStatusCode.Unauthorized)
            res = await PostAccountAsync(request, forceRefresh: true, ct);

        if (!res.IsSuccessStatusCode)
        {
            var detail = await res.Content.ReadAsStringAsync(ct);
            throw new SalesforceException($"Salesforce returned {(int)res.StatusCode}: {detail}");
        }

        var body = await res.Content.ReadFromJsonAsync<JsonElement>(ct);
        return new CreateAccountResult(body.GetProperty("id").GetString()!);
    }

    private async Task<HttpResponseMessage> PostAccountAsync(CreateAccountRequest request, bool forceRefresh, CancellationToken ct)
    {
        var token = await tokens.GetTokenAsync(forceRefresh, ct);
        using var msg = new HttpRequestMessage(HttpMethod.Post, $"services/data/{ApiVersion}/sobjects/Account")
        {
            Content = JsonContent.Create(new { Name = request.Name, AnnualRevenue = request.AnnualRevenue }, options: SalesforceJson),
        };
        msg.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return await http.SendAsync(msg, ct);
    }
}
