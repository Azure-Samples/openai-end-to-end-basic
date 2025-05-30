﻿using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Azure;
using Azure.AI.Agents.Persistent;
using chatui.Models;
using chatui.Configuration;

namespace chatui.Controllers;

[ApiController]
[Route("[controller]/[action]")]

public class ChatController(
    PersistentAgentsClient client,
    IOptionsMonitor<ChatApiOptions> options,
    ILogger<ChatController> logger) : ControllerBase
{
    private readonly PersistentAgentsClient _client = client;
    private readonly IOptionsMonitor<ChatApiOptions> _options = options;
    private readonly ILogger<ChatController> _logger = logger;

    [HttpPost]
    public async Task<IActionResult> Completions([FromBody] string prompt)
    {
        if (string.IsNullOrWhiteSpace(prompt))
            throw new ArgumentException("Prompt cannot be null, empty, or whitespace.", nameof(prompt));

        _logger.LogDebug("Prompt received {Prompt}", prompt);
        var _config = _options.CurrentValue;

        // TODO: Reuse chat context.
        PersistentAgentThread thread = await _client.Threads.CreateThreadAsync();

        PersistentThreadMessage message = await _client.Messages.CreateMessageAsync(
            thread.Id,
            MessageRole.User,
            prompt);

        ThreadRun run = await _client.Runs.CreateRunAsync(thread.Id, _config.AIAgentId);

        while (run.Status == RunStatus.Queued || run.Status == RunStatus.InProgress || run.Status == RunStatus.RequiresAction)
        {
            await Task.Delay(TimeSpan.FromMilliseconds(500));
            run = (await _client.Runs.GetRunAsync(thread.Id, run.Id)).Value;
        }

        Pageable<PersistentThreadMessage>  messages = _client.Messages.GetMessages(
            threadId: thread.Id, order: ListSortOrder.Ascending);

        var fullText = string.Concat(
            messages
                .Where(m => m.Role == MessageRole.Agent)
                .SelectMany(m => m.ContentItems.OfType<MessageTextContent>())
                .Select(c => c.Text)
        );

        return Ok(new HttpChatResponse(true, fullText));
    }
}