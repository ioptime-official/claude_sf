using System.Net;
using Api;
using Xunit;

public class TokenProviderTests
{
    private sealed class CountingHandler(HttpStatusCode status, string body) : HttpMessageHandler
    {
        public int Requests { get; private set; }
        public string? LastForm { get; private set; }
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Requests++;
            LastForm = await request.Content!.ReadAsStringAsync(ct);
            return new HttpResponseMessage(status) { Content = new StringContent(body) };
        }
    }

    private static ClientCredentialsTokenProvider Provider(CountingHandler h) =>
        new(new HttpClient(h) { BaseAddress = new Uri("https://example.my.salesforce.com/") }, "cid", "secret");

    [Fact]
    public async Task Requests_client_credentials_and_caches_the_token()
    {
        var handler = new CountingHandler(HttpStatusCode.OK, "{\"access_token\":\"abc\"}");
        var provider = Provider(handler);

        Assert.Equal("abc", await provider.GetTokenAsync());
        Assert.Equal("abc", await provider.GetTokenAsync());

        Assert.Equal(1, handler.Requests);
        Assert.Contains("grant_type=client_credentials", handler.LastForm);
        Assert.Contains("client_id=cid", handler.LastForm);
    }

    [Fact]
    public async Task ForceRefresh_requests_a_new_token()
    {
        var handler = new CountingHandler(HttpStatusCode.OK, "{\"access_token\":\"abc\"}");
        var provider = Provider(handler);
        await provider.GetTokenAsync();
        await provider.GetTokenAsync(forceRefresh: true);
        Assert.Equal(2, handler.Requests);
    }

    [Fact]
    public async Task Failed_token_request_throws_without_leaking_the_secret()
    {
        var provider = Provider(new CountingHandler(HttpStatusCode.BadRequest, "{\"error\":\"invalid_client\"}"));
        var ex = await Assert.ThrowsAsync<SalesforceException>(() => provider.GetTokenAsync());
        Assert.DoesNotContain("secret", ex.Message);
    }
}
