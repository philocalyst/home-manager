{ config, ... }:

let
  stubPackage = config.lib.test.mkStubPackage { outPath = "@activitywatch@"; };

in
{
  services.activitywatch = {
    enable = true;
    package = stubPackage;
    settings = {
      port = 3012;
    };
    watchers = {
      aw-watcher-afk = {
        package = stubPackage;
      };
      custom-watcher = {
        package = stubPackage;
        settings = {
          foo = "bar";
          baz = 8;
        };
        settingsFilename = "config.toml";
      };
    };
  };

  nmt.script = ''
    # Server agent
    assertFileExists LaunchAgents/org.nix-community.home.activitywatch.plist

    # Watcher agents
    assertFileExists LaunchAgents/org.nix-community.home.activitywatch-watcher-aw-watcher-afk.plist
    assertFileExists LaunchAgents/org.nix-community.home.activitywatch-watcher-custom-watcher.plist

    # Server settings are generated
    assertFileExists home-files/.config/activitywatch/aw-server-rust/config.toml

    # Watcher settings are generated only when provided
    assertFileExists home-files/.config/activitywatch/custom-watcher/config.toml
    assertPathNotExists home-files/.config/activitywatch/aw-watcher-afk/aw-watcher-afk.toml
  '';
}
