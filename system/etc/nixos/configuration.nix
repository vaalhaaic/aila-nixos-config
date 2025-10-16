{ config, pkgs, lib, ... }:

let
  # ============================================================
  # 🧰 预设变量区（集中管理，方便统一调整）
  # ------------------------------------------------------------
  systemUser = "mason";
  gentooSnapshotBase = "/home/${systemUser}/snapshots";
  gentooSnapshotDir = "${gentooSnapshotBase}/gentoo";
  gentooMountUuid = "93235277-22bb-49cd-bcfb-6ed243163f07";

  # ------------------------------------------------------------
  # Gentoo 备份脚本：对 /mnt/gentoo 进行硬链接增量备份
  # ------------------------------------------------------------
  # 系统维护工具（保留系统层，确保全局可用）
  gentooSnap = pkgs.writeShellApplication {
    name = "gentoo-snap";
    runtimeInputs = with pkgs; [ coreutils rsync util-linux ];
    text = ''
      set -euo pipefail

      SNAPDIR="${gentooSnapshotDir}"
      NOW="$(date +%Y-%m-%d_%H-%M)"
      LAST="''${SNAPDIR}/latest"
      DEST="''${SNAPDIR}/''${NOW}"

      mkdir -p "''${SNAPDIR}" "''${DEST}"

      echo "Creating snapshot: ''${DEST}"
      sudo rsync -aAX --delete \
        --link-dest="''${LAST}" \
        /mnt/gentoo/ "''${DEST}"

      sudo ln -sfn "''${DEST}" "''${LAST}"
      echo "Snapshot done."
    '';
  };

  # ------------------------------------------------------------
  # Gentoo 回滚脚本：选择快照恢复到 /mnt/gentoo
  # ------------------------------------------------------------
  # 系统维护工具（保留系统层，确保全局可用）
  gentooRollback = pkgs.writeShellApplication {
    name = "gentoo-rollback";
    runtimeInputs = with pkgs; [ coreutils rsync util-linux ];
    text = ''
      set -euo pipefail

      SNAPDIR_BASE="${gentooSnapshotDir}"
      SNAP_ARG="''${1:-latest}"

      if [[ "''${SNAP_ARG}" == "latest" ]]; then
        if [[ ! -L "''${SNAPDIR_BASE}/latest" ]]; then
          echo "Error: ''${SNAPDIR_BASE}/latest not found"
          exit 1
        fi
        SNAP_REAL="$(readlink -f "''${SNAPDIR_BASE}/latest")"
      else
        SNAP_REAL="''${SNAP_ARG}"
      fi

      if [[ ! -d "''${SNAP_REAL}" ]]; then
        echo "Error: snapshot directory missing: ''${SNAP_REAL}"
        exit 1
      fi

      echo "Restoring from snapshot: ''${SNAP_REAL}"
      echo "Target root: /mnt/gentoo (temporarily remounting writable)"
      read -r -p "Confirm rollback? (yes/no) " ans
      [[ "''${ans}" == "yes" ]] || { echo "Cancelled"; exit 1; }

      systemctl start mnt-gentoo.automount >/dev/null 2>&1 || true
      sudo mount -o remount,rw /mnt/gentoo

      sudo rsync -aAXH --delete --numeric-ids \
        --exclude='/proc/*' \
        --exclude='/sys/*'  \
        --exclude='/run/*'  \
        --exclude='/dev/*'  \
        "''${SNAP_REAL}"/ /mnt/gentoo/

      sync
      echo "Rollback complete. Consider rebooting into Gentoo."
    '';
  };

  # ------------------------------------------------------------
  # 常用软件分组：避免一长串包名难以阅读
  # ------------------------------------------------------------
  basePackages = with pkgs; [
    curl
    git
    htop
    neofetch
    pciutils
    tabby
    tmux
    unzip
    usbutils
    wget
  ];

  desktopPackages = with pkgs; [
    anki
    evince
    firefox
    freetube
    gnome-tweaks
    gnomeExtensions.appindicator
    google-chrome
    jellyfin-media-player
    libreoffice-fresh
    obsidian
    stellarium
    vlc
  ];

  creativePackages = with pkgs; [
    blender
    darktable
    kdePackages.kdenlive
    olive-editor
    shotcut
  ];

  gamingPackages = with pkgs; [
    dolphin-emu
    heroic
    lutris
    pcsx2
    retroarch
    superTuxKart
  ];

  devPackages = with pkgs; [
    clang
    clang-tools
    cmake
    gcc
    gdb
    gnumake
    nodejs_22
    nodePackages.npm
    nodePackages.pnpm
    nodePackages.yarn
    pipx
    pkg-config
    python3
    python3Full
    python3Packages.numpy
    python3Packages.simpleaudio
    vscode
  ];

  # ============================================================
  # 🎯 AI 工具包配置
  # ------------------------------------------------------------
  # 包含 Ollama 和其他 AI 工具，移除复杂的 CUDA 编译依赖
  # ============================================================
  aiPackages = with pkgs; [
    ollama        # GPU 加速的 LLM 运行环境
  ];

in
{
  # ============================================================
  # ① 导入其他 Nix 模块（硬件 & 辅助容器）
  # ------------------------------------------------------------
  imports = [
    ./hardware-configuration.nix
    ./containers/reflector.nix
  ];

  # ============================================================
  # ② Nixpkgs 全局开关
  # ------------------------------------------------------------
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  # ============================================================
  # ③ 引导与双系统菜单
  # ------------------------------------------------------------
  boot.loader = {
    systemd-boot.enable = false;
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      useOSProber = true;
      extraEntries = ''
        menuentry "Windows 11" {
          insmod part_gpt
          insmod fat
          insmod chain
          search --fs-uuid --no-floppy --set=root 8004-8C63
          chainloader /EFI/Microsoft/Boot/bootmgfw.efi
        }

        menuentry "Gentoo Linux" {
          insmod ext2
          search --fs-uuid --no-floppy --set=root ${gentooMountUuid}
          linux   /boot/vmlinuz-6.16.9-gentoo-x86_64 root=UUID=${gentooMountUuid} ro
          initrd  /boot/initramfs-6.16.9-gentoo-x86_64.img
        }
      '';
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
  };

  # ============================================================
  # ④ 基础系统信息：主机名 / 时间 / 语言 / 输入法
  # ============================================================
  networking = {
    hostName = "AilaCradle";
    networkmanager.enable = true;
  };

  time.timeZone = "Asia/Shanghai";

  i18n = {
    defaultLocale = "zh_CN.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "zh_CN.UTF-8";
      LC_MONETARY = "zh_CN.UTF-8";
      LC_NUMERIC = "zh_CN.UTF-8";
      LC_ADDRESS = "zh_CN.UTF-8";
      LC_PAPER = "zh_CN.UTF-8";
      LC_NAME = "zh_CN.UTF-8";
      LC_TELEPHONE = "zh_CN.UTF-8";
      LC_MEASUREMENT = "zh_CN.UTF-8";
      LC_IDENTIFICATION = "zh_CN.UTF-8";
    };
    inputMethod = {
      enable = true;
      type = "ibus";
      ibus.engines = with pkgs.ibus-engines; [
        libpinyin
        rime
      ];
    };
  };

  environment.sessionVariables = {
    # 让桌面应用默认使用 IBus 输入法接口
    GTK_IM_MODULE = "ibus";
    QT_IM_MODULE = "ibus";
    XMODIFIERS = "@im=ibus";
  };

  # ============================================================
  # ⑤ 桌面环境：GNOME + 显示管理器
  # ============================================================
  #
  # 🖥️ 显示服务器配置
  services.xserver = {
    enable = lib.mkDefault true;                    # 启用 X11 显示服务器
    videoDrivers = lib.mkDefault [ "nvidia" ];      # 使用 NVIDIA 显卡驱动
    xkb.layout = lib.mkDefault "us";                # 键盘布局：美式键盘

    # 🚪 显示管理器：GDM（GNOME Display Manager）
    displayManager.gdm = {
      enable = lib.mkDefault true;                  # 启用 GDM 登录管理器
      wayland = lib.mkDefault false;                # 禁用 Wayland，使用 X11（兼容性更好）
    };

    # 🖼️ 桌面环境：GNOME
    desktopManager.gnome.enable = lib.mkDefault true;  # 启用 GNOME 桌面环境
  };

  programs.dconf.enable = true;
  services.gnome.gnome-browser-connector.enable = true;

  # ============================================================
  # ⑥ 硬件配置：视频 | 音频 | 外设
  # ============================================================
  #
  # 🖥️ 视频配置：NVIDIA 显卡 + 图形系统
  hardware = {
    nvidia = {
      # 启用模式设置，提高兼容性
      modesetting.enable = true;
      # 禁用电源管理（可能导致编译问题）
      powerManagement.enable = false;
      # 启用 NVIDIA 设置工具
      nvidiaSettings = true;
      # 使用闭源驱动（更稳定）
      open = false;
      # 启用 NVidia 的 Wayland 支持（可选）
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
    # setLdLibraryPath 在 25.05 中已移除，启用 opengl 即可自动处理驱动路径
  };



  # ============================================================
  # 系统服务与桌面会话
  # ------------------------------------------------------------
  # 全局服务开关与基础设置
  # ============================================================
  # 保存当时的配置源文件到系统路径
  system.copySystemConfiguration = true;

  services = {
    # 蓝牙服务
    blueman.enable = true;

    # Flatpak 应用支持
    flatpak.enable = true;

    # 打印服务
    printing.enable = true;

    pulseaudio.enable = false;  # 改用 PipeWire 提供音频

    # PipeWire 音频栈设置
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # 本地网络发现（AirPlay/打印/服务发现）
    avahi = {
      enable = true;
      nssmdns4 = true;
    };

    # SSH 服务配置
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
      };
    };

    # systemd-resolved 统一管理 DNS
    resolved.enable = true;
  };

  security.rtkit.enable = true;  # 低延迟音频所需 real-time kit

    # 防火墙
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 8080 ];
      allowPing = true;
    };

  # 🔵 硬件外设配置
  hardware.bluetooth.enable = true;  # 启用蓝牙硬件支持

  # 💤 电源管理配置
  services.logind.extraConfig = ''
    HandleSuspendKey=ignore
    HandleLidSwitch=ignore
    HandleLidSwitchDocked=ignore
    IdleAction=ignore
    IdleActionSec=0
  '';
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;


  # ============================================================
  # ⑦ 用户与权限管理
  # ============================================================
  #
  # 👤 用户配置：系统主要用户权限设置
  users.users.${systemUser} = {
    isNormalUser = true;
    description = "系统主要用户 - 拥有完整管理权限";

    # 用户组权限：
    # - wheel: 系统管理权限（sudo）
    # - networkmanager: 网络管理权限
    # - video: 视频硬件访问权限
    # - docker: 容器管理权限
    # - audio: 音频设备访问权限（重要！）
    # - ollama: AI服务权限
    extraGroups = [ "wheel" "networkmanager" "video" "docker" "audio" "ollama" ];

    # 用户专属软件包
    packages = with pkgs; [
      gnomeExtensions.appindicator  # GNOME系统托盘扩展
    ];
  };

  # ============================================================
  # ⑧ 系统软件包管理
  # ============================================================
  #
  # 📦 软件包分组说明：
  # - basePackages: 基础系统工具（curl, git, htop等）
  # - desktopPackages: 桌面应用（浏览器、办公套件、媒体播放）
  # - creativePackages: 创意工具（Blender、视频编辑、图像处理）
  # - gamingPackages: 游戏相关（模拟器、游戏平台）
  # - devPackages: 开发工具（编译器、调试器、IDE）
  # - aiPackages: AI工具（Ollama）
  # - gentooSnap/gentooRollback: 自定义Gentoo备份工具
  #
  environment.systemPackages =
    basePackages
    ++ desktopPackages
    ++ creativePackages
    ++ gamingPackages
    ++ devPackages
    ++ aiPackages
    ++ [ gentooSnap gentooRollback ];

  # ============================================================
  # ⑨ Ollama AI 服务配置
  # ============================================================
  #
  # 🤖 Ollama 本地大语言模型服务
  # - enable: 启用 Ollama 服务
  # - acceleration: CUDA GPU 加速
  # - openFirewall: 开放 11434 端口供网络访问
  # - environmentVariables: GPU 设备选择和监听地址
  #
  services.ollama = {
    enable = true;
    acceleration = "cuda";  # 使用 NVIDIA GPU 加速推理
    openFirewall = true;    # 开放防火墙端口 11434

    # 环境变量配置：
    # - CUDA_VISIBLE_DEVICES: 指定使用 GPU 设备 0
    # - OLLAMA_HOST: 监听所有网络接口，端口 11434
    environmentVariables = {
      CUDA_VISIBLE_DEVICES = "0";
      OLLAMA_HOST = "0.0.0.0:11434";
    };
  };

  # ============================================================
  # ⑩ 容器与虚拟化：自建服务 + 测试环境
  # ============================================================
  #
  # 🐳 Docker 容器支持
  virtualisation.docker.enable = true;

  # 📦 系统级容器配置
  # 使用 systemd-nspawn 的轻量级容器，用于：
  # - Aila: 主AI助手容器（自动启动）
  # - ubuntu-test: Ubuntu测试环境
  # - webserver: Web服务测试环境
  #

  containers = {
    Aila = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "10.250.0.1";
      localAddress = "10.250.0.3";
      bindMounts."/shared" = {
        hostPath = "/aila/logs";
        isReadOnly = false;
      };
      config = { config, pkgs, lib, ... }: {
        system.stateVersion = "25.05";
        services.openssh.enable = true;
        services.resolved.enable = true;
        networking.firewall.allowedTCPPorts = [ 22 80 443 ];
        networking.useHostResolvConf = lib.mkForce false;

        environment.systemPackages = with pkgs; [
          vim git curl wget htop
          (python3.withPackages (ps: with ps; [ simpleaudio numpy ]))
        ];

        systemd.services."aila-heartbeat" = {
          description = "Aila Heartbeat Service";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.python3}/bin/python3 /root/feel/sense.py";
            WorkingDirectory = "/root/feel";
            Restart = "always";
            RestartSec = 5;
          };
        };

        systemd.services."aila-interoception" = {
          description = "Aila 内部感知系统";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.python3}/bin/python3 /root/feel/interoception.py";
            WorkingDirectory = "/root/feel";
            Restart = "always";
            RestartSec = 5;
          };
        };

        systemd.services."aila-voice" = {
          description = "Aila Voice Interface";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.python3}/bin/python3 /root/feel/voice.py";
            WorkingDirectory = "/root/feel";
            Restart = "always";
            RestartSec = 5;
          };
        };
      };
    };

    "ubuntu-test" = {
      autoStart = false;
      privateNetwork = true;
      hostAddress = "10.250.0.1";
      localAddress = "10.250.0.2";
      config = { config, pkgs, ... }: {
        system.stateVersion = "25.05";
        services.openssh.enable = true;
        networking.firewall.allowedTCPPorts = [ 22 80 443 ];
        environment.systemPackages = with pkgs; [ vim git curl wget htop ];
      };
    };

    webserver = {
      autoStart = false;
      privateNetwork = true;
      hostAddress = "192.168.100.10";
      localAddress = "192.168.100.11";
      hostAddress6 = "fc00::1";
      localAddress6 = "fc00::2";
      config = { config, pkgs, lib, ... }: {
        system.stateVersion = "25.05";

        networking.firewall.allowedTCPPorts = [ 22 80 443 ];
        services.resolved.enable = true;
        services.openssh.enable = true;
        services.httpd = {
          enable = true;
          adminAddr = "admin@example.org";
        };
        environment.systemPackages = with pkgs; [ vim git curl wget ];

        networking.useHostResolvConf = lib.mkForce false;
        users.users.root.initialPassword = "1234";
      };
    };
  };
  # systemd-nspawn 的 Ubuntu 容器服务
  systemd.services."systemd-nspawn@ubuntu" = {
    description = "Ubuntu container via systemd-nspawn";
    wantedBy = [ "machines.target" ];
    serviceConfig = {
      ExecStart = "/run/current-system/sw/bin/systemd-nspawn -D /var/lib/machines/ubuntu";
      KillMode = "mixed";
      Type = "notify";
      Restart = "on-failure";
    };
  };

  # 宿主为容器转发 NAT，配合 docker/containers 使用
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  networking.nat = {
    enable = true;
    externalInterface = "enp6s0";
    internalInterfaces = [ "ve-ubuntu" "ve-Aila" "ve-ubuntu-test" ];
  };

  # ============================================================
  # ⑪ 文件系统与挂载管理
  # ============================================================
  #
  # 📁 Gentoo 工作区挂载
  # 以只读方式挂载 Gentoo 系统，支持自动挂载和超时卸载
  fileSystems."/mnt/gentoo" = {
    device = "/dev/disk/by-uuid/${gentooMountUuid}";
    fsType = "ext4";
    options = [
      "ro"                    # 只读挂载，保护源系统
      "nofail"                # 启动时不因挂载失败而停止
      "x-systemd.automount"   # 自动挂载支持
      "x-systemd.idle-timeout=600"  # 空闲10分钟后自动卸载
    ];
  };

  # 📸 快照目录创建
  # 为 Gentoo 备份系统创建必要的目录结构
  systemd.tmpfiles.rules = [
    "d ${gentooSnapshotBase} 0755 ${systemUser} ${systemUser} -"
    "d ${gentooSnapshotDir} 0755 ${systemUser} ${systemUser} -"
  ];

  # ============================================================
  # ⑫ 系统优化与维护
  # ============================================================
  #
  # 🔤 字体配置：多语言支持
  fonts.packages = with pkgs; [
    noto-fonts           # Google Noto 字体系列（多语言）
    noto-fonts-cjk-sans  # Noto CJK 字体（中日韩）
    noto-fonts-emoji     # Noto Emoji 表情符号字体
    wqy_microhei         # 文泉驿微米黑（中文）
  ];

  # 🗑️ Nix 系统维护
  # 自动垃圾回收：每周清理30天前的旧版本
  nix.settings = {
    auto-optimise-store = true;      # 自动优化存储空间
    experimental-features = [ "nix-command" "flakes" ];  # 启用实验功能
  };

  nix.gc = {
    automatic = true;    # 自动垃圾回收
    dates = "weekly";    # 每周执行
    options = "--delete-older-than 30d";  # 删除30天前的旧版本
  };

  # 💾 交换分区配置
  swapDevices = [
    { device = "/dev/disk/by-uuid/b92bb72b-38f3-4036-b939-fe9b7fe6b9d5"; }
  ];

  # ============================================================
  # ⑬ 系统环境变量配置
  # ============================================================
  #
  # 🔧 硬件兼容性环境变量
  # 确保 NVIDIA GPU 驱动和 Ollama 能够正确访问 GPU 库文件

  # ============================================================
  # ⑭ 系统版本基线
  # ============================================================
  # 重要：这是系统升级的关键配置，请勿随意修改
  system.stateVersion = "25.05";
}





