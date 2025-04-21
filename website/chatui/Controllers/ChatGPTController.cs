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

            var response = await client.PostAsync("", content);
            _logger.LogInformation("Http request status code: {ResponseStatusCode}",response.StatusCode);
            var responseContent = await response.Content.ReadAsStringAsync();

            if (response.IsSuccessStatusCode)
            {
                _logger.LogDebug("Result: {Result}", responseContent);

                var obj = JsonSerializer.Deserialize<Dictionary<string, string>>(responseContent);
                HttpChatGPTResponse oHttpResponse = new()
                {
                    Success = true,
                    Data = obj?.GetValueOrDefault(_config.ChatOutputName) ?? string.Empty
                };

                return Ok(oHttpResponse);
            }
            else
            {
                _logger.LogError("Result: {Result}", responseContent);
                foreach (var header in Response.Headers)
                {
                    _logger.LogDebug("{Key}: {Value}", header.Key, header.Value);
                }
                
                return BadRequest(responseContent);
            }
        }
    }
}