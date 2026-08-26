#ifndef IVL_vthread_H
#define IVL_vthread_H
/*
 * Copyright (c) 2001-2020 Stephen Williams (steve@icarus.com)
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

# include  "vvp_net.h"

# include  <string>

/*
 * A vthread is a simulation thread that executes instructions when
 * they are scheduled. This structure contains all the thread specific
 * context needed to run an instruction.
 *
 * Included in a thread are its program counter, local bits and
 * members needed for tracking the thread. The thread runs by fetching
 * instructions from code space, interpreting the instruction, then
 * fetching the next instruction.
 */

typedef struct vthread_s* vthread_t;
typedef struct vvp_code_s*vvp_code_t;
class __vpiScope;

/*
 * Blocking runtime objects (mailbox, semaphore, process::await) retain a
 * thread until their condition becomes ready.  The thread in turn retains
 * the runtime object, and supplies this callback so disabling/deleting the
 * thread can unlink it from the object's wait queue before freeing it.
 */
typedef void (*vthread_resource_cancel_t)(void*owner, vthread_t thr);

/*
 * This creates a new simulation thread, with the given start
 * address. The generated thread is ready to run, but is not yet
 * scheduled.
 */
extern vthread_t vthread_new(vvp_code_t sa, __vpiScope*scope);

/*
 * This function marks the thread as scheduled. It is used only by the
 * schedule_vthread function.
 */
extern void vthread_mark_scheduled(vthread_t thr);

/* Register a cancellable wait on a runtime object. OWNER_ID is the raw
 * identity handed back to the callback; OWNER_REF keeps that object alive
 * for as long as the thread is queued on it. A thread may be parked on at
 * most one resource at a time: the registration is created by the opcode
 * that suspends the thread and is cleared by exactly one claim or one
 * cancellation before the thread runs again. */
extern void vthread_mark_resource_wait(vthread_t thr, void*owner_id,
                                       const vvp_object_t&owner_ref,
                                       vthread_resource_cancel_t cancel);

/* Claim the registration THR holds on OWNER_ID, clearing it. This must be
 * done BEFORE any operation-specific side effect (consuming a message,
 * inserting a stored item, taking a semaphore key, touching the thread's
 * object stack, scheduling the thread), because a false return means the
 * record is obsolete -- the thread was killed while queued -- and none of
 * those side effects may happen. A successful claim moves the retaining
 * reference into KEEP_ALIVE so the resource cannot delete itself in the
 * middle of its own wake method. */
extern bool vthread_claim_resource_wait(vthread_t thr, void*owner_id,
                                        vvp_object_t&keep_alive);

/* Cancel a pending resource wait and unlink THR from the owner's wait
 * collection. Idempotent, and safe to call on a thread that is not waiting
 * on any resource. Every path that releases thread storage must run this
 * first, or the owner is left holding a pointer to freed memory. */
extern void vthread_cancel_resource_wait(vthread_t thr);

/*
 * True when the thread belongs to a program block (its scope chain
 * includes a vpiProgram scope) or was spawned by such a thread; the
 * scheduler places these in the Reactive region set (IEEE 1800-2017
 * 4.4.2.5, clause 24).
 */
extern int vthread_is_reactive(vthread_t thr);
/* Mark synthesized clocking scheduler infrastructure as a design process,
 * even when its lexical scope is a program. */
extern void vthread_mark_clocking_sync(vthread_t thr);
/* M6B: mark a thread as a program initial procedure (24.7). */
extern void vthread_mark_program_init(vthread_t thr);

/*
 * This function marks the thread as being a final procedure.
 */
extern void vthread_mark_final(vthread_t thr);

/*
 * This function causes deletion of the currently running thread to
 * be delayed until after all sync events have been processed for the
 * time step in which the thread terminates. It is only used by the
 * schedule_generic function.
 */
extern void vthread_delay_delete();

/*
 * Cause this thread to execute instructions until in is put to sleep
 * by executing some sort of delay or wait instruction.
 */
extern void vthread_run(vthread_t thr);

/*
 * This function schedules all the threads in the list to be scheduled
 * for execution with delay 0. The thr pointer is taken to be the head
 * of a list, and all the threads in the list are presumably placed in
 * the list by the %wait instruction.
 */
extern void vthread_schedule_list(vthread_t thr);
extern void vthread_schedule_event_waiters(vthread_t&thr);
/* During a side-effect-free always_comb evaluation, ordinary observers wake
 * immediately but other proven-pure combinational processes remain armed
 * until the source evaluation's final input values are known. */
extern bool vthread_schedule_non_pure_comb_waiters(vthread_t&thr);
extern void vthread_schedule_pure_comb_waiters(vthread_t&thr);
extern void vthread_schedule_mutation_waiter(vthread_t thr);
/* Insert THR at the intrusive wait-list HEAD and remember the exact link that
 * owns it. This makes an ordinary event wait cancellable in O(1) when a
 * disabled fork kills the waiting branch. */
extern vthread_t vthread_add_event_wait(vthread_t thr, vthread_t*head);
extern void vthread_cancel_event_wait(vthread_t thr);
extern void vthread_cancel_mutation_wait(vthread_t thr);
extern void vthread_dump_live_threads(const char*reason);
extern void vthread_dump_running_thread(const char*reason);

extern __vpiScope*vthread_scope(vthread_t thr);

/*
 * This function returns a handle to the writable context of the currently
 * running thread. Normally the writable context is the context allocated
 * to the scope associated with that thread. However, between executing a
 * %alloc instruction and executing the associated %fork instruction, the
 * writable context changes to the newly allocated context, thus allowing
 * the input parameters of an automatic task or function to be written to
 * the task/function local variables.
 */
extern vvp_context_t vthread_get_wt_context();

/*
 * This function returns a handle to the readable context of the currently
 * running thread. Normally the readable context is the context allocated
 * to the scope associated with that thread. However, between executing a
 * %join instruction and executing the associated %free instruction, the
 * readable context changes to the context allocated to the newly joined
 * thread, thus allowing the output parameters of an automatic task or
 * function to be read from the task/function local variables.
 */
extern vvp_context_t vthread_get_rd_context();

/*
 * This function returns a handle to an item in the writable context
 * of the currently running thread.
 */
extern vvp_context_item_t vthread_get_wt_context_item(unsigned context_idx);
extern vvp_context_item_t vthread_get_wt_context_item_scoped(unsigned context_idx,
                                                             __vpiScope*scope);

/*
 * This function returns a handle to an item in the readable context
 * of the currently running thread.
 */
extern vvp_context_item_t vthread_get_rd_context_item(unsigned context_idx);
extern vvp_context_item_t vthread_get_rd_context_item_scoped(unsigned context_idx,
                                                             __vpiScope*scope);

/*
 * Saved thread context around one delegated access through a `ref'
 * formal. See vthread_push_ref_context() in vthread.cc.
 */
struct vthread_ref_ctx_save {
      vvp_context_t rd;
      vvp_context_t wt;
      vvp_context_t staged_rd;
      __vpiScope*staged_rd_scope;
      bool engaged;
};
extern void vthread_push_ref_context(vvp_context_t ctx,
                                     struct vthread_ref_ctx_save*save);
extern void vthread_pop_ref_context(const struct vthread_ref_ctx_save*save);
extern vvp_context_t vthread_recover_context_for_scope(vvp_context_t candidate,
                                                       __vpiScope*scope);
/* Resolve only along CANDIDATE's lexical activation stack. Unlike the
   general recovery helper, this never selects an unrelated sole live frame. */
extern vvp_context_t vthread_recover_stacked_context_for_scope(
      vvp_context_t candidate, __vpiScope*scope);
/* Return the target scope's activation only when it has exactly one live
   frame. This is the same unambiguous fallback used by scoped reads. */
extern vvp_context_t vthread_recover_unique_context_for_scope(__vpiScope*scope);
/* True when CANDIDATE belongs to a lexical child of SCOPE. This lets an
   automatic signal distinguish a native store from a detached nested block
   from an unrelated cross-scope object-mutation notification. */
extern bool vthread_context_owner_is_within(vvp_context_t candidate,
                                            __vpiScope*scope);

/* Returns true if automatic-context debug warnings should be printed.
   Set IVL_AUTO_CTX_WARN=1 to enable. */
extern bool auto_ctx_warn_enabled();

/* Bump a named counter in the context-recovery engagement census
   (active only when IVL_CTX_STATS names an output file; see vthread.cc). */
extern void ctx_stats_bump(const char* site);

/* True when the given context is a live activation frame of the given
   automatic scope. Used by recv paths to distinguish a native store
   (context belongs to the functor's own scope) from a cross-scope
   notification delivery. */
extern bool vthread_context_live_matches_scope(vvp_context_t context,
                                               __vpiScope*scope);

/*
 * Access value stacks from thread space.
 */
extern void vthread_push(struct vthread_s*thr, const vvp_vector4_t&val);
extern void vthread_push(struct vthread_s*thr, const std::string&val);
extern void vthread_push(struct vthread_s*thr, double val);

/*
 * Push/pop a single vvp_object_t item on the object stack of a thread.
 * These are thin wrappers around the inline push_object/pop_object
 * methods, provided so that code outside vthread.cc (e.g. vvp_mailbox.cc)
 * can manipulate a thread's object stack without needing the full
 * vthread_s struct definition.
 */
extern void vthread_push_obj_item(struct vthread_s*thr, const vvp_object_t&obj);
extern void vthread_pop_obj_item(struct vthread_s*thr, vvp_object_t&obj);

extern void vthread_pop_vec4(struct vthread_s*thr, unsigned count);
extern void vthread_pop_str(struct vthread_s*thr, unsigned count);
extern void vthread_pop_real(struct vthread_s*thr, unsigned count);
extern void vthread_pop_obj(struct vthread_s*thr, unsigned count);


/* Get/set the string from/to the requested position in the vthread string
   stack. The top of the stack is depth==0, and items below are
   depth==1, etc. */
extern const std::string&vthread_get_str_stack(struct vthread_s*thr, unsigned depth);
extern void vthread_set_str_stack(struct vthread_s*thr, unsigned depth, const std::string&val);
extern double vthread_get_real_stack(struct vthread_s*thr, unsigned depth);
extern const vvp_vector4_t& vthread_get_vec4_stack(struct vthread_s*thr, unsigned depth);
extern void vthread_set_vec4_stack(struct vthread_s*thr, unsigned depth, const vvp_vector4_t&val);
extern const vvp_object_t& vthread_get_obj_stack(struct vthread_s*thr, unsigned depth);
extern void vthread_set_obj_stack(struct vthread_s*thr, unsigned depth, const vvp_object_t&val);

/* This is used to actually delete a thread once we are done with it. */
extern void vthread_delete(vthread_t thr);

#endif /* IVL_vthread_H */
