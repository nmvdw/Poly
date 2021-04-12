Require Import Syntax.Signature.Types.
Require Import Syntax.Signature.Contexts.
Require Import Syntax.Signature.Terms.
Require Import Syntax.Signature.TermWeakenings.

Inductive Sub {B : Type} {F : Type} : (F -> Ty B) -> Con B -> Con B -> Type :=
| ToEmpty : forall {ar : F -> Ty B} (C : Con B), Sub ar C ∙
| ExtendSub : forall {ar : F -> Ty B} {C1 C2 : Con B} {A : Ty B},
    Sub ar C1 C2 -> Tm ar C1 A -> Sub ar C1 (A ,, C2).

Notation "s , t" := (ExtendSub s t) (at level 30).

Fixpoint dropSub
         {B : Type}
         {C1 C2 : Con B}
         {F : Type}
         {ar : F -> Ty B}
         {A : Ty B}
         (s : Sub ar C1 C2)
  : Sub ar (A ,, C1) C2
  := match s with
     | ToEmpty _ => ToEmpty _
     | s , t => dropSub s , wkTm t (Drop A (idWk _))
     end.

Definition keepSub
           {B : Type}
           {C1 C2 : Con B}
           {F : Type}
           {ar : F -> Ty B}
           {A : Ty B}
           (s : Sub ar C1 C2)
  : Sub ar (A ,, C1) (A ,, C2)
  := dropSub s , TmVar Vz.

Definition subVar
           {B : Type}
           {C1 C2 : Con B}
           {F : Type}
           {ar : F -> Ty B}
           {A : Ty B}
           (v : Var C2 A)
           (s : Sub ar C1 C2)
  : Tm ar C1 A.
Proof.
  induction s.
  - apply TmVar.
    inversion v.
  - inversion v.
    + subst.
      assumption.
    + apply IHs.
      assumption.
Defined.

Fixpoint subTm
         {B : Type}
         {C2 : Con B}
         {A : Ty B}
         {F : Type}
         {ar : F -> Ty B}
         (t : Tm ar C2 A)
  : forall {C1 : Con B}, Sub ar C1 C2 -> Tm ar C1 A
  := match t with
     | BaseTm f => fun _ _ => BaseTm f
     | TmVar v => fun _ s => subVar v s
     | Lam f => fun _ s => Lam (subTm f (keepSub s))
     | App f t => fun _ s => App (subTm f s) (subTm t s) 
     end.
