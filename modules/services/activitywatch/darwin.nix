{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.activitywatch;

  mkWatcherAgent =
    name: watcherCfg:
    lib.nameValuePair "activitywatch-watcher-${watcherCfg.name}" {
      enable = true;
      config = {
        ProgramArguments =
          [ "${lib.getExe' watcherCfg.package watcherCfg.executable}" ]
          ++ watcherCfg.extraOptions;
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        ProcessType = "Background";
      };
    };
in
{
  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    launchd.agents = lib.mapAttrs' mkWatcherAgent cfg.watchers // {
      activitywatch = {
        enable = true;
        config = {
          ProgramArguments =
            [ "${lib.getExe' cfg.package "aw-server"}" ]
            ++ cfg.extraOptions;
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          ProcessType = "Background";
        };
      };
    };
  };
}
