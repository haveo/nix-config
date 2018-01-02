{ config, lib, pkgs, ... }:
{
  system.defaults.NSGlobalDomain.AppleKeyboardUIMode = 3;
  system.defaults.NSGlobalDomain.ApplePressAndHoldEnabled = false;

  system.defaults.dock.autohide    = true;
  system.defaults.dock.launchanim  = false;
  system.defaults.dock.orientation = "right";

  system.defaults.trackpad.Clicking = true;

  launchd.daemons = {
    cleanup = {
      command = "/Users/johnw/bin/cleanup -u";
      serviceConfig.StartInterval = 86400;
    };

    collectgarbage = {
      command = "${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 14d";
      serviceConfig.StartInterval = 86400;
    };

    pdnsd = {
      script = ''
        cp -p ${pkgs.johnw-home}/etc/pdnsd.conf /tmp/.pdnsd.conf
        chown root /tmp/.pdnsd.conf
        ${pkgs.pdnsd}/sbin/pdnsd -c /tmp/.pdnsd.conf
      '';
      serviceConfig.RunAtLoad = true;
    };
  };

  launchd.user.agents = {
    dovecot = {
      command = "${pkgs.dovecot}/libexec/dovecot/imap -c /etc/dovecot/dovecot.conf";
      serviceConfig.WorkingDirectory = "${pkgs.dovecot}/lib";
      serviceConfig.inetdCompatibility.Wait = "nowait";
      serviceConfig.Sockets.Listeners = {
        SockNodeName = "127.0.0.1";
        SockServiceName = "9143";
      };
    };

    # leafnode = {
    #   command = "${pkgs.leafnode}/sbin/leafnode -d ~/Messages/Newsdir -F ~/Messages/leafnode/config";
    #   serviceConfig.WorkingDirectory = "${pkgs.dovecot}/lib";
    #   serviceConfig.inetdCompatibility.Wait = "nowait";
    #   serviceConfig.Sockets.Listeners = {
    #     SockNodeName = "127.0.0.1";
    #     SockServiceName = "9119";
    #   };
    # };

    languagetool = {
      script = ''
        ${pkgs.jdk8}/bin/java                                      \
            -cp ${pkgs.languagetool}/share/languagetool-server.jar \
            org.languagetool.server.HTTPServer                     \
            --port 8099 --allow-origin "*"
      '';
      serviceConfig.RunAtLoad = true;
    };

    rdm = {
      script = ''
        ${pkgs.rtags}/bin/rdm \
            --verbose \
            --launchd \
            --inactivity-timeout 300 \
            --log-file /Users/johnw/Library/Logs/rtags.launchd.log
      '';
      serviceConfig.Sockets.Listeners.SockPathName = "/Users/johnw/.rdm";
    };

    # znc = {
    #   command = "${pkgs.znc}/bin/znc";
    #   serviceConfig.RunAtLoad = true;
    # };
  };

  environment.etc."per-user/johnw/aspell.conf".text = ''
    data-dir ${pkgs.aspell}/lib/aspell
  '';

  environment.etc."per-user/johnw/scdaemon-wrapper".text = ''
    #!/bin/bash
    export DYLD_FRAMEWORK_PATH=/System/Library/Frameworks
    exec ${pkgs.gnupg}/libexec/scdaemon "$@"
  '';

  environment.etc."per-user/johnw/gpg-agent.conf".text = ''
    enable-ssh-support
    default-cache-ttl 600
    max-cache-ttl 7200
    pinentry-program ${pkgs.pinentry_mac}/Applications/pinentry-mac.app/Contents/MacOS/pinentry-mac
    scdaemon-program /Users/johnw/.gnupg/scdaemon-wrapper
  '';

  environment.etc."per-user/johnw/com.dannyvankooten.browserpass.json".text = ''
    {
      "name": "com.dannyvankooten.browserpass",
      "description": "Browserpass binary for the Firefox extension",
      "path": "${pkgs.browserpass}/bin/browserpass",
      "type": "stdio",
      "allowed_extensions": [
        "browserpass@maximbaz.com"
      ]
    }
  '';

  environment.etc."msmtp.conf".text = ''
    defaults

    tls on
    tls_starttls on
    tls_trust_file ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

    account fastmail
    host smtp.fastmail.com
    port 587
    auth on
    user johnw@newartisans.com
    passwordeval pass smtp.fastmail.com
    from johnw@newartisans.com
    logfile /Users/johnw/Library/Logs/msmtp.log
  '';

  environment.etc."dovecot/dovecot.conf".text = ''
    auth_mechanisms = plain
    disable_plaintext_auth = no
    lda_mailbox_autocreate = yes
    log_path = syslog
    mail_gid = 20
    mail_location = mdbox:/Users/johnw/Messages/Mailboxes
    mail_plugin_dir = ${pkgs.dovecot-plugins}/etc/dovecot/modules
    mail_plugins = fts fts_lucene zlib
    mail_uid = 501
    postmaster_address = postmaster@newartisans.com
    protocols = imap
    sendmail_path = ${pkgs.msmtp}/bin/sendmail
    ssl = no
    syslog_facility = mail

    protocol lda {
      mail_plugins = $mail_plugins sieve
    }
    userdb {
      driver = prefetch
    }

    passdb {
      driver = static
      args = uid=501 gid=20 home=/Users/johnw password=pass
    }

    namespace {
      type = private
      separator = .
      prefix =
      location =
      inbox = yes
      subscriptions = yes
    }

    plugin {
      fts = lucene
      fts_squat = partial=4 full=10

      fts_lucene = whitespace_chars=@.
      fts_autoindex = yes

      zlib_save_level = 6
      zlib_save = gz
    }
    plugin {
      sieve_extensions = +editheader
      sieve = ~/Messages/dovecot.sieve
      sieve_dir = ~/Messages/sieve
    }
  '';

  environment.etc."fetchmailrc".text = ''
    poll imap.fastmail.com protocol IMAP port 993
      user 'johnw@newartisans.com' there is johnw here
      ssl sslcertck sslcertfile "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      folder INBOX
      fetchall
      mda "${pkgs.dovecot}/libexec/dovecot/dovecot-lda -e"
  '';

  environment.etc."fetchmailrc.lists".text = ''
    poll imap.fastmail.com protocol IMAP port 993
      user 'johnw@newartisans.com' there is johnw here
      ssl sslcertck sslcertfile "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      folder 'Lists'
      fetchall
      mda "${pkgs.dovecot}/libexec/dovecot/dovecot-lda -e -m list.misc"
  '';

  system.activationScripts.extraPostActivation.text = ''
    chflags nohidden ~/Library

    ln -sf /etc/bashrc ~/.bashrc

    cp -p /etc/fetchmailrc ~/.fetchmailrc
    chown johnw ~/.fetchmailrc
    chmod 0600 ~/.fetchmailrc

    cp -p /etc/fetchmailrc.lists ~/.fetchmailrc.lists
    chown johnw ~/.fetchmailrc.lists
    chmod 0600 ~/.fetchmailrc.lists

    for i in                                    \
        /etc/per-user/johnw/aspell.conf         \
        ${pkgs.johnw-home}/dot-files/*
    do
        ln -sf $i ~/.$(basename $i)
    done

    mkdir -p ~/.parallel
    touch ~/.parallel/will-cite

    rm -f ~/.gitconfig
    cp -p ${pkgs.johnw-home}/dot-files/gitconfig ~/.gitconfig
    git config --global http.sslCAinfo "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    git config --global http.sslverify true

    cp -p /etc/per-user/johnw/scdaemon-wrapper ~/.gnupg
    chmod +x ~/.gnupg/scdaemon-wrapper

    cp -p /etc/per-user/johnw/gpg-agent.conf ~/.gnupg
    ${pkgs.gnupg}/bin/gpgconf --launch gpg-agent

    for file in                                           \
        Library/KeyBindings/DefaultKeyBinding.dict        \
        Library/Keyboard\ Layouts/PersianDvorak.keylayout \
        Library/Scripts
    do
        dir=$(dirname "$file")
        mkdir -p ~/"$dir"
        ln -sf "${pkgs.johnw-home}/$file" ~/"$file"
    done

    for file in \
        Library/Application\ Support/Mozilla/NativeMessagingHosts/com.dannyvankooten.browserpass.json
    do
        dir=$(dirname "$file")
        mkdir -p ~/"$dir"
        ln -sf "/etc/per-user/johnw/$(basename "$file")" ~/"$file"
    done
  '';

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowBroken = true;

  nixpkgs.config.packageOverrides = pkgs:
    import ./overrides.nix { pkgs = pkgs; };

  environment.systemPackages = with pkgs; [
    nix-prefetch-scripts
    nix-repl
    nix-scripts

    coreutils
    johnw-home
    johnw-scripts

    # gitToolsEnv
    diffstat
    diffutils
    ghi
    gist
    git-scripts
    gitRepo
    gitAndTools.git-imerge
    gitAndTools.gitFull
    gitAndTools.gitflow
    gitAndTools.hub
    gitAndTools.tig
    gitAndTools.git-annex
    gitAndTools.git-annex-remote-rclone
    (haskell.lib.justStaticExecutables haskPkgs.git-all)
    (haskell.lib.justStaticExecutables haskPkgs.git-monitor)
    patch
    patchutils

    # jsToolsEnv
    jq
    nodejs
    nodePackages.eslint
    nodePackages.csslint
    nodePackages.jsontool
    jquery

    # langToolsEnv
    global
    (haskell.lib.justStaticExecutables haskPkgs.bench)
    (haskell.lib.justStaticExecutables haskPkgs.hpack)
    autoconf
    automake
    libtool
    pkgconfig
    clang
    libcxx
    libcxxabi
    llvm
    cmake
    ninja
    gnumake
    rabbitmq-c
    lp_solve
    cabal2nix
    cabal-install
    rtags
    gmp
    mpfr
    htmlTidy
    idutils
    lean
    ott
    R
    sbcl
    sloccount
    verasco

    # mailToolsEnv
    dovecot
    dovecot-plugins
    contacts
    fetchmail
    imapfilter
    leafnode
    msmtp

    # networkToolsEnv
    aria2
    backblaze-b2
    bazaar
    cacert
    httrack
    mercurialFull
    iperf
    nmap
    lftp
    mtr
    dnsutils
    openssh
    openssl
    pdnsd
    privoxy
    rclone
    rsync
    sipcalc
    socat2pre
    spiped
    subversion
    w3m
    wget
    youtube-dl
    znc
    zncModules.fish
    zncModules.push

    # publishToolsEnv
    hugo
    biber
    dot2tex
    doxygen
    graphviz-nox
    highlight
    languagetool
    ledger
    pdf-tools-server
    poppler
    sourceHighlight
    # texinfo
    yuicompressor
    (haskell.lib.justStaticExecutables haskPkgs.lhs2tex)
    (haskell.lib.justStaticExecutables haskPkgs.sitebuilder)
    texFull

    # pythonToolsEnv
    python3
    python27
    pythonDocs.pdf_letter.python27
    pythonDocs.html.python27
    python27Packages.setuptools
    python27Packages.pygments
    python27Packages.certifi

    # systemToolsEnv
    aspell
    aspellDicts.en
    bashInteractive
    bash-completion
    nix-bash-completions
    browserpass
    ctop
    direnv
    exiv2
    findutils
    fzf
    gawk
    gnugrep
    gnupg
    paperkey
    gnuplot
    gnused
    gnutar
    (haskell.lib.justStaticExecutables haskPkgs.hours)
    (haskell.lib.justStaticExecutables haskPkgs.pushme)
    (haskell.lib.justStaticExecutables haskPkgs.runmany)
    (haskell.lib.justStaticExecutables haskPkgs.simple-mirror)
    (haskell.lib.justStaticExecutables haskPkgs.sizes)
    (haskell.lib.justStaticExecutables haskPkgs.una)
    imagemagick_light
    jdk8
    jenkins
    less
    multitail
    renameutils
    p7zip
    pass
    parallel
    pinentry_mac
    postgresql96
    pv
    # jww (2017-12-26): Waiting on https://bugs.launchpad.net/qemu/+bug/1714750
    # qemu
    ripgrep
    rlwrap
    screen
    silver-searcher
    srm
    sqlite
    stow
    time
    tmux
    tree
    unrar
    unzip
    watch
    xz
    z3
    cvc4
    zip
    zsh
  ];

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.bash.enable = true;

  # Recreate /run/current-system symlink after boot.
  services.nix-daemon.enable = true;
  services.activate-system.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 2;

  # You should generally set this to the total number of logical cores in your
  # system. (sysctl -n hw.ncpu)
  nix.maxJobs = 4;
  nix.nixPath =
    [ # Use local nixpkgs checkout instead of channels.
      "darwin-config=$HOME/src/nix/darwin-configuration.nix"
      "darwin=$HOME/oss/darwin"
      "nixpkgs=$HOME/oss/nixpkgs"
      "nixpkgs-next=$HOME/oss/nixpkgs-next"
      "$HOME/.nix-defexpr/channels"
    ];

  nix.trustedUsers = [ "johnw" ];
  nix.extraOptions = ''
    gc-keep-outputs = true
    gc-keep-derivations = true
    env-keep-derivations = true
  '';

  programs.nix-index.enable = true;

  environment.etc."bash.local".text = ''
    if [[ -x "$(which docker-machine)" ]]; then
        if docker-machine status default > /dev/null 2>&1; then
            eval $(docker-machine env default) > /dev/null 2>&1
        fi
    fi

    export GPG_TTY=$(tty)
    if [ -f $HOME/.gpg-agent-info ]; then
        . $HOME/.gpg-agent-info
        export GPG_AGENT_INFO
        export SSH_AUTH_SOCK
        export SSH_AGENT_PID
    fi

    shopt -s histappend

    for path in                                     \
        /usr/X11/man                                \
        /Developer/usr/share/man                    \
        /usr/share/man                              \
        /usr/local/share/man                        \
        $HOME/run/current-system/sw/man             \
        $HOME/run/current-system/sw/share/man       \
        $HOME/.nix-profile/man                      \
        $HOME/.nix-profile/share/man
    do
        export MANPATH=$path:$MANPATH
    done

    # mkdir -p /tmp/current-load
    # chmod a+rwX /tmp/current-load
    #
    # export NIX_BUILD_HOOK=$HOME/.nix-profile/libexec/nix/build-remote.pl
    # export NIX_REMOTE_SYSTEMS=$HOME/.nixpkgs/remote-systems.conf
    # export NIX_CURRENT_LOAD=/tmp/current-load
  '';

  environment.pathsToLink = [ "/info" "/etc" "/share" ];

  environment.variables = {
    ALTERNATE_EDITOR   = "vi";
    COLUMNS            = "100";
    COQVER             = "87";
    EDITOR             = "emacsclient -a vi";
    EMACSVER           = "26";
    EMAIL              = "johnw@newartisans.com";
    GHCPKGVER          = "822";
    GHCVER             = "82";
    GIT_PAGER          = "less";
    HISTCONTROL        = "ignoreboth:erasedups";
    HISTFILE           = "/Users/johnw/.bash_history";
    HISTFILESIZE       = "50000";
    HISTSIZE           = "50000";
    JAVA_OPTS          = "-Xverify:none";
    LC_CTYPE           = "en_US.UTF-8";
    # LD_LIBRARY_PATH    = "/usr/local/lib:\\$LD_LIBRARY_PATH";
    LEDGER_COLOR       = "true";
    LESS               = "-FRSXM";
    LESSCHARSET        = "utf-8";
    PAGER              = "less";
    PASSWORD_STORE_DIR = "/Users/johnw/doc/.passwords";
    PROMPT_DIRTRIM     = "2";
    PS1                = "\\D{%H:%M} \\h:\\W $ ";
    SAVEHIST           = "50000";
    SSH_AUTH_SOCK      = "/Users/johnw/.gnupg/S.gpg-agent.ssh";
    WORDCHARS          = "";
  };

  environment.shellAliases = {
    b       = "git branch --color -v";
    g       = "hub";
    ga      = "git-annex";
    gerp    = "grep";
    git     = "hub";
    l       = "git l";
    ls      = "ls --color=auto";
    par     = "parallel";
    rehash  = "hash -r";
    rm      = "rmtrash";
    scp     = "rsync -aP --inplace";
    snaplog = "git log refs/snapshots/\\$(git symbolic-ref HEAD)";
    w       = "git status -sb";
  };
}
