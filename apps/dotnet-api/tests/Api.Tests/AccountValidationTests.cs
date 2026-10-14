using Api;
using Xunit;

public class AccountValidationTests
{
    [Fact]
    public void Valid_request_has_no_errors() =>
        Assert.Empty(AccountValidation.Validate(new CreateAccountRequest("Acme", 100)));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Missing_name_is_rejected(string? name) =>
        Assert.Contains("name is required", AccountValidation.Validate(new CreateAccountRequest(name, 1)));

    [Fact]
    public void Negative_revenue_is_rejected() =>
        Assert.Contains("annualRevenue must be >= 0", AccountValidation.Validate(new CreateAccountRequest("Acme", -1)));

    [Fact]
    public void Overlong_name_is_rejected() =>
        Assert.Contains("name must be 255 characters or fewer",
            AccountValidation.Validate(new CreateAccountRequest(new string('x', 256), 1)));
}
