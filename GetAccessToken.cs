using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Identity.Client;
using System.Security.Cryptography.X509Certificates;

public static class TokenBroker
{
    [FunctionName("GetAccessToken")]
    public static async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
        ILogger log)
    {
        string tenantId = Environment.GetEnvironmentVariable("TenantId");
        string clientId = Environment.GetEnvironmentVariable("ClientId");
        string certPassword = Environment.GetEnvironmentVariable("CertPassword");
        string certFile = Environment.GetEnvironmentVariable("CertFileName"); // E.g., "mycert.pfx"
        string[] scopes = new[] { "https://graph.microsoft.com/.default" };

        // Path to .pfx inside function directory (best: use Key Vault in prod)
        string certPath = Path.Combine(Environment.CurrentDirectory, certFile);

        var cert = new X509Certificate2(certPath, certPassword);

        var app = ConfidentialClientApplicationBuilder
            .Create(clientId)
            .WithCertificate(cert)
            .WithAuthority($"https://login.microsoftonline.com/{tenantId}")
            .Build();

        var result = await app.AcquireTokenForClient(scopes).ExecuteAsync();

        return new OkObjectResult(new { access_token = result.AccessToken });
    }
}
