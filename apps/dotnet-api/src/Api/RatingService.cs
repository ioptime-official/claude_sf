namespace Api;

/// <summary>Mirrors the Salesforce AccountService rating bands so both systems agree.</summary>
public static class RatingService
{
    public const decimal HotThreshold = 10_000_000m;
    public const decimal WarmThreshold = 1_000_000m;

    public static string Rate(decimal annualRevenue) =>
        annualRevenue >= HotThreshold ? "Hot"
        : annualRevenue >= WarmThreshold ? "Warm"
        : "Cold";
}
