Set Implicit Arguments.

Section ADTValue.

  Variable ADTValue : Type.

  Require Import Platform.Cito.Transit.
  Require Import Platform.Cito.Semantics.

  Require Import Platform.Cito.Syntax.
  Require Import Platform.Cito.GLabel.

  Notation Callee := (@Callee ADTValue).

  Definition Env := ((glabel -> option W) * (W -> option Callee))%type.

  Require Import Platform.Cito.SemanticsExpr.
  Require Import Coq.Lists.List.
  Require Import Platform.Cito.WordMap.
  Import WordMap.
  Require Import Platform.Cito.WordMapFacts.
  Import FMapNotations.
  Open Scope fmap_scope.
  
  Definition strengthen_op_ax (spec_op : InternalFuncSpec) spec_ax (env_ax : Env) :=
    let args := ArgVars spec_op in
    let rvar := RetVar spec_op in
    let s := Body spec_op in
    (forall ins, 
       PreCond spec_ax ins ->
       length args = length ins) /\
    (forall v inputs,
       TransitSafe spec_ax (List.map (sel (fst v)) args) inputs (snd v) ->
       Safe env_ax s v) /\
    forall v v', 
      RunsTo env_ax s v v' -> 
      forall inputs,
        let vs := fst v in
        let h := snd v in
        let vs' := fst v' in
        let h' := snd v' in
        let words := List.map (sel vs) args in
        let outputs := List.map (fun k => find k h') words in
        let ret_w := sel vs' rvar in
        let ret_a := find ret_w h' in
        TransitSafe spec_ax words inputs h ->
        TransitTo spec_ax words inputs outputs ret_w ret_a h h'.
  
  Arguments Internal {_} _.

  Definition strengthen (env_op env_ax : Env) := 
    (forall lbl, fst env_op lbl = fst env_ax lbl) /\ 
    let fs_op := snd env_op in
    let fs_ax := snd env_ax in
    forall w,
      fs_op w = fs_ax w \/
      exists spec_op spec_ax,
        fs_op w = Some (Internal spec_op) /\
        fs_ax w = Some (Foreign spec_ax) /\
        strengthen_op_ax spec_op spec_ax env_ax.

  Hint Constructors Semantics.RunsTo.
  Hint Constructors Semantics.Safe.

  Require Import Platform.Cito.GeneralTactics Platform.Cito.GeneralTactics3.

  Lemma strengthen_runsto : forall env_op s v v', RunsTo env_op s v v' -> forall env_ax, strengthen env_op env_ax -> Safe env_ax s v -> RunsTo env_ax s v v'.
    induction 1; simpl; intros; unfold_all.

    Focus 7.
    {
      (* call internal *)
      generalize H2; intro.
      unfold strengthen, strengthen_op_ax in H2; openhyp.
      destruct (H5 (eval (fst v) f)); clear H5.
      {
        eapply RunsToCallInternal; eauto.
        destruct env_ax; destruct env_op; simpl in *.
        congruence.
        eapply IHRunsTo; eauto.

        destruct env_ax; destruct env_op; simpl in *.
        inv_clear H3; simpl in *.
        {
          rewrite H6 in H.
          rewrite H9 in H; injection H; intros; subst.
          eapply H12.
          eauto.
        }
        rewrite H6 in H.
        rewrite H9 in H; discriminate.
      }
      openhyp.
      destruct env_ax; destruct env_op; simpl in *.
      rewrite H in H5; injection H5; intros; subst.
      Require Import Platform.Cito.GeneralTactics4.
      copy_as H3 Hsf.
      eapply Safe_TransitSafe in Hsf; eauto.
      destruct Hsf as [inputs Htsf].
      eapply IHRunsTo in H4.
      {
        eapply H9 in H4; clear H9.
        {
          simpl in *.
          eapply TransitTo_RunsTo; eauto.
          simpl in *.
          rewrite <- H0.
          eauto.
          simpl.
          eauto.
        }
        simpl in *.
        rewrite H0.
        eauto.
      }
      eapply H8.
      simpl.
      rewrite H0.
      eauto.
    }
    Unfocus.

    Focus 7.
    {
      (* call foreign *)
      generalize H6; intro.
      unfold strengthen, strengthen_op_ax in H6; openhyp.
      destruct (H9 (eval (fst v) f)); clear H9.
      {
        eapply RunsToCallForeign; eauto.
        destruct env_ax; destruct env_op; simpl in *.
        congruence.
      }
      openhyp.
      destruct env_ax; destruct env_op; simpl in *.
      rewrite H in H9; discriminate.
    }
    Unfocus.

    {
      (* skip *)
      eauto.
    }
    {
      (* seq *)
      inv_clear H2.
      econstructor; eauto.
    }
    {
      (* if true *)
      inv_clear H2.
      openhyp.
      - eapply RunsToIfTrue; eauto.
      - rewrite H2 in H; discriminate.
    }
    {
      (* if false *)
      inv_clear H2.
      openhyp.
      - rewrite H2 in H; discriminate.
      - eapply RunsToIfFalse; eauto.
    }
    {
      (* while true *)
      inv_clear H3.
      - eapply RunsToWhileTrue; eauto.
      - rewrite H7 in H; discriminate.
    }
    {      
      (* while false *)
      eauto.
    }
    {
      (* label *)
      econstructor.
      destruct H0.
      rewrite <- H0.
      eauto.
    }
    {
      (* assign *)
      eauto.
    }
  Qed.

  Require Import Platform.Cito.ListFacts5.
  Require Import Platform.Cito.ListFacts4.

  Lemma strengthen_safe : forall env_ax s v, Safe env_ax s v -> forall env_op, strengthen env_op env_ax -> Safe env_op s v.
    intros.
    eapply (Safe_coind (fun s v => Safe env_ax s v)); [ .. | eauto ]; generalize H0; clear; intros.

    Focus 4.
    {
      inversion H; unfold_all; subst; simpl in *.
      {
        (* call internal *)
        generalize H0; intro.
        unfold strengthen, strengthen_op_ax in H0; openhyp.
        destruct (H2 (eval (fst v) f)); clear H2.
        {
          left; descend; eauto.
          destruct env_ax; destruct env_op; simpl in *.
          rewrite H3; eauto.
        }
        openhyp.
        destruct env_ax; destruct env_op; simpl in *.
        destruct v; simpl in *.
        rewrite H4 in H3; discriminate.
      }
      (* call foreign *)
      generalize H0; intro.
      unfold strengthen, strengthen_op_ax in H0; openhyp.
      destruct (H2 (eval (fst v) f)); clear H2.
      {
        right; descend; eauto.
        destruct env_ax; destruct env_op; simpl in *.
        rewrite H3; eauto.
      }
      openhyp.
      destruct env_ax; destruct env_op; simpl in *.
      destruct v; simpl in *.
      rewrite H4 in H3; injection H3; intros; subst.
      left; descend; eauto.
      Focus 2.
      {
        eapply H9; simpl; eauto.
        rewrite H11.
        unfold TransitSafe.
        descend; eauto.
        {
          repeat rewrite map_length in *.
          eapply map_eq_length_eq; eauto.
        }
        rewrite H5.
        rewrite combine_map.
        setoid_rewrite <- surjective_pairing.
        rewrite map_id.
        eauto.
      }
      Unfocus.

      erewrite H6; eauto.
      repeat rewrite map_length in *.
      eapply map_eq_length_eq; eauto.
    }
    Unfocus.
    {
      (* seq *)
      inversion H; unfold_all; subst.
      descend; eauto.
      eapply H5; eauto.
      eapply strengthen_runsto; eauto.
    }
    {
      (* if *)
      inversion H; unfold_all; subst.
      eauto.
    }
    {
      (* while *)
      unfold_all.
      inversion H; unfold_all; subst.
      {
        left; descend; eauto.
        eapply H6; eauto.
        eapply strengthen_runsto; eauto.
      }
      right; eauto.
    }
    {
      (* label *)
      inversion H; unfold_all; subst.
      destruct H0.
      rewrite H0; eauto.
    }
  Qed.

End ADTValue.