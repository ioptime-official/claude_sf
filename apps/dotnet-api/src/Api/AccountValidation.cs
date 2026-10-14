namespace Api;

public static class AccountValidation
{
    public static IReadOnlyList<string> Validate(CreateAccountRequest request)
    {
        var errors = new List<string>();
        if (string.IsNullOrWhiteSpace(request.Name)) errors.Add("name is required");
        else if (request.Name.Length > 255) errors.Add("name must be 255 characters or fewer");
        if (request.AnnualRevenue < 0) errors.Add("annualRevenue must be >= 0");
        return errors;
    }
}
