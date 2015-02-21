Require Import Platform.AutoSep.
Require Import Platform.Cito.ListFacts5.

Ltac hide_upd_sublist :=
  repeat match goal with
           | H : context [ upd_sublist ?L _ _ ] |- _ => set (upd_sublist L _ _) in *
         end.

