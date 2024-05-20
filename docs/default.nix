{ lib
, stdenvNoCC
, writeText
, runCommand
, mdbook
, transpire
, ...
}:

let
  # Some helpers for splitting the long list of options into pages

  chapterPats = [
    [ "namespaces" "<name>" "resources" "*" "*" ]
    [ "namespaces" "<name>" "*" ]
    [ "*" ]
  ];

  locSegMatchesPatSeg = locSeg: patSeg: patSeg == "*" || patSeg == locSeg;
  locMatchesPat = loc: pat: lib.all lib.id (lib.zipListsWith locSegMatchesPatSeg loc pat);
  locToName = loc: lib.concatStringsSep "." (map lib.strings.escapeNixIdentifier loc);

  chapterName = opt: locToName
    (lib.zipListsWith
      (_: locSeg: locSeg)
      (lib.findFirst (locMatchesPat opt.loc) [ ] chapterPats)
      opt.loc);

  # Generate docs and split into pages

  eval = transpire.evalModules {
    modules = [{
      options._module.args = lib.mkOption { internal = true; };
      config._module.check = false;
    }];
  };

  docList = builtins.filter
    (opt: opt.visible && !opt.internal)
    (lib.optionAttrSetToDocList eval.options);

  docPages = builtins.groupBy chapterName docList;

  # Generate a Markdown file for each documentation page containing the options.
  # Originally, `writeText` was used for each page and `linkFarmFromDrvs` was
  # used to combine them together, but this resulted in a large number of
  # derivations, slowing down the build. Instead, we now generate a single
  # derivation that writes all pages at once.

  mdEscape = text: lib.escape [ "*" "<" "[" "`" "." "#" "&" "\\" ] text;
  pathEscape = text: builtins.replaceStrings [ "/" "'" "\"" "<" ">" ] [ "-" "-" "-" "-" "-" ] text;

  renderOption = opt: (
    "## ${mdEscape opt.name}\n\n"
    + opt.description
    + "\n\n*Type:* ${opt.type}"
    + lib.optionalString opt.readOnly "*(read only)*"
    + lib.optionalString (opt ? default) "\n\n*Default:* `${opt.default.text}`"
  );

  pages = lib.mapAttrs
    (name: opts: (lib.concatStringsSep "\n\n\n" (map renderOption opts)))
    docPages;

  pageCommands = lib.mapAttrsToList
    (name: text: "echo -n ${lib.escapeShellArg text} > $out/'${pathEscape name}.md' ")
    pages;

  referenceDrv = runCommand "transpire-reference" { } ''
    mkdir -p $out
    ${lib.concatStringsSep "\n" pageCommands}
  '';

  # Append links to every page to the SUMMARY.md file.
  # This allows mdBook to find our page.

  summaryExtDrv = writeText "SUMMARY-ext.md" (lib.concatLines
    (lib.mapAttrsToList
      (name: _: "  - [${mdEscape name}](reference/${pathEscape name}.md)")
      docPages));
in
stdenvNoCC.mkDerivation {
  name = "transpire-docs";
  src = ./.;

  nativeBuildInputs = [
    mdbook
  ];

  buildPhase = ''
    ln -s ${referenceDrv} src/reference
    cat ${summaryExtDrv} >> src/SUMMARY.md
    mdbook build
  '';

  installPhase = ''
    mv book $out
  '';
}
