namespace chatui.Models;

public class HttpChatGPTResponse
{
    public bool Success { get; set; }
    public required string Data { get; set; }
}
