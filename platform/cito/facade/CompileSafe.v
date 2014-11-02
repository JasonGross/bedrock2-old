Set Implicit Arguments.

Require Import Compile.

Require Import Facade.
Require Import Memory IL.
Require Import GLabel.

Require Import String.
Local Open Scope string_scope.
Require Import StringMap.
Import StringMap.
Require Import StringMapFacts.
Import FMapNotations.
Local Open Scope fmap_scope.
Require Import List.
Require Import ListFacts ListFacts2 ListFacts3 ListFactsNew ListFacts4.
Local Open Scope list_scope.
Require Import GeneralTactics GeneralTactics2 GeneralTactics3 GeneralTactics4.

Section ADTValue.

  Variable ADTValue : Type.

  Notation RunsTo := (@RunsTo ADTValue).
  Notation State := (@State ADTValue).
  Notation Env := (@Env ADTValue).
  Notation AxiomaticSpec := (@AxiomaticSpec ADTValue).
  Notation Value := (@Value ADTValue).
  Notation Sca := (@SCA ADTValue).
  Notation Adt := (@ADT ADTValue).

  Section Safe_coind.

    Variable env : Env.

    Variable R : Stmt -> State -> Prop.

    Hypothesis SeqCase : forall a b st, R (Seq a b) st -> R a st /\ forall st', RunsTo env a st st' -> R b st'.

    Hypothesis IfCase : forall cond t f st, R (If cond t f) st -> (is_true st cond /\ R t st) \/ (is_false st cond /\ R f st).

    Hypothesis WhileCase : 
      forall cond body st, 
        let loop := While cond body in 
        R loop st -> 
        (is_true st cond /\ R body st /\ (forall st', RunsTo env body st st' -> R loop st')) \/ 
        (is_false st cond).

    Hypothesis AssignCase :
      forall x e st,
        R (Facade.Assign x e) st ->
        not_mapsto_adt x st = true /\
        exists w, eval st e = Some (Sca w).

    Hypothesis LabelCase : 
      forall x lbl st,
        R (Label x lbl) st -> 
        not_mapsto_adt x st = true /\
        exists w, Label2Word env lbl = Some w.

    Hypothesis CallCase : 
      forall x f args st,
        R (Call x f args) st ->
        NoDup args /\
        not_mapsto_adt x st = true /\
        exists f_w input, 
          eval st f = Some (Sca f_w) /\
          mapM (sel st) args = Some input /\
          ((exists spec,
              Word2Spec env f_w = Some (Axiomatic spec) /\
              PreCond spec input) \/
           (exists spec,
              Word2Spec env f_w = Some (Operational _ spec) /\
              length args = length (ArgVars spec) /\
              let callee_st := make_map (ArgVars spec) input in
              R (Body spec) callee_st /\
              (forall callee_st',
                 RunsTo env (Body spec) callee_st callee_st' ->
                 sel callee_st' (RetVar spec) <> None /\
                 no_adt_leak input (ArgVars spec) (RetVar spec) callee_st'))).
    
    Hint Constructors Safe.

    Require Import GeneralTactics.

    Theorem Safe_coind : forall c st, R c st -> Safe env c st.
      cofix; intros; destruct c.

      solve [eauto].
      Guarded.

      solve [eapply SeqCase in H; openhyp; eapply SafeSeq; eauto].
      Guarded.

      solve [eapply IfCase in H; openhyp; eauto].
      Guarded.

      solve [eapply WhileCase in H; openhyp; eauto].
      Guarded.

      solve [eapply CallCase in H; openhyp; simpl in *; intuition eauto].
      Guarded.

      solve [eapply LabelCase in H; openhyp; eauto].
      Guarded.

      solve [eapply AssignCase in H; openhyp; eauto].
    Qed.

  End Safe_coind.
  
  
  Require Import WordMap.
  Import WordMap.
  Require Import WordMapFacts.
  Import FMapNotations.
  Local Open Scope fmap_scope.

  Require Import FacadeFacts.

  Notation CitoSafe := (@Semantics.Safe ADTValue).

  Ltac try_eexists := try match goal with | |- exists _, _ => eexists end.
  Ltac try_split := try match goal with | |- _ /\ _ => split end.
  Ltac eexists_split := 
    try match goal with
          | |- exists _, _ => eexists
          | |- _ /\ _ => split
        end.
  Ltac pick_related := try match goal with | |- related _ _ => eauto end.

  Theorem compile_safe :
    forall s_env s s_st,
      Safe s_env s s_st ->
      (* h1 : the heap portion that this program is allowed to change *)
      forall vs h h1, 
        h1 <= h -> 
        related s_st (vs, h1) -> 
        let t_env := compile_env s_env in
        let t := compile s in
        let t_st := (vs, h) in
        CitoSafe t_env t t_st.
  Proof.
    simpl; intros.
    eapply 
      (Semantics.Safe_coind 
         (fun t v =>
            exists s s_st h1,
              let vs := fst v in
              let h := snd v in
              Safe s_env s s_st /\
              h1 <= h /\
              related s_st (vs, h1) /\
              t = compile s)
      ); [ .. | repeat try_eexists; simpl in *; intuition eauto ]; clear; simpl; intros until v; destruct v as [vs h]; intros [s [s_st [h1 [Hsf [Hsm [Hr Hcomp]]]]]]; destruct s; simpl in *; try discriminate; inject Hcomp.

    (* seq *)
    {
      rename s1 into a.
      rename s2 into b.
      inversion Hsf; subst.
      destruct H2 as [Hsfa Hsfb].
      split.
      - exists a, s_st, h1; eauto.
      - intros [vs' h'] Hcrt; simpl in *.
        eapply compile_runsto in Hcrt; eauto.
        simpl in *.
        openhyp.
        repeat eexists_split; pick_related; eauto.
        eapply diff_submap.
    }

    (* if *)
    {
      rename e into cond.
      rename s1 into t.
      rename s2 into f.
      inversion Hsf; subst.
      - left.
        rename H3 into Hcond.
        rename H4 into Hsfbr.
        split.
        + eapply eval_bool_wneb; eauto.
        + repeat eexists_split; pick_related; eauto.
      - right.
        rename H3 into Hcond.
        rename H4 into Hsfbr.
        split.
        + eapply eval_bool_wneb; eauto.
        + repeat eexists_split; pick_related; eauto.
    }

    (* while *)
    {
      rename e into cond.
      rename s into body.
      inversion Hsf; unfold_all; subst.
      - left.
        rename H1 into Hcond.
        rename H2 into Hsfbody.
        rename H4 into Hsfk.
        repeat try_split.
        + eapply eval_bool_wneb; eauto.
        + repeat eexists_split; pick_related; eauto.
        + intros [vs' h'] Hcrt; simpl in *.
          eapply compile_runsto in Hcrt; eauto.
          simpl in *.
          openhyp.
          repeat eexists_split; pick_related; eauto.
          eapply diff_submap.
      - right.
        eapply eval_bool_wneb; eauto.
    }

    Require Import Setoid.
    Require Import Morphisms.

    Global Add Parametric Morphism A B : (@List.map A B)
        with signature pointwise_relation A eq ==> eq ==> eq as list_map_m.
    Proof.
      intros; eapply map_ext; eauto.
    Qed.

    Definition FacadeIn_CitoIn (v : Value) :=
      match v with
        | SCA w => inl w
        | ADT a => inr a
      end.

    Lemma CF_FC x : CitoIn_FacadeIn (FacadeIn_CitoIn x) = x.
    Proof.
      destruct x; simpl; eauto.
    Qed.

    (* call *)
    {
      rename s into x.
      rename e into f_e.
      rename l into args.
      inversion Hsf; unfold_all; subst.
      (* axiomatic *)
      {
        right.
        rename H2 into Hnd.
        rename H3 into Hfe.
        rename H4 into Hfw.
        rename H5 into Hmm.
        rename H7 into Hna.
        rename H8 into Hpre.
        destruct spec; simpl in *.
        rewrite map_map.
        simpl.
        set (words := List.map (fun x0 : string => vs x0) args) in *.
        eexists.
        set (cinput := List.map FacadeIn_CitoIn input) in *.
        exists (combine words cinput).
        repeat eexists_split.
        {
          eapply eval_ceval in Hfe; eauto.
          rewrite Hfe.
          rewrite Hfw.
          simpl.
          eauto.
        }
        {
          Lemma map_fst_combine A B (ls1 : list A) : forall (ls2 : list B), length ls1 = length ls2 -> List.map fst (combine ls1 ls2) = ls1.
            induction ls1; destruct ls2; simpl in *; intros; intuition.
            f_equal; eauto.
          Qed.
          Lemma map_snd_combine A B (ls1 : list A) : forall (ls2 : list B), length ls1 = length ls2 -> List.map snd (combine ls1 ls2) = ls2.
            induction ls1; destruct ls2; simpl in *; intros; intuition.
            f_equal; eauto.
          Qed.
          rewrite map_fst_combine.
          eauto.
          unfold_all.
          repeat rewrite map_length.
          eapply mapM_length; eauto.
        }
        {
          Hint Constructors NoDup.

          Require Import Option.

          Lemma cito_is_adt_iff x : Semantics.is_adt x = true <-> exists a : ADTValue, x = inr a.
          Proof.
            destruct x; simpl in *.
            intuition.
            openhyp; intuition.
            intuition.
            eexists; eauto.
          Qed.

          Lemma mapM_good_inputs args :
            forall words cinput input h h2 st vs,
              mapM (sel st) args = Some input ->
              cinput = List.map FacadeIn_CitoIn input ->
              words = List.map vs args ->
              h2 <= h ->
              related st (vs, h2) ->
              NoDup args ->
              Semantics.good_inputs h (combine words cinput).
          Proof.
            simpl; induction args; destruct words; destruct cinput; destruct input; try solve [simpl in *; intros; eauto; try discriminate]; unfold Semantics.good_inputs, Semantics.disjoint_ptrs in *.
            - simpl in *.
              intros.
              intuition.
            - simpl in *.
              intros.
              intuition.
            - simpl in *.
              rename a into x.
              rename s into cv.
              intros h h2 st vs Hmm Hcin Hw Hsm Hr Hnd.
              destruct (option_dec (sel st x)) as [[y Hy] | Hn].
              + rewrite Hy in *.
                destruct (option_dec (mapM (sel st) args)) as [[ys Hys] | Hn].
                * rewrite Hys in *.
                  inject Hmm.
                  inject Hcin.
                  inject Hw.
                  inversion Hnd; subst.
                  rename H1 into Hni.
                  rename H2 into Hnd2.
                  destruct v as [w | a]; simpl in *.
                  {
                    split.
                    - econstructor.
                      + unfold Semantics.word_adt_match.
                        simpl.
                        eapply Hr in Hy; simpl in *.
                        eauto.
                      + eapply IHargs; eauto.
                    - eapply IHargs; eauto.
                  }
                  {
                    split.
                    - econstructor.
                      + unfold Semantics.word_adt_match.
                        simpl.
                        eapply Hr in Hy; simpl in *.
                        eauto.
                      + eapply IHargs; eauto.
                    - econstructor.
                      + nintro.
                        contradict Hni.
                        eapply in_map_iff in H.
                        destruct H as [[w cv] [Hw Hin]]; simpl in *.
                        subst.
                        eapply filter_In in Hin.
                        destruct Hin as [Hin Hadt]; simpl in *.
                        eapply cito_is_adt_iff in Hadt.
                        destruct Hadt as [a' Hcv].
                        subst.
                        eapply in_nth_error in Hin.
                        destruct Hin as [i Hnc].
                        eapply nth_error_combine_elim in Hnc.
                        destruct Hnc as [Hia Hii].
                        eapply nth_error_map_elim in Hia.
                        destruct Hia as [x' [Hia Hvs]].
                        eapply nth_error_map_elim in Hii.
                        destruct Hii as [v [Hii Hv]].
                        destruct v as [w | a'']; simpl in *.
                        * discriminate.
                        * inject Hv.
                          eapply mapM_nth_error_1 in Hys; eauto.
                          destruct Hys as [v [Hii' Hx']].
                          unif v.
                          assert (x = x').
                          {
                            eapply related_no_alias; eauto.
                          }
                          subst.
                          eapply Locals.nth_error_In; eauto.
                      + eapply IHargs; eauto.
                  }
                * rewrite Hn in *; discriminate.
              + rewrite Hn in *; discriminate.
          Qed.

          eapply mapM_good_inputs; unfold_all; eauto.
        }
        {
          simpl in *.
          rewrite map_snd_combine.
          unfold_all.
          rewrite map_map.
          setoid_rewrite CF_FC.
          rewrite map_id; eauto.
          unfold_all.
          repeat rewrite map_length.
          eapply mapM_length; eauto.
        }
      }
      (* opereational *)
      {
        left.
        rename H2 into Hnd.
        rename H3 into Hfe.
        rename H4 into Hfw.
        rename H5 into Hl.
        rename H6 into Hmm.
        rename H7 into Hna.
        rename H9 into Hsfb.
        rename H10 into Hnl.
        destruct spec; simpl in *.
        repeat eexists_split.
        {
          eapply eval_ceval in Hfe; eauto.
          rewrite Hfe.
          rewrite Hfw.
          simpl.
          eauto.
        }
        {
          simpl in *.
          rewrite map_length.
          symmetry; eauto.
        }
        {
          simpl in *.
          intros vs_arg Hm.
          rewrite map_map in Hm.
          eapply reachable_submap_related in Hr; eauto.
          destruct Hr as [Hsm2 Hr].
          repeat eexists_split.
          - eauto.
          - instantiate (1 := reachable_heap vs args input).
            eapply submap_trans; eauto.
          - eapply change_var_names; eauto.
            eapply is_no_dup_sound; eauto.
            eapply mapM_length; eauto.
          - eauto.
        }
      }
    }      

    (* label *)
    {
      rename s into x.
      rename g into lbl.
      inversion Hsf; unfold_all; subst.
      intuition.
    }

  Qed.

End ADTValue.