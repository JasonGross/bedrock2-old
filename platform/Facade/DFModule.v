Set Implicit Arguments.

Require Import Platform.Cito.StringMap.
Import StringMap.

Require Import Platform.Facade.FModule.
Require Import Platform.Facade.DFacade.
Require Import Platform.Facade.CompileDFacade.

Local Notation FunCore := OperationalSpec.

Record DFFun :=
  {
    Core : FunCore;
    compiled_syntax_ok : FModule.is_syntax_ok (compile_op Core) = true
  }.
    
Coercion Core : DFFun >-> OperationalSpec.

Section ADTValue.

  Variable ADTValue : Type.

  Notation AxiomaticSpec := (@AxiomaticSpec ADTValue).

  Require Import Platform.Cito.GLabelMap.

  Record DFModule := 
    {
      Imports : GLabelMap.t AxiomaticSpec;
      (* Exports : StringMap.t AxiomaticSpec; *)
      Funs : StringMap.t DFFun
    }.

End ADTValue.