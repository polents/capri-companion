using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Speech.Synthesis;

namespace CapriCompanion.Windows;

public partial class MainframeWindow : Window
{
    private readonly CapriStore store;

    public MainframeWindow(CapriStore store)
    {
        InitializeComponent();
        this.store = store;
        DataContext = store;
        PalettePicker.ItemsSource = new[] { "Ion Bloom", "Rose Quartz", "Solar Flare", "Acid Glass" };
        WakePicker.ItemsSource = new[] { "Soft Boot", "Shatter", "Wake" };
        StylePicker.ItemsSource = new[] { "Warm deadpan", "Soft and thoughtful", "Bright and playful", "Short and direct" };
        MoodPicker.ItemsSource = new[] { "Curious", "Calm", "Playful", "Dreamy", "Focused" };
        CheckInPicker.ItemsSource = new[]
        {
            new CheckInInterval("Off", 0),
            new CheckInInterval("15 min", 15),
            new CheckInInterval("30 min", 30),
            new CheckInInterval("60 min", 60)
        };
        using (var speech = new SpeechSynthesizer())
        {
            VoicePicker.ItemsSource = speech.GetInstalledVoices().Select(v => v.VoiceInfo.Name).ToArray();
            if (!string.IsNullOrWhiteSpace(store.Settings.VoiceName) && VoicePicker.Items.Contains(store.Settings.VoiceName))
                VoicePicker.SelectedItem = store.Settings.VoiceName;
            else if (VoicePicker.Items.Count > 0)
                VoicePicker.SelectedIndex = 0;
        }
        store.PropertyChanged += StoreChanged;
        MemoryList.ItemsSource = store.Memories;
        UpdateStatus();
        UpdateScaleLabel();
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        await store.RefreshConnectionAsync();
        UpdateStatus();
    }

    private void StoreChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(CapriStore.ConnectionState) or nameof(CapriStore.StatusMessage))
            Dispatcher.BeginInvoke(new Action(UpdateStatus));
        if (e.PropertyName == nameof(CapriStore.PetScale)) Dispatcher.BeginInvoke(new Action(UpdateScaleLabel));
    }

    private void UpdateStatus()
    {
        BrainStatus.Text = store.ConnectionState;
        BrainMessage.Text = store.StatusMessage;
        VoiceStatus.Text = store.Settings.VoiceInput
            ? "Speech input is enabled. Tap the mic in chat when you want to dictate."
            : "Speech input is off. Turn it on here; the mic remains off until tapped in chat.";
    }

    private void UpdateScaleLabel() => ScaleLabel.Text = $"{store.PetScale:P0}";
    private void ModelSelected(object sender, SelectionChangedEventArgs e)
    {
        if (ModelPicker.SelectedItem is string model) store.Settings.Model = model;
    }

    private void VoiceSelected(object sender, SelectionChangedEventArgs e)
    {
        if (VoicePicker.SelectedItem is string name) store.Settings.VoiceName = name;
    }

    private async void RefreshModels(object sender, RoutedEventArgs e)
    {
        await store.RefreshConnectionAsync();
        UpdateStatus();
    }

    private async void PullModel(object sender, RoutedEventArgs e)
    {
        PullButton.IsEnabled = false;
        await store.PullSelectedModelAsync();
        PullButton.IsEnabled = true;
        UpdateStatus();
    }

    private void SelectMemory(object sender, SelectionChangedEventArgs e)
    {
        if (MemoryList.SelectedItem is MemoryItem memory) MemoryEditor.Text = memory.Text;
    }

    private void AddMemory(object sender, RoutedEventArgs e)
    {
        store.AddMemory(MemoryEditor.Text);
        MemoryEditor.Clear();
    }

    private void SaveMemory(object sender, RoutedEventArgs e)
    {
        if (MemoryList.SelectedItem is not MemoryItem memory) return;
        store.SaveMemory(memory, MemoryEditor.Text);
        MemoryList.Items.Refresh();
    }

    private void DeleteMemory(object sender, RoutedEventArgs e)
    {
        if (MemoryList.SelectedItem is not MemoryItem memory) return;
        store.DeleteMemory(memory);
        MemoryEditor.Clear();
    }

    private void DragWindow(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton == MouseButton.Left)
        {
            try { DragMove(); } catch (InvalidOperationException) { }
        }
    }

    private void CloseMainframe(object sender, RoutedEventArgs e) => Close();
    protected override void OnClosed(EventArgs e)
    {
        store.PropertyChanged -= StoreChanged;
        base.OnClosed(e);
    }

}
