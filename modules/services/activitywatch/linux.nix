{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.activitywatch;

  mkWatcherService =
    name: watcherCfg:
    let
      jobName = "activitywatch-watcher-${watcherCfg.name}";
    in
    lib.nameValuePair jobName {
      Unit = {
        Description = "ActivityWatch watcher '${watcherCfg.name}'";
        After = [ "activitywatch.service" ];
        BindsTo = [ "activitywatch.target" ];
      };

      Service = {
        ExecStart = "${lib.getExe' watcherCfg.package watcherCfg.executable} ${lib.escapeShellArgs watcherCfg.extraOptions}";

        # Some sandboxing.
        LockPersonality = true;
        NoNewPrivileges = true;
        RestrictNamespaces = true;
      };

      Install.WantedBy = [ "activitywatch.target" ];
    };
in
{
  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
    # We'll group these services with a target to make it easier to manage for
    # the maintainers and the user. Win-win.
    systemd.user.targets.activitywatch = {
      Unit = {
        Description = "ActivityWatch server";
        Requires = [ "default.target" ];
        After = [ "default.target" ];
      };

      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.services = lib.mapAttrs' mkWatcherService cfg.watchers // {
      activitywatch = {
        Unit = {
          Description = "ActivityWatch time tracker server";
          Documentation = [ "https://docs.activitywatch.net" ];
          BindsTo = [ "activitywatch.target" ];
        };

        Service = {
          ExecStart = "${lib.getExe' cfg.package "aw-server"} ${lib.escapeShellArgs cfg.extraOptions}";
          Restart = "on-failure";

          # Some sandboxing.
          LockPersonality = true;
          NoNewPrivileges = true;
          RestrictNamespaces = true;
        };

        Install.WantedBy = [ "activitywatch.target" ];
      };
    };
  };
}
