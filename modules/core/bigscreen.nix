# KDE Plasma 6 (latest from nixos-unstable) with Plasma Bigscreen as the
# auto-login session. App modules add their tiles (nixtv.favorites), window
# rules (nixtv.fullscreenApps) and top-row items (nixtv.bigscreen.indicators).
{ config, lib, pkgs, ... }:

let
  cfg = config.nixtv;
  user = cfg.user;
  home = config.users.users.${user}.home;

  # The home screen's Favorites row, lowest `order` first.
  favorites = lib.sort (a: b: a.order < b.order) (lib.attrValues cfg.favorites);

  # Top-row items between the network item and KDE Connect, chained for
  # remote navigation: wifi -> indicators... -> KDE Connect.
  indicators = cfg.bigscreen.indicators;
  indicatorId =
    ind: "${lib.toLower (lib.substring 0 1 ind.name)}${lib.substring 1 (-1) ind.name}Indicator";
  ids = map indicatorId indicators;
  indicatorBlocks = lib.concatImapStrings (
    i: ind:
    let
      prev = if i == 1 then "wifiIndicator" else lib.elemAt ids (i - 2);
      next = if i == lib.length ids then "kdeConnectIndicator" else lib.elemAt ids i;
    in
    "Indicators.${ind.name} {\n"
    + lib.concatMapStrings (l: "                    ${l}\n") [
      "id: ${indicatorId ind}"
      "KeyNavigation.right: ${next}"
      "KeyNavigation.tab: ${next}"
      "KeyNavigation.backtab: ${prev}"
      "KeyNavigation.left: ${prev}"
    ]
    + "                }\n\n                "
  ) indicators;

  # Bigscreen, as a copy of the package with a few home-screen files edited
  # (no rebuild). share/ must be real files: KPackage rejects package files that
  # are symlinks pointing outside the package directory.
  #  - main.xml: Recent, Applications and Games rows off by default, so the
  #    home screen shows only the favorites above (Bigscreen settings →
  #    Launcher Sections turns them back on).
  #  - IconDelegate.qml: tile labels are plain black on light tiles and white
  #    on dark ones. Upstream uses the icon colour closest to black/white,
  #    which for a single-colour icon (like assets/iptv.svg) is the icon colour.
  #  - the look-and-feel layout script: new home screens get the wallpaper
  #    below instead of a slideshow of /usr/share/wallpapers (not a NixOS path).
  #  - MainColumn.qml: the overlay's "On-screen Keyboard" switch used KWin's
  #    old `enabled` property, gone in Plasma 6.8 (it did nothing and showed
  #    off). It now uses `mode`: on = show for any input (2, as configured
  #    below), off = never (0). Off lasts until the next login, since the
  #    configured mode is locked.
  #  - HomeHeader.qml: the items in nixtv.bigscreen.indicators (e.g. the
  #    Tailscale exit node, modules/tailscale) in the top row, copied into
  #    ui/indicators/. Left untouched when there are none.
  #  - the login splash: NixTV's own (splash/Splash.qml), the logo pulsing on
  #    navy instead of Bigscreen's logo.
  bigscreenUpstream = pkgs.kdePackages.plasma-bigscreen;
  splashDir = "share/plasma/look-and-feel/org.kde.plasma.bigscreen/contents/splash";

  # assets/splash-logo.svg (the logo for dark backgrounds) as a PNG. Its
  # wordmark is live text, which Qt's SVG renderer draws unreliably, so it's
  # rendered here with a fixed font (Inter, the logo's design font).
  splashLogo =
    pkgs.runCommand "nixtv-splash-logo.png"
      {
        nativeBuildInputs = [ pkgs.librsvg ];
        FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.inter ]; };
      }
      ''
        export HOME=$TMPDIR
        rsvg-convert --width 1600 --keep-aspect-ratio ${../../assets/splash-logo.svg} -o $out
      '';
  layoutScript = "share/plasma/look-and-feel/org.kde.plasma.bigscreen/contents/layouts/org.kde.plasma.bigscreen-layout.js";
  homescreenDir = "share/plasma/plasmoids/org.kde.bigscreen.homescreen/contents";
  homescreenConfig = "${homescreenDir}/config/main.xml";
  iconDelegate = "${homescreenDir}/ui/launcher/delegates/IconDelegate.qml";
  overlayMenu = "${homescreenDir}/ui/homeoverlay/MainColumn.qml";
  homeHeader = "${homescreenDir}/ui/HomeHeader.qml";

  plasma-bigscreen = pkgs.runCommand "plasma-bigscreen-tv-${bigscreenUpstream.version}"
    {
      inherit (bigscreenUpstream) passthru meta;
    }
    (
      ''
        cp -rs ${bigscreenUpstream} $out
        chmod -R u+w $out
        rm -r $out/share
        cp -r --no-preserve=mode ${bigscreenUpstream}/share $out/share
        sed -E '/name="show(Recent|Applications|Games)"/,/<\/entry>/ s|<default>true</default>|<default>false</default>|' \
          ${bigscreenUpstream}/${homescreenConfig} > $out/${homescreenConfig}
        grep -c '<default>false</default>' $out/${homescreenConfig} | grep -qx 4 # wallpaperBlur + the 3 rows
        substituteInPlace $out/${iconDelegate} --replace-fail \
          "imagePalette.closestToBlack : imagePalette.closestToWhite" \
          '"black" : "white"'
        substituteInPlace $out/${overlayMenu} \
          --replace-fail 'checked: Keyboards.KWinVirtualKeyboard.enabled' \
            'checked: Keyboards.KWinVirtualKeyboard.mode !== 0' \
          --replace-fail 'Keyboards.KWinVirtualKeyboard.enabled = checked;' \
            'Keyboards.KWinVirtualKeyboard.mode = checked ? 2 : 0;' \
          --replace-fail 'checked = Qt.binding(() => Keyboards.KWinVirtualKeyboard.enabled);' \
            'checked = Qt.binding(() => Keyboards.KWinVirtualKeyboard.mode !== 0);'
        cp ${./splash/Splash.qml} $out/${splashDir}/Splash.qml
        cp ${splashLogo} $out/${splashDir}/images/nixtv-logo.png
      ''
      + lib.optionalString (indicators != [ ]) ''
        ${lib.concatMapStrings (ind: ''
          cp ${ind.source} $out/${homescreenDir}/ui/indicators/${ind.name}.qml
        '') indicators}
        substituteInPlace $out/${homeHeader} \
          --replace-fail 'KeyNavigation.right: kdeConnectIndicator' 'KeyNavigation.right: ${lib.head ids}' \
          --replace-fail 'KeyNavigation.tab: kdeConnectIndicator' 'KeyNavigation.tab: ${lib.head ids}' \
          --replace-fail 'KeyNavigation.backtab: wifiIndicator' 'KeyNavigation.backtab: ${lib.last ids}' \
          --replace-fail 'KeyNavigation.left: wifiIndicator' 'KeyNavigation.left: ${lib.last ids}'
        substituteInPlace $out/${homeHeader} --replace-fail '            Indicators.KdeConnect {' '            ${indicatorBlocks}Indicators.KdeConnect {'
      ''
      + ''
        substituteInPlace $out/${layoutScript} \
          --replace-fail 'desk.wallpaperPlugin = "org.kde.slideshow";' 'desk.wallpaperPlugin = "org.kde.image";' \
          --replace-fail '"Wallpaper","org.kde.slideshow","General"' '"Wallpaper","org.kde.image","General"' \
          --replace-fail 'desk.writeConfig("SlideInterval", 480);' 'desk.writeConfig("Image", "file://${wallpaperPath}");' \
          --replace-fail 'desk.writeConfig("SlidePaths", "/usr/share/wallpapers/");' ""
      ''
    );

  # Default wallpaper: Bratislava castle at dusk (Martin Katler, Unsplash),
  # cropped to 16:9 at 3840x2160 (assets/wallpaper.jpg). Installed as a Plasma
  # wallpaper package, so it's also in the wallpaper picker, at a path that
  # stays stable across rebuilds.
  wallpaperId = "NixTV-Bratislava";
  wallpaperPath = "/run/current-system/sw/share/wallpapers/${wallpaperId}";
  wallpaper = pkgs.runCommand "nixtv-wallpaper" { } ''
    dir=$out/share/wallpapers/${wallpaperId}
    install -Dm644 ${../../assets/wallpaper.jpg} $dir/contents/images/3840x2160.jpg
    cat > $dir/metadata.json <<EOF
    {"KPlugin": {"Id": "${wallpaperId}", "Name": "Bratislava at dusk",
      "Authors": [{"Name": "Martin Katler (Unsplash)"}]}}
    EOF
  '';
in
{
  options.nixtv = {
    favorites = lib.mkOption {
      description = ''
        The home screen's Favorites row. Bigscreen launches favorites by
        storageId, so a launcher of the same name in ~/.local/share/applications
        wins over the app's own (that's how apps get renamed).
      '';
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            order = lib.mkOption {
              type = lib.types.int;
              default = 100;
              description = "Position in the row, lowest first.";
            };
            storageId = lib.mkOption { type = lib.types.str; };
            name = lib.mkOption { type = lib.types.str; };
            icon = lib.mkOption { type = lib.types.str; };
            desktopPath = lib.mkOption { type = lib.types.str; };
            entryPath = lib.mkOption { type = lib.types.str; };
          };
        }
      );
    };

    fullscreenApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Window classes (Wayland app IDs) that always open fullscreen and in
        front. Apps that draw their own title bar only hide it when fullscreen.
      '';
    };

    bigscreen.indicators = lib.mkOption {
      description = "Extra items in the home screen's top row, after the network item.";
      default = [ ];
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              example = "Tailscale";
              description = "QML type name; installed as ui/indicators/<name>.qml.";
            };
            source = lib.mkOption {
              type = lib.types.path;
              description = "The QML file (an AbstractIndicator).";
            };
          };
        }
      );
    };

    onScreenKeyboard.locales = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "en_US" ];
      example = [
        "sv_SE"
        "en_US"
      ];
      description = ''
        On-screen keyboard layouts (more than one adds a language-switch key),
        with word suggestions where nixpkgs has a hunspell dictionary.
      '';
    };
  };

  config = {
    services.desktopManager.plasma6.enable = true;

    services.displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };

      # Register the Bigscreen session (the package exposes
      # passthru.providedSessions = [ "plasma-bigscreen-wayland" ]).
      sessionPackages = [ plasma-bigscreen ];
      defaultSession = "plasma-bigscreen-wayland";

      autoLogin = {
        enable = true;
        inherit user;
      };
    };

    # Bigscreen's home screen imports org.kde.kdeconnect from QML; having it in
    # the system profile puts its QML module on the import path. It also lets you
    # use your phone as a remote/keyboard.
    programs.kdeconnect.enable = true;

    # Bigscreen is built with libcec + SDL3, so TV-remote (HDMI-CEC) and gamepad
    # navigation work without extra packages.
    environment.systemPackages = [
      plasma-bigscreen
      wallpaper
    ]
    # Word suggestions for the on-screen keyboard.
    ++ lib.filter (d: d != null) (
      map (l: pkgs.hunspellDicts.${l} or null) cfg.onScreenKeyboard.locales
    );

    # Default favorites. KDE falls back to /etc/xdg when ~/.config/bigscreen-favs
    # has no entry, so favorites stay editable on the TV.
    environment.etc."xdg/bigscreen-favs".text = lib.concatImapStrings (i: fav: ''
      [Favs][${toString (i - 1)}]
      storageId=${fav.storageId}
      name=${fav.name}
      icon=${fav.icon}
      desktopPath=${fav.desktopPath}
      entryPath=${fav.entryPath}
      comment=
      categories=AudioVideo,Video,Player
      startupNotify=true

    '') favorites;

    # KWin rule forcing nixtv.fullscreenApps fullscreen, and with no
    # focus-stealing prevention so they come to the front even when their
    # window is opened by another process (e.g. Waydroid's session for Android
    # apps). Bigscreen puts /etc/xdg on KDE's config path; [$i] locks the keys
    # so the per-user kwinrulesrc (where Plasma writes its own `Order=` entry)
    # can't shadow this rule list.
    environment.etc."xdg/kwinrulesrc" = lib.mkIf (cfg.fullscreenApps != [ ]) {
      text = ''
        [General][$i]
        count=1
        rules=tv-fullscreen

        [tv-fullscreen][$i]
        Description=TV: force media apps fullscreen and in front
        fullscreen=true
        fullscreenrule=2
        fsplevel=0
        fsplevelrule=2
        wmclass=^(${lib.concatStringsSep "|" cfg.fullscreenApps})$
        wmclassmatch=3
        types=1
      '';
    };

    # On-screen keyboard (plasma-keyboard). [$i] makes these win over the
    # kwinrc Bigscreen generates in ~/.config/plasma-bigscreen:
    #  - InputMethod: Bigscreen points it at /usr/share/applications/...,
    #    which doesn't exist on NixOS, so the keyboard never started.
    #  - VirtualKeyboardMode=2 (show for any input): Bigscreen still exports
    #    KWIN_IM_SHOW_ALWAYS, which KWin 6.8 no longer reads, so it fell back
    #    to showing the keyboard only after touch/pen input. 2 makes it appear
    #    when a text field is focused with a remote, keyboard or mouse too.
    environment.etc."xdg/kwinrc".text = ''
      [Wayland]
      InputMethod[$i]=${pkgs.kdePackages.plasma-keyboard}/share/applications/org.kde.plasma.keyboard.desktop
      VirtualKeyboardMode[$i]=2
    '';

    # On-screen keyboard layouts. A default, not locked: the keyboard's own
    # settings can still change it.
    environment.etc."xdg/plasmakeyboardrc".text = ''
      [General]
      enabledLocales=${lib.concatStringsSep "," cfg.onScreenKeyboard.locales}
    '';

    # No file indexing (Baloo): nothing to search on a TV, and it was
    # crash-looping in the background.
    environment.etc."xdg/baloofilerc".text = ''
      [Basic Settings]
      Indexing-Enabled=false
    '';

    # App modules link their renamed launchers in here (see nixtv.favorites).
    systemd.tmpfiles.rules = [
      "d ${home}/.local 0755 ${user} users -"
      "d ${home}/.local/share 0755 ${user} users -"
      "d ${home}/.local/share/applications 0755 ${user} users -"
    ];

    # Trim desktop apps that make no sense on a TV.
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      kate
      khelpcenter
      konsole
      elisa
    ];
  };
}
