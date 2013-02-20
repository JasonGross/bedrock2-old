Require Import Bedrock PreAutoSep Sys.
Import XCAP.


Definition goodSize' (n : nat) := (N.of_nat n < 1 + Npow2 32)%N.

Lemma wordToNat_ninj : forall sz (u v : word sz),
  u <> v
  -> wordToNat u <> wordToNat v.
  intros; intro; apply H.
  assert (natToWord sz (wordToNat u) = natToWord sz (wordToNat v)) by congruence.
  repeat rewrite natToWord_wordToNat in H1.
  assumption.
Qed.

Lemma get_memoryIn' : forall m w init,
  (wordToNat w < init)%nat
  -> goodSize' init
  -> smem_get' (allWordsUpto 32 init) w (memoryIn' m _) = m w.
  induction init; simpl; intuition.
  destruct (H.addr_dec $(init) w).
  unfold H.mem_get, ReadByte.
  congruence.
  apply IHinit.
  apply wordToNat_ninj in n.
  rewrite wordToNat_natToWord_idempotent in n.
  omega.
  generalize H0; clear.
  unfold goodSize'.
  generalize (Npow2 32); intros.
  apply Nlt_out in H0.
  rewrite N2Nat.inj_add in H0.
  autorewrite with N in *.
  pre_nomega.
  simpl in *.
  omega.
  generalize H0; clear.
  unfold goodSize'.
  generalize (Npow2 32).
  intros.
  nomega.
Qed.

Lemma pow2_N : forall n,
  N.of_nat (pow2 n) = Npow2 n.
  intros.
  assert (N.to_nat (N.of_nat (pow2 n)) = N.to_nat (Npow2 n)).
  autorewrite with N.
  symmetry; apply Npow2_nat.
  assert (N.of_nat (N.to_nat (N.of_nat (pow2 n))) = N.of_nat (N.to_nat (Npow2 n))) by congruence.
  autorewrite with N in *.
  assumption.
Qed.

Lemma get_memoryIn : forall m w,
  smem_get w (memoryIn m) = m w.
  intros.
  unfold smem_get, memoryIn, HT.memoryIn, H.all_addr.
  rewrite allWords_eq.
  apply get_memoryIn'.
  apply wordToNat_bound.
  hnf.
  rewrite pow2_N.
  reflexivity.
Qed.


Section OpSem.
  Variable m : module.
  Variable stn : settings.
  Variable prog : program.

  Hypothesis inj : forall l1 l2 w, Labels stn l1 = Some w
    -> Labels stn l2 = Some w
    -> l1 = l2.

  Definition labelSys' (l_pre : string * spec) :=
    (Global (fst l_pre), Precondition (snd l_pre) None).

  Definition labelSys (l : LabelMap.key) (pre : assert) :=
    fst l = "sys"
    /\ In (snd l, pre) (map labelSys' (
      ("abort", abortS)
      :: ("printInt", printIntS)
      :: ("listen", listenS)
      :: ("accept", acceptS)
      :: ("read", readS)
      :: nil)).

  Hypothesis impSys :
    LabelMap.fold (fun l pre P => labelSys l pre /\ P) (Imports m) True.

  Lemma preserve : forall (ls : list (LabelMap.key * assert)) Q,
    fold_left (fun P p => labelSys (fst p) (snd p) /\ P) ls Q
    -> Q.
    induction ls; simpl in *; intuition.
    apply IHls in H; tauto.
  Qed.

  Theorem impSys' : forall l pre, LabelMap.MapsTo l pre (Imports m)
    -> labelSys l pre.
    rewrite LabelMap.fold_1 in impSys; intros.
    apply LabelMap.elements_1 in H.
    generalize dependent True.
    clear impSys; induction H; simpl in *; intuition.

    hnf in H; simpl in H; intuition subst.
    apply preserve in impSys; tauto.

    eauto.
  Qed.    

  Hypothesis agree : forall l pre bl, LabelMap.MapsTo l (pre, bl) (Blocks m)
    -> exists w, Labels stn l = Some w
      /\ prog w = Some bl.

  Hypothesis agreeImp : forall l pre, LabelMap.MapsTo l pre (Imports m)
    -> exists w, Labels stn l = Some w
      /\ prog w = None.

  Hypothesis omitImp : forall l w,
    Labels stn ("sys", l) = Some w
    -> prog w = None.

  Hypothesis ok : moduleOk m.

  Hint Constructors reachable sys_step sys_reachable.

  Definition goodState (st : state') :=
    exists l pre, Labels stn l = Some (fst st)
      /\ interp (specs m stn) (pre (stn, snd st))
      /\ (LabelMap.MapsTo l pre (Imports m)
        \/ exists bl, LabelMap.MapsTo l (pre, bl) (Blocks m)).

  Lemma locals_mapped' : forall specs stn st vs ns sp P,
    interp specs (![array (toArray ns vs) sp * P] (stn, st))
    -> mapped sp (length ns * 4) (Mem st).
    induction ns; simpl; intuition; hnf; intuition.
    unfold array in H.
    assert (interp specs (![ptsto32m' nil sp 0 (vs a :: toArray ns vs) * P] (stn0, st))).
    eapply ILTacCommon.interp_interp_himp; eauto.
    eapply himp_star_frame; [ apply Arrays.ptsto32m'_in | reflexivity ].
    clear H.
    simpl in *.
    assert (n < 4 \/ (n >= 4 /\ n - 4 < length ns * 4))%nat by omega.
    intuition.
    rewrite sepFormula_eq in H2; propxFo.
    unfold smem_get_word, H.footprint_w in H6.
    repeat match type of H6 with
             | match ?E with None => _ | _ => _ end = _ => case_eq E; intros;
               try match goal with
                     | [ H : _ = _ |- _ ] => rewrite H in H6
                   end; try discriminate
           end.
    inversion H3; clear H3; subst.

    Lemma unsplit_smem_get' : forall a v ls m m',
      smem_get' ls a m = Some v
      -> smem_get' ls a (join' ls m m') = Some v.
      induction ls; simpl; intuition.
      destruct (H.addr_dec a0 a); subst.
      rewrite H; auto.
      eauto.
    Qed.

    Lemma unsplit_smem_get : forall a m v m0 m1,
      smem_get a m = Some v
      -> split m0 m m1
        -> smem_get a m0 = Some v.
      unfold split; intuition subst; apply unsplit_smem_get'; auto.
    Qed.

    do 2 (eapply unsplit_smem_get in H11; eauto).
    rewrite get_memoryIn in H11.
    replace (sp ^+ $0 ^+ $3) with (sp ^+ $3) in * by words.
    congruence.

    inversion H13; clear H13; subst.
    do 2 (eapply unsplit_smem_get in H10; eauto).
    rewrite get_memoryIn in H10.
    replace (sp ^+ $0 ^+ $2) with (sp ^+ $2) in * by words.
    congruence.

    inversion H12; clear H12; subst.
    do 2 (eapply unsplit_smem_get in H9; eauto).
    rewrite get_memoryIn in H9.
    replace (sp ^+ $0 ^+ $1) with (sp ^+ $1) in * by words.
    congruence.

    inversion H13; clear H13; subst.
    do 2 (eapply unsplit_smem_get in H; eauto).
    rewrite get_memoryIn in H.
    congruence.

    inversion H12.

    assert (interp specs (![array (toArray ns vs) (sp ^+ $4) * ((sp ^+ $ (0)) =*> vs a * P)] (stn0, st))).
    eapply ILTacCommon.interp_interp_himp; eauto.
    clear.

    Lemma comeOnOut : forall P Q R,
      P * Q * R ===> Q * (P * R).
      clear; sepLemma.
    Qed.

    etransitivity; [ apply comeOnOut | ].
    apply Himp_star_frame; [ | apply Himp_refl ].
    eapply Himp_trans; [ | apply ptsto32m'_out ].
    apply ptsto32m'_shift_base'; auto.

    clear H2.
    apply IHns in H3.
    hnf in H3.
    eapply H3.
    eauto.
    replace (sp ^+ $4 ^+ $(n - 4)) with (sp ^+ $(n)); auto.
    rewrite natToW_minus by auto.
    unfold natToW.
    W_eq.
  Qed.

  Lemma locals_mapped : forall specs ns vs res sp stn st P,
    interp specs (![locals ns vs res sp * P] (stn, st))
    -> mapped sp (length ns * 4) (Mem st).
    unfold locals; intros.
    assert (interp specs
      (![array (toArray ns vs) sp * ([|NoDup ns|] *
        (sp ^+ $ (Datatypes.length ns * 4)) =?> res * P)]
      (stn0, st))).
    generalize H; clear; intros; step auto_ext.
    eapply locals_mapped'; eauto.
  Qed.

  Lemma array8_mapped : forall specs stn bs p m,
    interp specs (array8 bs p stn m)
    -> forall n, (n < length bs)%nat
      -> smem_get (p ^+ $(n)) m <> None.
    induction bs; simpl; post.
    intuition.
    destruct n.
    replace (p ^+ $0) with p in H1 by words.
    eapply split_smem_get in H2; eauto.
    rewrite H1 in H2; discriminate.
    eapply IHbs in H4; try tauto.
    instantiate (1 := n); auto.
    replace (p ^+ $1 ^+ $(n)) with (p ^+ $(S n))
      by (rewrite natToW_S; unfold natToW; W_eq).
    case_eq (smem_get (p ^+ $(S n)) x0); intros; auto.
    eapply split_smem_get in H2; eauto.
    congruence.
  Qed.

  Lemma bytes_mapped : forall specs p sz stn st P,
    interp specs (![p =?>8 sz * P] (stn, st))
    -> mapped p sz (Mem st).
    rewrite sepFormula_eq; post.
    hnf; intros.
    eapply split_comm in H1; eapply split_semp in H1; eauto; subst.
    eapply array8_mapped in H; eauto.
    case_eq (smem_get (p ^+ $(n)) x2); intros; try congruence.
    eapply split_smem_get in H0; eauto.
    rewrite get_memoryIn in H0.
    congruence.
  Qed.

  Hint Unfold onlyChange.

  Lemma prove_ReadWord : forall stn m (p : W) v st,
    evalInstrs stn st (Assign Rv (LvMem p) :: nil) <> None
    -> (forall st', evalInstrs stn st (Assign Rv (LvMem p) :: nil) = Some st'
      -> Regs st' Rv = v)
    -> Mem st = m
    -> ReadWord stn m p = Some v.
    intros.
    match goal with
      | [ H : (?X <> None)%type |- _ ] => case_eq X; intros; try tauto
    end.
    Transparent evalInstrs.
    simpl in *.
    subst.
    destruct (ReadWord stn0 (Mem st) p); simpl in *; try congruence.
    injection H2; clear H2; intros; subst; auto.
    specialize (H0 _ eq_refl).
    subst; auto.
  Qed.

  Lemma evalInstrs_slot : forall stn st n,
    evalInstrs stn st (Assign Rv (LvMem (Imm (Regs st Sp ^+ $(n)))) :: nil)
    = evalInstrs stn st (Assign Rv (LvMem (Sp + $(n))%loc) :: nil).
    auto.
  Qed.
  
  Opaque evalInstrs.

  Lemma specs_hit : forall w pre,
    specs m stn w = Some pre
    -> exists l, Labels stn l = Some w
      /\ (LabelMap.MapsTo l pre (Imports m)
        \/ exists bl, LabelMap.MapsTo l (pre, bl) (Blocks m)).
    intros.
    apply specs_hit in H; post; eauto.
    apply specs'_hit in H0; post; eauto.
  Qed.

  Lemma progress : forall st, goodState st
    -> exists st', sys_step stn prog st st'.
    unfold goodState; post;
      match goal with
        | [ x : label |- _ ] => destruct x
      end.

    match goal with
      | [ H : _ |- _ ] => specialize (impSys' _ _ H); intro Hi; hnf in Hi;
        unfold labelSys' in Hi; simpl in Hi; intuition subst;
          match goal with
            | [ H : (_, _) = (_, _) |- _ ] =>
              injection H; clear H; intros; subst
          end; eauto; post
    end;
    match goal with
      | [ H : interp ?specs (![locals ?a ?b ?c ?d * ?Q * ?R] ?X) |- _ ] =>
        let H' := fresh in
          assert (H' : interp specs (![locals a b c d * (Q * R)] X))
            by (generalize H; clear; intros; step auto_ext);
            clear H; rename H' into H;
              specialize (locals_mapped _ _ _ _ _ _ _ _ H);
                intro Hm; simpl in Hm
    end;
    try match goal with
          | [ H : interp ?specs (![?P * (?p =?>8 ?sz * ?Q)] ?X) |- _ ] =>
            let H' := fresh in
              assert (H' : interp specs (![p =?>8 sz * (P * Q)] X))
                by (generalize H; clear; intros; step auto_ext);
                clear H; rename H' into H;
                  specialize (bytes_mapped _ _ _ _ _ _ H);
                    intro Hb; simpl in Hb
        end;
    match goal with
      | [ H : specs _ _ _ = Some _ |- _ ] =>
        apply specs_hit in H; post; eauto
    end;
    try match goal with
          | [ st : state' |- Logic.ex _ ] =>
            solve [ exists (st#Rp, snd st); eauto
              | exists (st#Rp, snd st); eapply Read; eauto;
                match goal with
                  | [ H : interp _ _ |- ReadWord ?stn (Mem (snd ?st)) _ = Some _ ] =>
                    generalize H; clear; intros;
                      apply prove_ReadWord with (snd st); hnf; intros; cbv beta in *;
                        try rewrite evalInstrs_slot in *;
                          generalize dependent (snd st);
                            generalize dependent (specs m stn); intros;
                              evaluate auto_ext; auto
                end ]
        end.

    match goal with
      | [ H : _, H' : interp _ _ |- _ ] =>
        specialize (BlocksOk ok H); intro Hb; hnf in Hb;
          apply Hb in H'; [ | eapply specsOk; eauto ];
            clear Hb; post;
              specialize (agree _ _ _ H); destruct agree as [ ? [ ] ]
    end;
    repeat (match goal with
              | [ H : _ = _ |- _ ] => rewrite H in *
              | [ H : Some _ = Some _ |- _ ] =>
                injection H; clear H; intros
              | [ H : Logic.ex _ |- _ ] => destruct H; try clear H
              | [ H : _ /\ _ |- _ ] => destruct H; try clear H
            end; subst);
    match goal with
      | [ H : specs _ _ _ = Some _ |- _ ] =>
        apply specs_hit in H; post; eauto
    end;
    descend; apply Normal; unfold step;
      match goal with
        | [ H : _ = _ |- _ ] => rewrite H; eauto
      end.
  Qed.

  Lemma preservation : forall st, goodState st
    -> forall st', sys_step stn prog st st'
      -> goodState st'.
    unfold goodState; destruct 2; post.

    specialize (impSys' _ _ H2); intro Hi; hnf in Hi; intuition subst.
    apply omitImp in H1.
    unfold step in H0.
    rewrite H1 in H0; discriminate.
    apply omitImp in H1.
    unfold step in H0.
    rewrite H1 in H0; discriminate.

    specialize (BlocksOk ok H2); intro Hb; hnf in Hb.
    apply Hb in H; [ | eapply specsOk; eauto ].
    clear Hb; post.
    specialize (agree _ _ _ H2); destruct agree as [ ? [ ] ].
    rewrite H1 in H; injection H; clear H; intros; subst.
    unfold step in H0.
    rewrite H6 in H0.
    rewrite H0 in H3; injection H3; clear H3; intros; subst.
    apply specs_hit in H4; destruct H4; intuition idtac.
    eauto 10.
    destruct H; eauto 10.

    specialize (impSys' _ _ H3); intro Hi; hnf in Hi; intuition subst.
    eapply (inj _ _ _ H0) in H2; discriminate. 
    post.
    apply specs_hit in H5; destruct H5; intuition idtac.
    descend.
    eauto.
    2: eauto.
    descend; step auto_ext.
    descend; eauto.
    descend.
    eauto.
    2: eauto.
    descend; step auto_ext.
    descend; eauto.

    apply (inj _ _ _ H0) in H2.
    subst.
    specialize (omitImp _ _ H0).
    apply agree in H3.
    post.
    congruence.

    specialize (impSys' _ _ H3); intro Hi; hnf in Hi; intuition subst.
    eapply (inj _ _ _ H0) in H2; discriminate. 
    post.
    apply specs_hit in H5; destruct H5; intuition idtac.
    descend.
    eauto.
    2: eauto.
    descend; step auto_ext.
    descend; eauto.
    descend.
    eauto.
    2: eauto.
    descend; step auto_ext.
    descend; eauto.

    apply (inj _ _ _ H0) in H2.
    subst.
    specialize (omitImp _ _ H0).
    apply agree in H3.
    post.
    congruence.

    specialize (impSys' _ _ H3); intro Hi; hnf in Hi; intuition subst.
    eapply (inj _ _ _ H0) in H2; discriminate. 
    post.
    apply specs_hit in H5; destruct H5; intuition idtac.
    descend.
    eauto.
    2: eauto.
    descend; step auto_ext.
    descend; eauto.
    descend.
    eauto.
    2: eauto.
    descend; step auto_ext.
    descend; eauto.

    apply (inj _ _ _ H0) in H2.
    subst.
    specialize (omitImp _ _ H0).
    apply agree in H3.
    post.
    congruence.
  Qed.

  Lemma safety' : forall st, goodState st
    -> forall st', sys_reachable stn prog st st'
      -> goodState st'.
    induction 2; simpl; eauto using preservation.
  Qed.

  Theorem safety : forall st mn g pre, LabelMap.MapsTo (mn, Global g) pre (Exports m)
    -> Labels stn (mn, Global g) = Some (fst st)
    -> interp (specs0 m stn) (pre (stn, snd st))
    -> sys_safe stn prog st.
    unfold sys_safe; intros.
    eapply safety' in H2.
    auto using progress.
    hnf; descend; eauto.
    apply (ExportsSound ok) in H; eauto.
  Qed.
End OpSem.