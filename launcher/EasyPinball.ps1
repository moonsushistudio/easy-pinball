# Easy Pinball: a simple game picker for Visual Pinball X.
. "$PSScriptRoot\PinballCommon.ps1"
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Easy Pinball" WindowState="Maximized" WindowStyle="None" ResizeMode="NoResize"
        Background="#0B0D12" Foreground="#E8EAF0" FontFamily="Segoe UI" FontSize="15">
  <Window.Resources>
    <SolidColorBrush x:Key="Gold" Color="#F5B301"/>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="#E8EAF0"/>
      <Setter Property="Background" Value="#1C212B"/>
      <Setter Property="BorderBrush" Value="#2C3340"/>
      <Setter Property="Padding" Value="16,9"/>
      <Setter Property="Margin" Value="0,0,10,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" CornerRadius="8" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#F5B301"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.35"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="PlayBtn" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#F5B301"/>
      <Setter Property="Foreground" Value="#101318"/>
      <Setter Property="BorderBrush" Value="#F5B301"/>
      <Setter Property="FontFamily" Value="Bahnschrift"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FontSize" Value="26"/>
      <Setter Property="Padding" Value="20,14"/>
      <Setter Property="Margin" Value="0"/>
    </Style>
  </Window.Resources>

  <Grid Margin="40,28,40,20">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="400"/>
    </Grid.ColumnDefinitions>

    <!-- Header -->
    <DockPanel Grid.ColumnSpan="2" Margin="0,0,0,20">
      <Button x:Name="CloseBtn" DockPanel.Dock="Right" Style="{StaticResource Btn}" Margin="0" Content="Close  (Esc)"/>
      <Button x:Name="SettingsBtn" DockPanel.Dock="Right" Style="{StaticResource Btn}" Content="Settings"/>
      <Button x:Name="ImportBtn" DockPanel.Dock="Right" Style="{StaticResource Btn}" Content="Import from Downloads"/>
      <Button x:Name="FolderBtn" DockPanel.Dock="Right" Style="{StaticResource Btn}" Content="Tables folder"/>
      <Button x:Name="AddBtn" DockPanel.Dock="Right" Style="{StaticResource Btn}" Content="Add a table  (Ctrl+F)"/>
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
        <Ellipse Width="34" Height="34" Margin="0,0,14,0">
          <Ellipse.Fill>
            <RadialGradientBrush GradientOrigin="0.35,0.3">
              <GradientStop Color="#FFFFFF" Offset="0"/>
              <GradientStop Color="#9AA3B2" Offset="0.55"/>
              <GradientStop Color="#3A404C" Offset="1"/>
            </RadialGradientBrush>
          </Ellipse.Fill>
        </Ellipse>
        <TextBlock Text="EASY PINBALL" FontFamily="Bahnschrift" FontWeight="Bold" FontSize="34" Foreground="{StaticResource Gold}" VerticalAlignment="Center"/>
        <TextBlock x:Name="Summary" Margin="20,6,0,0" Foreground="#8A93A6" VerticalAlignment="Center"/>
      </StackPanel>
    </DockPanel>

    <!-- Game grid -->
    <ListBox x:Name="Games" Grid.Row="1" Background="Transparent" BorderThickness="0" Foreground="#E8EAF0"
             ScrollViewer.HorizontalScrollBarVisibility="Disabled" KeyboardNavigation.DirectionalNavigation="Cycle">
      <ListBox.ItemsPanel>
        <ItemsPanelTemplate><WrapPanel/></ItemsPanelTemplate>
      </ListBox.ItemsPanel>
      <ListBox.ItemContainerStyle>
        <Style TargetType="ListBoxItem">
          <Setter Property="Margin" Value="0,0,12,12"/>
          <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
          <Setter Property="Template">
            <Setter.Value>
              <ControlTemplate TargetType="ListBoxItem">
                <Border x:Name="card" Width="134" Background="#151922" CornerRadius="12" BorderThickness="3" BorderBrush="Transparent" Cursor="Hand">
                  <ContentPresenter/>
                </Border>
                <ControlTemplate.Triggers>
                  <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="card" Property="BorderBrush" Value="#3A4252"/></Trigger>
                  <Trigger Property="IsSelected" Value="True"><Setter TargetName="card" Property="BorderBrush" Value="#F5B301"/></Trigger>
                </ControlTemplate.Triggers>
              </ControlTemplate>
            </Setter.Value>
          </Setter>
        </Style>
      </ListBox.ItemContainerStyle>
      <ListBox.ItemTemplate>
        <DataTemplate>
          <StackPanel>
            <Grid Height="150" ClipToBounds="True">
              <Border CornerRadius="9,9,0,0" Background="{Binding Fill}">
                <TextBlock Text="{Binding Initials}" FontFamily="Bahnschrift" FontWeight="Bold" FontSize="40" Foreground="#30FFFFFF"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <Image Source="{Binding Image}" Stretch="UniformToFill" VerticalAlignment="Top"/>
              <Border HorizontalAlignment="Left" VerticalAlignment="Top" Margin="7" CornerRadius="8" Padding="7,2" Background="{Binding PillBrush}">
                <TextBlock Text="{Binding Status}" FontSize="10" FontWeight="SemiBold" Foreground="#101318"/>
              </Border>
            </Grid>
            <StackPanel Margin="9,7,9,9">
              <TextBlock Text="{Binding Title}" FontFamily="Bahnschrift" FontWeight="SemiBold" FontSize="14" TextTrimming="CharacterEllipsis"/>
              <TextBlock Text="{Binding Sub}" Foreground="#8A93A6" FontSize="11" Margin="0,2,0,0"/>
              <TextBlock Text="{Binding BestText}" Foreground="{Binding BestBrush}" FontSize="12" FontWeight="SemiBold" Margin="0,5,0,0"/>
            </StackPanel>
          </StackPanel>
        </DataTemplate>
      </ListBox.ItemTemplate>
    </ListBox>

    <!-- Details -->
    <Border Grid.Row="1" Grid.Column="1" Background="#151922" CornerRadius="14" Padding="26" Margin="10,0,0,18">
      <DockPanel>
        <Button x:Name="PlayBtn" DockPanel.Dock="Bottom" Style="{StaticResource PlayBtn}" Content="PLAY"/>
        <StackPanel x:Name="Steps" DockPanel.Dock="Bottom" Margin="0,0,0,18"/>
        <Button x:Name="RemoveBtn" DockPanel.Dock="Bottom" Style="{StaticResource Btn}" HorizontalAlignment="Right" Margin="0,0,0,14"
                Padding="12,5" FontSize="12" Foreground="#8A93A6" Content="Remove from my list"/>
        <StackPanel>
          <Border x:Name="DFill" Height="90" CornerRadius="10" Margin="0,0,0,14" ClipToBounds="True">
            <Grid>
              <TextBlock x:Name="DInitials" FontFamily="Bahnschrift" FontWeight="Bold" FontSize="56" Foreground="#30FFFFFF"
                         HorizontalAlignment="Center" VerticalAlignment="Center"/>
              <Image x:Name="DImage" Stretch="UniformToFill" VerticalAlignment="Center"/>
            </Grid>
          </Border>
          <TextBlock x:Name="DTitle" FontFamily="Bahnschrift" FontWeight="Bold" FontSize="26" TextWrapping="Wrap"/>
          <TextBlock x:Name="DSub" Foreground="{StaticResource Gold}" FontSize="15" Margin="0,4,0,10"/>
          <TextBlock x:Name="DBlurb" TextWrapping="Wrap" Foreground="#B9C0CE" LineHeight="20"/>
          <Border x:Name="ScoreBox" Background="#0F1218" CornerRadius="10" Padding="14,10" Margin="0,14,0,0">
            <StackPanel>
              <DockPanel>
                <TextBlock x:Name="DChamp" DockPanel.Dock="Right" Foreground="#8A93A6" FontSize="12" VerticalAlignment="Bottom" Margin="0,0,0,4"/>
                <TextBlock Text="YOUR BEST" Foreground="#8A93A6" FontSize="11" FontWeight="SemiBold"/>
              </DockPanel>
              <TextBlock x:Name="DBest" FontFamily="Bahnschrift" FontWeight="Bold" FontSize="28" Foreground="{StaticResource Gold}"/>
              <TextBlock x:Name="DBestInfo" Foreground="#8A93A6" FontSize="12" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>
        </StackPanel>
      </DockPanel>
    </Border>

    <!-- Controls cheat sheet -->
    <Border Grid.Row="2" Grid.ColumnSpan="2" Background="#11141B" CornerRadius="10" Padding="18,12">
      <DockPanel>
        <TextBlock x:Name="Status" DockPanel.Dock="Right" Foreground="#8A93A6" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" MaxWidth="700"/>
        <WrapPanel x:Name="Keys" VerticalAlignment="Center"/>
      </DockPanel>
    </Border>

    <!-- Add a table: search the Virtual Pinball Spreadsheet -->
    <Grid x:Name="Search" Grid.RowSpan="3" Grid.ColumnSpan="2" Margin="-40,-28,-40,-20" Background="#E60B0D12" Visibility="Collapsed">
      <Border Width="860" Margin="0,70" Background="#151922" CornerRadius="14" Padding="26" HorizontalAlignment="Center">
        <DockPanel>
          <DockPanel DockPanel.Dock="Top" Margin="0,0,0,16">
            <Button x:Name="SearchClose" DockPanel.Dock="Right" Style="{StaticResource Btn}" Margin="0" Content="Back  (Esc)"/>
            <TextBlock Text="ADD A TABLE" FontFamily="Bahnschrift" FontWeight="Bold" FontSize="26" Foreground="{StaticResource Gold}" VerticalAlignment="Center"/>
          </DockPanel>
          <TextBox x:Name="SearchBox" DockPanel.Dock="Top" FontSize="20" Padding="12,8" Background="#0F1218" Foreground="#E8EAF0"
                   BorderBrush="#2C3340" CaretBrush="#F5B301"/>
          <TextBlock x:Name="SearchInfo" DockPanel.Dock="Top" Foreground="#8A93A6" FontSize="13" Margin="2,8,0,12" TextWrapping="Wrap"/>
          <DockPanel DockPanel.Dock="Bottom" Margin="0,16,0,0">
            <Button x:Name="SearchAdd" DockPanel.Dock="Right" Style="{StaticResource PlayBtn}" FontSize="18" Padding="22,10" Content="ADD TO MY LIST"/>
            <TextBlock Foreground="#8A93A6" FontSize="12" VerticalAlignment="Center" TextWrapping="Wrap" Margin="0,0,20,0"
                       Text="Table list from the Virtual Pinball Spreadsheet. Arrow keys + Enter, or double-click."/>
          </DockPanel>
          <ListBox x:Name="Results" Background="Transparent" BorderThickness="0" Foreground="#E8EAF0"
                   ScrollViewer.HorizontalScrollBarVisibility="Disabled">
            <ListBox.ItemContainerStyle>
              <Style TargetType="ListBoxItem">
                <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
                <Setter Property="Template">
                  <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                      <Border x:Name="row" Background="Transparent" CornerRadius="8" BorderThickness="2" BorderBrush="Transparent" Padding="12,7" Margin="0,0,0,4" Cursor="Hand">
                        <ContentPresenter/>
                      </Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="row" Property="Background" Value="#1C212B"/></Trigger>
                        <Trigger Property="IsSelected" Value="True"><Setter TargetName="row" Property="BorderBrush" Value="#F5B301"/><Setter TargetName="row" Property="Background" Value="#1C212B"/></Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Setter.Value>
                </Setter>
              </Style>
            </ListBox.ItemContainerStyle>
            <ListBox.ItemTemplate>
              <DataTemplate>
                <DockPanel>
                  <TextBlock DockPanel.Dock="Right" Text="{Binding Badge}" Foreground="#3DDC84" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
                  <StackPanel>
                    <TextBlock Text="{Binding Title}" FontFamily="Bahnschrift" FontWeight="SemiBold" FontSize="17"/>
                    <TextBlock Text="{Binding Sub}" Foreground="#8A93A6" FontSize="12" Margin="0,2,0,0"/>
                  </StackPanel>
                </DockPanel>
              </DataTemplate>
            </ListBox.ItemTemplate>
          </ListBox>
        </DockPanel>
      </Border>
    </Grid>

    <!-- Settings: brightness and camera tilt for every table -->
    <Grid x:Name="Settings" Grid.RowSpan="3" Grid.ColumnSpan="2" Margin="-40,-28,-40,-20" Background="#E60B0D12" Visibility="Collapsed">
      <Border Width="640" VerticalAlignment="Center" HorizontalAlignment="Center" Background="#151922" CornerRadius="14" Padding="30">
        <StackPanel>
          <DockPanel Margin="0,0,0,24">
            <Button x:Name="SettingsClose" DockPanel.Dock="Right" Style="{StaticResource Btn}" Margin="0" Content="Cancel  (Esc)"/>
            <TextBlock Text="SETTINGS" FontFamily="Bahnschrift" FontWeight="Bold" FontSize="26" Foreground="{StaticResource Gold}" VerticalAlignment="Center"/>
          </DockPanel>
          <DockPanel>
            <TextBlock x:Name="BrightValue" DockPanel.Dock="Right" FontFamily="Bahnschrift" FontWeight="SemiBold" FontSize="17" Foreground="{StaticResource Gold}"/>
            <TextBlock Text="Brightness" FontFamily="Bahnschrift" FontWeight="SemiBold" FontSize="17"/>
          </DockPanel>
          <Slider x:Name="Bright" Minimum="0.2" Maximum="1" SmallChange="0.05" LargeChange="0.1" TickFrequency="0.05" IsSnapToTickEnabled="True" Margin="0,10,0,2"/>
          <DockPanel Margin="0,0,0,26">
            <TextBlock DockPanel.Dock="Right" Text="Daylight" Foreground="#8A93A6" FontSize="12"/>
            <TextBlock Text="Night" Foreground="#8A93A6" FontSize="12"/>
          </DockPanel>
          <DockPanel>
            <TextBlock x:Name="TiltValue" DockPanel.Dock="Right" FontFamily="Bahnschrift" FontWeight="SemiBold" FontSize="17" Foreground="{StaticResource Gold}"/>
            <TextBlock Text="Camera tilt" FontFamily="Bahnschrift" FontWeight="SemiBold" FontSize="17"/>
          </DockPanel>
          <Slider x:Name="Tilt" Minimum="0" Maximum="50" SmallChange="1" LargeChange="5" TickFrequency="1" IsSnapToTickEnabled="True" Margin="0,10,0,2"/>
          <DockPanel Margin="0,0,0,26">
            <TextBlock DockPanel.Dock="Right" Text="Leaning back (VPX's usual view)" Foreground="#8A93A6" FontSize="12"/>
            <TextBlock Text="Straight down" Foreground="#8A93A6" FontSize="12"/>
          </DockPanel>
          <DockPanel>
            <TextBlock x:Name="EffectsValue" DockPanel.Dock="Right" FontFamily="Bahnschrift" FontWeight="SemiBold" FontSize="17" Foreground="{StaticResource Gold}"/>
            <TextBlock Text="Sound effects" FontFamily="Bahnschrift" FontWeight="SemiBold" FontSize="17"/>
          </DockPanel>
          <Slider x:Name="Effects" Minimum="0" Maximum="100" SmallChange="10" LargeChange="10" TickFrequency="10" IsSnapToTickEnabled="True" Margin="0,10,0,2"/>
          <DockPanel Margin="0,0,0,26">
            <TextBlock x:Name="EffectsHigh" DockPanel.Dock="Right" Text="Full" Foreground="#8A93A6" FontSize="12"/>
            <TextBlock x:Name="EffectsLow" Text="Flippers, ball, bumpers" Foreground="#8A93A6" FontSize="12"/>
          </DockPanel>
          <DockPanel>
            <TextBlock x:Name="MusicValue" DockPanel.Dock="Right" FontFamily="Bahnschrift" FontWeight="SemiBold" FontSize="17" Foreground="{StaticResource Gold}"/>
            <TextBlock Text="Music and voices" FontFamily="Bahnschrift" FontWeight="SemiBold" FontSize="17"/>
          </DockPanel>
          <!-- Above 100% the ticks are PinMAME's whole-dB boost steps (+1 ... +6 dB). -->
          <Slider x:Name="Music" Minimum="0" Maximum="200" SmallChange="10" LargeChange="10" IsSnapToTickEnabled="True" Margin="0,10,0,2"
                  Ticks="0,10,20,30,40,50,60,70,80,90,100,112,126,141,158,178,200"/>
          <DockPanel Margin="0,0,0,20">
            <TextBlock DockPanel.Dock="Right" Text="Over 100% is a boost and may crackle" Foreground="#8A93A6" FontSize="12"/>
            <TextBlock Text="The machine's own sound (100% = normal)" Foreground="#8A93A6" FontSize="12"/>
          </DockPanel>
          <TextBlock x:Name="SettingsNote" Foreground="#8A93A6" FontSize="13" TextWrapping="Wrap" LineHeight="19"/>
          <DockPanel Margin="0,24,0,0">
            <Button x:Name="SettingsSave" DockPanel.Dock="Right" Style="{StaticResource PlayBtn}" FontSize="18" Padding="30,10" Content="SAVE"/>
            <Button x:Name="SettingsReset" Style="{StaticResource Btn}" HorizontalAlignment="Left" Content="Defaults"/>
          </DockPanel>
        </StackPanel>
      </Border>
    </Grid>
  </Grid>
</Window>
'@

$win = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
$ui = @{}
foreach ($n in 'Games', 'PlayBtn', 'Steps', 'DFill', 'DInitials', 'DImage', 'DTitle', 'DSub', 'DBlurb', 'ScoreBox', 'DChamp', 'DBest', 'DBestInfo', 'Summary', 'Status', 'Keys', 'ImportBtn', 'FolderBtn', 'CloseBtn',
           'AddBtn', 'RemoveBtn', 'Search', 'SearchBox', 'SearchInfo', 'SearchAdd', 'SearchClose', 'Results',
           'SettingsBtn', 'Settings', 'SettingsClose', 'Bright', 'BrightValue', 'Tilt', 'TiltValue', 'SettingsNote', 'SettingsSave', 'SettingsReset',
           'Effects', 'EffectsValue', 'EffectsLow', 'EffectsHigh', 'Music', 'MusicValue') {
    $ui[$n] = $win.FindName($n)
}

function New-Brush([string]$hex) { [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }

function Get-Image([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    $bmp = [Windows.Media.Imaging.BitmapImage]::new()
    $bmp.BeginInit()
    $bmp.CacheOption = 'OnLoad'          # don't lock the file, we overwrite snapshots
    $bmp.CreateOptions = 'IgnoreImageCache'
    $bmp.UriSource = [Uri]$path
    $bmp.DecodePixelWidth = 420
    $bmp.EndInit(); $bmp.Freeze()
    $bmp
}

# --- Controls legend --------------------------------------------------------
$keys = @(
    @('Shift  /  L-click', 'Left flipper'), @('Shift  /  R-click', 'Right flipper'),
    @('Enter  /  Middle-click', 'Plunger'), @('5', 'Coin'), @('1', 'Start'),
    @('Space', 'Nudge'), @('Ctrl', 'Magna-save (some tables: color filter)'), @('F12', 'Table options & view'), @('Q', 'Menu > Quit')
)
foreach ($k in $keys) {
    $sp = [Windows.Controls.StackPanel]@{ Orientation = 'Horizontal'; Margin = [Windows.Thickness]::new(0, 2, 22, 2) }
    $kb = [Windows.Controls.Border]@{ Background = (New-Brush '#232937'); CornerRadius = [Windows.CornerRadius]::new(5); Padding = [Windows.Thickness]::new(8, 2, 8, 2) }
    $kb.Child = [Windows.Controls.TextBlock]@{ Text = $k[0]; FontWeight = 'SemiBold'; FontSize = 13 }
    [void]$sp.Children.Add($kb)
    [void]$sp.Children.Add([Windows.Controls.TextBlock]@{ Text = $k[1]; Foreground = (New-Brush '#8A93A6'); FontSize = 13; Margin = [Windows.Thickness]::new(7, 0, 0, 0); VerticalAlignment = 'Center' })
    [void]$ui.Keys.Children.Add($sp)
}

# --- Library ------------------------------------------------------------------
function Update-Library {
    $sel = $ui.Games.SelectedItem
    $library = @(Get-Library)
    foreach ($g in $library | Where-Object { $_.Table -and $_.Rom }) { Update-ScoreBook $g.Id $g.Rom }
    $book = Get-ScoreBook
    $items = foreach ($g in $library) {
        $mine = $book[$g.Id]
        if ($mine -and [long]$mine.Best -le 0) { $mine = $null }   # tracked, but no score of yours yet
        $machine = if ($g.Table -and $g.Rom) { Get-MachineScores $g.Rom } else { $null }
        $ready = $g.Table -and ($g.RomOk -or -not $g.NeedsRom)
        $status = if ($ready) { 'READY' } elseif (-not $g.Table) { 'NEEDS TABLE' } else { 'NEEDS ROM' }
        $pill = if ($ready) { '#3DDC84' } else { '#F59E0B' }
        $c = [Windows.Media.ColorConverter]::ConvertFromString($g.Color)
        $fill = [Windows.Media.LinearGradientBrush]::new($c, [Windows.Media.Color]::FromRgb(16, 19, 26), 75)
        $words = @($g.Title -split '\W+' | Where-Object { $_ -and $_ -notin 'The', 'of', 'from' })
        $g | Add-Member -Force -NotePropertyMembers @{
            Ready = $ready; Status = $status; PillBrush = (New-Brush $pill); Fill = $fill
            Initials = (-join ($words | Select-Object -First 3 | ForEach-Object { $_[0] })).ToUpper()
            Sub = (@($g.Maker, $g.Year) | Where-Object { $_ }) -join "  $([char]0xB7)  "
            Image = (Get-Image (Join-Path $MediaDir "$($g.Id).jpg"))
            Mine = $mine; Machine = $machine
            BestText = if ($mine) { "Best  $(([long]$mine.Best).ToString('N0'))" } elseif ($machine) { 'No score yet' } else { '' }
            BestBrush = New-Brush $(if ($mine) { '#F5B301' } else { '#4A5262' })
        }
        $g
    }
    $script:Items = @($items)
    $ui.Games.ItemsSource = $script:Items
    $listed = @($script:Items | Where-Object Curated)
    $ui.Summary.Text = "$(@($listed | Where-Object Ready).Count) of $($listed.Count) on your list ready to play"
    $again = if ($sel) { $script:Items | Where-Object Id -eq $sel.Id } else { $null }
    $ui.Games.SelectedItem = if ($again) { $again } else { ($script:Items | Where-Object Ready | Select-Object -First 1) }
    if (-not $ui.Games.SelectedItem) { $ui.Games.SelectedIndex = 0 }
}

function Add-Step([string]$text, [bool]$done, [string]$button, [scriptblock]$action) {
    $row = [Windows.Controls.DockPanel]@{ Margin = [Windows.Thickness]::new(0, 0, 0, 10) }
    if ($button) {
        $b = [Windows.Controls.Button]@{ Content = $button; Style = $win.FindResource('Btn'); Margin = [Windows.Thickness]::new(10, 0, 0, 0) }
        $b.Add_Click($action)
        [Windows.Controls.DockPanel]::SetDock($b, 'Right'); [void]$row.Children.Add($b)
    }
    $mark = if ($done) { [char]0x2714 } else { [char]0x25CB }
    $color = if ($done) { '#3DDC84' } else { '#F59E0B' }
    $tb = [Windows.Controls.TextBlock]@{ TextWrapping = 'Wrap'; VerticalAlignment = 'Center' }
    $tb.Inlines.Add([Windows.Documents.Run]@{ Text = "$mark  "; Foreground = (New-Brush $color); FontWeight = 'Bold' })
    $tb.Inlines.Add([Windows.Documents.Run]@{ Text = $text })
    [void]$row.Children.Add($tb)
    [void]$ui.Steps.Children.Add($row)
}

function Show-Details {
    $g = $ui.Games.SelectedItem
    $ui.Steps.Children.Clear()
    if (-not $g) { return }
    $ui.DFill.Background = $g.Fill
    $ui.DInitials.Text = $g.Initials
    $ui.DImage.Source = $g.Image
    $ui.DTitle.Text = $g.Title
    $ui.DSub.Text = $g.Sub
    $ui.DBlurb.Text = $g.Blurb
    $ui.ScoreBox.Visibility = if ($g.Mine -or $g.Machine) { 'Visible' } else { 'Collapsed' }
    $ui.DBest.Text = if ($g.Mine) { ([long]$g.Mine.Best).ToString('N0') } else { 'No score yet' }
    $ui.DBestInfo.Text = if ($g.Mine) {
        $when = ([datetime]$g.Mine.BestDate).ToString('MMM d')
        $games = if ([int]$g.Mine.Games -eq 1) { '1 game' } else { "$($g.Mine.Games) games" }
        $parts = @("Set $when")
        if ([long]$g.Mine.Last -gt 0) { $parts += "last game $(([long]$g.Mine.Last).ToString('N0'))" }
        if ($null -ne $g.Mine.Games) { $parts += $games }
        $parts -join "  $([char]0xB7)  "
    } else { 'Your score shows here after your first game.' }
    $c = if ($g.Machine) { $g.Machine.Champion } else { $null }
    $ui.DChamp.Text = if ($c) { "Machine record  $($c.Initials)  $($c.Score.ToString('N0'))" } else { '' }
    $q = [Uri]::EscapeDataString($g.Title)
    if ($g.Ready) {
        $romNote = if ($g.NeedsRom -or $g.RomOk) { "  $([char]0xB7)  ROM $($g.Rom)" } else { '' }
        Add-Step "Installed$romNote" $true $null $null
    } elseif ($g.Table) {
        Add-Step "Table: $($g.Table.BaseName)" $true $null $null
    } elseif ($g.TableUrl) {
        $url = $g.TableUrl
        Add-Step "Table not installed yet. Download it (best version: $($g.TableBy)), then press Import." $false 'Find table' {
            Start-Process $url
        }.GetNewClosure()
    } else {
        Add-Step 'Table not installed yet. Download the newest version (VPW builds are the best), then press Import.' $false 'Find table' {
            Start-Process "https://vpuniverse.com/search/?q=$q&type=downloads_file"
        }.GetNewClosure()
    }
    # A game from the database lists several ROMs; which one is needed is only known from the table.
    if ($g.Vps -and -not $g.Table) { Add-Step 'ROM: the table says which one it needs once it is installed.' $false $null $null }
    elseif (-not $g.Ready -and ($g.NeedsRom -or ($g.Rom -and $g.RomOk))) {
        if ($g.RomOk) { Add-Step "ROM: $($g.Rom)" $true $null $null }
        else {
            $rom = $g.Rom
            $url = if ($g.RomUrl) { $g.RomUrl } else { "https://www.google.com/search?q=$rom.zip+vpinmame+rom" }
            Add-Step "ROM $rom.zip not installed. Download it (keep it zipped), then press Import." $false 'Find ROM' {
                Start-Process $url
            }.GetNewClosure()
        }
    }
    if ($g.Table -and $g.B2sUrl -and -not (Test-Path ([IO.Path]::ChangeExtension($g.Table.FullName, '.directb2s')))) {
        $url = $g.B2sUrl
        Add-Step 'Backglass (optional): not installed. Download it, then press Import.' $false 'Find backglass' {
            Start-Process $url
        }.GetNewClosure()
    }
    $ui.RemoveBtn.Visibility = if ($g.Curated) { 'Visible' } else { 'Collapsed' }
    $ui.PlayBtn.IsEnabled = [bool]$g.Ready
    $ui.PlayBtn.Content = if ($g.Ready) { 'PLAY' } else { 'NOT READY YET' }
}

# --- Playing --------------------------------------------------------------------
function Save-Snapshot($game) {
    # Grab the middle of the screen (where the table sits) as the card picture.
    $s = Get-ScreenSize
    $w = [int]($s.Width * 0.30); $x = [int](($s.Width - $w) / 2)
    $full = [Drawing.Bitmap]::new($w, $s.Height)
    $g = [Drawing.Graphics]::FromImage($full)
    $g.CopyFromScreen($x, 0, 0, 0, $full.Size)
    $small = [Drawing.Bitmap]::new($full, 420, [int](420 * $s.Height / $w))
    New-Item -ItemType Directory -Force $MediaDir | Out-Null
    $small.Save((Join-Path $MediaDir "$($game.Id).jpg"), [Drawing.Imaging.ImageFormat]::Jpeg)
    $g.Dispose(); $full.Dispose(); $small.Dispose()
}

function Start-Game {
    $g = $ui.Games.SelectedItem
    if (-not $g -or -not $g.Ready -or $script:Running) { return }
    $ui.Status.Text = "Loading $($g.Title)..."
    try { Set-TableDefaults $g.Table } catch {}
    # -ExtMinimized: no editor window, and quitting the game closes VPX (frontend mode).
    $p = Start-Process $VPX -ArgumentList '-ExtMinimized', '-Play', "`"$($g.Table.FullName)`"" -WorkingDirectory $VPRoot -PassThru
    $script:Running = @{ Proc = $p; Game = $g; Started = Get-Date; SawPlayer = $false; GoneSince = $null; Shot = $false }
    $win.WindowState = 'Minimized'
    $script:Timer.Start()
}

$script:Timer = [Windows.Threading.DispatcherTimer]@{ Interval = [TimeSpan]::FromSeconds(1) }
$script:Timer.Add_Tick({
    $r = $script:Running
    if (-not $r) { $script:Timer.Stop(); return }
    $p = $r.Proc
    if (-not $p.HasExited) {
        $player = [MyPinball.Windows]::HasWindow($p.Id, 'Visual Pinball Player')
        if ($player) { $r.SawPlayer = $true; $r.GoneSince = $null }
        elseif ($r.SawPlayer) {
            # Player closed but VPX stayed open (e.g. "Quit to Editor"): close it for the user.
            if (-not $r.GoneSince) { $r.GoneSince = Get-Date }
            elseif (((Get-Date) - $r.GoneSince).TotalSeconds -gt 4) { try { $p.Kill() } catch {} }
        }
        if ($player -and -not $r.Shot -and ((Get-Date) - $r.Started).TotalSeconds -gt 40 -and -not $r.Game.Image) {
            try { Save-Snapshot $r.Game } catch {}
            $r.Shot = $true
        }
        return
    }
    $script:Timer.Stop()
    $script:Running = $null
    $win.WindowState = 'Maximized'
    $win.Activate()
    $before = (Get-ScoreBook)[$r.Game.Id]
    try { Update-ScoreBook $r.Game.Id $r.Game.Rom -JustPlayed } catch {}
    $after = (Get-ScoreBook)[$r.Game.Id]
    $changed = $after -and (-not $before -or "$($after.Last)|$($after.Games)" -ne "$($before.Last)|$($before.Games)")
    $ui.Status.Text = if ($changed -and [long]$after.Last -gt 0) {
        $msg = "$($r.Game.Title): you scored $(([long]$after.Last).ToString('N0'))"
        if (-not $before -or [long]$after.Best -gt [long]$before.Best) { "$msg  $([char]0x2014)  new personal best!" } else { $msg }
    } elseif ($changed) { "$($r.Game.Title): that game didn't make the table's high-score board, so its score isn't known" }
    else { "Played $($r.Game.Title)" }
    Update-Library
})

# --- Adding tables ----------------------------------------------------------------
function Open-Search {
    if ($script:Running) { return }
    $ui.Search.Visibility = 'Visible'
    if (-not $script:VpsLoaded) {
        $ui.SearchInfo.Text = 'Getting the table list...'
        $win.Cursor = 'Wait'
        $win.Dispatcher.Invoke([Action] {}, 'Render')
        try { Open-VpsDb } catch { $ui.SearchInfo.Text = $_.Exception.Message }
        $win.Cursor = $null
    }
    $ui.SearchBox.SelectAll()
    [void]$ui.SearchBox.Focus()
    Update-Search
}

function Close-Search {
    $ui.Search.Visibility = 'Collapsed'
    Set-CardFocus
}

function Set-CardFocus {
    $item = $ui.Games.ItemContainerGenerator.ContainerFromItem($ui.Games.SelectedItem)
    if ($item) { [void]$item.Focus() }
}

function Update-Search {
    if (-not $script:VpsLoaded) { return }
    $q = $ui.SearchBox.Text.Trim()
    $games = @(Get-Games)
    $found = @(if ($q) { Find-VpsGames $q })
    # Find-ListedGame is slow-ish per call, so only titles that could match are checked.
    $listedWords = @{}; foreach ($g in $games) { $listedWords[(Get-TitleWords $g.title) -join ' '] = $true }
    $vpsIds = @{}; foreach ($g in $games) { if ($g.vps) { $vpsIds[$g.vps] = $true } }
    $ui.Results.ItemsSource = @(foreach ($v in $found) {
        $kind = @{ SS = 'Solid state'; EM = 'Electro-mechanical'; PM = 'Pure mechanical'; DG = 'Digital' }[$v.Type]
        $tables = if ($v.TableCount -eq 1) { '1 VPX table' } else { "$($v.TableCount) VPX tables" }
        [pscustomobject]@{
            Title = $v.Name; Vps = $v
            Sub = (@($v.Maker, $v.Year, $kind, $tables) | Where-Object { $_ }) -join "  $([char]0xB7)  "
            Badge = if ($vpsIds[$v.Id] -or ($listedWords[(Get-TitleWords $v.Name) -join ' '] -and (Find-ListedGame $v $games))) { 'ON YOUR LIST' } else { '' }
        }
    })
    $ui.Results.SelectedIndex = 0
    $ui.SearchInfo.Text = if (-not $q) { 'Type part of a name, like "star trek" or "gottlieb 1977".' }
        elseif (-not $found) { "Nothing found for `"$q`"." }
        elseif ($found.Count -ge 60) { 'Showing the first 60. Type more to narrow it down.' }
        else { "$($found.Count) found" }
}

function Add-Selected {
    $r = $ui.Results.SelectedItem
    if (-not $r) { return }
    try { $id = Add-GameFromVps $r.Vps } catch { $ui.SearchInfo.Text = "Couldn't add it: $($_.Exception.Message)"; return }
    Update-Library
    $ui.Games.SelectedItem = $script:Items | Where-Object Id -eq $id | Select-Object -First 1
    $ui.Games.ScrollIntoView($ui.Games.SelectedItem)
    Close-Search
    $ui.Status.Text = if ($ui.Games.SelectedItem.Ready) { "$($r.Title) is on your list and ready to play." }
        else { "$($r.Title) added. Follow the steps on the right to download it." }
}

function Remove-Selected {
    $g = $ui.Games.SelectedItem
    if (-not $g -or -not $g.Curated) { return }
    $note = if ($g.Table) { "`n`nThe table stays installed and shows up as an extra." } else { '' }
    $ok = [Windows.MessageBox]::Show($win, "Remove $($g.Title) from your list?$note", 'Easy Pinball', 'YesNo', 'Question')
    if ($ok -ne 'Yes') { return }
    Remove-Game $g.Id
    $ui.Games.SelectedItem = $null
    Update-Library
    $ui.Status.Text = "Removed $($g.Title). Add it again any time with Add a table."
}

# --- Settings ---------------------------------------------------------------------
# Values Apply-Settings.ps1 also writes: room light (EmissionScale), the legacy camera
# tilt (View*LookAt) and effects volume (SoundVolume); plus PinMAME's music volume.
# VPX and PinMAME read them when a table starts.
$script:Inv = [Globalization.CultureInfo]::InvariantCulture

# VPX 10.8.0 plays table sounds at full volume for any SoundVolume above 0
# (github.com/vpinball/vpinball/issues/1903, fixed in 10.8.1), so there the slider is On/Off.
$script:EffectsOnOff = try { (Get-Item $VPX).VersionInfo.ProductVersion -like '10.8.0*' } catch { $false }
if ($EffectsOnOff) {
    $ui.Effects.TickFrequency = 100; $ui.Effects.SmallChange = 100; $ui.Effects.LargeChange = 100
    $ui.EffectsLow.Text = 'Off    (Visual Pinball 10.8.0 can only switch these on or off)'
    $ui.EffectsHigh.Text = 'On'
}

function Open-Settings {
    if ($script:Running) { return }
    $b = Get-IniValue $VpxIni 'Player' 'EmissionScale'
    $t = Get-IniValue $VpxIni 'TableOverride' 'ViewDTLookAt'
    $ui.Bright.Value = if ($b) { [double]::Parse($b, $Inv) } else { 0.8 }
    $ui.Tilt.Value = if ($t) { [double]::Parse($t, $Inv) } else { 25 }
    $v = Get-IniValue $VpxIni 'Player' 'SoundVolume'
    $fx = if ($v) { ConvertFrom-VpxVolume ([double]::Parse($v, $Inv)) } else { 100 }   # blank = VPX's default, full
    # Snap to the sliders' steps (a value set elsewhere, e.g. raw 5 = 22%, would show oddly).
    $ui.Effects.Value = if ($EffectsOnOff) { if ($fx -gt 0) { 100 } else { 0 } } else { [Math]::Round($fx / 10) * 10 }
    $m = Get-MusicVolume
    $ui.Music.Value = $ui.Music.Ticks | Sort-Object { [Math]::Abs($_ - $m) } | Select-Object -First 1
    # A table's own .ini (F12 menu, or the No Good Gofers brightness fix) wins over these.
    $own = @(foreach ($ini in Get-ChildItem $TablesDir -Filter *.ini) {
        $what = @()
        if (Get-IniValue $ini.FullName 'Player' 'EmissionScale') { $what += 'brightness' }
        if (Get-IniValue $ini.FullName 'TableOverride' 'ViewDTLookAt') { $what += 'tilt' }
        $name = ($ini.BaseName -replace '\s+-\s.*$', '' -replace '\s*\(.*$', '').Trim()
        if ($what) { $name + ' (' + ($what -join ', ') + ')' }
    })
    $note = 'Used by every table, starting with the next one you play.'
    if ($EffectsOnOff) { $note += ' To hear music and voices over the flippers and ball, turn music above 100% and your PC volume down.' }
    if ($own) { $note += " These tables have their own setting, which wins: $($own -join ', ')." }
    $ui.SettingsNote.Text = $note
    $ui.Settings.Visibility = 'Visible'
    [void]$ui.Bright.Focus()
}

function Close-Settings {
    $ui.Settings.Visibility = 'Collapsed'
    Set-CardFocus
}

function Save-Settings {
    $b = $ui.Bright.Value.ToString('0.00', $Inv)
    $t = $ui.Tilt.Value.ToString('0', $Inv)
    $fx = [int]$ui.Effects.Value; $music = [int]$ui.Music.Value
    try {
        Set-IniValues $VpxIni 'Player' @{ OverrideTableEmissionScale = 1; EmissionScale = $b; SoundVolume = (ConvertTo-VpxVolume $fx) }
        Set-IniValues $VpxIni 'TableOverride' @{ ViewDTLookAt = $t; ViewFSSLookAt = $t }
        Set-MusicVolume $music
    } catch { $ui.SettingsNote.Text = "Couldn't save: $($_.Exception.Message)"; return }
    Close-Settings
    $ui.Status.Text = "Saved: brightness $b, tilt $t$([char]0xB0), effects $($ui.EffectsValue.Text.ToLower()), music $music%. Used from the next table you start."
}

# --- Wiring ---------------------------------------------------------------------
$ui.SettingsBtn.Add_Click({ Open-Settings })
$ui.SettingsClose.Add_Click({ Close-Settings })
$ui.SettingsSave.Add_Click({ Save-Settings })
$ui.SettingsReset.Add_Click({
    $ui.Bright.Value = 0.8; $ui.Tilt.Value = 25; $ui.Music.Value = 100
    $ui.Effects.Value = if ($EffectsOnOff) { 100 } else { 50 }
})
$ui.Effects.Add_ValueChanged({
    $ui.EffectsValue.Text = if ($ui.Effects.Value -eq 0) { 'Off' } elseif ($EffectsOnOff) { 'On' } else { "$([int]$ui.Effects.Value)%" }
})
$ui.Music.Add_ValueChanged({
    $p = [int]$ui.Music.Value
    $ui.MusicValue.Text = if ($p -gt 100) { "$p%  boost" } else { "$p%" }
})
$ui.Bright.Add_ValueChanged({ $ui.BrightValue.Text = $ui.Bright.Value.ToString('0.00') })
$ui.Tilt.Add_ValueChanged({ $ui.TiltValue.Text = "$($ui.Tilt.Value.ToString('0'))$([char]0xB0)" })
$ui.AddBtn.Add_Click({ Open-Search })
$ui.RemoveBtn.Add_Click({ Remove-Selected })
$ui.SearchClose.Add_Click({ Close-Search })
$ui.SearchAdd.Add_Click({ Add-Selected })
$ui.SearchBox.Add_TextChanged({ Update-Search })
$ui.Results.Add_MouseDoubleClick({ Add-Selected })
$ui.Games.Add_SelectionChanged({ Show-Details })
$ui.Games.Add_MouseDoubleClick({ Start-Game })
$ui.PlayBtn.Add_Click({ Start-Game })
$ui.CloseBtn.Add_Click({ $win.Close() })
$ui.FolderBtn.Add_Click({ Start-Process explorer.exe $TablesDir })
$ui.ImportBtn.Add_Click({
    $ui.Status.Text = 'Looking through Downloads...'
    $win.Cursor = 'Wait'
    $win.Dispatcher.Invoke([Action] {}, 'Render')
    try {
        $log = @(Import-Downloads)
        $ui.Status.Text = if ($log) { $log -join '   |   ' } else { 'Nothing new found in Downloads.' }
    } catch { $ui.Status.Text = "Import failed: $($_.Exception.Message)" }
    $win.Cursor = $null
    Update-Library
})
$win.Add_PreviewKeyDown({
    param($s, $e)
    if ($ui.Settings.Visibility -eq 'Visible') {
        # Arrow keys stay with the sliders.
        if ($e.Key -eq 'Escape') { Close-Settings; $e.Handled = $true }
        elseif ($e.Key -eq 'Return') { Save-Settings; $e.Handled = $true }
        return
    }
    if ($ui.Search.Visibility -eq 'Visible') {
        switch ($e.Key) {
            'Escape' { Close-Search; $e.Handled = $true }
            'Return' { Add-Selected; $e.Handled = $true }
            { $_ -in 'Down', 'Up' -and $ui.SearchBox.IsKeyboardFocused } {
                # Arrows move through the results while you keep typing.
                $n = $ui.Results.Items.Count
                if ($n) { $ui.Results.SelectedIndex = [Math]::Max(0, [Math]::Min($n - 1, $ui.Results.SelectedIndex + $(if ($e.Key -eq 'Down') { 1 } else { -1 }))) }
                $ui.Results.ScrollIntoView($ui.Results.SelectedItem)
                $e.Handled = $true
            }
        }
        return
    }
    if ($e.Key -eq 'F' -and [Windows.Input.Keyboard]::Modifiers -eq 'Control') { Open-Search; $e.Handled = $true; return }
    switch ($e.Key) {
        'Escape' { $win.Close(); $e.Handled = $true }
        'Return' { Start-Game; $e.Handled = $true }
    }
})
$icon = Join-Path $Root 'assets\EasyPinball.ico'
if (Test-Path $icon) { $win.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]$icon) }
$win.Add_Loaded({
    # Started from a hidden PowerShell, Windows would apply "hidden" to our first window too.
    $hwnd = [Windows.Interop.WindowInteropHelper]::new($win).Handle
    [void][MyPinball.Native]::ShowWindow($hwnd, 3)
    [void][MyPinball.Native]::SetForegroundWindow($hwnd)
})
$win.Add_ContentRendered({ Set-CardFocus })

# Entries without direct download links get them from the table list (once, if it was downloaded before).
if ((Test-Path $VpsDbFile) -and @(Get-Games | Where-Object { -not $_.vps })) { try { Open-VpsDb } catch {} }
Update-Library
$ui.Status.Text = 'Arrow keys + Enter, or double-click a table.'
[void]$win.ShowDialog()
