{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # zigscient-src = {
    #   url = "https://github.com/nuIIpointerexception/zigscient-builds/releases/download/20250223/zigscient-x86_64-linux-gnu.zip";
    #   flake = false;
    # };
  };

  outputs = {...} @ inputs: let
    system = "x86_64-linux";
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    pico-sdk = pkgs.pico-sdk.overrideAttrs rec {
      pname = "pico-sdk";
      version = "2.1.0";
      src = pkgs.fetchFromGitHub {
        owner = "raspberrypi";
        repo = pname;
        rev = version;
        fetchSubmodules = true;
        sha256 = "sha256-nLn6H/P79Jbk3/TIowH2WqmHFCXKEy7lgs7ZqhqJwDM=";
      };
    };

    # zigscient = pkgs.stdenvNoLibs.mkDerivation {
    #   name = "zigscient";
    #   src = inputs.zigscient-src;
    #   dontUnpack = true;
    #   # nativeBuildInputs = [pkgs.unzip];
    #   # unpackCmd="unzip $curSrc";
    #   installPhase = ''
    #     ls $src
    #     mkdir -p $out/bin
    #     cp $src $out/bin/zls
    #     chmod +x $out/bin/zls
    #   '';
    # };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        pkgs.zig_0_13
        pkgs.zls
        # zigscient

        # utils
        pkgs.udisks
        pkgs.tio
        pkgs.picocom
        pkgs.openocd-rp2040
        pkgs.gdb

        # pico deps
        pico-sdk
        pkgs.gcc-arm-embedded

        # c deps
        pkgs.cmake
        pkgs.clang-tools
        pkgs.python3
      ];

      PICO_SDK_PATH = "${pico-sdk}/lib/pico-sdk";
      ARM_NONE_EABI_PATH = "${pkgs.gcc-arm-embedded}/arm-none-eabi/include";
    };

    formatter.${system} = pkgs.alejandra;
  };
}
