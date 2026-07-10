{ ... }: {
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          leftalt = "layer(mac)";
          leftmeta = "leftalt";
          rightalt = "layer(mac)";
          rightmeta = "rightalt";
        };

        # Mac Cmd (Left Alt) + key → Ctrl+key equivalents
        mac = {
          c = "C-c";
          v = "C-v";
          x = "C-x";
          z = "C-z";
          y = "C-y";
          a = "C-a";
          s = "C-s";
          w = "C-w";
          q = "C-q";
          t = "C-t";
          n = "C-n";
          f = "C-f";
          r = "C-r";
          tab = "A-tab";
          "`" = "A-grave";
        };
      };
    };
  };
}
