Require Import Prelude.Funext.
Require Import Prelude.Wellfounded.
Require Import Prelude.CompatibleRelation.
Require Import Syntax.Signature.
Require Import Syntax.StrongNormalization.SN.
Require Import Coq.Program.Equality.

Definition TODO {A : Type} : A.
Admitted.

Record Interpretation {B F R : Type} (X : AFS B F R) :=
  {
    semTy : Ty B -> CompatRel ;
    semCon : Con B -> CompatRel ;
    semTm : forall {C : Con B} {A : Ty B},
        Tm (Arity X) C A -> semCon C -> semTy A ;
    semRew : forall (r : R)
                    (C : Con B)
                    (s : Sub (Arity X) C (Vars X r))
                    (x : semCon C),
        semTm (subTm (Lhs X r) s) x > semTm (subTm (Rhs X r) s) x ;
    semBeta : forall {C : Con B}
                     {A1 A2 : Ty B}
                     (f : Tm (Arity X) (A1,, C) A2)
                     (t : Tm (Arity X) C A1)
                     (x : semCon C),
        semTm ((λ f) · t) x >= semTm (subTm f (beta_sub t)) x
  }.

Arguments semTy {_ _ _ _} _ _.
Arguments semCon {_ _ _ _} _ _.
Arguments semTm {_ _ _ _} _ {_ _} _ _.
Arguments semRew {_ _ _ _} _ {_} _ _.
Arguments semBeta {_ _ _ _} _ {_ _ _} _ _ _.

Definition isWf_interpretation
           {B F R : Type}
           {X : AFS B F R}
           (I : Interpretation X)
  : Prop
  := forall (b : B), Wf (fun (x y : semTy I (Base b)) => x > y).

Section OrderInterpretation.
  Context {B : Type}
          (semB : B -> CompatRel)
          `{forall (b : B), isCompatRel (semB b)}.

  Fixpoint sem_Ty
           (A : Ty B)
    : CompatRel
    := match A with
       | Base b => semB b
       | A1 ⟶ A2 => sem_Ty A1 ⇒ sem_Ty A2
       end.

  Global Instance sem_Ty_CompatRel
         (A : Ty B)
    : isCompatRel (sem_Ty A).
  Proof.
    induction A ; apply _.
  Qed.
    
  Fixpoint sem_Con
           (C : Con B)
    : CompatRel
    := match C with
       | ∙ => unit_CompatRel
       | A ,, C => sem_Ty A * sem_Con C
       end.

  Global Instance sem_Con_isCompatRel
         (C : Con B)
    : isCompatRel (sem_Con C).
  Proof.
    induction C ; apply _.
  Qed.

  Fixpoint sem_Var_map
           {C : Con B}
           {A : Ty B}
           (v : Var C A)
    : sem_Con C -> sem_Ty A
    := match v with
       | Vz => fst
       | Vs v => fun x => sem_Var_map v (snd x)
       end.

  Global Instance sem_Var_strictMonotone
         {C : Con B}
         {A : Ty B}
         (v : Var C A)
    : strictMonotone (sem_Var_map v).
  Proof.
    induction v ; apply _.
  Qed.

  Global Instance sem_Var_weakMonotone
         {C : Con B}
         {A : Ty B}
         (v : Var C A)
    : weakMonotone (sem_Var_map v).
  Proof.
    induction v ; apply _.
  Qed.

  Definition sem_Var
             {C : Con B}
             {A : Ty B}
             (v : Var C A)
    : sem_Con C ⇒ sem_Ty A
    := make_monotone (sem_Var_map v) _.

  Context {F : Type}
          {ar : F -> Ty B}
          (semF : forall (f : F), sem_Ty (ar f)).

  Definition sem_Tm
             {C : Con B}
             {A : Ty B}
             (t : Tm ar C A)
    : weakMonotoneMap (sem_Con C) (sem_Ty A).
  Proof.
    induction t as [ ? f | ? ? v | ? ? ? ? IHf | ? ? ? f IHf t IHt ].
    - exact (const_WM _ _ (semF f)).
    - exact (sem_Var v).
    - exact (lambda_abs IHf).      
    - apply TODO.
  Defined.
End OrderInterpretation.

Definition sem_Wk
           {B : Type}
           (semB : B -> CompatRel)
           {C1 C2 : Con B}
           (w : Wk C1 C2)
  : sem_Con semB C1 -> sem_Con semB C2.
Proof.
  induction w as [ | ? ? ? w IHw | ? ? ? w IHw ].
  - exact (fun _ => tt).
  - exact (fun x => (fst x , IHw (snd x))).
  - exact (fun x => IHw (snd x)).
Defined.

Global Instance sem_Wk_weakMonotone
       {B : Type}
       (semB : B -> CompatRel)
       `{forall (b : B), isCompatRel (semB b)}
       {C1 C2 : Con B}
       (w : Wk C1 C2)
  : weakMonotone (sem_Wk semB w).
Proof.
  induction w ; apply _.
Qed.

Global Instance sem_Wk_strictMonotone
       {B : Type}
       (semB : B -> CompatRel)
       `{forall (b : B), isCompatRel (semB b)}
       {C1 C2 : Con B}
       (w : Wk C1 C2)
  : strictMonotone (sem_Wk semB w).
Proof.
  induction w.
  - intro ; cbn in *.
    contradiction.
  - apply _.
  - apply _.
Qed.

Proposition sem_idWk
            {B : Type}
            (semB : B -> CompatRel)
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
            (semB : B -> CompatRel)
            `{forall (b : B), isCompatRel (semB b)}
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
            (semB : B -> CompatRel)
            `{forall (b : B), isCompatRel (semB b)}
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
    apply eq_weakMonotoneMap.
    intro a.
    simpl.
    refine (IHt semB H semF _ _ (Keep _ w) _ t _ _ _ _) ; auto.
  - (*simpl.
    rewrite IHt2 ; auto.
    rewrite IHt1 ; auto.
     *)
    apply TODO.
Qed.

Proposition sem_dropIdWk
            {B : Type}
            (semB : B -> CompatRel)
            `{forall (b : B), isCompatRel (semB b)}
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
    apply eq_weakMonotoneMap.
    intro z ; simpl.
    rewrite (sem_keepWk semB semF (Drop A2 (idWk C)) t (y , x) z).
    do 2 f_equal.
    exact (sem_idWk semB x).
  - (*simpl.
    rewrite IHt1, IHt2.
    reflexivity.*)
    apply TODO.
Qed.

Definition sem_Sub
           {B : Type}
           (semB : B -> CompatRel)
           `{forall (b : B), isCompatRel (semB b)}
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

Global Instance sem_Sub_weakMonotone
       {B : Type}
       (semB : B -> CompatRel)
       `{forall (b : B), isCompatRel (semB b)}
       {F : Type}
       {ar : F -> Ty B}
       (semF : forall (f : F), sem_Ty semB (ar f))
       {C1 C2 : Con B}
       (s : Sub ar C1 C2)
  : weakMonotone (sem_Sub semB semF s).
Proof.
  induction s ; apply _.
Qed.

Proposition sem_dropSub
            {B : Type}
            (semB : B -> CompatRel)
            `{forall (b : B), isCompatRel (semB b)}
            {F : Type}
            {ar : F -> Ty B}
            (semF : forall (f : F), sem_Ty semB (ar f))
            {C1 C2 : Con B}
            (s : Sub ar C1 C2)
            {A : Ty B}
            (y : sem_Ty semB A)
            (x : sem_Con semB C1)
  : sem_Sub semB semF (dropSub _ s) (y , x)
    =
    sem_Sub semB semF s x.
Proof.
  induction s.
  - reflexivity.
  - simpl.
    rewrite IHs.
    rewrite (sem_dropIdWk _ _ t x y).
    reflexivity.
Qed.

Proposition sub_Lemma
            {B : Type}
            (semB : B -> CompatRel)
            `{forall (b : B), isCompatRel (semB b)}
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
    apply eq_weakMonotoneMap.
    intro y.
    cbn.
    specialize (IHt _ (keepSub _ s) (y , x)).
    etransitivity.
    { 
      apply IHt.
    }
    simpl.
    do 2 f_equal.
    rewrite sem_dropSub.
    reflexivity.
  - (*simpl.
    rewrite IHt1.
    rewrite IHt2.
    reflexivity.
     *)
    apply TODO.
Qed.

Record AFSAlgebra {B F R : Type} (X : AFS B F R) :=
  {
    sem_baseTy : B -> CompatRel ;
    sem_baseTy_el : forall (b : B), sem_baseTy b ;
    sem_baseTyWf : forall (b : B), Wf (fun (x y : sem_baseTy b) => x > y) ;
    sem_baseTy_isCompatRel : forall (b : B), isCompatRel (sem_baseTy b) ;
    sem_baseTm : forall (f : F), sem_Ty sem_baseTy (Arity X f) ;
  }.

Arguments sem_baseTy {_ _ _ _}.
Arguments sem_baseTy_el {_ _ _ _}.
Arguments sem_baseTyWf {_ _ _ _} _ _ _.
Arguments sem_baseTy_isCompatRel {_ _ _ _}.
Arguments sem_baseTm {_ _ _ _}.

Theorem AFSAlgebra_to_Interpretation
        {B F R : Type}
        {X : AFS B F R}
        (Xalg : AFSAlgebra X)
  : Interpretation X.
Proof.
  unshelve esplit.
  - apply sem_Ty.
    exact (sem_baseTy Xalg).
  - apply sem_Con.
    exact (sem_baseTy Xalg).
  - apply sem_Tm.
    + exact (sem_baseTy_isCompatRel Xalg).
    + exact (sem_baseTm Xalg).
  - simpl.
    apply TODO.
  - simpl.
    apply TODO.
Defined.

Theorem AFSAlgebra_to_WfInterpretation
        {B F R : Type}
        {X : AFS B F R}
        (Xalg : AFSAlgebra X)
  : isWf_interpretation (AFSAlgebra_to_Interpretation Xalg).
Proof.
  exact (sem_baseTyWf Xalg).
Defined.

Definition sem_Ty_el
           {B F R : Type}
           {X : AFS B F R}
           (Xalg : AFSAlgebra X)
           (A : Ty B)
  : sem_Ty (sem_baseTy Xalg) A.
Proof.
  induction A as [ b | A1 IHA1 A2 IHA2 ].
  - exact (sem_baseTy_el Xalg b).
  - simpl.
    apply const_WM.
    + apply sem_Ty_CompatRel.
      exact (sem_baseTy_isCompatRel Xalg).
    + exact IHA2.
Defined.

Definition sem_Con_el
           {B F R : Type}
           {X : AFS B F R}
           (Xalg : AFSAlgebra X)
           (C : Con B)
  : sem_Con (sem_baseTy Xalg) C.
Proof.
  induction C as [ | A C IHC ].
  - exact tt.
  - exact (sem_Ty_el Xalg A , IHC).
Defined.

Definition AFS_is_SN_from_Alg_map
           {B F R : Type}
           (b : B)
           {X : AFS B F R}
           (Xalg : AFSAlgebra X)
           (C : Con B)
           (x : AFSNotation.Tm X C (Base b))
  : sem_baseTy Xalg b * AFSNotation.Tm X C (Base b).
Proof.
  refine (semTm (AFSAlgebra_to_Interpretation Xalg) x _ , x).
  exact (sem_Con_el Xalg C).
Defined.

Import AFSNotation.

Theorem AFS_is_SN_from_Alg
        {B F R : Type}
        (b : B)
        {X : AFS B F R}
        (Xalg : AFSAlgebra X)
  : isSN X.
Proof.
  apply (SN_if_TySN X (Base b)).
  intro C.
  refine (fiber_is_Wf _ (AFS_is_SN_from_Alg_map b Xalg C) _).
  - refine (lexico_Wf
              (fun (x y : sem_baseTy Xalg b) => x > y)
              (fun (x y : Tm X C (Base b)) => BetaRed X x y)
              (sem_baseTyWf _ _)
              _).
    apply TODO.
  - intros t1 t2 p.
    unfold Rew in p.
    (* dependent induction p. *)
Admitted.
