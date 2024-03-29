Set Implicit Arguments.

Require Import Platform.AutoSep.
Require Import Platform.Cito.examples.ExampleADT.
Import ExampleADT.ExampleADT.
Require Import Platform.Cito.RepInv.

Require Import Platform.Cito.examples.Cell Platform.Cito.examples.SimpleCell Platform.Cito.examples.Seq Platform.Cito.examples.ArraySeq Platform.Cito.examples.FiniteSet Platform.Cito.examples.ListSet.

Definition rep_inv p adtvalue : HProp :=
  match adtvalue with
    | Cell v => cell v p
    | Arr ws => arr ws p
    | FSet s => lset s p
  end.

Module ExampleRepInv <: RepInv ExampleADT.

  Definition RepInv := W -> ADTValue -> HProp.

  Definition rep_inv := rep_inv.

  Lemma rep_inv_ptr : forall p a, rep_inv p a ===> p =?> 1 * any.
    destruct a; simpl.
    eapply Himp_trans; [ apply cell_fwd | sepLemma ]; apply any_easy.
    eapply Himp_trans; [ apply arr_fwd | sepLemma ]; apply any_easy.
    eapply Himp_trans; [ apply lset_fwd | sepLemma ]; apply any_easy.
  Qed.

End ExampleRepInv.
