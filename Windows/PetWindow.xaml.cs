using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;

namespace CapriCompanion.Windows;

public partial class PetWindow : Window
{
    private readonly CapriStore store;
    private readonly DispatcherTimer idleTimer = new() { Interval = TimeSpan.FromSeconds(25) };
    private readonly DispatcherTimer persistTimer = new() { Interval = TimeSpan.FromMilliseconds(350) };
    private readonly DispatcherTimer glitchTimer = new();

    public PetWindow(CapriStore store)
    {
        InitializeComponent();
        this.store = store;
        DataContext = store;
        Width = 190 * store.PetScale;
        Height = 326 * store.PetScale;
        if (store.PetLeft >= 0 && store.PetTop >= 0)
        {
            Left = store.PetLeft;
            Top = store.PetTop;
        }
        store.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(CapriStore.PetScale)) Dispatcher.Invoke(ApplyScale);
        };
        store.Settings.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(CapriSettings.Palette)) Dispatcher.Invoke(ApplyPalette);
        };
        idleTimer.Tick += (_, _) => store.MaybeCheckIn();
        glitchTimer.Tick += (_, _) =>
        {
            glitchTimer.Interval = TimeSpan.FromSeconds(Random.Shared.Next(8, 16));
            if (!IsVisible) return;
            PetImage.BeginAnimation(OpacityProperty, new DoubleAnimationUsingKeyFrames
            {
                Duration = TimeSpan.FromMilliseconds(155),
                KeyFrames =
                {
                    new DiscreteDoubleKeyFrame(1, KeyTime.FromPercent(0)),
                    new DiscreteDoubleKeyFrame(.72, KeyTime.FromPercent(.22)),
                    new DiscreteDoubleKeyFrame(1, KeyTime.FromPercent(.46)),
                    new DiscreteDoubleKeyFrame(.88, KeyTime.FromPercent(.70)),
                    new DiscreteDoubleKeyFrame(1, KeyTime.FromPercent(1))
                }
            });
        };
        persistTimer.Tick += (_, _) =>
        {
            persistTimer.Stop();
            store.PetLeft = Left;
            store.PetTop = Top;
        };
    }

    public void StartIdleLoop() => idleTimer.Start();

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (store.PetLeft < 0 || store.PetTop < 0)
        {
            var area = SystemParameters.WorkArea;
            Left = area.Right - Width - 22;
            Top = area.Bottom - Height - 20;
            store.PetLeft = Left;
            store.PetTop = Top;
        }

        var transforms = (TransformGroup)PetSurface.RenderTransform;
        var entranceScale = (ScaleTransform)transforms.Children[0];
        var entranceOffset = (TranslateTransform)transforms.Children[1];
        var floatOffset = (TranslateTransform)PetImage.RenderTransform;
        var duration = store.Settings.Wake switch
        {
            "Shatter" => .34,
            "Wake" => .58,
            _ => .42
        };
        var ease = new BackEase { EasingMode = EasingMode.EaseOut, Amplitude = .16 };
        entranceScale.BeginAnimation(ScaleTransform.ScaleXProperty, new DoubleAnimation(.78, 1, TimeSpan.FromSeconds(duration)) { EasingFunction = ease });
        entranceScale.BeginAnimation(ScaleTransform.ScaleYProperty, new DoubleAnimation(.78, 1, TimeSpan.FromSeconds(duration)) { EasingFunction = ease });
        entranceOffset.BeginAnimation(TranslateTransform.YProperty, new DoubleAnimation(18, 0, TimeSpan.FromSeconds(duration)) { EasingFunction = ease });
        PetSurface.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, TimeSpan.FromSeconds(.28)));

        var floatAnimation = new DoubleAnimation(-3.5, 3.5, TimeSpan.FromSeconds(2.4))
        {
            AutoReverse = true,
            RepeatBehavior = RepeatBehavior.Forever,
            EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut }
        };
        floatOffset.BeginAnimation(TranslateTransform.YProperty, floatAnimation);
        ApplyPalette();
        glitchTimer.Interval = TimeSpan.FromSeconds(Random.Shared.Next(8, 16));
        glitchTimer.Start();
        if (store.Settings.Wake == "Wake")
        {
            var ringScale = (ScaleTransform)OrbitRing.RenderTransform;
            OrbitRing.BeginAnimation(OpacityProperty, new DoubleAnimation(.72, 0, TimeSpan.FromSeconds(1.2)));
            ringScale.BeginAnimation(ScaleTransform.ScaleXProperty, new DoubleAnimation(.72, 1.12, TimeSpan.FromSeconds(1.2)));
            ringScale.BeginAnimation(ScaleTransform.ScaleYProperty, new DoubleAnimation(.72, 1.12, TimeSpan.FromSeconds(1.2)));
        }
        if (store.Settings.Wake == "Shatter")
        {
            var shake = new DoubleAnimationUsingKeyFrames { Duration = TimeSpan.FromMilliseconds(340) };
            shake.KeyFrames.Add(new DiscreteDoubleKeyFrame(0, KeyTime.FromPercent(0)));
            shake.KeyFrames.Add(new DiscreteDoubleKeyFrame(-6, KeyTime.FromPercent(.20)));
            shake.KeyFrames.Add(new DiscreteDoubleKeyFrame(5, KeyTime.FromPercent(.42)));
            shake.KeyFrames.Add(new DiscreteDoubleKeyFrame(-2, KeyTime.FromPercent(.70)));
            shake.KeyFrames.Add(new DiscreteDoubleKeyFrame(0, KeyTime.FromPercent(1)));
            floatOffset.BeginAnimation(TranslateTransform.XProperty, shake);
        }
    }

    private void ApplyScale()
    {
        var oldBottom = Top + Height;
        Width = 190 * store.PetScale;
        Height = 326 * store.PetScale;
        Top = oldBottom - Height;
    }

    private void ApplyPalette()
    {
        if (PetImage.Effect is not System.Windows.Media.Effects.DropShadowEffect current) return;
        var glow = (System.Windows.Media.Effects.DropShadowEffect)current.Clone();
        glow.Color = store.Settings.Palette switch
        {
            "Rose Quartz" => System.Windows.Media.Color.FromRgb(255, 105, 200),
            "Solar Flare" => System.Windows.Media.Color.FromRgb(171, 56, 255),
            "Acid Glass" => System.Windows.Media.Color.FromRgb(167, 247, 124),
            _ => System.Windows.Media.Color.FromRgb(84, 231, 242)
        };
        PetImage.Effect = glow;
        var color = glow.Color;
        OrbitRing.Stroke = new SolidColorBrush(color);
        if (OrbitRing.Effect is System.Windows.Media.Effects.DropShadowEffect ringShadow)
        {
            var ringGlow = (System.Windows.Media.Effects.DropShadowEffect)ringShadow.Clone();
            ringGlow.Color = color;
            OrbitRing.Effect = ringGlow;
        }
    }

    private void PetMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton != MouseButton.Left) return;
        var start = new System.Windows.Point(Left, Top);
        try { DragMove(); } catch (InvalidOperationException) { }
        var didMove = Math.Abs(Left - start.X) > 3 || Math.Abs(Top - start.Y) > 3;
        if (didMove)
        {
            persistTimer.Stop();
            persistTimer.Start();
        }
        else
        {
            ((App)System.Windows.Application.Current).OpenChat();
        }
        e.Handled = true;
    }

    private void OpenContextMenu(object sender, MouseButtonEventArgs e)
    {
        var menu = new ContextMenu();
        menu.Items.Add(Menu("Chat", () => ((App)System.Windows.Application.Current).OpenChat()));
        menu.Items.Add(Menu("Mainframe", () => ((App)System.Windows.Application.Current).OpenMainframe()));
        var size = new MenuItem { Header = "Size" };
        foreach (var scale in new[] { .75, 1.0, 1.25, 1.45 })
        {
            var item = new MenuItem { Header = $"{scale:P0}", IsCheckable = true, IsChecked = Math.Abs(store.PetScale - scale) < .01 };
            item.Click += (_, _) => store.PetScale = scale;
            size.Items.Add(item);
        }
        menu.Items.Add(size);
        menu.Items.Add(new Separator());
        menu.Items.Add(Menu("Hide Capri", () => ((App)System.Windows.Application.Current).HidePet()));
        menu.Items.Add(Menu("Quit", () => System.Windows.Application.Current.Shutdown()));
        ContextMenu = menu;
        menu.IsOpen = true;
        e.Handled = true;
    }

    private static MenuItem Menu(string title, Action action)
    {
        var item = new MenuItem { Header = title };
        item.Click += (_, _) => action();
        return item;
    }

    private void OnLocationChanged(object? sender, EventArgs e)
    {
        if (!IsLoaded) return;
        persistTimer.Stop();
        persistTimer.Start();
    }
}
