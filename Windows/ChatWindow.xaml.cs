using System.Speech.Recognition;
using System.Speech.Synthesis;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;

namespace CapriCompanion.Windows;

public partial class ChatWindow : Window
{
    private readonly CapriStore store;
    private readonly PetWindow pet;
    private SpeechRecognitionEngine? recognizer;
    private readonly SpeechSynthesizer synthesizer = new();
    private bool recording;

    public ChatWindow(CapriStore store, PetWindow pet)
    {
        this.store = store;
        this.pet = pet;
        InitializeComponent();
        Owner = pet;
        DataContext = store;
        store.PropertyChanged += StoreChanged;
        store.Messages.CollectionChanged += (_, _) =>
            Dispatcher.BeginInvoke(new Action(() => MessagesScroll.ScrollToEnd()), DispatcherPriority.Background);

        if (store.Messages.Count == 0)
        {
            store.Messages.Add(new ChatLine
            {
                Role = "capri",
                Text = store.HasMetUser
                    ? $"Hey, {store.Settings.UserName}. Local line's open. What's on your mind?"
                    : "Hey. I'm Capri. Before I make myself at home, what should I call you?"
            });
        }
    }

    public void FocusInput()
    {
        if (!IsLoaded) return;
        MessageInput.Focus();
        Keyboard.Focus(MessageInput);
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        var area = SystemParameters.WorkArea;
        var desiredLeft = pet.Left + pet.Width - Width;
        var desiredTop = pet.Top + 30;
        Left = Math.Clamp(desiredLeft, area.Left + 8, area.Right - Width - 8);
        Top = Math.Clamp(desiredTop, area.Top + 8, area.Bottom - Height - 8);
        FocusInput();
        UpdateStatus();
    }

    private async void SendMessage(object sender, RoutedEventArgs e) => await SendCurrentAsync();

    private async void InputKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter && Keyboard.Modifiers == ModifierKeys.None)
        {
            e.Handled = true;
            await SendCurrentAsync();
        }
    }

    private void InputChanged(object sender, System.Windows.Controls.TextChangedEventArgs e) => store.RecordActivity();

    private async Task SendCurrentAsync()
    {
        var text = MessageInput.Text.Trim();
        if (text.Length == 0 || store.IsSending) return;
        MessageInput.Clear();
        await store.SendAsync(text);
        UpdateStatus();
        if (store.Settings.SpokenReplies && store.Messages.LastOrDefault()?.Role == "capri")
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(store.Settings.VoiceName)) synthesizer.SelectVoice(store.Settings.VoiceName);
                synthesizer.SpeakAsync(store.Messages.Last().Text);
            }
            catch { StatusText.Text = "Windows speech output is unavailable."; }
        }
        FocusInput();
    }

    private void ToggleMicrophone(object sender, RoutedEventArgs e)
    {
        if (recording) StopRecording();
        else StartRecording();
    }

    private void StartRecording()
    {
        if (!store.Settings.VoiceInput)
        {
            StatusText.Text = "Enable speech input in Mainframe → Voice first.";
            return;
        }
        try
        {
            recognizer ??= CreateRecognizer();
            recognizer.SetInputToDefaultAudioDevice();
            recognizer.RecognizeAsync(RecognizeMode.Multiple);
            recording = true;
            MicButton.Content = "■";
        MicButton.BorderBrush = System.Windows.Media.Brushes.HotPink;
            StatusText.Text = "Listening on your microphone · click ■ to stop";
        }
        catch (Exception ex)
        {
            recording = false;
            StatusText.Text = $"Microphone unavailable: {ex.Message}";
            store.Settings.VoiceInput = false;
        }
    }

    private SpeechRecognitionEngine CreateRecognizer()
    {
        var engine = new SpeechRecognitionEngine();
        engine.LoadGrammar(new DictationGrammar());
        engine.SpeechRecognized += (_, args) =>
        {
            if (args.Result.Confidence < .52 || string.IsNullOrWhiteSpace(args.Result.Text)) return;
            Dispatcher.Invoke(() =>
            {
                MessageInput.Text = string.IsNullOrWhiteSpace(MessageInput.Text)
                    ? args.Result.Text
                    : MessageInput.Text.TrimEnd() + " " + args.Result.Text;
                MessageInput.CaretIndex = MessageInput.Text.Length;
            });
        };
        engine.SpeechRecognitionRejected += (_, _) => Dispatcher.Invoke(() => StatusText.Text = "Didn't catch that. Try again or type your message.");
        engine.RecognizeCompleted += (_, _) => Dispatcher.Invoke(() =>
        {
            recording = false;
            MicButton.Content = "◖";
            MicButton.ClearValue(System.Windows.Controls.Control.BorderBrushProperty);
            if (IsVisible) StatusText.Text = store.StatusMessage;
        });
        return engine;
    }

    private void StopRecording()
    {
        try { recognizer?.RecognizeAsyncCancel(); } catch { }
        recording = false;
        MicButton.Content = "◖";
        StatusText.Text = store.StatusMessage;
    }

    private void StoreChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(CapriStore.StatusMessage) or nameof(CapriStore.ConnectionState))
            Dispatcher.BeginInvoke(new Action(UpdateStatus));
    }

    private void UpdateStatus()
    {
        if (!recording) StatusText.Text = store.StatusMessage;
        MessageInput.ToolTip = store.HasMetUser ? "Type to Capri; Enter sends" : "Type your name for Capri";
    }

    private void OpenMainframe(object sender, RoutedEventArgs e) => ((App)System.Windows.Application.Current).OpenMainframe();
    private void CloseChat(object sender, RoutedEventArgs e) => Close();
    private void DragWindow(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton == MouseButton.Left)
        {
            try { DragMove(); } catch (InvalidOperationException) { }
        }
    }

    private void OnClosed(object? sender, EventArgs e)
    {
        if (recording) StopRecording();
        recognizer?.Dispose();
        synthesizer.Dispose();
        store.PropertyChanged -= StoreChanged;
    }
}
