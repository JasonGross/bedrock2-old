Require Import Bedrock PreAutoSep.


(** * Separation logic specifications for system calls *)

Definition abortS := SPEC reserving 0
  PREonly[_] Emp.

Definition printIntS := SPEC("n") reserving 0
  PRE[_] Emp
  POST[_] Emp.

Definition listenS := SPEC("port") reserving 0
  PRE[_] Emp
  POST[stream] Emp.

Definition acceptS := SPEC("stream") reserving 0
  PRE[_] Emp
  POST[stream'] Emp.

Notation "buf =?>8 size" := (Ex bs, array8 bs buf * [| length bs = size |])%Sep
  (at level 39) : Sep_scope.
Notation "buf =?>8 size" := (Body (buf =?>8 size)%Sep) : qspec_scope.

Definition readS := SPEC("stream", "buffer", "size") reserving 0
  PRE[V] V "buffer" =?>8 wordToNat (V "size")
  POST[bytesRead] V "buffer" =?>8 wordToNat (V "size").


(** * More primitive operational semantics *)

Definition mapped (base : W) (len : nat) (m : mem) :=
  forall n, (n < len)%nat -> m (base ^+ $(n)) <> None.

Definition onlyChange (base : W) (len : nat) (m m' : mem) :=
  forall p, (forall n, (n < len)%nat -> p <> base ^+ $(n)) -> m' p = m p.

Section OpSem.
  Variable stn : settings.
  Variable prog : program.

  Inductive sys_step : state' -> state' -> Prop :=
  | Normal : forall st st', step stn prog st = Some st'
    -> sys_step st st'
  | Abort : forall st, Labels stn ("sys", Global "abort") = Some (fst st)
    -> sys_step st st
  | PrintInt : forall st st',
    Labels stn ("sys", Global "printInt") = Some (fst st)
    -> mapped (Regs (snd st) Sp) 8 (Mem (snd st))
    -> Regs st' Sp = Regs (snd st) Sp
    -> Mem st' = Mem (snd st)
    -> sys_step st (Regs (snd st) Rp, st')
  | Listen : forall st st', Labels stn ("sys", Global "listen") = Some (fst st)
    -> mapped (Regs (snd st) Sp) 8 (Mem (snd st))
    -> Regs st' Sp = Regs (snd st) Sp
    -> Mem st' = Mem (snd st)
    -> sys_step st (Regs (snd st) Rp, st')
  | Accept : forall st st',
    Labels stn ("sys", Global "accept") = Some (fst st)
    -> mapped (Regs (snd st) Sp) 8 (Mem (snd st))
    -> Regs st' Sp = Regs (snd st) Sp
    -> Mem st' = Mem (snd st)
    -> sys_step st (Regs (snd st) Rp, st')
  | Read : forall st buffer size st',
    Labels stn ("sys", Global "read") = Some (fst st)
    -> mapped (Regs (snd st) Sp) 16 (Mem (snd st))
    -> ReadWord stn (Mem (snd st)) (Regs (snd st) Sp ^+ $8) = Some buffer
    -> ReadWord stn (Mem (snd st)) (Regs (snd st) Sp ^+ $12) = Some size
    -> mapped buffer (wordToNat size) (Mem (snd st))
    -> Regs st' Sp = Regs (snd st) Sp
    -> onlyChange buffer (wordToNat size) (Mem (snd st)) (Mem st')
    -> sys_step st (Regs (snd st) Rp, st').

  Inductive sys_reachable : state' -> state' -> Prop :=
  | SR0 : forall st, sys_reachable st st
  | SR1 : forall st st' st'', sys_step st st'
    -> sys_reachable st' st''
    -> sys_reachable st st''.

  Definition sys_safe (st : state') :=
    forall st', sys_reachable st st' -> exists st'', sys_step st' st''.
End OpSem.