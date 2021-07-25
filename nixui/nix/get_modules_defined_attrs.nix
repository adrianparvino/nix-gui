module_path:
let
  config = import module_path {config = {}; pkgs = import <nixpkgs> {}; lib = import <nixpkgs/lib>;};
  closure = builtins.tail (builtins.genericClosure {
    startSet = [{ key = builtins.toJSON []; value = {config = builtins.removeAttrs config ["x"];}; }];
    operator = {key, value}: builtins.filter (x: x != null) (let
      inherit (value) config;
    in
      if
        builtins.isAttrs config
      then
        builtins.map (new_key:
          let
            pos = (builtins.unsafeGetAttrPos new_key config);
          in
            if
              builtins.isNull pos || (pos.file != builtins.toString module_path)
            then null
            else {
              key = builtins.toJSON ((builtins.fromJSON key) ++ [new_key]);
              value = {
                config = builtins.getAttr new_key config;
                inherit pos;
              };
            }
        ) (builtins.attrNames config)
      else if
        builtins.isList config
      then builtins.genList (new_key:
        {
          key = builtins.toJSON ((builtins.fromJSON key) ++ [(builtins.toString new_key)]);
          value = {
            config = builtins.elemAt config new_key;
            pos = null;
          };
        }
      ) (builtins.length config)
      else []
    );
  });
  leaves = builtins.filter (x: !(builtins.isAttrs x.value.config || builtins.isList x.value.config)) closure;
  leaves' = builtins.filter (x: !(builtins.isNull x.value.pos)) leaves;
in
(if config ? imports
 then [
   {
     name = ["imports"];
     position = builtins.unsafeGetAttrPos "imports" config;
   }
 ]
 else [])
++ (
  builtins.map (x:
    {name = builtins.fromJSON x.key;} //
    {position = x.value.pos;}
  ) leaves')
