Set Implicit Arguments.

Require Import Memory IL.
Require Import Facade.
Require Syntax.
Require Import String.
Open Scope string.
Require Import SyntaxExpr.
Require Import StringMap.
Import StringMap.
Require Import GLabel.
Require Import StringMapFacts.
Import FMapNotations.
Open Scope fmap.

Coercion Var : string >-> Expr.

Fixpoint compile (s : Stmt) : Syntax.Stmt :=
  match s with
    | Skip => Syntax.Skip
    | Seq a b => Syntax.Seq (compile a) (compile b)
    | If e t f => Syntax.If e (compile t) (compile f)
    | While e c => Syntax.While e (compile c)
    | Assign x e => Syntax.Assign x e
    | Label x lbl => Syntax.Label x lbl
    | Call x f args => Syntax.Call x f (List.map Var args)
  end.

Require Import ADT.

Module Make (Import A : ADT).

  Require Semantics.
  Module Cito := Semantics.Make A.

  Definition RunsTo := @RunsTo ADTValue.
  Definition State := @State ADTValue.
  Definition Env := @Env ADTValue.
  Definition AxiomaticSpec := @AxiomaticSpec ADTValue.
  Definition Value := @Value ADTValue.

  Import StringMap.

  Definition related_state (s_st : State) (t_st : Cito.State) := 
    (forall x v, 
       find x s_st = Some v ->
       match v with
         | SCA w => Locals.sel (fst t_st) x = w
         | ADT a => exists p, Locals.sel (fst t_st) x = p /\ Cito.heap_sel (snd t_st) p = Some a
       end) /\
    (forall p a,
       Cito.heap_sel (snd t_st) p = Some a ->
       exists x,
         Locals.sel (fst t_st)  x = p /\
         find x s_st = Some (ADT a)).
                
  Definition CitoEnv := ((glabel -> option W) * (W -> option Cito.Callee))%type.

  Coercion Semantics.Fun : Semantics.InternalFuncSpec >-> FuncCore.FuncCore.

  Definition CitoIn_FacadeIn (argin : Cito.ArgIn) : Value :=
    match argin with
      | inl w => SCA _ w
      | inr a => ADT a
    end.

  Definition CitoInOut_FacadeInOut (in_out : Cito.ArgIn * Cito.ArgOut) : Value * option Value :=
    match fst in_out, snd in_out with
      | inl w, _ => (SCA _ w, Some (SCA _ w))
      | inr a, Some a' => (ADT a, Some (ADT a'))
      | inr a, None => (ADT a, None)
    end.

  Definition compile_ax (spec : AxiomaticSpec) : Cito.Callee :=
    Semantics.Foreign 
      {|
        Semantics.PreCond args := PreCond spec (List.map CitoIn_FacadeIn args) ;
        Semantics.PostCond pairs ret := PostCond spec (List.map CitoInOut_FacadeInOut pairs) (CitoIn_FacadeIn ret)
      |}.

  Definition compile_op (spec : OperationalSpec) : Cito.Callee.
    refine
      (Cito.Internal
         {|
           Semantics.Fun :=
             {|
               FuncCore.ArgVars := ArgVars spec;
               FuncCore.RetVar := RetVar spec;
               FuncCore.Body := compile (Body spec)
             |};
           Semantics.NoDupArgVars := _
         |}
      ).
    simpl.
    destruct spec.
    simpl.
    inversion NoDupArgVars.
    eauto.
  Defined.

  Definition FuncSpec := @FuncSpec ADTValue.

  Definition compile_spec (spec : FuncSpec) : Cito.Callee :=
    match spec with
      | Axiomatic s => compile_ax s
      | Operational s => compile_op s
    end.

  Definition compile_env (env : Env) : CitoEnv :=
    (Label2Word env, 
     fun w => option_map compile_spec (Word2Spec env w)).
    
  Require Import GeneralTactics.
  Require Import GeneralTactics3.

  Ltac inject h := injection h; intros; subst; clear h.

  Notation ceval := SemanticsExpr.eval.
  Notation cRunsTo := Semantics.RunsTo.
  Lemma is_true_is_false : forall (st : State) e, is_true st e -> is_false st e -> False.
  Proof.
    intros.
    unfold is_true, is_false in *.
    rewrite H in *; discriminate.
  Qed.
  Lemma safe_if_true : forall (env : Env) e t f st, Safe env (If e t f) st -> is_true st e -> Safe env t st.
  Proof.
    intros.
    inversion H; subst.
    eauto.
    exfalso; eapply is_true_is_false; eauto.
  Qed.
  Definition is_bool (st : State) e := eval_bool st e <> None.
  Definition value_dec (v : Value) : {w | v = SCA _ w} + {a | v = ADT a}.
    destruct v.
    left; exists w; eauto.
    right; exists a; eauto.
  Defined.
  Definition option_value_dec (v : option Value) : {w | v = Some (SCA _ w)} + {a | v = Some (ADT a)} + {v = None}.
    destruct (option_dec v).
    destruct s; subst.
    destruct (value_dec  x).
    destruct s; subst.
    left; left; eexists; eauto.
    destruct s; subst.
    left; right; eexists; eauto.
    subst.
    right; eauto.
  Qed.
  Lemma eval_ceval : forall s_st t_st e w, eval s_st e = Some (SCA _ w) -> related_state s_st t_st -> ceval (fst t_st) e = w.
  Proof.
    induction e; simpl; intuition.
    unfold related_state in *.
    openhyp.
    eapply H0 in H.
    eauto.

    unfold eval_binop_m in *.
    destruct (option_value_dec (eval s_st e1)).
    destruct s.
    destruct s.
    rewrite e in *.
    destruct (option_value_dec (eval s_st e2)).
    destruct s.
    destruct s.
    rewrite e0 in *.
    inject H.
    erewrite IHe1; [ | eauto .. ].
    erewrite IHe2; [ | eauto .. ].
    eauto.
    destruct s.
    rewrite e0 in *; discriminate.
    rewrite e0 in *; discriminate.
    destruct s.
    rewrite e in *; discriminate.
    rewrite e in *; discriminate.
    
    unfold eval_binop_m in *.
    destruct (option_value_dec (eval s_st e1)).
    destruct s.
    destruct s.
    rewrite e in *.
    destruct (option_value_dec (eval s_st e2)).
    destruct s.
    destruct s.
    rewrite e0 in *.
    inject H.
    erewrite IHe1; [ | eauto .. ].
    erewrite IHe2; [ | eauto .. ].
    eauto.
    destruct s.
    rewrite e0 in *; discriminate.
    rewrite e0 in *; discriminate.
    destruct s.
    rewrite e in *; discriminate.
    rewrite e in *; discriminate.
  Qed.
  Lemma eval_bool_wneb : forall (s_st : State) t_st e b, eval_bool s_st e = Some b -> related_state s_st t_st -> wneb (ceval (fst t_st) e) $0 = b.
  Proof.
    intros.
    unfold eval_bool in *.
    destruct (option_value_dec (eval s_st e)).
    destruct s.
    destruct s.
    rewrite e0 in *.
    inject H.
    eapply eval_ceval in e0; [ | eauto].
    rewrite e0 in *; eauto.
    destruct s.
    rewrite e0 in *; discriminate.
    rewrite e0 in *; discriminate.
  Qed.
  Notation boolcase := Sumbool.sumbool_of_bool.
  Lemma wneb_is_true : forall s_st t_st e, wneb (ceval (fst t_st) e) $0 = true -> related_state s_st t_st -> is_bool s_st e -> is_true s_st e.
  Proof.
    intros.
    unfold is_true.
    unfold is_bool in *.
    eapply ex_up in H1.
    openhyp.
    destruct (boolcase x); subst.
    eauto.
    eapply eval_bool_wneb in H1; eauto.
    set (ceval _ _) in *.
    rewrite H in *; discriminate.
  Qed.
  Lemma is_true_is_bool : forall st e, is_true st e -> is_bool st e.
  Proof.
    intros.
    unfold is_true, is_bool in *.
    rewrite H in *.
    discriminate.
  Qed.
  Lemma is_false_is_bool : forall st e, is_false st e -> is_bool st e.
  Proof.
    intros.
    unfold is_false, is_bool in *.
    rewrite H in *.
    discriminate.
  Qed.
  Lemma safe_if_is_bool : forall (env : Env) e t f st, Safe env (If e t f) st -> is_bool st e.
  Proof.
    intros.
    inversion H; subst.
    eapply is_true_is_bool; eauto.
    eapply is_false_is_bool; eauto.
  Qed.
  Lemma safe_if_false : forall (env : Env) e t f st, Safe env (If e t f) st -> is_false st e -> Safe env f st.
  Proof.
    intros.
    inversion H; subst.
    exfalso; eapply is_true_is_false; eauto.
    eauto.
  Qed.
  Lemma wneb_is_false : forall s_st t_st e, wneb (ceval (fst t_st) e) $0 = false -> related_state s_st t_st -> is_bool s_st e -> is_false s_st e.
  Proof.
    intros.
    unfold is_false.
    unfold is_bool in *.
    eapply ex_up in H1.
    openhyp.
    destruct (boolcase x); subst.
    eapply eval_bool_wneb in H1; eauto.
    set (ceval _ _) in *.
    rewrite H in *; discriminate.
    eauto.
  Qed.

  Theorem compile_runsto : forall t t_env t_st t_st', Cito.RunsTo t_env t t_st t_st' -> forall s, t = compile s -> forall s_env s_st, t_env = compile_env s_env -> related_state s_st t_st -> Safe s_env s s_st -> exists s_st', RunsTo s_env s s_st s_st' /\ related_state s_st' t_st'.
  Proof.
    induction 1; simpl; intros; destruct s; simpl in *; intros; try discriminate.

    (* skip *)
    eexists; split.
    eapply RunsToSkip.
    eauto.

    (* seq *)
    subst.
    inject H1.
    edestruct IHRunsTo1; clear IHRunsTo1; eauto.
    Lemma safe_seq_1 : forall (env : Env) a b st, Safe env (Seq a b) st -> Safe env a st.
    Proof.
      intros.
      inversion H; subst.
      openhyp.
      eauto.
    Qed.
    eapply safe_seq_1; eauto.
    openhyp.
    edestruct IHRunsTo2; clear IHRunsTo2; eauto.
    Lemma safe_seq_2 : forall (env : Env) a b st, Safe env (Seq a b) st -> forall st', RunsTo env a st st' -> Safe env b st'.
    Proof.
      intros.
      inversion H; subst.
      openhyp.
      eauto.
    Qed.
    eapply safe_seq_2; eauto.
    openhyp.
    eexists.
    split.
    eapply RunsToSeq; eauto.
    eauto.

    (* if-true *)
    injection H1; intros; subst; clear H1.
    edestruct IHRunsTo.
    eauto.
    eauto.
    eauto.
    eapply safe_if_true; eauto.
    eapply wneb_is_true; eauto.
    eapply safe_if_is_bool; eauto.
    openhyp.
    eexists.
    split.
    eapply RunsToIfTrue.
    eapply wneb_is_true; eauto.
    eapply safe_if_is_bool; eauto.
    eauto.
    eauto.

    (* if-false *)
    injection H1; intros; subst; clear H1.
    edestruct IHRunsTo.
    eauto.
    eauto.
    eauto.
    eapply safe_if_false; eauto.
    eapply wneb_is_false; eauto.
    eapply safe_if_is_bool; eauto.
    openhyp.
    eexists.
    split.
    eapply RunsToIfFalse.
    eapply wneb_is_false; eauto.
    eapply safe_if_is_bool; eauto.
    eauto.
    eauto.


    (* while-true *)
    admit.
    (* while-false *)
    admit.

    (* call-operational *)
    unfold_all.
    inject H2.
    simpl in *.
    destruct (option_dec (Word2Spec s_env (SemanticsExpr.eval (fst v) e))); simpl in *.
    destruct s.
    rewrite e0 in *; simpl in *.
    inject H.
    destruct x; simpl in *.
    destruct a; simpl in *; unfold compile_ax in *; simpl in *; discriminate.
    unfold compile_op in *; simpl in *.
    inject H2; simpl in *.
    inversion H5; subst.
    replace f_w with (SemanticsExpr.eval (fst v) e) in * by (eapply eval_ceval; eauto).
    rewrite e0 in *.
    discriminate.
    
    unfold_all.
    replace f_w with (SemanticsExpr.eval (fst v) e) in * by  (eapply eval_ceval; eauto).
    rewrite e0 in *.
    inject H8.

    edestruct IHRunsTo.
    eauto.
    eauto.
    Focus 3.
    openhyp.
    eexists.
    split.
    eapply ex_up in H13.
    2 : eauto.
    openhyp.
    eapply RunsToCallOp.
    eauto.
    eauto.
    eauto.
    eauto.
    eauto.
    eauto.
    (* here *)
    Definition get_ret (st : Cito.State) x : Value :=
      let w := fst st x in
      match Cito.heap_sel (snd st) w with
        | Some a => ADT a
        | None => SCA _ w
      end.
    instantiate (1 := get_ret (vs_callee', heap') (RetVar spec)).
    admit.
    reflexivity.
    admit.
    admit.
    eauto.

    rewrite e0 in *; simpl in *; discriminate.

    (* call-axiomatic *)
    unfold_all.
    injection H6; intros; subst; clear H6.
    simpl in *.
    destruct (option_dec (Word2Spec s_env (SemanticsExpr.eval (fst v) e))).
    destruct s.
    rewrite e0 in *; simpl in *.
    injection H; intros; subst; clear H.
    destruct x; simpl in *.
    destruct a; simpl in *.
    unfold compile_ax in *; simpl in *.
    injection H6; intros; subst; simpl in *; clear H6.
    (* eexists. *)
    (* split. *)
    (* eapply RunsToCallAx. *)
    admit.

    discriminate.
    
    rewrite e0 in *; simpl in *; discriminate.

    (* label *)
    admit.

    (* assign *)
    admit.

  Qed.

End Make.