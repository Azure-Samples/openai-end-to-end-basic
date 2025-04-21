using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using OpenAI.Chat;
using chatui.Configuration;
using chatui.Models;

namespace chatui.Controllers;

[ApiController]
[Route("[controller]/[action]")]

public class ChatController(
    ChatClient client,
    IOptionsMonitor<ChatApiOptions> options,
    ILogger<ChatController> logger) : ControllerBase
{
    private readonly ChatClient _client = client;
    private readonly IOptionsMonitor<ChatApiOptions> _options = options;
    private readonly ILogger<ChatController> _logger = logger;

    [HttpPost]
    public async Task<IActionResult> Completions([FromBody] string prompt)
    {
        if (string.IsNullOrWhiteSpace(prompt))
            throw new ArgumentException("Prompt cannot be null, empty, or whitespace.", nameof(prompt));

        _logger.LogDebug("Prompt received {Prompt}", prompt);

        var _config = _options.CurrentValue;

        HttpChatResponse response;
        try
        {
            ChatCompletion completion = await _client.CompleteChatAsync(
            [
                // System messages represent instructions or other guidance about how the assistant should behave
                new SystemChatMessage("You are a helpful Azure Chatbot assistant that answer questions about the Azure.") { ParticipantName = _config.ChatOutputName },
                // User messages represent user input, whether historical or the most recent input
                new UserChatMessage(prompt) { ParticipantName = _config.ChatInputName },
            ]);

            response = new (true, completion.Content.FirstOrDefault()?.Text ?? string.Empty);

            _logger.LogInformation("Successfully completed chat response with: {Data}.", response.Data);
        }
        catch (Exception ex)
        {
            _logger.LogError("Unexpected error occurred while completing the chat: {Error}", ex.Message);

            return StatusCode(503, new
            {
                success = false,
                error = "Service is temporarily unavailable."
            });
        }

        return Ok(response);
    }
}
