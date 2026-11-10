using System.Drawing;
using System.Windows;
using Forms = System.Windows.Forms;

namespace CapriCompanion.Windows;

public partial class App : System.Windows.Application
{
    public static CapriStore Store { get; private set; } = null!;
    public static PetWindow Pet { get; private set; } = null!;
    public bool IsChatVisible => chatWindow?.IsVisible == true;
    public bool IsMainframeVisible => mainframeWindow?.IsVisible == true;
    private Forms.NotifyIcon? trayIcon;
    private ChatWindow? chatWindow;
    private MainframeWindow? mainframeWindow;

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        Store = new CapriStore();
        Pet = new PetWindow(Store);
        Pet.Show();
        CreateTrayIcon();
        Pet.StartIdleLoop();
        if (!Store.HasMetUser) OpenChat();
        await Store.RefreshConnectionAsync();
    }

    public void OpenChat()
    {
        Store.RecordActivity();
        if (chatWindow is null)
        {
            chatWindow = new ChatWindow(Store, Pet);
            chatWindow.Closed += (_, _) => chatWindow = null;
        }
        chatWindow.Show();
        chatWindow.Activate();
        chatWindow.FocusInput();
    }

    public void OpenMainframe()
    {
        Store.RecordActivity();
        if (mainframeWindow is null)
        {
            mainframeWindow = new MainframeWindow(Store);
            mainframeWindow.Closed += (_, _) => mainframeWindow = null;
        }
        mainframeWindow.Show();
        mainframeWindow.Activate();
    }

    public void HidePet() => Pet.Hide();

    private void CreateTrayIcon()
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Show Capri", null, (_, _) =>
        {
            Pet.Show();
            Pet.Activate();
        });
        menu.Items.Add("Chat", null, (_, _) => OpenChat());
        menu.Items.Add("Mainframe", null, (_, _) => OpenMainframe());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Quit Capri", null, (_, _) => ShutdownApp());
        trayIcon = new Forms.NotifyIcon
        {
            Text = "Capri Companion",
            Icon = Icon.ExtractAssociatedIcon(Environment.ProcessPath!) ?? SystemIcons.Application,
            ContextMenuStrip = menu,
            Visible = true
        };
        trayIcon.DoubleClick += (_, _) =>
        {
            Pet.Show();
            Pet.Activate();
        };
    }

    private void ShutdownApp()
    {
        trayIcon?.Dispose();
        mainframeWindow?.Close();
        chatWindow?.Close();
        Pet.Close();
        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        Store?.Flush();
        trayIcon?.Dispose();
        base.OnExit(e);
    }
}
