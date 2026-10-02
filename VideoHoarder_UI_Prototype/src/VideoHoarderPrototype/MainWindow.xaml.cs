using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;

namespace VideoHoarderPrototype;

public partial class MainWindow : Window
{
    bool darkMode = false;
    string currentMode = "Download";
    string demoState = "Normal";
    TextBox? urlBox;
    readonly ContentControl workspace = new();
    readonly TextBlock status = new();
    readonly Dictionary<string, Button> nav = new();

    Brush Bg => B(darkMode ? "#0B1020" : "#F4F6FA");
    Brush Panel => B(darkMode ? "#11182B" : "#FFFFFF");
    Brush Panel2 => B(darkMode ? "#18213A" : "#F6F8FC");
    Brush Border => B(darkMode ? "#2A3658" : "#D8DFEA");
    Brush Text => B(darkMode ? "#F3F6FF" : "#172033");
    Brush Muted => B(darkMode ? "#94A3C7" : "#6E7890");
    Brush Accent => B("#F43F7A");
    Brush Blue => B("#2E7DF6");
    Brush Good => B("#16A36A");
    Brush Warn => B("#E79A21");
    Brush Danger => B("#E64B55");

    static SolidColorBrush B(string hex) => new((Color)ColorConverter.ConvertFromString(hex));

    public MainWindow()
    {
        InitializeComponent();
        FontFamily = new FontFamily("Segoe UI");
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        WindowState = WindowState.Maximized;
        AllowDrop = true;
        Drop += OnDrop;
        PreviewKeyDown += OnPreviewKeyDown;
        BuildShell();
    }

    TextBlock T(string text, double size = 13, Brush? brush = null, FontWeight? weight = null)
        => new()
        {
            Text = text,
            FontSize = size,
            Foreground = brush ?? Text,
            FontWeight = weight ?? FontWeights.Normal,
            VerticalAlignment = VerticalAlignment.Center,
            TextWrapping = TextWrapping.Wrap
        };

    Border Card(UIElement child, Thickness? margin = null, Thickness? padding = null, Brush? background = null)
        => new()
        {
            Child = child,
            Background = background ?? Panel,
            BorderBrush = Border,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(9),
            Margin = margin ?? new Thickness(0, 0, 10, 10),
            Padding = padding ?? new Thickness(14)
        };

    Button Btn(string text, bool accent = false, double minWidth = 0, double height = 34)
    {
        var b = new Button
        {
            Content = text,
            MinWidth = minWidth,
            Height = height,
            Margin = new Thickness(0, 0, 7, 0),
            Padding = new Thickness(12, 0, 12, 0),
            Foreground = accent ? Brushes.White : Text,
            Background = accent ? Accent : Panel,
            BorderBrush = accent ? Accent : Border,
            BorderThickness = new Thickness(1),
            Cursor = Cursors.Hand
        };
        return b;
    }

    CheckBox Check(string text, bool value = false) => new()
    {
        Content = text,
        IsChecked = value,
        Foreground = Text,
        Margin = new Thickness(0, 5, 16, 5),
        VerticalAlignment = VerticalAlignment.Center
    };

    StackPanel H(params UIElement[] items)
    {
        var s = new StackPanel { Orientation = Orientation.Horizontal };
        foreach (var i in items) s.Children.Add(i);
        return s;
    }

    Border Badge(string text, string tone = "neutral")
    {
        var color = tone switch
        {
            "good" => Good,
            "warn" => Warn,
            "danger" => Danger,
            "planned" => B("#8B6AD9"),
            _ => Blue
        };
        return new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(28, ((SolidColorBrush)color).Color.R, ((SolidColorBrush)color).Color.G, ((SolidColorBrush)color).Color.B)),
            BorderBrush = color,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(8, 2, 8, 2),
            Margin = new Thickness(5, 0, 0, 0),
            Child = T(text, 11, color, FontWeights.SemiBold)
        };
    }

    TextBox Input(string text, double height = 38)
        => new()
        {
            Text = text,
            Height = height,
            Padding = new Thickness(11, 8, 11, 6),
            FontSize = 13,
            Foreground = Text,
            Background = Panel,
            BorderBrush = Border,
            BorderThickness = new Thickness(1)
        };

    ComboBox Combo(params string[] values)
    {
        var c = new ComboBox
        {
            Height = 34,
            MinWidth = 120,
            Padding = new Thickness(7, 4, 7, 4),
            Foreground = Text,
            Background = Panel,
            BorderBrush = Border
        };
        foreach (var v in values) c.Items.Add(v);
        if (c.Items.Count > 0) c.SelectedIndex = 0;
        return c;
    }

    Border Thumbnail(string label, string color1 = "#244D8E", string color2 = "#673F88", double width = 160, double height = 90)
    {
        var grad = new LinearGradientBrush(B(color1).Color, B(color2).Color, 35);
        var box = new Border { Width = width, Height = height, Background = grad, CornerRadius = new CornerRadius(7) };
        var grid = new Grid();
        var mark = T("▶", 24, Brushes.White, FontWeights.Bold);
        mark.HorizontalAlignment = HorizontalAlignment.Center;
        mark.VerticalAlignment = VerticalAlignment.Center;
        var caption = T(label, 11, Brushes.White, FontWeights.SemiBold);
        caption.Margin = new Thickness(7);
        caption.VerticalAlignment = VerticalAlignment.Bottom;
        grid.Children.Add(mark);
        grid.Children.Add(caption);
        box.Child = grid;
        return box;
    }

    void BuildShell()
    {
        Root.Children.Clear();
        nav.Clear();
        Background = Bg;
        Foreground = Text;

        var shell = new Grid { Background = Bg };
        shell.RowDefinitions.Add(new RowDefinition { Height = new GridLength(50) });
        shell.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        shell.RowDefinitions.Add(new RowDefinition { Height = new GridLength(30) });

        var top = new Grid { Background = Panel };
        top.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        top.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        top.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        top.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var brand = H(T("▶", 20, Accent, FontWeights.Bold), T("  VideoHoarder", 18, Text, FontWeights.Bold));
        brand.Margin = new Thickness(16, 0, 18, 0);
        top.Children.Add(brand);

        var menu = H();
        foreach (var item in new[] { "File", "Downloads", "Tools" })
        {
            var b = Btn(item, false, 0, 30);
            b.Background = Brushes.Transparent;
            b.BorderBrush = Brushes.Transparent;
            b.Click += (_, _) => ShowTopMenu(b, item);
            menu.Children.Add(b);
        }
        Grid.SetColumn(menu, 1);
        top.Children.Add(menu);

        var modes = H();
        modes.HorizontalAlignment = HorizontalAlignment.Center;
        foreach (var m in new[] { "Download", "AI", "Library", "Subscriptions", "Chapters", "Operations" })
        {
            var b = Btn(m, m == currentMode, 0, 32);
            b.Tag = m;
            b.Margin = new Thickness(2, 9, 2, 9);
            b.Click += (_, _) => ShowMode(m);
            nav[m] = b;
            modes.Children.Add(b);
        }
        Grid.SetColumn(modes, 2);
        top.Children.Add(modes);

        var right = H();
        right.Margin = new Thickness(6, 8, 12, 8);
        var command = Btn("Ctrl+K  Search", false, 116, 32);
        command.Click += (_, _) => ShowCommandPalette();
        var activity = Btn("↓ 3   AI 2   ⚠ 1", false, 120, 32);
        activity.Click += (_, _) => ShowActivityDrawer();
        var bell = Btn("🔔", false, 38, 32);
        bell.Click += (_, _) => ShowNotifications();
        var theme = Btn(darkMode ? "☀" : "☾", false, 38, 32);
        theme.Click += (_, _) => { darkMode = !darkMode; BuildShell(); };
        var settings = Btn("⚙", false, 38, 32);
        settings.Click += (_, _) => ShowSettings();
        right.Children.Add(command);
        right.Children.Add(activity);
        right.Children.Add(bell);
        right.Children.Add(theme);
        right.Children.Add(settings);
        Grid.SetColumn(right, 3);
        top.Children.Add(right);
        shell.Children.Add(top);

        workspace.Margin = new Thickness(14, 12, 14, 8);
        workspace.Content = CreateMode(currentMode);
        Grid.SetRow(workspace, 1);
        shell.Children.Add(workspace);

        var foot = new Grid { Background = Panel, Margin = new Thickness(0) };
        foot.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        foot.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        status.Text = $"{currentMode} • {demoState} • UI prototype only";
        status.Foreground = Muted;
        status.Margin = new Thickness(14, 0, 0, 0);
        foot.Children.Add(status);
        var rhs = T("Local-first • Backend disconnected • 1,248 library items", 11, Muted);
        rhs.Margin = new Thickness(0, 0, 14, 0);
        Grid.SetColumn(rhs, 1);
        foot.Children.Add(rhs);
        Grid.SetRow(foot, 2);
        shell.Children.Add(foot);

        Root.Children.Add(shell);
    }

    UIElement CreateMode(string mode)
    {
        if (demoState != "Normal") return CreateStatePreview(mode, demoState);
        return mode switch
        {
            "Download" => CreateDownload(),
            "AI" => CreateAI(),
            "Library" => CreateLibrary(),
            "Subscriptions" => CreateSubscriptions(),
            "Chapters" => CreateChapters(),
            _ => CreateOperations()
        };
    }

    void ShowMode(string mode)
    {
        currentMode = mode;
        foreach (var pair in nav)
        {
            pair.Value.Background = pair.Key == mode ? Accent : Panel;
            pair.Value.Foreground = pair.Key == mode ? Brushes.White : Text;
            pair.Value.BorderBrush = pair.Key == mode ? Accent : Border;
        }
        workspace.Content = CreateMode(mode);
        status.Text = $"{mode} • {demoState} • UI prototype only";
    }

    UIElement CreateStatePreview(string mode, string state)
    {
        var root = new Grid();
        var stack = new StackPanel { Width = 620, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        var icon = state switch { "Offline" => "⚠", "Loading" => "◌", "First Run" => "★", _ => "□" };
        stack.Children.Add(T(icon, 52, state == "Offline" ? Warn : Accent, FontWeights.Bold));
        ((TextBlock)stack.Children[^1]).HorizontalAlignment = HorizontalAlignment.Center;
        var title = state switch
        {
            "First Run" => "Welcome to VideoHoarder",
            "Empty" => $"No {mode.ToLowerInvariant()} items yet",
            "Loading" => $"Loading {mode.ToLowerInvariant()} data…",
            "Offline" => "Local service is unavailable",
            _ => state
        };
        var h = T(title, 25, Text, FontWeights.Bold); h.HorizontalAlignment = HorizontalAlignment.Center; h.Margin = new Thickness(0, 12, 0, 8); stack.Children.Add(h);
        var explain = T(state == "Offline" ? "Your files stay local. Retry the service or open Operations → Diagnostics." :
            state == "First Run" ? "Choose a profile, check portable tools, then paste your first URL." :
            state == "Loading" ? "Reading the local library and job state. This preview demonstrates the loading treatment." :
            "Use the controls above to create your first item. Empty screens always explain the next action.", 14, Muted);
        explain.TextAlignment = TextAlignment.Center; stack.Children.Add(explain);
        if (state == "Loading")
        {
            var bar = new ProgressBar { IsIndeterminate = true, Height = 8, Margin = new Thickness(0, 20, 0, 0) };
            stack.Children.Add(bar);
        }
        else
        {
            var back = Btn("Return to normal preview", true, 180, 38); back.Margin = new Thickness(0, 20, 0, 0); back.HorizontalAlignment = HorizontalAlignment.Center;
            back.Click += (_, _) => { demoState = "Normal"; ShowMode(currentMode); };
            stack.Children.Add(back);
        }
        root.Children.Add(stack);
        return root;
    }

    UIElement CreateDownload()
    {
        var root = new Grid();
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var entry = new Grid();
        entry.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        entry.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        urlBox = Input("Paste a URL, playlist, channel, course, M3U8/HLS or drop files here…", 46);
        urlBox.AllowDrop = true;
        entry.Children.Add(urlBox);
        var download = Btn("↓  Download", true, 130, 46);
        download.Click += (_, _) => Toast("Mock download added to queue");
        Grid.SetColumn(download, 1); entry.Children.Add(download);
        root.Children.Add(entry);

        var controls = new Grid { Margin = new Thickness(0, 9, 0, 9) };
        controls.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        controls.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var left = H(T("Profile", 12, Muted), Combo("Full Library", "Fast Download", "Transcript Only", "AI Research", "Media Only", "Audio Only"),
                     T("  Quality", 12, Muted), Combo("Best available", "1080p", "720p", "480p", "360p"),
                     T("  Subtitles", 12, Muted), Combo("VTT + SRT", "VTT", "SRT", "Off"));
        controls.Children.Add(left);
        var right = H(Btn("Clipboard"), Btn("Batch"), Btn("Output"), Btn("Download options"));
        ((Button)right.Children[0]).Click += (_, _) => ImportClipboard();
        ((Button)right.Children[1]).Click += (_, _) => ShowBatchDialog();
        ((Button)right.Children[2]).Click += (_, _) => ShowSimpleDialog("Output folder", "Portable / relative output folder\nDownloads\\Videos\\\n\nThe real app will resolve this relative to the application/library root.");
        ((Button)right.Children[3]).Click += (_, _) => ShowDownloadOptions();
        Grid.SetColumn(right, 1); controls.Children.Add(right);
        Grid.SetRow(controls, 1); root.Children.Add(controls);

        var area = new Grid();
        area.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        area.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        var viewBar = new Grid();
        viewBar.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        viewBar.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var views = H(Btn("Active"), Btn("Grid"), Btn("List"), Btn("Subscriptions"), Btn("Log"), Btn("History"));
        viewBar.Children.Add(views);
        var filter = H(Combo("All sources", "YouTube", "External", "Imported"), Btn("Filter"), Btn("Folder"));
        Grid.SetColumn(filter, 1); viewBar.Children.Add(filter);
        area.Children.Add(viewBar);
        var host = new ContentControl { Margin = new Thickness(0, 8, 0, 0) };
        Grid.SetRow(host, 1); area.Children.Add(host);
        void SetView(string view)
        {
            host.Content = view switch
            {
                "Grid" => DownloadGrid(),
                "List" => DownloadTable(),
                "Subscriptions" => DownloadSourceView(),
                "Log" => DownloadLogFull(),
                "History" => UnifiedHistory("Download history"),
                _ => DownloadActive()
            };
        }
        foreach (Button b in views.Children)
        {
            var label = b.Content?.ToString() ?? "Active";
            b.Click += (_, _) => SetView(label);
        }
        SetView("Active");
        Grid.SetRow(area, 2); root.Children.Add(area);
        return root;
    }

    UIElement DownloadActive()
    {
        var root = new Grid();
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(340) });
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var jobs = new StackPanel();
        jobs.Children.Add(T("Downloads (4)", 15, Text, FontWeights.Bold));
        jobs.Children.Add(DownloadJob("NASA Mars Documentary", "68%", "2.1 MB/s", "4m 12s", "RUNNING", "#75566E", "#C54B4B"));
        jobs.Children.Add(DownloadJob("Python Basics for Data Science", "32%", "1.4 MB/s", "8m 21s", "RUNNING", "#315E81", "#1B273E"));
        jobs.Children.Add(DownloadJob("The Future of AI", "92%", "6.8 MB/s", "45s", "RUNNING", "#4A4C9F", "#B04F6F"));
        jobs.Children.Add(DownloadJob("Machine Learning Basics", "Queued", "—", "Waiting", "QUEUED", "#30595B", "#1B2B54"));
        var left = Card(new ScrollViewer { Content = jobs, VerticalScrollBarVisibility = ScrollBarVisibility.Auto }, new Thickness(0, 0, 10, 0), new Thickness(10));
        root.Children.Add(left);

        var log = LiveLogPanel();
        Grid.SetColumn(log, 1); root.Children.Add(log);
        var actions = H(Btn("Ⅱ Pause All"), Btn("▶ Resume All"), Btn("↻ Retry Failed"), Btn("Auto-clear Completed"), Btn("✕ Cancel In Progress"));
        actions.Margin = new Thickness(0, 8, 0, 0);
        Grid.SetRow(actions, 1); Grid.SetColumnSpan(actions, 2); root.Children.Add(actions);
        return root;
    }

    Border DownloadJob(string title, string pct, string speed, string eta, string state, string c1, string c2)
    {
        var g = new Grid();
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(86) });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        g.Children.Add(Thumbnail("", c1, c2, 78, 52));
        var stack = new StackPanel { Margin = new Thickness(8, 0, 0, 0) };
        var name = T(title, 12, Text, FontWeights.SemiBold); name.TextTrimming = TextTrimming.CharacterEllipsis; stack.Children.Add(name);
        stack.Children.Add(T($"{pct}  •  {speed}  •  {eta}", 11, state == "RUNNING" ? Good : Muted));
        var pb = new ProgressBar { Height = 5, Maximum = 100, Value = pct.EndsWith("%") && int.TryParse(pct.TrimEnd('%'), out var n) ? n : 0, Margin = new Thickness(0, 4, 0, 0) };
        stack.Children.Add(pb);
        Grid.SetColumn(stack, 1); g.Children.Add(stack);
        return Card(g, new Thickness(0, 8, 0, 0), new Thickness(8));
    }

    Border LiveLogPanel()
    {
        var root = new DockPanel();
        var tabs = H(Btn("Download Log"), Btn("FFmpeg Output"), Btn("Metadata"), Btn("JSON"));
        DockPanel.SetDock(tabs, Dock.Top); root.Children.Add(tabs);
        var console = new TextBox
        {
            IsReadOnly = true,
            AcceptsReturn = true,
            TextWrapping = TextWrapping.NoWrap,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            FontFamily = new FontFamily("Consolas"),
            FontSize = 12,
            Foreground = B("#D9E4FF"),
            Background = B("#080B10"),
            BorderBrush = B("#202633"),
            Padding = new Thickness(12),
            Text = "[12:14:03] [info] Extracting URL: https://youtube.com/watch?v=...\n" +
                   "[12:14:04] [youtube] Downloading webpage\n" +
                   "[12:14:05] [info] Selected format 137+140\n" +
                   "[12:14:05] [download] Destination: NASA Mars Documentary.mp4\n" +
                   "[12:14:08] [download] 42.1% of 1.4GiB at 5.01MiB/s ETA 04:21\n" +
                   "[12:14:10] [download] 68.3% of 1.4GiB at 6.42MiB/s ETA 02:11\n" +
                   "[12:14:11] [ffmpeg] Merging formats into final container\n" +
                   "[12:14:12] [subtitle] Writing English VTT/SRT\n" +
                   "[12:14:13] [metadata] Writing info JSON and thumbnail\n\n" +
                   "Full selected-job history is retained in this prototype view."
        };
        root.Children.Add(console);
        return Card(root, new Thickness(0), new Thickness(10));
    }

    UIElement DownloadGrid()
    {
        var wrap = new WrapPanel();
        foreach (var x in new[]
        {
            ("NASA Mars Documentary", "68%", "#6A4C6F", "#C34B4B"),
            ("Python Basics", "32%", "#325B82", "#1C263C"),
            ("The Future of AI", "92%", "#49479A", "#A74467"),
            ("Machine Learning Basics", "Queued", "#245A5C", "#253A75"),
            ("Beautiful Places in Japan", "Completed", "#4B7A8B", "#2B4E6A"),
            ("History of the Internet", "Completed", "#684837", "#263B62")
        })
        {
            var stack = new StackPanel();
            stack.Children.Add(Thumbnail(x.Item1, x.Item3, x.Item4, 220, 122));
            var title = T(x.Item1, 13, Text, FontWeights.SemiBold); title.Width = 220; title.Margin = new Thickness(0, 8, 0, 3); stack.Children.Add(title);
            stack.Children.Add(T(x.Item2, 11, x.Item2 == "Completed" ? Good : Muted));
            wrap.Children.Add(Card(stack, new Thickness(0, 0, 10, 10), new Thickness(9)));
        }
        return new ScrollViewer { Content = wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
    }

    UIElement DownloadTable()
    {
        var dg = MakeGrid();
        dg.ItemsSource = new[]
        {
            new { Select="☑", Title="NASA Mars Documentary", Source="YouTube", Status="Downloading", Progress="68%", Speed="6.4 MB/s", ETA="02:11", Profile="Full Library" },
            new { Select="☑", Title="Python Basics for Data Science", Source="YouTube", Status="Downloading", Progress="32%", Speed="1.4 MB/s", ETA="08:21", Profile="AI Research" },
            new { Select="☐", Title="The Future of AI", Source="YouTube", Status="Downloading", Progress="92%", Speed="6.8 MB/s", ETA="00:45", Profile="Transcript Only" },
            new { Select="☐", Title="Machine Learning Basics", Source="YouTube", Status="Queued", Progress="0%", Speed="—", ETA="—", Profile="Full Library" }
        };
        return dg;
    }

    UIElement DownloadSourceView()
    {
        var root = new Grid();
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(260) });
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var left = new StackPanel(); left.Children.Add(T("Source views", 16, Text, FontWeights.Bold));
        foreach (var s in new[] { "YouTube channels", "Playlists", "Imported URLs", "M3U8 / HLS", "Embedded video sources" }) left.Children.Add(Card(T(s, 13), new Thickness(0, 8, 0, 0), new Thickness(11)));
        root.Children.Add(left);
        var right = new StackPanel { Margin = new Thickness(16, 0, 0, 0) };
        right.Children.Add(T("Source-specific download intake", 18, Text, FontWeights.Bold));
        right.Children.Add(T("Use this view to inspect URL groups, playlist/channel expansion, metadata scan state and Smart Resume decisions before queueing.", 13, Muted));
        right.Children.Add(Card(T("Metadata scan: 14 URLs • 82 videos discovered • 79 unique VIDEO_IDs\nSmart Resume: 64 complete • 9 repair • 6 new downloads\nEmbedded resolution: 3 pages contain playable external media", 13), new Thickness(0, 12, 0, 0), new Thickness(16)));
        Grid.SetColumn(right, 1); root.Children.Add(right); return root;
    }

    UIElement DownloadLogFull()
    {
        var root = new Grid();
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(300) });
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var list = new StackPanel(); list.Children.Add(T("Select job", 15, Text, FontWeights.Bold));
        list.Children.Add(DownloadJob("NASA Mars Documentary", "68%", "6.4 MB/s", "02:11", "RUNNING", "#6A4C6F", "#C34B4B"));
        list.Children.Add(DownloadJob("Python Basics", "32%", "1.4 MB/s", "08:21", "RUNNING", "#325B82", "#1C263C"));
        root.Children.Add(Card(list, new Thickness(0, 0, 10, 0), new Thickness(10)));
        var log = LiveLogPanel(); Grid.SetColumn(log, 1); root.Children.Add(log); return root;
    }

    UIElement UnifiedHistory(string heading)
    {
        var root = new Grid();
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        var top = new Grid(); top.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); top.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        top.Children.Add(T(heading, 18, Text, FontWeights.Bold));
        var f = H(Combo("All activity", "Downloads", "AI", "Library", "Subscriptions", "Operations"), Combo("Today", "7 days", "30 days", "All time")); Grid.SetColumn(f, 1); top.Children.Add(f); root.Children.Add(top);
        var dg = MakeGrid(); dg.Margin = new Thickness(0, 10, 0, 0);
        dg.ItemsSource = new[]
        {
            new { Time="12:14", Type="Download", Item="NASA Mars Documentary", Action="Completed Full Library profile", Result="Success" },
            new { Time="12:09", Type="AI", Item="Python Basics", Action="Transcript + chapters + summary", Result="Completed" },
            new { Time="11:54", Type="Library", Item="The Future of AI", Action="Added to collection: AI Research", Result="Saved" },
            new { Time="11:31", Type="Subscription", Item="Kurzgesagt", Action="3 new videos discovered", Result="Review" },
            new { Time="10:48", Type="Operations", Item="Smart Resume Audit", Action="64 skip / 9 repair / 6 download", Result="Completed" }
        };
        Grid.SetRow(dg, 1); root.Children.Add(dg); return root;
    }

    UIElement CreateAI()
    {
        var root = new Grid(); root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        var pipeline = new UniformGrid { Columns = 8, Margin = new Thickness(0, 0, 0, 10) };
        foreach (var s in new[] { "Transcript", "Clean", "Translate", "Analyze", "Chapters", "Report", "Knowledge", "Embeddings" })
        {
            var box = new StackPanel();
            var accentColor = ((SolidColorBrush)Accent).Color;
            var circle = new Border { Width = 34, Height = 34, Background = new SolidColorBrush(Color.FromArgb(34, accentColor.R, accentColor.G, accentColor.B)), BorderBrush = Accent, BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(17), Child = T("✓", 15, Accent, FontWeights.Bold), HorizontalAlignment = HorizontalAlignment.Center };
            ((TextBlock)circle.Child).HorizontalAlignment = HorizontalAlignment.Center;
            box.Children.Add(circle); var tx = T(s, 12, Text, FontWeights.SemiBold); tx.HorizontalAlignment = HorizontalAlignment.Center; tx.Margin = new Thickness(0, 5, 0, 0); box.Children.Add(tx);
            pipeline.Children.Add(box);
        }
        root.Children.Add(Card(pipeline, new Thickness(0, 0, 0, 8), new Thickness(12)));

        var tabs = H(Btn("Jobs"), Btn("Results"), Btn("Review"), Btn("Packages"), Btn("Knowledge"), Btn("Ask AI"), Btn("Semantic Search"));
        Grid.SetRow(tabs, 1); root.Children.Add(tabs);
        var host = new ContentControl { Margin = new Thickness(0, 8, 0, 0) }; Grid.SetRow(host, 2); root.Children.Add(host);
        void Set(string view) => host.Content = view switch { "Review" => AIReview(), "Packages" => AIPackages(), "Knowledge" => AIKnowledge(), "Ask AI" => AIAsk(), "Semantic Search" => AISearch(), _ => AIJobs() };
        foreach (Button b in tabs.Children) { var v = b.Content?.ToString() ?? "Jobs"; b.Click += (_, _) => Set(v); }
        Set("Jobs"); return root;
    }

    UIElement AIJobs()
    {
        var root = new Grid(); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(380) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(360) });
        var jobs = new StackPanel(); jobs.Children.Add(T("AI jobs", 16, Text, FontWeights.Bold));
        jobs.Children.Add(DownloadJob("Climate Change — Full Course", "70%", "Local Ollama", "12m left", "RUNNING", "#4D6A82", "#4A547A"));
        jobs.Children.Add(DownloadJob("History of the Internet", "40%", "Translation", "6m left", "RUNNING", "#4A617B", "#203D65"));
        jobs.Children.Add(DownloadJob("NASA Mars Documentary", "100%", "Validated", "Completed", "DONE", "#704A61", "#B34A4C"));
        root.Children.Add(Card(jobs, new Thickness(0, 0, 10, 0), new Thickness(10)));
        var middle = new StackPanel(); middle.Children.Add(T("Selected job pipeline", 17, Text, FontWeights.Bold));
        foreach (var row in new[] { "✓ Extract audio", "✓ Transcribe", "● Clean transcript", "○ Translate (English)", "○ Analyze topics / people / places", "○ Generate chapters", "○ Create report" }) middle.Children.Add(Card(T(row, 13), new Thickness(0, 7, 0, 0), new Thickness(10)));
        Grid.SetColumn(middle, 1); root.Children.Add(middle);
        var side = new StackPanel { Margin = new Thickness(10, 0, 0, 0) }; side.Children.Add(T("AI settings", 16, Text, FontWeights.Bold));
        side.Children.Add(H(T("Local Ollama", 12, Text, FontWeights.SemiBold), Badge("Available", "good")));
        side.Children.Add(H(T("ChatGPT exchange", 12, Text, FontWeights.SemiBold), Badge("Available", "good")));
        side.Children.Add(H(T("Cloud API direct", 12, Text, FontWeights.SemiBold), Badge("Needs setup", "warn")));
        side.Children.Add(Card(T("Model: qwen2.5:7b\nValidation: enabled\nRetry on failure: enabled\nStructured data: enabled\nComments intelligence: enabled", 12), new Thickness(0, 10, 0, 0), new Thickness(12)));
        var sideCard = Card(side, new Thickness(10, 0, 0, 0), new Thickness(12)); Grid.SetColumn(sideCard, 2); root.Children.Add(sideCard); return root;
    }

    UIElement AIReview()
    {
        var root = new Grid(); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(360) });
        var dg = MakeGrid(); dg.ItemsSource = new[]
        {
            new { Select="☑", Package="pkg_20261002_01", Video="NASA Mars Documentary", English="PASS", Timestamps="96%", Quality="92", Status="Ready" },
            new { Select="☑", Package="pkg_20261002_01", Video="Python Basics", English="PASS", Timestamps="88%", Quality="81", Status="Review" },
            new { Select="☐", Package="pkg_20261002_02", Video="Old Lecture Series", English="WARN", Timestamps="61%", Quality="68", Status="Retry" }
        }; root.Children.Add(dg);
        var side = new StackPanel(); side.Children.Add(T("Review decision", 16, Text, FontWeights.Bold)); side.Children.Add(T("Validate imported ChatGPT results before applying titles, taxonomy, chapters and structured intelligence.", 12, Muted));
        side.Children.Add(Card(T("Warnings\n• Timestamp coverage below preferred threshold\n• One generated section contains mixed-language prose\n\nRecommended action: retry only this video in a smaller package.", 12), new Thickness(0, 10, 0, 0), new Thickness(12)));
        side.Children.Add(H(Btn("Accept selected", true), Btn("Retry selected"), Btn("Reject")));
        var reviewCard = Card(side, new Thickness(10, 0, 0, 0), new Thickness(12)); Grid.SetColumn(reviewCard, 1); root.Children.Add(reviewCard); return root;
    }

    UIElement AIPackages()
    {
        var root = new Grid(); root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        var top = H(Btn("Create package", true), Btn("Import results"), Btn("Validate all"), Btn("Retry failed"), Btn("Open exchange folder")); root.Children.Add(top);
        var dg = MakeGrid(); dg.Margin = new Thickness(0, 9, 0, 0); dg.ItemsSource = new[]
        {
            new { Package="pkg_20261002_01", Videos=8, Features="Summary, Chapters, Taxonomy", Status="Imported", Quality="Clean", Updated="10:48" },
            new { Package="pkg_20261002_02", Videos=5, Features="Full Intelligence", Status="Needs review", Quality="1 warning", Updated="10:12" },
            new { Package="pkg_retry_17", Videos=1, Features="Transcript + Chapters", Status="Outgoing", Quality="Pending", Updated="09:54" }
        }; Grid.SetRow(dg, 1); root.Children.Add(dg); return root;
    }

    UIElement AIKnowledge()
    {
        var root = new StackPanel(); root.Children.Add(T("Knowledge layer", 18, Text, FontWeights.Bold)); root.Children.Add(T("Existing VideoHoarder search indexes, topic intelligence, collections and semantic layer are surfaced here without adding another main mode.", 13, Muted));
        var cards = new UniformGrid { Columns = 4, Margin = new Thickness(0, 12, 0, 0) };
        foreach (var x in new[] { ("Phase 5 index", "1,248 videos", "good"), ("Phase 6 chunks", "18,432 chunks", "good"), ("Embeddings", "Current", "good"), ("Answer cache", "342 entries", "neutral") }) cards.Children.Add(Card(H(T(x.Item1 + "\n" + x.Item2, 13, Text, FontWeights.SemiBold), Badge(x.Item3 == "good" ? "Healthy" : "Ready", x.Item3)), new Thickness(0, 0, 10, 0), new Thickness(12)));
        root.Children.Add(cards); return root;
    }

    UIElement AIAsk()
    {
        var root = new Grid(); root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        var input = Input("Ask your library: What did the videos say about agent memory and tool use?", 44); root.Children.Add(input);
        var answer = Card(T("Answer preview\n\nAcross 6 matching videos, agent memory is described as a combination of short-lived conversation state, external stores, and retrieval. Tool use is treated separately as action execution.\n\nEvidence\n• AI Agents Explained — 06:48 Tools & memory\n• Python Agent Tutorial — 14:22 Persistent state\n• Local LLM Workflow — 22:10 Retrieval layer", 14), new Thickness(0, 10, 0, 0), new Thickness(18)); Grid.SetRow(answer, 1); root.Children.Add(answer); return root;
    }

    UIElement AISearch()
    {
        var root = new StackPanel(); root.Children.Add(Input("Semantic search across transcripts, chapters, summaries, tags and structured intelligence…", 44));
        root.Children.Add(Card(T("6 semantic matches\n\nAI Agents Explained — 06:48 Tools & memory\nPython Agent Tutorial — 14:22 Persistent state\nLocal LLM Workflow — 22:10 Retrieval layer\nHistory of the Internet — 18:04 Search indexes", 13), new Thickness(0, 10, 0, 0), new Thickness(14))); return root;
    }

    UIElement CreateLibrary()
    {
        var root = new Grid(); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(220) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(340) });
        var left = new StackPanel(); left.Children.Add(T("Saved views", 15, Text, FontWeights.Bold));
        foreach (var v in new[] { "All Videos        1,248", "New This Week       34", "Unwatched          318", "Missing Transcript  46", "AI Complete        992", "Favorites           42", "Failed              18", "Archived           120" }) left.Children.Add(Btn(v, v.StartsWith("All"), 190, 32));
        left.Children.Add(T("Tags", 14, Text, FontWeights.Bold));
        foreach (var v in new[] { "Education 342", "Technology 284", "Science 198", "Documentary 176", "Music 64", "Gaming 52", "News 48" }) left.Children.Add(T("  " + v, 12, Muted));
        root.Children.Add(Card(left, new Thickness(0, 0, 10, 0), new Thickness(10)));

        var middle = new Grid(); middle.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); middle.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); middle.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var search = new Grid(); search.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); search.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto }); search.Children.Add(Input("Search library, transcript, chapters, tags, AI summary…", 38));
        var view = H(Btn("Grid"), Btn("List"), Btn("Table"), Combo("Recently added", "Title A-Z", "Channel", "Rating"), Btn("Filter")); Grid.SetColumn(view, 1); search.Children.Add(view); middle.Children.Add(search);
        var wrap = new WrapPanel { Margin = new Thickness(0, 10, 0, 0) };
        foreach (var x in new[] { ("NASA Mars Documentary", "Science", "#6D4C5F", "#C34B4B"), ("The Future of AI", "AI", "#484A9E", "#B14A72"), ("Python for Beginners", "Education", "#385F7B", "#233D63"), ("Climate Change", "Science", "#3C6C7A", "#365B3F"), ("Beautiful Places in Japan", "Travel", "#4D7186", "#5B5A85"), ("SpaceX Starship Updates", "Space", "#5F475C", "#66342F"), ("History of the Internet", "Technology", "#5B4B3A", "#364C69"), ("Machine Learning Basics", "AI", "#2E5C5C", "#313F78") })
        {
            var card = new StackPanel(); card.Children.Add(Thumbnail(x.Item1, x.Item3, x.Item4, 190, 104)); var n = T("☑  " + x.Item1, 12, Text, FontWeights.SemiBold); n.Width = 190; n.Margin = new Thickness(0, 6, 0, 2); card.Children.Add(n); card.Children.Add(H(Badge(x.Item2), Badge("AI", "good"))); wrap.Children.Add(Card(card, new Thickness(0, 0, 8, 8), new Thickness(7)));
        }
        var scroll = new ScrollViewer { Content = wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto }; Grid.SetRow(scroll, 1); middle.Children.Add(scroll);
        var bulk = H(T("3 selected", 12, Muted), Btn("Play"), Btn("Add to collection"), Btn("Run AI pipeline"), Btn("Export"), Btn("Move to…"), Btn("Delete")); bulk.Margin = new Thickness(0, 8, 0, 0); Grid.SetRow(bulk, 2); middle.Children.Add(bulk);
        Grid.SetColumn(middle, 1); root.Children.Add(middle);

        var side = new StackPanel(); side.Children.Add(Thumbnail("NASA Mars Documentary", "#704A61", "#B34A4C", 300, 166)); side.Children.Add(T("NASA Mars Documentary", 16, Text, FontWeights.Bold)); side.Children.Add(H(Badge("Downloaded", "good"), Badge("AI complete", "good")));
        var tabs = H(Btn("Overview"), Btn("Player"), Btn("Transcript"), Btn("Chapters"), Btn("AI"), Btn("Files"), Btn("History")); tabs.Margin = new Thickness(0, 8, 0, 0); side.Children.Add(new ScrollViewer { Content = tabs, HorizontalScrollBarVisibility = ScrollBarVisibility.Auto });
        side.Children.Add(T("A comprehensive look at NASA's Mars exploration, including mission context, rover capabilities, major discoveries and evidence-backed chapter summaries.\n\nRating  ★★★★☆\nCategory  Science / Space\nTags  Mars, NASA, Rover, Exploration\nSubtitles  English, Hindi\nAI status  Completed\nChapters  12", 12, Muted));
        var collapse = Btn("Collapse inspector"); collapse.Click += (_, _) => ((ColumnDefinition)root.ColumnDefinitions[2]).Width = new GridLength(0); side.Children.Add(collapse);
        var inspectorCard = Card(side, new Thickness(10, 0, 0, 0), new Thickness(10)); Grid.SetColumn(inspectorCard, 2); root.Children.Add(inspectorCard); return root;
    }

    UIElement CreateSubscriptions()
    {
        var root = new Grid(); root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        var providers = H(Btn("YouTube"), Badge("Available", "good"), Btn("Udemy"), Badge("Planned", "planned"), Btn("RSS / Web"), Badge("Planned", "planned")); root.Children.Add(providers);
        var controls = new Grid { Margin = new Thickness(0, 8, 0, 8) }; controls.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); controls.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto }); controls.Children.Add(Input("Search channels / sources…", 36));
        var right = H(Btn("Add YouTube source", true), Btn("Check selected"), Btn("Bulk rule"), Btn("Export plan")); Grid.SetColumn(right, 1); controls.Children.Add(right); Grid.SetRow(controls, 1); root.Children.Add(controls);
        var dg = MakeGrid(); dg.ItemsSource = new[]
        {
            new { Select="☑", Source="NASA", Type="Channel", Status="Available", New=1, Downloaded=124, Rule="Download + AI", LastChecked="2 hours ago" },
            new { Select="☑", Source="Veritasium", Type="Channel", Status="Available", New=2, Downloaded=87, Rule="Auto-download", LastChecked="4 hours ago" },
            new { Select="☐", Source="Kurzgesagt", Type="Channel", Status="Available", New=0, Downloaded=64, Rule="Review first", LastChecked="1 day ago" },
            new { Select="☐", Source="Fireship", Type="Channel", Status="Available", New=1, Downloaded=98, Rule="Auto-download", LastChecked="5 hours ago" },
            new { Select="☐", Source="3Blue1Brown", Type="Channel", Status="Available", New=0, Downloaded=42, Rule="Download + AI", LastChecked="1 day ago" },
            new { Select="☐", Source="Lex Fridman", Type="Channel", Status="Available", New=1, Downloaded=112, Rule="Review first", LastChecked="3 hours ago" }
        }; Grid.SetRow(dg, 2); root.Children.Add(dg); return root;
    }

    UIElement CreateChapters()
    {
        var root = new Grid(); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(155) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(430) });
        var preview = new Border { Background = B("#070A0F"), CornerRadius = new CornerRadius(8), Margin = new Thickness(0, 0, 10, 0) };
        var pv = new Grid(); var ptxt = T("▶\n\nNASA Mars Documentary\n00:12:34 / 00:45:12", 18, Brushes.White, FontWeights.SemiBold); ptxt.HorizontalAlignment = HorizontalAlignment.Center; ptxt.VerticalAlignment = VerticalAlignment.Center; ptxt.TextAlignment = TextAlignment.Center; pv.Children.Add(ptxt); preview.Child = pv; root.Children.Add(preview);
        var side = new StackPanel(); side.Children.Add(H(T("Chapters", 18, Text, FontWeights.Bold), Badge("AI Generated", "good")));
        side.Children.Add(H(Btn("Chapters"), Btn("Templates"), Btn("Inspector"), Btn("Import / Export")));
        var dg = MakeGrid(); dg.Height = 380; dg.ItemsSource = new[] { new { Time="00:00", Title="Introduction", State="✓" }, new { Time="02:14", Title="Early Discoveries", State="✓" }, new { Time="06:32", Title="Mars Environment", State="✓" }, new { Time="12:34", Title="Analysis & Discussion", State="●" }, new { Time="18:20", Title="The Rovers", State="✓" }, new { Time="24:10", Title="Expert Opinions", State="✓" }, new { Time="28:45", Title="Conclusion", State="✓" } }; side.Children.Add(dg);
        side.Children.Add(H(Btn("Add Chapter"), Btn("Split"), Btn("Merge"), Btn("AI Chapters", true), Btn("Save Template"))); Grid.SetColumn(side, 1); root.Children.Add(side);
        var timeline = new StackPanel { Margin = new Thickness(0, 10, 10, 0) }; timeline.Children.Add(T("Timeline • reusable chapter templates • drag boundaries • timestamp snapping", 12, Muted));
        var bar = new Border { Height = 74, Background = B("#DCE7F7"), CornerRadius = new CornerRadius(6), Margin = new Thickness(0, 8, 0, 0) }; bar.Child = T("00:00     ▌ Intro ▌──── Early Discoveries ────▌ Mars Environment ▌──── Analysis & Discussion ────▌ Rovers ▌──── Conclusion     45:12", 12, B("#27466B"), FontWeights.SemiBold); timeline.Children.Add(bar); Grid.SetRow(timeline, 1); root.Children.Add(timeline); return root;
    }

    UIElement CreateOperations()
    {
        var root = new Grid(); root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        var stats = new UniformGrid { Columns = 5 };
        foreach (var x in new[] { ("Library Health", "98%", "good"), ("Failed Items", "4", "danger"), ("Missing Data", "12", "warn"), ("Duplicates", "3", "neutral"), ("Zero-byte Files", "0", "good") })
        {
            var s = new StackPanel(); s.Children.Add(T(x.Item1, 12, Muted)); s.Children.Add(T(x.Item2, 22, x.Item3 == "good" ? Good : x.Item3 == "warn" ? Warn : x.Item3 == "danger" ? Danger : Blue, FontWeights.Bold)); stats.Children.Add(Card(s, new Thickness(0, 0, 9, 0), new Thickness(12)));
        }
        root.Children.Add(stats);
        var tabs = H(Btn("Maintenance"), Btn("Diagnostics"), Btn("Rebuild & Export"), Btn("Dependencies"), Btn("Logs"), Btn("History")); tabs.Margin = new Thickness(0, 10, 0, 8); Grid.SetRow(tabs, 1); root.Children.Add(tabs);
        var host = new ContentControl(); Grid.SetRow(host, 2); root.Children.Add(host);
        void Set(string view) => host.Content = view switch { "Dependencies" => DependenciesView(), "History" => UnifiedHistory("Unified application history"), "Diagnostics" => DiagnosticsView(), "Rebuild & Export" => RebuildView(), "Logs" => LogsView(), _ => MaintenanceView() };
        foreach (Button b in tabs.Children) { var v = b.Content?.ToString() ?? "Maintenance"; b.Click += (_, _) => Set(v); }
        Set("Maintenance"); return root;
    }

    UIElement MaintenanceView()
    {
        var root = new Grid(); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(230) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(360) });
        var left = new StackPanel(); left.Children.Add(T("Maintenance & tools", 15, Text, FontWeights.Bold)); foreach (var x in new[] { "Import & Repair", "Smart Resume Audit", "Missing Data", "Duplicates", "Cleanup", "Library Health", "Failure History", "Recovery Center" }) left.Children.Add(Btn(x, x == "Missing Data", 200, 34)); root.Children.Add(Card(left, new Thickness(0, 0, 10, 0), new Thickness(10)));
        var dg = MakeGrid(); dg.ItemsSource = new[] { new { Video="Interview with Elon Musk", Issue="HTTP 429 Too Many Requests", Count=3, LastAttempt="2 hours ago" }, new { Video="DeepMind AI Safety", Issue="Video unavailable", Count=2, LastAttempt="1 day ago" }, new { Video="Old Lecture Series", Issue="FFmpeg invalid data", Count=1, LastAttempt="5 hours ago" }, new { Video="Cooking with Science", Issue="Private video / login required", Count=4, LastAttempt="2 days ago" } }; Grid.SetColumn(dg, 1); root.Children.Add(dg);
        var side = new StackPanel(); side.Children.Add(T("Preview → Apply → Undo", 17, Text, FontWeights.Bold)); side.Children.Add(H(Badge("Safe workflow", "good"), Badge("No automatic delete", "warn"))); side.Children.Add(Card(T("Selected issue\nHTTP 429 Too Many Requests\n\nPreviewed changes\n1. Wait and retry (recommended)\n2. Try cookies from configured browser\n3. Reduce fragment concurrency for this job\n4. Preserve current files and failure history\n\nNo change has been applied yet.", 12), new Thickness(0, 10, 0, 0), new Thickness(12)));
        var preview = Btn("Preview Fix"); var apply = Btn("Apply Fix", true); var undo = Btn("Undo"); preview.Click += (_, _) => Toast("Preview refreshed — no files changed"); apply.Click += (_, _) => Toast("Prototype only — change recorded in mock history"); undo.Click += (_, _) => Toast("Prototype undo preview"); side.Children.Add(H(preview, apply, undo)); var repairCard = Card(side, new Thickness(10, 0, 0, 0), new Thickness(12)); Grid.SetColumn(repairCard, 2); root.Children.Add(repairCard); return root;
    }

    UIElement DependenciesView()
    {
        var root = new StackPanel(); root.Children.Add(T("Portable tools status", 18, Text, FontWeights.Bold)); root.Children.Add(T("Every required runtime stays inside the application/tools area. Version checks and setup remain visible without exposing a command prompt.", 13, Muted));
        var dg = MakeGrid(); dg.Margin = new Thickness(0, 10, 0, 0); dg.ItemsSource = new[]
        {
            new { Tool="yt-dlp", Version="nightly 2026.09.27", Status="Ready", Location="tools/yt-dlp.exe", Action="Check update" },
            new { Tool="FFmpeg", Version="7.x", Status="Ready", Location="tools/ffmpeg/bin", Action="Verify" },
            new { Tool="Deno", Version="2.x", Status="Ready", Location="tools/deno.exe", Action="Verify" },
            new { Tool="Ollama", Version="Local", Status="Ready", Location="tools/ollama", Action="Test model" },
            new { Tool="Python packages", Version="Bundled", Status="Ready", Location="tools/python_packages", Action="Audit" },
            new { Tool="Selenium", Version="Optional", Status="Needs setup", Location="tools/python_packages", Action="Install portable" }
        }; root.Children.Add(dg); return root;
    }

    UIElement DiagnosticsView()
    {
        var root = new WrapPanel(); foreach (var x in new[] { ("Full Diagnostics", "System, paths, dependencies and configuration"), ("Phase 0 Self-Test", "Core library integrity and startup checks"), ("Path Audit", "Windows path lengths and folder compatibility"), ("Original Title Audit", "Markers and references"), ("Staging Audit", "Incomplete staged media/transcripts"), ("Package Integrity", "ChatGPT package/result linkage") }) { var s = new StackPanel { Width = 280 }; s.Children.Add(T(x.Item1, 15, Text, FontWeights.Bold)); s.Children.Add(T(x.Item2, 12, Muted)); s.Children.Add(Btn("Run preview")); root.Children.Add(Card(s, new Thickness(0, 0, 10, 10), new Thickness(12))); } return root;
    }

    UIElement RebuildView()
    {
        var root = new WrapPanel(); foreach (var x in new[] { "Rebuild HTML Reports", "Build / Refresh Library Indexes", "Export video_list.csv", "Export ChatGPT Titles CSV", "Export Structured Content Cards", "Refresh Knowledge Layer", "Refresh Semantic Embeddings", "Repair Broken HTML Video Links" }) { var s = new StackPanel { Width = 260 }; s.Children.Add(T(x, 14, Text, FontWeights.Bold)); s.Children.Add(T("Preview impact before running.", 11, Muted)); s.Children.Add(H(Btn("Preview"), Btn("Queue"))); root.Children.Add(Card(s, new Thickness(0, 0, 10, 10), new Thickness(12))); } return root;
    }

    UIElement LogsView()
    {
        var root = new Grid(); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(250) }); root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var left = new StackPanel(); foreach (var x in new[] { "Application log", "GUI log", "yt-dlp failures", "FFmpeg", "ChatGPT package history", "Repair history" }) left.Children.Add(Btn(x, x == "Application log", 220, 34)); root.Children.Add(left);
        var log = new TextBox { IsReadOnly = true, AcceptsReturn = true, FontFamily = new FontFamily("Consolas"), FontSize = 12, Background = B("#080B10"), Foreground = B("#D9E4FF"), Padding = new Thickness(12), Text = "2026-10-02 12:14:03 | INFO | Download queue ready\n2026-10-02 12:14:05 | INFO | Smart Resume classified 79 video IDs\n2026-10-02 12:14:08 | INFO | AI package validation complete\n2026-10-02 12:14:10 | WARN | One subscription source requires login\n2026-10-02 12:14:12 | INFO | Library health 98%" }; Grid.SetColumn(log, 1); root.Children.Add(log); return root;
    }

    DataGrid MakeGrid()
    {
        return new DataGrid
        {
            AutoGenerateColumns = true,
            IsReadOnly = true,
            HeadersVisibility = DataGridHeadersVisibility.Column,
            Background = Panel,
            Foreground = Text,
            BorderBrush = Border,
            RowBackground = Panel,
            AlternatingRowBackground = Panel2,
            GridLinesVisibility = DataGridGridLinesVisibility.Horizontal,
            HorizontalGridLinesBrush = Border,
            VerticalGridLinesBrush = Brushes.Transparent,
            CanUserAddRows = false,
            CanUserDeleteRows = false,
            SelectionMode = DataGridSelectionMode.Extended,
            SelectionUnit = DataGridSelectionUnit.FullRow
        };
    }

    void ShowTopMenu(Button anchor, string menuName)
    {
        var menu = new ContextMenu { PlacementTarget = anchor, Placement = PlacementMode.Bottom };
        void Add(string text, Action action, bool check = false)
        {
            var item = new MenuItem { Header = text, IsCheckable = check, Foreground = Brushes.Black };
            item.Click += (_, _) => action(); menu.Items.Add(item);
        }
        if (menuName == "File")
        {
            Add("New Download", () => ShowMode("Download"));
            Add("Import URLs / file…", ShowBatchDialog);
            Add("Open portable folder", () => Toast("Prototype folder action"));
            menu.Items.Add(new Separator());
            Add("Exit", Close);
        }
        else if (menuName == "Downloads")
        {
            Add("Pause All Downloads", () => Toast("Paused (prototype)"));
            Add("Resume All Downloads", () => Toast("Resumed (prototype)"));
            Add("Restart All Failed Downloads", () => Toast("Retry queued (prototype)"));
            Add("Auto-Clear Completed Downloads", () => Toast("Auto-clear toggled"), true);
            menu.Items.Add(new Separator());
            Add("Clear Completed / Failed", () => Toast("Preview cleanup first"));
            Add("Cancel All In Progress", () => Toast("Cancel preview"));
        }
        else
        {
            Add("Command Palette   Ctrl+K", ShowCommandPalette);
            Add("Global Activity", ShowActivityDrawer);
            Add("Unified History", () => ShowStandalone("Unified History", UnifiedHistory("Unified application history"), 1050, 650));
            Add("Notification Center", ShowNotifications);
            Add("Keyboard Shortcuts", ShowShortcuts);
            Add("Portable Tools Status", () => ShowStandalone("Portable Tools", DependenciesView(), 980, 620));
            Add("Preview App States", ShowStateChooser);
            Add("Settings", ShowSettings);
        }
        menu.IsOpen = true;
    }

    void ShowDownloadOptions()
    {
        var win = CreateDialog("Download Options — profiles and advanced settings", 880, 690);
        var root = new Grid { Margin = new Thickness(18) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.Children.Add(T("Download Options", 22, Text, FontWeights.Bold));
        var body = new Grid { Margin = new Thickness(0, 14, 0, 14) }; body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(180) }); body.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var sections = new StackPanel(); foreach (var x in new[] { "General", "Formats & Quality", "Subtitles & Captions", "Extraction & Cookies", "Queue & Performance", "Automation", "File Naming", "Network & Advanced" }) sections.Children.Add(Btn(x, x == "General", 165, 34)); body.Children.Add(sections);
        var content = new StackPanel { Margin = new Thickness(16, 0, 0, 0) }; content.Children.Add(T("Profiles", 16, Text, FontWeights.Bold));
        var profiles = new UniformGrid { Columns = 4, Margin = new Thickness(0, 8, 0, 12) };
        foreach (var p in new[] { ("Full Library", "Best quality + metadata"), ("Fast Download", "Quick, reliable"), ("Transcript Only", "Text + transcript"), ("AI Research", "Video + AI analysis") })
        { var s = new StackPanel(); s.Children.Add(T(p.Item1, 13, Text, FontWeights.Bold)); s.Children.Add(T(p.Item2, 11, Muted)); profiles.Children.Add(Card(s, new Thickness(0, 0, 8, 0), new Thickness(10))); }
        content.Children.Add(profiles);
        content.Children.Add(H(T("Quality", 12, Muted), Combo("Best available", "1080p", "720p", "480p"), T("  Container", 12, Muted), Combo("Auto", "MP4", "MKV")));
        content.Children.Add(H(Check("Download subtitles", true), Check("Save SRT", true), Check("Save VTT", true), Check("Capture comments")));
        content.Children.Add(H(Check("Smart Resume", true), Check("Resolve embedded video URL"), Check("Use cookies/browser fallback", true)));
        content.Children.Add(H(T("Queue workers", 12, Muted), Combo("3", "1", "2", "4", "5"), T("  Parallel videos", 12, Muted), Combo("3", "1", "2", "4", "5"), T("  Concurrent fragments", 12, Muted), Combo("8", "4", "6", "12", "16")));
        content.Children.Add(H(Check("Download thumbnail", true), Check("Write metadata / info JSON", true), Check("Prefix upload date"), Check("Post-download AI processing")));
        content.Children.Add(Card(T("Feature state\nYouTube downloads — Available\nExternal M3U8/HLS — Available\nUdemy provider integration — Planned\nBrowser-cookie fallback — Available\nYouTube 403 fallback/update ladder — Available", 12), new Thickness(0, 12, 0, 0), new Thickness(12)));
        Grid.SetColumn(content, 1); body.Children.Add(content); Grid.SetRow(body, 1); root.Children.Add(body);
        var buttons = H(Btn("Reset to defaults"), Btn("Cancel"), Btn("Apply", true)); buttons.HorizontalAlignment = HorizontalAlignment.Right; ((Button)buttons.Children[1]).Click += (_, _) => win.Close(); ((Button)buttons.Children[2]).Click += (_, _) => win.Close(); Grid.SetRow(buttons, 2); root.Children.Add(buttons); win.Content = root; win.ShowDialog();
    }

    void ShowActivityDrawer()
    {
        var win = CreateDialog("Global Activity", 620, 610);
        win.WindowStartupLocation = WindowStartupLocation.CenterOwner;
        var root = new StackPanel { Margin = new Thickness(16) }; root.Children.Add(H(T("Global Activity", 21, Text, FontWeights.Bold), Badge("Downloads 3", "good"), Badge("AI jobs 2"), Badge("Warnings 1", "warn")));
        root.Children.Add(T("Cross-mode running work", 12, Muted));
        foreach (var x in new[] { ("NASA Mars Documentary", "Download", "68% • 6.4 MB/s • 2m 11s"), ("Python Basics", "Download", "32% • 1.4 MB/s • 8m 21s"), ("Climate Change — Full Course", "AI", "Analyze chapters • 70%"), ("Subscription scan — NASA", "Subscription", "Checking 124 items"), ("Smart Resume audit", "Operations", "79 video IDs classified") })
        { var g = new Grid(); g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(160) }); var s = new StackPanel(); s.Children.Add(T(x.Item1, 13, Text, FontWeights.SemiBold)); s.Children.Add(T(x.Item2, 11, Muted)); g.Children.Add(s); var state = T(x.Item3, 11, Blue); Grid.SetColumn(state, 1); g.Children.Add(state); root.Children.Add(Card(g, new Thickness(0, 9, 0, 0), new Thickness(11))); }
        root.Children.Add(H(Btn("Pause all"), Btn("Open Queue", true), Btn("View history"))); win.Content = root; win.ShowDialog();
    }

    void ShowNotifications()
    {
        var win = CreateDialog("Notifications", 520, 560); var root = new StackPanel { Margin = new Thickness(16) }; root.Children.Add(H(T("Notifications", 21, Text, FontWeights.Bold), Badge("3 unread", "warn")));
        foreach (var x in new[] { ("Download completed", "Beautiful Places in Japan is ready in Library.", "good"), ("AI review required", "Package pkg_20261002_02 has one validation warning.", "warn"), ("Subscription discoveries", "NASA and Veritasium have 3 new videos.", "neutral"), ("Health check", "Library health is 98%; 12 missing-data items need review.", "warn") })
        { var s = new StackPanel(); s.Children.Add(H(T(x.Item1, 13, Text, FontWeights.Bold), Badge(x.Item3 == "good" ? "Done" : x.Item3 == "warn" ? "Attention" : "Info", x.Item3))); s.Children.Add(T(x.Item2, 12, Muted)); root.Children.Add(Card(s, new Thickness(0, 9, 0, 0), new Thickness(11))); }
        root.Children.Add(H(Btn("Mark all read"), Btn("Notification settings"))); win.Content = root; win.ShowDialog();
    }

    void ShowCommandPalette()
    {
        var win = CreateDialog("Command Palette", 760, 590); var root = new Grid { Margin = new Thickness(16) }; root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        var input = Input("Type a command or search…", 42); root.Children.Add(input);
        var list = new StackPanel { Margin = new Thickness(0, 10, 0, 0) };
        foreach (var x in new[] { ("Rebuild Reports", "Rebuild HTML reports for selected or all videos", "R"), ("Smart Resume Audit", "Check and repair interrupted downloads", "S"), ("Create ChatGPT Package", "Create a package with transcripts and metadata", "P"), ("Find Timestamp", "Search transcript text and jump to the matching time", "F"), ("Open Logs", "Show application logs", "L"), ("Preview First Run State", "Review onboarding screen", ""), ("Portable Tools Status", "Verify yt-dlp, FFmpeg, Deno, Ollama and Python packages", "") })
        { var g = new Grid(); g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(220) }); g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }); g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(40) }); g.Children.Add(T(x.Item1, 13, Text, FontWeights.SemiBold)); var d = T(x.Item2, 11, Muted); Grid.SetColumn(d, 1); g.Children.Add(d); var key = T(x.Item3, 11, Muted); Grid.SetColumn(key, 2); g.Children.Add(key); list.Children.Add(Card(g, new Thickness(0, 5, 0, 0), new Thickness(9))); }
        Grid.SetRow(list, 1); root.Children.Add(new ScrollViewer { Content = list }); win.Content = root; win.ShowDialog();
    }

    void ShowSettings()
    {
        var win = CreateDialog("Settings", 760, 650); var root = new StackPanel { Margin = new Thickness(18) }; root.Children.Add(T("Settings", 22, Text, FontWeights.Bold));
        root.Children.Add(Card(H(T("Appearance", 14, Text, FontWeights.Bold), Btn(darkMode ? "Switch to Light" : "Switch to Dark")), new Thickness(0, 12, 0, 0), new Thickness(12)));
        var themeButton = (Button)((StackPanel)((Border)root.Children[^1]).Child).Children[1]; themeButton.Click += (_, _) => { darkMode = !darkMode; win.Close(); BuildShell(); };
        var states = Combo("Normal", "First Run", "Empty", "Loading", "Offline"); states.SelectedItem = demoState; states.SelectionChanged += (_, _) => { demoState = states.SelectedItem?.ToString() ?? "Normal"; };
        root.Children.Add(Card(H(T("Preview app state", 14, Text, FontWeights.Bold), states), new Thickness(0, 10, 0, 0), new Thickness(12)));
        root.Children.Add(Card(H(T("Feature badges", 14, Text, FontWeights.Bold), Badge("Available", "good"), Badge("Experimental", "warn"), Badge("Planned", "planned"), Badge("Needs setup", "danger")), new Thickness(0, 10, 0, 0), new Thickness(12)));
        root.Children.Add(Card(T("Responsive behavior\n• Inspector drawers collapse on smaller windows\n• Split panes remain resizable\n• Splitter positions will be persisted in the production app\n• No permanent left navigation rail\n\nPrivacy / portability\n• Portable tool paths are relative to the application folder\n• No backend connection exists in this prototype", 12, Muted), new Thickness(0, 10, 0, 0), new Thickness(12)));
        var shortcuts = Btn("Keyboard shortcuts"); shortcuts.Click += (_, _) => ShowShortcuts(); root.Children.Add(shortcuts);
        var apply = Btn("Apply & refresh preview", true, 170, 38); apply.Margin = new Thickness(0, 12, 0, 0); apply.Click += (_, _) => { win.Close(); BuildShell(); }; root.Children.Add(apply); win.Content = root; win.ShowDialog();
    }

    void ShowShortcuts()
    {
        ShowSimpleDialog("Keyboard Shortcuts", "Ctrl+K    Command palette\nCtrl+L    Focus URL / download field\nCtrl+F    Search current mode\nCtrl+Shift+V    Paste / import from clipboard\nSpace     Pause / resume selected job\nF5        Refresh current view\nCtrl+H    Unified history\nCtrl+J    Global activity\nCtrl+,    Settings\nF1        Shortcut help");
    }

    void ShowStateChooser()
    {
        var win = CreateDialog("Preview application states", 500, 420); var root = new StackPanel { Margin = new Thickness(18) }; root.Children.Add(T("State previews", 21, Text, FontWeights.Bold)); root.Children.Add(T("These states are part of the design so the app never presents an unexplained blank screen.", 12, Muted));
        foreach (var s in new[] { "Normal", "First Run", "Empty", "Loading", "Offline" }) { var b = Btn(s, s == demoState, 180, 36); b.Margin = new Thickness(0, 8, 0, 0); b.Click += (_, _) => { demoState = s; win.Close(); ShowMode(currentMode); }; root.Children.Add(b); }
        win.Content = root; win.ShowDialog();
    }

    void ShowBatchDialog()
    {
        var win = CreateDialog("Batch import", 650, 500); var root = new StackPanel { Margin = new Thickness(18) }; root.Children.Add(T("Batch import / drag & drop", 21, Text, FontWeights.Bold)); root.Children.Add(T("Paste URLs, one per line, or drop a text/CSV file onto the main application window.", 12, Muted));
        root.Children.Add(new TextBox { Height = 270, AcceptsReturn = true, TextWrapping = TextWrapping.NoWrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Background = Panel, Foreground = Text, BorderBrush = Border, Padding = new Thickness(10), Text = "https://youtube.com/watch?v=example1\nhttps://youtube.com/playlist?list=example2\nhttps://example.com/stream.m3u8" }); root.Children.Add(H(Btn("Paste clipboard"), Btn("Import file"), Btn("Add all to queue", true))); win.Content = root; win.ShowDialog();
    }

    void ImportClipboard()
    {
        try
        {
            if (Clipboard.ContainsText() && urlBox != null) urlBox.Text = Clipboard.GetText();
            else Toast("Clipboard contains no text");
        }
        catch { Toast("Clipboard is unavailable"); }
    }

    void OnDrop(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            var files = (string[]?)e.Data.GetData(DataFormats.FileDrop);
            if (urlBox != null && files != null) urlBox.Text = string.Join(Environment.NewLine, files);
            Toast($"Imported {files?.Length ?? 0} dropped file(s) into the prototype");
        }
        else if (e.Data.GetDataPresent(DataFormats.Text))
        {
            var text = e.Data.GetData(DataFormats.Text)?.ToString() ?? "";
            if (urlBox != null) urlBox.Text = text;
            Toast("Dropped text imported");
        }
    }

    void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control) && e.Key == Key.K) { ShowCommandPalette(); e.Handled = true; }
        else if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control) && e.Key == Key.L) { ShowMode("Download"); Dispatcher.BeginInvoke(() => urlBox?.Focus()); e.Handled = true; }
        else if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control) && Keyboard.Modifiers.HasFlag(ModifierKeys.Shift) && e.Key == Key.V) { ImportClipboard(); e.Handled = true; }
        else if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control) && e.Key == Key.F) { Toast($"Search activated for {currentMode} mode"); e.Handled = true; }
        else if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control) && e.Key == Key.H) { ShowStandalone("Unified History", UnifiedHistory("Unified application history"), 1050, 650); e.Handled = true; }
        else if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control) && e.Key == Key.J) { ShowActivityDrawer(); e.Handled = true; }
        else if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control) && e.Key == Key.OemComma) { ShowSettings(); e.Handled = true; }
        else if (e.Key == Key.Space && currentMode == "Download") { Toast("Selected download pause / resume toggled (prototype)"); e.Handled = true; }
        else if (e.Key == Key.F1) { ShowShortcuts(); e.Handled = true; }
        else if (e.Key == Key.F5) { ShowMode(currentMode); e.Handled = true; }
    }

    Window CreateDialog(string title, double width, double height)
        => new()
        {
            Title = title,
            Owner = this,
            Width = width,
            Height = height,
            MinWidth = Math.Min(width, 500),
            MinHeight = Math.Min(height, 360),
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Background = Bg,
            Foreground = Text
        };

    void ShowStandalone(string title, UIElement content, double width, double height)
    {
        var win = CreateDialog(title, width, height); win.Content = new Border { Padding = new Thickness(16), Child = content }; win.ShowDialog();
    }

    void ShowSimpleDialog(string title, string body)
    {
        var win = CreateDialog(title, 560, 430); var root = new StackPanel { Margin = new Thickness(20) }; root.Children.Add(T(title, 21, Text, FontWeights.Bold)); root.Children.Add(T(body, 13, Muted)); var close = Btn("Close", true, 100, 36); close.Margin = new Thickness(0, 18, 0, 0); close.Click += (_, _) => win.Close(); root.Children.Add(close); win.Content = root; win.ShowDialog();
    }

    void Toast(string message)
    {
        status.Text = message;
        var timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(3) };
        timer.Tick += (_, _) => { timer.Stop(); status.Text = $"{currentMode} • {demoState} • UI prototype only"; };
        timer.Start();
    }
}