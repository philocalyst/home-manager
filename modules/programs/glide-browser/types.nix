{ lib }:
let
  inherit (lib) mkOption types;

  pathOrLines = types.either types.path types.lines;

  rawType = types.submodule {
    options.__raw = mkOption {
      type = types.lines;
      description = "Literal TypeScript to include without quoting.";
    };
  };

  modeType = types.enum [
    "normal"
    "insert"
    "visual"
    "hint"
    "ignore"
    "command"
    "op-pending"
  ];

  keymapOptionsType = types.submodule {
    options = {
      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Human-readable description of the keymap.";
      };

      buffer = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Whether the mapping only applies to the current buffer.
        '';
      };

      retain_key_display = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Whether to keep showing the entered key sequence after the mapping
          runs.
        '';
      };
    };
  };

  addonOptionsType = types.submodule {
    options = {
      force = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether to force installation of the addon.";
      };

      private_browsing_allowed = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether the addon is allowed in private browsing.";
      };
    };
  };

  keymapType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = "Whether to enable the keymap.";
      };

      modes = mkOption {
        type = types.either modeType (types.nonEmptyListOf modeType);
        description = "Modes where this keymap is active.";
      };

      key = mkOption {
        type = types.str;
        example = "<C-m>";
        description = "The key to map.";
      };

      action = mkOption {
        type = types.either types.str rawType;
        description = "The action to execute.";
      };

      options = mkOption {
        type = types.nullOr keymapOptionsType;
        default = null;
        description = "Additional options passed to `glide.keymaps.set`.";
      };
    };
  };

  searchEngineType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Display name of the search engine.";
      };

      keyword = mkOption {
        type = types.nullOr (types.either types.str (types.listOf types.str));
        default = null;
        description = "Keyword or keywords used to trigger the engine.";
      };

      search_url = mkOption {
        type = types.str;
        description = "Base URL used for search requests.";
      };

      favicon_url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "URL of the favicon to show for the engine.";
      };

      suggest_url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Base URL used for suggestion requests.";
      };

      search_url_get_params = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "GET parameters for `search_url` as a query string.";
      };

      search_url_post_params = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "POST parameters for `search_url` as a query string.";
      };

      suggest_url_get_params = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "GET parameters for `suggest_url` as a query string.";
      };

      suggest_url_post_params = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "POST parameters for `suggest_url` as a query string.";
      };

      encoding = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Encoding used for the search term.";
      };

      is_default = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether this built-in engine should be the default.";
      };
    };
  };

  autocmdPatternType = types.oneOf [
    types.str
    rawType
    (types.submodule {
      options.hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Hostname pattern matched by the autocommand.";
      };
    })
  ];

  autocmdType = types.submodule {
    options = {
      event = mkOption {
        type = types.enum [
          "UrlEnter"
          "ModeChanged"
          "KeyStateChanged"
          "ConfigLoaded"
          "WindowLoaded"
          "CommandLineExit"
        ];
        description = "Event that triggers the autocommand.";
      };

      pattern = mkOption {
        type = types.nullOr autocmdPatternType;
        default = null;
        description = "Optional pattern restricting where the autocommand runs.";
      };

      callback = mkOption {
        type = types.lines;
        description = "Literal callback function body or expression.";
      };
    };
  };

  excmdType = types.submodule {
    options = {
      info = mkOption {
        type = types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Name used to invoke the ex command.";
            };
            description = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Description shown for the ex command.";
            };
          };
        };
        description = "Metadata for the ex command.";
      };

      fn = mkOption {
        type = types.lines;
        description = "Literal command implementation.";
      };
    };
  };

  addonType = types.submodule {
    options = {
      url = mkOption {
        type = types.str;
        description = "URL of the addon to install.";
      };

      options = mkOption {
        type = types.nullOr addonOptionsType;
        default = null;
        description = "Installation options for the addon.";
      };
    };
  };

  runtimeOptionsType = types.submodule {
    options = {
      mapping_timeout = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Timeout, in milliseconds, for completing key mappings.";
      };

      yank_highlight = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Highlight style used after yanking.";
      };

      yank_highlight_time = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Duration, in milliseconds, for yank highlighting.";
      };

      which_key_delay = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Delay before which-key hints are shown.";
      };

      jumplist_max_entries = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Maximum number of jumplist entries to keep.";
      };

      hint_size = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Sizing mode used for link hints.";
      };

      hint_chars = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Characters used to generate hint labels.";
      };

      hint_label_generator = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Built-in hint label generator to use.";
      };

      switch_mode_on_focus = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Whether to switch modes when page focus changes.";
      };

      scroll_implementation = mkOption {
        type = types.nullOr (
          types.enum [
            "keys"
            "legacy"
          ]
        );
        default = null;
        description = "Scrolling backend used by Glide.";
      };

      native_tabs = mkOption {
        type = types.nullOr (
          types.enum [
            "show"
            "hide"
            "autohide"
          ]
        );
        default = null;
        description = "How native browser tabs are displayed.";
      };

      newtab_url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "URL opened for new tabs.";
      };

      go_next_patterns = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Patterns used by the next-page navigation command.";
      };

      go_previous_patterns = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Patterns used by the previous-page navigation command.";
      };

      keymaps_use_physical_layout = mkOption {
        type = types.nullOr (
          types.enum [
            "never"
            "for_macos_option_modifier"
            "force"
          ]
        );
        default = null;
        description = "Whether keymaps should use the physical keyboard layout.";
      };

      keyboard_layout = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Keyboard layout identifier used for key handling.";
      };

      keyboard_layouts = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Keyboard layouts available to Glide.";
      };
    };
  };

  settingsType = types.submodule {
    options = {
      mapleader = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Leader key used for keymaps.";
      };

      label_generators = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Literal value assigned to `glide.hints.label_generators`.";
      };

      options = mkOption {
        type = types.nullOr runtimeOptionsType;
        default = null;
        description = "Runtime options assigned through `glide.o`.";
      };

      preferences = mkOption {
        type = types.attrsOf (
          types.oneOf [
            types.str
            types.int
            types.bool
          ]
        );
        default = { };
        description = "Firefox preferences applied through `glide.prefs.set`.";
      };

      keymaps = mkOption {
        type = types.listOf keymapType;
        default = [ ];
        description = "Keymaps registered through `glide.keymaps.set`.";
      };

      search_engines = mkOption {
        type = types.listOf searchEngineType;
        default = [ ];
        description = "Search engines registered through `glide.search_engines.add`.";
      };

      autocmds = mkOption {
        type = types.listOf autocmdType;
        default = [ ];
        description = "Autocommands registered through `glide.autocmds.create`.";
      };

      excmds = mkOption {
        type = types.listOf excmdType;
        default = [ ];
        description = "Ex commands registered through `glide.excmds.create`.";
      };
    };
  };
in
{
  inherit
    addonType
    pathOrLines
    rawType
    settingsType
    ;
}
