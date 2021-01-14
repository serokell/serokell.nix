{ lib }:

let
  foldRecursiveUpdateDefinitions =
    builtins.foldl' (res: def: lib.recursiveUpdate res def.value) { };
  # Throw if a config value is unset
  # We can't just do `unsetValue = path: throw ...` because recursiveUpdate
  # will lazily evaluate it and that results in a throw. If we add a proxy
  # attrset, lazily evaluating it doesn't throw, but deeply evaluating it
  # (which toJSON does) throws.
  unsetValue = path: {
    fakeValue = throw "You haven't set ${
        builtins.concatStringsSep "." path
      }, and it's a required field";
  };

  # Throw if a config value is null
  throwForRequired = loc:
    lib.mapAttrsRecursive (path: value:
      if value == "__required__" then unsetValue (loc ++ path) else value);

in {
  attrsRec = lib.mkOptionType {
    name = "attrsRec";
    description = "attribute set with all definitions merged recursively";
    check = lib.isAttrs;
    merge = loc: foldRecursiveUpdateDefinitions;
    emptyValue = { value = { }; };
  };

  attrsRecWithRequired = lib.mkOptionType {
    name = "attrsRecThrowForNulls";
    description =
      "attribute set with all defintions merged recursively and with required fields";
    check = lib.isAttrs;
    merge = loc: defs:
      throwForRequired loc (foldRecursiveUpdateDefinitions defs);
    emptyValue = { value = { }; };
  };

  json = lib.mkOptionType {
    name = "json";
    description =
      "attribute set with all definitions merged recursively"; # And rendered as JSON string
    check = lib.isAttrs;
    merge = loc: defs:
      (foldRecursiveUpdateDefinitions defs) // {
        __toString = c:
          builtins.toJSON (builtins.removeAttrs c [ "__toString" ]);
      };
    emptyValue = { value = { __toString = _: "{}"; }; };
  };

  jsonWithRequired = lib.mkOptionType {
    name = "jsonWithRequired";
    description =
      "attribute set with all definitions merged recursively and with required fields"; # And renderered as JSON string
    check = lib.isAttrs;
    merge = loc: defs:
      throwForRequired loc (foldRecursiveUpdateDefinitions defs) // {
        __toString = c:
          builtins.toJSON (builtins.removeAttrs c [ "__toString" ]);
      };
    emptyValue = { value = { __toString = _: "{}"; }; };
  };

  jsonConfig = lib.mkOptionType {
    name = "jsonConfig";
    description =
      "attribute set with all definitions merged recursively and with required fields"; # And rendered as JSON file
    check = lib.isAttrs;
    merge = loc: defs:
      throwForRequired loc (foldRecursiveUpdateDefinitions defs) // {
        __toString = c:
          builtins.toFile "config.json"
          (builtins.toJSON (builtins.removeAttrs c [ "__toString" ]));
      };
    emptyValue = { value = { __toString = _: "{}"; }; };
  };
}
