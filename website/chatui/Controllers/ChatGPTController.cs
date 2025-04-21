using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using chatui.Configuration;
using chatui.Models;

namespace chatui.Controllers
{
    [ApiController]
    [Route("[controller]/[action]")]

    public class ChatGPTController(IOptions<ChatApiOptions> options, ILogger<ChatGPTController> logger) : ControllerBase
    {
        private readonly ChatApiOptions _config = options.Value;
        private readonly ILogger<ChatGPTController> _logger = logger;

        [HttpPost("Ask")]
        public async Task<IActionResult> Ask([FromBody] string prompt)
        {
            ArgumentNullException.ThrowIfNull(prompt);
            _logger.LogDebug("Prompt received {Prompt}", prompt);

            using var client = new HttpClient(new HttpClientHandler
            {
                ClientCertificateOptions = ClientCertificateOption.Manual,
                ServerCertificateCustomValidationCallback = (_, _, _, _) => true
            });

            client.BaseAddress = new Uri(_config.ChatApiEndpoint);
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", _config.ChatApiKey);

            var requestBody = JsonSerializer.Serialize(new Dictionary<string, string>
            {
                [_config.ChatInputName] = prompt
            });

            using var content = new StringContent(requestBody, System.Text.Encoding.UTF8, "application/json");

            var response = await client.PostAsync(string.Empty, content);
            var responseContent = await response.Content.ReadAsStringAsync();

            _logger.LogInformation("Http request status code: {ResponseStatusCode}",response.StatusCode);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("Result: {Result}", responseContent);
                foreach (var (key, value) in response.Headers)
                    _logger.LogDebug("Header {Key}: {Value}", key, string.Join(", ", value));
                foreach (var (key, value) in response.Content.Headers)
                    _logger.LogDebug("Content-Header {Key}: {Value}", key, string.Join(", ", value));

                return BadRequest(responseContent);
            }

            _logger.LogDebug("Result: {Result}", responseContent);

            var result = JsonSerializer.Deserialize<Dictionary<string, string>>(responseContent);
            var output = result?.GetValueOrDefault(_config.ChatOutputName) ?? string.Empty;

            return Ok(new HttpChatGPTResponse { Success = true, Data = output });
        }
    }
}