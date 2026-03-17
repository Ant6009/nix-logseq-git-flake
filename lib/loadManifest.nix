{ lib, manifestPath }:
let
  inherit (builtins) fromJSON hasAttr readFile;
  inherit (lib) concatStringsSep hasPrefix throwIf;
  parsed = fromJSON (readFile manifestPath);
  requiredKeys = [
    "tag"
    "publishedAt"
    "assetUrl"
    "assetSha256"
    "logseqRev"
    "logseqVersion"
    "cliSrcHash"
    "cliYarnDepsHash"
    "cliVersion"
  ];
  missing = lib.filter (key: !hasAttr key parsed) requiredKeys;
  validateHash =
    acc: key:
    throwIf (
      !hasPrefix "sha256-" parsed.${key}
    ) "Manifest ${key} must begin with sha256- (Nix SRI)." acc;
  # Validate per-platform assets map when present
  validateAssets =
    acc:
    if hasAttr "assets" parsed then
      let
        platforms = lib.attrNames parsed.assets;
        validatePlatform =
          inner: plat:
          let
            entry = parsed.assets.${plat};
          in
          throwIf (!hasAttr "url" entry || !hasAttr "sha256" entry)
            "Manifest assets.${plat} must have 'url' and 'sha256' keys."
            (
              throwIf (!hasPrefix "sha256-" entry.sha256)
                "Manifest assets.${plat}.sha256 must begin with sha256- (Nix SRI)."
                inner
            );
      in
      builtins.foldl' validatePlatform acc platforms
    else
      acc;
in
throwIf (missing != [ ]) "Manifest missing required keys: ${concatStringsSep ", " missing}" (
  validateAssets (
    builtins.foldl' validateHash parsed [
      "assetSha256"
      "cliSrcHash"
      "cliYarnDepsHash"
    ]
  )
)
