Set Implicit Arguments.

Section TopSection.

  Require Import Coq.Lists.List.
  Open Scope bool_scope.
  Notation "! b" := (negb b) (at level 35).

  Fixpoint NoDup_bool A (eqb : A -> A -> bool) (ls : list A) {struct ls} :=
    match ls with
      | nil => true
      | x :: xs => forallb (fun e => ! (eqb e x)) xs && NoDup_bool eqb xs
    end.

  Require Import Coq.Bool.Bool.

  Lemma NoDup_bool_sound : forall A eqb, (forall a b : A, eqb a b = true <-> a = b) -> forall ls, NoDup_bool eqb ls = true -> NoDup ls.
    induction ls; simpl; intros.
    econstructor.
    eapply andb_true_iff in H0.
    Require Import Platform.Cito.GeneralTactics.
    openhyp.
    econstructor.
    Require Import Platform.Cito.GeneralTactics2.
    nintro.
    eapply forallb_forall in H0; eauto.
    eapply negb_true_iff in H0.
    replace (eqb a a) with true in H0.
    intuition.
    symmetry; eapply H; eauto.
    eauto.
  Qed.

  Definition sumbool_to_bool A B (b : {A} + {B}) := if b then true else false.

  Require Import Coq.Strings.String.

  Definition string_bool a b := sumbool_to_bool (string_dec a b).

  Lemma NoDup_bool_string_eq_sound : forall ls, NoDup_bool string_bool ls = true -> NoDup ls.
    intros.
    eapply NoDup_bool_sound.
    2 : eauto.
    split; intros.
    unfold string_bool, sumbool_to_bool in *; destruct (string_dec a b); try discriminate; eauto.
    unfold string_bool, sumbool_to_bool in *; destruct (string_dec a b); try discriminate; eauto.
  Qed.

  Definition is_no_dup := NoDup_bool string_bool.

  (* test boolean deciders *)
  Require Import Coq.Lists.List.
  Import ListNotations.
  Local Open Scope string_scope.
  Goal is_no_dup ["aa"; "ab"; "cc"] = true. Proof. exact eq_refl. Qed.
  Goal is_no_dup ["aa"; "aa"; "cc"] = false. Proof. exact eq_refl. Qed.

  Lemma is_no_dup_sound ls : is_no_dup ls = true -> NoDup ls.
    intros; eapply NoDup_bool_string_eq_sound; eauto.
  Qed.

End TopSection.
