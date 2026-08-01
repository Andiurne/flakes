{
  config,
  lib,
  pkgs,
  options,
  ...
}:
/*
TODO

fix regex to match "extended posix regex"
see https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html#tag_09_04
returns a list of the captured groups
strMatching uses this as a bool test

*/
let
  inherit (lib)
    types
    mkOption
    mkEnableOption
  ;
  cfg = config.programs.swayimg;

  # Types adapted from the Lua source file upstream,
  # at github:artemsen/swayimg/extra/swayimg.lua
  # last updated from commit c99591f

  swayimgTypes = {
    appmode_t = types.enum [
      "viewer"
      "slideshow"
      "gallery"
    ];
    color_t = with types; either (strMatching "^0x[[:xdigit:]]{8}$") luaText;
    order_t = types.enum [
      "none"
      "alpha"
      "numeric"
      "mtime"
      "size"
      "random"
    ];
    vdir_t = types.enum [
      "first"
      "last"
      "next"
      "prev"
      "next_dir"
      "prev_dir"
      "random"
    ];
    fixed_scale_t = types.enum [
      "optimal"
      "width"
      "height"
      "fit"
      "fill"
      "real"
      "keep"
    ];
    fixed_position_t = types.enum [
      "center"
      "topcenter"
      "bottomcenter"
      "leftcenter"
      "rightcenter"
      "topleft"
      "topright"
      "bottomleft"
      "bottomright"
    ];
    rotation_t = types.enum [
      90
      180
      270
    ];
    bkgmode_t = types.enum [
      "extend"
      "mirror"
      "auto"
    ];
    gdir_t = types.enum [
      "first"
      "last"
      "up"
      "down"
      "left"
      "right"
      "pgup"
      "pgdown"
    ];
    aspect_t = types.enum [
      "fit"
      "fill"
      "keep"
    ];
    block_positions = [
      "topleft"
      "topright"
      "bottomleft"
      "bottomright"
    ];
    block_position_t = types.enum swayimgTypes.block_positions;
    mbutton_t = types.enum [
      "MouseLeft"
      "MouseRight"
      "MouseMiddle"
      "MouseSide"
      "MouseExtra"
      "ScrollUp"
      "ScrollDown"
      "ScrollLeft"
      "ScrollRight"
    ];
    # Has a whole regex for text in {}, implement later
    text_template_t = types.strMatching lib.concatStrings [
      "*"
    ];
  };

  mkLuaText = text: {inherit text; isLiteral = true;};

  luaText = types.submodule ({name, ...}:{
    options = {
      lua = mkOption {
        type = types.str;
        default = name;
      };
      isLiteral = mkDisableOption "whether to treat <lua> as literal Lua (unquoted)";
    };
  });

  mkDisableOption = name:(mkOption {
    type = types.bool;
    default = true;
    description = "Whether to enable ${name}.";
  });

  # Common submodules
  setWindowBkgOpt = mkOption {
    type = types.either swayimgTypes.color_t swayimgTypes.bkgmode_t;
    default = "auto";
    description = ''
    Window background mode, or an explicit color.
    '';
  };

  set_text_option = mode: lib.genAttrs swayimgTypes.block_positions (position: mkOption{
        type = with types; listOf str;
        default = [];
        description = ''
        Text formatting for the `${position}` text in ${mode} mode.
        Written as a list, with string entries according to swayimg
        formatting.
        '';
        example = [
        "File:\t{name}"
        "Format:\t{format}"
        ];
  });

  on_key_option = mode: mkOption {
        type = with types; attrsOf (either lines keyBinding);
        # This could include the default keybinds...
        # But it doesn't need to and that's a lot for no benefit really.
        default = {};
        description = ''
        An attribute set of keybinding submodules for ${mode} mode.
        Each binding is of the format:
        # on_key
        <keyDescriptor> = <functionBody>
        # or
        <name> = {
          keyDescriptor = "Return"; # Defaults to <name>
          functionBody = \'\'
            swayimg.exit()
          \'\'
        };
        '';
  };

  on_mouse_option = mode: mkOption {
    type = with types; attrsOf (either lines mouseBinding);
    default = {};
    description = ''
    An attribute set of mouse binding submodules for ${mode} mode.
    The name of each submodule is used as the default for the
    keyDescriptor field.
    '';
  };

  # Identical to keybinding, just different
  # hypothetical regex. Could probably be
  # merged into a core variable.
  mouseBinding = types.submodule (
  {name, ...}:{options = {
    keyDescriptor = mkOption {
      type = types.str;
      default = name;
      example = "ScrollLeft";
      description = ''
      A keybind descriptor in the form of (<mod>+)*<mouse_key>,
      where <mouse_key> is any of:
      ``${lib.concatStringsSep "\n" swayimgTypes.mbutton_t}``
      '';
    };
    functionBody = mkOption {
      type = types.lines;
      default = null;
      description = ''
      A Lua function body triggered on the binding.
      '';
    };
  };}
  );

  mkKeyBinding = keyDescriptor: functionBody: {inherit keyDescriptor functionBody;};
  keyBinding = with types; (submodule (
  {name, ...}:{
    options = {
      keyDescriptor = mkOption {
        type = types.str;
        default = name;
        description = ''
        A keybind descriptor in the format (<mod>+)*<sym> to trigger the keybind.
        Defaults to the name of the keybind, for efficient definition in the form
        of
        `on_key."Ctrl+a".functionBody = '''';`
        '';
        example = "Ctrl+a";
      };

      functionBody = mkOption {
        type = types.lines;
        default = null;
        description = ''
        A lua function body to be triggered on keypress.
        '';
      };
    };
  }));

  luaFunctionDeclaration = types.submodule (
    {name, ...}:{options = {

        name = mkOption {
          type = types.singleLineStr;
          default = name;
          description = ''
            Name of the local lua function to be declared.
          '';
        };

        parameters = mkOption {
          type = types.listOf lib.types.singleLineStr;
          default = [];
          description = ''
            A list of names of function parameters to declare.
          '';
        };

        body = mkOption {
          type = types.lines;
          default = ''

          '';
          description = ''
            The function body as a multiline string.
          '';
        };
      };
    }
  );
in
{
  meta.maintainers = with lib.maintainers; [ dod-101 andiurne ];

  imports = [
    (lib.mkRemovedOptionModule [
      "programs"
      "swayimg"
      "settings"
    ] "Upstream moved to a lua config. This option has been replaced by programs.swayimg.extraLua.")
  ];

  options.programs.swayimg = {
    enable = mkEnableOption "swayimg";

    package = lib.mkPackageOption pkgs "swayimg" { };

    functions = mkOption {
      type = types.attrsOf luaFunctionDeclaration;
      default = { };
      description = ''
        An attribute set of user-defined lua functions, written to
        the top of {file}`XDG_CONFIG_HOME`/`configPath` (default swayimg/init.lua)
      '';
      example = lib.literalExpression ''
      # TODO: insert examples
      '';
    };

    variables = mkOption {
      type = with types; attrsOf str;
      default = {};
      description = ''
        An attribute set of lua variables to declare.
        Treated as literal lua (no quotes added to name or value).
        Uses the format:
        `<name> = <value>`
      '';
    };

    configPath = mkOption {
      type = types.str;
      default = "swayimg/init.lua";
      description = ''
      Path to write the configuration file to, relative from {file}`XDG_CONFIG_HOME`. Useful for templating engines.
      Defaults to swayimg/init.lua
      '';
    };

    initLua = mkOption {
      type = with types; nullOr (either path lines);
      default = null;
      description = ''
        Initial lua written to the top of the config file.
        May be either a multiline string, or an import path to a lua file.

        See <https://github.com/artemsen/swayimg/blob/master/CONFIG.md>
        for documentation.
      '';
    };

    extraLua = mkOption {
      type = with types; nullOr (either path lines);
      default = null;
      description = ''
        Extra lua written to the end of the config file.
        May be either a multiline string, or an import path
        to a lua file.

        See <https://github.com/artemsen/swayimg/blob/master/CONFIG.md>
        for documentation.
      '';
      example = lib.literalExpression ''
        swayimg.text.set_size(32)
        swayimg.text.set_foreground(0xffff0000)

        swayimg.viewer.set_default_scale("fill")

        swayimg.gallery.on_key("Delete", function()
          local image = swayimg.gallery.get_image()
          os.remove(image.path)
        end)
      '';
    };

    requirePaths = mkOption {
      type = with types; listOf str;
      default = [];
      description = ''A list of strings to pass to require calls at the top of the generated file.'';
    };

    # "General Config" options, as per the example configuration
    /*
    In keeping with attempting to nix-ify the configuration more,
    I'll move the mode sub-options under, appropriately,
    swayimg.<name>.<options>
    */
    mode = mkOption {
      type = swayimgTypes.appmode_t;
      default = "viewer";
      description = ''
      The mode of swayimg on startup.
      '';
    };

    viewer = {
      default_scale = mkOption {
        type = swayimgTypes.fixed_scale_t;
        default = "optimal";
        description = ''
        The default scaling mode for images in viewer.
        '';
      };

      default_position = mkOption {
        type = swayimgTypes.fixed_position_t;
        default = "center";
        description = ''
        The default position for images in viewer.
        '';
      };

      drag_button = mkOption {
        type = swayimgTypes.mbutton_t;
        default = "MouseLeft";
        description = ''
        Mouse button to drag image.
        '';
      };

      autocenter = mkDisableOption "automatic centering.";

      loop = mkDisableOption "image list loop mode.";

      preload = mkOption {
        type = types.ints.unsigned;
        default = 1;
        description = ''
        Number of images to preload.
        '';
      };

      history = mkOption {
        type = types.ints.unsigned;
        default = 1;
        description = ''
        Number of images in history cache.
        '';
      };

      mark_color = mkOption {
        type = swayimgTypes.color_t;
        default = "0xff808080";
        description = ''
        Mark icon color.
        '';
      };

      pinch_factor = mkOption {
        type = types.number;
        default = 1;
        description = ''
        Factor to scale by for the pinch gesture.
        '';
      };

      set_window_background = setWindowBkgOpt;

      set_text = set_text_option "viewer";

      set_image_chessboard = {
        size = mkOption {
          type = types.ints.unsigned;
          default = 20;
        };
        color1 = mkOption {
          type = swayimgTypes.color_t;
          default = "0xff333333";
        };
        color2 = mkOption {
          type = swayimgTypes.color_t;
          default = "0xff4c4c4c";
        };
      };


      # Bind List (list of submodules)
      on_mouse = on_mouse_option "viewer";
      on_key = on_key_option "viewer";
    };

    slideshow = {
      timeout = mkOption {
        type = types.number;
        default = 5;
        description = ''
        Timeout in seconds after which the next image should be opened.
        '';
      };

      default_scale = mkOption {
        type = swayimgTypes.fixed_scale_t;
        default = "fit";
        description = ''
        The default scaling mode used for slideshow images.
        '';
      };

      history = mkOption {
        type = types.ints.unsigned;
        default = 0;
        description = ''
        How many images to store in the history cache.
        '';
      };


      set_window_background = setWindowBkgOpt;
      set_text = set_text_option "slideshow";
      on_mouse = on_mouse_option "slideshow";
      on_key = on_key_option "slideshow";
    };

    gallery = {
      thumb_size = mkOption {
        type = types.ints.unsigned;
        default = 200;
        description = ''
        Thumbnail size of gallery images in pixels.
        '';
      };

      aspect = mkOption {
        type = swayimgTypes.aspect_t;
        default = "fill";
        description = ''
        Thumbnail aspect ratio of gallery images.
        '';
      };

      padding_size = mkOption {
        type = types.ints.unsigned;
        default = 5;
        description = ''
        Padding size in pixels between gallery images.
        '';
      };

      border_size = mkOption {
        type = types.ints.unsigned;
        default = 5;
        description = ''
        Border size in pixels of selected thumbnail.
        '';
      };

      border_color = mkOption {
        type = swayimgTypes.color_t;
        default = "0xffaaaaaa";
        description = ''
        Border color for selected thumbnail, in ARGB hex.
        '';
      };

      selected_scale = mkOption {
        type = types.number;
        default = 1.15;
        description = ''
        Scaling factor for selected thumbnail.
        '';
      };

      selected_color = mkOption {
        type = swayimgTypes.color_t;
        default = "0xff404040";
        description = ''
        Background color of the selected thumbnail, in ARGB hex.
        '';
      };

      unselected_color = mkOption {
        type = swayimgTypes.color_t;
        default = "0xff202020";
        description = ''
        Background color of unselected thumbnails, in ARGB hex.
        '';
      };

      window_color = mkOption {
        type = swayimgTypes.color_t;
        default = "0xff000000";
        description = ''
        Background color of the window in gallery mode.
        '';
      };

      pinch_factor = mkOption {
        type = types.number;
        # The default for gallery is 100?? For some reason?
        # Inspect the source code for the fuckery.
        default = 100;
        description = ''
        Pinch gesture scaling factor.
        '';
      };

      hover = mkDisableOption "mouse following.";

      cache = mkOption {
        type = types.ints.unsigned;
        default = 100;
        description = ''
        Number of image thumbnails to store in memory.
        '';
      };

      preload = mkEnableOption "preloading invisible thumbnails";
      embedded_thumb = mkDisableOption "using embedded thumbnails";
      pstore = mkEnableOption "persistent storage for thumbnails";

      set_text = set_text_option "gallery";
      on_mouse = on_mouse_option "gallery";
      on_key = on_key_option "gallery";
    };

    imagelist = {
      order = mkOption {
        type = swayimgTypes.order_t;
        default = "numeric";
        description = ''
        Sorting order to use when constructing the image list.
        '';
      };

      reverse = mkEnableOption "reverse sorting order";
      recursive = mkEnableOption "recursive directory reading";
      adjacent = mkEnableOption "adding adjacent files from same dir";
      fsmon = mkDisableOption ''
        Enable file system monitoring.
      '';
    };

    text = {
      visible = mkDisableOption ''
        Whether to show the text layer on startup.
      '';

      font = mkOption {
        type = types.str;
        default = "monospace";
        description = ''
        Font name for the text overlay.
        '';
      };

      size = mkOption {
        type = types.int;
        default = 24;
        description = ''
        Font size for the text overlay.
        '';
      };

      spacing = mkOption {
        type = types.int;
        default = 0;
      };

      padding = mkOption {
        type = types.int;
        default = 10;
      };

      color = mkOption {
        type = swayimgTypes.color_t;
        default = "0xff000000";
        description = ''
        Text color in ARGB hex format;
        '';
        example = mkLuaText "0xff00aa99";
      };

      background = mkOption {
        type = swayimgTypes.color_t;
        default = "0x00000000";
        description = ''
        Background color for text in ARGB hex format.
        '';
        example = mkLuaText "0xff00aa99";
      };

      shadow = mkOption {
        type = swayimgTypes.color_t;
        default = "0x0d000000";
        description = ''
        Color of text shadow in ARGB hex format.
        '';
      };

      timeout = mkOption {
        type = types.number;
        default = 5;
        description = ''
        Time in seconds before the text layer hides.
        '';
      };

      status_timeout = mkOption {
        type = types.number;
        default = 3;
        description = ''
        Time in seconds for status messages to timeout.
        '';
      };

    };

    # Yes these could've been enable options
    # but the default values are true,
    # and I want the default configuration to mirror swayimg's.
    #
    # This leads to a shorter init.lua, since if the default value
    # is left alone, we can omit the line.
    antialiasing = mkDisableOption ''
        Whether to enable antialiasing on startup.
    '';
    decoration = mkDisableOption ''
      Whether to enable window title, buttons, and borders.
    '';
    exif_orientation = mkDisableOption ''
      Whether to orient images using EXIF data.
    '';

    overlay = mkEnableOption "overlay mode";

    dnd_button = mkOption {
      type = swayimgTypes.mbutton_t;
      default = "MouseRight";
      description = ''
        Drag-and-drop mouse binding.
      '';
      example = "MouseLeft";
    };
  };

  config =
  let
    defaultValue = attributePath:
      lib.getAttrFromPath
      (attributePath ++ ["default"])
      options.programs.swayimg
    ;

    addTab = lines: "\t" + (builtins.replaceStrings [ "\n" ] [ "\n\t" ] lines);
    checkQuotes = text:
      if builtins.isList (builtins.match ''"[^"]*"'' text)
        then text
        else ''"${text}"'';

    mkLuaFunction = name: parameters: body:
    ''
    function ${name} (${builtins.concatStringsSep ", " parameters})
    ${addTab body}
    end
    '';

    mkLuaVariable = name: value: ''${name} = ${value}'';

    toLuaVal = input:
    if builtins.isAttrs input
      then (if input.isLiteral then input.lua else checkQuotes input.lua)

    else if builtins.isString input
      then if builtins.isList (builtins.match "0x[[:xdigit:]]{8}" input)
        then input
        else checkQuotes input

    else if lib.isBool input
      then lib.boolToString input
    # Must be a number
    else toString input
    ;

    sectionToLua = section:
    [''

      --------------
      -- ${section}
      --------------

    '']
    ++
    lib.lists.flatten
    (lib.mapAttrsToList
      (attr: value:
      # Checks for function call set values
        if attr == "set_window_background"  && value != defaultValue [ section attr ]
          then mkSwayimgCall section attr [(toLuaVal value)]

        else if attr == "set_image_chessboard"
          then mkSwayimgCall section attr (with value; (map toLuaVal [size color1 color1]))

        else if attr == "set_text"
          then
            lib.attrsets.mapAttrsToList
            (position: textFormat:
              if defaultValue [ section attr position ] == textFormat
                then ""
                else mkSwayimgCall section attr
                  [position ("{${lib.concatStringsSep ", " textFormat}}") ]
            )
            value

        else if (attr == "on_key") || (attr == "on_mouse")
          then
            lib.attrsets.mapAttrsToList
            (bindName: bindVal: let
                # Assumes that if keybind shorthand is used, the descriptor
                # needs to be quoted
                keybind = if builtins.isAttrs bindVal then bindVal else mkKeyBinding (checkQuotes bindName) bindVal;
              in (mkSwayimgCall section attr (
              [
              (toLuaVal keybind.keyDescriptor)
              (mkLuaFunction "" [] keybind.functionBody)
              ])) + "\n")
            value
        else mkLuaSectionAttribute section attr
      )
      cfg.${section}
    );

    mkSwayimgCall =
    mode: functionName: argumentList:
      let
        path = if isNull mode then "${functionName}" else "${mode}.${functionName}";
      in
      ''
      swayimg.${path}(${builtins.concatStringsSep ", " argumentList})
      ''
    ;

    # These could be merged by parsing attribute paths
    # But that would also forbid names with periods
    mkLuaGlobalAttribute = attribute:
      if (defaultValue [ attribute ] == cfg.${attribute})
        then ""
        else "swayimg.${attribute} = ${toLuaVal cfg.${attribute}}\n"
    ;
    mkLuaSectionAttribute = section: attribute:
      if (defaultValue [ section attribute ] == cfg.${section}.${attribute})
        then ""
        else "swayimg.${section}.${attribute} = ${toLuaVal cfg.${section}.${attribute}}\n"
    ;
    extraLuaText = if builtins.isPath cfg.extraLua then builtins.readFile cfg.extraLua else cfg.extraLua;
  in
  lib.mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "programs.swayimg" pkgs lib.platforms.linux)
    ];

    home.packages = [ cfg.package ];

    xdg.configFile.${cfg.configPath} = {
      text = lib.concatStrings (
      # Begin massive string list concatenation
      (map (requirePath: ''require "${requirePath}"'') cfg.requirePaths)
      ++
      (
      [''

        ----------------
        -- Lua Variables
        ----------------

      ''] ++ lib.mapAttrsToList
        (name: setting: (if builtins.isAttrs setting then (mkLuaVariable name setting.value) else mkLuaVariable name setting) + "\n")
        cfg.variables
      )
      ++
      ([''

        ----------------
        -- Lua Functions
        ----------------

        ''] ++ lib.mapAttrsToList
        (name: set: (mkLuaFunction set.name set.parameters set.body) + "\n")
        cfg.functions
      )
      ++
      ([
        ''

        ------------------
        -- Swayimg Globals
        ------------------

        ''
      ] ++ (map mkLuaGlobalAttribute [
        "mode"
        "antialiasing"
        "decoration"
        "overlay"
        "exif_orientation"
        "dnd_button"
      ]))
      ++
      (lib.lists.flatten (map sectionToLua
          [
            "imagelist"
            "text"
            "viewer"
            "slideshow"
            "gallery"
          ]
      ))
      ++
      [
        ''

        ------------
        -- Extra Lua
        ------------

        ''
        (if isNull extraLuaText then "" else extraLuaText)
      ]);
    };
  };
}
