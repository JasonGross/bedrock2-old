Set Implicit Arguments.

Require Import Platform.Cito.ADT.
Require Import Platform.Cito.RepInv.

Module Make (Import E : ADT) (Import M : RepInv E).

  Require Import Platform.AutoSep.
  Require Import Bedrock.StructuredModule.
  Require Import Platform.Cito.StructuredModuleFacts.
  Require Import Platform.Cito.GoodModule.
  Require Import Platform.Cito.GoodFunction.
  Require Import Platform.Cito.ConvertLabel.
  Require Import Platform.Facade.NameDecoration.
  Require Import Platform.Wrap.
  Require Import Platform.Cito.GeneralTactics.
  Require Import Platform.Cito.GeneralTactics2.
  Require Import Platform.Cito.StringFacts2.

  Require Import Platform.Cito.LinkModuleImpls.
  Module Import LinkModuleImplsMake := Make E M.
  Require Import Platform.Cito.Stubs.
  Module Import StubsMake := Make E M.
  Require Import Platform.Cito.Stub.
  Import StubMake.
  Require Import Platform.Cito.CompileFuncSpec.
  Import CompileFuncSpecMake.
  Require Import Platform.Cito.Inv.
  Import InvMake.
  Require Import Platform.Cito.Semantics.
  Import SemanticsMake.
  Import InvMake2.
  Require Import Platform.Cito.GoodOptimizer.
  Module Import GoodOptimizerMake := Make E.

  Require Import Platform.Cito.LinkSpec.
  Module Import LinkSpecMake := Make E.
  Module Import LinkSpecMake2 := Make M.

  Require Import Platform.Cito.ListFacts1.
  Require Import Platform.Cito.ListFacts2.

  Require Import Bedrock.StringSet.
  Module Import SS := StringSet.
  Require Import Platform.Cito.StringSetFacts.

  Require Import Bedrock.Labels.
  Require Import Bedrock.LabelMap.
  Require Platform.Cito.LabelMapFacts.
  Require Import Platform.Cito.GLabel.
  Require Import Platform.Cito.GLabelMap.
  Import GLabelMap.
  Require Import Platform.Cito.GLabelMapFacts.

  Require Import Platform.Cito.ConvertLabelMap.
  Import Notations.
  Open Scope clm_scope.

  Section TopSection.

    (* modules to be linked *)
    Variable modules : list GoodModule.

    Hypothesis ModulesNotEmpty : modules <> nil.

    Notation FName := SyntaxFunc.Name.
    Notation MName := GoodModule.Name.
    Notation module_names := (List.map MName modules).

    Hypothesis NoDupModuleNames : List.NoDup module_names.

    (* imported specs *)
    Variable imports : t ForeignFuncSpec.

    Notation fst2 := (fun x => @fst _ _ (@fst _ _ x)).
    Notation imported_module_names := (List.map fst2 (elements imports)).

    Hypothesis NoSelfImport : ListFacts1.Disjoint module_names imported_module_names.

    Hypotheses ImportsGoodModuleName : forall l, In l imports -> IsGoodModuleName (fst l).

    (* optimizer *)

    Variable optimizer : Optimizer.

    Hypothesis IsGoodOptimizer : GoodOptimizer optimizer.

    Import ListNotations.
    Import FMapNotations.
    Open Scope fmap.
    Notation to_set := StringSetFacts.of_list.

    Hint Extern 1 => reflexivity.

    Require Import Coq.Setoids.Setoid.

    Lemma Disjoint_MNames_impl_MNames : StringSetFacts.Disjoint (to_set (List.map impl_MName modules)) (to_set (List.map MName modules)).
      unfold StringSetFacts.Disjoint.
      intros.
      nintro.
      openhyp.
      eapply of_list_spec in H.
      eapply of_list_spec in H0.
      eapply in_map_iff in H; openhyp; subst.
      eapply in_map_iff in H0; openhyp; subst.
      unfold impl_MName in *.
      eapply IsGoodModuleName_not_impl_module_name.
      eapply GoodModule_GoodName.
      eexists; eauto.
    Qed.

    Lemma final_imports_Compat_total_exports : Compat (final_imports modules imports) (LinkSpecMake2.impl_exports modules).
      unfold final_imports.
      Existing Instance Compat_rel_Symmetric.
      symmetry.
      eapply Compat_update.
      eapply Disjoint_Compat.
      Existing Instance Disjoint_rel_Symmetric.
      symmetry.
      eapply foreign_imports_Disjoint_total_impls; eauto.
      Existing Instance Compat_rel_Reflexive.
      reflexivity.
    Qed.

    Notation foreign_imports := LinkSpecMake2.imports.

    Lemma final_imports_diff_total_exports : final_imports modules imports - LinkSpecMake2.impl_exports modules == foreign_imports imports.
      unfold final_imports.
      rewrite <- update_diff_same.
      rewrite diff_same.
      rewrite update_empty_2.
      eapply Disjoint_diff_no_effect.
      eapply foreign_imports_Disjoint_total_impls; eauto.
    Qed.

    Definition impls := LinkModuleImplsMake.m modules IsGoodOptimizer.

    Definition stubs := StubsMake.m modules imports.

    Definition result := link impls stubs.

    (* Interface *)

    Theorem result_ok : moduleOk result.
      unfold result.
      eapply linkOk.
      eapply LinkModuleImplsMake.module_ok; eauto.
      eapply StubsMake.module_ok; eauto.
      eapply inter_is_empty_iff.
      unfold impls.
      rewrite LinkModuleImplsMake.module_module_names; eauto.
      unfold stubs.
      rewrite StubsMake.module_module_names; eauto.
      eapply Disjoint_MNames_impl_MNames.
      eapply importsOk_Compat.
      unfold impls.
      rewrite LinkModuleImplsMake.module_imports; eauto.
      unfold stubs.
      rewrite StubsMake.module_exports; eauto.
      eapply to_blm_Compat.
      symmetry.
      eapply Compat_empty.
      eapply importsOk_Compat.
      unfold impls.
      rewrite LinkModuleImplsMake.module_exports; eauto.
      unfold stubs.
      rewrite StubsMake.module_imports; eauto.
      eapply to_blm_Compat.
      eapply final_imports_Compat_total_exports.
      eapply importsOk_Compat.
      unfold impls.
      rewrite LinkModuleImplsMake.module_imports; eauto.
      unfold stubs.
      rewrite StubsMake.module_imports; eauto.
      eapply to_blm_Compat.
      symmetry.
      eapply Compat_empty.
    Qed.

    Theorem result_imports : Imports result === LinkSpecMake2.imports imports.
      simpl.
      rewrite XCAP_union_update.
      repeat rewrite XCAP_diff_diff.
      unfold impls.
      rewrite LinkModuleImplsMake.module_imports; eauto.
      rewrite LinkModuleImplsMake.module_exports; eauto.
      unfold stubs.
      rewrite StubsMake.module_imports; eauto.
      rewrite StubsMake.module_exports; eauto.
      repeat rewrite <- to_blm_diff.
      rewrite <- to_blm_update.
      eapply to_blm_Equal.
      repeat rewrite empty_diff.
      rewrite update_empty_2.
      eapply final_imports_diff_total_exports.
    Qed.

    Theorem result_exports : Exports result === LinkSpecMake2.all_exports modules imports.
      simpl.
      rewrite XCAP_union_update.
      unfold impls.
      rewrite LinkModuleImplsMake.module_exports; eauto.
      unfold stubs.
      rewrite StubsMake.module_exports; eauto.
      rewrite <- to_blm_update.
      eapply to_blm_Equal.
      eauto.
    Qed.

    Theorem result_module_names : SS.Equal (Modules result) (union (to_set (List.map impl_MName modules)) (to_set (List.map MName modules))).
      simpl.
      unfold impls.
      rewrite LinkModuleImplsMake.module_module_names; eauto.
      unfold stubs.
      rewrite StubsMake.module_module_names; eauto.
    Qed.

  End TopSection.

End Make.