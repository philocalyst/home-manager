{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkOption;

  cfg = config.services.activitywatch;

  # Most ActivityWatch client libraries has a function that loads with a
  # certain configuration format for all watchers and itself which is nice for
  # us but watchers can load configuration in any location. We just hope
  # they're following it.
  watcherSettingsFormat = pkgs.formats.toml { };

  # The module interface for the watchers.
  watcherType =
    {
      name,
      config,
      ...
    }:
    {
      options = {
        name = mkOption {
          type = lib.types.str;
          default = name;
          example = "aw-watcher-afk";
          description = ''
            The name of the watcher. This will be used as the directory name for
            {file}`$XDG_CONFIG_HOME/activitywatch/$NAME` when
            {option}`services.activitywatch.watchers.<name>.settings` is set.
          '';
        };

        package = lib.mkPackageOption pkgs "activitywatch" {
          extraDescription = "The derivation containing the watcher executable.";
        };

        executable = mkOption {
          type = lib.types.str;
          default = config.name;
          description = ''
            The name of the executable of the watcher. This is useful in case the
            watcher name is different from the executable. By default, this
            option uses the watcher name.
          '';
        };

        settings = mkOption {
          inherit (watcherSettingsFormat) type;
          default = { };
          example = {
            timeout = 300;
            poll_time = 2;
          };
          description = ''
            The settings for the individual watcher in TOML format. If set, a
            file will be generated at
            {file}`$XDG_CONFIG_HOME/activitywatch/$NAME/$FILENAME`.

            To set the basename of the settings file, see
            [](#opt-services.activitywatch.watchers._name_.settingsFilename).
          '';
        };

        settingsFilename = mkOption {
          type = lib.types.str;
          default = "${config.name}.toml";
          example = "config.toml";
          description = ''
            The filename of the generated settings file. By default, this uses
            the watcher name to be generated at
            {file}`$XDG_CONFIG_HOME/activitywatch/$NAME/$NAME.toml`.

            This is useful in case the watcher requires a different name for the
            configuration file.
          '';
        };

        extraOptions = mkOption {
          type = with lib.types; listOf str;
          default = [ ];
          example = [
            "--host"
            "127.0.0.1"
          ];
          description = ''
            Extra arguments to be passed to the watcher executable.
          '';
        };
      };
    };

  generateWatchersConfig =
    name: watcherCfg:
    let
      # We're only assuming the generated filepath this since most watchers
      # uses the ActivityWatch client library which has `load_config_toml`
      # utility function for easily loading the configuration files.
      filename = "activitywatch/${watcherCfg.name}/${watcherCfg.settingsFilename}";
    in
    lib.nameValuePair filename (
      lib.mkIf (watcherCfg.settings != { }) {
        source = watcherSettingsFormat.generate "activitywatch-watcher-${watcherCfg.name}-settings" watcherCfg.settings;
      }
    );
in
{
  meta.maintainers = [ ];

  imports = [
    ./linux.nix
    ./darwin.nix
  ];

  options.services.activitywatch = {
    enable = lib.mkEnableOption "ActivityWatch, an automated time tracker";

    package = lib.mkPackageOption pkgs "activitywatch" {
      example = "pkgs.aw-server-rust";
      extraDescription = ''
        Specifically, this should be a package containing [the Rust implementation
        of ActivityWatch server](https://github.com/ActivityWatch/aw-server-rust).
      '';
    };

    settings = mkOption {
      description = ''
        Configuration for `aw-server-rust` to be generated at
        {file}`$XDG_CONFIG_HOME/activitywatch/aw-server-rust/config.toml`.
      '';
      inherit (watcherSettingsFormat) type;
      default = { };
      example = lib.literalExpression ''
        {
          port = 3012;

          custom_static = {
            my-custom-watcher = "''${pkgs.my-custom-watcher}/share/my-custom-watcher/static";
            aw-keywatcher = "''${pkgs.aw-keywatcher}/share/aw-keywatcher/static";
          };
        }
      '';
    };

    extraOptions = mkOption {
      description = ''
        Additional arguments to be passed on to the ActivityWatch server.
      '';
      type = with lib.types; listOf str;
      default = [ ];
      example = [
        "--port"
        "5999"
      ];
    };

    watchers = mkOption {
      description = ''
        Watchers to be included with the service alongside with their
        configuration.

        On Linux, check running watchers with
        `systemctl --user status "*aw*"`. On macOS, use
        `launchctl list | grep activitywatch`.

        If a configuration is set, a file will be generated in
        {file}`$XDG_CONFIG_HOME/activitywatch/$WATCHER_NAME/$WATCHER_SETTINGS_FILENAME`.

        ::: {.note}
        The watchers are run with the service manager and the settings format
        of the configuration is only assumed to be in TOML. Furthermore, it
        assumes the watcher program is using the official client libraries
        which has functions to store it in the appropriate location.
        :::
      '';
      type = with lib.types; attrsOf (submodule watcherType);
      default = { };
      example = lib.literalExpression ''
        {
          aw-watcher-afk = {
            package = pkgs.activitywatch;
            settings = {
              timeout = 300;
              poll_time = 2;
            };
          };

          aw-watcher-window = {
            package = pkgs.activitywatch;
            settings = {
              poll_time = 1;
              exclude_title = true;
            };
          };

          my-custom-watcher = {
            package = pkgs.my-custom-watcher;
            executable = "mcw";
            settings = {
              hello = "there";
              enable_greetings = true;
              poll_time = 5;
            };
            settingsFilename = "config.toml";
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile =
      lib.mapAttrs' generateWatchersConfig cfg.watchers
      // lib.optionalAttrs (cfg.settings != { }) {
        "activitywatch/aw-server-rust/config.toml" = {
          source = watcherSettingsFormat.generate "activitywatch-server-rust-config.toml" cfg.settings;
        };
      };
  };
}
