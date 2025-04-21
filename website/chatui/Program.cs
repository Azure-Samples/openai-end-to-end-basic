using Microsoft.Extensions.Options;
using Azure;
using Azure.AI.OpenAI;
using chatui.Configuration;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOptions<ChatApiOptions>()
    .Bind(builder.Configuration)
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddSingleton((provider) =>
{
    var config = provider.GetRequiredService<IOptions<ChatApiOptions>>().Value;
    var openAIClient = new AzureOpenAIClient(
        new Uri(config.ChatApiEndpoint),
        new AzureKeyCredential(config.ChatApiKey));

    // ensure this matches the custom deployment name you specified for
    // your model under ../../infra-as-code/bicep/openai.bicep
    return openAIClient.GetChatClient("gpt-35-turbo");
});

builder.Services.AddControllersWithViews();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAllOrigins",
        builder =>
        {
            builder.AllowAnyOrigin()
                   .AllowAnyMethod()
                   .AllowAnyHeader();
        });
});

var app = builder.Build();

app.UseStaticFiles();

app.UseRouting();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.UseCors("AllowAllOrigins");

app.Run();
