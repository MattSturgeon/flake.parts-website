{ inputs, ... }: {
  perSystem = { config, self', inputs', pkgs, lib, ... }: {

    /*
      Check the links, including anchors (not currently supported by mdbook)

      Putting this in a separate check has the benefits that
       - output can always be inspect with browser
       - this slow check (1 minute) is not part of the iteration cycle

      Ideally https://github.com/linkchecker/linkchecker/pull/661 is merged
      upstream, so that it's quick and can run often without blocking the
      iteration cycle unnecessarily.
    */
    checks.linkcheck = pkgs.runCommand "linkcheck"
      {
        nativeBuildInputs = [ pkgs.linkchecker pkgs.python3 ];
        site = config.packages.default;
      } ''
      # https://linkchecker.github.io/linkchecker/man/linkcheckerrc.html
      cat >>$TMPDIR/linkcheckrc <<EOF
      [checking]
      threads=''${NIX_BUILD_CORES:-4}

      [AnchorCheck]

      EOF

      echo Checking $site
      linkchecker -f $TMPDIR/linkcheckrc $site/

      touch $out
    '';

    packages = {
      default = pkgs.stdenvNoCC.mkDerivation {
        name = "site";
        nativeBuildInputs = [
          pkgs.mdbook
          pkgs.mdbook-linkcheck
          pkgs.mdbook-mermaid
        ];
        src = ./.;
        buildPhase = ''
          runHook preBuild

          {
            while read ln; do
              case "$ln" in
                *end_of_intro*)
                  break
                  ;;
                *)
                  echo "$ln"
                  ;;
              esac
            done
            cat src/intro-continued.md
          } <${inputs.flake-parts + "/README.md"} >src/README.md

          mkdir -p src/options
          for f in ${config.packages.generated-docs}/*.html; do
            cp "$f" "src/options/$(basename "$f" .html).md"
          done
          mdbook build --dest-dir $TMPDIR/out
          cp -r $TMPDIR/out/html $out

          echo '<html><head><script>window.location.pathname = window.location.pathname.replace(/options.html$/, "") + "options/flake-parts.html"</script></head><body><a href="options/flake-parts.html">to the options</a></body></html>' \
            >$out/options.html

          runHook postBuild
        '';
        dontInstall = true;
      };
    };
  };
}
