{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.rustic;

  tomlFormat = pkgs.formats.toml { };

  # All opendal-backed services supported by rustic.
  # See <https://rustic.cli.rs/docs/getting_started/supported_services.html>.
  opendalServices = [
    "azblob"
    "azdls"
    "azfile"
    "b2"
    "cos"
    "dropbox"
    "fs"
    "gcs"
    "gdrive"
    "ghac"
    "http"
    "ipmfs"
    "memory"
    "obs"
    "onedrive"
    "oss"
    "sftp"
    "swift"
    "s3"
    "webdav"
    "webhdfs"
    "yandex-disk"
  ];

  # Construct the repository string, with backend concat
  mkRepositoryString =
    repo:
    if repo.backend == "local" then
      repo.path
    else if repo.backend == "rest" then
      "rest:${repo.path}"
    else
      "opendal:${repo.backend}";

  mkRepositorySection =
    repo:
    lib.filterAttrs (_: v: v != null) {
      repository = mkRepositoryString repo;
      "no-cache" = if repo.noCache then true else null;
      "cache-dir" = repo.cacheDir;
      "repo-hot" = repo.repoHot;
      password = repo.password;
      "password-command" = repo.passwordCommand;
    }
    // lib.optionalAttrs (repo.options != { }) { options = repo.options; }
    // repo.extraSettings;

  mkProfileConfig =
    profile: { repository = mkRepositorySection profile.repository; } // profile.settings;

  repositoryModule = lib.types.submodule {
    options = {
      backend = lib.mkOption {
        type = lib.types.enum (
          [
            "local"
            "rest"
          ]
          ++ opendalServices
        );
        example = "s3";
        description = ''
          Storage backend for the repository.

          - `local` — local filesystem; set {option}`path` to the directory.
          - `rest` — rustic REST server; set {option}`path` to the server URL
            (e.g. `http://rest-server:8000/my-repo`).
          - Any opendal service name (e.g. `s3`, `b2`, `sftp`) — uses the
            opendal data-access layer; the module prepends `opendal:` automatically.
            Configure service-specific parameters via {option}`options`.
        '';
      };

      path = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/backup/rustic";
        description = ''
          Repository path or URL.

          - `local` backend: absolute path to the repository directory.
          - `rest` backend: full URL of the REST server.
          - opendal backends: not required here; use {option}`options.root`
            for the storage-side path.
        '';
      };

      noCache = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable the local cache for this repository.";
      };

      cacheDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/tmp/rustic-cache";
        description = "Override the default rustic cache directory.";
      };

      repoHot = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Secondary repository to use as hot (fast-access) storage.";
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Repository encryption password written in plain text.

          ::: {.warning}
          This value ends up in the Nix store, which is world-readable.
          Prefer {option}`passwordFile` or {option}`passwordCommand`.
          :::
        '';
      };

      passwordCommand = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "pass show rustic/backup";
        description = "Shell command whose stdout provides the repository password.";
      };

      options = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        example = lib.literalExpression ''
          {
            bucket = "my-backup-bucket";
            root = "/rustic-repo";
            region = "us-east-1";
            access_key_id = "AKIAIOSFODNN7EXAMPLE";
          }
        '';
        description = ''
          Service-specific options for opendal backends, written to the
          `[repository.options]` TOML table. See the
          [opendal service documentation](https://opendal.apache.org/docs/rust/opendal/services/index.html)
          for the keys accepted by each service.

          Has no effect for the `local` and `rest` backends.
        '';
      };

      extraSettings = lib.mkOption {
        type = tomlFormat.type;
        default = { };
        description = ''
          Additional keys merged verbatim into the `[repository]` TOML table,
          for repository-level options not covered by the dedicated sub-options.
        '';
      };
    };
  };
in
{
  meta.maintainers = with lib.maintainers; [ philocalyst ];

  options.programs.rustic = {
    enable = lib.mkEnableOption "rustic, a fast, encrypted, deduplicated backup tool";

    package = lib.mkPackageOption pkgs "rustic" { nullable = true; };

    profiles = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            repository = lib.mkOption {
              type = repositoryModule;
              description = ''
                Repository configuration. The {option}`backend` field selects the
                storage type and determines how the repository URL is assembled.
              '';
            };

            settings = lib.mkOption {
              type = tomlFormat.type;
              default = { };
              example = lib.literalExpression ''
                {
                  forget = {
                    keep-daily = 14;
                    keep-weekly = 5;
                  };
                  backup = {
                    exclude-if-present = [ ".nobackup" "CACHEDIR.TAG" ];
                    snapshots = [
                      {
                        name = "home";
                        sources = [ "/home/alice" ];
                        git-ignore = true;
                      }
                    ];
                  };
                }
              '';
              description = ''
                Additional profile settings merged alongside the repository
                section. Accepts any TOML-representable value, including the
                `[global]`, `[forget]`, and `[backup]` / `[[backup.snapshots]]`
                sections documented at
                <https://rustic.cli.rs/docs/getting_started/config_file.html>.
              '';
            };
          };
        }
      );
      default = { };
      example = lib.literalExpression ''
        {
          # Becomes ~/.config/rustic/main.toml
          # Use with: rustic -P main <command>
          main = {
            repository = {
              backend = "s3";
              passwordCommand = "cat /run/secrets/rustic-password";
              options = {
                bucket = "my-backup-bucket";
                root = "/rustic-repo";
                region = "us-east-1";
              };
            };
            settings = {
              forget = {
                keep-daily = 14;
                keep-weekly = 5;
              };
            };
          };

          # Default profile → ~/.config/rustic/rustic.toml (no -P flag needed)
          default = {
            repository = {
              backend = "local";
              path = "/backup/rustic";
              passwordCommand = "cat /root/key-rustic";
              noCache = true;
            };
            settings = {
              backup.snapshots = [
                { name = "home"; sources = [ "/home" ]; git-ignore = true; }
                { name = "etc";  sources = [ "/etc"  ]; }
              ];
            };
          };
        }
      '';
      description = ''
        Rustic configuration profiles. Each attribute `<name>` produces
        {file}`$XDG_CONFIG_HOME/rustic/<name>.toml`, except the reserved
        name `default` which produces {file}`$XDG_CONFIG_HOME/rustic/rustic.toml`
        (the file rustic reads when no `-P` flag is given).

        Select a named profile with `rustic -P <name> <command>`. Multiple
        profiles can also be composed at runtime:
        `rustic -P repo -P retention forget`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.mapAttrsToList (
      name: profile:
      let
        repo = profile.repository;
      in
      [
        {
          assertion = repo.backend == "local" -> repo.path != null;
          message = ''
            programs.rustic.profiles.${name}: `repository.path` must be set \
            for the `local` backend.
          '';
        }
        {
          assertion = repo.backend == "rest" -> repo.path != null;
          message = ''
            programs.rustic.profiles.${name}: `repository.path` must be set \
            for the `rest` backend (provide the full server URL).
          '';
        }
      ]
    ) cfg.profiles;

    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    xdg.configFile = lib.mapAttrs' (
      name: profile:
      lib.nameValuePair "rustic/${if name == "default" then "rustic" else name}.toml" {
        source = tomlFormat.generate "rustic-${name}-config" (mkProfileConfig profile);
      }
    ) cfg.profiles;
  };
}
