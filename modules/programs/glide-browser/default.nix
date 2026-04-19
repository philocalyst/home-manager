{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
    ;
  inherit (pkgs.stdenv) isDarwin;

  cfg = config.programs.glide-browser;

  modulePath = [
    "programs"
    "glide-browser"
  ];

  glideTypes = import ./types.nix { inherit lib; };
  glideRender = import ./render.nix { inherit lib; };
  mkFirefoxModule = import ../firefox/mkFirefoxModule.nix;

  nativeMessagingHostsPath =
    if isDarwin then
      "Library/Application Support/Glide Browser/NativeMessagingHosts"
    else
      ".glide-browser/native-messaging-hosts";

  nativeMessagingHostsPackage = pkgs.symlinkJoin {
    name = "glide-native-messaging-hosts";
    paths = lib.flatten [ cfg.nativeMessagingHosts ];
  };
in
{
  imports = [
    (mkFirefoxModule {
      inherit modulePath;
      name = "Glide";
      description = "Extensible and keyboard-focused web browser, based on Firefox.";
      wrappedPackageName = "glide-browser-bin";
      unwrappedPackageName = "glide-browser-bin-unwrapped";

      platforms.linux = {
        configPath = ".config/glide/glide";
      };
      platforms.darwin = {
        configPath = "Library/Application Support/Glide Browser";
      };
    })
  ];

  options.programs.glide-browser = {
    settings = mkOption {
      type = glideTypes.settingsType;
      default = { };
      description = ''
        Glide configuration rendered to {file}`glide.ts`.
      '';
    };

    addons = mkOption {
      type = types.listOf glideTypes.addonType;
      default = [ ];
      description = ''
        Glide addons to install at startup.
      '';
    };

    extraConfig = mkOption {
      type = types.either glideTypes.pathOrLines (types.listOf glideTypes.pathOrLines);
      default = [ ];
      description = ''
        Additional TypeScript configuration appended verbatim to
        {file}`glide.ts`.
      '';
    };

    styles = mkOption {
      type = types.listOf glideTypes.pathOrLines;
      default = [ ];
      description = ''
        CSS snippets added through `glide.styles.add`.
      '';
    };
  };

  config = mkIf cfg.enable {
    xdg.configFile."glide/glide.ts".text = glideRender.renderConfig {
      inherit cfg;
      dtsPath = "${config.xdg.configHome}/glide/glide.d.ts";
    };

    home.file = mkMerge [
      (mkIf (cfg.nativeMessagingHosts != [ ]) {
        "${nativeMessagingHostsPath}" = {
          source = "${nativeMessagingHostsPackage}/lib/mozilla/native-messaging-hosts";
          recursive = true;
          ignorelinks = true;
        };
      })
    ];
  };
}
