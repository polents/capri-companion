using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;

namespace CapriCompanion.Windows;

public sealed class CapriSettings : INotifyPropertyChanged
{
    private string userName = "";
    private string palette = "Ion Bloom";
    private string wake = "Soft Boot";
    private string speakingStyle = "Warm deadpan";
    private string mood = "Curious";
    private double humor = .62;
    private double friendliness = .74;
    private double sass = .38;
    private double proactivity = .36;
    private int checkInMinutes = 30;
    private bool quietMode;
    private string model = "gemma4:e4b";
    private bool voiceInput;
    private bool spokenReplies;
    private string voiceName = "";

    public string UserName { get => userName; set => Set(ref userName, value); }
    public string Palette { get => palette; set => Set(ref palette, value); }
    public string Wake { get => wake; set => Set(ref wake, value); }
    public string SpeakingStyle { get => speakingStyle; set => Set(ref speakingStyle, value); }
    public string Mood { get => mood; set => Set(ref mood, value); }
    public double Humor { get => humor; set => Set(ref humor, value); }
    public double Friendliness { get => friendliness; set => Set(ref friendliness, value); }
    public double Sass { get => sass; set => Set(ref sass, value); }
    public double Proactivity { get => proactivity; set => Set(ref proactivity, value); }
    public int CheckInMinutes { get => checkInMinutes; set => Set(ref checkInMinutes, value); }
    public bool QuietMode { get => quietMode; set => Set(ref quietMode, value); }
    public string Model { get => model; set => Set(ref model, value); }
    public bool VoiceInput { get => voiceInput; set => Set(ref voiceInput, value); }
    public bool SpokenReplies { get => spokenReplies; set => Set(ref spokenReplies, value); }
    public string VoiceName { get => voiceName; set => Set(ref voiceName, value); }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void Set<T>(ref T field, T value, [CallerMemberName] string? property = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(property));
    }
}

public sealed class ChatLine
{
    public string Role { get; set; } = "capri";
    public string Text { get; set; } = "";
    public DateTime Date { get; set; } = DateTime.Now;
    public HorizontalAlignment Alignment => Role == "you" ? HorizontalAlignment.Right : HorizontalAlignment.Left;
    public string Label => Role == "you" ? "YOU" : "CAPRI";
}

public sealed class MemoryItem
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Text { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.Now;
}

public sealed class SavedState
{
    public CapriSettings Settings { get; set; } = new();
    public List<MemoryItem> Memories { get; set; } = [];
    public List<ChatLine> Messages { get; set; } = [];
    public double PetScale { get; set; } = 1.0;
    public double PetLeft { get; set; } = -1;
    public double PetTop { get; set; } = -1;
}

public sealed record CheckInInterval(string Label, int Minutes);
