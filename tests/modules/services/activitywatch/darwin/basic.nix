{ config, ... }:

{
  services.activitywatch = {
    enable = true;
    package = config.lib.test.mkStubPackage { outPath = "@activitywatch@"; };
  };

  nmt.script = ''
    serverFile=LaunchAgents/org.nix-community.home.activitywatch.plist
    assertFileExists "$serverFile"

    serverFileNormalized=$(normalizeStorePaths "$serverFile")
    assertFileContent "$serverFileNormalized" ${./expected-server-agent.plist}

    assertPathNotExists home-files/.config/activitywatch/aw-server-rust/config.toml
  '';
}
