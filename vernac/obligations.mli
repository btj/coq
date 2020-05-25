(************************************************************************)
(*         *   The Coq Proof Assistant / The Coq Development Team       *)
(*  v      *         Copyright INRIA, CNRS and contributors             *)
(* <O___,, * (see version control and CREDITS file for authors & dates) *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

open Constr

(** Coq's Program mode support. This mode extends declarations of
   constants and fixpoints with [Program Definition] and [Program
   Fixpoint] to support incremental construction of terms using
   delayed proofs, called "obligations"

    The mode also provides facilities for managing and auto-solving
   sets of obligations.

    The basic code flow of programs/obligations is as follows:

    - [add_definition] / [add_mutual_definitions] are called from the
   respective [Program] vernacular command interpretation; at this
   point the only extra work we do is to prepare the new definition
   [d] using [RetrieveObl], which consists in turning unsolved evars
   into obligations. [d] is not sent to the kernel yet, as it is not
   complete and cannot be typchecked, but saved in a special
   data-structure. Auto-solving of obligations is tried at this stage
   (see below)

   - [next_obligation] will retrieve the next obligation
   ([RetrieveObl] sorts them by topological order) and will try to
   solve it. When all obligations are solved, the original constant
   [d] is grounded and sent to the kernel for addition to the global
   environment. Auto-solving of obligations is also triggered on
   obligation completion.

{2} Solving of obligations: Solved obligations are stored as regular
   global declarations in the global environment, usually with name
   [constant_obligation_number] where [constant] is the original
   [constant] and [number] is the corresponding (internal) number.

   Solving an obligation can trigger a bit of a complex cascaded
   callback path; closing an obligation can indeed allow all other
   obligations to be closed, which in turn may trigged the declaration
   of the original constant. Care must be taken, as this can modify
   [Global.env] in arbitrarily ways. Current code takes some care to
   refresh the [env] in the proper boundaries, but the invariants
   remain delicate.

{2} Saving of obligations: as open obligations use the regular proof
   mode, a `Qed` will call `Lemmas.save_lemma` first. For this reason
   obligations code is split in two: this file, [Obligations], taking
   care of the top-level vernac commands, and [Declare], which is
   called by `Lemmas` to close an obligation proof and eventually to
   declare the top-level [Program]ed constant.

 *)

val default_tactic : unit Proofview.tactic ref

(** Start a [Program Definition c] proof. [uctx] [udecl] [impargs]
   [kind] [scope] [poly] etc... come from the interpretation of the
   vernacular; `obligation_info` was generated by [RetrieveObl] It
   will return whether all the obligations were solved; if so, it will
   also register [c] with the kernel. *)
val add_definition :
     name:Names.Id.t
  -> ?term:constr
  -> types
  -> uctx:UState.t
  -> ?udecl:UState.universe_decl (** Universe binders and constraints *)
  -> ?impargs:Impargs.manual_implicits
  -> poly:bool
  -> ?scope:Locality.locality
  -> ?kind:Decls.logical_kind
  -> ?tactic:unit Proofview.tactic
  -> ?reduce:(constr -> constr)
  -> ?hook:Declare.Hook.t
  -> ?opaque:bool
  -> RetrieveObl.obligation_info
  -> Declare.progress

(* XXX: unify with MutualEntry *)

(** Start a [Program Fixpoint] declaration, similar to the above,
   except it takes a list now. *)
val add_mutual_definitions :
     (Declare.Recthm.t * Constr.t * RetrieveObl.obligation_info) list
  -> uctx:UState.t
  -> ?udecl:UState.universe_decl (** Universe binders and constraints *)
  -> ?tactic:unit Proofview.tactic
  -> poly:bool
  -> ?scope:Locality.locality
  -> ?kind:Decls.logical_kind
  -> ?reduce:(constr -> constr)
  -> ?hook:Declare.Hook.t
  -> ?opaque:bool
  -> Vernacexpr.decl_notation list
  -> Declare.Obls.fixpoint_kind
  -> unit

(** Implementation of the [Obligation] command *)
val obligation :
     int * Names.Id.t option * Constrexpr.constr_expr option
  -> Genarg.glob_generic_argument option
  -> Declare.Proof.t

(** Implementation of the [Next Obligation] command *)
val next_obligation :
  Names.Id.t option -> Genarg.glob_generic_argument option -> Declare.Proof.t

(** Implementation of the [Solve Obligation] command *)
val solve_obligations :
  Names.Id.t option -> unit Proofview.tactic option -> Declare.progress

val solve_all_obligations : unit Proofview.tactic option -> unit

(** Number of remaining obligations to be solved for this program *)
val try_solve_obligation :
  int -> Names.Id.t option -> unit Proofview.tactic option -> unit

val try_solve_obligations :
  Names.Id.t option -> unit Proofview.tactic option -> unit

val show_obligations : ?msg:bool -> Names.Id.t option -> unit
val show_term : Names.Id.t option -> Pp.t
val admit_obligations : Names.Id.t option -> unit

val check_program_libraries : unit -> unit
