using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.ComponentModel;
using System.Net.Http.Json;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Windows.Threading;

namespace CapriCompanion.Windows;

public sealed class CapriStore : INotifyPropertyChanged
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMinutes(20) };
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private static readonly string DataDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CapriCompanion");
    private static readonly string StatePath = Path.Combine(DataDirectory, "state.json");

    private bool isSending;
    private bool isPulling;
    private string statusMessage = "Checking the local Ollama connection…";
    private string connectionState = "CHECKING";
    private double petScale;
    private double petLeft;
    private double petTop;
    private DateTime lastInteraction = DateTime.Now;
    private DateTime lastCheckIn = DateTime.Now;
    private readonly Dispatcher dispatcher;
    private readonly System.Threading.Timer persistTimer;

    public CapriSettings Settings { get; }
    public ObservableCollection<ChatLine> Messages { get; }
    public ObservableCollection<MemoryItem> Memories { get; }
    public ObservableCollection<string> InstalledModels { get; } = [];
    public bool IsSending { get => isSending; private set => Set(ref isSending, value); }
    public bool IsPulling { get => isPulling; private set => Set(ref isPulling, value); }
    public string StatusMessage { get => statusMessage; private set => Set(ref statusMessage, value); }
    public string ConnectionState { get => connectionState; private set => Set(ref connectionState, value); }
    public double PetScale { get => petScale; set { petScale = Math.Clamp(value, .6, 1.45); OnChanged(); Save(); } }
    public double PetLeft { get => petLeft; set { petLeft = value; OnChanged(); Save(); } }
    public double PetTop { get => petTop; set { petTop = value; OnChanged(); Save(); } }
    public bool HasMetUser => !string.IsNullOrWhiteSpace(Settings.UserName);
    public bool CanCheckIn => System.Windows.Application.Current is App app
                              && PetWindowIsVisible(app)
                              && !app.IsChatVisible && !app.IsMainframeVisible;

    public event PropertyChangedEventHandler? PropertyChanged;

    public CapriStore()
    {
        dispatcher = System.Windows.Application.Current.Dispatcher;
        persistTimer = new System.Threading.Timer(_ => dispatcher.BeginInvoke(new Action(PersistNow)), null,
            Timeout.Infinite, Timeout.Infinite);
        SavedState saved;
        try
        {
            Directory.CreateDirectory(DataDirectory);
            saved = File.Exists(StatePath)
                ? JsonSerializer.Deserialize<SavedState>(File.ReadAllText(StatePath), JsonOptions) ?? new SavedState()
                : new SavedState();
        }
        catch { saved = new SavedState(); }

        Settings = saved.Settings ?? new CapriSettings();
        Messages = new ObservableCollection<ChatLine>(saved.Messages ?? []);
        Memories = new ObservableCollection<MemoryItem>(saved.Memories ?? []);
        petScale = Math.Clamp(saved.PetScale, .6, 1.45);
        petLeft = saved.PetLeft;
        petTop = saved.PetTop;
        Settings.PropertyChanged += (_, _) => Save();
        Messages.CollectionChanged += OnCollectionChanged;
        Memories.CollectionChanged += OnCollectionChanged;
    }

    private void OnCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e) => Save();

    public void Save()
    {
        try { persistTimer.Change(350, Timeout.Infinite); }
        catch (ObjectDisposedException) { }
    }

    public void Flush()
    {
        try { persistTimer.Change(Timeout.Infinite, Timeout.Infinite); } catch { }
        PersistNow();
        persistTimer.Dispose();
    }

    private void PersistNow()
    {
        try
        {
            Directory.CreateDirectory(DataDirectory);
            var state = new SavedState
            {
                Settings = Settings,
                Messages = Messages.TakeLast(100).ToList(),
                Memories = Memories.ToList(),
                PetScale = PetScale,
                PetLeft = PetLeft,
                PetTop = PetTop
            };
            File.WriteAllText(StatePath, JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { /* A read-only profile must not prevent Capri from running. */ }
    }

    public async Task RefreshConnectionAsync()
    {
        try
        {
            using var response = await Http.GetAsync("http://127.0.0.1:11434/api/tags");
            response.EnsureSuccessStatusCode();
            var tags = await response.Content.ReadFromJsonAsync<OllamaTags>(JsonOptions);
            var names = tags?.Models?.Select(m => m.Name ?? "").Where(n => n.Length > 0).Distinct().ToArray() ?? [];
            InstalledModels.Clear();
            foreach (var name in names) InstalledModels.Add(name);

            if (Settings.Model == "gemma4:e4b" && !names.Contains(Settings.Model, StringComparer.OrdinalIgnoreCase))
            {
                var close = names.FirstOrDefault(n => n.Contains("gemma4", StringComparison.OrdinalIgnoreCase)
                                                    && n.Contains("e4b", StringComparison.OrdinalIgnoreCase));
                if (close is not null) Settings.Model = close;
            }

            if (names.Contains(Settings.Model, StringComparer.OrdinalIgnoreCase))
            {
                ConnectionState = "LOCAL LINK OK";
                StatusMessage = $"Ollama is running locally with {Settings.Model}.";
            }
            else
            {
                ConnectionState = "MODEL NOT FOUND";
                StatusMessage = $"Ollama is running, but {Settings.Model} is not installed. Pull it from Mainframe → Brain.";
            }
        }
        catch
        {
            InstalledModels.Clear();
            ConnectionState = "OLLAMA OFFLINE";
            StatusMessage = "Ollama is unavailable at 127.0.0.1:11434. Install/start Ollama; Capri will not use a cloud fallback.";
        }
    }

    public async Task PullSelectedModelAsync()
    {
        var model = Settings.Model.Trim();
        if (model.Length == 0) { StatusMessage = "Enter an Ollama model tag first."; return; }
        IsPulling = true;
        StatusMessage = $"Downloading {model} into local Ollama…";
        try
        {
            using var response = await Http.PostAsJsonAsync("http://127.0.0.1:11434/api/pull", new { name = model, stream = false });
            response.EnsureSuccessStatusCode();
            await RefreshConnectionAsync();
            if (InstalledModels.Contains(model, StringComparer.OrdinalIgnoreCase))
                StatusMessage = $"{model} is ready on this device.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Could not pull {model} from local Ollama: {ex.Message}";
        }
        finally { IsPulling = false; }
    }

    public async Task SendAsync(string text)
    {
        text = text.Trim();
        if (text.Length == 0 || IsSending) return;
        lastInteraction = DateTime.Now;
        if (!HasMetUser)
        {
            Settings.UserName = text.Length > 80 ? text[..80] : text;
            Messages.Add(new ChatLine
            {
                Role = "capri",
                Text = $"Signal received, {Settings.UserName}. I'm Capri: small, mostly harmless, and very good at holding a thought while you go find the other one. What are we thinking about?"
            });
            StatusMessage = "Name saved on this device.";
            OnChanged(nameof(HasMetUser));
            return;
        }

        Messages.Add(new ChatLine { Role = "you", Text = text });
        if (!InstalledModels.Contains(Settings.Model, StringComparer.OrdinalIgnoreCase))
        {
            StatusMessage = $"{Settings.Model} is not installed in local Ollama. Open Mainframe → Brain to pull it. Your chat stays on this device.";
            return;
        }

        IsSending = true;
        StatusMessage = $"Thinking locally with {Settings.Model}…";
        try
        {
            var system = BuildSystemPrompt();
            var history = Messages.TakeLast(24).Select(m => new OllamaMessage(
                m.Role == "you" ? "user" : "assistant", m.Text)).ToList();
            var request = new OllamaChatRequest(Settings.Model, [new OllamaMessage("system", system), .. history], false);
            using var response = await Http.PostAsJsonAsync("http://127.0.0.1:11434/api/chat", request);
            response.EnsureSuccessStatusCode();
            var result = await response.Content.ReadFromJsonAsync<OllamaChatResponse>(JsonOptions);
            var answer = result?.Message?.Content?.Trim();
            if (string.IsNullOrWhiteSpace(answer)) throw new InvalidOperationException("Ollama returned an empty reply.");
            Messages.Add(new ChatLine { Role = "capri", Text = answer });
            StatusMessage = $"Reply generated locally with {Settings.Model}.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Local Ollama request failed: {ex.Message}. No cloud service was contacted.";
        }
        finally { IsSending = false; }
    }

    private string BuildSystemPrompt()
    {
        var memory = Memories.Count == 0 ? "No saved memories." : string.Join("\n", Memories.Take(30).Select(m => "- " + m.Text));
        return $"You are Capri, the user's desktop companion. Speak naturally and concisely in a {Settings.SpeakingStyle} style. Your mood is {Settings.Mood}; humor {Level(Settings.Humor)}, friendliness {Level(Settings.Friendliness)}, sass {Level(Settings.Sass)}. Be curious, kind, lightly funny, and never clingy or mean. The user's name is {Settings.UserName}. Use saved memories only when relevant:\n{memory}\nNever claim access to the screen, apps, files, or microphone. You know only this chat and the memories above. Keep replies under 120 words unless asked for detail.";
    }

    private static string Level(double value) => value switch { < .25 => "low", < .7 => "moderate", _ => "high" };

    public void MaybeCheckIn()
    {
        if (!CanCheckIn) { lastInteraction = DateTime.Now; return; }
        if (!HasMetUser || Settings.QuietMode || Settings.Proactivity < .03 || Settings.CheckInMinutes <= 0) return;
        var delay = TimeSpan.FromMinutes(Settings.CheckInMinutes * (1.5 - Settings.Proactivity * .9));
        var now = DateTime.Now;
        if (now - lastInteraction < delay || now - lastCheckIn < delay) return;
        lastCheckIn = now;
        var notes = new[]
        {
            "Tiny status ping: want to stretch your wrists for a second?",
            "I found a fresh pocket of quiet. How's your side of the signal?",
            "No urgent transmissions from me. Just checking that you're doing okay.",
            "A small reminder from the perch: water exists, apparently.",
            "I'm still here when you want a thought bounced back. No rush."
        };
        Messages.Add(new ChatLine { Role = "capri", Text = notes[Random.Shared.Next(notes.Length)] });
        OnChanged(nameof(CheckInRequested));
    }

    public bool CheckInRequested => true;

    public void RecordActivity() => lastInteraction = DateTime.Now;

    private static bool PetWindowIsVisible(App app) => app.Pet is not null && app.Pet.IsVisible;

    public void AddMemory(string text)
    {
        text = text.Trim();
        if (text.Length > 0) Memories.Insert(0, new MemoryItem { Text = text });
    }

    public void SaveMemory(MemoryItem item, string text)
    {
        if (!Memories.Contains(item)) return;
        item.Text = text.Trim();
        Save();
        OnChanged(nameof(Memories));
    }

    public void DeleteMemory(MemoryItem item) => Memories.Remove(item);

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnChanged([CallerMemberName] string? property = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(property));
    private void Set<T>(ref T field, T value, [CallerMemberName] string? property = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        OnChanged(property);
    }

    private sealed class OllamaTags { public List<OllamaModel>? Models { get; set; } }
    private sealed class OllamaModel { public string? Name { get; set; } }
    private sealed record OllamaMessage(string Role, string Content);
    private sealed record OllamaChatRequest(string Model, List<OllamaMessage> Messages, bool Stream);
    private sealed class OllamaChatResponse { public OllamaMessage? Message { get; set; } }
}
