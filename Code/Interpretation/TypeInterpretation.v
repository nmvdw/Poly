Require Import Prelude.Funext.
Require Import Syntax.Signature.
Require Import Coq.Program.Equality.

Section TypeInterpretation.
  Context {B : Type}
          (semB : B -> Type).

  Fixpoint sem_Ty
           (A : Ty B)
    : Type
    := match A with
       | Base b => semB b
       | A1 ⟶ A2 => sem_Ty A1 -> sem_Ty A2
       end.

  Fixpoint sem_Con
           (C : Con B)
    : Type
    := match C with
       | ∙ => unit
       | A ,, C => sem_Ty A * sem_Con C
       end.

  Fixpoint sem_Var
           {C : Con B}
           {A : Ty B}
           (v : Var C A)
    : sem_Con C -> sem_Ty A
    := match v with
       | Vz => fun x => fst x
       | Vs v => fun x => sem_Var v (snd x)
       end.

  Context {F : Type}
          {ar : F -> Ty B}
          (semF : forall (f : F), sem_Ty (ar f)).

  Definition sem_Tm
             {C : Con B}
             {A : Ty B}
             (t : Tm ar C A)
    : sem_Con C -> sem_Ty A.
  Proof.
    induction t as [ ? ? f | ? ? ? v | ? ? ? ? f IHf | ? ? ? ? f IHf t IHt ].
    - exact (fun _ => semF f).
    - exact (sem_Var v).
    - exact (fun x y => IHf semF (y , x)).
    - exact (fun x => IHf semF x (IHt semF x)).
  Defined.
End TypeInterpretation.

Definition sem_Wk
           {B : Type}
           (semB : B -> Type)
           {C1 C2 : Con B}
           (w : Wk C1 C2)
  : sem_Con semB C1 -> sem_Con semB C2.
Proof.
  induction w as [ | ? ? ? w IHw | ? ? ? w IHw ].
  - exact (fun _ => tt).
  - exact (fun x => (fst x , IHw (snd x))).
  - exact (fun x => IHw (snd x)).
Defined.

Proposition sem_idWk
            {B : Type}
            (semB : B -> Type)
            {C : Con B}
            (x : sem_Con semB C)
  : sem_Wk semB (idWk C) x = x.
Proof.
  induction C as [ | A C IHC ].
  - destruct x.
    reflexivity.
  - destruct x ; simpl.
    rewrite IHC.
    reflexivity.
Qed.

Proposition sem_wkVar
            {B : Type}
            (semB : B -> Type)
            {F : Type}
            {ar : F -> Ty B}
            (semF : forall (f : F), sem_Ty semB (ar f))
            {C1 C2 : Con B}
            (w : Wk C1 C2)
            {A : Ty B}
            (v : Var C2 A)
            (x : sem_Con semB C1)
  : sem_Tm semB semF (TmVar (wkVar v w)) x
    =
    sem_Tm semB semF (TmVar v) (sem_Wk semB w x).
Proof.
  induction w as [ | ? ? ? w IHw | ? ? ? w IHw ].
  - cbn.
    destruct x.
    reflexivity.
  - destruct x as [x1 x2].
    dependent induction v.
    + cbn.
      reflexivity.
    + simpl.
      apply IHw.
  - exact (IHw v (snd x)).
Qed.

Proposition sem_keepWk
            {B : Type}
            (semB : B -> Type)
            {F : Type}
            {ar : F -> Ty B}
            (semF : forall (f : F), sem_Ty semB (ar f))
            {C1 C2 : Con B}
            (w : Wk C1 C2)
            {A1 A2 : Ty B}
            (t : Tm ar (A1 ,, C2) A2)
            (x : sem_Con semB C1)
            (y : sem_Ty semB A1)
  : sem_Tm semB semF (wkTm t (Keep A1 w)) (y , x)
    =
    sem_Tm semB semF t (y , sem_Wk semB w x).
Proof.
  dependent induction t.
  - reflexivity.
  - dependent induction v.
    + reflexivity.
    + simpl.
      exact (sem_wkVar semB semF w v x).
  - simpl.
    apply funext.
    intro a.
    simpl.
    apply IHt ; auto.
  - simpl.
    rewrite IHt2 ; auto.
    rewrite IHt1 ; auto.
Qed.

Proposition sem_dropIdWk
            {B : Type}
            (semB : B -> Type)
            {F : Type}
            {ar : F -> Ty B}
            (semF : forall (f : F), sem_Ty semB (ar f))
            {C : Con B}
            {A1 A2 : Ty B}
            (t : Tm ar C A1)
            (x : sem_Con semB C)
            (y : sem_Ty semB A2)
  : sem_Tm semB semF (wkTm t (Drop A2 (idWk C))) (y , x)
    =
    sem_Tm semB semF t x.
Proof.
  induction t.
  - reflexivity.
  - simpl.
    induction v.
    + reflexivity.
    + simpl.
      rewrite IHv.
      reflexivity.
  - simpl.
    apply funext.
    intro z.
    rewrite (sem_keepWk semB semF (Drop A2 (idWk C))).
    do 2 f_equal.
    exact (sem_idWk semB x).
  - simpl.
    rewrite IHt1, IHt2.
    reflexivity.
Qed.

Definition sem_Sub
           {B : Type}
           (semB : B -> Type)
           {F : Type}
           {ar : F -> Ty B}
           (semF : forall (f : F), sem_Ty semB (ar f))
           {C1 C2 : Con B}
           (s : Sub ar C1 C2)
  : sem_Con semB C1 -> sem_Con semB C2.
Proof.
  induction s as [ | ? ? ? ? s IHs t ].
  - exact (fun _ => tt).
  - exact (fun x => (sem_Tm semB semF t x , IHs semF x)).
Defined.

Proposition sem_dropSub
            {B : Type}
            (semB : B -> Type)
            {F : Type}
            {ar : F -> Ty B}
            (semF : forall (f : F), sem_Ty semB (ar f))
            {C1 C2 : Con B}
            (s : Sub ar C1 C2)
            {A : Ty B}
            (y : sem_Ty semB A)
            (x : sem_Con semB C1)
  : sem_Sub semB semF (dropSub s) (y , x)
    =
    sem_Sub semB semF s x.
Proof.
  induction s.
  - reflexivity.
  - simpl.
    rewrite IHs.
    rewrite sem_dropIdWk.
    reflexivity.
Qed.

Proposition sub_Lemma
            {B : Type}
            (semB : B -> Type)
            {F : Type}
            {ar : F -> Ty B}
            (semF : forall (f : F), sem_Ty semB (ar f))
            {C1 C2 : Con B}
            (s : Sub ar C1 C2)
            {A : Ty B}
            (t : Tm ar C2 A)
            (x : sem_Con semB C1)
  : sem_Tm semB semF (subTm t s) x
    =
    sem_Tm semB semF t (sem_Sub semB semF s x).
Proof.
  revert s x.
  revert C1.
  induction t ; intros C1 s x.
  - reflexivity.
  - induction v.
    + dependent induction s.
      reflexivity.
    + dependent induction s.
      exact (IHv s).
  - simpl.
    apply funext.
    intro y.
    specialize (IHt semF _ (keepSub s) (y , x)).
    etransitivity.
    { 
      apply IHt.
    }
    simpl.
    do 2 f_equal.
    rewrite sem_dropSub.
    reflexivity.
  - simpl.
    rewrite IHt1.
    rewrite IHt2.
    reflexivity.
Qed.