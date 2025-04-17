using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using chatui.Models;

namespace chatui.Controllers
{
    [ApiController]

    public class ChatGPTController(IConfiguration configuration, ILogger<ChatGPTController> logger) : ControllerBase
    {
        private readonly IConfiguration _configuration = configuration;
        private readonly ILogger<ChatGPTController> _logger = logger;

        [HttpPost]
        [Route("AskChatGPT")]
        public async Task<IActionResult> AskChatGPT([FromBody] string prompt)
        {
            ArgumentNullException.ThrowIfNull(prompt);
            var chatApiEndpoint = _configuration["chatApiEndpoint"];
            ArgumentNullException.ThrowIfNull(chatApiEndpoint,  nameof(chatApiEndpoint));
            var chatApiKey = _configuration["chatApiKey"];
            ArgumentNullException.ThrowIfNull(chatApiKey,  nameof(chatApiKey));

            var chatInputName = _configuration["chatInputName"] ?? "chat_input";
            var chatOutputName = _configuration["chatOutputName"] ?? "chat_output";

            var handler = new HttpClientHandler()
            {
                ClientCertificateOptions = ClientCertificateOption.Manual,
                ServerCertificateCustomValidationCallback =
                        (httpRequestMessage, cert, cetChain, policyErrors) => { return true; }
            };
            using var client = new HttpClient(handler);
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", chatApiKey);
            client.BaseAddress = new Uri(chatApiEndpoint);

            var requestBody = JsonSerializer.Serialize(new Dictionary<string, string>
            {
                [chatInputName] = prompt
            });
            var content = new StringContent(requestBody);
            content.Headers.ContentType = new MediaTypeHeaderValue("application/json");

            var response = await client.PostAsync("", content);
            _logger.LogInformation($"Http request status code: {response.StatusCode}");
            var responseContent = await response.Content.ReadAsStringAsync();

            if (response.IsSuccessStatusCode)
            {
                _logger.LogDebug("Result: {Result}", responseContent);

                var obj = JsonSerializer.Deserialize<Dictionary<string, string>>(responseContent);
                HttpChatGPTResponse oHttpResponse = new()
                {
                    Success = true,
                    Data = obj?.GetValueOrDefault(chatOutputName) ?? string.Empty
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