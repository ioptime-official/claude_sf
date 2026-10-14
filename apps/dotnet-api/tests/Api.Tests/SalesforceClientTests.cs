using System.Net;
using System.Text;
using Api;
using Xunit;

public class SalesforceClientTests
{
    private sealed class StubHandler(HttpStatusCode status, string body) : HttpMessageHandler
    {
        public HttpRequestMessage? Seen { get; private set; }
        public string? SeenBody { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Seen = request;
            SeenBody = request.Content is null ? null : await request.Content.ReadAsStringAsync(ct);
            return new HttpResponseMessage(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        }
    }

    private sealed class FakeTokens : ITokenProvider
    {
        public int Calls { get; private set; }
        public int Refreshes { get; private set; }
        public Task<string> GetTokenAsync(bool forceRefresh = false, CancellationToken ct = default)
        {
            Calls++;
            if (forceRefresh) Refreshes++;
            return Task.FromResult(forceRefresh ? "fresh-token" : "old-token");
        }
    }

    private sealed class SequenceHandler(params HttpStatusCode[] statuses) : HttpMessageHandler
    {
        public List<string?> AuthHeaders { get; } = new();
        private int i;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            AuthHeaders.Add(request.Headers.Authorization?.Parameter);
            var status = statuses[Math.Min(i++, statuses.Length - 1)];
            var body = status == HttpStatusCode.Created ? "{\"id\":\"001REFRESHED\"}" : "[]";
            return Task.FromResult(new HttpResponseMessage(status) { Content = new StringContent(body) });
        }
    }

    private static SalesforceClient Client(HttpMessageHandler handler, ITokenProvider? tokens = null) =>
        new(new HttpClient(handler) { BaseAddress = new Uri("https://example.my.salesforce.com/") },
            tokens ?? new FakeTokens());

    [Fact]
    public async Task Creates_account_and_returns_id()
    {
        var handler = new StubHandler(HttpStatusCode.Created, "{\"id\":\"001XX0000001\",\"success\":true}");
        var result = await Client(handler).CreateAccountAsync(new CreateAccountRequest("Acme", 20_000_000));

        Assert.Equal("001XX0000001", result.Id);
        Assert.Equal(HttpMethod.Post, handler.Seen!.Method);
        Assert.EndsWith("/services/data/v62.0/sobjects/Account", handler.Seen.RequestUri!.AbsolutePath);
        Assert.Contains("\"Name\":\"Acme\"", handler.SeenBody);
        Assert.Contains("\"AnnualRevenue\":20000000", handler.SeenBody);
    }

    [Fact]
    public async Task Salesforce_error_becomes_SalesforceException()
    {
        var handler = new StubHandler(HttpStatusCode.BadRequest, "[{\"errorCode\":\"REQUIRED_FIELD_MISSING\"}]");
        var ex = await Assert.ThrowsAsync<SalesforceException>(() =>
            Client(handler).CreateAccountAsync(new CreateAccountRequest("Acme", 1)));
        Assert.Contains("400", ex.Message);
    }

    [Fact]
    public async Task Sends_bearer_token_from_provider()
    {
        var handler = new SequenceHandler(HttpStatusCode.Created);
        await Client(handler).CreateAccountAsync(new CreateAccountRequest("Acme", 1));
        Assert.Equal(new[] { "old-token" }, handler.AuthHeaders);
    }

    [Fact]
    public async Task Refreshes_token_once_on_401_then_succeeds()
    {
        var tokens = new FakeTokens();
        var handler = new SequenceHandler(HttpStatusCode.Unauthorized, HttpStatusCode.Created);
        var result = await Client(handler, tokens).CreateAccountAsync(new CreateAccountRequest("Acme", 1));

        Assert.Equal("001REFRESHED", result.Id);
        Assert.Equal(new[] { "old-token", "fresh-token" }, handler.AuthHeaders);
        Assert.Equal(1, tokens.Refreshes);
    }

    [Fact]
    public async Task Does_not_loop_when_401_persists()
    {
        var handler = new SequenceHandler(HttpStatusCode.Unauthorized);
        await Assert.ThrowsAsync<SalesforceException>(() =>
            Client(handler).CreateAccountAsync(new CreateAccountRequest("Acme", 1)));
        Assert.Equal(2, handler.AuthHeaders.Count);
    }
}
