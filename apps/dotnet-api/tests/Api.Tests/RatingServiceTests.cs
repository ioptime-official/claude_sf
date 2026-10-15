using Api;
using Xunit;

public class RatingServiceTests
{
    [Theory]
    [InlineData(20_000_000, "Hot")]
    [InlineData(10_000_000, "Hot")]
    [InlineData(5_000_000, "Warm")]
    [InlineData(1_000_000, "Warm")]
    [InlineData(999_999, "Cold")]
    [InlineData(0, "Cold")]
    public void Rate_returns_expected_band(decimal revenue, string expected) =>
        Assert.Equal(expected, RatingService.Rate(revenue));
}
