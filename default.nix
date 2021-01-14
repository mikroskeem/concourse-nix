{ pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchpatch ? pkgs.fetchpatch
, mkDerivation ? stdenv.mkDerivation
, buildGoModule ? pkgs.buildGoModule
, fetchFromGitHub ? pkgs.fetchFromGitHub
, makeWrapper ? pkgs.makeWrapper
, btrfs-progs ? pkgs.btrfs-progs
, cni-plugins ? pkgs.cni-plugins
, containerd ? pkgs.containerd
, glibc ? pkgs.glibc
, iptables ? pkgs.iptables
, packr ? pkgs.packr
, runc ? pkgs.runc
, postgresql ? pkgs.postgresql
}: let
  debugBuild = false;

  # TODO:
  # 2) Resource types?
  # 4) gdn?
  # 5) web does not work - need to buld the assets
in buildGoModule rec {
  pname = "concourse";
  #version = "6.7.3";
  version = "df62ba0d8a2d4b1b2d99bff9a25bb00874e8eb6e";

  src = fetchFromGitHub {
    owner = "concourse";
    repo = "concourse";
    rev = version; #"v${version}";
    #sha256 = "0icwr7b4lrjxpdirxg7f6h5z8mavf90drwykkmy1j71favzhrajx"; # 6.7.3
    sha256 = "0v10rsmrzc75v9ghn43h3nz2wvm35jfnc9sjxsjr9wns4mfldcd0";
  };

  # Concourse init
  init = mkDerivation {
    name = "concourse-worker-init-${version}";
    inherit src;

    dontConfigure = true;

    buildInputs = [ glibc glibc.static ];

    buildPhase = ''
      cc -O2 -static -o init ./cmd/init/init.c
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp ./init $out/bin/init
    '';
  };

  #vendorSha256 = "0000000000000000000000000000000000000000000000000000";
  #vendorSha256 = "0bsymg8k1qfa6a9zggg6vb2mbhl6nzc4bg6h0msy93sbqaanvsn5"; # 6.7.3
  vendorSha256 = "1smvzzcdkln9sricsdy24bdj1srd7zzzljkiy85g9sqm7cnzrv78";
  subPackages = [ "cmd/concourse" ];

  doCheck = true;
  checkInputs = [ postgresql ];

  nativeBuildInputs = [ packr makeWrapper ];

  patches = [
    (fetchpatch {
      # worker: behaviour: make containerd socket path configurable
      url = "https://github.com/concourse/concourse/commit/b4e5daa9b6c11ffbd973158bc14e0e52d1b6062c.patch";
      sha256 = "1cypqkmsvgj9hwc1vzs5i43lpv4safr1ipwwmzc8n1b7gkdc6jbs";
    })

    (fetchpatch {
      # worker: behaviour: mount init read-only
      url = "https://github.com/mikroskeem/concourse/commit/4f2aef203a33a6b8a8a029a163a1a358783f8386.patch";
      sha256 = "0hhfd82b8zlz1kbj8r2mh6ak55narb5d17h4xqy2h26z20c1zxcs";
    })
  ];

  postPatch = ''
  '' + lib.optionalString stdenv.isLinux (let
    initBin = "${init}/bin/init";
  in ''
    substituteInPlace worker/workercmd/worker_linux.go \
                      --replace /usr/local/concourse/bin/init ${initBin} \
                      --replace 'long:"cni-plugins-dir" default:"/usr/local/concourse/bin"' 'long:"cni-plugins-dir" default:"${cni-plugins}/bin"'

    substituteInPlace worker/runtime/spec/mounts.go \
                      --replace /usr/local/concourse/bin/init ${initBin}

    substituteInPlace worker/runtime/cni_network.go \
                      --replace /usr/local/concourse/bin ${cni-plugins}/bin
  '');

  preBuild = ''
    packr
  '';

  buildFlagsArray = [
    "-ldflags=-X github.com/concourse/concourse.Version=${version}"
  ];

  postInstall = ''
    mkdir -p $out/libexec
    mv $out/bin/concourse $out/libexec/
    makeWrapper $out/libexec/concourse $out/bin/concourse \
                --prefix PATH : ${lib.makeBinPath [ btrfs-progs cni-plugins containerd iptables runc ]} \
                --set CONCOURSE_RUNTIME containerd
  '';

  meta = {
    platforms = lib.platforms.linux;
  };
}
