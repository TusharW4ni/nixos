# Neovim, via nixvim. Moved here from the separate nvim repo's nixvim branch
# (github:TusharW4ni/nvim) so the whole config lives in one place: edit this
# file, then `ns`.
{ pkgs, ... }:
let
  # prettierd only: conform's stop_after_first never fell back to plain
  # prettier on a prettierd timeout, so the fallback was dead weight.
  prettier = [ "prettierd" ];
  # Where ts_ls finds the @vue/typescript-plugin. Was a Mason path; nixpkgs
  # ships a pnpm layout, so point at the @vue/language-server package dir
  # (it has node_modules/@vue/typescript-plugin alongside).
  vueLsPath = "${pkgs.vue-language-server}/lib/language-tools/packages/language-server";
in
{
  programs.nixvim = {
    enable = true;

    # Reuse the system pkgs (from useGlobalPkgs) instead of nixvim importing
    # its own nixpkgs; avoids a second nixpkgs evaluation.
    nixpkgs.useGlobalPackages = true;

    # No plugin uses the Ruby or Python providers (Ruby alone is ~41 MiB).
    withRuby = false;
    withPython3 = false;

    # Cache compiled Lua modules (vim.loader). Measured startup 115 -> 86 ms.
    luaLoader.enable = true;

    # Runtime tools nvim shells out to: LSP servers and formatters. Replaces
    # everything Mason used to fetch. clangd/clang-format come from
    # home.packages (clang-tools), which is already on nvim's PATH; prettierd
    # and vue-language-server bundle their own node.
    extraPackages = with pkgs; [
      lua-language-server
      vue-language-server
      typescript-language-server
      nixd
      nixfmt
      stylua
      prettierd
      # snacks.image: typesets $..$ math (tectonic) and converts/rasterises
      # for the kitty protocol (imagemagick, ghostscript).
      tectonic
      imagemagick
      ghostscript
    ];

    # vim.lsp.config/enable read default server definitions from nvim-lspconfig's
    # lsp/ runtime dir. We only need it on rtp, not its setup() framework.
    extraPlugins = [ pkgs.vimPlugins.nvim-lspconfig ];

    globals = {
      mapleader = " ";
    };

    opts = {
      splitbelow = true;
      splitright = true;
      clipboard = "unnamedplus";
      laststatus = 3;
      statusline = "%#StatusLineFile#  %f ";
      number = true;
      relativenumber = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      ignorecase = true;
      smartcase = true;
      termguicolors = true;
      undofile = true;
      scrolloff = 8;
      signcolumn = "yes";
    };

    # Inline diagnostic text; off by default since nvim 0.11.
    diagnostic.settings.virtual_text = true;

    # Reload buffers changed on disk while nvim keeps focus (treechat/pi,
    # agents in a toggleterm). FocusGained already checks via 'autoread'.
    # getcmdwintype guard: :checktime errors in the cmdline window.
    autoCmd = [
      {
        event = [ "BufEnter" "CursorHold" "TermLeave" ];
        callback.__raw = ''
          function()
            if vim.fn.getcmdwintype() == "" then vim.cmd.checktime() end
          end
        '';
      }
    ];

    highlight = {
      StatusLine.bg = "NONE";
      StatusLineFile = {
        fg = "#c0caf5";
        bg = "NONE";
      };
    };

    keymaps = [
      # notes (obsidian.nvim)
      { mode = "n"; key = "<leader>ob"; action = "<cmd>Obsidian backlinks<cr>"; options.desc = "Obsidian backlinks"; }
      { mode = "n"; key = "<leader>on"; action = "<cmd>Obsidian new<cr>"; options.desc = "Obsidian new note"; }
      { mode = "n"; key = "<leader>os"; action = "<cmd>Obsidian quick_switch<cr>"; options.desc = "Obsidian quick switch"; }
      # terminal (toggleterm): toggle hides/shows all, opens one if none exist
      {
        mode = "n";
        key = "<leader>tt";
        action.__raw = ''
          function()
            if #require("toggleterm.terminal").get_all() == 0 then
              vim.cmd("ToggleTerm")
            else
              vim.cmd("ToggleTermToggleAll!")
            end
          end
        '';
        options.desc = "Toggle terminals";
      }
      {
        mode = "n";
        key = "<leader>ts";
        action = "<cmd>TermNew<cr>";
        options.desc = "New terminal (side by side)";
      }
      {
        mode = "n";
        key = "<leader>tq";
        action.__raw = ''
          function()
            local terms = require("toggleterm.terminal")
            local id = terms.get_focused_id()
            if id then terms.get(id):shutdown() end
          end
        '';
        options.desc = "Close focused terminal";
      }
      # resize panes
      {
        mode = "n";
        key = "<C-Up>";
        action = "<cmd>resize +2<cr>";
        options.desc = "Increase pane height";
      }
      {
        mode = "n";
        key = "<C-Down>";
        action = "<cmd>resize -2<cr>";
        options.desc = "Decrease pane height";
      }
      {
        mode = "n";
        key = "<C-Left>";
        action = "<cmd>vertical resize -2<cr>";
        options.desc = "Decrease pane width";
      }
      {
        mode = "n";
        key = "<C-Right>";
        action = "<cmd>vertical resize +2<cr>";
        options.desc = "Increase pane width";
      }
      # oil
      {
        mode = "n";
        key = "-";
        action = "<cmd>Oil<cr>";
        options.desc = "Open parent directory (oil)";
      }
      # conform format
      {
        mode = [ "n" "v" ];
        key = "<leader>cf";
        action.__raw = "function() require('conform').format({ async = true, lsp_format = 'fallback' }) end";
        options.desc = "Format buffer";
      }
      # which-key buffer-local
      {
        mode = "n";
        key = "<leader>?";
        action.__raw = "function() require('which-key').show({ global = false }) end";
        options.desc = "Buffer local keymaps";
      }
      # Esc clears search highlights (native :nohlsearch).
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<CR>";
        options.desc = "Clear search highlight";
      }
    ]
    # C-h/j/k/l window navigation in normal + terminal mode. Normal mode uses
    # the native <C-w> prefix; terminal mode needs <C-\><C-n> to escape first.
    ++ map (dir: {
      mode = "n";
      key = "<C-${dir}>";
      action = "<C-w>${dir}";
      options.desc = "Window ${dir}";
    }) [ "h" "j" "k" "l" ]
    ++ map (dir: {
      mode = "t";
      key = "<C-${dir}>";
      action = "<C-\\><C-n><C-w>${dir}";
      options.desc = "Window ${dir}";
    }) [ "h" "j" "k" "l" ];

    plugins = {
      # --- completion ---
      friendly-snippets.enable = true;
      blink-cmp = {
        enable = true;
        settings = {
          keymap.preset = "default";
          appearance = {
            use_nvim_cmp_as_default = true;
            nerd_font_variant = "mono";
          };
          sources.default = [ "lsp" "path" "snippets" "buffer" ];
        };
      };

      # --- notes ---
      # obsidian.nvim: wikilinks/backlinks/tags/search on the flat markdown
      # vault. Completion comes from its built-in LSP, which blink-cmp's
      # "lsp" source already picks up. ripgrep comes from home.packages.
      obsidian = {
        enable = true;
        settings = {
          legacy_commands = false; # use `:Obsidian <sub>` form only
          workspaces = [{ name = "notes"; path = "~/obsidian-vaults/notes"; }];
          new_notes_location = "current_dir"; # vault is flat, no subfolders
          # Readable "Note Title.md" filenames, not zettel IDs.
          note_id_func.__raw = ''require("obsidian.builtin").title_id'';
          # Don't inject id/aliases/tags frontmatter into existing notes.
          frontmatter.enabled = false;
        };
      };

      # --- images / math ---
      # snacks.image renders markdown images and $..$ / $$..$$ math inline via
      # the kitty graphics protocol (Ghostty supports it).
      snacks = {
        enable = true;
        settings.image.enabled = true;
      };

      # --- auto-pairing ---
      # nvim-autopairs: closes (), [], {}, "", '' etc. as you type.
      nvim-autopairs = {
        enable = true;
        settings.check_ts = true; # use treesitter to skip pairing inside strings/comments
      };

      # ts-autotag: does the HTML/JSX/Vue side - typing `<div>` auto-inserts
      # `</div>`, and renaming the opening tag renames the closing one too.
      # Needs treesitter (already enabled above) for the html/jsx/vue parsers.
      ts-autotag.enable = true;

      # --- fuzzy finder ---
      telescope = {
        enable = true;
        # Route vim.ui.select (treechat's chat/model/thinking pickers, LSP code
        # actions, ...) through telescope instead of the cmdline list.
        extensions.ui-select.enable = true;
        extensions.fzf-native = {
          enable = true;
          settings = {
            fuzzy = true;
            override_generic_sorter = true;
            override_file_sorter = true;
            case_mode = "smart_case";
          };
        };
        keymaps = {
          "<leader>ff" = { action = "find_files"; options.desc = "Telescope find files"; };
          "<leader>fg" = { action = "live_grep"; options.desc = "Telescope live grep"; };
          "<leader>fb" = { action = "buffers"; options.desc = "Telescope buffers"; };
          "<leader>fh" = { action = "help_tags"; options.desc = "Telescope help tags"; };
          "<leader>/" = { action = "current_buffer_fuzzy_find"; options.desc = "Search current buffer"; };
        };
      };

      # --- terminal ---
      toggleterm = {
        enable = true;
        settings = {
          direction = "horizontal";
          size = 15;
        };
      };

      # --- treesitter ---
      # Grammars come from nix (default set), so no auto_install / ensure needed.
      treesitter = {
        enable = true;
        settings.highlight.enable = true;
      };

      # --- file explorer ---
      oil = {
        enable = true;
        settings = {
          default_file_explorer = true;
          view_options.show_hidden = true;
          keymaps."q" = "actions.close";
        };
      };

      # --- git ---
      gitsigns = {
        enable = true;
        settings.on_attach.__raw = ''
          function(bufnr)
            local gs = require('gitsigns')
            local function map(mode, lhs, rhs, desc)
              vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
            end

            map('n', ']c', function()
              if vim.wo.diff then vim.cmd.normal({ ']c', bang = true }) else gs.nav_hunk('next') end
            end, 'Next hunk')
            map('n', '[c', function()
              if vim.wo.diff then vim.cmd.normal({ '[c', bang = true }) else gs.nav_hunk('prev') end
            end, 'Prev hunk')

            map('n', '<leader>gs', gs.stage_hunk, 'Stage hunk (toggle)')
            map('n', '<leader>gr', gs.reset_hunk, 'Reset hunk')
            map('v', '<leader>gs', function()
              gs.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
            end, 'Stage selection')
            map('v', '<leader>gr', function()
              gs.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
            end, 'Reset selection')
            map('n', '<leader>gS', gs.stage_buffer, 'Stage buffer')
            map('n', '<leader>gR', gs.reset_buffer, 'Reset buffer')
            map('n', '<leader>gp', gs.preview_hunk, 'Preview hunk')
            map('n', '<leader>gb', function() gs.blame_line({ full = true }) end, 'Blame line')
            map('n', '<leader>gd', gs.diffthis, 'Diff this')
            map('n', '<leader>gt', gs.toggle_current_line_blame, 'Toggle line blame')

            map({ 'o', 'x' }, 'ih', gs.select_hunk, 'Select hunk')
          end
        '';
      };

      # --- treechat transcript rendering ---
      # Renders markdown (code blocks, headings, bullets, tables) in the
      # treechat transcript only; its buffer uses filetype "treechat", so
      # regular .md files are unaffected.
      render-markdown = {
        enable = true;
        settings = {
          file_types = [ "treechat" ];
          # Groups defined by treechat: faint block shade, no inline-code background.
          code = {
            highlight = "TreechatCode";
            highlight_inline = "TreechatCodeInline";
          };
        };
      };

      # --- which-key ---
      which-key.enable = true;

      # --- formatter ---
      conform-nvim = {
        enable = true;
        settings = {
          formatters_by_ft = {
            lua = [ "stylua" ];
            nix = [ "nixfmt" ];
            c = [ "clang-format" ];
            cpp = [ "clang-format" ];
            javascript = prettier;
            typescript = prettier;
            javascriptreact = prettier;
            typescriptreact = prettier;
            vue = prettier;
            css = prettier;
            html = prettier;
            json = prettier;
            jsonc = prettier;
            markdown = prettier;
            yaml = prettier;
          };
          # Skipped on save (format those with <leader>cf):
          # - markdown: prettier rewrites `- [ ]` to `* [ ]` in synced notes.
          # - nix: this repo is hand-formatted; nixfmt on save would reformat
          #   whole files on first edit.
          # 1500 ms: a cold prettierd start overran the old 500 ms.
          format_on_save.__raw = ''
            function(bufnr)
              local ft = vim.bo[bufnr].filetype
              if ft == "markdown" or ft == "nix" then return end
              return { timeout_ms = 1500, lsp_format = "fallback" }
            end
          '';
        };
      };
    };

    # Imperative bits that don't map cleanly to nixvim options: native LSP
    # config + LspAttach maps, which-key group names, the centering plugin,
    # and treechat.
    extraConfigLua = ''
      -- ================= LSP =================
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        settings = { Lua = { diagnostics = { globals = { "vim" } } } },
      })

      vim.lsp.config("vue_ls", { capabilities = capabilities })

      vim.lsp.config("clangd", { capabilities = capabilities })

      vim.lsp.config("nixd", { capabilities = capabilities })

      vim.lsp.config("ts_ls", {
        capabilities = capabilities,
        init_options = {
          plugins = {
            {
              name = "@vue/typescript-plugin",
              location = "${vueLsPath}",
              languages = { "vue" },
            },
          },
        },
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
      })

      vim.lsp.enable("lua_ls")
      vim.lsp.enable("vue_ls")
      vim.lsp.enable("ts_ls")
      vim.lsp.enable("clangd")
      vim.lsp.enable("nixd")

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = { buffer = args.buf, silent = true }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to Definition" }))
          vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover Docs" }))
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename Variable" }))
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code Action" }))
        end,
      })

      -- ============ which-key groups ============
      require('which-key').add({
        { '<leader>f', group = 'Find' },
        { '<leader>c', group = 'Code' },
        { '<leader>r', group = 'Rename/Refactor' },
        { '<leader>t', group = 'Terminal' },
        { '<leader>g', group = 'Git' },
      })

      -- ============ :Center ============
      local ratio = 1 / 2
      local pads = {}

      local function close_pads()
        for _, w in ipairs(pads) do
          if vim.api.nvim_win_is_valid(w) then vim.api.nvim_win_close(w, true) end
        end
        pads = {}
      end

      local function open_pads()
        close_pads()
        local content = math.floor(vim.o.columns * ratio)
        if content < 60 then return end
        local side = math.floor((vim.o.columns - math.floor(vim.o.columns * ratio)) / 2)
        if side < 1 then return end

        local main = vim.api.nvim_get_current_win()

        for _, cmd in ipairs({ "topleft vsplit", "botright vsplit" }) do
          vim.cmd(cmd)
          local win = vim.api.nvim_get_current_win()
          local buf = vim.api.nvim_create_buf(false, true)

          vim.bo[buf].buftype = "nofile"
          vim.bo[buf].bufhidden = "wipe"
          vim.bo[buf].swapfile = false
          vim.api.nvim_win_set_buf(win, buf)
          vim.api.nvim_win_set_width(win, side)

          vim.wo[win].number = false
          vim.wo[win].relativenumber = false
          vim.wo[win].signcolumn = "no"
          vim.wo[win].cursorline = false
          vim.wo[win].winfixwidth = true
          vim.wo[win].fillchars = "eob: "
          vim.wo[win].statusline = " "
          vim.wo[win].winhighlight = "StatusLine:Normal,StatusLineNC:Normal,WinSeparator:Normal"

          pads[#pads + 1] = win
        end

        vim.api.nvim_set_current_win(main)
      end

      vim.api.nvim_create_user_command("Center", function()
        if #pads > 0 then close_pads() else open_pads() end
      end, {})

      vim.api.nvim_create_user_command("CenterRatio", function(o)
        ratio = tonumber(o.args) or ratio
        if #pads > 0 then open_pads() end
      end, { nargs = 1 })

      vim.api.nvim_create_autocmd("VimResized", {
        callback = function() if #pads > 0 then open_pads() end end,
      })

      -- Not auto-opened on VimEnter: the pads are real windows and trapped
      -- <C-h>/<C-l> navigation. Toggle on demand.
      vim.keymap.set("n", "<leader>z", "<cmd>Center<cr>", { desc = "Center buffer" })

      vim.api.nvim_create_autocmd("QuitPre", {
        callback = function()
          local is_pad = {}
          for _, w in ipairs(pads) do is_pad[w] = true end
          local real = 0
          for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if not is_pad[w] and vim.api.nvim_win_get_config(w).relative == "" then
              real = real + 1
            end
          end
          if real <= 1 then close_pads() end
        end,
      })

      -- ============ treechat ============
      -- Tree-shaped LLM chats on top of pi, loaded from the local dev checkout
      -- so edits apply on nvim restart without a rebuild; skipped when the
      -- checkout isn't there. pcall: a broken dev checkout must not take the
      -- rest of the config down with it.
      local treechat_dir = vim.fn.expand("~/p/treechat.nvim")
      if vim.fn.isdirectory(treechat_dir) == 1 then
        vim.opt.rtp:prepend(treechat_dir)
        local ok, err = pcall(function() require("treechat").setup({}) end)
        if not ok then vim.notify("treechat: " .. err, vim.log.levels.WARN) end
      end
    '';
  };
}
