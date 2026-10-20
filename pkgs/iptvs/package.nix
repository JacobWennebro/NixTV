# iptvs: Flutter IPTV player (Xtream, Stalker, M3U) with a TV-friendly UI.
# https://github.com/GCHOfficial/iptvs (not in nixpkgs). Built from source:
# upstream's Linux release is an x86_64-only AppImage.
#
# - Cloud sync is left out: it's only compiled in when Supabase keys are
#   passed at build time, otherwise the app runs fully offline.
# - Its self-updater only works from a writable AppImage, so it stays idle.
# - No standalone mpv: video plays embedded (media_kit/libmpv). The optional
#   external-mpv path for Wayland HDR falls back to embedded without it.
{
  lib,
  flutter347,
  fetchFromGitHub,
  mpv-unwrapped,
  libsecret,
  sqlite,
}:

flutter347.buildFlutterApplication rec {
  pname = "iptvs";
  version = "0.1.70";

  src = fetchFromGitHub {
    owner = "GCHOfficial";
    repo = "iptvs";
    tag = "v${version}";
    hash = "sha256-ShBs4aX9cc4JMur3/rm2CH7M9j1pDyoWEHmM80rCxb8=";
  };

  # pubspec.lock converted to JSON (yq -o json pubspec.lock).
  pubspecLock = lib.importJSON ./pubspec.lock.json;

  gitHashes = {
    media_kit = "sha256-twu/4NxTc9RumYh8R0sIfSoo24c/OZtiwXa0fWkxWmg=";
  };

  buildInputs = [
    mpv-unwrapped # libmpv for media_kit
    libsecret # flutter_secure_storage
  ];

  # sqflite_common_ffi opens libsqlite3 at runtime.
  extraWrapProgramArgs = "--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ sqlite ]}";

  postInstall = ''
    install -Dm644 linux/com.gchofficial.iptvs.desktop $out/share/applications/com.gchofficial.iptvs.desktop
    install -Dm644 assets/icon/icon.png $out/share/pixmaps/com.gchofficial.iptvs.png
  '';

  meta = {
    description = "IPTV player for Xtream, Stalker and M3U sources";
    homepage = "https://github.com/GCHOfficial/iptvs";
    license = lib.licenses.gpl3Only;
    mainProgram = "iptvs";
    platforms = lib.platforms.linux;
  };
}
