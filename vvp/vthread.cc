/*
 * Copyright (c) 2001-2026 Stephen Williams (steve@icarus.com)
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

# include  "config.h"
# include  "vthread.h"
# include  "codes.h"
# include  "schedule.h"
# include  "ufunc.h"
# include  "event.h"
# include  "vpi_priv.h"
# include  "vvp_net_sig.h"
# include  "vvp_assoc.h"
# include  "vvp_cobject.h"
# include  "vvp_darray.h"
# include  "vvp_mailbox.h"
# include  "vvp_vinterface.h"
# include  "class_type.h"
# include  "vvp_z3.h"
# include  "compile.h"
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <set>
# include  <map>
# include  <typeinfo>
# include  <vector>
# include  <cstdlib>
# include  <climits>
# include  <cstring>
# include  <cmath>
# include  <cassert>

# include  <iostream>
# include  <sstream>
# include  <cstdio>

using namespace std;

/* This is the size of an unsigned long in bits. This is just a
   convenience macro. */
# define CPU_WORD_BITS (8*sizeof(unsigned long))
# define TOP_BIT (1UL << (CPU_WORD_BITS-1))

static void release_owned_context_(vthread_t thr);
static void retain_context_chain_(vvp_context_t context);
static void trace_context_event_(const char*where, vthread_t thr,
                                 __vpiScope*extra_scope = 0,
                                 vvp_context_t extra_context = 0);
static bool context_live_in_owner(vvp_context_t context);
static bool context_live_matches_scope_(vvp_context_t context, __vpiScope*ctx_scope);
static vvp_context_t ensure_write_context_(vthread_t thr, const char*where);
static bool copy_call_inputs_to_allocated_context_(__vpiScope*scope, vthread_t thr,
                                                   vvp_context_t dst_context);
static bool virtual_dispatch_trace_enabled_();
static bool vpi_call_trace_enabled_();
static const char*scope_name_or_unknown_(__vpiScope*scope);
static __vpiScope* resolve_context_scope(__vpiScope*scope);
static bool assoc_trace_scope_match_(vthread_t thr);
static bool load_str_trace_scope_match_(__vpiScope*scope);
static bool function_runtime_trace_enabled_(const char*scope_name);
static void resume_joining_parent_(vthread_t parent, vthread_t child);
static void notify_mutated_object_signal_(vthread_t thr, vvp_net_t*net, const char*where);
static void notify_mutated_object_root_(vthread_t thr, const vvp_object_t&recv,
                                        vvp_net_t*root_net, const vvp_object_t&root_obj,
                                        const char*where);
static set<vthread_t> live_threads_registry_;

static bool sched_dump_threads_enabled_(const char*reason)
{
      static int enabled = -1;
      static string filter;
      if (enabled < 0) {
            const char*env = getenv("IVL_SCHED_DUMP_THREADS");
            enabled = (env && *env) ? 1 : 0;
            if (enabled)
                  filter = env;
      }
      if (!enabled)
            return false;
      if (filter.empty() || filter == "1" || filter == "ALL"
          || filter == "*" || filter == "true")
            return true;
      return reason && strstr(reason, filter.c_str());
}

static vvp_array_t resolve_runtime_array_(vvp_code_t cp, const char*op)
{
      if (compile_runtime_resolve_array(cp, op))
            return cp->array;

      return cp ? cp->array : 0;
}

enum builtin_process_state_t {
      PROCESS_STATE_FINISHED = 0,
      PROCESS_STATE_RUNNING = 1,
      PROCESS_STATE_WAITING = 2,
      PROCESS_STATE_SUSPENDED = 3,
      PROCESS_STATE_KILLED = 4
};

class vvp_process : public vvp_object {
    public:
      explicit vvp_process(vthread_t owner);
      ~vvp_process() override;

      void shallow_copy(const vvp_object*that) override;
      vvp_object* duplicate(void) const override;

      void detach_owner(vthread_t owner);
      void mark_finished();
      void mark_killed();
      unsigned status() const;
      vthread_t owner() const;

      void add_waiter(vthread_t thr);
      void remove_waiter(vthread_t thr);

    private:
      void signal_waiters_();

    private:
      vthread_t owner_;
      unsigned final_status_;
      bool final_status_valid_;
      std::set<vthread_t> waiters_;
};

/*
 * This vthread_s structure describes all there is to know about a
 * thread, including its program counter, all the private bits it
 * holds, and its place in other lists.
 *
 *
 * ** Notes On The Interactions of %fork/%join/%end:
 *
 * The %fork instruction creates a new thread and pushes that into a
 * set of children for the thread. This new thread, then, becomes a
 * child of the current thread, and the current thread a parent of the
 * new thread. Any child can be reaped by a %join.
 *
 * Children that are detached with %join/detach need to have a different
 * parent/child relationship since the parent can still effect them if
 * it uses the %disable/fork or %wait/fork opcodes. The i_am_detached
 * flag and detached_children set are used for this relationship.
 *
 * It is a programming error for a thread that created threads to not
 * %join (or %join/detach) as many as it created before it %ends. The
 * children set will get messed up otherwise.
 *
 * the i_am_joining flag is a clue to children that the parent is
 * blocked in a %join and may need to be scheduled. The %end
 * instruction will check this flag in the parent to see if it should
 * notify the parent that something is interesting.
 *
 * The i_have_ended flag, on the other hand, is used by threads to
 * tell their parents that they are already dead. A thread that
 * executes %end will set its own i_have_ended flag and let its parent
 * reap it when the parent does the %join. If a thread has its
 * schedule_parent_on_end flag set already when it %ends, then it
 * reaps itself and simply schedules its parent. If a child has its
 * i_have_ended flag set when a thread executes %join, then it is free
 * to reap the child immediately.
 */

struct vthread_s {
      vthread_s();

      void debug_dump(ostream&fd, const char*label_text);

	/* This is the program counter. */
      vvp_code_t pc;
	/* These hold the private thread bits. */
      enum { FLAGS_COUNT = 512, WORDS_COUNT = 16 };
      vvp_bit4_t flags[FLAGS_COUNT];

	/* These are the word registers. */
      union {
	    int64_t  w_int;
	    uint64_t w_uint;
      } words[WORDS_COUNT];

	// These vectors are depths within the parent thread's
	// corresponding stack.  This is how the %ret/* instructions
	// get at parent thread arguments.
      vector<unsigned> args_real;
      vector<unsigned> args_str;
      vector<unsigned> args_vec4;

    private:
      vector<vvp_vector4_t>stack_vec4_;
    public:
      inline vvp_vector4_t pop_vec4(void)
      {
	    assert(! stack_vec4_.empty());
	    vvp_vector4_t val = stack_vec4_.back();
	    stack_vec4_.pop_back();
	    return val;
      }
      inline void push_vec4(const vvp_vector4_t&val)
      {
	    if (val.size() == 1 && getenv("IVL_PUSH1_TRACE")) {
		  fprintf(stderr, "[push1] pushed 1-bit val at depth %zu, pc=%p\n",
			  stack_vec4_.size(), (void*)pc);
	    }
	    stack_vec4_.push_back(val);
      }
      inline const vvp_vector4_t& peek_vec4(unsigned depth)
      {
	    unsigned size = stack_vec4_.size();
	    assert(depth < size);
	    unsigned use_index = size-1-depth;
	    return stack_vec4_[use_index];
      }
      inline const vvp_vector4_t* safe_peek_vec4(unsigned depth) const
      {
	    unsigned size = stack_vec4_.size();
	    if (depth >= size) return nullptr;
	    return &stack_vec4_[size-1-depth];
      }
      inline vvp_vector4_t& peek_vec4(void)
      {
	    unsigned use_index = stack_vec4_.size();
	    assert(use_index >= 1);
	    return stack_vec4_[use_index-1];
      }
      inline void poke_vec4(unsigned depth, const vvp_vector4_t&val)
      {
	    assert(depth < stack_vec4_.size());
	    unsigned use_index = stack_vec4_.size()-1-depth;
	    stack_vec4_[use_index] = val;
      }
      inline void pop_vec4(unsigned cnt)
      {
	    if (cnt > stack_vec4_.size()) {
		  static bool warned = false;
		  if (!warned) {
			fprintf(stderr, "Warning: pop_vec4 underflow (%u > %zu); clamping.\n",
			        cnt, stack_vec4_.size());
			warned = true;
		  }
		  cnt = stack_vec4_.size();
	    }
	    while (cnt > 0) {
		  stack_vec4_.pop_back();
		  cnt -= 1;
	    }
      }


    private:
      vector<double> stack_real_;
    public:
      inline double pop_real(void)
      {
	    assert(! stack_real_.empty());
	    double val = stack_real_.back();
	    stack_real_.pop_back();
	    return val;
      }
      inline void push_real(double val)
      {
	    stack_real_.push_back(val);
      }
      inline double peek_real(unsigned depth)
      {
	    assert(depth < stack_real_.size());
	    unsigned use_index = stack_real_.size()-1-depth;
	    return stack_real_[use_index];
      }
      inline void poke_real(unsigned depth, double val)
      {
	    assert(depth < stack_real_.size());
	    unsigned use_index = stack_real_.size()-1-depth;
	    stack_real_[use_index] = val;
      }
      inline void pop_real(unsigned cnt)
      {
	    if (cnt > stack_real_.size()) {
		  static bool warned = false;
		  if (!warned) {
			fprintf(stderr, "Warning: pop_real underflow (%u > %zu); clamping.\n",
			        cnt, stack_real_.size());
			warned = true;
		  }
		  cnt = stack_real_.size();
	    }
	    while (cnt > 0) {
		  stack_real_.pop_back();
		  cnt -= 1;
	    }
      }

	/* Strings are operated on using a forth-like operator
	   set. Items at the top of the stack (back()) are the objects
	   operated on except for special cases. New objects are
	   pushed onto the top (back()) and pulled from the top
	   (back()) only. */
    private:
      vector<string> stack_str_;
    public:
      inline string pop_str(void)
      {
	    assert(! stack_str_.empty());
	    string val = stack_str_.back();
	    stack_str_.pop_back();
	    return val;
      }
      inline void push_str(const string&val)
      {
	    stack_str_.push_back(val);
      }
      inline string&peek_str(unsigned depth)
      {
	    assert(depth<stack_str_.size());
	    unsigned use_index = stack_str_.size()-1-depth;
	    return stack_str_[use_index];
      }
      inline void poke_str(unsigned depth, const string&val)
      {
	    assert(depth < stack_str_.size());
	    unsigned use_index = stack_str_.size()-1-depth;
	    stack_str_[use_index] = val;
      }
      inline void pop_str(unsigned cnt)
      {
	    if (cnt > stack_str_.size()) {
		  static bool warned = false;
		  if (!warned) {
			fprintf(stderr, "Warning: pop_str underflow (%u > %zu); clamping.\n",
			        cnt, stack_str_.size());
			warned = true;
		  }
		  cnt = stack_str_.size();
	    }
	    while (cnt > 0) {
		  stack_str_.pop_back();
		  cnt -= 1;
	    }
      }

	/* Objects are also operated on in a stack. */
    private:
      enum { STACK_OBJ_MAX_SIZE = 32 };
      vvp_object_t stack_obj_[STACK_OBJ_MAX_SIZE];
      vvp_object_t stack_obj_root_[STACK_OBJ_MAX_SIZE];
      vvp_net_t* stack_obj_net_[STACK_OBJ_MAX_SIZE];
      unsigned stack_obj_size_;
    public:
      inline vvp_object_t& peek_object(void)
      {
	    assert(stack_obj_size_ > 0);
	    return stack_obj_[stack_obj_size_-1];
      }
      inline vvp_object_t& peek_object(unsigned depth)
      {
	    assert(depth < stack_obj_size_);
	    return stack_obj_[stack_obj_size_-1-depth];
      }
      inline void poke_object(unsigned depth, const vvp_object_t&obj)
      {
	    assert(depth < stack_obj_size_);
	    stack_obj_[stack_obj_size_-1-depth] = obj;
      }
      inline vvp_net_t* peek_object_source_net(unsigned depth) const
      {
            assert(depth < stack_obj_size_);
            return stack_obj_net_[stack_obj_size_-1-depth];
      }
      inline const vvp_object_t& peek_object_root(unsigned depth) const
      {
            assert(depth < stack_obj_size_);
            return stack_obj_root_[stack_obj_size_-1-depth];
      }
      inline void pop_object(vvp_object_t&obj)
      {
	    assert(stack_obj_size_ > 0);
	    stack_obj_size_ -= 1;
	    obj = stack_obj_[stack_obj_size_];
	    stack_obj_[stack_obj_size_].reset(0);
            stack_obj_root_[stack_obj_size_].reset(0);
            stack_obj_net_[stack_obj_size_] = 0;
      }
      inline void pop_object(unsigned cnt, unsigned skip =0)
      {
	    assert((cnt+skip) <= stack_obj_size_);
	    size_t old_size = stack_obj_size_;
	    size_t dst = old_size - skip - cnt;
	    size_t src = old_size - skip;

	    for (size_t idx = 0 ; idx < skip ; idx += 1) {
		  stack_obj_[dst + idx] = stack_obj_[src + idx];
                  stack_obj_root_[dst + idx] = stack_obj_root_[src + idx];
                  stack_obj_net_[dst + idx] = stack_obj_net_[src + idx];
            }

	    for (size_t idx = dst + skip ; idx < old_size ; idx += 1) {
		  stack_obj_[idx].reset(0);
                  stack_obj_root_[idx].reset(0);
                  stack_obj_net_[idx] = 0;
            }

	    stack_obj_size_ = old_size - cnt;
      }
      inline void push_object(const vvp_object_t&obj)
      {
	    assert(stack_obj_size_ < STACK_OBJ_MAX_SIZE);
	    stack_obj_[stack_obj_size_] = obj;
            stack_obj_root_[stack_obj_size_].reset(0);
            stack_obj_net_[stack_obj_size_] = 0;
	    stack_obj_size_ += 1;
      }
      inline void push_object(const vvp_object_t&obj, vvp_net_t*root_net,
                              const vvp_object_t&root_obj)
      {
            assert(stack_obj_size_ < STACK_OBJ_MAX_SIZE);
            stack_obj_[stack_obj_size_] = obj;
            stack_obj_root_[stack_obj_size_] = root_obj;
            stack_obj_net_[stack_obj_size_] = root_net;
            stack_obj_size_ += 1;
      }

      vvp_object_t process_obj_;
      set<vvp_process*> awaited_processes_;

	/* My parent sets this when it wants me to wake it up. */
      unsigned i_am_joining      :1;
      unsigned i_am_detached     :1;
      unsigned i_am_waiting      :1;
      unsigned i_am_in_function  :1; // True if running function code
      unsigned i_have_ended      :1;
      unsigned i_was_disabled    :1;
      unsigned waiting_for_event :1;
      unsigned is_scheduled      :1;
      unsigned delay_delete      :1;
      unsigned delete_pending    :1;
      unsigned pending_nonlocal_jmp :1;
      unsigned is_callf_child    :1;
      unsigned owns_automatic_context :1;
	/* This points to the children of the thread. */
      set<struct vthread_s*>children;
	/* This points to the detached children of the thread. */
      set<struct vthread_s*>detached_children;
	/* This points to my parent, if I have one. */
      struct vthread_s*parent;
	/* This points to the containing scope. */
      __vpiScope*parent_scope;
      vvp_code_t last_pause_pc;
	/* This is used for keeping wait queues. */
      struct vthread_s*wait_next;
	/* These are used to access automatically allocated items. */
      vvp_context_t wt_context, rd_context;
      vvp_context_t owned_context;
      vvp_context_t transferred_context;
      vvp_context_t skip_free_context;
      vvp_context_t staged_alloc_rd_context;
      vvp_code_t nonlocal_target;
      __vpiScope*nonlocal_origin_scope;
      __vpiScope*transferred_context_scope;
      __vpiScope*skip_free_scope;
      __vpiScope*staged_alloc_rd_scope;
      __vpiScope*return_object_mirror_scope;
      __vpiScope*dynamic_dispatch_base_scope;
	/* These are used to pass non-blocking event control information. */
      vvp_net_t*event;
      uint64_t ecount;
	/* Save the file/line information when available. */
    private:
      char *filenm_;
      unsigned lineno_;
    public:
      void set_fileline(char *filenm, unsigned lineno);
      string get_fileline();

      inline void cleanup()
      {
	    release_owned_context_(this);
	    while (!awaited_processes_.empty()) {
		  vvp_process*proc = *awaited_processes_.begin();
		  awaited_processes_.erase(awaited_processes_.begin());
		  if (proc)
			proc->remove_waiter(this);
	    }
	    if (vvp_process*proc = process_obj_.peek<vvp_process>())
		  proc->detach_owner(this);
	    process_obj_.reset(0);
	    if (i_was_disabled) {
		  stack_vec4_.clear();
		  stack_real_.clear();
		  stack_str_.clear();
		  pop_object(stack_obj_size_);
	    }
	    free(filenm_);
	    filenm_ = 0;
	    if (!stack_vec4_.empty()) {
		  const char*fn = parent_scope ? vpi_get_str(vpiFullName, parent_scope) : "<unknown>";
		  cerr << "BUG: stack_vec4_ not empty at cleanup: size=" << stack_vec4_.size()
		       << " scope=" << fn << endl;
		  assert(stack_vec4_.empty());
	    }
	    assert(stack_real_.empty());
	    assert(stack_str_.empty());
	    assert(stack_obj_size_ == 0);
      }
};

inline vthread_s::vthread_s()
{
      stack_obj_size_ = 0;
      for (unsigned idx = 0; idx < STACK_OBJ_MAX_SIZE; idx += 1)
            stack_obj_net_[idx] = 0;
      filenm_ = 0;
      lineno_ = 0;
      owns_automatic_context = 0;
      owned_context = 0;
      transferred_context = 0;
      skip_free_context = 0;
      staged_alloc_rd_context = 0;
      transferred_context_scope = 0;
      skip_free_scope = 0;
      staged_alloc_rd_scope = 0;
      return_object_mirror_scope = 0;
      dynamic_dispatch_base_scope = 0;
      last_pause_pc = 0;
}

void vthread_s::set_fileline(char *filenm, unsigned lineno)
{
      assert(filenm);
      if (!filenm_ || (strcmp(filenm_, filenm) != 0)) {
	    free(filenm_);
	    filenm_ = strdup(filenm);
      }
      lineno_ = lineno;
}

inline string vthread_s::get_fileline()
{
      ostringstream buf;
      if (filenm_) {
	    buf << filenm_ << ":" << lineno_ << ": ";
      }
      string res = buf.str();
      return res;
}

vvp_process::vvp_process(vthread_t owner)
: owner_(owner), final_status_(PROCESS_STATE_RUNNING), final_status_valid_(false)
{
}

vvp_process::~vvp_process()
{
}

void vvp_process::shallow_copy(const vvp_object*that)
{
      (void)that;
}

vvp_object* vvp_process::duplicate() const
{
      return const_cast<vvp_process*>(this);
}

void vvp_process::detach_owner(vthread_t owner)
{
      if (owner_ == owner)
	    owner_ = 0;
}

void vvp_process::signal_waiters_()
{
      std::set<vthread_t> waiters = waiters_;
      waiters_.clear();
      for (set<vthread_t>::iterator cur = waiters.begin()
		 ; cur != waiters.end() ; ++cur) {
	    vthread_t waiter = *cur;
	    if (!waiter)
		  continue;
	    waiter->awaited_processes_.erase(this);
	    if (!waiter->i_have_ended)
		  schedule_vthread(waiter, 0, true);
      }
}

void vvp_process::mark_finished()
{
      if (final_status_valid_)
	    return;
      final_status_ = PROCESS_STATE_FINISHED;
      final_status_valid_ = true;
      signal_waiters_();
}

void vvp_process::mark_killed()
{
      if (final_status_valid_ && final_status_ == PROCESS_STATE_KILLED)
	    return;
      final_status_ = PROCESS_STATE_KILLED;
      final_status_valid_ = true;
      signal_waiters_();
}

unsigned vvp_process::status() const
{
      if (final_status_valid_)
	    return final_status_;

      if (!owner_)
	    return PROCESS_STATE_FINISHED;

      if (owner_->i_was_disabled)
	    return PROCESS_STATE_KILLED;

      if (owner_->i_have_ended)
	    return PROCESS_STATE_FINISHED;

      if (owner_->i_am_waiting || owner_->waiting_for_event || owner_->i_am_joining)
	    return PROCESS_STATE_WAITING;

      return PROCESS_STATE_RUNNING;
}

vthread_t vvp_process::owner() const
{
      return owner_;
}

void vvp_process::add_waiter(vthread_t thr)
{
      if (!thr || thr->i_have_ended)
	    return;
      waiters_.insert(thr);
      thr->awaited_processes_.insert(this);
}

void vvp_process::remove_waiter(vthread_t thr)
{
      if (!thr)
	    return;
      waiters_.erase(thr);
      thr->awaited_processes_.erase(this);
}

void vthread_s::debug_dump(ostream&fd, const char*label)
{
      fd << "**** " << label << endl;
      fd << "**** ThreadId: " << this << ", parent id: " << parent << endl;

      fd << "**** Flags: ";
      for (int idx = 0 ; idx < FLAGS_COUNT ; idx += 1)
	    fd << flags[idx];
      fd << endl;
      fd << "**** vec4 stack..." << endl;
      for (size_t idx = stack_vec4_.size() ; idx > 0 ; idx -= 1)
	    fd << "    " << (stack_vec4_.size()-idx) << ": " << stack_vec4_[idx-1] << endl;
      fd << "**** str stack (" << stack_str_.size() << ")..." << endl;
      fd << "**** obj stack (" << stack_obj_size_ << ")..." << endl;
      fd << "**** args_vec4 array (" << args_vec4.size() << ")..." << endl;
      for (size_t idx = 0 ; idx < args_vec4.size() ; idx += 1)
	    fd << "    " << idx << ": " << args_vec4[idx] << endl;
      fd << "**** file/line (";
      if (filenm_) fd << filenm_;
      else fd << "<no file name>";
      fd << ":" << lineno_ << ")" << endl;
      fd << "**** Done ****" << endl;
}

/*
 * This function converts the text format of the string by interpreting
 * any octal characters (\nnn) to their single byte value. We do this here
 * because the text value in the vvp_code_t is stored as a C string. This
 * converts it to a C++ string that can hold binary values. We only have
 * to handle the octal escapes because the main compiler takes care of all
 * the other string special characters and normalizes the strings to use
 * only this format.
 */
static string filter_string(const char*text)
{
      vector<char> tmp (strlen(text)+1);
      size_t dst = 0;
      for (const char*ptr = text ; *ptr ; ptr += 1) {
	    // Not an escape? Move on.
	    if (*ptr != '\\') {
		  tmp[dst++] = *ptr;
		  continue;
	    }

	    // Now we know that *ptr is pointing to a \ character and we
	    // have an octal sequence coming up. Advance the ptr and start
	    // processing octal digits.
	    ptr += 1;
	    if (*ptr == 0)
		  break;

	    char byte = 0;
	    int cnt = 3;
	    while (*ptr && cnt > 0 && *ptr >= '0' && *ptr <= '7') {
		  byte *= 8;
		  byte += *ptr - '0';
		  cnt -= 1;
		  ptr += 1;
	    }

	    // null-bytes are supposed to be removed when assigning a string
	    // literal to a string.
	    if (byte != '\0')
		  tmp[dst++] = byte;

	    // After the while loop above, the ptr points to the next character,
	    // but the for-loop condition is assuming that ptr points to the last
	    // character, since it has the ptr+=1.
	    ptr -= 1;
      }

      // Put a nul byte at the end of the built up string, but really we are
      // using the known length in the string constructor.
      tmp[dst] = 0;
      string res (&tmp[0], dst);
      return res;
}

static bool do_disable(vthread_t thr, vthread_t match);
static void do_join(vthread_t thr, vthread_t child);

__vpiScope* vthread_scope(struct vthread_s*thr)
{
      return thr->parent_scope;
}

struct vthread_s*running_thread = 0;

static vpiHandle lookup_scope_item_(__vpiScope*scope, const char*name)
{
      if (!(scope && name))
            return 0;

      for (unsigned idx = 0; idx < scope->intern.size(); idx += 1) {
            vpiHandle item = scope->intern[idx];
            if (!item)
                  continue;

            if (vpi_get(vpiType, item) == vpiPort)
                  continue;

            const char*item_name = vpi_get_str(vpiName, item);
            if (item_name && strcmp(item_name, name) == 0)
                  return item;

            if (vpi_get(vpiType, item) == vpiMemory
                || vpi_get(vpiType, item) == vpiNetArray) {
                  vpiHandle word_iter = item->vpi_iterate(vpiMemoryWord);
                  vpiHandle word = 0;
                  while (word_iter && (word = vpi_scan(word_iter))) {
                        const char*word_name = vpi_get_str(vpiName, word);
                        if (word_name && strcmp(word_name, name) == 0) {
                              vpi_free_object(word_iter);
                              return word;
                        }
                  }
            }
      }

      if (virtual_dispatch_trace_enabled_()) {
            fprintf(stderr, "vdispatch: lookup miss name=%s scope=%s intern=%zu\n",
                    name, scope_name_or_unknown_(scope), scope->intern.size());
            for (unsigned idx = 0; idx < scope->intern.size(); idx += 1) {
                  vpiHandle cur = scope->intern[idx];
                  if (!cur)
                        continue;
                  const char*cur_name = vpi_get_str(vpiName, cur);
                  fprintf(stderr, "vdispatch:   intern[%u] type=%d name=%s\n",
                          idx, vpi_get(vpiType, cur), cur_name ? cur_name : "<null>");
            }
      }
      return 0;
}

static vvp_net_t* handle_net_(vpiHandle item)
{
      if (!item)
            return 0;

      if (__vpiSignal*sig = dynamic_cast<__vpiSignal*>(item))
            return sig->node;
      if (__vpiRealVar*sig = dynamic_cast<__vpiRealVar*>(item))
            return sig->net;
      if (__vpiBaseVar*sig = dynamic_cast<__vpiBaseVar*>(item))
            return sig->get_net();
      return 0;
}

static vpiHandle lookup_scope_item_by_net_(__vpiScope*scope, vvp_net_t*net)
{
      if (!(scope && net))
            return 0;

      for (unsigned idx = 0; idx < scope->intern.size(); idx += 1) {
            vpiHandle item = scope->intern[idx];
            if (!item)
                  continue;
            if (handle_net_(item) == net)
                  return item;
      }

      return 0;
}

static vpiHandle lookup_scope_item_by_net_chain_(__vpiScope*scope, vvp_net_t*net,
                                                 __vpiScope**found_scope)
{
      for (__vpiScope*cur = scope ; cur ; cur = cur->scope) {
            if (vpiHandle item = lookup_scope_item_by_net_(cur, net)) {
                  if (found_scope)
                        *found_scope = cur;
                  return item;
            }
      }

      if (found_scope)
            *found_scope = 0;
      return 0;
}

static vpiPortInfo* lookup_scope_port_by_index_(__vpiScope*scope, unsigned index)
{
      if (!scope)
            return 0;

      for (unsigned idx = 0; idx < scope->intern.size(); idx += 1) {
            vpiPortInfo*port = dynamic_cast<vpiPortInfo*>(scope->intern[idx]);
            if (!port)
                  continue;
            if (port->get_index() == index)
                  return port;
      }

      return 0;
}

static vvp_fun_signal_object* handle_object_fun_(vpiHandle item)
{
      vvp_net_t*net = handle_net_(item);
      if (!net)
            return 0;

      vvp_fun_signal_object*fun =
            dynamic_cast<vvp_fun_signal_object*>(net->fun);
      if (!fun)
            fun = dynamic_cast<vvp_fun_signal_object*>(net->fil);
      return fun;
}

static vvp_fun_signal_string* handle_string_fun_(vpiHandle item)
{
      vvp_net_t*net = handle_net_(item);
      if (!net)
            return 0;

      vvp_fun_signal_string*fun =
            dynamic_cast<vvp_fun_signal_string*>(net->fun);
      if (!fun)
            fun = dynamic_cast<vvp_fun_signal_string*>(net->fil);
      return fun;
}

static vvp_fun_signal_real* handle_real_fun_(vpiHandle item)
{
      vvp_net_t*net = handle_net_(item);
      if (!net)
            return 0;

      vvp_fun_signal_real*fun =
            dynamic_cast<vvp_fun_signal_real*>(net->fun);
      if (!fun)
            fun = dynamic_cast<vvp_fun_signal_real*>(net->fil);
      return fun;
}

static vvp_fun_signal_vec* handle_vec4_fun_(vpiHandle item)
{
      vvp_net_t*net = handle_net_(item);
      if (!net)
            return 0;

      vvp_fun_signal_vec*fun =
            dynamic_cast<vvp_fun_signal_vec*>(net->fun);
      if (!fun)
            fun = dynamic_cast<vvp_fun_signal_vec*>(net->fil);
      return fun;
}

static void collect_scope_copy_items_(vector<vpiHandle>&items,
                                      __vpiScope*scope,
                                      vpiHandle skip_item = 0)
{
      items.clear();
      if (!scope)
            return;

      for (unsigned idx = 0; idx < scope->intern.size(); idx += 1) {
            vpiHandle item = scope->intern[idx];
            if (!item || item == skip_item)
                  continue;
            if (dynamic_cast<__vpiScope*>(item))
                  continue;
            if (vpi_get(vpiType, item) == vpiPort)
                  continue;
            items.push_back(item);
      }
}

static vvp_signal_value* handle_signal_value_(vpiHandle item)
{
      vvp_net_t*net = handle_net_(item);
      if (!net)
            return 0;

      vvp_signal_value*fun =
            dynamic_cast<vvp_signal_value*>(net->fun);
      if (!fun)
            fun = dynamic_cast<vvp_signal_value*>(net->fil);
      return fun;
}

static bool read_handle_object_in_thread_(vpiHandle item, vthread_t thr,
                                          vvp_object_t&value)
{
      if (!(item && thr)) {
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: object read missing item=%p thr=%p\n",
                          (void*)item, (void*)thr);
            return false;
      }

      vvp_fun_signal_object*fun = handle_object_fun_(item);
      if (!fun) {
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: object read missing object fun for item=%s type=%d\n",
                          vpi_get_str(vpiName, item), vpi_get(vpiType, item));
            return false;
      }

      vthread_t save_running = running_thread;
      running_thread = thr;
      value = fun->get_object();
      running_thread = save_running;
      return true;
}

static bool load_str_trace_scope_match_(__vpiScope*scope)
{
      static int enabled = -1;
      static string match_text;

      if (enabled < 0) {
            const char*env = getenv("IVL_LOAD_STR_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
            if (enabled && env
                && strcmp(env, "1") != 0 && strcmp(env, "ALL") != 0
                && strcmp(env, "*") != 0)
                  match_text = env;
      }

      if (!enabled)
            return false;
      if (match_text.empty())
            return true;

      const char*scope_name = scope ? vpi_get_str(vpiFullName, scope) : 0;
      return scope_name && strstr(scope_name, match_text.c_str());
}

static const char*object_trace_class_(const vvp_object_t&value)
{
      if (value.test_nil())
            return "<nil>";
      if (vvp_cobject*cobj = value.peek<vvp_cobject>()) {
            const class_type*defn = cobj->get_defn();
            if (defn)
                  return defn->class_name().c_str();
            return "<cobject>";
      }
      if (value.peek<vvp_vinterface>())
            return "<vinterface>";
      if (value.peek<vvp_queue>())
            return "<queue>";
      if (value.peek<vvp_darray>())
            return "<darray>";
      if (value.peek<vvp_process>())
            return "<process>";
      return "<object>";
}

template <typename T> static const char*assoc_value_trace_class_(const T&)
{
      return "<scalar>";
}

static const char*assoc_value_trace_class_(const vvp_object_t&value)
{
      return object_trace_class_(value);
}

static void assoc_trace_traversal_key_(const string&key)
{
      fprintf(stderr, " key=\"%s\"", key.c_str());
}

static void assoc_trace_traversal_key_(const vvp_object_t&key)
{
      fprintf(stderr, " key=%p key_class=%s",
              (void*)key.peek<vvp_object>(),
              object_trace_class_(key));
}

static void assoc_trace_traversal_key_(const vvp_vector4_t&key)
{
      fprintf(stderr, " key_width=%u", key.size());
}

template <typename KEY, class ASSOC>
static void assoc_trace_traversal_(vthread_t thr, const char*op,
                                   ASSOC*assoc, bool ok, const KEY&key)
{
      if (!assoc_trace_scope_match_(thr))
            return;

      fprintf(stderr, "trace assoc: op=%s scope=%s assoc=%p size=%zu ok=%d",
              op,
              scope_name_or_unknown_(thr ? thr->parent_scope : 0),
              (void*)assoc,
              assoc ? assoc->size() : 0,
              ok ? 1 : 0);
      if (ok)
            assoc_trace_traversal_key_(key);
      fputc('\n', stderr);
}

static const char*assoc_signal_fun_kind_(vvp_net_t*net)
{
      if (!net)
            return "<none>";

      if (dynamic_cast<vvp_fun_signal_object_aa*>(net->fun)
          || dynamic_cast<vvp_fun_signal_object_aa*>(net->fil))
            return "object_aa";
      if (dynamic_cast<vvp_fun_signal_object_sa*>(net->fun)
          || dynamic_cast<vvp_fun_signal_object_sa*>(net->fil))
            return "object_sa";
      return "<other>";
}

template <typename ELEM, class ASSOC>
static void assoc_trace_signal_store_(vthread_t thr, vvp_net_t*net,
                                      ASSOC*assoc, const string&key,
                                      const ELEM&value)
{
      if (!assoc_trace_scope_match_(thr))
            return;

      fprintf(stderr,
              "trace assoc: op=store/sig/str scope=%s net=%p fun=%s assoc=%p size=%zu key=\"%s\" value_class=%s\n",
              scope_name_or_unknown_(thr ? thr->parent_scope : 0),
              (void*)net,
              assoc_signal_fun_kind_(net),
              (void*)assoc,
              assoc ? assoc->size() : 0,
              key.c_str(),
              assoc_value_trace_class_(value));
}

template <typename ELEM, class ASSOC>
static void assoc_trace_signal_store_(vthread_t thr, vvp_net_t*net,
                                      ASSOC*assoc, const vvp_object_t&key,
                                      const ELEM&value)
{
      if (!assoc_trace_scope_match_(thr))
            return;

      fprintf(stderr,
              "trace assoc: op=store/sig/obj scope=%s net=%p fun=%s assoc=%p size=%zu key=%p key_class=%s value_class=%s\n",
              scope_name_or_unknown_(thr ? thr->parent_scope : 0),
              (void*)net,
              assoc_signal_fun_kind_(net),
              (void*)assoc,
              assoc ? assoc->size() : 0,
              (void*)key.peek<vvp_object>(),
              object_trace_class_(key),
              assoc_value_trace_class_(value));
}

template <typename ELEM, class ASSOC>
static void assoc_trace_signal_store_(vthread_t thr, vvp_net_t*net,
                                      ASSOC*assoc, const vvp_vector4_t&key,
                                      const ELEM&value)
{
      if (!assoc_trace_scope_match_(thr))
            return;

      fprintf(stderr,
              "trace assoc: op=store/sig/vec scope=%s net=%p fun=%s assoc=%p size=%zu key_wid=%u value_class=%s\n",
              scope_name_or_unknown_(thr ? thr->parent_scope : 0),
              (void*)net,
              assoc_signal_fun_kind_(net),
              (void*)assoc,
              assoc ? assoc->size() : 0,
              key.size(),
              assoc_value_trace_class_(value));
}

template <typename ELEM, class ASSOC>
static void assoc_trace_signal_load_(vthread_t thr, vvp_net_t*net,
                                     ASSOC*assoc, const string&key,
                                     const ELEM&value)
{
      if (!assoc_trace_scope_match_(thr))
            return;

      fprintf(stderr,
              "trace assoc: op=load/sig/str scope=%s net=%p fun=%s assoc=%p size=%zu key=\"%s\" value_class=%s\n",
              scope_name_or_unknown_(thr ? thr->parent_scope : 0),
              (void*)net,
              assoc_signal_fun_kind_(net),
              (void*)assoc,
              assoc ? assoc->size() : 0,
              key.c_str(),
              assoc_value_trace_class_(value));
}

template <typename ELEM, class ASSOC>
static void assoc_trace_signal_load_(vthread_t thr, vvp_net_t*net,
                                     ASSOC*assoc, const vvp_object_t&key,
                                     const ELEM&value)
{
      if (!assoc_trace_scope_match_(thr))
            return;

      fprintf(stderr,
              "trace assoc: op=load/sig/obj scope=%s net=%p fun=%s assoc=%p size=%zu key=%p key_class=%s value_class=%s\n",
              scope_name_or_unknown_(thr ? thr->parent_scope : 0),
              (void*)net,
              assoc_signal_fun_kind_(net),
              (void*)assoc,
              assoc ? assoc->size() : 0,
              (void*)key.peek<vvp_object>(),
              object_trace_class_(key),
              assoc_value_trace_class_(value));
}

template <typename ELEM, class ASSOC>
static void assoc_trace_signal_load_(vthread_t thr, vvp_net_t*net,
                                     ASSOC*assoc, const vvp_vector4_t&key,
                                     const ELEM&value)
{
      if (!assoc_trace_scope_match_(thr))
            return;

      fprintf(stderr,
              "trace assoc: op=load/sig/vec scope=%s net=%p fun=%s assoc=%p size=%zu key_wid=%u value_class=%s\n",
              scope_name_or_unknown_(thr ? thr->parent_scope : 0),
              (void*)net,
              assoc_signal_fun_kind_(net),
              (void*)assoc,
              assoc ? assoc->size() : 0,
              key.size(),
              assoc_value_trace_class_(value));
}

static bool read_handle_string_in_thread_(vpiHandle item, vthread_t thr,
                                          string&value)
{
      if (!(item && thr))
            return false;

      vvp_fun_signal_string*fun = handle_string_fun_(item);
      if (!fun)
            return false;

      vthread_t save_running = running_thread;
      running_thread = thr;
      value = fun->get_string();
      running_thread = save_running;
      return true;
}

static bool read_handle_real_in_thread_(vpiHandle item, vthread_t thr,
                                        double&value)
{
      if (!(item && thr))
            return false;

      vvp_fun_signal_real*fun = handle_real_fun_(item);
      if (!fun)
            return false;

      vthread_t save_running = running_thread;
      running_thread = thr;
      value = fun->real_unfiltered_value();
      running_thread = save_running;
      return true;
}

static bool read_handle_vec4_in_thread_(vpiHandle item, vthread_t thr,
                                        vvp_vector4_t&value)
{
      if (!(item && thr))
            return false;

      vvp_signal_value*fun = handle_signal_value_(item);
      if (!fun)
            return false;

      vthread_t save_running = running_thread;
      running_thread = thr;
      value = vvp_vector4_t(fun->value_size(), BIT4_X);
      fun->vec4_value(value);
      running_thread = save_running;
      return true;
}

static bool write_handle_object_to_context_(vpiHandle item,
                                            const vvp_object_t&value,
                                            vvp_context_t context)
{
      vvp_net_t*net = handle_net_(item);
      if (!(net && context))
            return false;
      if (!handle_object_fun_(item))
            return false;

      vvp_send_object(vvp_net_ptr_t(net, 0), value, context);
      return true;
}

static bool write_handle_string_to_context_(vpiHandle item,
                                            const string&value,
                                            vvp_context_t context)
{
      vvp_net_t*net = handle_net_(item);
      if (!(net && context))
            return false;
      if (!handle_string_fun_(item))
            return false;

      vvp_send_string(vvp_net_ptr_t(net, 0), value, context);
      return true;
}

static bool write_handle_real_to_context_(vpiHandle item,
                                          double value,
                                          vvp_context_t context)
{
      vvp_net_t*net = handle_net_(item);
      if (!(net && context))
            return false;
      if (!handle_real_fun_(item))
            return false;

      vvp_send_real(vvp_net_ptr_t(net, 0), value, context);
      return true;
}

static bool write_handle_vec4_to_context_(vpiHandle item,
                                          const vvp_vector4_t&value,
                                          vvp_context_t context)
{
      vvp_net_t*net = handle_net_(item);
      if (!(net && context))
            return false;
      if (!handle_vec4_fun_(item))
            return false;

      vvp_send_vec4(vvp_net_ptr_t(net, 0), value, context);
      return true;
}

static bool copy_handle_value_to_context_(vpiHandle src_item, vthread_t src_thr,
                                          vpiHandle dst_item, vvp_context_t dst_context)
{
      vvp_object_t obj_val;
      if (read_handle_object_in_thread_(src_item, src_thr, obj_val))
            return write_handle_object_to_context_(dst_item, obj_val, dst_context);

      string str_val;
      if (read_handle_string_in_thread_(src_item, src_thr, str_val))
            return write_handle_string_to_context_(dst_item, str_val, dst_context);

      double real_val = 0.0;
      if (read_handle_real_in_thread_(src_item, src_thr, real_val))
            return write_handle_real_to_context_(dst_item, real_val, dst_context);

      vvp_vector4_t vec_val;
      if (read_handle_vec4_in_thread_(src_item, src_thr, vec_val))
            return write_handle_vec4_to_context_(dst_item, vec_val, dst_context);

      return false;
}

string get_fileline()
{
      return running_thread->get_fileline();
}

void vthread_push(struct vthread_s*thr, double val)
{
      thr->push_real(val);
}

void vthread_push(struct vthread_s*thr, const string&val)
{
      thr->push_str(val);
}

void vthread_push(struct vthread_s*thr, const vvp_vector4_t&val)
{
      thr->push_vec4(val);
}

void vthread_pop_real(struct vthread_s*thr, unsigned depth)
{
      thr->pop_real(depth);
}

void vthread_pop_str(struct vthread_s*thr, unsigned depth)
{
      thr->pop_str(depth);
}

void vthread_pop_vec4(struct vthread_s*thr, unsigned depth)
{
      thr->pop_vec4(depth);
}

void vthread_pop_obj(struct vthread_s*thr, unsigned depth)
{
      thr->pop_object(depth);
}

double vthread_get_real_stack(struct vthread_s*thr, unsigned depth)
{
      return thr->peek_real(depth);
}

const string&vthread_get_str_stack(struct vthread_s*thr, unsigned depth)
{
      return thr->peek_str(depth);
}

void vthread_set_str_stack(struct vthread_s*thr, unsigned depth, const string&val)
{
      thr->poke_str(depth, val);
}

const vvp_vector4_t& vthread_get_vec4_stack(struct vthread_s*thr, unsigned depth)
{
      return thr->peek_vec4(depth);
}

void vthread_set_vec4_stack(struct vthread_s*thr, unsigned depth, const vvp_vector4_t&val)
{
      thr->poke_vec4(depth, val);
}

const vvp_object_t& vthread_get_obj_stack(struct vthread_s*thr, unsigned depth)
{
      return thr->peek_object(depth);
}

void vthread_set_obj_stack(struct vthread_s*thr, unsigned depth, const vvp_object_t&val)
{
      thr->poke_object(depth, val);
}

/*
 * Some thread management functions
 */
static void size_to_vec4_(size_t size, vvp_vector4_t&val);
static size_t dynamic_collection_size_(const vvp_object_t&obj);
static bool step_trace_enabled_(const char*scope_name);

/*
 * This is a function to get a vvp_queue handle from the variable
 * referenced by "net". If the queue is nil, then allocated it and
 * assign the value to the net. Note that this function is
 * parameterized by the queue type so that we can create the right
 * derived type of queue object.
 */
template <class VVP_QUEUE> static vvp_queue*get_queue_object(vthread_t thr, vvp_net_t*net)
{
      vvp_fun_signal_object*obj = dynamic_cast<vvp_fun_signal_object*> (net->fun);
      assert(obj);

      vvp_queue*queue = obj->get_object().peek<vvp_queue>();
      VVP_QUEUE*typed_queue = dynamic_cast<VVP_QUEUE*>(queue);
      if (typed_queue == 0) {
	    /* Compile-progress fallback: queue variables can be touched by mixed
	     * opcodes while emit-side typing is being completed. If the stored
	     * queue kind does not match the opcode-requested element type, rebind
	     * to the expected queue class so subsequent operations stay coherent. */
	    if (queue != 0 && queue->get_size() != 0) {
		  static bool warned_queue_type_rebind = false;
		  if (!warned_queue_type_rebind) {
			cerr << thr->get_fileline()
			     << "Warning: queue element-type mismatch at runtime; "
			     << "reinitializing queue with opcode-selected type."
			     << endl;
			warned_queue_type_rebind = true;
		  }
	    }
	    queue = new VVP_QUEUE;
	    vvp_object_t val (queue);
	    vvp_net_ptr_t ptr (net, 0);
	    vvp_send_object(ptr, val, ensure_write_context_(thr, "queue-init"));
	    typed_queue = static_cast<VVP_QUEUE*>(queue);
      }

      return typed_queue;
}

template <class VVP_QUEUE> static VVP_QUEUE*pop_queue_receiver_(vthread_t thr, vvp_object_t&recv)
{
      thr->pop_object(recv);
      vvp_queue*queue = recv.peek<vvp_queue>();
      if (!queue)
	    return 0;
      return dynamic_cast<VVP_QUEUE*>(queue);
}

template <class VVP_QUEUE>
static VVP_QUEUE*pop_queue_receiver_(vthread_t thr, vvp_object_t&recv,
                                     vvp_net_t*&root_net, vvp_object_t&root_obj)
{
      root_net = thr->peek_object_source_net(0);
      root_obj = thr->peek_object_root(0);
      thr->pop_object(recv);
      vvp_queue*queue = recv.peek<vvp_queue>();
      if (!queue)
            return 0;
      return dynamic_cast<VVP_QUEUE*>(queue);
}

bool of_QSIZE(vthread_t thr, vvp_code_t cp)
{
      vvp_fun_signal_object*obj = dynamic_cast<vvp_fun_signal_object*> (cp->net->fun);
      assert(obj);

      vvp_vector4_t val;
      size_to_vec4_(dynamic_collection_size_(obj->get_object()), val);
      thr->push_vec4(val);
      return true;
}

bool of_QSIZE_O(vthread_t thr, vvp_code_t)
{
      vvp_object_t recv;
      thr->pop_object(recv);

      vvp_vector4_t val;
      size_to_vec4_(dynamic_collection_size_(recv), val);
      thr->push_vec4(val);
      return true;
}

/*
 * %randomize
 *
 * Randomize all rand/randc properties of the class object on top of the
 * object stack.  Pushes 1 (success) onto the vec4 stack.  Does not
 * implement constraint solving; constraints are ignored.
 */
bool of_RANDOMIZE(vthread_t thr, vvp_code_t)
{
      vvp_object_t&obj = thr->peek_object();
      vvp_cobject*cobj = obj.peek<vvp_cobject>();

      if (cobj) {
	    const class_type*defn = cobj->get_defn();

	      // Fill all rand properties with random bits first.
	    for (size_t pid = 0 ; pid < defn->property_count() ; pid += 1) {
		  if (!defn->property_is_rand(pid))
			continue;
		  if (!cobj->rand_mode(pid))
			continue;
		  vvp_vector4_t val;
		  cobj->get_vec4(pid, val);
		  unsigned wid = val.size();
		  if (wid == 0)
			continue;
		  for (unsigned i = 0 ; i < wid ; i += 32) {
			unsigned rnd = (unsigned)rand();
			for (unsigned b = 0 ; b < 32 && i + b < wid ; b += 1)
			      val.set_bit(i + b, (rnd >> b) & 1 ? BIT4_1 : BIT4_0);
		  }
		  cobj->set_vec4(pid, val);
	    }

	      // If this class has constraints, solve with Z3.
	    if (defn->constraint_count() > 0)
		  vvp_z3_randomize(defn, cobj);
      }

      vvp_object_t tmp;
      thr->pop_object(tmp);

	// Return a 32-bit result (1 = success) so %store/vec4 with any
	// width up to 32 works without assertion failure.
      vvp_vector4_t result(32, BIT4_0);
      result.set_bit(0, BIT4_1);
      thr->push_vec4(result);
      return true;
}

bool of_RANDOMIZE_WITH(vthread_t thr, vvp_code_t code)
{
	// code->text      = IR string (with possible "v:N:W" slot placeholders)
	// code->bit_idx[0] = number of runtime value slots on the vec4 stack
      unsigned n_vals = code->bit_idx[0];
      const char* ir_text = code->text ? code->text : "";

	// Pop runtime slot values (pushed in reverse: slot 0 is deepest).
      vector<uint64_t> slot_vals(n_vals);
      for (unsigned i = n_vals ; i > 0 ; i--) {
	    vvp_vector4_t v = thr->pop_vec4();
	    uint64_t bits = 0;
	    unsigned wid = v.size(); if (wid > 64) wid = 64;
	    for (unsigned b = 0 ; b < wid ; b++)
		  if (v.value(b) == BIT4_1) bits |= (1ULL << b);
	    slot_vals[i - 1] = bits;
      }

      vvp_object_t&obj = thr->peek_object();
      vvp_cobject*cobj = obj.peek<vvp_cobject>();

      if (cobj) {
	    const class_type*defn = cobj->get_defn();

	      // Randomize all rand properties first.
	    for (size_t pid = 0 ; pid < defn->property_count() ; pid += 1) {
		  if (!defn->property_is_rand(pid)) continue;
		  if (!cobj->rand_mode(pid)) continue;
		  vvp_vector4_t val;
		  cobj->get_vec4(pid, val);
		  unsigned wid = val.size();
		  if (wid == 0) continue;
		  for (unsigned i = 0 ; i < wid ; i += 32) {
			unsigned rnd = (unsigned)rand();
			for (unsigned b = 0 ; b < 32 && i + b < wid ; b += 1)
			      val.set_bit(i + b, (rnd >> b) & 1 ? BIT4_1 : BIT4_0);
		  }
		  cobj->set_vec4(pid, val);
	    }

	      // Solve with Z3: class constraints + with-constraints.
	    vector<string> extra_ir;
	    if (ir_text && *ir_text) extra_ir.push_back(string(ir_text));
	    vvp_z3_randomize(defn, cobj, extra_ir, slot_vals);
      }

      vvp_object_t tmp;
      thr->pop_object(tmp);

      vvp_vector4_t result(32, BIT4_0);
      result.set_bit(0, BIT4_1);
      thr->push_vec4(result);
      return true;
}

/*
 * %rand_mode
 *
 * Set rand_mode for all rand properties of the cobject on the object stack.
 * Pops mode (0=disable, nonzero=enable) from vec4 stack, pops object.
 */
bool of_RAND_MODE(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t mode_vec = thr->pop_vec4();
      bool mode = (mode_vec.value(0) == BIT4_1);

      vvp_object_t obj;
      thr->pop_object(obj);
      vvp_cobject*cobj = obj.peek<vvp_cobject>();

      if (cobj) {
	    const class_type*defn = cobj->get_defn();
	    for (size_t pid = 0 ; pid < defn->property_count() ; pid += 1) {
		  if (defn->property_is_rand(pid))
			cobj->set_rand_mode(pid, mode);
	    }
      }
      return true;
}

/*
 * The following are used to allow a common template to be written for
 * queue real/string/vec4 operations
 */
inline static void pop_value(vthread_t thr, double&value, unsigned)
{
      value = thr->pop_real();
}

inline static void pop_value(vthread_t thr, string&value, unsigned)
{
      value = thr->pop_str();
}

inline static void pop_value(vthread_t thr, vvp_vector4_t&value, unsigned wid)
{
      value = thr->pop_vec4();
	/* Allow size mismatch: truncate or zero-extend to the expected width.
	 * UVM class-typed operations may push values of different widths. */
      if (value.size() != wid) {
	    value.resize(wid);
      }
}

inline static void pop_value(vthread_t thr, vvp_object_t&value, unsigned)
{
      thr->pop_object(value);
}

/*
 * The following are used to allow the queue templates to print correctly.
 */
inline static string get_queue_type(double&)
{
      return "queue<real>";
}

inline static string get_queue_type(string&)
{
      return "queue<string>";
}

inline static string get_queue_type(const vvp_vector4_t&value)
{
      ostringstream buf;
      buf << "queue<vector[" << value.size() << "]>";
      string res = buf.str();
      return res;
}

inline static string get_queue_type(vvp_object_t&)
{
      return "queue<object>";
}

inline static void print_queue_value(double value)
{
      cerr << value;
}

inline static void print_queue_value(const string&value)
{
      cerr << "\"" << value << "\"";
}

inline static void print_queue_value(const vvp_vector4_t&value)
{
      cerr << value;
}

inline static void print_queue_value(const vvp_object_t&)
{
      cerr << "<object>";
}

/*
 * The following are used to get a darray/queue default value.
 */
inline static void dq_default(double&value, unsigned)
{
      value = 0.0;
}

inline static void dq_default(string&value, unsigned)
{
      value = "";
}

inline static void dq_default(vvp_vector4_t&value, unsigned wid)
{
      value = vvp_vector4_t(wid);
}

inline static void dq_default(vvp_object_t&value, unsigned)
{
      value.reset();
}

static void size_to_vec4_(size_t size, vvp_vector4_t&val)
{
      uint32_t use_size = static_cast<uint32_t>(size);
      val = vvp_vector4_t(32, BIT4_0);
      for (unsigned idx = 0 ; idx < 32 ; idx += 1)
	    if ((use_size >> idx) & 1U)
		  val.set_bit(idx, BIT4_1);
}

static size_t dynamic_collection_size_(const vvp_object_t&obj)
{
      if (vvp_queue*queue = obj.peek<vvp_queue>())
	    return queue->get_size();
      if (vvp_darray*darray = obj.peek<vvp_darray>())
	    return darray->get_size();
      if (vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>())
            return assoc->size();
      return 0;
}


template <class T> T coerce_to_width(const T&that, unsigned width)
{
      if (that.size() == width)
	    return that;

      assert(that.size() > width);
      T res (width);
      for (unsigned idx = 0 ;  idx < width ;  idx += 1)
	    res.set_bit(idx, that.value(idx));

      return res;
}

/* Explicitly define the vvp_vector4_t version of coerce_to_width(). */
template vvp_vector4_t coerce_to_width(const vvp_vector4_t&that,
                                       unsigned width);

/*
 * Keep a best-effort owner map for automatic contexts so we can free
 * through the allocating scope even if callers pass a mismatched scope.
 */
static map<vvp_context_t, __vpiScope*> automatic_context_owner;
static map<vvp_context_t, unsigned> automatic_context_refcount;

static void retain_automatic_context_(vvp_context_t context)
{
      if (!context)
            return;

      map<vvp_context_t, unsigned>::iterator ref_it =
            automatic_context_refcount.find(context);
      if (ref_it == automatic_context_refcount.end()) {
            automatic_context_refcount[context] = 1;
      } else {
            ref_it->second += 1;
      }
}

static void retain_context_chain_(vvp_context_t context)
{
      while (context) {
            retain_automatic_context_(context);
            context = vvp_get_stacked_context(context);
      }
}


static void multiply_array_imm(unsigned long*res, const unsigned long*val,
			       unsigned words, unsigned long imm)
{
      for (unsigned idx = 0 ; idx < words ; idx += 1)
	    res[idx] = 0;

      for (unsigned mul_idx = 0 ; mul_idx < words ; mul_idx += 1) {
	    unsigned long sum;
	    unsigned long tmp = multiply_with_carry(val[mul_idx], imm, sum);

	    unsigned long carry = 0;
	    res[mul_idx] = add_with_carry(res[mul_idx], tmp, carry);
	    for (unsigned add_idx = mul_idx+1 ; add_idx < words ; add_idx += 1) {
		  res[add_idx] = add_with_carry(res[add_idx], sum, carry);
		  sum = 0;
	    }
      }
}

/*
 * Allocate a context for use by a child thread. By preference, use
 * the last freed context. If none available, create a new one. Add
 * it to the list of live contexts in that scope.
 */
static vvp_context_t vthread_alloc_context(__vpiScope*scope)
{
      assert(scope->is_automatic());

      vvp_context_t context = scope->free_contexts;
      if (context) {
            scope->free_contexts = vvp_get_next_context(context);
            vvp_set_next_context(context, 0);
            vvp_set_stacked_context(context, 0);
            for (unsigned idx = 0 ; idx < scope->nitem ; idx += 1) {
                  scope->item[idx]->reset_instance(context);
            }
      } else {
            context = vvp_allocate_context(scope->nitem);
            vvp_set_next_context(context, 0);
            vvp_set_stacked_context(context, 0);
            for (unsigned idx = 0 ; idx < scope->nitem ; idx += 1) {
                  scope->item[idx]->alloc_instance(context);
            }
      }

      vvp_set_next_context(context, scope->live_contexts);
      scope->live_contexts = context;
      automatic_context_owner[context] = scope;
      automatic_context_refcount[context] = 1;

      return context;
}

/*
 * Free a context previously allocated to a child thread by pushing it
 * onto the freed context stack. Remove it from the list of live contexts
 * in that scope.
 */
static void vthread_free_context(vvp_context_t context, __vpiScope*scope)
{
      assert(scope->is_automatic());
      if (!context)
            return;

      map<vvp_context_t, __vpiScope*>::const_iterator owner_it = automatic_context_owner.find(context);
      if (owner_it != automatic_context_owner.end()) {
            __vpiScope*owner = owner_it->second;
            if (owner && owner != scope && owner->is_automatic())
                  scope = owner;
      }

      map<vvp_context_t, unsigned>::iterator ref_it =
            automatic_context_refcount.find(context);
      if (ref_it != automatic_context_refcount.end()) {
            if (ref_it->second > 1) {
                  ref_it->second -= 1;
                  return;
            }
            automatic_context_refcount.erase(ref_it);
      }

      auto context_in_list = [](vvp_context_t head, vvp_context_t needle) -> bool {
            for (vvp_context_t cur = head ; cur ; cur = vvp_get_next_context(cur)) {
                  if (cur == needle)
                        return true;
            }
            return false;
      };

      if (context == scope->live_contexts) {
            scope->live_contexts = vvp_get_next_context(context);
      } else {
            vvp_context_t tmp = scope->live_contexts;
            while (tmp && context != vvp_get_next_context(tmp)) {
                  tmp = vvp_get_next_context(tmp);
            }
            if (tmp) {
                  vvp_set_next_context(tmp, vvp_get_next_context(context));
            } else {
                  // Duplicate free can happen on fallback control paths.
                  if (context_in_list(scope->free_contexts, context))
                        return;
                  static bool warned = false;
                  if (!warned) {
                        const char*scope_name = scope ? vpi_get_str(vpiFullName, scope) : 0;
                        cerr << "Warning: automatic context not found in live list during free; recycling orphan context."
                             << " scope=" << (scope_name ? scope_name : "<unknown>")
                             << " context=" << context
                             << " live_head=" << scope->live_contexts
                             << " free_head=" << scope->free_contexts
                              << endl;
                        warned = true;
                  }
                  vvp_set_stacked_context(context, 0);
                  vvp_set_next_context(context, scope->free_contexts);
                  scope->free_contexts = context;
                  return;
            }
      }

      for (unsigned idx = 0 ; idx < scope->nitem ; idx += 1) {
            if (vvp_fun_signal_object_aa*obj =
                    dynamic_cast<vvp_fun_signal_object_aa*>(scope->item[idx]))
                  obj->clear_current_alias(context);
      }

      vvp_set_stacked_context(context, 0);
      vvp_set_next_context(context, scope->free_contexts);
      scope->free_contexts = context;
}

#ifdef CHECK_WITH_VALGRIND
void contexts_delete(class __vpiScope*scope)
{
      vvp_context_t context = scope->free_contexts;

      while (context) {
	    scope->free_contexts = vvp_get_next_context(context);
	    for (unsigned idx = 0; idx < scope->nitem; idx += 1) {
		  scope->item[idx]->free_instance(context);
	    }
	    free(context);
	    context = scope->free_contexts;
      }
      free(scope->item);
}
#endif

/*
 * Create a new thread with the given start address.
 */
vthread_t vthread_new(vvp_code_t pc, __vpiScope*scope)
{
      vthread_t thr = new struct vthread_s;
      thr->pc     = pc;
	//thr->bits4  = vvp_vector4_t(32);
      thr->parent = 0;
      thr->parent_scope = scope;
      thr->wait_next = 0;
      thr->wt_context = 0;
      thr->rd_context = 0;

      thr->i_am_joining  = 0;
      thr->i_am_detached = 0;
      thr->i_am_waiting  = 0;
      thr->i_am_in_function = 0;
      thr->is_scheduled  = 0;
      thr->i_have_ended  = 0;
      thr->i_was_disabled = 0;
      thr->delay_delete  = 1;
      thr->delete_pending = 0;
      thr->pending_nonlocal_jmp = 0;
      thr->is_callf_child = 0;
      thr->owns_automatic_context = 0;
      thr->owned_context = 0;
      thr->transferred_context = 0;
      thr->skip_free_context = 0;
      thr->staged_alloc_rd_context = 0;
      thr->nonlocal_target = 0;
      thr->nonlocal_origin_scope = 0;
      thr->transferred_context_scope = 0;
      thr->skip_free_scope = 0;
      thr->staged_alloc_rd_scope = 0;
      thr->return_object_mirror_scope = 0;
      thr->dynamic_dispatch_base_scope = 0;
      thr->waiting_for_event = 0;
      thr->event  = 0;
      thr->ecount = 0;

      thr->flags[0] = BIT4_0;
      thr->flags[1] = BIT4_1;
      thr->flags[2] = BIT4_X;
      thr->flags[3] = BIT4_Z;
      for (int idx = 4 ; idx < 8 ; idx += 1)
	    thr->flags[idx] = BIT4_X;

      thr->process_obj_ = new vvp_process(thr);
      scope->threads .insert(thr);
      live_threads_registry_.insert(thr);
      return thr;
}

#ifdef CHECK_WITH_VALGRIND
#if 0
/*
 * These are not currently correct. If you use them you will get
 * double delete messages. There is still a leak related to a
 * waiting event that needs to be investigated.
 */

static void wait_next_delete(vthread_t base)
{
      while (base) {
	    vthread_t tmp = base->wait_next;
	    delete base;
	    base = tmp;
	    if (base->waiting_for_event == 0) break;
      }
}

static void child_delete(vthread_t base)
{
      while (base) {
	    vthread_t tmp = base->child;
	    delete base;
	    base = tmp;
      }
}
#endif

void vthreads_delete(class __vpiScope*scope)
{
      for (std::set<vthread_t>::iterator cur = scope->threads.begin()
		 ; cur != scope->threads.end() ; ++ cur ) {
	    delete *cur;
      }
      scope->threads.clear();
}
#endif

/*
 * Reaping pulls the thread out of the stack of threads. If I have a
 * child, then hand it over to my parent or fully detach it.
 */
static void vthread_reap(vthread_t thr)
{
      if (! thr->children.empty()) {
	    for (set<vthread_t>::iterator cur = thr->children.begin()
		       ; cur != thr->children.end() ; ++cur) {
		  vthread_t child = *cur;
		  assert(child);
		  assert(child->parent == thr);
		  child->parent = thr->parent;
	    }
      }
      if (! thr->detached_children.empty()) {
	    for (set<vthread_t>::iterator cur = thr->detached_children.begin()
		       ; cur != thr->detached_children.end() ; ++cur) {
		  vthread_t child = *cur;
		  assert(child);
		  assert(child->parent == thr);
		  assert(child->i_am_detached);
		  child->parent = 0;
		  child->i_am_detached = 0;
	    }
      }
      if (thr->parent) {
	      /* assert that the given element was removed. */
	    if (thr->i_am_detached) {
		  size_t res = thr->parent->detached_children.erase(thr);
		  assert(res == 1);
	    } else {
		  size_t res = thr->parent->children.erase(thr);
		  assert(res == 1);
	    }
      }

      thr->parent = 0;

	// Remove myself from the containing scope if needed.
      thr->parent_scope->threads.erase(thr);

      thr->pc = codespace_null();

	/* If this thread is not scheduled, then is it safe to delete
	   it now. Otherwise, let the schedule event (which will
	   execute the thread at of_ZOMBIE) delete the object. */
      if ((thr->is_scheduled == 0) && (thr->waiting_for_event == 0)) {
	    assert(thr->children.empty());
	    assert(thr->wait_next == 0);
	    if (thr->delay_delete) {
		  if (!thr->delete_pending) {
			thr->delete_pending = 1;
			schedule_del_thr(thr);
		  }
	    }
	    else
		  vthread_delete(thr);
      }
}

void vthread_delete(vthread_t thr)
{
      live_threads_registry_.erase(thr);
      thr->cleanup();
      delete thr;
}

void vthread_dump_live_threads(const char*reason)
{
      if (!sched_dump_threads_enabled_(reason))
            return;

      unsigned active = 0;
      unsigned waiting = 0;
      unsigned joining = 0;
      unsigned scheduled = 0;

      fprintf(stderr,
              "trace sched: live-thread dump reason=%s total=%zu\n",
              reason ? reason : "<unknown>",
              live_threads_registry_.size());

      for (set<vthread_t>::const_iterator it = live_threads_registry_.begin()
                 ; it != live_threads_registry_.end() ; ++it) {
            vthread_t thr = *it;
            if (!thr)
                  continue;
            if (thr->i_have_ended)
                  continue;

            const char*scope_name = scope_name_or_unknown_(thr->parent_scope);
            const char*parent_name = scope_name_or_unknown_(thr->parent
                                                            ? thr->parent->parent_scope : 0);
            const char*pc_name = thr->pc ? vvp_opcode_mnemonic(thr->pc->opcode) : "<nullpc>";
            const char*pause_name = thr->last_pause_pc
                                  ? vvp_opcode_mnemonic(thr->last_pause_pc->opcode) : "<none>";

            active += 1;
            if (thr->waiting_for_event)
                  waiting += 1;
            if (thr->i_am_joining)
                  joining += 1;
            if (thr->is_scheduled)
                  scheduled += 1;

            fprintf(stderr,
                    "trace sched: thr=%p scope=%s parent=%s pc=%s pause=%s scheduled=%d waiting=%d joining=%d ended=%d detached=%d disabled=%d callf=%d in_func=%d children=%zu wt=%p rd=%p event=%p ecount=%lu\n",
                    (void*)thr,
                    scope_name,
                    parent_name,
                    pc_name,
                    pause_name,
                    thr->is_scheduled ? 1 : 0,
                    thr->waiting_for_event ? 1 : 0,
                    thr->i_am_joining ? 1 : 0,
                    thr->i_have_ended ? 1 : 0,
                    thr->i_am_detached ? 1 : 0,
                    thr->i_was_disabled ? 1 : 0,
                    thr->is_callf_child ? 1 : 0,
                    thr->i_am_in_function ? 1 : 0,
                    thr->children.size(),
                    thr->wt_context,
                    thr->rd_context,
                    (void*)thr->event,
                    thr->ecount);
      }

      fprintf(stderr,
              "trace sched: live-thread summary reason=%s active=%u scheduled=%u waiting=%u joining=%u\n",
              reason ? reason : "<unknown>",
              active, scheduled, waiting, joining);
}

void vthread_dump_running_thread(const char*reason)
{
      if (!sched_dump_threads_enabled_(reason))
            return;

      if (!running_thread) {
            fprintf(stderr,
                    "trace sched: running-thread reason=%s thread=<none>\n",
                    reason ? reason : "<unknown>");
            return;
      }

      const char*scope_name = scope_name_or_unknown_(running_thread->parent_scope);
      const char*pc_name = running_thread->pc
                         ? vvp_opcode_mnemonic(running_thread->pc->opcode) : "<nullpc>";
      const char*pause_name = running_thread->last_pause_pc
                            ? vvp_opcode_mnemonic(running_thread->last_pause_pc->opcode) : "<none>";

      fprintf(stderr,
              "trace sched: running-thread reason=%s thr=%p scope=%s pc=%s pause=%s scheduled=%d waiting=%d joining=%d ended=%d detached=%d disabled=%d callf=%d in_func=%d children=%zu wt=%p rd=%p event=%p ecount=%lu\n",
              reason ? reason : "<unknown>",
              (void*)running_thread,
              scope_name,
              pc_name,
              pause_name,
              running_thread->is_scheduled ? 1 : 0,
              running_thread->waiting_for_event ? 1 : 0,
              running_thread->i_am_joining ? 1 : 0,
              running_thread->i_have_ended ? 1 : 0,
              running_thread->i_am_detached ? 1 : 0,
              running_thread->i_was_disabled ? 1 : 0,
              running_thread->is_callf_child ? 1 : 0,
              running_thread->i_am_in_function ? 1 : 0,
              running_thread->children.size(),
              running_thread->wt_context,
              running_thread->rd_context,
              (void*)running_thread->event,
              running_thread->ecount);
}

void vthread_mark_scheduled(vthread_t thr)
{
      while (thr != 0) {
            static unsigned long trace_count = 0;
            static unsigned long trace_limit = 512;
            const char*target_scope = scope_name_or_unknown_(thr->parent_scope);
            const char*src_scope = scope_name_or_unknown_(running_thread ? running_thread->parent_scope : 0);
            if (trace_count == 0) {
                  const char*env = getenv("IVL_FUNC_TRACE_LIMIT");
                  if (env && *env) {
                        unsigned long parsed = strtoul(env, 0, 10);
                        if (parsed > 0)
                              trace_limit = parsed;
                  }
            }
            if (trace_count < trace_limit
                && (thr->i_am_in_function || thr->is_callf_child
                    || (running_thread && running_thread->i_am_in_function))
                && (function_runtime_trace_enabled_(target_scope)
                    || function_runtime_trace_enabled_(src_scope))) {
                  const char*src_next = (running_thread && running_thread->pc)
                                      ? vvp_opcode_mnemonic(running_thread->pc->opcode)
                                      : "<nullpc>";
                  const char*target_pause = thr->last_pause_pc
                                          ? vvp_opcode_mnemonic(thr->last_pause_pc->opcode)
                                          : "<none>";
                  fprintf(stderr,
                          "trace func-schedule[%lu]: target=%s src=%s src_next=%s target_pause=%s target_waiting=%d target_joining=%d target_ended=%d target_callf=%d target_in_function=%d\n",
                          trace_count + 1,
                          target_scope,
                          src_scope,
                          src_next,
                          target_pause,
                          thr->waiting_for_event ? 1 : 0,
                          thr->i_am_joining ? 1 : 0,
                          thr->i_have_ended ? 1 : 0,
                          thr->is_callf_child ? 1 : 0,
                          thr->i_am_in_function ? 1 : 0);
                  trace_count += 1;
            }
	    assert(thr->is_scheduled == 0);
	    thr->is_scheduled = 1;
	    thr = thr->wait_next;
      }
}

void vthread_mark_final(vthread_t thr)
{
      /*
       * The behavior in a final thread is the same as in a function. Any
       * child thread will be executed immediately rather than being
       * scheduled.
       */
      while (thr != 0) {
	    thr->i_am_in_function = 1;
	    thr = thr->wait_next;
      }
}

void vthread_delay_delete()
{
      if (running_thread)
	    running_thread->delay_delete = 1;
}

/*
 * This function runs each thread by fetching an instruction,
 * incrementing the PC, and executing the instruction. The thread may
 * be the head of a list, so each thread is run so far as possible.
 */
static bool context_live_in_owner(vvp_context_t context);

void vthread_run(vthread_t thr)
{
      static int pc_hottrace_enabled = -1;
      static unsigned long pc_hottrace_limit = 100000;
      static std::map<const struct vvp_code_s*, unsigned long> pc_hottrace_hits;
      static std::set<const struct vvp_code_s*> pc_hottrace_reported;
      static int pc_progress_enabled = -1;
      static unsigned long pc_progress_period = 0;
      static unsigned long pc_progress_counter = 0;
      static bool warned_runentry_rd_sync = false;
      static bool warned_runentry_wt_sync = false;
      static const unsigned long noncallf_loop_limit = 200000;
      static std::set<const struct vvp_code_s*> noncallf_loop_reported;
      if (pc_hottrace_enabled < 0) {
            const char*env = getenv("IVL_PC_HOTTRACE");
            pc_hottrace_enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
            const char*lim = getenv("IVL_PC_HOTTRACE_LIMIT");
            if (lim && *lim) {
                  unsigned long parsed = strtoul(lim, 0, 10);
                  if (parsed > 0)
                        pc_hottrace_limit = parsed;
            }
            const char*prog = getenv("IVL_PC_PROGRESS");
            pc_progress_enabled = (prog && *prog && strcmp(prog, "0") != 0) ? 1 : 0;
            const char*prog_lim = getenv("IVL_PC_PROGRESS_LIMIT");
            if (prog_lim && *prog_lim) {
                  unsigned long parsed = strtoul(prog_lim, 0, 10);
                  if (parsed > 0)
                        pc_progress_period = parsed;
            }
            if (pc_progress_period == 0)
                  pc_progress_period = 1000000;
      }

      while (thr != 0) {
	    vthread_t tmp = thr->wait_next;
	    thr->wait_next = 0;

	    assert(thr->is_scheduled);
	    thr->is_scheduled = 0;

            running_thread = thr;
            __vpiScope*run_ctx_scope = resolve_context_scope(thr->parent_scope);
            if (!thr->wt_context && thr->rd_context
                && context_live_matches_scope_(thr->rd_context, run_ctx_scope)) {
                  if (!warned_runentry_wt_sync) {
                        const char*scope_name = thr->parent_scope ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
                        fprintf(stderr,
                                "Warning: vthread_run synchronized missing wt_context from live rd_context"
                                " (scope=%s wt=%p rd=%p; further similar warnings suppressed)\n",
                                scope_name ? scope_name : "<unknown>",
                                thr->wt_context, thr->rd_context);
                        warned_runentry_wt_sync = true;
                  }
                  thr->wt_context = thr->rd_context;
            }
            if (!thr->rd_context && thr->wt_context
                && context_live_matches_scope_(thr->wt_context, run_ctx_scope)) {
                  if (!warned_runentry_rd_sync) {
                        const char*scope_name = thr->parent_scope ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
                        fprintf(stderr,
                                "Warning: vthread_run synchronized missing rd_context from live wt_context"
                                " (scope=%s rd=%p wt=%p; further similar warnings suppressed)\n",
                                scope_name ? scope_name : "<unknown>",
                                thr->rd_context, thr->wt_context);
                        warned_runentry_rd_sync = true;
                  }
                  thr->rd_context = thr->wt_context;
            }

	    for (;;) {
		  vvp_code_t cp = thr->pc;
                  const char*step_scope_name = thr->parent_scope
                                             ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
                  bool trace_step = step_trace_enabled_(step_scope_name);
		  thr->pc += 1;

		  unsigned long hits = ++pc_hottrace_hits[cp];
		  if (pc_progress_enabled) {
			pc_progress_counter += 1;
			if (pc_progress_counter >= pc_progress_period) {
			      const char*scope_name = "<unknown>";
			      const char*op_name = vvp_opcode_mnemonic(cp->opcode);
			      if (thr->parent_scope) {
				    const char*nm = vpi_get_str(vpiFullName, thr->parent_scope);
				    if (nm) scope_name = nm;
			      }
			      fprintf(stderr,
				      "trace pc-progress: pc=%p opcode=%s@%p scope=%s in_function=%d hits=%lu\n",
				      (void*)cp, op_name, (void*)cp->opcode, scope_name,
				      thr->i_am_in_function ? 1 : 0, hits);
			      pc_progress_counter = 0;
			}
		  }
		  if (pc_hottrace_enabled) {
			if (hits >= pc_hottrace_limit
			    && pc_hottrace_reported.count(cp) == 0) {
			      const char*scope_name = "<unknown>";
			      const char*op_name = vvp_opcode_mnemonic(cp->opcode);
			      if (thr->parent_scope) {
				    const char*nm = vpi_get_str(vpiFullName, thr->parent_scope);
				    if (nm) scope_name = nm;
			      }
			      fprintf(stderr,
				      "Warning: PC hotspot at %p (opcode=%s@%p) hit %lu times in scope %s; potential non-callf liveness loop\n",
				      (void*)cp, op_name, (void*)cp->opcode, hits, scope_name);
			      pc_hottrace_reported.insert(cp);
			}
		  }

		  if (thr->i_am_in_function
		      && hits >= noncallf_loop_limit
		      && noncallf_loop_reported.count(cp) == 0) {
			const char*scope_name = "<unknown>";
			const char*op_name = vvp_opcode_mnemonic(cp->opcode);
			if (thr->parent_scope) {
			      const char*nm = vpi_get_str(vpiFullName, thr->parent_scope);
			      if (nm) scope_name = nm;
			}
			fprintf(stderr,
				"Warning: non-callf loop hotspot at %p (opcode=%s@%p) in %s exceeded %lu hits;"
				" forcing function return fallback (further similar warnings suppressed per-PC)\n",
				(void*)cp, op_name, (void*)cp->opcode, scope_name, hits);
			noncallf_loop_reported.insert(cp);
			thr->pc = codespace_null();
			thr->i_have_ended = 1;
			break;
		  }

		    /* Run the opcode implementation. If the execution of
		       the opcode returns false, then the thread is meant to
		       be paused, so break out of the loop. */
		  bool rc = (cp->opcode)(thr, cp);
                  if (trace_step) {
                        static unsigned long step_trace_count = 0;
                        static unsigned long step_trace_limit = 0;
                        if (step_trace_limit == 0) {
                              const char*env = getenv("IVL_STEP_TRACE_LIMIT");
                              step_trace_limit = env && *env ? strtoul(env, 0, 10) : 256;
                              if (step_trace_limit == 0)
                                    step_trace_limit = 256;
                        }
                        if (step_trace_count < step_trace_limit) {
                              fprintf(stderr,
                                      "trace step[%lu]: scope=%s op=%s cp=%p next=%p rc=%d ended=%d joining=%d children=%zu stopped=%d finished=%d flag4=%d\n",
                                      step_trace_count + 1,
                                      step_scope_name ? step_scope_name : "<unknown>",
                                      vvp_opcode_mnemonic(cp->opcode), (void*)cp,
                                      (void*)thr->pc, rc ? 1 : 0,
                                      thr->i_have_ended ? 1 : 0,
                                      thr->i_am_joining ? 1 : 0,
                                      thr->children.size(),
                                      schedule_stopped() ? 1 : 0,
                                      schedule_finished() ? 1 : 0,
                                      (int)thr->flags[4]);
                              step_trace_count += 1;
                        }
                  }
		  if (rc == false) {
                        thr->last_pause_pc = cp;
                        if (thr->i_am_in_function
                            && function_runtime_trace_enabled_(step_scope_name)) {
                              static unsigned long pause_trace_count = 0;
                              static unsigned long pause_trace_limit = 512;
                              if (pause_trace_count == 0) {
                                    const char*env = getenv("IVL_FUNC_TRACE_LIMIT");
                                    if (env && *env) {
                                          unsigned long parsed = strtoul(env, 0, 10);
                                          if (parsed > 0)
                                                pause_trace_limit = parsed;
                                    }
                              }
                              if (pause_trace_count < pause_trace_limit) {
                                    const char*next_op = thr->pc ? vvp_opcode_mnemonic(thr->pc->opcode) : "<nullpc>";
                                    fprintf(stderr,
                                            "trace func-pause[%lu]: scope=%s pause_op=%s cp=%p next_op=%s next=%p scheduled=%d waiting=%d joining=%d ended=%d disabled=%d children=%zu callf=%d\n",
                                            pause_trace_count + 1,
                                            step_scope_name ? step_scope_name : "<unknown>",
                                            vvp_opcode_mnemonic(cp->opcode),
                                            (void*)cp,
                                            next_op,
                                            (void*)thr->pc,
                                            thr->is_scheduled ? 1 : 0,
                                            thr->waiting_for_event ? 1 : 0,
                                            thr->i_am_joining ? 1 : 0,
                                            thr->i_have_ended ? 1 : 0,
                                            thr->i_was_disabled ? 1 : 0,
                                            thr->children.size(),
                                            thr->is_callf_child ? 1 : 0);
                                    pause_trace_count += 1;
                              }
                        }
			break;
                  }
		    }

	    thr = tmp;
      }
      running_thread = 0;
}

/*
 * The CHUNK_LINK instruction is a special next pointer for linking
 * chunks of code space. It's like a simplified %jmp.
 */
bool of_CHUNK_LINK(vthread_t thr, vvp_code_t code)
{
      assert(code->cptr);
      thr->pc = code->cptr;
      return true;
}

/*
 * This is called by an event functor to wake up all the threads on
 * its list. I in fact created that list in the %wait instruction, and
 * I also am certain that the waiting_for_event flag is set.
 */
void vthread_schedule_list(vthread_t thr)
{
      for (vthread_t cur = thr ;  cur ;  cur = cur->wait_next) {
	    assert(cur->waiting_for_event);
	    cur->waiting_for_event = 0;
      }

      schedule_vthread(thr, 0);
}

static __vpiScope* resolve_context_scope(__vpiScope*scope);

vvp_context_t vthread_get_wt_context()
{
      if (running_thread)
            return ensure_write_context_(running_thread, "get-wt-context");
      else
            return 0;
}

vvp_context_t vthread_get_rd_context()
{
      if (running_thread)
            return running_thread->rd_context;
      else
            return 0;
}

static bool context_on_list(vvp_context_t head, vvp_context_t needle)
{
      for (vvp_context_t cur = head ; cur ; cur = vvp_get_next_context(cur)) {
	    if (cur == needle)
		  return true;
      }
      return false;
}

static bool context_live_in_owner(vvp_context_t context)
{
      if (!context)
            return false;
      map<vvp_context_t, __vpiScope*>::const_iterator owner_it = automatic_context_owner.find(context);
      if (owner_it == automatic_context_owner.end())
            return false;
      __vpiScope*owner = owner_it->second;
      if (!(owner && owner->is_automatic()))
            return false;
      return context_on_list(owner->live_contexts, context);
}

static bool context_live_matches_scope_(vvp_context_t context, __vpiScope*ctx_scope)
{
      if (!context)
            return false;

      if (!(ctx_scope && ctx_scope->is_automatic()))
            return context_live_in_owner(context);

      map<vvp_context_t, __vpiScope*>::const_iterator owner_it = automatic_context_owner.find(context);
      if (owner_it == automatic_context_owner.end())
            return false;
      if (owner_it->second != ctx_scope)
            return false;

      return context_on_list(ctx_scope->live_contexts, context);
}

static void warn_stacked_context_cycle_(const char*where, __vpiScope*ctx_scope,
                                        vvp_context_t start, vvp_context_t cur)
{
      static bool warned = false;
      if (warned)
            return;

      const char*scope_name = ctx_scope ? vpi_get_str(vpiFullName, ctx_scope) : 0;
      fprintf(stderr,
              "Warning: stacked automatic context cycle detected in %s"
              " (scope=%s start=%p repeated=%p; further similar warnings suppressed)\n",
              where ? where : "<unknown>",
              scope_name ? scope_name : "<unknown>",
              start, cur);
      warned = true;
}

template <typename MatchFn>
static vvp_context_t find_stacked_context_match_(vvp_context_t candidate,
                                                 __vpiScope*ctx_scope,
                                                 const char*where,
                                                 MatchFn match_fn)
{
      std::set<vvp_context_t> seen;
      for (vvp_context_t cur = candidate ; cur ; cur = vvp_get_stacked_context(cur)) {
            if (!seen.insert(cur).second) {
                  warn_stacked_context_cycle_(where, ctx_scope, candidate, cur);
                  return 0;
            }
            if (match_fn(cur))
                  return cur;
      }
      return 0;
}

static bool context_on_stacked_chain_(vvp_context_t head, vvp_context_t needle,
                                      __vpiScope*ctx_scope, const char*where)
{
      if (!(head && needle))
            return false;

      return find_stacked_context_match_(head, ctx_scope, where,
                  [needle](vvp_context_t cur) { return cur == needle; }) != 0;
}

static vvp_context_t remove_context_from_stacked_chain_(vvp_context_t head,
                                                        vvp_context_t needle)
{
      if (!(head && needle))
            return head;

      std::set<vvp_context_t> seen;
      vvp_context_t new_head = head;
      vvp_context_t prev = 0;
      vvp_context_t cur = head;

      while (cur) {
            if (!seen.insert(cur).second) {
                  warn_stacked_context_cycle_("remove_context_from_stacked_chain_",
                                              0, head, cur);
                  if (prev)
                        vvp_set_stacked_context(prev, 0);
                  else if (new_head == cur)
                        vvp_set_stacked_context(cur, 0);
                  break;
            }

            vvp_context_t next = vvp_get_stacked_context(cur);
            if (cur == needle) {
                  if (prev)
                        vvp_set_stacked_context(prev, next);
                  else
                        new_head = next;
                  vvp_set_stacked_context(cur, 0);
                  break;
            }

            prev = cur;
            cur = next;
      }

      return new_head;
}

static vvp_context_t first_live_stacked_context(vvp_context_t candidate, __vpiScope*ctx_scope)
{
      if (!candidate)
            return 0;

      bool prefer_scope = (ctx_scope && ctx_scope->is_automatic());

      if (!prefer_scope) {
            return find_stacked_context_match_(candidate, ctx_scope,
                        "first_live_stacked_context(any)",
                        [](vvp_context_t cur) { return context_live_in_owner(cur); });
      }

      vvp_context_t scoped_match = find_stacked_context_match_(candidate, ctx_scope,
                        "first_live_stacked_context(scope)",
                        [ctx_scope](vvp_context_t cur) {
                              return context_on_list(ctx_scope->live_contexts, cur);
                        });
      if (scoped_match)
            return scoped_match;

      return find_stacked_context_match_(candidate, ctx_scope,
                  "first_live_stacked_context(owner)",
                  [](vvp_context_t cur) {
                        map<vvp_context_t, __vpiScope*>::const_iterator owner_it =
                              automatic_context_owner.find(cur);
                        if (owner_it == automatic_context_owner.end())
                              return false;
                        __vpiScope*owner = owner_it->second;
                        return owner && owner->is_automatic()
                            && context_on_list(owner->live_contexts, cur);
                  });
}

static vvp_context_t first_live_context_for_scope(vvp_context_t candidate, __vpiScope*ctx_scope)
{
      if (!(candidate && ctx_scope && ctx_scope->is_automatic()))
            return 0;

      return find_stacked_context_match_(candidate, ctx_scope,
                  "first_live_context_for_scope",
                  [ctx_scope](vvp_context_t cur) {
                        map<vvp_context_t, __vpiScope*>::const_iterator owner_it =
                              automatic_context_owner.find(cur);
                        if (owner_it == automatic_context_owner.end())
                              return false;
                        if (owner_it->second != ctx_scope)
                              return false;
                        return context_on_list(ctx_scope->live_contexts, cur);
                  });
}

vvp_context_item_t vthread_get_wt_context_item(unsigned context_idx)
{
      static bool warned_null_wt_context = false;
      static bool warned_stale_wt_context = false;
      static bool warned_wt_fallback_to_rd = false;
      if (!running_thread) {
	    if (!warned_null_wt_context) {
		  fprintf(stderr, "Warning: vthread_get_wt_context_item called with null context;"
		                  " returning null item (further similar warnings suppressed)\n");
		  warned_null_wt_context = true;
	    }
	    return 0;
      }

      __vpiScope*ctx_scope = resolve_context_scope(running_thread->parent_scope);
      vvp_context_t use_context = 0;
      if (running_thread->wt_context
          && context_live_matches_scope_(running_thread->wt_context, ctx_scope))
            use_context = running_thread->wt_context;
      if (!use_context)
            use_context = first_live_stacked_context(running_thread->wt_context, ctx_scope);
      if (!use_context)
            use_context = first_live_stacked_context(running_thread->rd_context, ctx_scope);
      if (!use_context && running_thread->rd_context
          && context_live_matches_scope_(running_thread->rd_context, ctx_scope)) {
            if (!warned_wt_fallback_to_rd && auto_ctx_warn_enabled()) {
                  const char*scope_name = 0;
                  if (ctx_scope)
                        scope_name = vpi_get_str(vpiFullName, ctx_scope);
                  fprintf(stderr,
                          "Warning: vthread_get_wt_context_item using rd-context fallback"
                          " (scope=%s rd=%p wt=%p; further similar warnings suppressed)\n",
                          scope_name ? scope_name : "<unknown>",
                          running_thread->rd_context, running_thread->wt_context);
                  warned_wt_fallback_to_rd = true;
            }
            use_context = running_thread->rd_context;
      }

      if (!use_context) {
	    if (!warned_stale_wt_context && auto_ctx_warn_enabled()) {
		  const char*scope_name = 0;
		  if (ctx_scope)
			scope_name = vpi_get_str(vpiFullName, ctx_scope);
		  fprintf(stderr, "Warning: vthread_get_wt_context_item encountered stale context;"
		                  " returning null item (scope=%s wt=%p rd=%p; further similar warnings suppressed)\n",
			  scope_name ? scope_name : "<unknown>",
			  running_thread->wt_context, running_thread->rd_context);
		  warned_stale_wt_context = true;
	    }
	    return 0;
      }
      running_thread->wt_context = use_context;
      return vvp_get_context_item(use_context, context_idx);
}

vvp_context_item_t vthread_get_rd_context_item(unsigned context_idx)
{
      static bool warned_null_rd_context = false;
      static bool warned_stale_rd_context = false;
      static bool warned_rd_fallback_to_wt = false;
      if (!running_thread) {
	    if (!warned_null_rd_context) {
		  fprintf(stderr, "Warning: vthread_get_rd_context_item called with null context;"
		                  " returning null item (further similar warnings suppressed)\n");
		  warned_null_rd_context = true;
	    }
	    return 0;
      }

      __vpiScope*ctx_scope = resolve_context_scope(running_thread->parent_scope);
      vvp_context_t use_context = 0;
      vvp_context_t wt_scope_context =
            first_live_context_for_scope(running_thread->wt_context, ctx_scope);
      if (wt_scope_context)
            use_context = wt_scope_context;
      if (!use_context && running_thread->rd_context
          && context_live_matches_scope_(running_thread->rd_context, ctx_scope))
            use_context = running_thread->rd_context;
      if (!use_context)
            use_context = first_live_stacked_context(running_thread->rd_context, ctx_scope);
      if (!use_context && wt_scope_context)
            use_context = wt_scope_context;
      if (!use_context)
            use_context = first_live_stacked_context(running_thread->wt_context, ctx_scope);
      if (!use_context && running_thread->owned_context
          && context_live_matches_scope_(running_thread->owned_context, ctx_scope))
            use_context = running_thread->owned_context;
      if (!use_context && running_thread->wt_context
          && context_live_matches_scope_(running_thread->wt_context, ctx_scope)) {
            if (!warned_rd_fallback_to_wt && auto_ctx_warn_enabled()) {
                  const char*scope_name = 0;
                  if (ctx_scope)
                        scope_name = vpi_get_str(vpiFullName, ctx_scope);
                  fprintf(stderr,
                          "Warning: vthread_get_rd_context_item using wt-context fallback"
                          " (scope=%s rd=%p wt=%p; further similar warnings suppressed)\n",
                          scope_name ? scope_name : "<unknown>",
                          running_thread->rd_context, running_thread->wt_context);
                  warned_rd_fallback_to_wt = true;
            }
            use_context = running_thread->wt_context;
      }

      if (!use_context) {
	    if (!warned_stale_rd_context && auto_ctx_warn_enabled()) {
		  const char*scope_name = 0;
		  if (ctx_scope)
			scope_name = vpi_get_str(vpiFullName, ctx_scope);
		  fprintf(stderr, "Warning: vthread_get_rd_context_item encountered stale context;"
		                  " returning null item (scope=%s rd=%p wt=%p; further similar warnings suppressed)\n",
			  scope_name ? scope_name : "<unknown>",
			  running_thread->rd_context, running_thread->wt_context);
		  warned_stale_rd_context = true;
	    }
	    return 0;
      }
	      running_thread->rd_context = use_context;
	      return vvp_get_context_item(use_context, context_idx);
}

vvp_context_item_t vthread_get_rd_context_item_scoped(unsigned context_idx, __vpiScope*ctx_scope)
{
      static bool warned_scoped_context_miss = false;

      ctx_scope = resolve_context_scope(ctx_scope);
      if (!(ctx_scope && ctx_scope->is_automatic()))
            return vthread_get_rd_context_item(context_idx);
      if (!running_thread)
            return 0;

      const bool trace_this = load_str_trace_scope_match_(ctx_scope);

      if (running_thread->staged_alloc_rd_context
          && running_thread->staged_alloc_rd_scope == ctx_scope
          && context_live_matches_scope_(running_thread->staged_alloc_rd_context, ctx_scope)) {
            if (trace_this) {
                  fprintf(stderr,
                          "trace rd_scoped scope=%s source=staged rd=%p wt=%p owned=%p use=%p idx=%u\n",
                          scope_name_or_unknown_(ctx_scope),
                          running_thread->rd_context, running_thread->wt_context,
                          running_thread->owned_context,
                          running_thread->staged_alloc_rd_context, context_idx);
            }
            running_thread->rd_context = running_thread->staged_alloc_rd_context;
            return vvp_get_context_item(running_thread->staged_alloc_rd_context,
                                        context_idx);
      }

      /* Nested automatic blocks can stage writes into a fresh frame while
         keeping rd_context on the caller frame long enough to evaluate
         initializers. For scoped reads in the current automatic scope,
         prefer the live write-head first so subsequent loads see locals
         that were just initialized in the new frame. */
      vvp_context_t wt_context = first_live_context_for_scope(running_thread->wt_context, ctx_scope);
      vvp_context_t rd_context = first_live_context_for_scope(running_thread->rd_context, ctx_scope);
      vvp_context_t owned_context = first_live_context_for_scope(running_thread->owned_context, ctx_scope);
      vvp_context_t use_context = wt_context;
      const char*source = "wt";
      if (!use_context) {
            use_context = rd_context;
            source = "rd";
      }
      if (!use_context) {
            use_context = owned_context;
            source = "owned";
      }
      if (!use_context) {
            if (trace_this) {
                  fprintf(stderr,
                          "trace rd_scoped scope=%s source=miss rd=%p wt=%p owned=%p idx=%u\n",
                          scope_name_or_unknown_(ctx_scope),
                          running_thread->rd_context, running_thread->wt_context,
                          running_thread->owned_context, context_idx);
            }
            if (!warned_scoped_context_miss && auto_ctx_warn_enabled()) {
                  const char*scope_name = vpi_get_str(vpiFullName, ctx_scope);
                  fprintf(stderr,
                          "Warning: vthread_get_rd_context_item_scoped could not find"
                          " a live automatic context for scope=%s"
                          " (rd=%p wt=%p owned=%p; further similar warnings suppressed)\n",
                          scope_name ? scope_name : "<unknown>",
                          running_thread->rd_context, running_thread->wt_context,
                          running_thread->owned_context);
                  warned_scoped_context_miss = true;
            }
            return 0;
      }

      if (trace_this) {
            fprintf(stderr,
                    "trace rd_scoped scope=%s source=%s rd=%p wt=%p owned=%p"
                    " live_rd=%p live_wt=%p live_owned=%p use=%p idx=%u\n",
                    scope_name_or_unknown_(ctx_scope), source,
                    running_thread->rd_context, running_thread->wt_context,
                    running_thread->owned_context,
                    rd_context, wt_context, owned_context, use_context, context_idx);
      }
      /* Do NOT update rd_context here. After a function returns, do_join
         places the child frame at the head of the rd_context chain so the
         caller's copy-out code can read back inout/output parameters. If we
         advance rd_context when we find a parent-scope context deeper in the
         chain, we silently drop the child frame and subsequent loads from
         that frame return null. Each call to first_live_context_for_scope
         already walks the chain correctly, so the lazy advancement is both
         redundant and harmful. */
      return vvp_get_context_item(use_context, context_idx);
}

bool auto_ctx_warn_enabled()
{
      static int enabled = -1;
      if (enabled < 0) {
            const char*env = getenv("IVL_AUTO_CTX_WARN");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return enabled != 0;
}

vvp_context_t vthread_recover_context_for_scope(vvp_context_t candidate,
                                                __vpiScope*ctx_scope)
{
      ctx_scope = resolve_context_scope(ctx_scope);
      if (!(ctx_scope && ctx_scope->is_automatic())) {
            if (candidate && context_live_in_owner(candidate))
                  return candidate;
            if (!running_thread)
                  return 0;
            if (running_thread->wt_context
                && context_live_in_owner(running_thread->wt_context))
                  return running_thread->wt_context;
            if (running_thread->rd_context
                && context_live_in_owner(running_thread->rd_context))
                  return running_thread->rd_context;
            if (running_thread->owned_context
                && context_live_in_owner(running_thread->owned_context))
                  return running_thread->owned_context;
            return 0;
      }

      vvp_context_t use_context = 0;
      if (candidate && context_live_matches_scope_(candidate, ctx_scope))
            use_context = candidate;
      if (!use_context)
            use_context = first_live_context_for_scope(candidate, ctx_scope);
      if (!running_thread)
            return use_context;
      if (!use_context)
            use_context = first_live_context_for_scope(running_thread->wt_context, ctx_scope);
      if (!use_context)
            use_context = first_live_context_for_scope(running_thread->rd_context, ctx_scope);
      if (!use_context)
            use_context = first_live_context_for_scope(running_thread->owned_context, ctx_scope);
      return use_context;
}

static __vpiScope* resolve_context_scope(__vpiScope*scope);

static void sanitize_thread_contexts_(vthread_t thr, const char*reason)
{
      static bool warned = false;

      if (!thr)
            return;

      __vpiScope*ctx_scope = resolve_context_scope(thr->parent_scope);
      vvp_context_t clean_wt = 0;
      vvp_context_t clean_rd = 0;

      /* The write-context stack may legitimately carry staged automatic
         frames for upcoming calls in scopes other than the currently
         executing thread scope. Keep the top live write frame, regardless
         of owner scope, and only scope-filter the read side. */
      if (thr->wt_context && context_live_in_owner(thr->wt_context))
            clean_wt = thr->wt_context;
      else
            clean_wt = first_live_stacked_context(thr->wt_context, 0);

      if (thr->rd_context && context_live_matches_scope_(thr->rd_context, ctx_scope))
            clean_rd = thr->rd_context;
      else
            clean_rd = first_live_stacked_context(thr->rd_context, ctx_scope);

      if (!clean_rd && clean_wt && context_live_matches_scope_(clean_wt, ctx_scope))
            clean_rd = clean_wt;

      if (!warned && (clean_wt != thr->wt_context) && auto_ctx_warn_enabled()) {
            const char*scope_name = ctx_scope ? vpi_get_str(vpiFullName, ctx_scope) : 0;
            fprintf(stderr,
                    "Warning: sanitized thread automatic contexts after %s"
                    " (scope=%s wt=%p->%p rd=%p->%p; further similar warnings suppressed)\n",
                    reason ? reason : "<unknown>",
                    scope_name ? scope_name : "<unknown>",
                    thr->wt_context, clean_wt,
                    thr->rd_context, clean_rd);
            warned = true;
      }

      thr->wt_context = clean_wt;
      thr->rd_context = clean_rd;
}

static void release_owned_context_(vthread_t thr)
{
      if (!(thr && thr->owns_automatic_context && thr->owned_context))
            return;

      vvp_context_t owned = thr->owned_context;
      thr->owned_context = 0;
      thr->owns_automatic_context = 0;

      while (owned) {
            vvp_context_t next_owned = vvp_get_stacked_context(owned);
            __vpiScope*ctx_scope = resolve_context_scope(thr->parent_scope);
            map<vvp_context_t, __vpiScope*>::const_iterator owner_it =
                  automatic_context_owner.find(owned);
            if (owner_it != automatic_context_owner.end() && owner_it->second)
                  ctx_scope = owner_it->second;

            thr->wt_context = remove_context_from_stacked_chain_(thr->wt_context, owned);
            thr->rd_context = remove_context_from_stacked_chain_(thr->rd_context, owned);

            if (ctx_scope && ctx_scope->is_automatic())
                  vthread_free_context(owned, ctx_scope);
            owned = next_owned;
      }
}

static vvp_context_t ensure_write_context_(vthread_t thr, const char*where)
{
      static bool warned = false;
      static bool warned_owned_fallback = false;

      if (!thr)
            return 0;

      sanitize_thread_contexts_(thr, where ? where : "ensure-write-context");

      __vpiScope*ctx_scope = resolve_context_scope(thr->parent_scope);
      vvp_context_t use_context = 0;
      if (thr->wt_context && context_live_in_owner(thr->wt_context))
            use_context = thr->wt_context;
      if (!use_context)
            use_context = first_live_stacked_context(thr->wt_context, 0);
      if (!use_context)
            use_context = first_live_stacked_context(thr->rd_context, ctx_scope);
      if (!use_context && thr->owned_context
          && context_live_matches_scope_(thr->owned_context, ctx_scope)) {
            if (!warned_owned_fallback && auto_ctx_warn_enabled()) {
                  const char*scope_name = thr->parent_scope
                                        ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
                  fprintf(stderr,
                          "Warning: using owned automatic context as write context during %s"
                          " (scope=%s wt=%p rd=%p owned=%p; further similar warnings suppressed)\n",
                          where ? where : "<unknown>",
                          scope_name ? scope_name : "<unknown>",
                          thr->wt_context, thr->rd_context, thr->owned_context);
                  warned_owned_fallback = true;
            }
            use_context = thr->owned_context;
      }

      if (!thr->wt_context && use_context && thr->rd_context
          && context_live_matches_scope_(use_context, ctx_scope)) {
            if (!warned && auto_ctx_warn_enabled()) {
                  const char*scope_name = thr->parent_scope
                                        ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
                  fprintf(stderr,
                          "Warning: synchronized missing wt_context from live rd_context during %s"
                          " (scope=%s wt=%p rd=%p; further similar warnings suppressed)\n",
                          where ? where : "<unknown>",
                          scope_name ? scope_name : "<unknown>",
                          thr->wt_context, thr->rd_context);
                  warned = true;
            }
      }

      if (use_context) {
            thr->wt_context = use_context;
            if (!thr->rd_context && context_live_matches_scope_(use_context, ctx_scope))
                  thr->rd_context = use_context;
      }
      return use_context;
}

/*
 * %abs/wr
 */
bool of_ABS_WR(vthread_t thr, vvp_code_t)
{
      thr->push_real( fabs(thr->pop_real()) );
      return true;
}

bool of_ALLOC(vthread_t thr, vvp_code_t cp)
{
      __vpiScope*ctx_scope = resolve_context_scope(cp->scope);
      thr->staged_alloc_rd_context = 0;
      thr->staged_alloc_rd_scope = 0;
      if (ctx_scope && cp->scope && ctx_scope != cp->scope) {
            trace_context_event_("alloc-shared", thr, cp->scope, 0);
            return true;
      }
        /* Allocate a context. */
      vvp_context_t child_context = vthread_alloc_context(ctx_scope);

        /* If this context is being reused from the free list, scrub any
           stale references to the same storage out of the current thread's
           stacked chains before pushing it again. */
      thr->wt_context = remove_context_from_stacked_chain_(thr->wt_context,
                                                           child_context);
      thr->rd_context = remove_context_from_stacked_chain_(thr->rd_context,
                                                           child_context);

        /* Push the allocated context onto the write context stack. */
      vvp_set_stacked_context(child_context, thr->wt_context);
      thr->wt_context = child_context;

      /* %alloc stages a fresh automatic frame for the upcoming child
         call/block, but argument loads that follow still need to read
         from the caller frame. Only hand reads to the new frame if
         there is no live caller read context to preserve. */
      if (!(thr->rd_context && context_live_in_owner(thr->rd_context)))
            thr->rd_context = child_context;
      else if (ctx_scope && ctx_scope->is_automatic()) {
            vvp_context_t caller_rd =
                  first_live_context_for_scope(thr->rd_context, ctx_scope);
            if (caller_rd && caller_rd != child_context) {
                  thr->staged_alloc_rd_context = caller_rd;
                  thr->staged_alloc_rd_scope = ctx_scope;
            }
      }
      trace_context_event_("alloc", thr, ctx_scope, child_context);

      return true;
}

bool of_AND(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t valb = thr->pop_vec4();
      vvp_vector4_t&vala = thr->peek_vec4();
      assert(vala.size() == valb.size());
      vala &= valb;
      return true;
}

/*
 * This function must ALWAYS be called with the val set to the right
 * size, and initialized with BIT4_0 bits. Certain optimizations rely
 * on that.
 */
static void get_immediate_rval(vvp_code_t cp, vvp_vector4_t&val)
{
      uint32_t vala = cp->bit_idx[0];
      uint32_t valb = cp->bit_idx[1];
      unsigned wid  = cp->number;

      if (valb == 0) {
	      // Special case: if the value is zero, we are done
	      // before we start.
	    if (vala == 0) return;

	      // Special case: The value has no X/Z bits, so we can
	      // use the setarray method to write the value all at once.
	    unsigned use_wid = 8*sizeof(unsigned long);
	    if (wid < use_wid)
		  use_wid = wid;
	    unsigned long tmp[1];
	    tmp[0] = vala;
	    val.setarray(0, use_wid, tmp);
	    return;
      }

	// The immediate value can be values bigger then 32 bits, but
	// only if the high bits are zero. So at most we need to run
	// through the loop below 32 times. Maybe less, if the target
	// width is less. We don't have to do anything special on that
	// because vala/valb bits will shift away so (vala|valb) will
	// turn to zero at or before 32 shifts.

      for (unsigned idx = 0 ; idx < wid && (vala|valb) ; idx += 1) {
	    uint32_t ba = 0;
	      // Convert the vala/valb bits to a ba number that
	      // matches the encoding of the vvp_bit4_t enumeration.
	    ba = (valb & 1) << 1;
	    ba |= vala & 1;

	      // Note that the val is already pre-filled with BIT4_0
	      // bits, os we only need to set non-zero bit values.
	    if (ba) val.set_bit(idx, (vvp_bit4_t)ba);

	    vala >>= 1;
	    valb >>= 1;
      }
}

/*
 * %add
 *
 * Pop r,
 * Pop l,
 * Push l+r
 *
 * Pop 2 and push 1 is the same as pop 1 and replace the remaining top
 * of the stack with a new value. That is what we will do.
 */
bool of_ADD(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t r = thr->pop_vec4();
	// Rather then pop l, use it directly from the stack. When we
	// assign to 'l', that will edit the top of the stack, which
	// replaces a pop and a pull.
      vvp_vector4_t&l = thr->peek_vec4();

      l.add(r);

      return true;
}

/*
 * %addi <vala>, <valb>, <wid>
 *
 * Pop1 operand, get the other operand from the arguments, and push
 * the result.
 */
bool of_ADDI(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;

      vvp_vector4_t&l = thr->peek_vec4();

	// I expect that most of the bits of an immediate value are
	// going to be zero, so start the result vector with all zero
	// bits. Then we only need to replace the bits that are different.
      vvp_vector4_t r (wid, BIT4_0);
      get_immediate_rval (cp, r);

      l.add(r);

      return true;
}

/*
 * %add/wr
 */
bool of_ADD_WR(vthread_t thr, vvp_code_t)
{
      double r = thr->pop_real();
      double l = thr->pop_real();
      thr->push_real(l + r);
      return true;
}

/* %assign/ar <array>, <delay>
 * Generate an assignment event to a real array. Index register 3
 * contains the canonical address of the word in the memory. <delay>
 * is the delay in simulation time. <bit> is the index register
 * containing the real value.
 */
bool of_ASSIGN_AR(vthread_t thr, vvp_code_t cp)
{
      long adr = thr->words[3].w_int;
      unsigned delay = cp->bit_idx[0];
      double value = thr->pop_real();

      if (adr >= 0) {
	    vvp_array_t array = resolve_runtime_array_(cp, "%assign/ar");
	    if (array)
		  schedule_assign_array_word(array, adr, value, delay);
      }

      return true;
}

/* %assign/ar/d <array>, <delay_idx>
 * Generate an assignment event to a real array. Index register 3
 * contains the canonical address of the word in the memory.
 * <delay_idx> is the integer register that contains the delay value.
 */
bool of_ASSIGN_ARD(vthread_t thr, vvp_code_t cp)
{
      long adr = thr->words[3].w_int;
      double value = thr->pop_real();

      if (adr >= 0) {
	    vvp_time64_t delay = thr->words[cp->bit_idx[0]].w_uint;
	    vvp_array_t array = resolve_runtime_array_(cp, "%assign/ar/d");
	    if (array)
		  schedule_assign_array_word(array, adr, value, delay);
      }

      return true;
}

/* %assign/ar/e <array>
 * Generate an assignment event to a real array. Index register 3
 * contains the canonical address of the word in the memory. <bit>
 * is the index register containing the real value. The event
 * information is contained in the thread event control registers
 * and is set with %evctl.
 */
bool of_ASSIGN_ARE(vthread_t thr, vvp_code_t cp)
{
      long adr = thr->words[3].w_int;
      double value = thr->pop_real();

      if (adr >= 0) {
	    vvp_array_t array = resolve_runtime_array_(cp, "%assign/ar/e");
	    if (!array)
		  return true;
	    if (thr->ecount == 0) {
		  schedule_assign_array_word(array, adr, value, 0);
	    } else {
		  schedule_evctl(array, adr, value, thr->event,
		                 thr->ecount);
	    }
      }

      return true;
}

/*
 * %assign/vec4 <var>, <delay>
 */
bool of_ASSIGN_VEC4(vthread_t thr, vvp_code_t cp)
{
      vvp_net_ptr_t ptr (cp->net, 0);
      unsigned delay = cp->bit_idx[0];
      const vvp_vector4_t&val = thr->peek_vec4();

      schedule_assign_vector(ptr, 0, 0, val, delay);
      thr->pop_vec4(1);
      return true;
}

/*
 * Resizes a vector value for a partial assignment so that the value is fully
 * in-bounds of the target signal. Both `val` and `off` will be updated if
 * necessary.
 *
 * Returns false if the value is fully out-of-bounds and the assignment should
 * be skipped. Otherwise returns true.
 */
static bool resize_rval_vec(vvp_vector4_t &val, int64_t &off,
			    unsigned int sig_wid)
{
      unsigned int wid = val.size();

        // Fully in bounds, most likely case
      if (off >= 0 && (uint64_t)off + wid <= sig_wid)
	    return true;

      unsigned int base = 0;
      if (off >= 0) {
	      // Fully out-of-bounds
	    if ((uint64_t)off >= sig_wid)
		  return false;
      } else {
	      // Fully out-of-bounds */
	    if ((uint64_t)(-off) >= wid)
		  return false;

	      // If the index is below the vector, then only assign the high
	      // bits that overlap with the target
	    base = -off;
	    wid += off;
		off = 0;
      }

	// If the value is partly above the target, then only assign
	// the bits that overlap
      if ((uint64_t)off + wid > sig_wid)
	    wid = sig_wid - (uint64_t)off;

      val = val.subvalue(base, wid);

      return true;
}

/*
 * %assign/vec4/a/d <arr>, <offx>, <delx>
 */
bool of_ASSIGN_VEC4_A_D(vthread_t thr, vvp_code_t cp)
{
      int off_idx = cp->bit_idx[0];
      int del_idx = cp->bit_idx[1];
      int adr_idx = 3;

      int64_t  off = off_idx ? thr->words[off_idx].w_int : 0;
      vvp_time64_t del = del_idx? thr->words[del_idx].w_uint : 0;
      long     adr = thr->words[adr_idx].w_int;

      vvp_vector4_t val = thr->pop_vec4();

	// Abort if flags[4] is set. This can happen if the calculation
	// into an index register failed.
      if (thr->flags[4] == BIT4_1)
	    return true;

      vvp_array_t array = resolve_runtime_array_(cp, "%assign/vec4/a/d");
      if (!array)
	    return true;

      if (!resize_rval_vec(val, off, array->get_word_size()))
	    return true;

      schedule_assign_array_word(array, adr, off, val, del);

      return true;
}

/*
 * %assign/vec4/a/e <arr>, <offx>
 */
bool of_ASSIGN_VEC4_A_E(vthread_t thr, vvp_code_t cp)
{
      int off_idx = cp->bit_idx[0];
      int adr_idx = 3;

      int64_t  off = off_idx ? thr->words[off_idx].w_int : 0;
      long     adr = thr->words[adr_idx].w_int;

      vvp_vector4_t val = thr->pop_vec4();

	// Abort if flags[4] is set. This can happen if the calculation
	// into an index register failed.
      if (thr->flags[4] == BIT4_1)
	    return true;

      vvp_array_t array = resolve_runtime_array_(cp, "%assign/vec4/a/e");
      if (!array)
	    return true;

      if (!resize_rval_vec(val, off, array->get_word_size()))
	    return true;

      if (thr->ecount == 0) {
	    schedule_assign_array_word(array, adr, off, val, 0);
      } else {
	    schedule_evctl(array, adr, val, off, thr->event, thr->ecount);
      }

      return true;
}

/*
 * %assign/vec4/off/d <var>, <off>, <del>
 */
bool of_ASSIGN_VEC4_OFF_D(vthread_t thr, vvp_code_t cp)
{
      vvp_net_ptr_t ptr (cp->net, 0);
      unsigned off_index = cp->bit_idx[0];
      unsigned del_index = cp->bit_idx[1];
      vvp_vector4_t val = thr->pop_vec4();

      int64_t off = thr->words[off_index].w_int;
      vvp_time64_t del = thr->words[del_index].w_uint;

	// Abort if flags[4] is set. This can happen if the calculation
	// into an index register failed.
      if (thr->flags[4] == BIT4_1)
	    return true;

      vvp_signal_value*sig = dynamic_cast<vvp_signal_value*> (cp->net->fil);
      assert(sig);

      if (!resize_rval_vec(val, off, sig->value_size()))
	    return true;

      schedule_assign_vector(ptr, off, sig->value_size(), val, del);
      return true;
}

/*
 * %assign/vec4/off/e <var>, <off>
 */
bool of_ASSIGN_VEC4_OFF_E(vthread_t thr, vvp_code_t cp)
{
      vvp_net_ptr_t ptr (cp->net, 0);
      unsigned off_index = cp->bit_idx[0];
      vvp_vector4_t val = thr->pop_vec4();

      int64_t off = thr->words[off_index].w_int;

	// Abort if flags[4] is set. This can happen if the calculation
	// into an index register failed.
      if (thr->flags[4] == BIT4_1)
	    return true;

      vvp_signal_value*sig = dynamic_cast<vvp_signal_value*> (cp->net->fil);
      assert(sig);

      if (!resize_rval_vec(val, off, sig->value_size()))
	    return true;

      if (thr->ecount == 0) {
	    schedule_assign_vector(ptr, off, sig->value_size(), val, 0);
      } else {
	    schedule_evctl(ptr, val, off, sig->value_size(), thr->event, thr->ecount);
      }

      return true;
}

/*
 * %assign/vec4/d <var-label> <delay>
 */
bool of_ASSIGN_VEC4D(vthread_t thr, vvp_code_t cp)
{
      vvp_net_ptr_t ptr (cp->net, 0);
      unsigned del_index = cp->bit_idx[0];
      vvp_time64_t del = thr->words[del_index].w_int;

      vvp_vector4_t value = thr->pop_vec4();

      vvp_signal_value*sig = dynamic_cast<vvp_signal_value*> (cp->net->fil);
      assert(sig);

      schedule_assign_vector(ptr, 0, sig->value_size(), value, del);

      return true;
}

/*
 * %assign/vec4/e <var-label>
 */
bool of_ASSIGN_VEC4E(vthread_t thr, vvp_code_t cp)
{
      vvp_net_ptr_t ptr (cp->net, 0);
      vvp_vector4_t value = thr->pop_vec4();

      vvp_signal_value*sig = dynamic_cast<vvp_signal_value*> (cp->net->fil);
      assert(sig);

      if (thr->ecount == 0) {
	    schedule_assign_vector(ptr, 0, sig->value_size(), value, 0);
      } else {
	    schedule_evctl(ptr, value, 0, sig->value_size(), thr->event, thr->ecount);
      }

      return true;
}

/*
 * This is %assign/wr <vpi-label>, <delay>
 *
 * This assigns (after a delay) a value to a real variable. Use the
 * vpi_put_value function to do the assign, with the delay written
 * into the vpiInertialDelay carrying the desired delay.
 */
bool of_ASSIGN_WR(vthread_t thr, vvp_code_t cp)
{
      unsigned delay = cp->bit_idx[0];
      double value = thr->pop_real();
      s_vpi_time del;

      del.type = vpiSimTime;
      vpip_time_to_timestruct(&del, delay);

      __vpiHandle*tmp = cp->handle;

      t_vpi_value val;
      val.format = vpiRealVal;
      val.value.real = value;
      vpi_put_value(tmp, &val, &del, vpiTransportDelay);

      return true;
}

bool of_ASSIGN_WRD(vthread_t thr, vvp_code_t cp)
{
      vvp_time64_t delay = thr->words[cp->bit_idx[0]].w_uint;
      double value = thr->pop_real();
      s_vpi_time del;

      del.type = vpiSimTime;
      vpip_time_to_timestruct(&del, delay);

      __vpiHandle*tmp = cp->handle;

      t_vpi_value val;
      val.format = vpiRealVal;
      val.value.real = value;
      vpi_put_value(tmp, &val, &del, vpiTransportDelay);

      return true;
}

bool of_ASSIGN_WRE(vthread_t thr, vvp_code_t cp)
{
      assert(thr->event != 0);
      double value = thr->pop_real();
      __vpiHandle*tmp = cp->handle;

	// If the count is zero then just put the value.
      if (thr->ecount == 0) {
	    t_vpi_value val;

	    val.format = vpiRealVal;
	    val.value.real = value;
	    vpi_put_value(tmp, &val, 0, vpiNoDelay);
      } else {
	    schedule_evctl(tmp, value, thr->event, thr->ecount);
      }

      thr->event = 0;
      thr->ecount = 0;

      return true;
}

bool of_BLEND(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t vala = thr->pop_vec4();
      vvp_vector4_t valb = thr->pop_vec4();
      assert(vala.size() == valb.size());

      for (unsigned idx = 0 ; idx < vala.size() ; idx += 1) {
	    if (vala.value(idx) == valb.value(idx))
		  continue;

	    vala.set_bit(idx, BIT4_X);
      }

      thr->push_vec4(vala);
      return true;
}

bool of_BLEND_WR(vthread_t thr, vvp_code_t)
{
      double f = thr->pop_real();
      double t = thr->pop_real();
      thr->push_real((t == f) ? t : 0.0);
      return true;
}

bool of_BREAKPOINT(vthread_t, vvp_code_t)
{
      return true;
}

/*
 * %callf/void <code-label>, <scope-label>
 * Combine the %fork and %join steps for invoking a function.
 */
static int callf_depth = 0;
static bool warned_callf_self_recursion_fallback = false;
static bool warned_callf_depth_fallback = false;
static bool warned_callf_scope_cycle_fallback = false;
static bool warned_callf_child_reaped = false;
static bool warned_callf_self_callsite_fallback = false;
static bool warned_callf_rd_sync = false;
static bool warned_callf_child_not_ended = false;
static unsigned callf_target_trace_count = 0;
static unsigned callf_target_trace_limit = 256;
static std::vector<__vpiScope*> callf_scope_stack;
static std::map<const __vpiScope*, unsigned long> callf_scope_invocations;
static std::set<const __vpiScope*> callf_scope_hot_warned;
struct callf_edge_key_s {
      const __vpiScope*from;
      const __vpiScope*to;
      bool operator<(const callf_edge_key_s&that) const
      {
	    if (from < that.from) return true;
	    if (from > that.from) return false;
	    return to < that.to;
      }
};
static std::map<callf_edge_key_s, unsigned long> callf_edge_invocations;
static std::set<callf_edge_key_s> callf_edge_hot_warned;
struct callf_self_site_key_s {
      const __vpiScope*scope;
      const struct vvp_code_s*pc;
      bool operator<(const callf_self_site_key_s&that) const
      {
            if (scope < that.scope) return true;
            if (scope > that.scope) return false;
            return pc < that.pc;
      }
};
static std::map<callf_self_site_key_s, unsigned long> callf_self_site_invocations;
static std::map<const struct vvp_code_s*, unsigned long> callf_self_name_site_invocations;

static bool scope_has_own_automatic_context_(__vpiScope*scope)
{
      if (!(scope && scope->is_automatic()))
            return false;

      switch (scope->get_type_code()) {
          case vpiTask:
          case vpiFunction:
            return true;
          case vpiNamedBegin:
          case vpiNamedFork:
            return scope->nitem > 0;
          default:
            return false;
      }
}

static __vpiScope* resolve_context_scope(__vpiScope*scope)
{
      __vpiScope*orig_scope = scope;
      __vpiScope*ctx_scope = scope;

      while (ctx_scope && !ctx_scope->is_automatic()) {
            if (ctx_scope->scope && ctx_scope->scope->is_automatic()) {
                  ctx_scope = ctx_scope->scope;
                  break;
            }
            ctx_scope = ctx_scope->scope;
      }

      if (!ctx_scope)
            return orig_scope;

      while (!scope_has_own_automatic_context_(ctx_scope)
             && ctx_scope->scope && ctx_scope->scope->is_automatic())
            ctx_scope = ctx_scope->scope;
      return ctx_scope;
}

static bool flow_trace_enabled_()
{
      static int enabled = -1;
      if (enabled < 0) {
            const char*env = getenv("IVL_FLOW_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return enabled != 0;
}

static const char*scope_name_or_unknown_(__vpiScope*scope)
{
      const char*name = scope ? vpi_get_str(vpiFullName, scope) : 0;
      return name ? name : "<unknown>";
}

static bool scope_is_within_or_equal_(__vpiScope*scope, __vpiScope*ancestor)
{
      if (!(scope && ancestor))
            return false;

      for (__vpiScope*cur = scope ; cur ; cur = cur->scope) {
            if (cur == ancestor)
                  return true;
      }
      return false;
}

static bool scope_name_has_prefix_(const char*name, const char*prefix)
{
      if (!(name && prefix))
            return false;

      size_t plen = strlen(prefix);
      if (strncmp(name, prefix, plen) != 0)
            return false;
      return name[plen] == 0 || name[plen] == '.';
}

static bool scope_trace_enabled_(const char*env_name, const char*scope_name)
{
      const char*env = getenv(env_name);
      if (!(env && *env && scope_name))
            return false;

      if ((strcmp(env, "1") == 0) || (strcmp(env, "ALL") == 0)
          || (strcmp(env, "*") == 0) || (strcmp(env, "true") == 0))
            return true;

      return strstr(scope_name, env) != 0;
}

static bool step_trace_enabled_(const char*scope_name)
{
      return scope_trace_enabled_("IVL_STEP_TRACE", scope_name);
}

static bool function_runtime_trace_enabled_(const char*scope_name)
{
      return scope_trace_enabled_("IVL_FUNC_TRACE", scope_name);
}

static void dump_callf_tree_(vthread_t thr, unsigned depth)
{
      if (!thr)
            return;

      const char*scope_name = scope_name_or_unknown_(thr->parent_scope);
      const char*pc_op = thr->pc ? vvp_opcode_mnemonic(thr->pc->opcode) : "<nullpc>";
      const char*pause_op = thr->last_pause_pc
                          ? vvp_opcode_mnemonic(thr->last_pause_pc->opcode) : "<none>";
      fprintf(stderr,
              "trace callf-tree:%*s scope=%s thr=%p ended=%d disabled=%d scheduled=%d waiting=%d joining=%d detached=%d callf=%d children=%zu pc=%s pause=%s\n",
              depth * 2, "",
              scope_name, (void*)thr,
              thr->i_have_ended ? 1 : 0,
              thr->i_was_disabled ? 1 : 0,
              thr->is_scheduled ? 1 : 0,
              thr->waiting_for_event ? 1 : 0,
              thr->i_am_joining ? 1 : 0,
              thr->i_am_detached ? 1 : 0,
              thr->is_callf_child ? 1 : 0,
              thr->children.size(),
              pc_op ? pc_op : "<unknown>",
              pause_op ? pause_op : "<unknown>");

      for (set<vthread_t>::const_iterator it = thr->children.begin()
                 ; it != thr->children.end() ; ++it)
            dump_callf_tree_(*it, depth + 1);
}

static bool callf_dump_tree_enabled_(const char*caller_name, const char*child_name)
{
      const char*env = getenv("IVL_CALLF_DUMP_TREE");
      if (!(env && *env))
            return false;
      if ((strcmp(env, "1") == 0) || (strcmp(env, "ALL") == 0)
          || (strcmp(env, "*") == 0) || (strcmp(env, "true") == 0))
            return true;
      return (caller_name && strstr(caller_name, env))
          || (child_name && strstr(child_name, env));
}

static void resume_joining_parent_(vthread_t parent, vthread_t child)
{
      assert(parent);
      assert(child);

      parent->i_am_joining = 0;
      do_join(parent, child);

      if (parent->i_am_in_function && !parent->i_have_ended) {
            parent->is_scheduled = 1;
            vthread_run(parent);
            running_thread = child;
      } else if (!parent->i_have_ended) {
            schedule_vthread(parent, 0, true);
      }
}

static void trace_context_event_(const char*where, vthread_t thr,
                                 __vpiScope*extra_scope,
                                 vvp_context_t extra_context)
{
      const char*scope_name = scope_name_or_unknown_(thr ? thr->parent_scope : 0);
      const char*extra_name = scope_name_or_unknown_(extra_scope);
      const char*wt_owner_name = "<none>";
      const char*rd_owner_name = "<none>";
      if (!scope_trace_enabled_("IVL_CTX_TRACE", scope_name)
          && !scope_trace_enabled_("IVL_CTX_TRACE", extra_name))
            return;

      if (thr && thr->wt_context) {
            map<vvp_context_t, __vpiScope*>::const_iterator wt_owner_it =
                  automatic_context_owner.find(thr->wt_context);
            if (wt_owner_it != automatic_context_owner.end())
                  wt_owner_name = scope_name_or_unknown_(wt_owner_it->second);
      }
      if (thr && thr->rd_context) {
            map<vvp_context_t, __vpiScope*>::const_iterator rd_owner_it =
                  automatic_context_owner.find(thr->rd_context);
            if (rd_owner_it != automatic_context_owner.end())
                  rd_owner_name = scope_name_or_unknown_(rd_owner_it->second);
      }

      fprintf(stderr,
              "trace ctx: %s scope=%s wt=%p(%s) wt_next=%p rd=%p(%s) rd_next=%p owned=%p xfer=%p skip=%p extra_scope=%s extra_ctx=%p\n",
              where ? where : "<unknown>",
              scope_name,
              thr ? thr->wt_context : 0,
              wt_owner_name,
              (thr && thr->wt_context) ? vvp_get_stacked_context(thr->wt_context) : 0,
              thr ? thr->rd_context : 0,
              rd_owner_name,
              (thr && thr->rd_context) ? vvp_get_stacked_context(thr->rd_context) : 0,
              thr ? thr->owned_context : 0,
              thr ? thr->transferred_context : 0,
              thr ? thr->skip_free_context : 0,
              extra_name,
              extra_context);
}

static bool child_nonlocal_jump_matches_parent_(vthread_t thr, vthread_t child)
{
      if (!(thr && child))
            return false;
      if (!thr->i_am_in_function)
            return false;
      if (!(child->pending_nonlocal_jmp && child->nonlocal_target))
            return false;
      if (scope_is_within_or_equal_(child->nonlocal_origin_scope, thr->parent_scope))
            return true;

      const char*origin_name = child->nonlocal_origin_scope
                             ? vpi_get_str(vpiFullName, child->nonlocal_origin_scope) : 0;
      const char*parent_name = thr->parent_scope
                             ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
      if (scope_name_has_prefix_(origin_name, parent_name))
            return true;

      return false;
}

static bool callf_trace_scope_match_(const char*name)
{
      if (!name)
            return false;
      const char*env = getenv("IVL_CALLF_TRACE_TARGET");
      if (env && *env) {
            if (strcmp(env, "ALL") == 0 || strcmp(env, "*") == 0)
                  return true;
            if (strcmp(env, "1") != 0 && strcmp(env, "true") != 0
                && strstr(name, env) != 0)
                  return true;
      }
      return strstr(name, "uvm_object.new") != 0
          || strstr(name, "uvm_report_object.uvm_report_info") != 0
          || strstr(name, "uvm_cmdline_processor.get_arg_value") != 0;
}

static bool callf_trace_enabled_()
{
      static int enabled = -1;
      if (enabled < 0) {
            const char*env = getenv("IVL_CALLF_TRACE_TARGET");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
            const char*lim = getenv("IVL_CALLF_TRACE_LIMIT");
            if (lim && *lim) {
                  unsigned parsed = strtoul(lim, 0, 10);
                  if (parsed > 0)
                        callf_target_trace_limit = parsed;
            }
      }
      return enabled != 0;
}

static bool virtual_dispatch_trace_enabled_()
{
      static int enabled = -1;
      if (enabled < 0) {
            const char*env = getenv("IVL_VDISPATCH_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return enabled != 0;
}

static bool vpi_call_trace_enabled_()
{
      static int enabled = -1;
      if (enabled < 0) {
            const char*env = getenv("IVL_VPI_CALL_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return enabled != 0;
}

static bool vpi_call_trace_match_(const char*thr_scope, const char*tf_name,
                                  const char*call_scope)
{
      const char*target = getenv("IVL_VPI_CALL_TRACE_TARGET");
      if (!(target && *target))
            return true;

      if (thr_scope && strstr(thr_scope, target))
            return true;
      if (tf_name && strstr(tf_name, target))
            return true;
      if (call_scope && strstr(call_scope, target))
            return true;

      return false;
}

static vvp_context_t live_context_for_scope_on_thread_(vthread_t thr,
                                                       __vpiScope*scope)
{
      if (!(thr && scope && scope->is_automatic()))
            return 0;

      vvp_context_t use_context = first_live_context_for_scope(thr->wt_context, scope);
      if (!use_context)
            use_context = first_live_context_for_scope(thr->rd_context, scope);
      return use_context;
}

static bool build_dynamic_method_label_(const class_type*defn,
                                        const char*method_name,
                                        string&label)
{
      if (!(defn && method_name && *method_name))
            return false;

      label = "TD_";
      if (!defn->dispatch_prefix().empty()) {
            label += defn->dispatch_prefix();
      } else {
            if (!defn->scope_path().empty()) {
                  label += defn->scope_path();
                  label += ".";
            }
            label += defn->class_name();
      }
      label += ".";
      label += method_name;
      return true;
}

static bool copy_method_ports_to_context_(__vpiScope*src_scope, vthread_t src_thr,
                                          __vpiScope*dst_scope, vvp_context_t dst_context,
                                          bool copy_outputs)
{
      if (!(src_scope && src_thr && dst_scope && dst_context))
            return false;

      bool copied_any = false;
      std::set<std::string> seen_names;

      auto copy_named_item = [&](const std::string&name, vpiHandle src_item) {
            if (name.empty() || !src_item)
                  return;
            if ((name != "@") && name[0] == '$')
                  return;
            if (!seen_names.insert(name).second)
                  return;

            vpiHandle dst_item = lookup_scope_item_(dst_scope, name.c_str());
            if (!dst_item)
                  return;

            bool copied = copy_handle_value_to_context_(src_item, src_thr,
                                                        dst_item, dst_context);
            if (virtual_dispatch_trace_enabled_()) {
                  fprintf(stderr,
                          "vdispatch: copy-port scope=%s -> %s name=%s copied=%d outputs=%d\n",
                          scope_name_or_unknown_(src_scope),
                          scope_name_or_unknown_(dst_scope),
                          name.c_str(), copied ? 1 : 0, copy_outputs ? 1 : 0);
            }
            if (copied)
                  copied_any = true;
      };

      for (unsigned idx = 0; idx < src_scope->intern.size(); idx += 1) {
            vpiPortInfo*port = dynamic_cast<vpiPortInfo*>(src_scope->intern[idx]);
            if (!port)
                  continue;

            int dir = port->get_direction();
            if (copy_outputs) {
                  if (dir != vpiOutput && dir != vpiInout)
                        continue;
            } else {
                  if (dir != vpiInput && dir != vpiInout)
                        continue;
            }

            const char*name = vpi_get_str(vpiName, port);
            if (!name || strcmp(name, "@") == 0)
                  continue;
            std::string stable_name = name;

            vpiHandle src_item = lookup_scope_item_(src_scope, stable_name.c_str());
            if (!src_item)
                  src_item = lookup_scope_item_by_net_(src_scope, port->get_port());

            if (!src_item)
                  continue;
            copy_named_item(stable_name, src_item);
      }

      /* Some virtual override scopes do not surface the output formal as a
         vpiPortInfo even though the base scope does. Use the destination
         scope's declared output ports as a second pass so task outputs still
         mirror back into the caller frame after dynamic dispatch. */
      if (copy_outputs) {
            for (unsigned idx = 0; idx < dst_scope->intern.size(); idx += 1) {
                  vpiPortInfo*port = dynamic_cast<vpiPortInfo*>(dst_scope->intern[idx]);
                  if (!port)
                        continue;

                  int dir = port->get_direction();
                  if (dir != vpiOutput && dir != vpiInout)
                        continue;

                  const char*name = vpi_get_str(vpiName, port);
                  if (!name || strcmp(name, "@") == 0)
                        continue;

                  vpiHandle src_item = lookup_scope_item_(src_scope, name);
                  if (!src_item)
                        continue;

                  copy_named_item(name, src_item);
            }

            if (src_scope != dst_scope) {
                  vector<vpiHandle> src_items;
                  collect_scope_copy_items_(src_items, src_scope);
                  for (unsigned idx = 0; idx < src_items.size(); idx += 1) {
                        vpiHandle src_item = src_items[idx];
                        const char*name = vpi_get_str(vpiName, src_item);
                        if (!(name && *name) || strcmp(name, "@") == 0 || name[0] == '$')
                              continue;
                        std::string stable_name = name;

                        vpiHandle dst_item = lookup_scope_item_(dst_scope, stable_name.c_str());
                        if (!dst_item)
                              continue;
                        if (vpi_get(vpiType, src_item) != vpi_get(vpiType, dst_item))
                              continue;

                        copy_named_item(stable_name, src_item);
                  }
            }
      }

      /* Output mirroring should only copy declared output/inout ports.
         Pulling every signal-backed scope item here writes input formals and
         locals from the callee back into the caller frame on recursive
         automatic method returns. */
      if (copy_outputs)
            return copied_any;

      vector<vpiHandle> src_items;
      collect_scope_copy_items_(src_items, src_scope);
      for (unsigned idx = 0; idx < src_items.size(); idx += 1) {
            vpiHandle src_item = src_items[idx];
            const char*name = vpi_get_str(vpiName, src_item);
            copy_named_item(name ? std::string(name) : std::string(), src_item);
      }

      return copied_any;
}

static bool copy_call_inputs_to_allocated_context_(__vpiScope*scope, vthread_t thr,
                                                   vvp_context_t dst_context)
{
      if (!(scope && thr && dst_context))
            return false;

      __vpiScope*src_scope = scope;
      __vpiScope*src_ctx_scope = resolve_context_scope(src_scope);
      vvp_context_t save_wt_context = 0;
      vvp_context_t save_rd_context = 0;
      bool staged_src_context = false;
      const char*scope_name = scope_name_or_unknown_(scope);
      const char*thr_scope_name = scope_name_or_unknown_(thr ? thr->parent_scope : 0);
      const char*src_scope_name = scope_name_or_unknown_(src_scope);
      bool trace_inputs = scope_trace_enabled_("IVL_CTX_TRACE", scope_name)
                       || scope_trace_enabled_("IVL_CTX_TRACE", thr_scope_name);
      if (scope != thr->parent_scope && trace_inputs) {
            fprintf(stderr,
                    "trace ctx-input: scope-mismatch alloc_scope=%s src_scope=%s thr_scope=%s wt=%p rd=%p dst=%p\n",
                    scope_name, src_scope_name, thr_scope_name,
                    thr->wt_context, thr->rd_context, dst_context);
      }

      if (src_ctx_scope && src_ctx_scope->is_automatic()) {
            vvp_context_t src_context = live_context_for_scope_on_thread_(thr, src_ctx_scope);
            if (src_context) {
                  save_wt_context = thr->wt_context;
                  save_rd_context = thr->rd_context;
                  thr->wt_context = src_context;
                  thr->rd_context = src_context;
                  staged_src_context = true;
            }
      }

      bool copied_any = false;
      vpiHandle dst_this_item = lookup_scope_item_(scope, "@");
      vpiHandle src_this_item = lookup_scope_item_(src_scope, "@");
      if (!src_this_item)
            src_this_item = dst_this_item;
      if (dst_this_item && src_this_item) {
            vvp_object_t this_value;
            bool have_this_value = read_handle_object_in_thread_(src_this_item, thr, this_value);
            if (trace_inputs) {
                  fprintf(stderr,
                          "trace ctx-input: scope=%s src_scope=%s this_lookup=1 this_read=%d this=%s wt=%p rd=%p dst=%p\n",
                          scope_name,
                          src_scope_name,
                          have_this_value ? 1 : 0,
                          have_this_value ? object_trace_class_(this_value) : "<unreadable>",
                          thr->wt_context, thr->rd_context, dst_context);
            }
            if (copy_handle_value_to_context_(src_this_item, thr,
                                             dst_this_item, dst_context))
                  copied_any = true;
      } else if (trace_inputs) {
            fprintf(stderr,
                    "trace ctx-input: scope=%s src_scope=%s this_lookup=0 wt=%p rd=%p dst=%p\n",
                    scope_name, src_scope_name,
                    thr->wt_context, thr->rd_context, dst_context);
      }

      if (copy_method_ports_to_context_(src_scope, thr, scope, dst_context, false))
            copied_any = true;

      if (staged_src_context) {
            thr->wt_context = save_wt_context;
            thr->rd_context = save_rd_context;
      }

      return copied_any;
}

static bool stage_scope_reads_from_write_context_(vthread_t thr, __vpiScope*scope,
                                                  vvp_context_t&saved_rd_context)
{
      saved_rd_context = 0;

      if (!(thr && scope && scope->is_automatic()))
            return false;

      if (first_live_context_for_scope(thr->rd_context, scope))
            return false;

      if (!first_live_context_for_scope(thr->wt_context, scope))
            return false;

      saved_rd_context = thr->rd_context;
      thr->rd_context = thr->wt_context;
      return true;
}

static void restore_staged_scope_reads_(vthread_t thr, bool staged_reads,
                                        vvp_context_t saved_rd_context)
{
      if (staged_reads && thr)
            thr->rd_context = saved_rd_context;
}

static void mirror_automatic_call_outputs_if_needed_(vthread_t thr, vthread_t child)
{
      if (!(thr && child && child->parent_scope))
            return;
      if (!child->parent_scope->is_automatic())
            return;

      __vpiScope*scope = child->parent_scope;
      vvp_context_t src_context = live_context_for_scope_on_thread_(child, scope);
      if (!src_context)
            return;

      vvp_context_t dst_context = live_context_for_scope_on_thread_(thr, scope);
      if (!dst_context)
            return;

      vvp_context_t save_child_wt = child->wt_context;
      vvp_context_t save_child_rd = child->rd_context;
      child->wt_context = src_context;
      child->rd_context = src_context;

      /* Hidden "@" is the receiver/input object for methods and constructors.
         Copying it back from a same-scope automatic child clobbers the caller's
         live receiver on recursive calls, especially constructor->super/new
         paths. Mirror only declared outputs and the function return item. */
      copy_method_ports_to_context_(scope, child, scope, dst_context, true);

      if (scope->get_type_code() == vpiFunction) {
            const char*ret_name = scope->scope_name();
            if (ret_name) {
                  if (vpiHandle ret_item = lookup_scope_item_(scope, ret_name))
                        copy_handle_value_to_context_(ret_item, child, ret_item, dst_context);
            }
      }
      child->wt_context = save_child_wt;
      child->rd_context = save_child_rd;
}

static bool maybe_dispatch_virtual_method_call_(vthread_t thr, vvp_code_t cp,
                                                vthread_t child,
                                                bool mirror_object_return)
{
      if (!(thr && cp && cp->scope && child)) {
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: missing inputs thr=%p cp=%p scope=%p child=%p\n",
                          (void*)thr, (void*)cp, cp ? (void*)cp->scope : 0, (void*)child);
            return false;
      }

      __vpiScope*base_scope = cp->scope;
      __vpiScope*base_class_scope = base_scope->scope;
      const char*method_name = base_scope->scope_name();
      if (!(base_class_scope && method_name)) {
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: missing base class scope or method for %s\n",
                          scope_name_or_unknown_(base_scope));
            return false;
      }
      if ((strcmp(method_name, "new") == 0)
          || (strcmp(method_name, "new@") == 0)) {
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr,
                          "vdispatch: constructors are not virtual; keeping base scope %s\n",
                          scope_name_or_unknown_(base_scope));
            return false;
      }
      if (base_class_scope->get_type_code() != vpiClassTypespec) {
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: scope %s parent type %d is not class\n",
                          scope_name_or_unknown_(base_scope), base_class_scope->get_type_code());
            return false;
      }

      vvp_context_t saved_rd_context = 0;
      bool staged_reads = stage_scope_reads_from_write_context_(thr, base_scope,
                                                                saved_rd_context);
      if (staged_reads && virtual_dispatch_trace_enabled_()) {
            fprintf(stderr,
                    "vdispatch: staging reads from wt_context for base scope %s\n",
                    scope_name_or_unknown_(base_scope));
      }

      vpiHandle base_this = lookup_scope_item_(base_scope, "@");
      vvp_object_t this_obj;
      if (!read_handle_object_in_thread_(base_this, thr, this_obj)) {
            restore_staged_scope_reads_(thr, staged_reads, saved_rd_context);
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: failed to read this from %s on thread %p\n",
                          scope_name_or_unknown_(base_scope), (void*)thr);
            return false;
      }

      vvp_cobject*cobj = this_obj.peek<vvp_cobject>();
      if (!cobj) {
            restore_staged_scope_reads_(thr, staged_reads, saved_rd_context);
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: this is not a cobject for %s\n",
                          scope_name_or_unknown_(base_scope));
            return false;
      }

      const class_type*defn = cobj->get_defn();
      if (!defn) {
            restore_staged_scope_reads_(thr, staged_reads, saved_rd_context);
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: cobject missing defn for %s\n",
                          scope_name_or_unknown_(base_scope));
            return false;
      }

      string label;
      const class_type*dispatch_type = defn;
      if (!build_dynamic_method_label_(dispatch_type, method_name, label)) {
            restore_staged_scope_reads_(thr, staged_reads, saved_rd_context);
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: failed to build label for class=%s method=%s\n",
                          defn->class_name().c_str(), method_name);
            return false;
      }

      vvp_code_t override_pc = 0;
      __vpiScope*override_scope = 0;
      while (dispatch_type) {
            if (compile_lookup_code_scope(label.c_str(), &override_pc, &override_scope))
                  break;

            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: no override label %s\n", label.c_str());

            dispatch_type = dispatch_type->runtime_super();
            if (!(dispatch_type && build_dynamic_method_label_(dispatch_type, method_name, label)))
                  break;
      }

      if (!override_pc || !override_scope) {
            restore_staged_scope_reads_(thr, staged_reads, saved_rd_context);
            return false;
      }
      if (!(override_pc && override_scope && override_scope->is_automatic())) {
            restore_staged_scope_reads_(thr, staged_reads, saved_rd_context);
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: override %s invalid pc=%p scope=%p auto=%d\n",
                          label.c_str(), (void*)override_pc, (void*)override_scope,
                          override_scope ? override_scope->is_automatic() : 0);
            return false;
      }
      if (override_scope == base_scope) {
            restore_staged_scope_reads_(thr, staged_reads, saved_rd_context);
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: override %s resolves to base scope %s\n",
                          label.c_str(), scope_name_or_unknown_(base_scope));
            return false;
      }

      vpiHandle override_this = lookup_scope_item_(override_scope, "@");
      if (!override_this) {
            restore_staged_scope_reads_(thr, staged_reads, saved_rd_context);
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: override scope %s missing this handle\n",
                          scope_name_or_unknown_(override_scope));
            return false;
      }

      vvp_context_t override_context = vthread_alloc_context(override_scope);
      if (!write_handle_object_to_context_(override_this, this_obj, override_context)) {
            restore_staged_scope_reads_(thr, staged_reads, saved_rd_context);
            if (virtual_dispatch_trace_enabled_())
                  fprintf(stderr, "vdispatch: failed to seed this into override scope %s\n",
                          scope_name_or_unknown_(override_scope));
            vthread_free_context(override_context, override_scope);
            return false;
      }

      copy_method_ports_to_context_(base_scope, thr, override_scope,
                                    override_context, false);
      restore_staged_scope_reads_(thr, staged_reads, saved_rd_context);

      child->pc = override_pc;
      child->parent_scope = override_scope;
      child->wt_context = override_context;
      child->rd_context = override_context;
      child->owns_automatic_context = 1;
      child->owned_context = override_context;
      child->dynamic_dispatch_base_scope = base_scope;
      if (mirror_object_return)
            child->return_object_mirror_scope = base_scope;

      if (virtual_dispatch_trace_enabled_())
            fprintf(stderr, "vdispatch: %s -> %s via %s\n",
                    scope_name_or_unknown_(base_scope),
                    scope_name_or_unknown_(override_scope), label.c_str());

      return true;
}

static bool maybe_dispatch_uvm_object_wrapper_call_(vthread_t thr, vvp_code_t cp,
                                                    vthread_t child)
{
      if (!(thr && cp && cp->scope && child))
            return false;

      __vpiScope*base_scope = cp->scope;
      __vpiScope*base_class_scope = base_scope->scope;
      const char*method_name = base_scope->scope_name();
      if (!(base_class_scope && method_name))
            return false;
      if (strcmp(base_class_scope->scope_name(), "uvm_object_wrapper") != 0)
            return false;
      if (strcmp(method_name, "get_type_name") != 0
          && strcmp(method_name, "create_object") != 0
          && strcmp(method_name, "create_component") != 0)
            return false;
      return maybe_dispatch_virtual_method_call_(
            thr, cp, child,
            (strcmp(method_name, "create_object") == 0)
            || (strcmp(method_name, "create_component") == 0));
}

static void mirror_object_return_if_needed_(vthread_t thr, vthread_t child)
{
      if (!(thr && child && child->return_object_mirror_scope))
            return;

      __vpiScope*src_scope = child->parent_scope;
      __vpiScope*dst_scope = child->return_object_mirror_scope;
      const char*ret_name = src_scope ? src_scope->scope_name() : 0;
      if (!ret_name)
            return;

      vpiHandle src_item = lookup_scope_item_(src_scope, ret_name);
      vpiHandle dst_item = lookup_scope_item_(dst_scope, ret_name);
      vvp_context_t dst_context = live_context_for_scope_on_thread_(thr, dst_scope);
      if (!(src_item && dst_item && dst_context))
            return;

      vvp_object_t value;
      if (!read_handle_object_in_thread_(src_item, child, value))
            return;

      write_handle_object_to_context_(dst_item, value, dst_context);
}

static void mirror_dynamic_dispatch_outputs_if_needed_(vthread_t thr, vthread_t child)
{
      if (!(thr && child && child->dynamic_dispatch_base_scope))
            return;

      __vpiScope*src_scope = child->parent_scope;
      __vpiScope*dst_scope = child->dynamic_dispatch_base_scope;
      vvp_context_t dst_context = live_context_for_scope_on_thread_(thr, dst_scope);
      if (virtual_dispatch_trace_enabled_()) {
            fprintf(stderr,
                    "vdispatch: mirror outputs src=%s dst=%s dst_ctx=%p child_wt=%p child_rd=%p thr_wt=%p thr_rd=%p\n",
                    scope_name_or_unknown_(src_scope),
                    scope_name_or_unknown_(dst_scope),
                    dst_context,
                    child->wt_context, child->rd_context,
                    thr->wt_context, thr->rd_context);
      }
      if (!(src_scope && dst_scope && dst_context))
            return;

      copy_method_ports_to_context_(src_scope, child, dst_scope, dst_context, true);

      if (thr->parent_scope != dst_scope) {
            vector<vpiHandle> src_items;
            collect_scope_copy_items_(src_items, src_scope);
            for (unsigned idx = 0; idx < src_items.size(); idx += 1) {
                  vpiHandle src_item = src_items[idx];
                  const char*name = vpi_get_str(vpiName, src_item);
                  if (!(name && *name) || strcmp(name, "@") == 0 || name[0] == '$')
                        continue;
                  std::string stable_name = name;

                  vpiHandle dst_item = lookup_scope_item_(dst_scope, stable_name.c_str());
                  if (!dst_item)
                        continue;
                  if (vpi_get(vpiType, src_item) != vpi_get(vpiType, dst_item))
                        continue;

                  bool copied = copy_handle_value_to_context_(src_item, child,
                                                              dst_item, dst_context);
                  if (virtual_dispatch_trace_enabled_()) {
                        fprintf(stderr,
                                "vdispatch: mirror shared-name src=%s dst=%s name=%s copied=%d\n",
                                scope_name_or_unknown_(src_scope),
                                scope_name_or_unknown_(dst_scope),
                                stable_name.c_str(), copied ? 1 : 0);
                  }
            }
      }
}

static bool do_callf_void(vthread_t thr, vthread_t child)
{
      callf_depth++;
      __vpiScope*caller_scope = thr->parent_scope;
      __vpiScope*child_scope = child->parent_scope;
      __vpiScope*caller_ctx_scope = resolve_context_scope(caller_scope);
      __vpiScope*child_ctx_scope = resolve_context_scope(child_scope);
      if (thr->staged_alloc_rd_scope
          && child_ctx_scope == thr->staged_alloc_rd_scope) {
            thr->staged_alloc_rd_context = 0;
            thr->staged_alloc_rd_scope = 0;
      }
      vvp_code_t callsite_pc = thr->pc ? (thr->pc - 1) : 0;
      string caller_name_buf;
      string child_name_buf;
      const char*caller_name = 0;
      const char*child_name = 0;
      if (caller_scope) {
            const char*tmp = vpi_get_str(vpiFullName, caller_scope);
            if (tmp) {
                  caller_name_buf = tmp;
                  caller_name = caller_name_buf.c_str();
            }
      }
      if (child_scope) {
            const char*tmp = vpi_get_str(vpiFullName, child_scope);
            if (tmp) {
                  child_name_buf = tmp;
                  child_name = child_name_buf.c_str();
            }
      }
      if (callf_trace_enabled_()
          && callf_target_trace_count < callf_target_trace_limit
          && (callf_trace_scope_match_(caller_name) || callf_trace_scope_match_(child_name))) {
            fprintf(stderr,
                    "trace callf[%u] depth=%d caller=%s callee=%s pc=%p\n",
                    callf_target_trace_count + 1,
                    callf_depth,
                    caller_name ? caller_name : "<unknown>",
                    child_name ? child_name : "<unknown>",
                    (void*)callsite_pc);
            callf_target_trace_count += 1;
      }
      if (!thr->rd_context && thr->wt_context) {
            vvp_context_t caller_live = first_live_context_for_scope(thr->wt_context,
                                                                     caller_ctx_scope);
            bool warn_missing_caller_rd = caller_live != 0;
            if (warn_missing_caller_rd && !warned_callf_rd_sync) {
                  fprintf(stderr,
                          "Warning: callf entry synchronizing missing rd_context from wt_context"
                          " (scope=%s rd=%p wt=%p; further similar warnings suppressed)\n",
                          caller_name ? caller_name : "<unknown>",
                          thr->rd_context, thr->wt_context);
                  warned_callf_rd_sync = true;
            }
            thr->rd_context = thr->wt_context;
      }
      bool same_scope = (caller_scope && child_scope && caller_scope == child_scope);
      bool same_scope_name = (caller_name && child_name && strcmp(caller_name, child_name) == 0);
      if ((same_scope || same_scope_name) && callsite_pc) {
            unsigned long site_hits = 0;
            if (same_scope) {
                  callf_self_site_key_s self_key = { caller_scope, callsite_pc };
                  site_hits = ++callf_self_site_invocations[self_key];
            } else {
                  site_hits = ++callf_self_name_site_invocations[callsite_pc];
            }
            unsigned long site_limit = 256;
            if ((caller_name && strstr(caller_name, "uvm_object.new"))
                || (child_name && strstr(child_name, "uvm_object.new")))
                  site_limit = 64;
            if ((caller_name && strstr(caller_name, "uvm_cmdline_processor.get_arg_value"))
                || (child_name && strstr(child_name, "uvm_cmdline_processor.get_arg_value")))
                  site_limit = 2048;
            if ((caller_name && strstr(caller_name, "uvm_root.m_uvm_get_root"))
                || (child_name && strstr(child_name, "uvm_root.m_uvm_get_root")))
                  site_limit = 16384;
            if ((caller_name && strstr(caller_name, "uvm_report_object.uvm_report_info"))
                || (child_name && strstr(child_name, "uvm_report_object.uvm_report_info")))
                  site_limit = 8192;
            if ((caller_name && strstr(caller_name, "uvm_coreservice_t.get"))
                || (child_name && strstr(child_name, "uvm_coreservice_t.get"))
                || (caller_name && strstr(caller_name, "uvm_coreservice_t.get_root"))
                || (child_name && strstr(child_name, "uvm_coreservice_t.get_root")))
                  site_limit = 16384;
	            if (site_hits > site_limit) {
	                  if (!warned_callf_self_callsite_fallback) {
	                        fprintf(stderr,
	                                "%sWarning: callf self-recursion at %s callsite %p exceeded %lu hits (limit %lu);"
                                " using compile-progress return fallback (further similar warnings suppressed)\n",
                                thr->get_fileline().c_str(),
                                caller_name ? caller_name : "<unknown>",
                                (void*)callsite_pc, site_hits, site_limit);
                        warned_callf_self_callsite_fallback = true;
                  }
                  vthread_delete(child);
                  callf_depth--;
                  return true;
            }
      }
      callf_edge_key_s edge = { caller_scope, child_scope };
      unsigned long edge_invoc = ++callf_edge_invocations[edge];
      if ((edge_invoc >= 50000) && (callf_edge_hot_warned.count(edge) == 0)) {
	    const char*from_name = "<unknown>";
	    const char*to_name = "<unknown>";
	    if (caller_scope) {
		  const char*nm = vpi_get_str(vpiFullName, caller_scope);
		  if (nm) from_name = nm;
	    }
	    if (child_scope) {
		  const char*nm = vpi_get_str(vpiFullName, child_scope);
		  if (nm) to_name = nm;
	    }
	    fprintf(stderr, "Warning: hot callf edge %s -> %s has %lu invocations; potential zero-time liveness loop\n",
	            from_name, to_name, edge_invoc);
	    callf_edge_hot_warned.insert(edge);
      }
      unsigned long invoc = ++callf_scope_invocations[child_scope];
      if ((invoc >= 50000) && (callf_scope_hot_warned.count(child_scope) == 0)) {
	    const char*scope_name = "<unknown>";
	    if (child_scope) {
		  const char*nm = vpi_get_str(vpiFullName, child_scope);
		  if (nm) scope_name = nm;
	    }
	    fprintf(stderr, "Warning: hot callf scope %s has %lu invocations; potential zero-time liveness loop\n",
	            scope_name, invoc);
	    callf_scope_hot_warned.insert(child_scope);
      }
	      unsigned scope_hits = 0;
	      for (size_t idx = 0 ; idx < callf_scope_stack.size() ; idx += 1) {
		    if (callf_scope_stack[idx] == child_scope)
			  scope_hits += 1;
	      }
	      unsigned scope_limit = 4096;
	      if (child_name && strstr(child_name, "uvm_root.m_uvm_get_root"))
	            scope_limit = 16384;
	      if (scope_hits >= scope_limit) {
		    if (!warned_callf_scope_cycle_fallback) {
			  const char*scope_name = "<unknown>";
			  if (child_scope) {
				const char*nm = vpi_get_str(vpiFullName, child_scope);
				if (nm) scope_name = nm;
			  }
			  fprintf(stderr,
			          "Warning: callf scope-cycle detected at %s (hits=%u limit=%u);"
			          " using compile-progress return fallback (further similar warnings suppressed)\n",
			          scope_name, scope_hits, scope_limit);
			  warned_callf_scope_cycle_fallback = true;
		    }
		    vthread_delete(child);
		    callf_depth--;
	    return true;
      }

      callf_scope_stack.push_back(child_scope);
      unsigned depth_limit = 2048;
      if (child_name && strstr(child_name, "uvm_report_object.uvm_report_info"))
            depth_limit = 16384;
      if (child_name && strstr(child_name, "uvm_root.m_uvm_get_root"))
            depth_limit = 32768;
      if (child->parent_scope && thr->parent_scope
          && child->parent_scope == thr->parent_scope
          && callf_depth > depth_limit) {
	    if (!warned_callf_self_recursion_fallback) {
		  const char*scope_name = vpi_get_str(vpiFullName, child->parent_scope);
		  if (!scope_name) scope_name = "<unknown>";
		  fprintf(stderr, "Warning: callf recursion on %s exceeded %u frames;"
		          " using compile-progress return fallback (further similar warnings suppressed)\n",
		          scope_name, depth_limit);
		  warned_callf_self_recursion_fallback = true;
	    }
	    vthread_delete(child);
	    callf_scope_stack.pop_back();
	    callf_depth--;
	    return true;
      }
      if (callf_depth > 4096) {
	    if (!warned_callf_depth_fallback) {
		  const char*scope_name = "<unknown>";
		  if (child->parent_scope) {
			const char*nm = vpi_get_str(vpiFullName, child->parent_scope);
			if (nm) scope_name = nm;
		  }
		  fprintf(stderr, "%sWarning: do_callf_void recursion depth %d exceeded at %s;"
		          " using compile-progress return fallback (further similar warnings suppressed)\n",
		          thr->get_fileline().c_str(), callf_depth, scope_name);
		  warned_callf_depth_fallback = true;
	    }
	    vthread_delete(child);
	    callf_scope_stack.pop_back();
	    callf_depth--;
	    return true; /* pretend it returned normally */
      }

      if (child->parent_scope->is_automatic()) {
	      /* The context allocated for this child is the top entry
		 on the write context stack */
	    if (!child->wt_context)
		  child->wt_context = thr->wt_context;
	    if (!child->rd_context)
		  child->rd_context = child->wt_context;
            trace_context_event_("callf-child-bind", thr, child->parent_scope,
                                 child->wt_context);
      }

      child->is_callf_child = 1;

        // Mark the function thread as a direct child of the current thread.
      child->parent = thr;
      thr->children.insert(child);
        // This should be the only child
      assert(thr->children.size()==1);

        // Execute the function. This SHOULD run the function to completion,
        // but there are some exceptional situations where it won't.
      assert(child->parent_scope->get_type_code() == vpiFunction);
      child->is_scheduled = 1;
      child->i_am_in_function = 1;
      child->delay_delete = 1;
      vthread_run(child);
      running_thread = thr;
      {
            unsigned sync_resume_count = 0;
            const unsigned sync_resume_limit = 256;
            while (!child->i_have_ended
                   && child->parent == thr
                   && child->is_callf_child
                   && child->is_scheduled
                   && !child->waiting_for_event) {
                  if (sync_resume_count >= sync_resume_limit) {
                        static bool warned = false;
                        if (!warned) {
                              fprintf(stderr,
                                      "Warning: callf child exceeded synchronous resume budget"
                                      " (caller=%s callee=%s); leaving child scheduled"
                                      " (further similar warnings suppressed)\n",
                                      caller_name ? caller_name : "<unknown>",
                                      child_name ? child_name : "<unknown>");
                              warned = true;
                        }
                        break;
                  }
                  vthread_run(child);
                  running_thread = thr;
                  sync_resume_count += 1;
            }
      }
	      {
	            unsigned sync_drain_count = 0;
	            const unsigned sync_drain_limit = 256;
	            while (!child->i_have_ended
	                   && child->parent == thr
	                   && child->is_callf_child
	                   && !child->waiting_for_event) {
	                  vthread_t join_ready = 0;
	                  vthread_t drive = 0;
	                  vector<vthread_t> pending;
	                  pending.push_back(child);
	                  while (!pending.empty()) {
	                        vthread_t cur = pending.back();
	                        pending.pop_back();
	                        if (!cur)
	                              continue;
	                        if (cur->i_have_ended
	                            && !cur->i_am_detached
	                            && cur->parent && cur->parent->i_am_joining) {
	                              join_ready = cur;
	                              break;
	                        }
	                        if (!drive
	                            && !cur->i_have_ended
	                            && !cur->waiting_for_event
	                            && (cur->is_scheduled
	                                || cur->children.empty()))
	                              drive = cur;
	                        for (set<vthread_t>::const_iterator it = cur->children.begin()
	                                   ; it != cur->children.end() ; ++it)
	                              pending.push_back(*it);
	                  }
	                  if (join_ready) {
	                        resume_joining_parent_(join_ready->parent, join_ready);
	                        running_thread = thr;
	                        sync_drain_count += 1;
	                        continue;
	                  }
	                  if (!drive)
	                        break;
	                  if (sync_drain_count >= sync_drain_limit) {
	                        static bool warned = false;
	                        if (!warned) {
	                              fprintf(stderr,
	                                      "Warning: callf child exceeded synchronous drain budget"
                                      " (caller=%s callee=%s); leaving nested child tree active"
                                      " (further similar warnings suppressed)\n",
                                      caller_name ? caller_name : "<unknown>",
                                      child_name ? child_name : "<unknown>");
                              warned = true;
                        }
                        break;
                  }
	                  if (!drive->is_scheduled)
	                        drive->is_scheduled = 1;
	                  vthread_run(drive);
	                  running_thread = thr;
	                  sync_drain_count += 1;
	            }
      }
      {
            unsigned sync_resume_count = 0;
            const unsigned sync_resume_limit = 256;
            while (!child->i_have_ended
                   && child->parent == thr
                   && child->is_callf_child
                   && child->is_scheduled
                   && !child->waiting_for_event) {
                  if (sync_resume_count >= sync_resume_limit)
                        break;
                  vthread_run(child);
                  running_thread = thr;
                  sync_resume_count += 1;
            }
      }
      if (callf_trace_enabled_() && callf_trace_scope_match_(child_name)) {
            static unsigned post_trace_count = 0;
            if (post_trace_count < callf_target_trace_limit) {
                  const char*post_scope = child->parent_scope
                                        ? vpi_get_str(vpiFullName, child->parent_scope) : 0;
                  const char*post_op = child->pc ? vvp_opcode_mnemonic(child->pc->opcode) : "<nullpc>";
                  fprintf(stderr,
                          "trace callf-post[%u]: callee=%s scope=%s parent_ok=%d ended=%d joining=%d children=%zu pc=%s\n",
                          post_trace_count + 1,
                          child_name ? child_name : "<unknown>",
                          post_scope ? post_scope : "<unknown>",
                          child->parent == thr ? 1 : 0,
                          child->i_have_ended ? 1 : 0,
                          child->i_am_joining ? 1 : 0,
                          child->children.size(),
                          post_op);
                  post_trace_count += 1;
            }
      }

	      if (child->parent != thr) {
		    sanitize_thread_contexts_(thr, "callf child reap");
                    ensure_write_context_(thr, "callf-child-reap");
		    if (!warned_callf_child_reaped) {
			  fprintf(stderr, "Warning: callf child thread was reaped during execution;"
			          " treating call as completed (further similar warnings suppressed)\n");
			  warned_callf_child_reaped = true;
		    }
	    callf_scope_stack.pop_back();
	    callf_depth--;
	    return true;
      }

	      if (child->i_have_ended) {
		    trace_context_event_("callf-before-join", thr, child->parent_scope,
		                         child->wt_context);
		    do_join(thr, child);
                    if (!(child->parent_scope
                          && child->parent_scope->is_automatic())) {
                          ensure_write_context_(thr, "callf-join");
                    }
		    trace_context_event_("callf-after-join", thr, child->parent_scope,
		                         child->wt_context);
		    callf_scope_stack.pop_back();
		    callf_depth--;
		    return true;
	      } else {
		    static int trace_callf_wait = -1;
		    if (trace_callf_wait < 0) {
			  const char*env = getenv("IVL_CALLF_TRACE");
			  trace_callf_wait = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
		    }
		    if (trace_callf_wait) {
			  const char*wait_scope = "<unknown>";
			  const char*wait_op = "<nullpc>";
			  const char*pause_op = "<none>";
			  const char*nested_scope = "<none>";
			  const char*nested_op = "<none>";
			  int child_in_scope = 0;
			  if (child->parent_scope) {
				const char*nm = vpi_get_str(vpiFullName, child->parent_scope);
				if (nm) wait_scope = nm;
				child_in_scope = child->parent_scope->threads.count(child) ? 1 : 0;
			  }
			  if (child->pc)
				wait_op = vvp_opcode_mnemonic(child->pc->opcode);
			  if (child->last_pause_pc)
				pause_op = vvp_opcode_mnemonic(child->last_pause_pc->opcode);
			  if (!child->children.empty()) {
				vthread_t nested = *(child->children.begin());
				if (nested && nested->parent_scope) {
				      const char*nm = vpi_get_str(vpiFullName, nested->parent_scope);
				      if (nm) nested_scope = nm;
				}
				if (nested && nested->pc)
				      nested_op = vvp_opcode_mnemonic(nested->pc->opcode);
			  }
			  fprintf(stderr,
			          "trace callf-wait: caller=%s callee=%s wait_scope=%s wait_op=%s pause_op=%s nested=%s nested_op=%s joining=%d children=%zu ended=%d disabled=%d waiting=%d scheduled=%d in_scope=%d pc_null=%d\n",
			          caller_name ? caller_name : "<unknown>",
			          child_name ? child_name : "<unknown>",
			          wait_scope, wait_op, pause_op, nested_scope, nested_op,
			          child->i_am_joining ? 1 : 0, child->children.size(),
			          child->i_have_ended ? 1 : 0,
			          child->i_was_disabled ? 1 : 0,
			          child->waiting_for_event ? 1 : 0,
			          child->is_scheduled ? 1 : 0,
			          child_in_scope,
			          child->pc == codespace_null() ? 1 : 0);
		    }
		    if (!warned_callf_child_not_ended) {
			  fprintf(stderr,
				          "Warning: callf child did not end synchronously"
				          " (caller=%s callee=%s); caller entering join wait (further similar warnings suppressed)\n",
				          caller_name ? caller_name : "<unknown>",
				          child_name ? child_name : "<unknown>");
				  warned_callf_child_not_ended = true;
			    }
			    if (callf_dump_tree_enabled_(caller_name, child_name))
			          dump_callf_tree_(child, 0);
			    thr->i_am_joining = 1;
			    callf_scope_stack.pop_back();
			    callf_depth--;
			    return false;
		      }
}

bool of_CALLF_OBJ(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);
      maybe_dispatch_uvm_object_wrapper_call_(thr, cp, child);
      return do_callf_void(thr, child);

      // XXXX NOT IMPLEMENTED
}

bool of_CALLF_OBJ_V(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);
      maybe_dispatch_virtual_method_call_(thr, cp, child, true);
      return do_callf_void(thr, child);
}

bool of_CALLF_REAL(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);

	// This is the return value. Push a place-holder value. The function
	// will replace this with the actual value using a %ret/real instruction.
      thr->push_real(0.0);
      child->args_real.push_back(0);

      return do_callf_void(thr, child);
}

bool of_CALLF_REAL_V(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);
      maybe_dispatch_virtual_method_call_(thr, cp, child, false);

      thr->push_real(0.0);
      child->args_real.push_back(0);

      return do_callf_void(thr, child);
}

bool of_CALLF_STR(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);
      maybe_dispatch_uvm_object_wrapper_call_(thr, cp, child);

      thr->push_str("");
      child->args_str.push_back(0);

      return do_callf_void(thr, child);
}

bool of_CALLF_STR_V(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);
      maybe_dispatch_virtual_method_call_(thr, cp, child, false);

      thr->push_str("");
      child->args_str.push_back(0);

      return do_callf_void(thr, child);
}

bool of_CALLF_VEC4(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);

      vpiScopeFunction*scope_func = dynamic_cast<vpiScopeFunction*>(cp->scope);
      assert(scope_func);

	// This is the return value. Push a place-holder value. The function
	// will replace this with the actual value using a %ret/real instruction.
      thr->push_vec4(vvp_vector4_t(scope_func->get_func_width(), scope_func->get_func_init_val()));
      child->args_vec4.push_back(0);

      return do_callf_void(thr, child);
}

bool of_CALLF_VEC4_V(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);
      maybe_dispatch_virtual_method_call_(thr, cp, child, false);

      vpiScopeFunction*scope_func = dynamic_cast<vpiScopeFunction*>(cp->scope);
      assert(scope_func);

      thr->push_vec4(vvp_vector4_t(scope_func->get_func_width(), scope_func->get_func_init_val()));
      child->args_vec4.push_back(0);

      return do_callf_void(thr, child);
}

bool of_CALLF_VOID(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);
      return do_callf_void(thr, child);
}

bool of_CALLF_VOID_V(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);
      maybe_dispatch_virtual_method_call_(thr, cp, child, false);
      return do_callf_void(thr, child);
}

/*
 * The %cassign/link instruction connects a source node to a
 * destination node. The destination node must be a signal, as it is
 * marked with the source of the cassign so that it may later be
 * unlinked without specifically knowing the source that this
 * instruction used.
 */
bool of_CASSIGN_LINK(vthread_t, vvp_code_t cp)
{
      vvp_net_t*dst = cp->net;
      vvp_net_t*src = cp->net2;

      vvp_fun_signal_base*sig
	    = dynamic_cast<vvp_fun_signal_base*>(dst->fun);
      assert(sig);

	/* Any previous continuous assign should have been removed already. */
      assert(sig->cassign_link == 0);

      sig->cassign_link = src;

	/* Link the output of the src to the port[1] (the cassign
	   port) of the destination. */
      vvp_net_ptr_t dst_ptr (dst, 1);
      src->link(dst_ptr);

      return true;
}

/*
 * If there is an existing continuous assign linked to the destination
 * node, unlink it. This must be done before applying a new continuous
 * assign, otherwise the initial assigned value will be propagated to
 * any other nodes driven by the old continuous assign source.
 */
static void cassign_unlink(vvp_net_t*dst)
{
      vvp_fun_signal_base*sig
	    = dynamic_cast<vvp_fun_signal_base*>(dst->fun);
      assert(sig);

      if (sig->cassign_link == 0)
	    return;

      vvp_net_ptr_t tmp (dst, 1);
      sig->cassign_link->unlink(tmp);
      sig->cassign_link = 0;
}

/*
 * The %cassign/v instruction invokes a continuous assign of a
 * constant value to a signal. The instruction arguments are:
 *
 *     %cassign/vec4 <net>;
 *
 * Where the <net> is the net label assembled into a vvp_net pointer,
 * and the <base> and <wid> are stashed in the bit_idx array.
 *
 * This instruction writes vvp_vector4_t values to port-1 of the
 * target signal.
 */
bool of_CASSIGN_VEC4(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;
      vvp_vector4_t value = thr->pop_vec4();

	/* Remove any previous continuous assign to this net. */
      cassign_unlink(net);

	/* Set the value into port 1 of the destination. */
      vvp_net_ptr_t ptr (net, 1);
      vvp_send_vec4(ptr, value, 0);

      return true;
}

/*
 * %cassign/vec4/off <var>, <off>
 */
bool of_CASSIGN_VEC4_OFF(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;
      unsigned base_idx = cp->bit_idx[0];
      long base = thr->words[base_idx].w_int;
      vvp_vector4_t value = thr->pop_vec4();
      unsigned wid = value.size();

      if (thr->flags[4] == BIT4_1)
	    return true;

	/* Remove any previous continuous assign to this net. */
      cassign_unlink(net);

      vvp_signal_value*sig = dynamic_cast<vvp_signal_value*> (net->fil);
      assert(sig);

      if (base < 0 && (wid <= (unsigned)-base))
	    return true;

      if (base >= (long)sig->value_size())
	    return true;

      if (base < 0) {
	    wid -= (unsigned) -base;
	    base = 0;
	    value.resize(wid);
      }

      if (base+wid > sig->value_size()) {
	    wid = sig->value_size() - base;
	    value.resize(wid);
      }

      vvp_net_ptr_t ptr (net, 1);
      vvp_send_vec4_pv(ptr, value, base, sig->value_size(), 0);
      return true;
}

bool of_CASSIGN_WR(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net  = cp->net;
      double value = thr->pop_real();

	/* Remove any previous continuous assign to this net. */
      cassign_unlink(net);

	/* Set the value into port 1 of the destination. */
      vvp_net_ptr_t ptr (net, 1);
      vvp_send_real(ptr, value, 0);

      return true;
}

/*
 * %cast2
 */
bool of_CAST2(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t&val = thr->peek_vec4();
      unsigned wid = val.size();

      for (unsigned idx = 0 ; idx < wid ; idx += 1) {
	    switch (val.value(idx)) {
		case BIT4_0:
		case BIT4_1:
		  break;
		default:
		  val.set_bit(idx, BIT4_0);
		  break;
	    }
      }

      return true;
}

bool do_cast_vec_dar(vthread_t thr, vvp_code_t cp, bool as_vec4)
{
      unsigned wid = cp->number;

      vvp_object_t obj;
      thr->pop_object(obj);

      vvp_darray*darray = obj.peek<vvp_darray>();
      assert(darray);

      vvp_vector4_t vec = darray->get_bitstream(as_vec4);
      if (vec.size() != wid) {
	    cerr << thr->get_fileline()
	         << "VVP error: size mismatch when casting dynamic array to vector." << endl;
            thr->push_vec4(vvp_vector4_t(wid));
            schedule_stop(0);
            return false;
      }
      thr->push_vec4(vec);
      return true;
}

/*
 * %cast/vec2/dar <wid>
 */
bool of_CAST_VEC2_DAR(vthread_t thr, vvp_code_t cp)
{
      return do_cast_vec_dar(thr, cp, false);
}

/*
 * %cast/vec4/dar <wid>
 */
bool of_CAST_VEC4_DAR(vthread_t thr, vvp_code_t cp)
{
      return do_cast_vec_dar(thr, cp, true);
}

/*
 * %cast/vec4/str <wid>
 */
bool of_CAST_VEC4_STR(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;
      string str = thr->pop_str();

      vvp_vector4_t vec(wid, BIT4_0);
      const unsigned swid = 8 * str.length();
      const unsigned use_wid = (wid < swid)? wid : swid;
      const unsigned use_chars = (use_wid + 7) / 8;

      // SV compile-progress behavior: permit width/length mismatch by
      // truncating high-order bytes when target width is narrower and
      // zero-padding when target width is wider.
      unsigned sdx = 0;
      unsigned vdx = wid;
      while (vdx > 0 && sdx < use_chars) {
            char ch = str[sdx++];
            if (vdx < 8) {
                  for (unsigned bdx = 0; bdx < vdx; bdx += 1) {
                        if (ch & 1)
                              vec.set_bit(bdx, BIT4_1);
                        ch >>= 1;
                  }
                  vdx = 0;
                  break;
            }
            vdx -= 8;
            for (unsigned bdx = 0; bdx < 8; bdx += 1) {
                  if (ch & 1)
                        vec.set_bit(vdx+bdx, BIT4_1);
                  ch >>= 1;
            }
      }

      thr->push_vec4(vec);
      return true;
}

static void do_CMPE(vthread_t thr, const vvp_vector4_t&lval, const vvp_vector4_t&rval)
{
	// If the operands differ in width, zero-extend the narrower one.
	// This matches SystemVerilog semantics for unsigned equality comparison.
      if (rval.size() != lval.size()) {
	    unsigned wid = std::max(lval.size(), rval.size());
	    vvp_vector4_t ext_lval = lval;
	    vvp_vector4_t ext_rval = rval;
	    if (ext_lval.size() < wid) ext_lval.resize(wid, BIT4_0);
	    if (ext_rval.size() < wid) ext_rval.resize(wid, BIT4_0);
	    do_CMPE(thr, ext_lval, ext_rval);
	    return;
      }

      if (lval.has_xz() || rval.has_xz()) {

	    unsigned wid = lval.size();
	    vvp_bit4_t eq  = BIT4_1;
	    vvp_bit4_t eeq = BIT4_1;

	    for (unsigned idx = 0 ; idx < wid ; idx += 1) {
		  vvp_bit4_t lv = lval.value(idx);
		  vvp_bit4_t rv = rval.value(idx);

		  if (lv != rv)
			eeq = BIT4_0;

		  if (eq==BIT4_1 && (bit4_is_xz(lv) || bit4_is_xz(rv)))
			eq = BIT4_X;
		  if ((lv == BIT4_0) && (rv==BIT4_1))
			eq = BIT4_0;
		  if ((lv == BIT4_1) && (rv==BIT4_0))
			eq = BIT4_0;

		  if (eq == BIT4_0)
			break;
	    }

	    thr->flags[4] = eq;
	    thr->flags[6] = eeq;

      } else {
	      // If there are no XZ bits anywhere, then the results of
	      // == match the === test.
	    thr->flags[4] = thr->flags[6] = (lval.eeq(rval)? BIT4_1 : BIT4_0);
      }
}

/*
 *  %cmp/e
 *
 * Pop the operands from the stack, and do not replace them. The
 * results are written to flag bits:
 *
 *	4: eq  (equal)
 *
 *	6: eeq (case equal)
 */
bool of_CMPE(vthread_t thr, vvp_code_t)
{
	// We are going to pop these and push nothing in their
	// place, but for now it is more efficient to use a constant
	// reference. When we finish, pop the stack without copies.
      const vvp_vector4_t&rval = thr->peek_vec4(0);
      const vvp_vector4_t&lval = thr->peek_vec4(1);

      do_CMPE(thr, lval, rval);

      thr->pop_vec4(2);
      return true;
}

bool of_CMPNE(vthread_t thr, vvp_code_t)
{
	// We are going to pop these and push nothing in their
	// place, but for now it is more efficient to use a constant
	// reference. When we finish, pop the stack without copies.
      const vvp_vector4_t&rval = thr->peek_vec4(0);
      const vvp_vector4_t&lval = thr->peek_vec4(1);

      do_CMPE(thr, lval, rval);

      thr->flags[4] =  ~thr->flags[4];
      thr->flags[6] =  ~thr->flags[6];

      thr->pop_vec4(2);
      return true;
}

/*
 * %cmpi/e <vala>, <valb>, <wid>
 *
 * Pop1 operand, get the other operand from the arguments.
 */
bool of_CMPIE(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;

      const vvp_vector4_t&lval = thr->peek_vec4();

	// I expect that most of the bits of an immediate value are
	// going to be zero, so start the result vector with all zero
	// bits. Then we only need to replace the bits that are different.
      vvp_vector4_t rval (wid, BIT4_0);
      get_immediate_rval (cp, rval);

      do_CMPE(thr, lval, rval);

      thr->pop_vec4(1);
      return true;
}

bool of_CMPINE(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;

      const vvp_vector4_t&lval = thr->peek_vec4();

	// I expect that most of the bits of an immediate value are
	// going to be zero, so start the result vector with all zero
	// bits. Then we only need to replace the bits that are different.
      vvp_vector4_t rval (wid, BIT4_0);
      get_immediate_rval (cp, rval);

      do_CMPE(thr, lval, rval);

      thr->flags[4] =  ~thr->flags[4];
      thr->flags[6] =  ~thr->flags[6];

      thr->pop_vec4(1);
      return true;
}



static void do_CMPS(vthread_t thr, const vvp_vector4_t&lval, const vvp_vector4_t&rval)
{
      assert(rval.size() == lval.size());

	// If either value has XZ bits, then the eq and lt values are
	// known already to be X. Just calculate the eeq result as a
	// special case and short circuit the rest of the compare.
      if (lval.has_xz() || rval.has_xz()) {
	    thr->flags[4] = BIT4_X; // eq
	    thr->flags[5] = BIT4_X; // lt
	    thr->flags[6] = lval.eeq(rval)? BIT4_1 : BIT4_0;
	    return;
      }

	// Past this point, we know we are dealing only with fully
	// defined values.
      unsigned wid = lval.size();

      const vvp_bit4_t sig1 = lval.value(wid-1);
      const vvp_bit4_t sig2 = rval.value(wid-1);

	// If the lval is <0 and the rval is >=0, then we know the result.
      if ((sig1 == BIT4_1) && (sig2 == BIT4_0)) {
	    thr->flags[4] = BIT4_0; // eq;
	    thr->flags[5] = BIT4_1; // lt;
	    thr->flags[6] = BIT4_0; // eeq
	    return;
      }

	// If the lval is >=0 and the rval is <0, then we know the result.
      if ((sig1 == BIT4_0) && (sig2 == BIT4_1)) {
	    thr->flags[4] = BIT4_0; // eq;
	    thr->flags[5] = BIT4_0; // lt;
	    thr->flags[6] = BIT4_0; // eeq
	    return;
      }

	// The values have the same sign, so we have to look at the
	// actual value. Scan from the MSB down. As soon as we find a
	// bit that differs, we know the result.

      for (unsigned idx = 1 ;  idx < wid ;  idx += 1) {
	    vvp_bit4_t lv = lval.value(wid-1-idx);
	    vvp_bit4_t rv = rval.value(wid-1-idx);

	    if (lv == rv)
		  continue;

	    thr->flags[4] = BIT4_0; // eq
	    thr->flags[6] = BIT4_0; // eeq

	    if (lv==BIT4_0) {
		  thr->flags[5] = BIT4_1; // lt
	    } else {
		  thr->flags[5] = BIT4_0; // lt
	    }
	    return;
      }

	// If we survive the loop above, then the values must be equal.
      thr->flags[4] = BIT4_1;
      thr->flags[5] = BIT4_0;
      thr->flags[6] = BIT4_1;
}

/*
 *  %cmp/s
 *
 * Pop the operands from the stack, and do not replace them. The
 * results are written to flag bits:
 *
 *	4: eq  (equal)
 *	5: lt  (less than)
 *	6: eeq (case equal)
 */
bool of_CMPS(vthread_t thr, vvp_code_t)
{
	// We are going to pop these and push nothing in their
	// place, but for now it is more efficient to use a constant
	// reference. When we finish, pop the stack without copies.
      const vvp_vector4_t&rval = thr->peek_vec4(0);
      const vvp_vector4_t&lval = thr->peek_vec4(1);

      do_CMPS(thr, lval, rval);

      thr->pop_vec4(2);
      return true;
}

/*
 * %cmpi/s <vala>, <valb>, <wid>
 *
 * Pop1 operand, get the other operand from the arguments.
 */
bool of_CMPIS(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;

      const vvp_vector4_t&lval = thr->peek_vec4();

	// I expect that most of the bits of an immediate value are
	// going to be zero, so start the result vector with all zero
	// bits. Then we only need to replace the bits that are different.
      vvp_vector4_t rval (wid, BIT4_0);
      get_immediate_rval (cp, rval);

      do_CMPS(thr, lval, rval);

      thr->pop_vec4(1);
      return true;
}

/*
 * %cmp/obj
 * Compare two object handles on the object stack for pointer identity.
 * Pops both, sets flag 4 = 1 if equal (same object), 0 if not.
 */
bool of_CMPOBJ(vthread_t thr, vvp_code_t)
{
      vvp_object_t re;
      thr->pop_object(re);
      vvp_object_t le;
      thr->pop_object(le);

      bool eq = (le == re);
      thr->flags[4] = eq ? BIT4_1 : BIT4_0;

      const char*scope_name = scope_name_or_unknown_(thr->parent_scope);
      if (scope_trace_enabled_("IVL_CMPOBJ_TRACE", scope_name)) {
            fprintf(stderr,
                    "trace cmp_obj scope=%s le_nil=%d re_nil=%d eq=%d\n",
                    scope_name,
                    le.test_nil() ? 1 : 0,
                    re.test_nil() ? 1 : 0,
                    eq ? 1 : 0);
      }
      return true;
}

bool of_CMPSTR(vthread_t thr, vvp_code_t)
{
      string re = thr->pop_str();
      string le = thr->pop_str();

      int rc = strcmp(le.c_str(), re.c_str());

      vvp_bit4_t eq;
      vvp_bit4_t lt;

      if (rc == 0) {
	    eq = BIT4_1;
	    lt = BIT4_0;
      } else if (rc < 0) {
	    eq = BIT4_0;
	    lt = BIT4_1;
      } else {
	    eq = BIT4_0;
	    lt = BIT4_0;
      }

      thr->flags[4] = eq;
      thr->flags[5] = lt;

      return true;
}

static void of_CMPU_the_hard_way(vthread_t thr, unsigned wid,
				 const vvp_vector4_t&lval,
				 const vvp_vector4_t&rval)
{
      vvp_bit4_t eq = BIT4_1;
      vvp_bit4_t eeq = BIT4_1;

      for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {
	    vvp_bit4_t lv = lval.value(idx);
	    vvp_bit4_t rv = rval.value(idx);

	    if (lv != rv)
		  eeq = BIT4_0;

	    if (eq==BIT4_1 && (bit4_is_xz(lv) || bit4_is_xz(rv)))
		  eq = BIT4_X;
	    if ((lv == BIT4_0) && (rv==BIT4_1))
		  eq = BIT4_0;
	    if ((lv == BIT4_1) && (rv==BIT4_0))
		  eq = BIT4_0;

	    if (eq == BIT4_0)
		  break;

      }

      thr->flags[4] = eq;
      thr->flags[5] = BIT4_X;
      thr->flags[6] = eeq;
}

static void do_CMPU(vthread_t thr, const vvp_vector4_t&lval, const vvp_vector4_t&rval)
{
      vvp_bit4_t eq = BIT4_1;
      vvp_bit4_t lt = BIT4_0;

      if (rval.size() != lval.size()) {
	    cerr << thr->get_fileline()
	         << "VVP ERROR: %cmp/u operand width mismatch: lval=" << lval
		 << ", rval=" << rval << endl;
      }
      assert(rval.size() == lval.size());
      unsigned wid = lval.size();

      unsigned long*larray = lval.subarray(0,wid);
      if (larray == 0) return of_CMPU_the_hard_way(thr, wid, lval, rval);

      unsigned long*rarray = rval.subarray(0,wid);
      if (rarray == 0) {
	    delete[]larray;
	    return of_CMPU_the_hard_way(thr, wid, lval, rval);
      }

      unsigned words = (wid+CPU_WORD_BITS-1) / CPU_WORD_BITS;

      for (unsigned wdx = 0 ; wdx < words ; wdx += 1) {
	    if (larray[wdx] == rarray[wdx])
		  continue;

	    eq = BIT4_0;
	    if (larray[wdx] < rarray[wdx])
		  lt = BIT4_1;
	    else
		  lt = BIT4_0;
      }

      delete[]larray;
      delete[]rarray;

      thr->flags[4] = eq;
      thr->flags[5] = lt;
      thr->flags[6] = eq;
}

bool of_CMPU(vthread_t thr, vvp_code_t)
{

      const vvp_vector4_t&rval = thr->peek_vec4(0);
      const vvp_vector4_t&lval = thr->peek_vec4(1);

      do_CMPU(thr, lval, rval);

      thr->pop_vec4(2);
      return true;
}

/*
 * %cmpi/u <vala>, <valb>, <wid>
 *
 * Pop1 operand, get the other operand from the arguments.
 */
bool of_CMPIU(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;

      const vvp_vector4_t&lval = thr->peek_vec4();

	// I expect that most of the bits of an immediate value are
	// going to be zero, so start the result vector with all zero
	// bits. Then we only need to replace the bits that are different.
      vvp_vector4_t rval (wid, BIT4_0);
      get_immediate_rval (cp, rval);

      do_CMPU(thr, lval, rval);

      thr->pop_vec4(1);
      return true;
}


/*
 * %cmp/x
 */
bool of_CMPX(vthread_t thr, vvp_code_t)
{
      vvp_bit4_t eq = BIT4_1;
      vvp_vector4_t rval = thr->pop_vec4();
      vvp_vector4_t lval = thr->pop_vec4();

      assert(rval.size() == lval.size());
      unsigned wid = lval.size();

      for (unsigned idx = 0 ; idx < wid ; idx += 1) {
	    vvp_bit4_t lv = lval.value(idx);
	    vvp_bit4_t rv = rval.value(idx);
	    if ((lv != rv) && !bit4_is_xz(lv) && !bit4_is_xz(rv)) {
		  eq = BIT4_0;
		  break;
	    }
      }

      thr->flags[4] = eq;
      return true;
}

static void do_CMPWE(vthread_t thr, const vvp_vector4_t&lval, const vvp_vector4_t&rval)
{
      assert(rval.size() == lval.size());

      if (lval.has_xz() || rval.has_xz()) {

	    unsigned wid = lval.size();
	    vvp_bit4_t eq  = BIT4_1;

	    for (unsigned idx = 0 ; idx < wid ; idx += 1) {
		  vvp_bit4_t lv = lval.value(idx);
		  vvp_bit4_t rv = rval.value(idx);

		  if (bit4_is_xz(rv))
			continue;
		  if ((eq == BIT4_1) && bit4_is_xz(lv))
			eq = BIT4_X;
		  if ((lv == BIT4_0) && (rv==BIT4_1))
			eq = BIT4_0;
		  if ((lv == BIT4_1) && (rv==BIT4_0))
			eq = BIT4_0;

		  if (eq == BIT4_0)
			break;
	    }

	    thr->flags[4] = eq;

      } else {
	      // If there are no XZ bits anywhere, then the results of
	      // ==? match the === test.
	    thr->flags[4] = (lval.eeq(rval)? BIT4_1 : BIT4_0);
      }
}

bool of_CMPWE(vthread_t thr, vvp_code_t)
{
	// We are going to pop these and push nothing in their
	// place, but for now it is more efficient to use a constant
	// reference. When we finish, pop the stack without copies.
      const vvp_vector4_t&rval = thr->peek_vec4(0);
      const vvp_vector4_t&lval = thr->peek_vec4(1);

      do_CMPWE(thr, lval, rval);

      thr->pop_vec4(2);
      return true;
}

bool of_CMPWNE(vthread_t thr, vvp_code_t)
{
	// We are going to pop these and push nothing in their
	// place, but for now it is more efficient to use a constant
	// reference. When we finish, pop the stack without copies.
      const vvp_vector4_t&rval = thr->peek_vec4(0);
      const vvp_vector4_t&lval = thr->peek_vec4(1);

      do_CMPWE(thr, lval, rval);

      thr->flags[4] =  ~thr->flags[4];

      thr->pop_vec4(2);
      return true;
}

bool of_CMPWR(vthread_t thr, vvp_code_t)
{
      double r = thr->pop_real();
      double l = thr->pop_real();

      vvp_bit4_t eq = (l == r)? BIT4_1 : BIT4_0;
      vvp_bit4_t lt = (l <  r)? BIT4_1 : BIT4_0;

      thr->flags[4] = eq;
      thr->flags[5] = lt;

      return true;
}

/*
 * %cmp/z
 */
bool of_CMPZ(vthread_t thr, vvp_code_t)
{
      vvp_bit4_t eq = BIT4_1;
      vvp_vector4_t rval = thr->pop_vec4();
      vvp_vector4_t lval = thr->pop_vec4();

      assert(rval.size() == lval.size());
      unsigned wid = lval.size();

      for (unsigned idx = 0 ; idx < wid ; idx += 1) {
	    vvp_bit4_t lv = lval.value(idx);
	    vvp_bit4_t rv = rval.value(idx);
	    if ((lv != rv) && (rv != BIT4_Z) && (lv != BIT4_Z)) {
		  eq = BIT4_0;
		  break;
	    }
      }

      thr->flags[4] = eq;
      return true;
}

/*
 *  %concat/str;
 */
bool of_CONCAT_STR(vthread_t thr, vvp_code_t)
{
      string text = thr->pop_str();
      thr->peek_str(0).append(text);
      return true;
}

/*
 *  %concati/str <string>;
 */
bool of_CONCATI_STR(vthread_t thr, vvp_code_t cp)
{
      const char*text = cp->text;
      thr->peek_str(0).append(filter_string(text));
      return true;
}

/*
 * %concat/vec4
 */
bool of_CONCAT_VEC4(vthread_t thr, vvp_code_t)
{
      const vvp_vector4_t&lsb = thr->peek_vec4(0);
      const vvp_vector4_t&msb = thr->peek_vec4(1);

	// The result is the size of the top two vectors in the stack.
      vvp_vector4_t res (msb.size() + lsb.size(), BIT4_X);

	// Build up the result.
      res.set_vec(0, lsb);
      res.set_vec(lsb.size(), msb);

	// Rearrange the stack to pop the inputs and push the
	// result. Do that by actually popping only 1 stack position
	// and replacing the new top with the new value.
      thr->pop_vec4(1);
      thr->peek_vec4() = res;

      return true;
}

/*
 * %concati/vec4 <vala>, <valb>, <wid>
 *
 * Concat the immediate value to the LOW bits of the concatenation.
 * Get the HIGH bits from the top of the vec4 stack.
 */
bool of_CONCATI_VEC4(vthread_t thr, vvp_code_t cp)
{
      unsigned wid  = cp->number;

      vvp_vector4_t&msb = thr->peek_vec4();

	// I expect that most of the bits of an immediate value are
	// going to be zero, so start the result vector with all zero
	// bits. Then we only need to replace the bits that are different.
      vvp_vector4_t lsb (wid, BIT4_0);
      get_immediate_rval (cp, lsb);

      vvp_vector4_t res (msb.size()+lsb.size(), BIT4_X);
      res.set_vec(0, lsb);
      res.set_vec(lsb.size(), msb);

      msb = res;
      return true;
}

/*
 * %cvt/rv
 */
bool of_CVT_RV(vthread_t thr, vvp_code_t)
{
      double val;
      vvp_vector4_t val4 = thr->pop_vec4();
      vector4_to_value(val4, val, false);
      thr->push_real(val);
      return true;
}

/*
 * %cvt/rv/s
 */
bool of_CVT_RV_S(vthread_t thr, vvp_code_t)
{
      double val;
      vvp_vector4_t val4 = thr->pop_vec4();
      vector4_to_value(val4, val, true);
      thr->push_real(val);
      return true;
}

/*
 * %cvt/sr <idx>
 * Pop the top value from the real stack, convert it to a 64bit signed
 * and save it to the indexed register.
 */
bool of_CVT_SR(vthread_t thr, vvp_code_t cp)
{
      double r = thr->pop_real();
      thr->words[cp->bit_idx[0]].w_int = i64round(r);

      return true;
}

/*
 * %cvt/ur <idx>
 */
bool of_CVT_UR(vthread_t thr, vvp_code_t cp)
{
      double r = thr->pop_real();
      thr->words[cp->bit_idx[0]].w_uint = vlg_round_to_u64(r);

      return true;
}

/*
 * %cvt/vr <wid>
 */
bool of_CVT_VR(vthread_t thr, vvp_code_t cp)
{
      double r = thr->pop_real();
      unsigned wid = cp->number;

      vvp_vector4_t tmp(wid, r);
      thr->push_vec4(tmp);
      return true;
}

/*
 * This implements the %deassign instruction. All we do is write a
 * long(1) to port-3 of the addressed net. This turns off an active
 * continuous assign activated by %cassign/v
 */
bool of_DEASSIGN(vthread_t, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;
      unsigned base  = cp->bit_idx[0];
      unsigned width = cp->bit_idx[1];

      vvp_signal_value*fil = dynamic_cast<vvp_signal_value*> (net->fil);
      assert(fil);
      vvp_fun_signal_vec*sig = dynamic_cast<vvp_fun_signal_vec*>(net->fun);
      assert(sig);

      if (base >= fil->value_size()) return true;
      if (base+width > fil->value_size()) width = fil->value_size() - base;

      bool full_sig = base == 0 && width == fil->value_size();

	// This is the net that is forcing me...
      if (vvp_net_t*src = sig->cassign_link) {
	    if (! full_sig) {
		  fprintf(stderr, "Sorry: when a signal is assigning a "
		          "register, I cannot deassign part of it.\n");
		  exit(1);
	    }
	      // And this is the pointer to be removed.
	    vvp_net_ptr_t dst_ptr (net, 1);
	    src->unlink(dst_ptr);
	    sig->cassign_link = 0;
      }

	/* Do we release all or part of the net? */
      if (full_sig) {
	    sig->deassign();
      } else {
	    sig->deassign_pv(base, width);
      }

      return true;
}

bool of_DEASSIGN_WR(vthread_t, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;

      vvp_fun_signal_real*sig = dynamic_cast<vvp_fun_signal_real*>(net->fun);
      assert(sig);

	// This is the net that is forcing me...
      if (vvp_net_t*src = sig->cassign_link) {
	      // And this is the pointer to be removed.
	    vvp_net_ptr_t dst_ptr (net, 1);
	    src->unlink(dst_ptr);
	    sig->cassign_link = 0;
      }

      sig->deassign();

      return true;
}

/*
 * %debug/thr
 */
bool of_DEBUG_THR(vthread_t thr, vvp_code_t cp)
{
      const char*text = cp->text;
      thr->debug_dump(cerr, text);
      return true;
}

/*
 * The delay takes two 32bit numbers to make up a 64bit time.
 *
 *   %delay <low>, <hig>
 */
bool of_DELAY(vthread_t thr, vvp_code_t cp)
{
      vvp_time64_t low = cp->bit_idx[0];
      vvp_time64_t hig = cp->bit_idx[1];

      vvp_time64_t delay = (hig << 32) | low;

      if (schedule_finished())
            return false;

      if (delay == 0) schedule_inactive(thr);
      else schedule_vthread(thr, delay);
      return false;
}

bool of_DELAYX(vthread_t thr, vvp_code_t cp)
{
      vvp_time64_t delay;

      assert(cp->number < vthread_s::WORDS_COUNT);
      delay = thr->words[cp->number].w_uint;
      if (schedule_finished())
            return false;
      if (delay == 0) schedule_inactive(thr);
      else schedule_vthread(thr, delay);
      return false;
}

bool of_DELETE_ELEM(vthread_t thr, vvp_code_t cp)
{
	      vvp_net_t*net = cp->net;

      int64_t idx_val = thr->words[3].w_int;
      if (thr->flags[4] == BIT4_1) {
	    cerr << thr->get_fileline()
	         << "Warning: skipping queue delete() with undefined index."
	         << endl;
	    return true;
      }
      if (idx_val < 0) {
	    cerr << thr->get_fileline()
	         << "Warning: skipping queue delete() with negative index."
	         << endl;
	    return true;
      }
      size_t idx = idx_val;

      vvp_fun_signal_object*obj = dynamic_cast<vvp_fun_signal_object*> (net->fun);
      assert(obj);

      vvp_queue*queue = obj->get_object().peek<vvp_queue>();
      if (queue == 0) {
	    cerr << thr->get_fileline()
	         << "Warning: skipping delete(" << idx
	         << ") on empty queue." << endl;
      } else {
	    size_t size = queue->get_size();
	    if (idx >= size) {
		  cerr << thr->get_fileline()
		       << "Warning: skipping out of range delete(" << idx
		       << ") on queue of size " << size << "." << endl;
	    } else {
		  queue->erase(idx);
                  notify_mutated_object_signal_(thr, net, "queue-delete-elem");
	    }
      }

	      return true;
}

/* %delete/o/elem
 *
 * Delete a queue element from an object receiver popped from the object stack.
 */
bool of_DELETE_O_ELEM(vthread_t thr, vvp_code_t)
{
	      int64_t idx_val = thr->words[3].w_int;
	      if (thr->flags[4] == BIT4_1) {
		    cerr << thr->get_fileline()
		         << "Warning: skipping queue delete() with undefined index."
		         << endl;
		    return true;
	      }
	      if (idx_val < 0) {
		    cerr << thr->get_fileline()
		         << "Warning: skipping queue delete() with negative index."
		         << endl;
		    return true;
	      }
	      size_t idx = idx_val;

	      vvp_object_t recv, root_obj;
            vvp_net_t*root_net = 0;
	      vvp_queue*queue = pop_queue_receiver_<vvp_queue>(thr, recv, root_net, root_obj);
	      if (!queue)
		    return true;

	      size_t size = queue->get_size();
	      if (idx >= size) {
		    cerr << thr->get_fileline()
		         << "Warning: skipping out of range delete(" << idx
		         << ") on queue of size " << size << "." << endl;
	      } else {
		    queue->erase(idx);
                  notify_mutated_object_root_(thr, recv, root_net, root_obj,
                                              "queue-delete-o-elem");
	      }

	      return true;
}

/* %delete/obj <label>
 *
 * This operator works by assigning a nil to the target object. This
 * causes any value that might be there to be garbage collected, thus
 * deleting the object.
 */
bool of_DELETE_OBJ(vthread_t thr, vvp_code_t cp)
{
	/* set the value into port 0 of the destination. */
      vvp_net_ptr_t ptr (cp->net, 0);
      vvp_send_object(ptr, vvp_object_t(), ensure_write_context_(thr, "clear-obj"));

	      return true;
}

/* %delete/o/obj
 *
 * Clear a queue receiver popped from the object stack.
 */
bool of_DELETE_O_OBJ(vthread_t thr, vvp_code_t)
{
	      vvp_object_t recv, root_obj;
            vvp_net_t*root_net = 0;
	      vvp_queue*queue = pop_queue_receiver_<vvp_queue>(thr, recv, root_net, root_obj);
	      if (!queue)
		    return true;

	      queue->erase_tail(0);
            notify_mutated_object_root_(thr, recv, root_net, root_obj,
                                        "queue-delete-o-obj");
	      return true;
}

/* %delete/tail <label>, idx
 *
 * Remove all elements after the one specified.
 */
bool of_DELETE_TAIL(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;

      vvp_fun_signal_object*obj = dynamic_cast<vvp_fun_signal_object*> (net->fun);
      assert(obj);

      vvp_queue*queue = obj->get_object().peek<vvp_queue>();
      assert(queue);

      unsigned idx = thr->words[cp->bit_idx[0]].w_int;
      queue->erase_tail(idx);
      notify_mutated_object_signal_(thr, net, "queue-delete-tail");

      return true;
}

static bool do_disable(vthread_t thr, vthread_t match)
{
      bool flag = false;

      if (vvp_process*proc = thr->process_obj_.peek<vvp_process>()) {
	    if (thr->i_have_ended && !thr->i_was_disabled)
		  proc->mark_finished();
	    else
		  proc->mark_killed();
      }

	/* Pull the target thread out of its scope if needed. */
      thr->parent_scope->threads.erase(thr);

	/* Turn the thread off by setting is program counter to
	   zero and setting an OFF bit. */
      thr->pc = codespace_null();
      thr->i_was_disabled = 1;
      thr->i_have_ended = 1;

	/* Turn off all the children of the thread. Simulate a %join
	   for as many times as needed to clear the results of all the
	   %forks that this thread has done. */
      while (! thr->children.empty()) {

	    vthread_t tmp = *(thr->children.begin());
	    assert(tmp);
	    assert(tmp->parent == thr);
	    thr->i_am_joining = 0;
	    if (do_disable(tmp, match))
		  flag = true;

	    vthread_reap(tmp);
      }

      vthread_t parent = thr->parent;
      if (parent && parent->i_am_joining) {
	      // If a parent is waiting in a %join, wake it up. Note
	      // that it is possible to be waiting in a %join yet
	      // already scheduled if multiple child threads are
	      // ending. So check if the thread is already scheduled
	      // before scheduling it again.
	    resume_joining_parent_(parent, thr);

      } else if (parent) {
	      /* If the parent is yet to %join me, let its %join
		 do the reaping. */
	      //assert(tmp->is_scheduled == 0);

      } else {
	      /* No parent at all. Goodbye. */
	    vthread_reap(thr);
      }

      return flag || (thr == match);
}

/*
 * Implement the %disable instruction by scanning the target scope for
 * all the target threads. Kill the target threads and wake up a
 * parent that is attempting a %join.
 */
bool of_DISABLE(vthread_t thr, vvp_code_t cp)
{
      __vpiScope*scope = static_cast<__vpiScope*>(cp->handle);

      bool disabled_myself_flag = false;

      while (! scope->threads.empty()) {
	    set<vthread_t>::iterator cur = scope->threads.begin();

	    if (do_disable(*cur, thr))
		  disabled_myself_flag = true;
      }

      return ! disabled_myself_flag;
}

/*
 * Similar to `of_DISABLE`. But will only disable a single thread of the
 * specified scope. The disabled thread will be the thread closest to the
 * current thread in thread hierarchy. This can either be the current thread,
 * either the thread itself or one of its parents.
 * This is used for SystemVerilog flow control instructions like `return`,
 * `continue` and `break`.
 */

bool of_DISABLE_FLOW(vthread_t thr, vvp_code_t cp)
{
      const __vpiScope*scope = static_cast<__vpiScope*>(cp->handle);
      vthread_t cur = thr;
      vthread_t name_match = 0;
      const char*target_name = scope ? vpi_get_str(vpiFullName, (vpiHandle)scope) : 0;
      const char*thr_name = thr && thr->parent_scope
                          ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;

      while (cur && cur->parent_scope != scope) {
            if (!name_match && target_name && cur->parent_scope) {
                  const char*cur_name = vpi_get_str(vpiFullName, cur->parent_scope);
                  if (cur_name && (strcmp(cur_name, target_name) == 0))
                        name_match = cur;
            }
            cur = cur->parent;
      }

      if (!cur && name_match)
            cur = name_match;

      if (!cur) {
            static bool warned = false;
            if (!warned) {
                  fprintf(stderr,
                          "Warning: %%disable/flow target scope not found; "
                          "disabling current thread as fallback "
                          "(further similar warnings suppressed)\n");
                  warned = true;
            }
            cur = thr;
      }

      if (flow_trace_enabled_()) {
            static unsigned trace_count = 0;
            if (trace_count < 256) {
                  const char*sel_name = cur && cur->parent_scope
                                      ? vpi_get_str(vpiFullName, cur->parent_scope) : 0;
                  fprintf(stderr,
                          "trace flow: disable/flow src=%s target=%s selected=%s self=%d\n",
                          thr_name ? thr_name : "<unknown>",
                          target_name ? target_name : "<unknown>",
                          sel_name ? sel_name : "<unknown>",
                          (cur == thr) ? 1 : 0);
                  trace_count += 1;
            }
      }

      return !do_disable(cur, thr);
}

bool of_DISABLE_FLOW_CHILD(vthread_t thr, vvp_code_t cp)
{
      const __vpiScope*scope = static_cast<__vpiScope*>(cp->handle);
      vthread_t cur = thr;
      vthread_t child = 0;
      const char*target_name = scope ? vpi_get_str(vpiFullName, (vpiHandle)scope) : 0;
      const char*thr_name = thr && thr->parent_scope
                          ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;

      while (cur && cur->parent_scope != scope) {
            child = cur;
            cur = cur->parent;
      }

      if (!child) {
            static bool warned = false;
            if (!warned) {
                  fprintf(stderr,
                          "Warning: %%disable/flow/child target scope not found; "
                          "disabling current thread as fallback "
                          "(further similar warnings suppressed)\n");
                  warned = true;
            }
            child = thr;
      }

      if (flow_trace_enabled_()) {
            static unsigned trace_count = 0;
            if (trace_count < 256) {
                  const char*sel_name = child && child->parent_scope
                                      ? vpi_get_str(vpiFullName, child->parent_scope) : 0;
                  fprintf(stderr,
                          "trace flow: disable/flow/child src=%s target=%s selected=%s self=%d\n",
                          thr_name ? thr_name : "<unknown>",
                          target_name ? target_name : "<unknown>",
                          sel_name ? sel_name : "<unknown>",
                          (child == thr) ? 1 : 0);
                  trace_count += 1;
            }
      }

      return !do_disable(child, thr);
}

/*
 * Implement the %disable/fork (SystemVerilog) instruction by disabling
 * all the detached children of the given thread.
 */
bool of_DISABLE_FORK(vthread_t thr, vvp_code_t)
{
	/* If a %disable/fork is being executed then the parent thread
	 * cannot be waiting in a join. */
      assert(! thr->i_am_joining);

	/* There should be no active children to disable. */
      assert(thr->children.empty());

	/* Disable any detached children. */
      while (! thr->detached_children.empty()) {
	    vthread_t child = *(thr->detached_children.begin());
	    assert(child);
	    assert(child->parent == thr);
	      /* Disabling the children can never match the parent thread. */
	    bool res = do_disable(child, thr);
	    assert(! res);
	    vthread_reap(child);
      }

      return true;
}

/*
 * This function divides a 2-word number {high, a} by a 1-word
 * number. Assume that high < b.
 */
static unsigned long divide2words(unsigned long a, unsigned long b,
				  unsigned long high)
{
      unsigned long result = 0;
      while (high > 0) {
	    unsigned long tmp_result = ULONG_MAX / b;
	    unsigned long remain = ULONG_MAX % b;

	    remain += 1;
	    if (remain >= b) {
		  remain -= b;
		  tmp_result += 1;
	    }

	      // Now 0x1_0...0 = b*tmp_result + remain
	      // high*0x1_0...0 = high*(b*tmp_result + remain)
	      // high*0x1_0...0 = high*b*tmp_result + high*remain

	      // We know that high*0x1_0...0 >= high*b*tmp_result, and
	      // we know that high*0x1_0...0 > high*remain. Use
	      // high*remain as the remainder for another iteration,
	      // and add tmp_result*high into the current estimate of
	      // the result.
	    result += tmp_result * high;

	      // The new iteration starts with high*remain + a.
	    remain = multiply_with_carry(high, remain, high);
	    a += remain;
            if(a < remain)
              high += 1;

	      // Now result*b + {high,a} == the input {high,a}. It is
	      // possible that the new high >= 1. If so, it will
	      // certainly be less than high from the previous
	      // iteration. Do another iteration and it will shrink,
	      // eventually to 0.
      }

	// high is now 0, so a is the remaining remainder, so we can
	// finish off the integer divide with a simple a/b.

      return result + a/b;
}

static unsigned long* divide_bits(unsigned long*ap, const unsigned long*bp, unsigned wid)
{
	// Do all our work a cpu-word at a time. The "words" variable
	// is the number of words of the wid.
      unsigned words = (wid+CPU_WORD_BITS-1) / CPU_WORD_BITS;

      unsigned btop = words-1;
      while (btop > 0 && bp[btop] == 0)
	    btop -= 1;

	// Detect divide by 0, and exit.
      if (btop==0 && bp[0]==0)
	    return 0;

	// The result array will eventually accumulate the result. The
	// diff array is a difference that we use in the intermediate.
      unsigned long*diff  = new unsigned long[words];
      unsigned long*result= new unsigned long[words];
      for (unsigned idx = 0 ; idx < words ; idx += 1)
	    result[idx] = 0;

      for (unsigned cur = words-btop ; cur > 0 ; cur -= 1) {
	    unsigned cur_ptr = cur-1;
	    unsigned long cur_res;
	    if (ap[cur_ptr+btop] >= bp[btop]) {
		  unsigned long high = 0;
		  if (cur_ptr+btop+1 < words)
			high = ap[cur_ptr+btop+1];
		  cur_res = divide2words(ap[cur_ptr+btop], bp[btop], high);

	    } else if (cur_ptr+btop+1 >= words) {
		  continue;

	    } else if (ap[cur_ptr+btop+1] == 0) {
		  continue;

	    } else {
		  cur_res = divide2words(ap[cur_ptr+btop], bp[btop],
					 ap[cur_ptr+btop+1]);
	    }

	      // cur_res is a guesstimate of the result this far. It
	      // may be 1 too big. (But it will also be >0) Try it,
	      // and if the difference comes out negative, then adjust.

	      // diff = (bp * cur_res)  << cur_ptr;
	    multiply_array_imm(diff+cur_ptr, bp, words-cur_ptr, cur_res);
	      // ap -= diff
	    unsigned long carry = 1;
	    for (unsigned idx = cur_ptr ; idx < words ; idx += 1)
		  ap[idx] = add_with_carry(ap[idx], ~diff[idx], carry);

	      // ap has the diff subtracted out of it. If cur_res was
	      // too large, then ap will turn negative. (We easily
	      // tell that ap turned negative by looking at
	      // carry&1. If it is 0, then it is *negative*.) In that
	      // case, we know that cur_res was too large by 1. Correct by
	      // adding 1b back in and reducing cur_res.
	    if ((carry&1) == 0) {
		    // Keep adding b back in until the remainder
		    // becomes positive again.
		  do {
			cur_res -= 1;
			carry = 0;
			for (unsigned idx = cur_ptr ; idx < words ; idx += 1)
			      ap[idx] = add_with_carry(ap[idx], bp[idx-cur_ptr], carry);
		  } while (carry == 0);
	    }

	    result[cur_ptr] = cur_res;
      }

	// Now ap contains the remainder and result contains the
	// desired result. We should find that:
	//  input-a = bp * result + ap;

      delete[]diff;
      return result;
}

/*
 * %div
 */
bool of_DIV(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t valb = thr->pop_vec4();
      vvp_vector4_t vala = thr->pop_vec4();

      assert(vala.size()== valb.size());
      unsigned wid = vala.size();

      unsigned long*ap = vala.subarray(0, wid);
      if (ap == 0) {
	    vvp_vector4_t tmp(wid, BIT4_X);
	    thr->push_vec4(tmp);
	    return true;
      }

      unsigned long*bp = valb.subarray(0, wid);
      if (bp == 0) {
	    delete[]ap;
	    vvp_vector4_t tmp(wid, BIT4_X);
	    thr->push_vec4(tmp);
	    return true;
      }

	// If the value fits in a single CPU word, then do it the easy way.
      if (wid <= CPU_WORD_BITS) {
	    if (bp[0] == 0) {
		  vvp_vector4_t tmp(wid, BIT4_X);
		  thr->push_vec4(tmp);
	    } else {
		  ap[0] /= bp[0];
		  vala.setarray(0, wid, ap);
		  thr->push_vec4(vala);
	    }
	    delete[]ap;
	    delete[]bp;
	    return true;
      }

      unsigned long*result = divide_bits(ap, bp, wid);
      if (result == 0) {
	    delete[]ap;
	    delete[]bp;
	    vvp_vector4_t tmp(wid, BIT4_X);
	    thr->push_vec4(tmp);
	    return true;
      }

	// Now ap contains the remainder and result contains the
	// desired result. We should find that:
	//  input-a = bp * result + ap;

      vala.setarray(0, wid, result);
      thr->push_vec4(vala);
      delete[]ap;
      delete[]bp;
      delete[]result;

      return true;
}


static void negate_words(unsigned long*val, unsigned words)
{
      unsigned long carry = 1;
      for (unsigned idx = 0 ; idx < words ; idx += 1)
	    val[idx] = add_with_carry(0, ~val[idx], carry);
}

/*
 * %div/s
 */
bool of_DIV_S(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t valb = thr->pop_vec4();
      vvp_vector4_t&vala = thr->peek_vec4();

      assert(vala.size()== valb.size());
      unsigned wid = vala.size();
      unsigned words = (wid + CPU_WORD_BITS - 1) / CPU_WORD_BITS;

	// Get the values, left in right, in binary form. If there is
	// a problem with either (caused by an X or Z bit) then we
	// know right away that the entire result is X.
      unsigned long*ap = vala.subarray(0, wid);
      if (ap == 0) {
	    vvp_vector4_t tmp(wid, BIT4_X);
	    vala = tmp;
	    return true;
      }

      unsigned long*bp = valb.subarray(0, wid);
      if (bp == 0) {
	    delete[]ap;
	    vvp_vector4_t tmp(wid, BIT4_X);
	    vala = tmp;
	    return true;
      }

	// Sign extend the bits in the array to fill out the array.
      unsigned long sign_mask = 0;
      if (unsigned long sign_bits = (words*CPU_WORD_BITS) - wid) {
	    sign_mask = -1UL << (CPU_WORD_BITS-sign_bits);
	    if (ap[words-1] & (sign_mask>>1))
		  ap[words-1] |= sign_mask;
	    if (bp[words-1] & (sign_mask>>1))
		  bp[words-1] |= sign_mask;
      }

	// If the value fits in a single word, then use the native divide.
      if (wid <= CPU_WORD_BITS) {
	    if (bp[0] == 0) {
		  vvp_vector4_t tmp(wid, BIT4_X);
		  vala = tmp;
	    } else if (((long)ap[0] == LONG_MIN) && ((long)bp[0] == -1)) {
		  vvp_vector4_t tmp(wid, BIT4_0);
		  tmp.set_bit(wid-1, BIT4_1);
		  vala = tmp;
	    } else {
		  long tmpa = (long) ap[0];
		  long tmpb = (long) bp[0];
		  long res = tmpa / tmpb;
		  ap[0] = ((unsigned long)res) & ~sign_mask;
		  vala.setarray(0, wid, ap);
	    }
	    delete[]ap;
	    delete[]bp;
	    return true;
      }

	// We need to the actual division to positive integers. Make
	// them positive here, and remember the negations.
      bool negate_flag = false;
      if ( ((long) ap[words-1]) < 0 ) {
	    negate_flag = true;
	    negate_words(ap, words);
      }
      if ( ((long) bp[words-1]) < 0 ) {
	    negate_flag ^= true;
	    negate_words(bp, words);
      }

      unsigned long*result = divide_bits(ap, bp, wid);
      if (result == 0) {
	    delete[]ap;
	    delete[]bp;
	    vvp_vector4_t tmp(wid, BIT4_X);
	    vala = tmp;
	    return true;
      }

      if (negate_flag) {
	    negate_words(result, words);
      }

      result[words-1] &= ~sign_mask;

      vala.setarray(0, wid, result);
      delete[]ap;
      delete[]bp;
      delete[]result;
      return true;
}

bool of_DIV_WR(vthread_t thr, vvp_code_t)
{
      double r = thr->pop_real();
      double l = thr->pop_real();
      thr->push_real(l / r);

      return true;
}

/*
 * %dup/obj
 * %dup/real
 * %dup/vec4
 *
 * Push a duplicate of the object on the appropriate stack.
 */
bool of_DUP_OBJ(vthread_t thr, vvp_code_t)
{
      vvp_object_t src = thr->peek_object();

        // If it is null push a new null object
      if (src.test_nil())
	    thr->push_object(vvp_object_t());
      else
	    thr->push_object(src.duplicate());

      return true;
}

bool of_DUP_REAL(vthread_t thr, vvp_code_t)
{
      thr->push_real(thr->peek_real(0));
      return true;
}

bool of_DUP_STR(vthread_t thr, vvp_code_t)
{
      thr->push_str(thr->peek_str(0));
      return true;
}

bool of_DUP_VEC4(vthread_t thr, vvp_code_t)
{
      thr->push_vec4(thr->peek_vec4(0));
      return true;
}

/*
 * This terminates the current thread. If there is a parent who is
 * waiting for me to die, then I schedule it. At any rate, I mark
 * myself as a zombie by setting my pc to 0.
 */
bool of_END(vthread_t thr, vvp_code_t)
{
      assert(! thr->waiting_for_event);
      if (vvp_process*proc = thr->process_obj_.peek<vvp_process>())
	    proc->mark_finished();
      thr->i_have_ended = 1;
      thr->pc = codespace_null();

      if (flow_trace_enabled_()) {
            static unsigned end_trace_count = 0;
            if (end_trace_count < 256) {
                  const char*scope_name = thr && thr->parent_scope
                                      ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
                  const char*parent_name = (thr && thr->parent && thr->parent->parent_scope)
                                       ? vpi_get_str(vpiFullName, thr->parent->parent_scope) : 0;
                  fprintf(stderr,
                          "trace flow: end scope=%s parent=%s detached=%d joining_parent=%d\n",
                          scope_name ? scope_name : "<unknown>",
                          parent_name ? parent_name : "<none>",
                          thr->i_am_detached ? 1 : 0,
                          (thr->parent && thr->parent->i_am_joining) ? 1 : 0);
                  end_trace_count += 1;
            }
      }

	/* Fully detach any detached children. */
      while (! thr->detached_children.empty()) {
	    vthread_t child = *(thr->detached_children.begin());
	    assert(child);
	    assert(child->parent == thr);
	    assert(child->i_am_detached);
	    child->parent = 0;
	    child->i_am_detached = 0;
	    thr->detached_children.erase(thr->detached_children.begin());
      }

	/* It is an error to still have active children running at this
	 * point in time. They should have all been detached or joined. */
      assert(thr->children.empty());

	/* If I have a parent who is waiting for me, then mark that I
	   have ended, and schedule that parent. Also, finish the
	   %join for the parent. */
      if (!thr->i_am_detached && thr->parent && thr->parent->i_am_joining) {
	    vthread_t tmp = thr->parent;
	    assert(! thr->i_am_detached);

	    resume_joining_parent_(tmp, thr);
	    return false;
      }

	/* If this thread is not fully detached then remove it from the
	 * parents detached_children set and reap it. */
      if (thr->i_am_detached) {
	    vthread_t tmp = thr->parent;
	    assert(tmp);
	    size_t res = tmp->detached_children.erase(thr);
	    assert(res == 1);
	      /* If the parent is waiting for the detached children to
	       * finish then the last detached child needs to tell the
	       * parent to wake up when it is finished. */
	    if (tmp->i_am_waiting && tmp->detached_children.empty()) {
		  tmp->i_am_waiting = 0;
		  schedule_vthread(tmp, 0, true);
	    }
	      /* Fully detach this thread so it will be reaped below. */
	    thr->i_am_detached = 0;
	    thr->parent = 0;
      }

	/* If I have no parent, then no one can %join me and there is
	 * no reason to stick around. This can happen, for example if
	 * I am an ``initial'' thread. */
      if (thr->parent == 0) {
	    vthread_reap(thr);
	    return false;
      }

	/* If I make it this far, then I have a parent who may wish
	   to %join me. Remain a zombie so that it can. */

      return false;
}

/*
 * %event <var-label>
 */
bool of_EVENT(vthread_t thr, vvp_code_t cp)
{
      vvp_net_ptr_t ptr (cp->net, 0);
      vvp_vector4_t tmp (1, BIT4_X);
      vvp_send_vec4(ptr, tmp, ensure_write_context_(thr, "assign-vec4"));
      return true;
}

/*
 * %event/nb <var-label>, <delay>
 */
bool of_EVENT_NB(vthread_t thr, vvp_code_t cp)
{
      vvp_time64_t delay;

      delay = thr->words[cp->bit_idx[0]].w_uint;
      schedule_propagate_event(cp->net, delay);
      return true;
}

bool of_EVCTL(vthread_t thr, vvp_code_t cp)
{
      assert(thr->event == 0 && thr->ecount == 0);
      thr->event = cp->net;
      thr->ecount = thr->words[cp->bit_idx[0]].w_uint;
      return true;
}
bool of_EVCTLC(vthread_t thr, vvp_code_t)
{
      thr->event = 0;
      thr->ecount = 0;
      return true;
}

bool of_EVCTLI(vthread_t thr, vvp_code_t cp)
{
      assert(thr->event == 0 && thr->ecount == 0);
      thr->event = cp->net;
      thr->ecount = cp->bit_idx[0];
      return true;
}

bool of_EVCTLS(vthread_t thr, vvp_code_t cp)
{
      assert(thr->event == 0 && thr->ecount == 0);
      thr->event = cp->net;
      int64_t val = thr->words[cp->bit_idx[0]].w_int;
      if (val < 0) val = 0;
      thr->ecount = val;
      return true;
}

bool of_FLAG_GET_VEC4(vthread_t thr, vvp_code_t cp)
{
      int flag = cp->number;
      assert(flag < vthread_s::FLAGS_COUNT);

      vvp_vector4_t val (1, thr->flags[flag]);
      thr->push_vec4(val);

      return true;
}

/*
 * %flag_inv <flag1>
 */
bool of_FLAG_INV(vthread_t thr, vvp_code_t cp)
{
      int flag1 = cp->bit_idx[0];

      thr->flags[flag1] = ~ thr->flags[flag1];
      return true;
}

/*
 * %flag_mov <flag1>, <flag2>
 */
bool of_FLAG_MOV(vthread_t thr, vvp_code_t cp)
{
      int flag1 = cp->bit_idx[0];
      int flag2 = cp->bit_idx[1];

      thr->flags[flag1] = thr->flags[flag2];
      return true;
}

/*
 * %flag_or <flag1>, <flag2>
 */
bool of_FLAG_OR(vthread_t thr, vvp_code_t cp)
{
      int flag1 = cp->bit_idx[0];
      int flag2 = cp->bit_idx[1];

      thr->flags[flag1] = thr->flags[flag1] | thr->flags[flag2];
      return true;
}

bool of_FLAG_SET_IMM(vthread_t thr, vvp_code_t cp)
{
      int flag = cp->number;
      int vali = cp->bit_idx[0];

      assert(flag < vthread_s::FLAGS_COUNT);
      assert(vali >= 0 && vali < 4);

      static const vvp_bit4_t map_bit[4] = {BIT4_0, BIT4_1, BIT4_Z, BIT4_X};
      thr->flags[flag] = map_bit[vali];
      return true;
}

bool of_FLAG_SET_VEC4(vthread_t thr, vvp_code_t cp)
{
      int flag = cp->number;
      assert(flag < vthread_s::FLAGS_COUNT);

      const vvp_vector4_t&val = thr->peek_vec4();
      thr->flags[flag] = val.value(0);
      thr->pop_vec4(1);

      return true;
}

/*
 * the %force/link instruction connects a source node to a
 * destination node. The destination node must be a signal, as it is
 * marked with the source of the force so that it may later be
 * unlinked without specifically knowing the source that this
 * instruction used.
 */
bool of_FORCE_LINK(vthread_t, vvp_code_t cp)
{
      vvp_net_t*dst = cp->net;
      vvp_net_t*src = cp->net2;

      assert(dst->fil);
      dst->fil->force_link(dst, src);

      return true;
}

/*
 * The %force/vec4 instruction invokes a force assign of a constant value
 * to a signal. The instruction arguments are:
 *
 *     %force/vec4 <net> ;
 *
 * where the <net> is the net label assembled into a vvp_net pointer,
 * and the value to be forced is popped from the vec4 stack.\.
 *
 * The instruction writes a vvp_vector4_t value to port-2 of the
 * target signal.
 */
bool of_FORCE_VEC4(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;

      vvp_vector4_t value = thr->pop_vec4();

	/* Send the force value to the filter on the node. */

      assert(net->fil);
      if (value.size() != net->fil->filter_size())
	    value = coerce_to_width(value, net->fil->filter_size());

      net->force_vec4(value, vvp_vector2_t(vvp_vector2_t::FILL1, net->fil->filter_size()));

      return true;
}

/*
 * %force/vec4/off <net>, <off>
 */
bool of_FORCE_VEC4_OFF(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;
      unsigned base_idx = cp->bit_idx[0];
      long base = thr->words[base_idx].w_int;
      vvp_vector4_t value = thr->pop_vec4();
      unsigned wid = value.size();

      assert(net->fil);

      if (thr->flags[4] == BIT4_1)
	    return true;

	// This is the width of the target vector.
      unsigned use_size = net->fil->filter_size();

      if (base >= (long)use_size)
	    return true;
      if (base < -(long)use_size)
	    return true;

      if ((base + wid) > use_size)
	    wid = use_size - base;

	// Make a mask of which bits are to be forced, 0 for unforced
	// bits and 1 for forced bits.
      vvp_vector2_t mask (vvp_vector2_t::FILL0, use_size);
      for (unsigned idx = 0 ; idx < wid ; idx += 1)
	    mask.set_bit(base+idx, 1);

      vvp_vector4_t tmp (use_size, BIT4_Z);

	// vvp_net_t::force_vec4 propagates all the bits of the
	// forced vector value, regardless of the mask. This
	// ensures the unforced bits retain their current value.
      vvp_signal_value*sig = dynamic_cast<vvp_signal_value*>(net->fil);
      assert(sig);
      sig->vec4_value(tmp);

      tmp.set_vec(base, value);

      net->force_vec4(tmp, mask);
      return true;
}

/*
 * %force/vec4/off/d <net>, <off>, <del>
 */
bool of_FORCE_VEC4_OFF_D(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;

      unsigned base_idx = cp->bit_idx[0];
      long base = thr->words[base_idx].w_int;

      unsigned delay_idx = cp->bit_idx[1];
      vvp_time64_t delay = thr->words[delay_idx].w_uint;

      vvp_vector4_t value = thr->pop_vec4();

      assert(net->fil);

      if (thr->flags[4] == BIT4_1)
	    return true;

	// This is the width of the target vector.
      unsigned use_size = net->fil->filter_size();

      if (base >= (long)use_size)
	    return true;
      if (base < -(long)use_size)
	    return true;

      schedule_force_vector(net, base, use_size, value, delay);
      return true;
}

bool of_FORCE_WR(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net  = cp->net;
      double value = thr->pop_real();

      net->force_real(value, vvp_vector2_t(vvp_vector2_t::FILL1, 1));

      return true;
}

/*
 * The %fork instruction causes a new child to be created and pushed
 * in front of any existing child. This causes the new child to be
 * added to the list of children, and for me to be the parent of the
 * new child.
 */
bool of_FORK(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);
      __vpiScope*child_ctx_scope = resolve_context_scope(cp->scope);
      if (thr->staged_alloc_rd_scope
          && child_ctx_scope == thr->staged_alloc_rd_scope) {
            thr->staged_alloc_rd_context = 0;
            thr->staged_alloc_rd_scope = 0;
      }

      if (cp->scope->is_automatic()) {
              /* The context allocated for this child is the top entry
                 on the write context stack. */
            child->wt_context = thr->wt_context;
            child->rd_context = thr->wt_context;
      }
      if (thr->owned_context && !child->owned_context
          && context_live_in_owner(thr->owned_context)) {
              /* Detached automatic fork blocks can retain a shared frame in
                 owned_context. Nested children still need to read locals from
                 that frame, so inherit a retained reference instead of losing
                 it when the parent allocates a fresh begin-block frame. */
            retain_context_chain_(thr->owned_context);
            child->owns_automatic_context = 1;
            child->owned_context = thr->owned_context;
      }
      trace_context_event_("fork", thr, child->parent_scope, child->wt_context);

      child->parent = thr;
      thr->children.insert(child);

	      if (thr->i_am_in_function && !(thr->pc && thr->pc->opcode == of_JOIN_DETACH)) {
		    child->is_scheduled = 1;
		    child->i_am_in_function = 1;
		    vthread_run(child);
		    running_thread = thr;
	      } else {
		    schedule_vthread(child, 0, true);
	      }
	      return true;
}

bool of_FORK_V(vthread_t thr, vvp_code_t cp)
{
      vthread_t child = vthread_new(cp->cptr2, cp->scope);
      __vpiScope*child_ctx_scope = resolve_context_scope(cp->scope);
      if (thr->staged_alloc_rd_scope
          && child_ctx_scope == thr->staged_alloc_rd_scope) {
            thr->staged_alloc_rd_context = 0;
            thr->staged_alloc_rd_scope = 0;
      }
      maybe_dispatch_virtual_method_call_(thr, cp, child, false);

      if (cp->scope->is_automatic() && !child->wt_context) {
              /* The context allocated for this child is the top entry
                 on the write context stack. */
            child->wt_context = thr->wt_context;
            child->rd_context = thr->wt_context;
      }
      if (thr->owned_context && !child->owned_context
          && context_live_in_owner(thr->owned_context)) {
            retain_context_chain_(thr->owned_context);
            child->owns_automatic_context = 1;
            child->owned_context = thr->owned_context;
      }
      trace_context_event_("fork", thr, child->parent_scope, child->wt_context);

      child->parent = thr;
      thr->children.insert(child);

	      if (thr->i_am_in_function && !(thr->pc && thr->pc->opcode == of_JOIN_DETACH)) {
		    child->is_scheduled = 1;
		    child->i_am_in_function = 1;
		    vthread_run(child);
		    running_thread = thr;
	      } else {
		    schedule_vthread(child, 0, true);
	      }
	      return true;
}

bool of_FREE(vthread_t thr, vvp_code_t cp)
{
      __vpiScope*ctx_scope = resolve_context_scope(cp->scope);
      if (thr->staged_alloc_rd_scope
          && (!ctx_scope || thr->staged_alloc_rd_scope == ctx_scope)) {
            thr->staged_alloc_rd_context = 0;
            thr->staged_alloc_rd_scope = 0;
      }
      if (ctx_scope && cp->scope && ctx_scope != cp->scope) {
            trace_context_event_("free-shared", thr, cp->scope, 0);
            return true;
      }
      if (thr->skip_free_context
          && (!ctx_scope || thr->skip_free_scope == ctx_scope)) {
            vvp_context_t skip_context = thr->skip_free_context;
            __vpiScope*skip_scope = thr->skip_free_scope
                                  ? thr->skip_free_scope : ctx_scope;
            vvp_context_t saved_skip_next = vvp_get_stacked_context(skip_context);
            bool retain_skip_chain = false;
            map<vvp_context_t, unsigned>::const_iterator ref_it =
                  automatic_context_refcount.find(skip_context);
            if (ref_it != automatic_context_refcount.end() && ref_it->second > 1)
                  retain_skip_chain = true;
            thr->wt_context = remove_context_from_stacked_chain_(thr->wt_context,
                                                                 skip_context);
            thr->rd_context = remove_context_from_stacked_chain_(thr->rd_context,
                                                                 skip_context);
            trace_context_event_("free-skip", thr, ctx_scope, skip_context);
            thr->skip_free_context = 0;
            thr->skip_free_scope = 0;
            vthread_free_context(skip_context, skip_scope);
            if (retain_skip_chain)
                  vvp_set_stacked_context(skip_context, saved_skip_next);
            ensure_write_context_(thr, "free-skip");
            return true;
      }

        /* %alloc/%free pairs manage staged automatic frames on the write
           stack around calls. After nested callf/join activity the matching
           frame may no longer be at the top of rd_context, so free the live
           frame for this scope from the write stack first and scrub it from
           both chains. */
      vvp_context_t child_context = 0;
      if (ctx_scope && ctx_scope->is_automatic()) {
            if (thr->rd_context
                && context_live_matches_scope_(thr->rd_context, ctx_scope))
                  child_context = thr->rd_context;
            if (!child_context)
                  child_context = first_live_context_for_scope(thr->wt_context, ctx_scope);
            if (!child_context)
                  child_context = first_live_context_for_scope(thr->rd_context, ctx_scope);
      } else {
            child_context = thr->wt_context ? thr->wt_context : thr->rd_context;
      }
      if (!child_context) {
            trace_context_event_("free-null", thr, ctx_scope, 0);
            return true;
      }
      thr->wt_context = remove_context_from_stacked_chain_(thr->wt_context, child_context);
      thr->rd_context = remove_context_from_stacked_chain_(thr->rd_context, child_context);

      /* If the current scope has no remaining live read frame after this
         free, hand reads back to the next live caller frame before the
         generic sanitizer runs. Otherwise sanitize_thread_contexts_ can
         incorrectly drop the caller read chain while returning across
         automatic class-call scopes. */
      if (ctx_scope && ctx_scope->is_automatic()) {
            vvp_context_t next_rd = 0;

            /* Same-scope recursion keeps the immediate caller frame at the
               head of wt_context after the callee frame is removed. Prefer
               that live write-head over deeper same-scope entries that may
               still sit on the old rd_context chain. */
            if (thr->wt_context && context_live_in_owner(thr->wt_context))
                  next_rd = thr->wt_context;

            if (!next_rd)
                  next_rd = first_live_context_for_scope(thr->rd_context, ctx_scope);
            if (!next_rd)
                  next_rd = first_live_stacked_context(thr->wt_context, 0);
            if (!next_rd)
                  next_rd = first_live_stacked_context(thr->rd_context, 0);
            if (next_rd)
                  thr->rd_context = next_rd;
      }

      /* Free the context. */
      vthread_free_context(child_context, ctx_scope);
      if (!(ctx_scope && ctx_scope->is_automatic()
            && thr->wt_context && context_live_in_owner(thr->wt_context))) {
            ensure_write_context_(thr, "free");
      }
      trace_context_event_("free", thr, ctx_scope, child_context);

      return true;
}

/*
 * %inv
 *
 * Logically, this pops a value, inverts is (Verilog style, with Z and
 * X converted to X) and pushes the result. We can more efficiently
 * just to the invert in place.
 */
bool of_INV(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t&val = thr->peek_vec4();
      val.invert();
      return true;
}


/*
 * Index registers, arithmetic.
 */

static inline int64_t get_as_64_bit(uint32_t low_32, uint32_t high_32)
{
      int64_t low = low_32;
      int64_t res = high_32;

      res <<= 32;
      res |= low;
      return res;
}

bool of_IX_ADD(vthread_t thr, vvp_code_t cp)
{
      thr->words[cp->number].w_int += get_as_64_bit(cp->bit_idx[0],
                                                    cp->bit_idx[1]);
      return true;
}

bool of_IX_SUB(vthread_t thr, vvp_code_t cp)
{
      thr->words[cp->number].w_int -= get_as_64_bit(cp->bit_idx[0],
                                                    cp->bit_idx[1]);
      return true;
}

bool of_IX_MUL(vthread_t thr, vvp_code_t cp)
{
      thr->words[cp->number].w_int *= get_as_64_bit(cp->bit_idx[0],
                                                    cp->bit_idx[1]);
      return true;
}

bool of_IX_LOAD(vthread_t thr, vvp_code_t cp)
{
      thr->words[cp->number].w_int = get_as_64_bit(cp->bit_idx[0],
                                                   cp->bit_idx[1]);
      return true;
}

bool of_IX_MOV(vthread_t thr, vvp_code_t cp)
{
      thr->words[cp->bit_idx[0]].w_int = thr->words[cp->bit_idx[1]].w_int;
      return true;
}

bool of_IX_GETV(vthread_t thr, vvp_code_t cp)
{
      unsigned index = cp->bit_idx[0];
      vvp_net_t*net = cp->net;

      vvp_signal_value*sig = dynamic_cast<vvp_signal_value*>(net->fil);
      if (sig == 0) {
	    assert(net->fil);
	    cerr << thr->get_fileline()
	         << "%%ix/getv error: Net arg not a vector signal? "
		 << typeid(*net->fil).name() << endl;
      }
      assert(sig);

      vvp_vector4_t vec;
      sig->vec4_value(vec);
      bool overflow_flag;
      uint64_t val = 0;
      bool known_flag = vector4_to_value(vec, overflow_flag, val);

      if (known_flag)
	    thr->words[index].w_uint = val;
      else
	    thr->words[index].w_uint = 0;

	/* Set bit 4 as a flag if the input is unknown. */
      thr->flags[4] = known_flag ? (overflow_flag ? BIT4_X : BIT4_0) : BIT4_1;

      return true;
}

bool of_IX_GETV_S(vthread_t thr, vvp_code_t cp)
{
      unsigned index = cp->bit_idx[0];
      vvp_net_t*net = cp->net;

      vvp_signal_value*sig = dynamic_cast<vvp_signal_value*>(net->fil);
      if (sig == 0) {
	    assert(net->fil);
	    cerr << thr->get_fileline()
	         << "%%ix/getv/s error: Net arg not a vector signal? "
		 << "fun=" << typeid(*net->fil).name()
		 << ", fil=" << (net->fil? typeid(*net->fil).name() : "<>")
		 << endl;
      }
      assert(sig);

      vvp_vector4_t vec;
      sig->vec4_value(vec);
      int64_t val;
      bool known_flag = vector4_to_value(vec, val, true, true);

      if (known_flag)
	    thr->words[index].w_int = val;
      else
	    thr->words[index].w_int = 0;

	/* Set bit 4 as a flag if the input is unknown. */
      thr->flags[4] = known_flag? BIT4_0 : BIT4_1;

      return true;
}

static uint64_t vec4_to_index(vthread_t thr, bool signed_flag)
{
	// Get all the information we need about the vec4 vector, then
	// pop it away. We only need the bool bits and the length.
      const vvp_vector4_t&val = thr->peek_vec4();
      unsigned val_size = val.size();
      unsigned long*bits = val.subarray(0, val_size, false);
      thr->pop_vec4(1);

	// If there are X/Z bits, then the subarray will give us a nil
	// pointer. Set a flag to indicate the error, and give up.
      if (bits == 0) {
	    thr->flags[4] = BIT4_1;
	    return 0;
      }

      uint64_t v = 0;
      thr->flags[4] = BIT4_0;

      assert(sizeof(bits[0]) <= sizeof(v));

      v = 0;
      for (unsigned idx = 0 ; idx < val_size ; idx += 8*sizeof(bits[0])) {
	    uint64_t tmp = bits[idx/8/sizeof(bits[0])];
	    if (idx < 8*sizeof(v)) {
		  v |= tmp << idx;
	    } else {
		  bool overflow = signed_flag && (v >> 63) ? ~tmp != 0 : tmp != 0;
		  if (overflow) {
			thr->flags[4] = BIT4_X;
			break;
		  }
	    }
      }

	// Set the high bits that are not necessarily filled in by the
	// subarray function.
      if (val_size < 8*sizeof(v)) {
	    if (signed_flag && (v & (static_cast<uint64_t>(1)<<(val_size-1)))) {
		    // Propagate the sign bit...
		  v |= (~static_cast<uint64_t>(0)) << val_size;

	    } else {
		    // Fill with zeros.
		  v &= ~((~static_cast<uint64_t>(0)) << val_size);
	    }

      }

      delete[]bits;
      return v;
}

/*
 * %ix/vec4 <idx>
 */
bool of_IX_VEC4(vthread_t thr, vvp_code_t cp)
{
      unsigned use_idx = cp->number;
      thr->words[use_idx].w_uint = vec4_to_index(thr, false);
      return true;
}

/*
 * %ix/vec4/s <idx>
 */
bool of_IX_VEC4_S(vthread_t thr, vvp_code_t cp)
{
      unsigned use_idx = cp->number;
      thr->words[use_idx].w_uint = vec4_to_index(thr, true);
      return true;
}

/*
 * The various JMP instruction work simply by pulling the new program
 * counter from the instruction and resuming. If the jump is
 * conditional, then test the bit for the expected value first.
 */
bool of_JMP(vthread_t thr, vvp_code_t cp)
{
      thr->pc = cp->cptr;

	/* Normally, this returns true so that the processor just
	   keeps going to the next instruction. However, if there was
	   a $stop or $finish/vpiFinish, returning false here can break the
	   simulation out of a hung loop. */
      if (schedule_finished())
            return false;

      if (schedule_stopped()) {
	    schedule_vthread(thr, 0, false);
	    return false;
      }

      return true;
}

/*
 * %jmp/0 <pc>, <flag>
 */
bool of_JMP0(vthread_t thr, vvp_code_t cp)
{
      if (thr->flags[cp->bit_idx[0]] == BIT4_0)
	    thr->pc = cp->cptr;

	/* Normally, this returns true so that the processor just
	   keeps going to the next instruction. However, if there was
	   a $stop or $finish/vpiFinish, returning false here can break the
	   simulation out of a hung loop. */
      if (schedule_finished())
            return false;

      if (schedule_stopped()) {
	    schedule_vthread(thr, 0, false);
	    return false;
      }

      return true;
}

/*
 * %jmp/0xz <pc>, <flag>
 */
bool of_JMP0XZ(vthread_t thr, vvp_code_t cp)
{
      if (thr->flags[cp->bit_idx[0]] != BIT4_1)
	    thr->pc = cp->cptr;

	/* Normally, this returns true so that the processor just
	   keeps going to the next instruction. However, if there was
	   a $stop or $finish/vpiFinish, returning false here can break the
	   simulation out of a hung loop. */
      if (schedule_finished())
            return false;

      if (schedule_stopped()) {
	    schedule_vthread(thr, 0, false);
	    return false;
      }

      return true;
}

/*
 * %jmp/1 <pc>, <flag>
 */
bool of_JMP1(vthread_t thr, vvp_code_t cp)
{
      if (thr->flags[cp->bit_idx[0]] == BIT4_1)
	    thr->pc = cp->cptr;

	/* Normally, this returns true so that the processor just
	   keeps going to the next instruction. However, if there was
	   a $stop or $finish/vpiFinish, returning false here can break the
	   simulation out of a hung loop. */
      if (schedule_finished())
            return false;

      if (schedule_stopped()) {
	    schedule_vthread(thr, 0, false);
	    return false;
      }

      return true;
}

/*
 * %jmp/1xz <pc>, <flag>
 */
bool of_JMP1XZ(vthread_t thr, vvp_code_t cp)
{
      if (thr->flags[cp->bit_idx[0]] != BIT4_0)
	    thr->pc = cp->cptr;

	/* Normally, this returns true so that the processor just
	   keeps going to the next instruction. However, if there was
	   a $stop or $finish/vpiFinish, returning false here can break the
	   simulation out of a hung loop. */
      if (schedule_finished())
            return false;

      if (schedule_stopped()) {
	    schedule_vthread(thr, 0, false);
	    return false;
      }

      return true;
}

/*
 * The %join instruction causes the thread to wait for one child
 * to die.  If a child is already dead (and a zombie) then I reap
 * it and go on. Otherwise, I mark myself as waiting in a join so that
 * children know to wake me when they finish.
 */

static void do_join(vthread_t thr, vthread_t child)
{
      assert(child->parent == thr);
      mirror_automatic_call_outputs_if_needed_(thr, child);
      mirror_dynamic_dispatch_outputs_if_needed_(thr, child);
      mirror_object_return_if_needed_(thr, child);
      trace_context_event_("join-enter", thr, child ? child->parent_scope : 0,
                           child ? child->wt_context : 0);
      int child_type = child && child->parent_scope
                     ? child->parent_scope->get_type_code() : 0;
      __vpiScope*thr_ctx_scope = resolve_context_scope(thr ? thr->parent_scope : 0);
      __vpiScope*child_ctx_scope = resolve_context_scope(child ? child->parent_scope : 0);
      bool shared_auto_scope = child_ctx_scope && thr_ctx_scope
                            && (child_ctx_scope == thr_ctx_scope
                                || scope_is_within_or_equal_(thr ? thr->parent_scope : 0,
                                                             child_ctx_scope)
                                || scope_is_within_or_equal_(child ? child->parent_scope : 0,
                                                             thr_ctx_scope));

      if (child->transferred_context) {
            vvp_context_t child_context = child->transferred_context;
            thr->wt_context = remove_context_from_stacked_chain_(thr->wt_context,
                                                                 child_context);
            thr->rd_context = remove_context_from_stacked_chain_(thr->rd_context,
                                                                 child_context);
            thr->skip_free_context = child_context;
            thr->skip_free_scope = child->transferred_context_scope;
            child->transferred_context = 0;
            child->transferred_context_scope = 0;
            trace_context_event_("join-transfer", thr, child ? child->parent_scope : 0,
                                 child_context);

      } else if (child->wt_context
                 && (child_type == vpiTask || child_type == vpiFunction)
                 && thr->wt_context != thr->rd_context) {
            vvp_context_t child_context = 0;
            if (child_ctx_scope && child_ctx_scope->is_automatic())
                  child_context = first_live_context_for_scope(thr->wt_context,
                                                               child_ctx_scope);

            if (child_context && shared_auto_scope) {
                    /* Same-scope recursive automatic calls must keep the child
                       frame on the write stack for the matching %free, but the
                       caller's immediate post-call loads still need to read the
                       child frame. Point rd_context at the shared child head
                       until %free removes it from both chains. */
                  thr->rd_context = child_context;
                  trace_context_event_("join-rd-share", thr,
                                       child ? child->parent_scope : 0,
                                       child_context);
	            } else if (child_context) {
	                    /* Pop the child context from the write stack, then move that
	                       same context to the top of the read stack without leaving a
	                       duplicate stacked link behind. */
	                  vvp_context_t caller_rd = 0;
	                  thr->wt_context = vvp_get_stacked_context(child_context);
	                  caller_rd = remove_context_from_stacked_chain_(thr->rd_context,
	                                                                 child_context);
	                  thr->rd_context = caller_rd;
	                  vvp_set_stacked_context(child_context, thr->rd_context);
	                  thr->rd_context = child_context;
	                  if (!thr->wt_context && thr_ctx_scope && thr_ctx_scope->is_automatic()
	                      && caller_rd
	                      && context_live_matches_scope_(caller_rd, thr_ctx_scope)) {
	                        thr->wt_context = caller_rd;
	                        trace_context_event_("join-wt-caller-restore", thr,
	                                             child ? child->parent_scope : 0,
	                                             caller_rd);
	                  }
	                  trace_context_event_("join-pop-push", thr,
	                                       child ? child->parent_scope : 0,
	                                       child_context);
	            }
	      }

	      if (thr->i_am_in_function
	          && child->pending_nonlocal_jmp && child->nonlocal_target) {
	            if (!child->is_callf_child
	                && child_nonlocal_jump_matches_parent_(thr, child)) {
	                  if (flow_trace_enabled_()) {
	                        fprintf(stderr,
                                "trace flow: applying non-local join jump parent=%s child=%s origin=%s target=%p\n",
                                scope_name_or_unknown_(thr->parent_scope),
                                scope_name_or_unknown_(child->parent_scope),
                                scope_name_or_unknown_(child->nonlocal_origin_scope),
                                (void*)child->nonlocal_target);
                  }
	                  thr->pending_nonlocal_jmp = 1;
	                  thr->nonlocal_target = child->nonlocal_target;
	                  thr->nonlocal_origin_scope = child->nonlocal_origin_scope;
	                  thr->pc = child->nonlocal_target;
	            } else if (child->is_callf_child) {
	                  if (flow_trace_enabled_()) {
	                        fprintf(stderr,
	                                "trace flow: suppressing non-local join jump across callf boundary"
	                                " parent=%s child=%s origin=%s target=%p\n",
	                                scope_name_or_unknown_(thr->parent_scope),
	                                scope_name_or_unknown_(child->parent_scope),
	                                scope_name_or_unknown_(child->nonlocal_origin_scope),
	                                (void*)child->nonlocal_target);
	                  }
	            } else if (flow_trace_enabled_()) {
	                  fprintf(stderr,
	                          "trace flow: suppressing non-local join jump due to scope mismatch"
	                          " parent=%s child=%s origin=%s target=%p\n",
	                          scope_name_or_unknown_(thr->parent_scope),
	                          scope_name_or_unknown_(child->parent_scope),
	                          scope_name_or_unknown_(child->nonlocal_origin_scope),
	                          (void*)child->nonlocal_target);
            }
      }

      vthread_reap(child);
}

static bool do_join_opcode(vthread_t thr)
{
      assert( !thr->i_am_joining );
      assert( !thr->children.empty());

	// Are there any children that have already ended? If so, then
	// join with that one.
      for (set<vthread_t>::iterator cur = thr->children.begin()
		 ; cur != thr->children.end() ; ++cur) {
	    vthread_t curp = *cur;
	    if (! curp->i_have_ended)
		  continue;

	      // found something!
	    do_join(thr, curp);
	    return true;
      }

	// Otherwise, tell my children to awaken me when they end,
	// then pause.
      thr->i_am_joining = 1;
      return false;
}

bool of_JOIN(vthread_t thr, vvp_code_t)
{
      return do_join_opcode(thr);
}

/*
 * This %join/detach <n> instruction causes the thread to detach
 * threads that were created by an earlier %fork.
 */
bool of_JOIN_DETACH(vthread_t thr, vvp_code_t cp)
{
      unsigned long count = cp->number;

      assert(count == thr->children.size());
      trace_context_event_("join-detach-enter", thr, 0, 0);

	      while (! thr->children.empty()) {
		    vthread_t child = *thr->children.begin();
		    assert(child->parent == thr);

		      // We cannot detach automatic tasks/functions within an
		      // automatic scope. If we try to do that, we might make
		      // a mess of the allocation of the context. Note that it
		      // is OK if the child context is distinct (See %exec_ufunc.)
		    if (child->wt_context && thr->wt_context == child->wt_context) {
			  vvp_context_t child_context = child->wt_context;
			  map<vvp_context_t, __vpiScope*>::const_iterator owner_it =
				automatic_context_owner.find(child_context);
			  __vpiScope*child_context_scope =
				(owner_it != automatic_context_owner.end())
				      ? owner_it->second : resolve_context_scope(thr->parent_scope);
                          /* Detached nested blocks keep sharing the same
                             activation frame as the parent task. Retain the
                             frame for the child and let the parent drop its
                             reference at the matching %free. */
                          retain_automatic_context_(child_context);
                          vvp_context_t parent_context = thr->rd_context;
                          if (!parent_context || parent_context == child_context)
                                parent_context = vvp_get_stacked_context(child_context);
                          if (parent_context
                              && parent_context != child_context
                              && context_live_in_owner(parent_context)) {
                                retain_automatic_context_(parent_context);
                                vvp_set_stacked_context(child_context, parent_context);
                          }
                          thr->skip_free_context = child_context;
                          thr->skip_free_scope = child_context_scope;
                          child->owns_automatic_context = 1;
                          child->owned_context = child_context;
                          trace_context_event_("join-detach-share", thr,
                                               child ? child->parent_scope : 0,
                                               child_context);
		    }
		    if (child->i_have_ended) {
			    // If the child has already ended, then reap it.
			  vthread_reap(child);

	    } else {
		  size_t res = child->parent->children.erase(child);
		  assert(res == 1);
		  child->i_am_detached = 1;
		  thr->detached_children.insert(child);
	    }
      }

      return true;
}

/*
 * %load/ar <array-label>, <index>;
*/
bool of_LOAD_AR(vthread_t thr, vvp_code_t cp)
{
      unsigned idx = cp->bit_idx[0];
      double word;

	/* The result is 0.0 if the address is undefined. */
      if (thr->flags[4] == BIT4_1) {
	    word = 0.0;
      } else {
	    unsigned adr = thr->words[idx].w_int;
	    vvp_array_t array = resolve_runtime_array_(cp, "%load/ar");
	    word = array ? array->get_word_r(adr) : 0.0;
      }

      thr->push_real(word);
      return true;
}

template <typename ELEM>
static bool load_dar(vthread_t thr, vvp_code_t cp)
{
      int64_t adr = thr->words[3].w_int;
      vvp_net_t*net = cp->net;
      assert(net);

      vvp_fun_signal_object*obj = dynamic_cast<vvp_fun_signal_object*> (net->fun);
      assert(obj);

      vvp_darray*darray = obj->get_object().peek<vvp_darray>();

      ELEM word;
      if (darray &&
          (adr >= 0) && (thr->flags[4] == BIT4_0)) // A defined address >= 0
	    darray->get_word(adr, word);
      else
	    dq_default(word, obj->size());

      vthread_push(thr, word);
      return true;
}

/*
 * %load/dar/r <array-label>;
 */
bool of_LOAD_DAR_R(vthread_t thr, vvp_code_t cp)
{
      return load_dar<double>(thr, cp);
}

/*
 * %load/dar/str <array-label>;
 */
bool of_LOAD_DAR_STR(vthread_t thr, vvp_code_t cp)
{
      return load_dar<string>(thr, cp);
}

/*
 * %load/dar/vec4 <array-label>;
 */
bool of_LOAD_DAR_VEC4(vthread_t thr, vvp_code_t cp)
{
      return load_dar<vvp_vector4_t>(thr, cp);
}

/*
 * %load/dar/obj <array-label>
 *    Load an object from a dynamic array element, using integer register 3
 *    as the index. Pushes the object onto the object stack.
 */
bool of_LOAD_DAR_OBJ(vthread_t thr, vvp_code_t cp)
{
      int64_t adr = thr->words[3].w_int;
      vvp_net_t*net = cp->net;
      assert(net);

      vvp_fun_signal_object*obj = dynamic_cast<vvp_fun_signal_object*> (net->fun);
      assert(obj);

      vvp_darray*darray = obj->get_object().peek<vvp_darray>();

      vvp_object_t word;
      if (darray &&
          (adr >= 0) && (thr->flags[4] == BIT4_0))
	    darray->get_word(adr, word);
      // else word remains nil (default-constructed vvp_object_t)

      thr->push_object(word);
      return true;
}

inline static void push_loaded_qo_value_(vthread_t thr, double value, unsigned)
{
      thr->push_real(value);
}

inline static void push_loaded_qo_value_(vthread_t thr, const string&value, unsigned)
{
      thr->push_str(value);
}

inline static void push_loaded_qo_value_(vthread_t thr, const vvp_vector4_t&value, unsigned)
{
      thr->push_vec4(value);
}

inline static void push_loaded_qo_value_(vthread_t thr, const vvp_object_t&value, unsigned)
{
      thr->push_object(value);
}

static vvp_fun_signal_object* signal_object_fun_(vvp_net_t*net)
{
      if (!net)
            return 0;

      vvp_fun_signal_object*fun =
            dynamic_cast<vvp_fun_signal_object*>(net->fun);
      if (!fun)
            fun = dynamic_cast<vvp_fun_signal_object*>(net->fil);
      return fun;
}

static void notify_mutated_object_signal_(vthread_t thr, vvp_net_t*net, const char*where)
{
      vvp_fun_signal_object*fun = signal_object_fun_(net);
      if (!fun)
            return;

      vvp_object_t root = fun->peek_object();
      if (root.test_nil())
            return;

      root.touch();
      root.notify_signal_aliases();
      vvp_send_object(vvp_net_ptr_t(net, 0), root, ensure_write_context_(thr, where));
}

static void notify_mutated_object_root_(vthread_t thr, const vvp_object_t&recv,
                                        vvp_net_t*root_net, const vvp_object_t&root_obj,
                                        const char*where)
{
      static int trace_mut = -1;
      if (trace_mut < 0) {
            const char*env = getenv("IVL_MUTATE_TRACE");
            trace_mut = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      if (trace_mut) {
            const char*scope_name = (thr && thr->parent_scope)
                                  ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
            fprintf(stderr,
                    "trace mutate-root where=%s scope=%s recv=%p root_net=%p root_obj=%p root_nil=%d\n",
                    where ? where : "<unknown>",
                    scope_name ? scope_name : "<unknown>",
                    recv.peek<vvp_object>(),
                    (void*)root_net,
                    root_obj.peek<vvp_object>(),
                    root_obj.test_nil() ? 1 : 0);
      }
      if (!root_net || root_obj.test_nil()) {
            if (!recv.test_nil()) {
                  recv.touch();
                  recv.notify_signal_aliases();
            }
            return;
      }

      if (!recv.test_nil()) {
            recv.touch();
            recv.notify_signal_aliases();
      }
      if (root_obj != recv)
            root_obj.touch();

      root_obj.notify_signal_aliases();
      vvp_send_object(vvp_net_ptr_t(root_net, 0), root_obj,
                      ensure_write_context_(thr, where));
}

static vvp_fun_signal_string* signal_string_fun_(vvp_net_t*net)
{
      if (!net)
            return 0;

      vvp_fun_signal_string*fun =
            dynamic_cast<vvp_fun_signal_string*>(net->fun);
      if (!fun)
            fun = dynamic_cast<vvp_fun_signal_string*>(net->fil);
      return fun;
}

static vvp_signal_value* signal_vec4_fun_(vvp_net_t*net)
{
      if (!net)
            return 0;

      vvp_signal_value*fun =
            dynamic_cast<vvp_signal_value*>(net->fun);
      if (!fun)
            fun = dynamic_cast<vvp_signal_value*>(net->fil);
      return fun;
}

template <class ASSOC>
static ASSOC* peek_signal_assoc_(vvp_net_t*net)
{
      static bool warned = false;
      vvp_fun_signal_object*obj = signal_object_fun_(net);
      if (!obj)
            return 0;

      vvp_assoc_base*assoc = obj->get_object().peek<vvp_assoc_base>();
      if (!assoc)
            return 0;

      ASSOC*typed_assoc = dynamic_cast<ASSOC*>(assoc);
      if (!typed_assoc && !warned) {
            cerr << "Warning: signal assoc operation on unexpected container type."
                 << endl;
            warned = true;
      }

      return typed_assoc;
}

template <class ASSOC>
static ASSOC* ensure_signal_assoc_(vthread_t thr, vvp_net_t*net, const char*why)
{
      ASSOC*assoc = peek_signal_assoc_<ASSOC>(net);
      if (assoc)
            return assoc;

      if (!signal_object_fun_(net))
            return 0;

      vvp_object_t val(new ASSOC);
      vvp_send_object(vvp_net_ptr_t(net, 0), val, ensure_write_context_(thr, why));
      return peek_signal_assoc_<ASSOC>(net);
}

template <typename KEY> static KEY pop_assoc_key_(vthread_t thr);

template <>
string pop_assoc_key_<string>(vthread_t thr)
{
      return thr->pop_str();
}

template <>
vvp_object_t pop_assoc_key_<vvp_object_t>(vthread_t thr)
{
      vvp_object_t key;
      thr->pop_object(key);
      return key;
}

template <>
vvp_vector4_t pop_assoc_key_<vvp_vector4_t>(vthread_t thr)
{
      return thr->pop_vec4();
}

template <typename KEY>
static bool read_signal_assoc_key_(vthread_t thr, vvp_net_t*net, KEY&value);

template <>
bool read_signal_assoc_key_<string>(vthread_t thr, vvp_net_t*net, string&value)
{
      if (!(thr && net))
            return false;

      vvp_fun_signal_string*fun = signal_string_fun_(net);
      if (!fun)
            return false;

      vthread_t save_running = running_thread;
      running_thread = thr;
      value = fun->get_string();
      running_thread = save_running;
      return true;
}

template <>
bool read_signal_assoc_key_<vvp_object_t>(vthread_t thr, vvp_net_t*net, vvp_object_t&value)
{
      if (!(thr && net))
            return false;

      vvp_fun_signal_object*fun = signal_object_fun_(net);
      if (!fun)
            return false;

      vthread_t save_running = running_thread;
      running_thread = thr;
      value = fun->get_object();
      running_thread = save_running;
      return true;
}

template <>
bool read_signal_assoc_key_<vvp_vector4_t>(vthread_t thr, vvp_net_t*net, vvp_vector4_t&value)
{
      if (!(thr && net))
            return false;

      vvp_signal_value*fun = signal_vec4_fun_(net);
      if (!fun)
            return false;

      vthread_t save_running = running_thread;
      running_thread = thr;
      value = vvp_vector4_t(fun->value_size(), BIT4_X);
      fun->vec4_value(value);
      running_thread = save_running;
      return true;
}

template <typename KEY>
static bool write_signal_assoc_key_(vthread_t thr, vvp_net_t*net,
				    const KEY&value, const char*why);

template <>
bool write_signal_assoc_key_<string>(vthread_t thr, vvp_net_t*net,
				     const string&value, const char*why)
{
      if (!(thr && net))
            return false;
      if (!signal_string_fun_(net))
            return false;

      vvp_send_string(vvp_net_ptr_t(net, 0), value,
		      ensure_write_context_(thr, why));
      return true;
}

template <>
bool write_signal_assoc_key_<vvp_object_t>(vthread_t thr, vvp_net_t*net,
					   const vvp_object_t&value, const char*why)
{
      if (!(thr && net))
            return false;
      if (!signal_object_fun_(net))
            return false;

      vvp_send_object(vvp_net_ptr_t(net, 0), value,
		      ensure_write_context_(thr, why));
      return true;
}

template <>
bool write_signal_assoc_key_<vvp_vector4_t>(vthread_t thr, vvp_net_t*net,
					    const vvp_vector4_t&value, const char*why)
{
      if (!(thr && net))
            return false;
      if (!signal_vec4_fun_(net))
            return false;

      vvp_send_vec4(vvp_net_ptr_t(net, 0), value,
		    ensure_write_context_(thr, why));
      return true;
}

template <class ASSOC>
static ASSOC* peek_assoc_receiver_(vthread_t thr, unsigned depth=0)
{
      static bool warned = false;
      vvp_assoc_base*assoc = thr->peek_object(depth).peek<vvp_assoc_base>();
      if (!assoc)
	    return 0;

      ASSOC*typed_assoc = dynamic_cast<ASSOC*>(assoc);
      if (!typed_assoc && !warned) {
	    cerr << thr->get_fileline()
	         << "Warning: assoc operation on unexpected container type."
	         << endl;
	    warned = true;
      }

      return typed_assoc;
}

template <class ASSOC>
static ASSOC* pop_assoc_receiver_(vthread_t thr)
{
      static bool warned = false;
      vvp_object_t recv;
      thr->pop_object(recv);
      vvp_assoc_base*assoc = recv.peek<vvp_assoc_base>();
      if (!assoc)
	    return 0;

      ASSOC*typed_assoc = dynamic_cast<ASSOC*>(assoc);
      if (!typed_assoc && !warned) {
	    cerr << thr->get_fileline()
	         << "Warning: assoc operation on unexpected container type."
	         << endl;
	    warned = true;
      }

      return typed_assoc;
}

template <typename ELEM, class ASSOC>
static bool aa_load_str(vthread_t thr, unsigned wid=0)
{
      string key = thr->pop_str();
      ELEM value;
      dq_default(value, wid);

      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr);
      if (assoc)
	    assoc->get(key, value);

      push_loaded_qo_value_(thr, value, wid);
      return true;
}

template <typename ELEM, class ASSOC>
static bool aa_load_obj(vthread_t thr, unsigned wid=0)
{
      vvp_object_t key;
      thr->pop_object(key);

      ELEM value;
      dq_default(value, wid);

      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr);
      if (assoc)
	    assoc->get(key, value);

      if (assoc_trace_scope_match_(thr)) {
            fprintf(stderr,
                    "trace assoc: op=load/obj scope=%s assoc=%p size=%zu key=%p key_class=%s value_class=%s\n",
                    scope_name_or_unknown_(thr ? thr->parent_scope : 0),
                    (void*)assoc,
                    assoc ? assoc->size() : 0,
                    (void*)key.peek<vvp_object>(),
                    object_trace_class_(key),
                    assoc_value_trace_class_(value));
      }

      push_loaded_qo_value_(thr, value, wid);
      return true;
}

template <typename ELEM, class ASSOC>
static bool aa_load_vec(vthread_t thr, unsigned wid=0)
{
      vvp_vector4_t key = thr->pop_vec4();
      ELEM value;
      dq_default(value, wid);

      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr);
      if (assoc)
	    assoc->get(key, value);

      push_loaded_qo_value_(thr, value, wid);
      return true;
}

template <typename ELEM, class ASSOC>
static bool aa_load_keep_str(vthread_t thr, unsigned wid=0)
{
      const string&key = thr->peek_str(0);
      ELEM value;
      dq_default(value, wid);

      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr);
      if (assoc)
	    assoc->get(key, value);

      push_loaded_qo_value_(thr, value, wid);
      return true;
}

template <typename ELEM, class ASSOC>
static bool aa_load_keep_obj(vthread_t thr, unsigned wid=0)
{
      vvp_object_t key = thr->peek_object(0);

      ELEM value;
      dq_default(value, wid);

      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr, 1);
      if (assoc)
	    assoc->get(key, value);

      push_loaded_qo_value_(thr, value, wid);
      return true;
}

template <typename ELEM, class ASSOC>
static bool aa_load_keep_vec(vthread_t thr, unsigned wid=0)
{
      const vvp_vector4_t&key = thr->peek_vec4(0);
      ELEM value;
      dq_default(value, wid);

      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr, 1);
      if (assoc)
	    assoc->get(key, value);

      push_loaded_qo_value_(thr, value, wid);
      return true;
}

template <typename ELEM, class ASSOC>
static bool aa_store_str(vthread_t thr, unsigned wid=0)
{
      ELEM value;
      pop_value(thr, value, wid);

      string key = thr->pop_str();
      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr);
      if (assoc)
	    assoc->set(key, value);

      return true;
}

template <typename ELEM, class ASSOC>
static bool aa_store_obj(vthread_t thr, unsigned wid=0)
{
      ELEM value;
      pop_value(thr, value, wid);

      vvp_object_t key;
      thr->pop_object(key);

      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr);
      if (assoc)
	    assoc->set(key, value);

      if (assoc_trace_scope_match_(thr)) {
            fprintf(stderr,
                    "trace assoc: op=store/obj scope=%s assoc=%p size=%zu key=%p key_class=%s value_class=%s\n",
                    scope_name_or_unknown_(thr ? thr->parent_scope : 0),
                    (void*)assoc,
                    assoc ? assoc->size() : 0,
                    (void*)key.peek<vvp_object>(),
                    object_trace_class_(key),
                    assoc_value_trace_class_(value));
      }

      return true;
}

template <typename ELEM, class ASSOC>
static bool aa_store_vec(vthread_t thr, unsigned wid=0)
{
      ELEM value;
      pop_value(thr, value, wid);

      vvp_vector4_t key = thr->pop_vec4();
      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr);
      if (assoc)
	    assoc->set(key, value);

      return true;
}

template <class ASSOC>
static bool aa_delete_str(vthread_t thr)
{
      string key = thr->pop_str();
      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr);
      if (assoc)
	    assoc->erase_key(key);
      return true;
}

template <class ASSOC>
static bool aa_delete_obj(vthread_t thr)
{
      vvp_object_t key;
      thr->pop_object(key);
      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr);
      if (assoc)
	    assoc->erase_key(key);
      return true;
}

template <class ASSOC>
static bool aa_delete_vec(vthread_t thr)
{
      vvp_vector4_t key = thr->pop_vec4();
      ASSOC*assoc = peek_assoc_receiver_<ASSOC>(thr);
      if (assoc)
	    assoc->erase_key(key);
      return true;
}

template <class ASSOC>
static bool aa_exists_str(vthread_t thr, unsigned wid)
{
      string key = thr->pop_str();
      ASSOC*assoc = pop_assoc_receiver_<ASSOC>(thr);
      vvp_vector4_t val(wid, (assoc && assoc->exists_key(key)) ? BIT4_1 : BIT4_0);
      thr->push_vec4(val);
      return true;
}

template <class ASSOC>
static bool aa_exists_vec(vthread_t thr, unsigned wid)
{
      vvp_vector4_t key = thr->pop_vec4();
      ASSOC*assoc = pop_assoc_receiver_<ASSOC>(thr);
      vvp_vector4_t val(wid, (assoc && assoc->exists_key(key)) ? BIT4_1 : BIT4_0);
      thr->push_vec4(val);
      return true;
}

template <class ASSOC>
static bool aa_exists_obj(vthread_t thr, unsigned wid)
{
      vvp_object_t key;
      thr->pop_object(key);
      ASSOC*assoc = pop_assoc_receiver_<ASSOC>(thr);
      if (assoc_trace_scope_match_(thr)) {
            fprintf(stderr,
                    "trace assoc: op=exists/obj scope=%s assoc=%p size=%zu key=%p key_class=%s exists=%d\n",
                    scope_name_or_unknown_(thr ? thr->parent_scope : 0),
                    (void*)assoc,
                    assoc ? assoc->size() : 0,
                    (void*)key.peek<vvp_object>(),
                    object_trace_class_(key),
                    (assoc && assoc->exists_key(key)) ? 1 : 0);
      }
      vvp_vector4_t val(wid, (assoc && assoc->exists_key(key)) ? BIT4_1 : BIT4_0);
      thr->push_vec4(val);
      return true;
}

template <typename KEY, class ASSOC>
static bool aa_exists_signal(vthread_t thr, vvp_net_t*net, unsigned wid)
{
      KEY key = pop_assoc_key_<KEY>(thr);
      ASSOC*assoc = peek_signal_assoc_<ASSOC>(net);
      vvp_vector4_t val(wid, (assoc && assoc->exists_key(key)) ? BIT4_1 : BIT4_0);
      thr->push_vec4(val);
      return true;
}

template <typename KEY>
static bool aa_traversal_finish_(vthread_t thr, vvp_net_t*key_net,
				 const KEY&key, bool ok,
				 unsigned wid, const char*why)
{
      if (ok && !write_signal_assoc_key_<KEY>(thr, key_net, key, why))
            ok = false;

      vvp_vector4_t val(wid, ok ? BIT4_1 : BIT4_0);
      thr->push_vec4(val);
      return true;
}

template <typename KEY, class ASSOC>
static bool aa_first(vthread_t thr, vvp_net_t*key_net, unsigned wid)
{
      KEY key;
      ASSOC*assoc = pop_assoc_receiver_<ASSOC>(thr);
      if (assoc_trace_scope_match_(thr)) {
            fprintf(stderr, "trace assoc: op=first-enter scope=%s assoc=%p\n",
                    scope_name_or_unknown_(thr ? thr->parent_scope : 0),
                    (void*)assoc);
      }
      bool ok = assoc && assoc->first_key(key);
      assoc_trace_traversal_(thr, "first", assoc, ok, key);
      return aa_traversal_finish_(thr, key_net, key, ok, wid, "aa-first");
}

template <typename KEY, class ASSOC>
static bool aa_last(vthread_t thr, vvp_net_t*key_net, unsigned wid)
{
      KEY key;
      ASSOC*assoc = pop_assoc_receiver_<ASSOC>(thr);
      if (assoc_trace_scope_match_(thr)) {
            fprintf(stderr, "trace assoc: op=last-enter scope=%s assoc=%p\n",
                    scope_name_or_unknown_(thr ? thr->parent_scope : 0),
                    (void*)assoc);
      }
      bool ok = assoc && assoc->last_key(key);
      assoc_trace_traversal_(thr, "last", assoc, ok, key);
      return aa_traversal_finish_(thr, key_net, key, ok, wid, "aa-last");
}

template <typename KEY, class ASSOC>
static bool aa_next(vthread_t thr, vvp_net_t*key_net, unsigned wid)
{
      KEY key;
      bool ok = read_signal_assoc_key_<KEY>(thr, key_net, key);
      ASSOC*assoc = pop_assoc_receiver_<ASSOC>(thr);
      if (assoc_trace_scope_match_(thr)) {
            fprintf(stderr, "trace assoc: op=next-enter scope=%s assoc=%p read_ok=%d\n",
                    scope_name_or_unknown_(thr ? thr->parent_scope : 0),
                    (void*)assoc, ok ? 1 : 0);
      }
      ok = assoc && ok && assoc->next_key(key);
      assoc_trace_traversal_(thr, "next", assoc, ok, key);
      return aa_traversal_finish_(thr, key_net, key, ok, wid, "aa-next");
}

template <typename KEY, class ASSOC>
static bool aa_prev(vthread_t thr, vvp_net_t*key_net, unsigned wid)
{
      KEY key;
      bool ok = read_signal_assoc_key_<KEY>(thr, key_net, key);
      ASSOC*assoc = pop_assoc_receiver_<ASSOC>(thr);
      if (assoc_trace_scope_match_(thr)) {
            fprintf(stderr, "trace assoc: op=prev-enter scope=%s assoc=%p read_ok=%d\n",
                    scope_name_or_unknown_(thr ? thr->parent_scope : 0),
                    (void*)assoc, ok ? 1 : 0);
      }
      ok = assoc && ok && assoc->prev_key(key);
      assoc_trace_traversal_(thr, "prev", assoc, ok, key);
      return aa_traversal_finish_(thr, key_net, key, ok, wid, "aa-prev");
}

template <typename KEY, class ASSOC>
static bool aa_first_signal(vthread_t thr, vvp_net_t*recv_net,
			    vvp_net_t*key_net, unsigned wid)
{
      KEY key;
      ASSOC*assoc = peek_signal_assoc_<ASSOC>(recv_net);
      bool ok = assoc && assoc->first_key(key);
      assoc_trace_traversal_(thr, "first-sig", assoc, ok, key);
      return aa_traversal_finish_(thr, key_net, key, ok, wid, "aa-first-sig");
}

template <typename KEY, class ASSOC>
static bool aa_last_signal(vthread_t thr, vvp_net_t*recv_net,
			   vvp_net_t*key_net, unsigned wid)
{
      KEY key;
      ASSOC*assoc = peek_signal_assoc_<ASSOC>(recv_net);
      bool ok = assoc && assoc->last_key(key);
      assoc_trace_traversal_(thr, "last-sig", assoc, ok, key);
      return aa_traversal_finish_(thr, key_net, key, ok, wid, "aa-last-sig");
}

template <typename KEY, class ASSOC>
static bool aa_next_signal(vthread_t thr, vvp_net_t*recv_net,
			   vvp_net_t*key_net, unsigned wid)
{
      KEY key;
      bool ok = read_signal_assoc_key_<KEY>(thr, key_net, key);
      ASSOC*assoc = peek_signal_assoc_<ASSOC>(recv_net);
      ok = assoc && ok && assoc->next_key(key);
      assoc_trace_traversal_(thr, "next-sig", assoc, ok, key);
      return aa_traversal_finish_(thr, key_net, key, ok, wid, "aa-next-sig");
}

template <typename KEY, class ASSOC>
static bool aa_prev_signal(vthread_t thr, vvp_net_t*recv_net,
			   vvp_net_t*key_net, unsigned wid)
{
      KEY key;
      bool ok = read_signal_assoc_key_<KEY>(thr, key_net, key);
      ASSOC*assoc = peek_signal_assoc_<ASSOC>(recv_net);
      ok = assoc && ok && assoc->prev_key(key);
      assoc_trace_traversal_(thr, "prev-sig", assoc, ok, key);
      return aa_traversal_finish_(thr, key_net, key, ok, wid, "aa-prev-sig");
}

template <typename KEY, typename ELEM, class ASSOC>
static bool aa_load_signal(vthread_t thr, vvp_net_t*net, unsigned wid=0)
{
      KEY key = pop_assoc_key_<KEY>(thr);
      ELEM value;
      dq_default(value, wid);

      ASSOC*assoc = peek_signal_assoc_<ASSOC>(net);
      if (assoc)
            assoc->get(key, value);

      assoc_trace_signal_load_(thr, net, assoc, key, value);

      push_loaded_qo_value_(thr, value, wid);
      return true;
}

template <typename KEY, typename ELEM, class ASSOC>
static bool aa_store_signal(vthread_t thr, vvp_net_t*net, unsigned wid=0)
{
      ELEM value;
      pop_value(thr, value, wid);

      KEY key = pop_assoc_key_<KEY>(thr);
      ASSOC*assoc = ensure_signal_assoc_<ASSOC>(thr, net, "aa-store-sig");
      if (assoc)
            assoc->set(key, value);

      assoc_trace_signal_store_(thr, net, assoc, key, value);

      return true;
}

template <typename ELEM, class QTYPE>
static bool load_qo(vthread_t thr, unsigned wid=0)
{
      int64_t adr = thr->words[3].w_int;
      ELEM word;
      dq_default(word, wid);

      vvp_object_t recv;
      QTYPE*queue = pop_queue_receiver_<QTYPE>(thr, recv);
      if (queue &&
          (adr >= 0) &&
          (thr->flags[4] == BIT4_0) &&
          (static_cast<size_t>(adr) < queue->get_size()))
	    queue->get_word(adr, word);

      push_loaded_qo_value_(thr, word, wid);
      return true;
}

bool of_LOAD_QO_R(vthread_t thr, vvp_code_t)
{
      return load_qo<double, vvp_queue_real>(thr);
}

bool of_LOAD_QO_STR(vthread_t thr, vvp_code_t)
{
      return load_qo<string, vvp_queue_string>(thr);
}

bool of_LOAD_QO_V(vthread_t thr, vvp_code_t cp)
{
      return load_qo<vvp_vector4_t, vvp_queue_vec4>(thr, cp->bit_idx[0]);
}

bool of_LOAD_QO_OBJ(vthread_t thr, vvp_code_t)
{
      return load_qo<vvp_object_t, vvp_queue_object>(thr);
}

bool of_AA_LOAD_OBJ_OBJ(vthread_t thr, vvp_code_t)
{
      return aa_load_obj<vvp_object_t, vvp_assoc_object>(thr);
}

bool of_AA_LOAD_OBJ_STR(vthread_t thr, vvp_code_t)
{
      return aa_load_str<vvp_object_t, vvp_assoc_object>(thr);
}

bool of_AA_LOAD_OBJ_V(vthread_t thr, vvp_code_t)
{
      return aa_load_vec<vvp_object_t, vvp_assoc_object>(thr);
}

bool of_AA_LOADK_R_OBJ(vthread_t thr, vvp_code_t)
{
      return aa_load_keep_obj<double, vvp_assoc_real>(thr);
}

bool of_AA_LOADK_R_STR(vthread_t thr, vvp_code_t)
{
      return aa_load_keep_str<double, vvp_assoc_real>(thr);
}

bool of_AA_LOADK_R_V(vthread_t thr, vvp_code_t)
{
      return aa_load_keep_vec<double, vvp_assoc_real>(thr);
}

bool of_AA_LOADK_V_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_load_keep_obj<vvp_vector4_t, vvp_assoc_vec4>(thr, cp->bit_idx[0]);
}

bool of_AA_LOADK_V_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_load_keep_str<vvp_vector4_t, vvp_assoc_vec4>(thr, cp->bit_idx[0]);
}

bool of_AA_LOADK_V_V(vthread_t thr, vvp_code_t cp)
{
      return aa_load_keep_vec<vvp_vector4_t, vvp_assoc_vec4>(thr, cp->bit_idx[0]);
}

bool of_AA_LOAD_R_OBJ(vthread_t thr, vvp_code_t)
{
      return aa_load_obj<double, vvp_assoc_real>(thr);
}

bool of_AA_LOAD_R_STR(vthread_t thr, vvp_code_t)
{
      return aa_load_str<double, vvp_assoc_real>(thr);
}

bool of_AA_LOAD_R_V(vthread_t thr, vvp_code_t)
{
      return aa_load_vec<double, vvp_assoc_real>(thr);
}

bool of_AA_LOAD_STR_OBJ(vthread_t thr, vvp_code_t)
{
      return aa_load_obj<string, vvp_assoc_string>(thr);
}

bool of_AA_LOAD_STR_STR(vthread_t thr, vvp_code_t)
{
      return aa_load_str<string, vvp_assoc_string>(thr);
}

bool of_AA_LOAD_STR_V(vthread_t thr, vvp_code_t)
{
      return aa_load_vec<string, vvp_assoc_string>(thr);
}

bool of_AA_LOAD_V_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_load_obj<vvp_vector4_t, vvp_assoc_vec4>(thr, cp->bit_idx[0]);
}

bool of_AA_LOAD_V_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_load_str<vvp_vector4_t, vvp_assoc_vec4>(thr, cp->bit_idx[0]);
}

bool of_AA_LOAD_V_V(vthread_t thr, vvp_code_t cp)
{
      return aa_load_vec<vvp_vector4_t, vvp_assoc_vec4>(thr, cp->bit_idx[0]);
}

bool of_AA_STORE_OBJ_OBJ(vthread_t thr, vvp_code_t)
{
      return aa_store_obj<vvp_object_t, vvp_assoc_object>(thr);
}

bool of_AA_STORE_OBJ_STR(vthread_t thr, vvp_code_t)
{
      return aa_store_str<vvp_object_t, vvp_assoc_object>(thr);
}

bool of_AA_STORE_OBJ_V(vthread_t thr, vvp_code_t)
{
      return aa_store_vec<vvp_object_t, vvp_assoc_object>(thr);
}

bool of_AA_STORE_R_OBJ(vthread_t thr, vvp_code_t)
{
      return aa_store_obj<double, vvp_assoc_real>(thr);
}

bool of_AA_STORE_R_STR(vthread_t thr, vvp_code_t)
{
      return aa_store_str<double, vvp_assoc_real>(thr);
}

bool of_AA_STORE_R_V(vthread_t thr, vvp_code_t)
{
      return aa_store_vec<double, vvp_assoc_real>(thr);
}

bool of_AA_STORE_STR_OBJ(vthread_t thr, vvp_code_t)
{
      return aa_store_obj<string, vvp_assoc_string>(thr);
}

bool of_AA_STORE_STR_STR(vthread_t thr, vvp_code_t)
{
      return aa_store_str<string, vvp_assoc_string>(thr);
}

bool of_AA_STORE_STR_V(vthread_t thr, vvp_code_t)
{
      return aa_store_vec<string, vvp_assoc_string>(thr);
}

bool of_AA_STORE_V_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_store_obj<vvp_vector4_t, vvp_assoc_vec4>(thr, cp->bit_idx[0]);
}

bool of_AA_STORE_V_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_store_str<vvp_vector4_t, vvp_assoc_vec4>(thr, cp->bit_idx[0]);
}

bool of_AA_STORE_V_V(vthread_t thr, vvp_code_t cp)
{
      return aa_store_vec<vvp_vector4_t, vvp_assoc_vec4>(thr, cp->bit_idx[0]);
}

bool of_AA_DELETE_OBJ(vthread_t thr, vvp_code_t)
{
      return aa_delete_obj<vvp_assoc_base>(thr);
}

bool of_AA_DELETE_STR(vthread_t thr, vvp_code_t)
{
      return aa_delete_str<vvp_assoc_base>(thr);
}

bool of_AA_DELETE_V(vthread_t thr, vvp_code_t)
{
      return aa_delete_vec<vvp_assoc_base>(thr);
}

bool of_AA_EXISTS_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_exists_obj<vvp_assoc_base>(thr, cp->number);
}

bool of_AA_EXISTS_SIG_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_exists_signal<vvp_object_t, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_EXISTS_SIG_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_exists_signal<string, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_EXISTS_SIG_V(vthread_t thr, vvp_code_t cp)
{
      return aa_exists_signal<vvp_vector4_t, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_EXISTS_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_exists_str<vvp_assoc_base>(thr, cp->number);
}

bool of_AA_EXISTS_V(vthread_t thr, vvp_code_t cp)
{
      return aa_exists_vec<vvp_assoc_base>(thr, cp->number);
}

bool of_AA_FIRST_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_first<vvp_object_t, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_FIRST_SIG_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_first_signal<vvp_object_t, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_FIRST_SIG_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_first_signal<string, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_FIRST_SIG_V(vthread_t thr, vvp_code_t cp)
{
      return aa_first_signal<vvp_vector4_t, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_FIRST_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_first<string, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_FIRST_V(vthread_t thr, vvp_code_t cp)
{
      return aa_first<vvp_vector4_t, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_LAST_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_last<vvp_object_t, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_LAST_SIG_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_last_signal<vvp_object_t, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_LAST_SIG_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_last_signal<string, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_LAST_SIG_V(vthread_t thr, vvp_code_t cp)
{
      return aa_last_signal<vvp_vector4_t, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_LAST_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_last<string, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_LAST_V(vthread_t thr, vvp_code_t cp)
{
      return aa_last<vvp_vector4_t, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_NEXT_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_next<vvp_object_t, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_NEXT_SIG_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_next_signal<vvp_object_t, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_NEXT_SIG_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_next_signal<string, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_NEXT_SIG_V(vthread_t thr, vvp_code_t cp)
{
      return aa_next_signal<vvp_vector4_t, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_NEXT_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_next<string, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_NEXT_V(vthread_t thr, vvp_code_t cp)
{
      return aa_next<vvp_vector4_t, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_PREV_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_prev<vvp_object_t, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_PREV_SIG_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_prev_signal<vvp_object_t, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_PREV_SIG_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_prev_signal<string, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_PREV_SIG_V(vthread_t thr, vvp_code_t cp)
{
      return aa_prev_signal<vvp_vector4_t, vvp_assoc_base>(thr, cp->net, cp->net2, 1);
}

bool of_AA_PREV_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_prev<string, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_PREV_V(vthread_t thr, vvp_code_t cp)
{
      return aa_prev<vvp_vector4_t, vvp_assoc_base>(thr, cp->net, cp->bit_idx[0]);
}

bool of_AA_LOAD_SIG_OBJ_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_load_signal<vvp_object_t, vvp_object_t, vvp_assoc_object>(thr, cp->net);
}

bool of_AA_LOAD_SIG_OBJ_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_load_signal<string, vvp_object_t, vvp_assoc_object>(thr, cp->net);
}

bool of_AA_LOAD_SIG_OBJ_V(vthread_t thr, vvp_code_t cp)
{
      return aa_load_signal<vvp_vector4_t, vvp_object_t, vvp_assoc_object>(thr, cp->net);
}

bool of_AA_LOAD_SIG_R_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_load_signal<vvp_object_t, double, vvp_assoc_real>(thr, cp->net);
}

bool of_AA_LOAD_SIG_STR_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_load_signal<vvp_object_t, string, vvp_assoc_string>(thr, cp->net);
}

bool of_AA_LOAD_SIG_V_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_load_signal<vvp_object_t, vvp_vector4_t, vvp_assoc_vec4>(thr, cp->net,
                                                                         cp->bit_idx[0]);
}

/*
 * %load/obj <var-label>
 */
bool of_LOAD_OBJ(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;
      vvp_fun_signal_object*fun = signal_object_fun_(net);
      if (!fun) {
	    static bool warned_missing_fun = false;
	    if (!warned_missing_fun) {
		  cerr << thr->get_fileline()
		       << "Warning: %load/obj without object functor; pushing nil"
		       << " (further similar warnings suppressed)." << endl;
		  warned_missing_fun = true;
	    }
	    vvp_object_t nil;
	    thr->push_object(nil);
	    return true;
      }

      vvp_object_t val = fun->get_object();
      vvp_net_t*root_net = fun->get_root_net();
      vvp_object_t root_obj = fun->get_root_object();
      if (!root_net || root_obj.test_nil()) {
            root_net = net;
            root_obj = val;
      }

      static int trace_store_obj_enabled = -1;
      if (trace_store_obj_enabled < 0) {
            const char*env = getenv("IVL_STORE_OBJ_TRACE");
            trace_store_obj_enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      if (trace_store_obj_enabled) {
            const char*scope_name = (thr && thr->parent_scope)
                                  ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
            const char*env = getenv("IVL_STORE_OBJ_TRACE");
            bool trace_this = true;
            if (env && *env
                && strcmp(env, "1") != 0 && strcmp(env, "ALL") != 0 && strcmp(env, "*") != 0) {
                  trace_this = (scope_name && strstr(scope_name, env));
            }
            if (trace_this) {
                  const char*fun_kind = "other";
                  if (net->fun) {
                        if (dynamic_cast<vvp_fun_signal_object_sa*>(net->fun))
                              fun_kind = "object_sa";
                        else if (dynamic_cast<vvp_fun_signal_object_aa*>(net->fun))
                              fun_kind = "object_aa";
                  }
                  fprintf(stderr,
                          "trace load_obj  scope=%s net=%p fun=%s val_nil=%d val=%p class=%s wt=%p rd=%p\n",
                          scope_name ? scope_name : "<unknown>",
                          (void*)net, fun_kind, val.test_nil() ? 1 : 0,
                          val.peek<vvp_object>(),
                          object_trace_class_(val),
                          thr ? thr->wt_context : 0, thr ? thr->rd_context : 0);
            }
      }

      thr->push_object(val, root_net, root_obj);

      return true;
}

/*
 * %load/obja <index>
 *    Loads the object from array, using index <index> as the index
 *    value. If flags[4] == 1, the calculation of <index> may have
 *    failed, so push nil.
 */
bool of_LOAD_OBJA(vthread_t thr, vvp_code_t cp)
{
      unsigned idx = cp->bit_idx[0];
      vvp_object_t word;
      vvp_array_t array = resolve_runtime_array_(cp, "%load/obja");

	/* Guard against unresolved null array stub. */
      if (!array) {
	    thr->push_object(word); // push nil
	    return true;
      }

	/* The result is 0.0 if the address is undefined. */
      if (thr->flags[4] == BIT4_1) {
	    ; // Return nil
      } else {
	    unsigned adr = thr->words[idx].w_int;
	    array->get_word_obj(adr, word);
      }

      thr->push_object(word);
      return true;
}

/*
 * %load/real <var-label>
 */
bool of_LOAD_REAL(vthread_t thr, vvp_code_t cp)
{
      __vpiHandle*tmp = cp->handle;
      t_vpi_value val;

      val.format = vpiRealVal;
      vpi_get_value(tmp, &val);

      thr->push_real(val.value.real);

      return true;
}

/*
 * %load/str <var-label>
 */
bool of_LOAD_STR(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;


      vvp_fun_signal_string*fun = dynamic_cast<vvp_fun_signal_string*> (net->fun);
      assert(fun);

      const string&val = fun->get_string();
      if (load_str_trace_scope_match_(thr ? thr->parent_scope : 0)) {
            __vpiScope*item_scope = 0;
            vpiHandle item = lookup_scope_item_by_net_chain_(thr ? thr->parent_scope : 0,
                                                             net, &item_scope);
            const char*item_name = item ? vpi_get_str(vpiName, item) : 0;
            fprintf(stderr,
                    "trace load_str-op scope=%s item_scope=%s item=%s net=%p len=%zu text=\"%.*s\"\n",
                    thr ? scope_name_or_unknown_(thr->parent_scope) : "<null>",
                    scope_name_or_unknown_(item_scope),
                    item_name ? item_name : "<unknown>",
                    (void*)net, val.size(),
                    (int)(val.size() < 80 ? val.size() : 80), val.c_str());
      }
      thr->push_str(val);

      return true;
}

bool of_LOAD_STRA(vthread_t thr, vvp_code_t cp)
{
      unsigned idx = cp->bit_idx[0];
      string word;
      vvp_array_t array = resolve_runtime_array_(cp, "%load/stra");

      if (thr->flags[4] == BIT4_1) {
	    word = "";
      } else {
	    unsigned adr = thr->words[idx].w_int;
	    word = array ? array->get_word_str(adr) : "";
      }

      thr->push_str(word);
      return true;
}


/*
 * %load/vec4 <net>
 */
bool of_LOAD_VEC4(vthread_t thr, vvp_code_t cp)
{
	// Push a placeholder onto the stack in order to reserve the
	// stack space. Use a reference for the stack top as a target
	// for the load.
      thr->push_vec4(vvp_vector4_t());
      vvp_vector4_t&sig_value = thr->peek_vec4();

      vvp_net_t*net = cp->net;

	// For the %load to work, the functor must actually be a
	// signal functor. Only signals save their vector value.
      vvp_signal_value*sig = dynamic_cast<vvp_signal_value*> (net->fil);
      if (sig == 0) {
	    cerr << thr->get_fileline()
	         << "%load/v error: Net arg not a signal? "
		 << (net->fil ? typeid(*net->fil).name() :
	                        typeid(*net->fun).name())
	         << endl;
	    assert(sig);
	    return true;
      }

	// Extract the value from the signal and directly into the
	// target stack position.
      sig->vec4_value(sig_value);

      return true;
}

/*
 * %load/vec4a <arr>, <adrx>
 */
bool of_LOAD_VEC4A(vthread_t thr, vvp_code_t cp)
{
      int adr_index = cp->bit_idx[0];
      vvp_array_t array = resolve_runtime_array_(cp, "%load/vec4a");

      long adr = thr->words[adr_index].w_int;

	// If flag[3] is set, then the calculation of the address
	// failed, and this load should return X instead of the actual
	// value.
      if (thr->flags[4] == BIT4_1) {
	    vvp_vector4_t tmp (array ? array->get_word_size() : 1, BIT4_X);
	    thr->push_vec4(tmp);
	    return true;
      }

      if (!array) {
	    thr->push_vec4(vvp_vector4_t(1, BIT4_X));
	    return true;
      }

      vvp_vector4_t tmp (array->get_word(adr));
      thr->push_vec4(tmp);
      return true;
}

static void do_verylong_mod(vvp_vector4_t&vala, const vvp_vector4_t&valb,
			    bool left_is_neg, bool right_is_neg)
{
      bool out_is_neg = left_is_neg;
      const int len=vala.size();
      unsigned char *a, *z, *t;
      a = new unsigned char[len+1];
      z = new unsigned char[len+1];
      t = new unsigned char[len+1];

      unsigned char carry;
      unsigned char temp;

      int mxa = -1, mxz = -1;
      int i;
      int current, copylen;

      unsigned lb_carry = left_is_neg? 1 : 0;
      unsigned rb_carry = right_is_neg? 1 : 0;
      for (int idx = 0 ;  idx < len ;  idx += 1) {
	    unsigned lb = vala.value(idx);
	    unsigned rb = valb.value(idx);

	    if ((lb | rb) & 2) {
		  delete []t;
		  delete []z;
		  delete []a;
		  vvp_vector4_t tmp(len, BIT4_X);
		  vala = tmp;
		  return;
	    }

	    if (left_is_neg) {
		  lb = (1-lb) + lb_carry;
		  lb_carry = (lb & ~1)? 1 : 0;
		  lb &= 1;
	    }
	    if (right_is_neg) {
		  rb = (1-rb) + rb_carry;
		  rb_carry = (rb & ~1)? 1 : 0;
		  rb &= 1;
	    }

	    z[idx]=lb;
	    a[idx]=1-rb;	// for 2s complement add..
      }

      z[len]=0;
      a[len]=1;

      for(i=len-1;i>=0;i--) {
	    if(! a[i]) {
		  mxa=i;
		  break;
	    }
      }

      for(i=len-1;i>=0;i--) {
	    if(z[i]) {
		  mxz=i;
		  break;
	    }
      }

      if((mxa>mxz)||(mxa==-1)) {
	    if(mxa==-1) {
		  delete []t;
		  delete []z;
		  delete []a;
		  vvp_vector4_t tmpx (len, BIT4_X);
		  vala = tmpx;
		  return;
	    }

	    goto tally;
      }

      copylen = mxa + 2;
      current = mxz - mxa;

      while(current > -1) {
	    carry = 1;
	    for(i=0;i<copylen;i++) {
		  temp = z[i+current] + a[i] + carry;
		  t[i] = (temp&1);
		  carry = (temp>>1);
	    }

	    if(carry) {
		  for(i=0;i<copylen;i++) {
			z[i+current] = t[i];
		  }
	    }

	    current--;
      }

 tally:

      vvp_vector4_t tmp (len, BIT4_X);
      carry = out_is_neg? 1 : 0;
      for (int idx = 0 ;  idx < len ;  idx += 1) {
	    unsigned ob = z[idx];
	    if (out_is_neg) {
		  ob = (1-ob) + carry;
		  carry = (ob & ~1)? 1 : 0;
		  ob = ob & 1;
	    }
	    tmp.set_bit(idx, ob?BIT4_1:BIT4_0);
      }
      vala = tmp;
      delete []t;
      delete []z;
      delete []a;
}

bool of_MAX_WR(vthread_t thr, vvp_code_t)
{
      double r = thr->pop_real();
      double l = thr->pop_real();
      if (r != r)
	    thr->push_real(l);
      else if (l != l)
	    thr->push_real(r);
      else if (r < l)
	    thr->push_real(l);
      else
	    thr->push_real(r);
      return true;
}

bool of_MIN_WR(vthread_t thr, vvp_code_t)
{
      double r = thr->pop_real();
      double l = thr->pop_real();
      if (r != r)
	    thr->push_real(l);
      else if (l != l)
	    thr->push_real(r);
      else if (r < l)
	    thr->push_real(r);
      else
	    thr->push_real(l);
      return true;
}

bool of_MOD(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t valb = thr->pop_vec4();
      vvp_vector4_t&vala = thr->peek_vec4();

      assert(vala.size()==valb.size());
      unsigned wid = vala.size();

      if(wid <= 8*sizeof(unsigned long long)) {
	    unsigned long long lv = 0, rv = 0;

	    for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {
		  unsigned long long lb = vala.value(idx);
		  unsigned long long rb = valb.value(idx);

		  if ((lb | rb) & 2)
			goto x_out;

		  lv |= (unsigned long long) lb << idx;
		  rv |= (unsigned long long) rb << idx;
	    }

	    if (rv == 0)
		  goto x_out;

	    lv %= rv;

	    for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {
		  vala.set_bit(idx, (lv&1)?BIT4_1 : BIT4_0);
		  lv >>= 1;
	    }

	    return true;

      } else {
	    do_verylong_mod(vala, valb, false, false);
	    return true;
      }

 x_out:
      vala = vvp_vector4_t(wid, BIT4_X);
      return true;
}

/*
 * %mod/s
 */
bool of_MOD_S(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t valb = thr->pop_vec4();
      vvp_vector4_t&vala = thr->peek_vec4();

      assert(vala.size()==valb.size());
      unsigned wid = vala.size();

	/* Handle the case that we can fit the bits into a long-long
	   variable. We cause use native % to do the work. */
      if(wid <= 8*sizeof(long long)) {
	    long long lv = 0, rv = 0;

	    for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {
		  long long lb = vala.value(idx);
		  long long rb = valb.value(idx);

		  if ((lb | rb) & 2)
			goto x_out;

		  lv |= (long long) lb << idx;
		  rv |= (long long) rb << idx;
	    }

	    if (rv == 0)
		  goto x_out;

	    if ((lv == LLONG_MIN) && (rv == -1))
		  goto zero_out;

	      /* Sign extend the signed operands when needed. */
	    if (wid < 8*sizeof(long long)) {
		  if (lv & (1LL << (wid-1)))
			lv |= -1ULL << wid;
		  if (rv & (1LL << (wid-1)))
			rv |= -1ULL << wid;
	    }

	    lv %= rv;

	    for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {
		  vala.set_bit(idx, (lv&1)? BIT4_1 : BIT4_0);
		  lv >>= 1;
	    }

	      // vala is the top of the stack, edited in place, so we
	      // do not need to push the result.

	    return true;

      } else {

	    bool left_is_neg  = vala.value(vala.size()-1) == BIT4_1;
	    bool right_is_neg = valb.value(valb.size()-1) == BIT4_1;
	    do_verylong_mod(vala, valb, left_is_neg, right_is_neg);
	    return true;
      }

 x_out:
      vala = vvp_vector4_t(wid, BIT4_X);
      return true;
 zero_out:
      vala = vvp_vector4_t(wid, BIT4_0);
      return true;
}

/*
 * %mod/wr
 */
bool of_MOD_WR(vthread_t thr, vvp_code_t)
{
      double r = thr->pop_real();
      double l = thr->pop_real();
      thr->push_real(fmod(l,r));

      return true;
}

/*
 * %pad/s <wid>
 */
bool of_PAD_S(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;

      vvp_vector4_t&val = thr->peek_vec4();
      unsigned old_size = val.size();

	// Sign-extend.
      if (old_size < wid)
	    val.resize(wid, val.value(old_size-1));
      else
	    val.resize(wid);

      return true;
}

/*
 * %pad/u <wid>
 */
bool of_PAD_U(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;

      vvp_vector4_t&val = thr->peek_vec4();
      val.resize(wid, BIT4_0);

      return true;
}

/*
 * %part/s <wid>
 * %part/u <wid>
 * Two values are popped from the stack. First, pop the canonical
 * index of the part select, and second is the value to be
 * selected. The result is pushed back to the stack.
 */
static bool of_PART_base(vthread_t thr, vvp_code_t cp, bool signed_flag)
{
      unsigned wid = cp->number;

      vvp_vector4_t base4 = thr->pop_vec4();
      vvp_vector4_t&value = thr->peek_vec4();

      vvp_vector4_t res (wid, BIT4_X);

	// NOTE: This is treating the vector as signed. Is that correct?
      int32_t base;
      bool value_ok = vector4_to_value(base4, base, signed_flag);
      if (! value_ok) {
	    value = res;
	    return true;
      }

      if (base >= (int32_t)value.size()) {
	    value = res;
	    return true;
      }

      if ((base+(int)wid) <= 0) {
	    value = res;
	    return true;
      }

      long vbase = 0;
      if (base < 0) {
	    vbase = -base;
	    wid -= vbase;
	    base = 0;
      }

      if ((base+wid) > value.size()) {
	    wid = value.size() - base;
      }

      res .set_vec(vbase, value.subvalue(base, wid));
      value = res;

      return true;
}

bool of_PART_S(vthread_t thr, vvp_code_t cp)
{
      return of_PART_base(thr, cp, true);
}

bool of_PART_U(vthread_t thr, vvp_code_t cp)
{
      return of_PART_base(thr, cp, false);
}

/*
 * %parti/s <wid>, <basei>, <base_wid>
 * %parti/u <wid>, <basei>, <base_wid>
 *
 * Pop the value to be selected. The result is pushed back to the stack.
 */
static bool of_PARTI_base(vthread_t thr, vvp_code_t cp, bool signed_flag)
{
      unsigned wid = cp->number;
      uint32_t base = cp->bit_idx[0];
      uint32_t bwid = cp->bit_idx[1];

      vvp_vector4_t&value = thr->peek_vec4();

      vvp_vector4_t res (wid, BIT4_X);

	// NOTE: This is treating the vector as signed. Is that correct?
      int32_t use_base = base;
      if (signed_flag && bwid < 32 && (base&(1<<(bwid-1)))) {
	    use_base |= -1UL << bwid;
      }

      if (use_base >= (int32_t)value.size()) {
	    value = res;
	    return true;
      }

      if ((use_base+(int32_t)wid) <= 0) {
	    value = res;
	    return true;
      }

      long vbase = 0;
      if (use_base < 0) {
	    vbase = -use_base;
	    wid -= vbase;
	    use_base = 0;
      }

      if ((use_base+wid) > value.size()) {
	    wid = value.size() - use_base;
      }

      res .set_vec(vbase, value.subvalue(use_base, wid));
      value = res;

      return true;
}

bool of_PARTI_S(vthread_t thr, vvp_code_t cp)
{
      return of_PARTI_base(thr, cp, true);
}

bool of_PARTI_U(vthread_t thr, vvp_code_t cp)
{
      return of_PARTI_base(thr, cp, false);
}

/*
 * %mul
 */
bool of_MUL(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t r = thr->pop_vec4();
	// Rather then pop l, use it directly from the stack. When we
	// assign to 'l', that will edit the top of the stack, which
	// replaces a pop and a pull.
      vvp_vector4_t&l = thr->peek_vec4();

      l.mul(r);
      return true;
}

/*
 * %muli <vala>, <valb>, <wid>
 *
 * Pop1 operand, get the other operand from the arguments, and push
 * the result.
 */
bool of_MULI(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;

      vvp_vector4_t&l = thr->peek_vec4();

	// I expect that most of the bits of an immediate value are
	// going to be zero, so start the result vector with all zero
	// bits. Then we only need to replace the bits that are different.
      vvp_vector4_t r (wid, BIT4_0);
      get_immediate_rval (cp, r);

      l.mul(r);
      return true;
}

bool of_MUL_WR(vthread_t thr, vvp_code_t)
{
      double r = thr->pop_real();
      double l = thr->pop_real();
      thr->push_real(l * r);

      return true;
}

bool of_NAND(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t valr = thr->pop_vec4();
      vvp_vector4_t&vall = thr->peek_vec4();
      assert(vall.size() == valr.size());
      unsigned wid = vall.size();

      for (unsigned idx = 0 ; idx < wid ; idx += 1) {
	    vvp_bit4_t lb = vall.value(idx);
	    vvp_bit4_t rb = valr.value(idx);
	    vall.set_bit(idx, ~(lb&rb));
      }

      return true;
}

/*
 * %new/cobj <vpi_object>
 * This creates a new cobject (SystemVerilog class object) and pushes
 * it to the stack. The <vpi-object> is a __vpiHandle that is a
 * vpiClassDefn object that defines the item to be created.
 */
bool of_NEW_COBJ(vthread_t thr, vvp_code_t cp)
{
      const class_type*defn = dynamic_cast<const class_type*> (cp->handle);
      assert(defn);

      vvp_object_t tmp (new vvp_cobject(defn));
      thr->push_object(tmp);
      return true;
}

bool of_NEW_VIF(vthread_t thr, vvp_code_t cp)
{
      __vpiScope*scope = dynamic_cast<__vpiScope*> (cp->handle);
      const class_type*defn = reinterpret_cast<const class_type*> (cp->cptr2);

      if (!scope || !defn) {
	    thr->push_object(vvp_object_t());
	    return true;
      }

      vvp_object_t tmp (new vvp_vinterface(scope, defn));
      thr->push_object(tmp);
      return true;
}

static vthread_t logical_process_thread_(vthread_t thr)
{
      while (thr && thr->is_callf_child && thr->parent)
	    thr = thr->parent;
      return thr;
}

static void process_status_to_vec4_(unsigned status, vvp_vector4_t&val)
{
      val = vvp_vector4_t(32, BIT4_0);
      for (unsigned idx = 0 ; idx < 32 ; idx += 1) {
	    if ((status >> idx) & 1U)
		  val.set_bit(idx, BIT4_1);
      }
}

bool of_PROCESS_SELF(vthread_t thr, vvp_code_t)
{
      vthread_t owner = logical_process_thread_(thr);
      if (!owner) {
	    thr->push_object(vvp_object_t());
	    return true;
      }

      thr->push_object(owner->process_obj_);
      return true;
}

bool of_PROCESS_AWAIT(vthread_t thr, vvp_code_t)
{
      vvp_object_t obj;
      thr->pop_object(obj);

      vvp_process*proc = obj.peek<vvp_process>();
      if (!proc)
	    return true;

      unsigned status = proc->status();
      if (status == PROCESS_STATE_FINISHED || status == PROCESS_STATE_KILLED)
	    return true;

      proc->add_waiter(thr);
      return false;
}

bool of_PROCESS_KILL(vthread_t thr, vvp_code_t)
{
      vvp_object_t obj;
      thr->pop_object(obj);

      vvp_process*proc = obj.peek<vvp_process>();
      if (!proc)
	    return true;

      vthread_t target = proc->owner();
      if (!target)
	    return true;

      unsigned status = proc->status();
      if (status == PROCESS_STATE_FINISHED || status == PROCESS_STATE_KILLED)
	    return true;

      vthread_t self_process = logical_process_thread_(thr);
      bool self_kill = (target == thr) || (target == self_process);

      (void)do_disable(target, target);
      return !self_kill;
}

bool of_NEW_DARRAY(vthread_t thr, vvp_code_t cp)
{
      const char*text = cp->text;
      size_t size = thr->words[cp->bit_idx[0]].w_int;
      unsigned word_wid;
      size_t n;

      vvp_object_t obj;
      if (strcmp(text,"b8") == 0) {
	    obj = new vvp_darray_atom<uint8_t>(size);
      } else if (strcmp(text,"b16") == 0) {
	    obj = new vvp_darray_atom<uint16_t>(size);
      } else if (strcmp(text,"b32") == 0) {
	    obj = new vvp_darray_atom<uint32_t>(size);
      } else if (strcmp(text,"b64") == 0) {
	    obj = new vvp_darray_atom<uint64_t>(size);
      } else if (strcmp(text,"sb8") == 0) {
	    obj = new vvp_darray_atom<int8_t>(size);
      } else if (strcmp(text,"sb16") == 0) {
	    obj = new vvp_darray_atom<int16_t>(size);
      } else if (strcmp(text,"sb32") == 0) {
	    obj = new vvp_darray_atom<int32_t>(size);
      } else if (strcmp(text,"sb64") == 0) {
	    obj = new vvp_darray_atom<int64_t>(size);
      } else if ((1 == sscanf(text, "b%u%zn", &word_wid, &n)) &&
                 (n == strlen(text))) {
	    obj = new vvp_darray_vec2(size, word_wid);
      } else if ((1 == sscanf(text, "sb%u%zn", &word_wid, &n)) &&
                 (n == strlen(text))) {
	    obj = new vvp_darray_vec2(size, word_wid);
      } else if ((1 == sscanf(text, "v%u%zn", &word_wid, &n)) &&
                 (n == strlen(text))) {
	    obj = new vvp_darray_vec4(size, word_wid);
      } else if ((1 == sscanf(text, "sv%u%zn", &word_wid, &n)) &&
                 (n == strlen(text))) {
	    obj = new vvp_darray_vec4(size, word_wid);
      } else if (strcmp(text,"r") == 0) {
	    obj = new vvp_darray_real(size);
      } else if (strcmp(text,"S") == 0) {
	    obj = new vvp_darray_string(size);
      } else if (strcmp(text,"o") == 0) {
	    obj = new vvp_darray_object(size);
      } else {
	    cerr << get_fileline()
	         << "Internal error: Unsupported dynamic array type: "
	         << text << "." << endl;
	    assert(0);
      }

      thr->push_object(obj);

      return true;
}

bool of_NEW_QUEUE(vthread_t thr, vvp_code_t cp)
{
      const char*text = cp->text;
      unsigned word_wid;
      size_t n;

      vvp_object_t obj;
      if (strcmp(text, "r") == 0) {
	    obj = new vvp_queue_real;
      } else if (strcmp(text, "S") == 0) {
	    obj = new vvp_queue_string;
      } else if (strcmp(text, "o") == 0) {
	    obj = new vvp_queue_object;
      } else if ((1 == sscanf(text, "b%u%zn", &word_wid, &n))
		 && (n == strlen(text))) {
	    obj = new vvp_queue_vec4;
      } else if ((1 == sscanf(text, "sb%u%zn", &word_wid, &n))
		 && (n == strlen(text))) {
	    obj = new vvp_queue_vec4;
      } else if ((1 == sscanf(text, "v%u%zn", &word_wid, &n))
		 && (n == strlen(text))) {
	    obj = new vvp_queue_vec4;
      } else if ((1 == sscanf(text, "sv%u%zn", &word_wid, &n))
		 && (n == strlen(text))) {
	    obj = new vvp_queue_vec4;
      } else {
	    cerr << get_fileline()
		 << "Internal error: Unsupported queue type: "
		 << text << "." << endl;
	    assert(0);
      }

      thr->push_object(obj);
      return true;
}

bool of_NOOP(vthread_t, vvp_code_t)
{
      return true;
}

/*
 * %nor/r
 */
bool of_NORR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t val = thr->pop_vec4();

      vvp_bit4_t lb = BIT4_1;

      for (unsigned idx = 0 ;  idx < val.size() ;  idx += 1) {

	    vvp_bit4_t rb = val.value(idx);
	    if (rb == BIT4_1) {
		  lb = BIT4_0;
		  break;
	    }

	    if (rb != BIT4_0)
		  lb = BIT4_X;
      }

      vvp_vector4_t res (1, lb);
      thr->push_vec4(res);

      return true;
}

/*
 * Push a null to the object stack.
 */
bool of_NULL(vthread_t thr, vvp_code_t)
{
      vvp_object_t tmp;
      thr->push_object(tmp);
      return true;
}

/*
 * %and/r
 */
bool of_ANDR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t val = thr->pop_vec4();

      vvp_bit4_t lb = BIT4_1;

      for (unsigned idx = 0 ; idx < val.size() ; idx += 1) {
	    vvp_bit4_t rb = val.value(idx);
	    if (rb == BIT4_0) {
		  lb = BIT4_0;
		  break;
	    }

	    if (rb != 1)
		  lb = BIT4_X;
      }

      vvp_vector4_t res (1, lb);
      thr->push_vec4(res);

      return true;
}

/*
 * %nand/r
 */
bool of_NANDR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t val = thr->pop_vec4();

      vvp_bit4_t lb = BIT4_0;
      for (unsigned idx = 0 ; idx < val.size() ; idx += 1) {

	    vvp_bit4_t rb = val.value(idx);
	    if (rb == BIT4_0) {
		  lb = BIT4_1;
		  break;
	    }

	    if (rb != BIT4_1)
		  lb = BIT4_X;
      }

      vvp_vector4_t res (1, lb);
      thr->push_vec4(res);

      return true;
}

/*
 * %or/r
 */
bool of_ORR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t val = thr->pop_vec4();

      vvp_bit4_t lb = BIT4_0;
      for (unsigned idx = 0 ; idx < val.size() ; idx += 1) {
	    vvp_bit4_t rb = val.value(idx);
	    if (rb == BIT4_1) {
		  lb = BIT4_1;
		  break;
	    }

	    if (rb != BIT4_0)
		  lb = BIT4_X;
      }

      vvp_vector4_t res (1, lb);
      thr->push_vec4(res);
      return true;
}

/*
 * %xor/r
 */
bool of_XORR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t val = thr->pop_vec4();

      vvp_bit4_t lb = BIT4_0;
      for (unsigned idx = 0 ; idx < val.size() ; idx += 1) {

	    vvp_bit4_t rb = val.value(idx);
	    if (rb == BIT4_1)
		  lb = ~lb;
	    else if (rb != BIT4_0) {
		  lb = BIT4_X;
		  break;
	    }
      }

      vvp_vector4_t res (1, lb);
      thr->push_vec4(res);
      return true;
}

/*
 * %xnor/r
 */
bool of_XNORR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t val = thr->pop_vec4();

      vvp_bit4_t lb = BIT4_1;
      for (unsigned idx = 0 ; idx < val.size() ; idx += 1) {

	    vvp_bit4_t rb = val.value(idx);
	    if (rb == BIT4_1)
		  lb = ~lb;
	    else if (rb != BIT4_0) {
		  lb = BIT4_X;
		  break;
	    }
      }

      vvp_vector4_t res (1, lb);
      thr->push_vec4(res);
      return true;
}

/*
 * %or
 */
bool of_OR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t valb = thr->pop_vec4();
      vvp_vector4_t&vala = thr->peek_vec4();
      vala |= valb;
      return true;
}

/*
 * %nor
 */
bool of_NOR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t valr = thr->pop_vec4();
      vvp_vector4_t&vall = thr->peek_vec4();
      assert(vall.size() == valr.size());
      unsigned wid = vall.size();

      for (unsigned idx = 0 ; idx < wid ; idx += 1) {
	    vvp_bit4_t lb = vall.value(idx);
	    vvp_bit4_t rb = valr.value(idx);
	    vall.set_bit(idx, ~(lb|rb));
      }

      return true;
}

/*
 * %pop/obj <num>, <skip>
 */
bool of_POP_OBJ(vthread_t thr, vvp_code_t cp)
{
      unsigned cnt = cp->bit_idx[0];
      unsigned skip = cp->bit_idx[1];

      thr->pop_object(cnt, skip);
      return true;
}

/*
 * %pop/real <number>
 */
bool of_POP_REAL(vthread_t thr, vvp_code_t cp)
{
      unsigned cnt = cp->number;
      thr->pop_real(cnt);
      return true;
}

/*
 *  %pop/str <number>
 */
bool of_POP_STR(vthread_t thr, vvp_code_t cp)
{
      unsigned cnt = cp->number;
      thr->pop_str(cnt);
      return true;
}

/*
 *  %pop/vec4 <number>
 */
bool of_POP_VEC4(vthread_t thr, vvp_code_t cp)
{
      unsigned cnt = cp->number;
      thr->pop_vec4(cnt);
      return true;
}

/*
 * %pow
 * %pow/s
 */
static bool of_POW_base(vthread_t thr, bool signed_flag)
{
      vvp_vector4_t valb = thr->pop_vec4();
      vvp_vector4_t vala = thr->pop_vec4();

      unsigned wid = vala.size();

      vvp_vector2_t xv2 = vvp_vector2_t(vala, true);
      vvp_vector2_t yv2 = vvp_vector2_t(valb, true);


        /* If we have an X or Z in the arguments return X. */
      if (xv2.is_NaN() || yv2.is_NaN()) {
	    vvp_vector4_t tmp (wid, BIT4_X);
	    thr->push_vec4(tmp);
	    return true;
      }

	// Is the exponent negative? If so, table 5-6 in IEEE1364-2005
	// defines what value is returned.
      if (signed_flag && yv2.value(yv2.size()-1)) {
	    int a_val;
	    vvp_bit4_t pad = BIT4_0, lsb = BIT4_0;
	    if (vector2_to_value(xv2, a_val, true)) {
		  if (a_val == 0) {
			pad = BIT4_X; lsb = BIT4_X;
		  }
		  if (a_val == 1) {
			pad = BIT4_0; lsb = BIT4_1;
		  }
		  if (a_val == -1) {
			if (yv2.value(0)) {
			      pad = BIT4_1; lsb = BIT4_1;
			} else {
			      pad = BIT4_0; lsb = BIT4_1;
			}
		  }
	    }
	    vvp_vector4_t tmp (wid, pad);
	    tmp.set_bit(0, lsb);
	    thr->push_vec4(tmp);
	    return true;
      }

      vvp_vector2_t result = pow(xv2, yv2);

        /* Copy only what we need of the result. If the result is too
	   small, zero-pad it. */
      for (unsigned jdx = 0;  jdx < wid;  jdx += 1) {
	    if (jdx >= result.size())
		  vala.set_bit(jdx, BIT4_0);
	    else
		  vala.set_bit(jdx, result.value(jdx) ? BIT4_1 : BIT4_0);
      }
      thr->push_vec4(vala);

      return true;
}

bool of_POW(vthread_t thr, vvp_code_t)
{
      return of_POW_base(thr, false);
}

bool of_POW_S(vthread_t thr, vvp_code_t)
{
      return of_POW_base(thr, true);
}

bool of_POW_WR(vthread_t thr, vvp_code_t)
{
      double r = thr->pop_real();
      double l = thr->pop_real();
      thr->push_real(pow(l,r));

      return true;
}

/*
 * %prop/obj <pid>, <idx>
 *
 * Load an object value from the cobject and push it onto the object stack.
 */
static const char*prop_trace_obj_kind_(const vvp_object_t&obj);
static const char*prop_trace_receiver_class_(const vvp_object_t&obj);
static bool prop_pid_in_range_(const vvp_object_t&obj, size_t pid, size_t*count_out);
static void prop_trace_log_(vthread_t thr, const char*op, size_t pid, unsigned idx, const vvp_object_t&obj, bool has_propobj);

bool of_PROP_OBJ(vthread_t thr, vvp_code_t cp)
{
      unsigned pid = cp->number;
      unsigned idx = cp->bit_idx[0];

      if (idx != 0) {
	    assert(idx < vthread_s::WORDS_COUNT);
	    idx = thr->words[idx].w_uint;
      }

      vvp_object_t&obj = thr->peek_object();
      vvp_cobject*cobj = obj.peek<vvp_cobject>();
      vvp_vinterface*vif = obj.peek<vvp_vinterface>();
      bool has_propobj = cobj != 0 || vif != 0;
      prop_trace_log_(thr, "%prop/obj", pid, idx, obj, has_propobj);
      if (!has_propobj) {
	    static bool warned = false;
	    if (!warned) {
		  const char*scope_name = scope_name_or_unknown_(thr ? thr->parent_scope : 0);
		  cerr << thr->get_fileline()
		       << "Warning: %prop/obj on null/unsupported object handle"
		       << " (pid=" << pid << ", idx=" << idx << ")"
		       << " scope=" << scope_name
		       << " receiver=" << prop_trace_obj_kind_(obj)
		       << " class=" << prop_trace_receiver_class_(obj)
		       << "; using null object fallback." << endl;
		  warned = true;
	    }
	    vvp_object_t val;
	    val.reset();
	    thr->push_object(val, thr->peek_object_source_net(0), thr->peek_object_root(0));
	    return true;
      }

      size_t prop_count = 0;
      if (!prop_pid_in_range_(obj, pid, &prop_count)) {
            static bool warned = false;
            if (!warned) {
                  cerr << thr->get_fileline()
                       << "Warning: %prop/obj pid=" << pid
                       << " out of range for receiver class "
                       << prop_trace_receiver_class_(obj)
                       << " (size=" << prop_count << ")"
                       << "; using null object fallback."
                       << " scope=" << scope_name_or_unknown_(thr ? thr->parent_scope : 0)
                       << endl;
                  warned = true;
            }
            vvp_object_t val;
            val.reset();
            thr->push_object(val, thr->peek_object_source_net(0), thr->peek_object_root(0));
            return true;
      }

      vvp_object_t val;
      if (cobj)
	    cobj->get_object(pid, val, idx);
      else
	    vif->get_object(pid, val, idx);

      thr->push_object(val, thr->peek_object_source_net(0), thr->peek_object_root(0));

      return true;
}

static void get_from_obj(unsigned pid, vvp_cobject*cobj, double&val)
{
      val = cobj->get_real(pid);
}

static void get_from_obj(unsigned pid, vvp_vinterface*vif, double&val)
{
      val = vif->get_real(pid);
}

static void get_from_obj(unsigned pid, vvp_cobject*cobj, string&val)
{
      val = cobj->get_string(pid);
}

static void get_from_obj(unsigned pid, vvp_vinterface*vif, string&val)
{
      val = vif->get_string(pid);
}

static void get_from_obj(unsigned pid, vvp_cobject*cobj, vvp_vector4_t&val)
{
      cobj->get_vec4(pid, val);
}

static void get_from_obj(unsigned pid, vvp_vinterface*vif, vvp_vector4_t&val)
{
      vif->get_vec4(pid, val);
}

static void get_from_obj(unsigned pid, unsigned idx, vvp_cobject*cobj, double&val)
{
      (void)idx;
      val = cobj->get_real(pid);
}

static void get_from_obj(unsigned pid, unsigned idx, vvp_vinterface*vif, double&val)
{
      (void)idx;
      val = vif->get_real(pid);
}

static void get_from_obj(unsigned pid, unsigned idx, vvp_cobject*cobj, string&val)
{
      (void)idx;
      val = cobj->get_string(pid);
}

static void get_from_obj(unsigned pid, unsigned idx, vvp_vinterface*vif, string&val)
{
      (void)idx;
      val = vif->get_string(pid);
}

static void get_from_obj(unsigned pid, unsigned idx, vvp_cobject*cobj, vvp_vector4_t&val)
{
      cobj->get_vec4(pid, val, idx);
}

static void get_from_obj(unsigned pid, unsigned idx, vvp_vinterface*vif, vvp_vector4_t&val)
{
      vif->get_vec4(pid, val, idx);
}

static bool get_from_process_obj(unsigned pid, vvp_process*proc, double&val)
{
      (void)pid;
      (void)proc;
      (void)val;
      return false;
}

static bool get_from_process_obj(unsigned pid, vvp_process*proc, string&val)
{
      (void)pid;
      (void)proc;
      (void)val;
      return false;
}

static bool get_from_process_obj(unsigned pid, vvp_process*proc, vvp_vector4_t&val)
{
      if (!proc || pid != 0)
	    return false;
      process_status_to_vec4_(proc->status(), val);
      return true;
}

static bool get_from_process_obj(unsigned pid, unsigned idx, vvp_process*proc, double&val)
{
      (void)idx;
      return get_from_process_obj(pid, proc, val);
}

static bool get_from_process_obj(unsigned pid, unsigned idx, vvp_process*proc, string&val)
{
      (void)idx;
      return get_from_process_obj(pid, proc, val);
}

static bool get_from_process_obj(unsigned pid, unsigned idx, vvp_process*proc, vvp_vector4_t&val)
{
      if (idx != 0)
	    return false;
      return get_from_process_obj(pid, proc, val);
}

static bool warned_prop_fallback = false;
static bool warned_store_prop_fallback = false;
static int prop_trace_enabled_cache = -1;
static int assoc_trace_enabled_cache = -1;

static bool prop_trace_enabled_()
{
      if (prop_trace_enabled_cache < 0) {
            const char*env = getenv("IVL_PROP_TRACE");
            prop_trace_enabled_cache = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return prop_trace_enabled_cache != 0;
}

static bool prop_trace_scope_match_(vthread_t thr)
{
      if (!prop_trace_enabled_())
            return false;
      const char*scope_name = (thr && thr->parent_scope) ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
      if (!scope_name)
            return false;
      const char*env = getenv("IVL_PROP_TRACE");
      if (!env || !*env || strcmp(env, "1") == 0 || strcmp(env, "ALL") == 0 || strcmp(env, "*") == 0)
            return true;
      return strstr(scope_name, env) != 0;
}

static bool assoc_trace_scope_match_(vthread_t thr)
{
      if (assoc_trace_enabled_cache < 0) {
            const char*env = getenv("IVL_ASSOC_TRACE");
            assoc_trace_enabled_cache = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      if (assoc_trace_enabled_cache == 0)
            return false;

      const char*scope_name = (thr && thr->parent_scope) ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
      if (!scope_name)
            return false;

      const char*env = getenv("IVL_ASSOC_TRACE");
      if (!env || !*env || strcmp(env, "1") == 0 || strcmp(env, "ALL") == 0 || strcmp(env, "*") == 0)
            return true;
      return strstr(scope_name, env) != 0;
}

static const char*prop_trace_obj_kind_(const vvp_object_t&obj)
{
      if (obj.test_nil()) return "nil";
      if (obj.peek<vvp_process>()) return "process";
      if (obj.peek<vvp_cobject>()) return "cobject";
      if (obj.peek<vvp_vinterface>()) return "vinterface";
      if (obj.peek<vvp_darray>()) return "darray";
      if (obj.peek<vvp_queue>()) return "queue";
      return "other";
}

static const char*prop_trace_receiver_class_(const vvp_object_t&obj)
{
      if (vvp_cobject*cobj = obj.peek<vvp_cobject>()) {
            const class_type*defn = cobj->get_defn();
            if (defn)
                  return defn->class_name().c_str();
            return "<cobject>";
      }
      if (obj.peek<vvp_vinterface>())
            return "<vinterface>";
      return "<none>";
}

static bool prop_pid_in_range_(const vvp_object_t&obj, size_t pid, size_t*count_out)
{
      const class_type*defn = 0;
      if (vvp_cobject*cobj = obj.peek<vvp_cobject>())
            defn = cobj->get_defn();

      if (!defn)
            return true;

      size_t count = defn->property_count();
      if (count_out)
            *count_out = count;
      return pid < count;
}

static void prop_trace_log_(vthread_t thr, const char*op, size_t pid, unsigned idx, const vvp_object_t&obj, bool has_propobj)
{
      if (!prop_trace_scope_match_(thr))
            return;
      const char*scope_name = (thr && thr->parent_scope) ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
      fprintf(stderr,
              "trace prop: op=%s scope=%s pid=%zu idx=%u receiver=%s class=%s propobj=%d pc=%p\n",
              op ? op : "<unknown>",
              scope_name ? scope_name : "<unknown>",
              pid, idx, prop_trace_obj_kind_(obj), prop_trace_receiver_class_(obj),
              has_propobj ? 1 : 0,
              (void*)(thr ? thr->pc : 0));
}

template <typename ELEM>
static bool prop(vthread_t thr, vvp_code_t cp)
{
      unsigned pid = cp->number;

      vvp_object_t&obj = thr->peek_object();
      vvp_cobject*cobj = obj.peek<vvp_cobject>();
      vvp_vinterface*vif = obj.peek<vvp_vinterface>();
      vvp_process*proc = obj.peek<vvp_process>();
      bool has_propobj = cobj != 0 || vif != 0;
      prop_trace_log_(thr, "%prop/*", pid, 0, obj, has_propobj);
      if (!has_propobj && proc) {
	    ELEM val;
	    if (get_from_process_obj(pid, proc, val)) {
		  vthread_push(thr, val);
		  return true;
	    }
      }
      if (!has_propobj) {
	    if (!warned_prop_fallback) {
		  const char*scope_name = scope_name_or_unknown_(thr ? thr->parent_scope : 0);
		  cerr << thr->get_fileline()
		       << "Warning: %prop/* on null/unsupported object handle"
		       << " (pid=" << pid << ")"
		       << " scope=" << scope_name
		       << " receiver=" << prop_trace_obj_kind_(obj)
		       << " class=" << prop_trace_receiver_class_(obj)
		       << "; using default value fallback." << endl;
		  warned_prop_fallback = true;
	    }
	    ELEM fallback = ELEM();
	    vthread_push(thr, fallback);
	    return true;
      }

      ELEM val;
      if (cobj)
	    get_from_obj(pid, cobj, val);
      else
	    get_from_obj(pid, vif, val);
      vthread_push(thr, val);

      return true;
}

/*
 * %prop/r <pid>
 *
 * Load a real value from the cobject and push it onto the real value
 * stack.
 */
bool of_PROP_R(vthread_t thr, vvp_code_t cp)
{
      return prop<double>(thr, cp);
}

/*
 * %prop/str <pid>
 *
 * Load a string value from the cobject and push it onto the real value
 * stack.
 */
bool of_PROP_STR(vthread_t thr, vvp_code_t cp)
{
      return prop<string>(thr, cp);
}

/*
 * %prop/v <pid>
 *
 * Load a property <pid> from the cobject on the top of the stack into
 * the vector space at <base>.
 */
bool of_PROP_V(vthread_t thr, vvp_code_t cp)
{
      return prop<vvp_vector4_t>(thr, cp);
}

bool of_PROP_V_I(vthread_t thr, vvp_code_t cp)
{
      unsigned pid = cp->number;
      unsigned idx = cp->bit_idx[0];
      assert(idx < vthread_s::WORDS_COUNT);
      idx = thr->words[idx].w_uint;

      vvp_object_t&obj = thr->peek_object();
      vvp_cobject*cobj = obj.peek<vvp_cobject>();
      vvp_vinterface*vif = obj.peek<vvp_vinterface>();
      vvp_process*proc = obj.peek<vvp_process>();
      bool has_propobj = cobj != 0 || vif != 0;
      prop_trace_log_(thr, "%prop/v/i", pid, idx, obj, has_propobj);
      if (!has_propobj && proc) {
	    vvp_vector4_t val;
	    if (get_from_process_obj(pid, idx, proc, val)) {
		  vthread_push(thr, val);
		  return true;
	    }
      }
      if (!has_propobj) {
	    if (!warned_prop_fallback) {
		  cerr << thr->get_fileline()
		       << "Warning: %prop/v/i on null/unsupported object handle"
		       << " (pid=" << pid << ", idx=" << idx << "); using default value fallback."
		       << endl;
		  warned_prop_fallback = true;
	    }
	    vvp_vector4_t fallback;
	    vthread_push(thr, fallback);
	    return true;
      }

      vvp_vector4_t val;
      if (cobj)
	    get_from_obj(pid, idx, cobj, val);
      else
	    get_from_obj(pid, idx, vif, val);
      vthread_push(thr, val);
      return true;
}

bool of_PUSHI_REAL(vthread_t thr, vvp_code_t cp)
{
      double mant = cp->bit_idx[0];
      uint32_t imant = cp->bit_idx[0];
      int exp = cp->bit_idx[1];

	// Detect +infinity
      if (exp==0x3fff && imant==0) {
	    thr->push_real(INFINITY);
	    return true;
      }
	// Detect -infinity
      if (exp==0x7fff && imant==0) {
	    thr->push_real(-INFINITY);
	    return true;
      }
	// Detect NaN
      if (exp==0x3fff) {
	    thr->push_real(nan(""));
	    return true;
      }

      double sign = (exp & 0x4000)? -1.0 : 1.0;

      exp &= 0x1fff;

      mant = sign * ldexp(mant, exp - 0x1000);
      thr->push_real(mant);
      return true;
}

bool of_PUSHI_STR(vthread_t thr, vvp_code_t cp)
{
      const char*text = cp->text;
      thr->push_str(filter_string(text));
      return true;
}

/*
 * %pushi/vec4 <vala>, <valb>, <wid>
 */
bool of_PUSHI_VEC4(vthread_t thr, vvp_code_t cp)
{
      unsigned wid  = cp->number;

	// I expect that most of the bits of an immediate value are
	// going to be zero, so start the result vector with all zero
	// bits. Then we only need to replace the bits that are different.
      vvp_vector4_t val (wid, BIT4_0);
      get_immediate_rval (cp, val);

      thr->push_vec4(val);

      return true;
}

/*
 * %pushv/str
 *   Pops a vec4 value, and pushes a string.
 */
bool of_PUSHV_STR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t vec = thr->pop_vec4();

      size_t slen = (vec.size() + 7)/8;
      vector<char>buf;
      buf.reserve(slen);

      for (size_t idx = 0 ; idx < vec.size() ; idx += 8) {
	    char tmp = 0;
	    size_t trans = 8;
	    if (idx+trans > vec.size())
		  trans = vec.size() - idx;

	    for (size_t bdx = 0 ; bdx < trans ; bdx += 1) {
		  if (vec.value(idx+bdx) == BIT4_1)
			tmp |= 1 << bdx;
	    }

	    if (tmp != 0)
		  buf.push_back(tmp);
      }

      string val;
      for (vector<char>::reverse_iterator cur = buf.rbegin()
		 ; cur != buf.rend() ; ++cur) {
	    val.push_back(*cur);
      }

      thr->push_str(val);

      return true;
}

/*
 * %putc/str/vec4 <var>, <mux>
 */
bool of_PUTC_STR_VEC4(vthread_t thr, vvp_code_t cp)
{
      unsigned muxr = cp->bit_idx[0];
      int32_t mux = muxr? thr->words[muxr].w_int : 0;

      vvp_vector4_t val = thr->pop_vec4();
      assert(val.size() == 8);

      if (mux < 0)
	    return true;

	/* Get the existing value of the string. If we find that the
	   index is too big for the string, then give up. */
      vvp_net_t*net = cp->net;
      vvp_fun_signal_string*fun = dynamic_cast<vvp_fun_signal_string*> (net->fun);
      assert(fun);

      string tmp = fun->get_string();
      if (tmp.size() <= (size_t)mux)
	    return true;

      char val_str = 0;
      for (size_t idx = 0 ; idx < 8 ; idx += 1) {
	    if (val.value(idx)==BIT4_1)
		  val_str |= 1<<idx;
      }

	// It is a quirk of the Verilog standard that putc(..., 'h00)
	// has no effect. Test for that case here.
      if (val_str == 0)
	    return true;

      tmp[mux] = val_str;

      vvp_send_string(vvp_net_ptr_t(cp->net, 0), tmp,
                      ensure_write_context_(thr, "assign-string"));
      return true;
}

template <typename ELEM, class QTYPE>
static bool qinsert(vthread_t thr, vvp_code_t cp, unsigned wid=0)
{
      int64_t idx = thr->words[3].w_int;
      ELEM value;
      vvp_net_t*net = cp->net;
      pop_value(thr, value, wid); // Pop the value to store.

      vvp_queue*queue = get_queue_object<QTYPE>(thr, net);
      assert(queue);
      if (idx < 0) {
	    cerr << thr->get_fileline()
	         << "Warning: cannot insert at a negative "
	         << get_queue_type(value)
	         << " index (" << idx << "). ";
	    print_queue_value(value);
	    cerr << " was not added." << endl;
      } else if (thr->flags[4] != BIT4_0) {
	    cerr << thr->get_fileline()
	         << "Warning: cannot insert at an undefined "
	         << get_queue_type(value) << " index. ";
	    print_queue_value(value);
	    cerr << " was not added." << endl;
      } else {
	    unsigned max_size = thr->words[cp->bit_idx[0]].w_int;
	    queue->insert(idx, value, max_size);
            notify_mutated_object_signal_(thr, net, "queue-insert");
      }
      return true;
}

/*
 * %qinsert/real <var-label>
 */
bool of_QINSERT_REAL(vthread_t thr, vvp_code_t cp)
{
      return qinsert<double, vvp_queue_real>(thr, cp);
}

/*
 * %qinsert/obj <var-label>
 */
bool of_QINSERT_OBJ(vthread_t thr, vvp_code_t cp)
{
      return qinsert<vvp_object_t, vvp_queue_object>(thr, cp);
}

/*
 * %qinsert/str <var-label>
 */
bool of_QINSERT_STR(vthread_t thr, vvp_code_t cp)
{
      return qinsert<string, vvp_queue_string>(thr, cp);
}

/*
 * %qinsert/v <var-label>
 */
bool of_QINSERT_V(vthread_t thr, vvp_code_t cp)
{
      return qinsert<vvp_vector4_t, vvp_queue_vec4>(thr, cp, cp->bit_idx[1]);
}

template <typename ELEM, class QTYPE>
static bool qinsert_o(vthread_t thr, unsigned wid=0)
{
      int64_t idx = thr->words[3].w_int;
      ELEM value;
      pop_value(thr, value, wid);

      vvp_object_t recv, root_obj;
      vvp_net_t*root_net = 0;
      QTYPE*queue = pop_queue_receiver_<QTYPE>(thr, recv, root_net, root_obj);
      if (!queue)
	    return true;

      if (idx < 0) {
	    cerr << thr->get_fileline()
	         << "Warning: cannot insert at a negative "
	         << get_queue_type(value)
	         << " index (" << idx << "). ";
	    print_queue_value(value);
	    cerr << " was not added." << endl;
      } else if (thr->flags[4] != BIT4_0) {
	    cerr << thr->get_fileline()
	         << "Warning: cannot insert at an undefined "
	         << get_queue_type(value) << " index. ";
	    print_queue_value(value);
	    cerr << " was not added." << endl;
      } else {
	    queue->insert(idx, value, 0);
            notify_mutated_object_root_(thr, recv, root_net, root_obj,
                                        "queue-insert-o");
      }
      return true;
}

bool of_QINSERT_O_REAL(vthread_t thr, vvp_code_t)
{
      return qinsert_o<double, vvp_queue_real>(thr);
}

bool of_QINSERT_O_OBJ(vthread_t thr, vvp_code_t)
{
      return qinsert_o<vvp_object_t, vvp_queue_object>(thr);
}

bool of_QINSERT_O_STR(vthread_t thr, vvp_code_t)
{
      return qinsert_o<string, vvp_queue_string>(thr);
}

bool of_QINSERT_O_V(vthread_t thr, vvp_code_t cp)
{
      return qinsert_o<vvp_vector4_t, vvp_queue_vec4>(thr, cp->bit_idx[0]);
}

/*
 * Helper functions used in the queue pop templates
 */
inline void push_value(vthread_t thr, double value, unsigned)
{
      thr->push_real(value);
}

inline void push_value(vthread_t thr, const string&value, unsigned)
{
      thr->push_str(value);
}

inline void push_value(vthread_t thr, const vvp_vector4_t&value, unsigned wid)
{
      assert(wid == value.size());
      thr->push_vec4(value);
}

inline void push_value(vthread_t thr, const vvp_object_t&value, unsigned)
{
      thr->push_object(value);
}

template <typename ELEM, class QTYPE>
static bool q_pop(vthread_t thr, vvp_code_t cp,
                  void (*get_val_func)(vvp_queue*, ELEM&),
                  const char*loc, unsigned wid)
{
      vvp_net_t*net = cp->net;

      vvp_queue*queue = get_queue_object<QTYPE>(thr, net);
      assert(queue);

      size_t size = queue->get_size();

      ELEM value;
      if (size) {
	    get_val_func(queue, value);
            notify_mutated_object_signal_(thr, net, "queue-pop");
      } else {
	    dq_default(value, wid);
	    cerr << thr->get_fileline()
	         << "Warning: pop_" << loc << "() on empty "
	         << get_queue_type(value) << "." << endl;
      }

      push_value(thr, value, wid);
      return true;
}

template <typename ELEM>
static void get_back_value(vvp_queue*queue, ELEM&value)
{
      queue->get_word(queue->get_size()-1, value);
      queue->pop_back();
}

template <typename ELEM, class QTYPE>
static bool qpop_b(vthread_t thr, vvp_code_t cp, unsigned wid=0)
{
      return q_pop<ELEM, QTYPE>(thr, cp, get_back_value<ELEM>, "back", wid);
}

/*
 * %qpop/b/real <var-label>
 */
bool of_QPOP_B_REAL(vthread_t thr, vvp_code_t cp)
{
      return qpop_b<double, vvp_queue_real>(thr, cp);
}

/*
 * %qpop/b/obj <var-label>
 */
bool of_QPOP_B_OBJ(vthread_t thr, vvp_code_t cp)
{
      return qpop_b<vvp_object_t, vvp_queue_object>(thr, cp);
}

/*
 * %qpop/b/str <var-label>
 */
bool of_QPOP_B_STR(vthread_t thr, vvp_code_t cp)
{
      return qpop_b<string, vvp_queue_string>(thr, cp);
}

/*
 * %qpop/b/v <var-label>
 */
bool of_QPOP_B_V(vthread_t thr, vvp_code_t cp)
{
      return qpop_b<vvp_vector4_t, vvp_queue_vec4>(thr, cp, cp->bit_idx[0]);
}

template <typename ELEM, class QTYPE>
static bool qpop_o_b(vthread_t thr, unsigned wid=0)
{
      vvp_object_t recv, root_obj;
      vvp_net_t*root_net = 0;
      QTYPE*queue = pop_queue_receiver_<QTYPE>(thr, recv, root_net, root_obj);

      ELEM value;
      if (queue && queue->get_size()) {
	    get_back_value<ELEM>(queue, value);
            notify_mutated_object_root_(thr, recv, root_net, root_obj,
                                        "queue-pop-o-back");
      } else {
	    dq_default(value, wid);
	    cerr << thr->get_fileline()
	         << "Warning: pop_back() on empty "
	         << get_queue_type(value) << "." << endl;
      }

      push_value(thr, value, wid);
      return true;
}

bool of_QPOP_O_B_REAL(vthread_t thr, vvp_code_t)
{
      return qpop_o_b<double, vvp_queue_real>(thr);
}

bool of_QPOP_O_B_OBJ(vthread_t thr, vvp_code_t)
{
      return qpop_o_b<vvp_object_t, vvp_queue_object>(thr);
}

bool of_QPOP_O_B_STR(vthread_t thr, vvp_code_t)
{
      return qpop_o_b<string, vvp_queue_string>(thr);
}

bool of_QPOP_O_B_V(vthread_t thr, vvp_code_t cp)
{
      return qpop_o_b<vvp_vector4_t, vvp_queue_vec4>(thr, cp->bit_idx[0]);
}

template <typename ELEM>
static void get_front_value(vvp_queue*queue, ELEM&value)
{
      queue->get_word(0, value);
      queue->pop_front();
}

template <typename ELEM, class QTYPE>
static bool qpop_f(vthread_t thr, vvp_code_t cp, unsigned wid=0)
{
      return q_pop<ELEM, QTYPE>(thr, cp, get_front_value<ELEM>, "front", wid);
}


/*
 * %qpop/f/real <var-label>
 */
bool of_QPOP_F_REAL(vthread_t thr, vvp_code_t cp)
{
      return qpop_f<double, vvp_queue_real>(thr, cp);
}

/*
 * %qpop/f/obj <var-label>
 */
bool of_QPOP_F_OBJ(vthread_t thr, vvp_code_t cp)
{
      return qpop_f<vvp_object_t, vvp_queue_object>(thr, cp);
}

/*
 * %qpop/f/str <var-label>
 */
bool of_QPOP_F_STR(vthread_t thr, vvp_code_t cp)
{
      return qpop_f<string, vvp_queue_string>(thr, cp);
}

/*
 * %qpop/f/v <var-label>
 */
bool of_QPOP_F_V(vthread_t thr, vvp_code_t cp)
{
      return qpop_f<vvp_vector4_t, vvp_queue_vec4>(thr, cp, cp->bit_idx[0]);
}

template <typename ELEM, class QTYPE>
static bool qpop_o_f(vthread_t thr, unsigned wid=0)
{
      vvp_object_t recv, root_obj;
      vvp_net_t*root_net = 0;
      QTYPE*queue = pop_queue_receiver_<QTYPE>(thr, recv, root_net, root_obj);

      ELEM value;
      if (queue && queue->get_size()) {
	    get_front_value<ELEM>(queue, value);
            notify_mutated_object_root_(thr, recv, root_net, root_obj,
                                        "queue-pop-o-front");
      } else {
	    dq_default(value, wid);
	    cerr << thr->get_fileline()
	         << "Warning: pop_front() on empty "
	         << get_queue_type(value) << "." << endl;
      }

      push_value(thr, value, wid);
      return true;
}

bool of_QPOP_O_F_REAL(vthread_t thr, vvp_code_t)
{
      return qpop_o_f<double, vvp_queue_real>(thr);
}

bool of_QPOP_O_F_OBJ(vthread_t thr, vvp_code_t)
{
      return qpop_o_f<vvp_object_t, vvp_queue_object>(thr);
}

bool of_QPOP_O_F_STR(vthread_t thr, vvp_code_t)
{
      return qpop_o_f<string, vvp_queue_string>(thr);
}

bool of_QPOP_O_F_V(vthread_t thr, vvp_code_t cp)
{
      return qpop_o_f<vvp_vector4_t, vvp_queue_vec4>(thr, cp->bit_idx[0]);
}

/*
 * These implement the %release/net and %release/reg instructions. The
 * %release/net instruction applies to a net kind of functor by
 * sending the release/net command to the command port. (See vvp_net.h
 * for details.) The %release/reg instruction is the same, but sends
 * the release/reg command instead. These are very similar to the
 * %deassign instruction.
 */
static bool do_release_vec(vvp_code_t cp, bool net_flag)
{
      vvp_net_t*net = cp->net;
      unsigned base  = cp->bit_idx[0];
      unsigned width = cp->bit_idx[1];

      assert(net->fil);

      if (base >= net->fil->filter_size()) return true;
      if (base+width > net->fil->filter_size())
	    width = net->fil->filter_size() - base;

      bool full_sig = base == 0 && width == net->fil->filter_size();

	// XXXX Can't really do this if this is a partial release?
      net->fil->force_unlink();

	/* Do we release all or part of the net? */
      vvp_net_ptr_t ptr (net, 0);
      if (full_sig) {
	    net->fil->release(ptr, net_flag);
      } else {
	    net->fil->release_pv(ptr, base, width, net_flag);
      }
      net->fun->force_flag(false);

      return true;
}

bool of_RELEASE_NET(vthread_t, vvp_code_t cp)
{
      return do_release_vec(cp, true);
}


bool of_RELEASE_REG(vthread_t, vvp_code_t cp)
{
      return do_release_vec(cp, false);
}

/* The type is 1 for registers and 0 for everything else. */
bool of_RELEASE_WR(vthread_t, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;
      unsigned type  = cp->bit_idx[0];

      assert(net->fil);
      net->fil->force_unlink();

	// Send a command to this signal to unforce itself.
      vvp_net_ptr_t ptr (net, 0);
      net->fil->release(ptr, type==0);
      return true;
}

bool of_REPLICATE(vthread_t thr, vvp_code_t cp)
{
      int rept = cp->number;
      vvp_vector4_t val = thr->pop_vec4();
      vvp_vector4_t res (val.size() * rept, BIT4_X);

      for (int idx = 0 ; idx < rept ; idx += 1) {
	    res.set_vec(idx * val.size(), val);
      }

      thr->push_vec4(res);

      return true;
}

static void poke_val(vthread_t fun_thr, unsigned depth, double val)
{
      fun_thr->parent->poke_real(depth, val);
}

static void poke_val(vthread_t fun_thr, unsigned depth, const string&val)
{
      fun_thr->parent->poke_str(depth, val);
}

static size_t get_max(vthread_t fun_thr, double&)
{
      return fun_thr->args_real.size();
}

static size_t get_max(vthread_t fun_thr, string&)
{
      return fun_thr->args_str.size();
}

static size_t get_max(vthread_t fun_thr, vvp_vector4_t&)
{
      return fun_thr->args_vec4.size();
}

static unsigned get_depth(vthread_t fun_thr, size_t index, double&)
{
      return fun_thr->args_real[index];
}

static unsigned get_depth(vthread_t fun_thr, size_t index, string&)
{
      return fun_thr->args_str[index];
}

static unsigned get_depth(vthread_t fun_thr, size_t index, vvp_vector4_t&)
{
      return fun_thr->args_vec4[index];
}

static vthread_t get_func(vthread_t thr)
{
      vthread_t fun_thr = thr;

      while (fun_thr->parent_scope->get_type_code() != vpiFunction) {
	    assert(fun_thr->parent);
	    fun_thr = fun_thr->parent;
      }

      return fun_thr;
}

template <typename ELEM>
static bool ret(vthread_t thr, vvp_code_t cp)
{
      size_t index = cp->number;
      ELEM val;
      pop_value(thr, val, 0);

      vthread_t fun_thr = get_func(thr);
      assert(index < get_max(fun_thr, val));

      unsigned depth = get_depth(fun_thr, index, val);
	// Use the depth to put the value into the stack of
	// the parent thread.
      poke_val(fun_thr, depth, val);
      return true;
}

/*
 * %ret/real <index>
 */
bool of_RET_REAL(vthread_t thr, vvp_code_t cp)
{
      return ret<double>(thr, cp);
}

/*
 * %ret/str <index>
 */
bool of_RET_STR(vthread_t thr, vvp_code_t cp)
{
      return ret<string>(thr, cp);
}

/*
 * %ret/vec4 <index>, <offset>, <wid>
 */
bool of_RET_VEC4(vthread_t thr, vvp_code_t cp)
{
      size_t index = cp->number;
      unsigned off_index = cp->bit_idx[0];
      unsigned int wid = cp->bit_idx[1];
      vvp_vector4_t&val = thr->peek_vec4();

      vthread_t fun_thr = get_func(thr);
      assert(index < get_max(fun_thr, val));
      if (val.size() != wid) {
            // Compile-progress fallback: unresolved vec4 returns can appear
            // as width-0 values. Coerce silently to destination width.
            if (val.size() == 0) {
                  val.resize(wid, BIT4_X);
            } else {
            {
                  const char*fn = thr->parent_scope ? vpi_get_str(vpiFullName, thr->parent_scope) : "<unknown>";
                  cerr << "Warning: %ret/vec4 width mismatch (" << val.size()
                       << " != " << wid << "), coercing in " << fn << endl;
            }
            if (val.size() > wid) {
                  val = coerce_to_width(val, wid);
            } else {
                  val.resize(wid, BIT4_0);
            }
            }
      }
      unsigned depth = get_depth(fun_thr, index, val);

      int64_t off = off_index ? thr->words[off_index].w_int : 0;
      unsigned int sig_value_size = fun_thr->parent->peek_vec4(depth).size();

      if (off_index!=0 && thr->flags[4] == BIT4_1) {
	    thr->pop_vec4(1);
	    return true;
      }

      if (!resize_rval_vec(val, off, sig_value_size)) {
	    thr->pop_vec4(1);
	    return true;
      }

      if (off == 0 && val.size() == sig_value_size) {
	    fun_thr->parent->poke_vec4(depth, val);
      } else {
	    vvp_vector4_t tmp_dst = fun_thr->parent->peek_vec4(depth);
	    tmp_dst.set_vec(off, val);
	    fun_thr->parent->poke_vec4(depth, tmp_dst);
      }

      thr->pop_vec4(1);
      return true;
}

static void push_from_parent(vthread_t thr, vthread_t fun_thr, unsigned depth, double&)
{
      thr->push_real(fun_thr->parent->peek_real(depth));
}

static void push_from_parent(vthread_t thr, vthread_t fun_thr, unsigned depth, string&)
{
      thr->push_str(fun_thr->parent->peek_str(depth));
}

static void push_from_parent(vthread_t thr, vthread_t fun_thr, unsigned depth, vvp_vector4_t&)
{
      thr->push_vec4(fun_thr->parent->peek_vec4(depth));
}

template <typename ELEM>
static bool retload(vthread_t thr, vvp_code_t cp)
{
      size_t index = cp->number;
      ELEM type;

      vthread_t fun_thr = get_func(thr);
      assert(index < get_max(fun_thr, type));

      unsigned depth = get_depth(fun_thr, index, type);
	// Use the depth to extract the values from the stack
	// of the parent thread.
      push_from_parent(thr, fun_thr, depth, type);
      return true;
}

/*
 * %retload/real <index>
 */
bool of_RETLOAD_REAL(vthread_t thr, vvp_code_t cp)
{
      return retload<double>(thr, cp);
}

/*
 * %retload/str <index>
 */
bool of_RETLOAD_STR(vthread_t thr, vvp_code_t cp)
{
      return retload<string>(thr, cp);
}

/*
 * %retload/vec4 <index>
 */
bool of_RETLOAD_VEC4(vthread_t thr, vvp_code_t cp)
{
      return retload<vvp_vector4_t>(thr, cp);
}

/*
 * %scopy
 *
 * Pop the top item from the object stack, and shallow_copy() that item into
 * the new top of the object stack. This will copy at many items as needed
 * from the source object to fill the target object. If the target object is
 * larger then the source object, then some items will be left unchanged.
 *
 * The object may be any kind of object that supports shallow_copy(),
 * including dynamic arrays and class objects.
 */
bool of_SCOPY(vthread_t thr, vvp_code_t)
{
      vvp_object_t tmp;
      thr->pop_object(tmp);

      vvp_object_t&dest = thr->peek_object();
        // If it is null there is nothing to copy
      if (!tmp.test_nil())
	    dest.shallow_copy(tmp);

      return true;
}

static void thread_peek(vthread_t thr, double&value)
{
      value = thr->peek_real(0);
}

static void thread_peek(vthread_t thr, string&value)
{
      value = thr->peek_str(0);
}

static void thread_peek(vthread_t thr, vvp_vector4_t&value)
{
      value = thr->peek_vec4(0);
}

template <typename ELEM>
static bool set_dar_obj(vthread_t thr, vvp_code_t cp)
{
      unsigned adr = thr->words[cp->number].w_int;

      ELEM value;
      thread_peek(thr, value);

      vvp_object_t&top = thr->peek_object();
      if (vvp_queue*queue = top.peek<vvp_queue>())
	    queue->set_word_max(adr, value, 0);
      else {
	    vvp_darray*darray = top.peek<vvp_darray>();
	    assert(darray);
	    darray->set_word(adr, value);
      }
      notify_mutated_object_root_(thr, top, thr->peek_object_source_net(0),
                                  thr->peek_object_root(0), "set-dar-obj");
      return true;
}

/*
 * %set/dar/obj/real <index>
 */
bool of_SET_DAR_OBJ_REAL(vthread_t thr, vvp_code_t cp)
{
      return set_dar_obj<double>(thr, cp);
}

/*
 * %set/dar/obj/obj <index>
 */
bool of_SET_DAR_OBJ_OBJ(vthread_t thr, vvp_code_t cp)
{
      unsigned adr = thr->words[cp->number].w_int;

      vvp_object_t value;
      thr->pop_object(value);

      vvp_object_t&top = thr->peek_object();
      if (vvp_queue*queue = top.peek<vvp_queue>())
	    queue->set_word_max(adr, value, 0);
      else {
	    vvp_darray*darray = top.peek<vvp_darray>();
	    assert(darray);
	    darray->set_word(adr, value);
      }
      notify_mutated_object_root_(thr, top, thr->peek_object_source_net(0),
                                  thr->peek_object_root(0), "set-dar-obj-obj");
      return true;
}

/*
 * %set/dar/obj/str <index>
 */
bool of_SET_DAR_OBJ_STR(vthread_t thr, vvp_code_t cp)
{
      return set_dar_obj<string>(thr, cp);
}

/*
 * %set/dar/obj/vec4 <index>
 */
bool of_SET_DAR_OBJ_VEC4(vthread_t thr, vvp_code_t cp)
{
      return set_dar_obj<vvp_vector4_t>(thr, cp);
}

/*
 * %shiftl <idx>
 *
 * Pop the operand, then push the result.
 */
bool of_SHIFTL(vthread_t thr, vvp_code_t cp)
{
      int use_index = cp->number;
      uint64_t shift = thr->words[use_index].w_uint;

      vvp_vector4_t&val = thr->peek_vec4();
      unsigned wid  = val.size();

      if (thr->flags[4] == BIT4_1) {
	      // The result is 'bx if the shift amount is undefined
	    val = vvp_vector4_t(wid, BIT4_X);

      } else if (thr->flags[4] == BIT4_X || shift >= wid) {
	      // Shift is so big that all value is shifted out. Write
	      // a constant 0 result.
	    val = vvp_vector4_t(wid, BIT4_0);

      } else if (shift > 0) {
	    vvp_vector4_t blk = val.subvalue(0, wid-shift);
	    vvp_vector4_t tmp (shift, BIT4_0);
	    val.set_vec(0, tmp);
	    val.set_vec(shift, blk);
      }

      return true;
}

/*
 * %shiftr <idx>
 * This is an unsigned right shift. The <idx> is a number that selects
 * the index register with the amount of the shift. This instruction
 * checks flag bit 4, which will be true if the shift is invalid.
 */
bool of_SHIFTR(vthread_t thr, vvp_code_t cp)
{
      int use_index = cp->number;
      uint64_t shift = thr->words[use_index].w_uint;

      vvp_vector4_t val = thr->pop_vec4();
      unsigned wid  = val.size();

      if (thr->flags[4] == BIT4_1) {
	    val = vvp_vector4_t(wid, BIT4_X);

      } else if (thr->flags[4] == BIT4_X || shift > wid) {
	    val = vvp_vector4_t(wid, BIT4_0);

      } else if (shift > 0) {
	    vvp_vector4_t blk = val.subvalue(shift, wid-shift);
	    vvp_vector4_t tmp (shift, BIT4_0);
	    val.set_vec(0, blk);
	    val.set_vec(wid-shift, tmp);
      }

      thr->push_vec4(val);
      return true;
}

/*
 *  %shiftr/s <wid>
 */
bool of_SHIFTR_S(vthread_t thr, vvp_code_t cp)
{
      int use_index = cp->number;
      uint64_t shift = thr->words[use_index].w_uint;

      vvp_vector4_t val = thr->pop_vec4();
      unsigned wid  = val.size();

      vvp_bit4_t sign_bit = val.value(val.size()-1);

      if (thr->flags[4] == BIT4_1) {
	    val = vvp_vector4_t(wid, BIT4_X);

      } else if (thr->flags[4] == BIT4_X || shift > wid) {
	    val = vvp_vector4_t(wid, sign_bit);

      } else if (shift > 0) {
	    vvp_vector4_t blk = val.subvalue(shift, wid-shift);
	    vvp_vector4_t tmp (shift, sign_bit);
	    val.set_vec(0, blk);
	    val.set_vec(wid-shift, tmp);
      }

      thr->push_vec4(val);
      return true;
}

/*
 * %split/vec4 <wid>
 *   Pop 1 value,
 *   Take <wid> bits from the lsb,
 *   Push the remaining msb,
 *   Push the lsb.
 */
bool of_SPLIT_VEC4(vthread_t thr, vvp_code_t cp)
{
      unsigned lsb_wid = cp->number;

      vvp_vector4_t&val = thr->peek_vec4();
      assert(lsb_wid < val.size());

      vvp_vector4_t lsb = val.subvalue(0, lsb_wid);
      val = val.subvalue(lsb_wid, val.size()-lsb_wid);

      thr->push_vec4(lsb);
      return true;
}

/*
 * The following are used to allow the darray templates to print correctly.
 */
inline static string get_darray_type(double&)
{
      return "darray<real>";
}

inline static string get_darray_type(string&)
{
      return "darray<string>";
}

inline static string get_darray_type(const vvp_vector4_t&value)
{
      ostringstream buf;
      buf << "darray<vector[" << value.size() << "]>";
      string res = buf.str();
      return res;
}

/*
 * The following are used to allow a common template to be written for
 * darray real/string/vec4 operations
 */
inline static void dar_pop_value(vthread_t thr, double&value)
{
      value = thr->pop_real();
}

inline static void dar_pop_value(vthread_t thr, string&value)
{
      value = thr->pop_str();
}

inline static void dar_pop_value(vthread_t thr, vvp_vector4_t&value)
{
      value = thr->pop_vec4();
}

template <typename ELEM>
static bool store_dar(vthread_t thr, vvp_code_t cp)
{
      int64_t adr = thr->words[3].w_int;
      ELEM value;
	// FIXME: Can we get the size of the underlying array element
	//        and then use the normal pop_value?
      dar_pop_value(thr, value);

      vvp_net_t*net = cp->net;
      assert(net);

      vvp_fun_signal_object*obj = dynamic_cast<vvp_fun_signal_object*> (net->fun);
      assert(obj);

      vvp_darray*darray = obj->get_object().peek<vvp_darray>();

      if (adr < 0)
	    cerr << thr->get_fileline()
	         << "Warning: cannot write to a negative " << get_darray_type(value)
	         << " index (" << adr << ")." << endl;
      else if (thr->flags[4] != BIT4_0)
	    cerr << thr->get_fileline()
	         << "Warning: cannot write to an undefined " << get_darray_type(value)
	         << " index." << endl;
      else if (darray)
	    darray->set_word(adr, value);
      else
	    cerr << thr->get_fileline()
	         << "Warning: cannot write to an undefined " << get_darray_type(value)
	         << "." << endl;

      if (darray)
            notify_mutated_object_signal_(thr, net, "store-dar");

      return true;
}

/*
 * %store/dar/real <var>
 */
bool of_STORE_DAR_R(vthread_t thr, vvp_code_t cp)
{
      return store_dar<double>(thr, cp);
}

/*
 * %store/dar/str <var>
 */
bool of_STORE_DAR_STR(vthread_t thr, vvp_code_t cp)
{
      return store_dar<string>(thr, cp);
}

/*
 * %store/dar/vec4 <var>
 */
bool of_STORE_DAR_VEC4(vthread_t thr, vvp_code_t cp)
{
      return store_dar<vvp_vector4_t>(thr, cp);
}

/*
 * %store/dar/obj <var>
 * Store an object into a dynamic array element
 */
bool of_STORE_DAR_OBJ(vthread_t thr, vvp_code_t cp)
{
      int64_t adr = thr->words[3].w_int;
      vvp_object_t value;
      thr->pop_object(value);

      vvp_net_t*net = cp->net;
      assert(net);

      vvp_fun_signal_object*obj = dynamic_cast<vvp_fun_signal_object*> (net->fun);
      assert(obj);

      vvp_darray*darray = obj->get_object().peek<vvp_darray>();

      if (adr < 0)
	    cerr << thr->get_fileline()
	         << "Warning: cannot write to a negative darray<object>"
	         << " index (" << adr << ")." << endl;
      else if (thr->flags[4] != BIT4_0)
	    cerr << thr->get_fileline()
	         << "Warning: cannot write to an undefined darray<object>"
	         << " index." << endl;
      else if (darray)
	    darray->set_word(adr, value);
      else
	    cerr << thr->get_fileline()
	         << "Warning: cannot write to an undefined darray<object>"
	         << "." << endl;

      if (darray)
            notify_mutated_object_signal_(thr, net, "store-dar-obj");

      return true;
}

bool of_STORE_OBJ(vthread_t thr, vvp_code_t cp)
{
	/* set the value into port 0 of the destination. */
      vvp_net_ptr_t ptr (cp->net, 0);
      vvp_net_t*src_root_net = thr->peek_object_source_net(0);
      vvp_object_t src_root_obj = thr->peek_object_root(0);

      vvp_object_t val;
      thr->pop_object(val);

      static int trace_store_obj_enabled = -1;
      if (trace_store_obj_enabled < 0) {
            const char*env = getenv("IVL_STORE_OBJ_TRACE");
            trace_store_obj_enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      if (trace_store_obj_enabled) {
            const char*scope_name = (thr && thr->parent_scope)
                                  ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
            const char*env = getenv("IVL_STORE_OBJ_TRACE");
            bool trace_this = true;
            if (env && *env
                && strcmp(env, "1") != 0 && strcmp(env, "ALL") != 0 && strcmp(env, "*") != 0) {
                  trace_this = (scope_name && strstr(scope_name, env));
            }
            if (trace_this) {
                  const char*fun_kind = "other";
                  if (cp->net && cp->net->fun) {
                        if (dynamic_cast<vvp_fun_signal_object_sa*>(cp->net->fun))
                              fun_kind = "object_sa";
                        else if (dynamic_cast<vvp_fun_signal_object_aa*>(cp->net->fun))
                              fun_kind = "object_aa";
                  }
                  fprintf(stderr,
                          "trace store_obj scope=%s net=%p fun=%s val_nil=%d val=%p class=%s wt=%p rd=%p\n",
                          scope_name ? scope_name : "<unknown>",
                          (void*)cp->net, fun_kind, val.test_nil() ? 1 : 0,
                          val.peek<vvp_object>(),
                          object_trace_class_(val),
                          thr ? thr->wt_context : 0, thr ? thr->rd_context : 0);
            }
      }

      vvp_send_object(ptr, val, ensure_write_context_(thr, "store-obj"));
      if (vvp_fun_signal_object*fun = signal_object_fun_(cp->net)) {
            /* If the incoming provenance refers to a different object than
             * the handle we are storing, this assignment creates a new alias
             * boundary and the destination handle must become the canonical
             * wakeup root for later in-place mutations. */
            if (!src_root_net || src_root_obj.test_nil() || src_root_obj != val) {
                  src_root_net = cp->net;
                  src_root_obj = val;
            }
            fun->set_root_provenance(src_root_net, src_root_obj,
                                     ensure_write_context_(thr, "store-obj-root"));
      }

      return true;
}

/*
 * %store/obja <array-label> <index>
 */
bool of_STORE_OBJA(vthread_t thr, vvp_code_t cp)
{
      unsigned idx = cp->bit_idx[0];
      unsigned adr = thr->words[idx].w_int;
      vvp_array_t array = resolve_runtime_array_(cp, "%store/obja");

      vvp_object_t val;
      thr->pop_object(val);

      if (array)
	    array->set_word(adr, val);

      return true;
}

bool of_AA_STORE_SIG_OBJ_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_store_signal<vvp_object_t, vvp_object_t, vvp_assoc_object>(thr, cp->net);
}

bool of_AA_STORE_SIG_OBJ_STR(vthread_t thr, vvp_code_t cp)
{
      return aa_store_signal<string, vvp_object_t, vvp_assoc_object>(thr, cp->net);
}

bool of_AA_STORE_SIG_OBJ_V(vthread_t thr, vvp_code_t cp)
{
      return aa_store_signal<vvp_vector4_t, vvp_object_t, vvp_assoc_object>(thr, cp->net);
}

bool of_AA_STORE_SIG_R_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_store_signal<vvp_object_t, double, vvp_assoc_real>(thr, cp->net);
}

bool of_AA_STORE_SIG_STR_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_store_signal<vvp_object_t, string, vvp_assoc_string>(thr, cp->net);
}

bool of_AA_STORE_SIG_V_OBJ(vthread_t thr, vvp_code_t cp)
{
      return aa_store_signal<vvp_object_t, vvp_vector4_t, vvp_assoc_vec4>(thr, cp->net,
                                                                          cp->bit_idx[0]);
}


/*
 * %store/prop/obj <pid>, <idx>
 *
 * Pop an object value from the object stack, and store the value into
 * the property of the object references by the top of the stack. Do NOT
 * pop the object stack.
 */
bool of_STORE_PROP_OBJ(vthread_t thr, vvp_code_t cp)
{
      size_t pid = cp->number;
      unsigned idx = cp->bit_idx[0];

      if (idx != 0) {
	    assert(idx < vthread_s::WORDS_COUNT);
	    idx = thr->words[idx].w_uint;
      }

      vvp_object_t val;
      thr->pop_object(val);

      vvp_object_t&obj = thr->peek_object();
      vvp_cobject*cobj = obj.peek<vvp_cobject>();
      vvp_vinterface*vif_base = obj.peek<vvp_vinterface>();
      bool has_propobj = cobj != 0 || vif_base != 0;
      prop_trace_log_(thr, "%store/prop/obj", pid, idx, obj, has_propobj);
      if (!has_propobj) {
	      // Compile-progress fallback: storing into an unresolved/null class
	      // handle is a no-op.
	    return true;
      }

      size_t prop_count = 0;
      if (!prop_pid_in_range_(obj, pid, &prop_count)) {
            static bool warned = false;
            if (!warned) {
                  cerr << thr->get_fileline()
                       << "Warning: %store/prop/obj pid=" << pid
                       << " out of range for receiver class "
                       << prop_trace_receiver_class_(obj)
                       << " (size=" << prop_count << ")"
                       << "; ignoring write."
                       << " scope=" << scope_name_or_unknown_(thr ? thr->parent_scope : 0)
                       << endl;
                  warned = true;
            }
            return true;
      }

      if (cobj)
	    cobj->set_object(pid, val, idx);
      else
	    vif_base->set_object(pid, val, idx);
      notify_mutated_object_root_(thr, obj, thr->peek_object_source_net(0),
                                  thr->peek_object_root(0), "store-prop-obj");

      return true;
}

static void pop_prop_val(vthread_t thr, double&val, unsigned)
{
      val = thr->pop_real();
}

static void pop_prop_val(vthread_t thr, string&val, unsigned)
{
      val = thr->pop_str();
}

static void pop_prop_val(vthread_t thr, vvp_vector4_t&val, unsigned wid)
{
      val = thr->pop_vec4();
      assert(val.size() >= wid);
      val.resize(wid);
}

static void set_val(vvp_cobject*cobj, size_t pid, const double&val)
{
      cobj->set_real(pid, val);
}

static void set_val(vvp_vinterface*vif, size_t pid, const double&val)
{
      vif->set_real(pid, val);
}

static void set_val(vvp_cobject*cobj, size_t pid, const string&val)
{
      cobj->set_string(pid, val);
}

static void set_val(vvp_vinterface*vif, size_t pid, const string&val)
{
      vif->set_string(pid, val);
}

static void set_val(vvp_cobject*cobj, size_t pid, const vvp_vector4_t&val)
{
      cobj->set_vec4(pid, val);
}

static void set_val(vvp_vinterface*vif, size_t pid, const vvp_vector4_t&val)
{
      vif->set_vec4(pid, val);
}

static void set_val(vvp_cobject*cobj, size_t pid, const double&val, size_t idx)
{
      (void)idx;
      cobj->set_real(pid, val);
}

static void set_val(vvp_vinterface*vif, size_t pid, const double&val, size_t idx)
{
      (void)idx;
      vif->set_real(pid, val);
}

static void set_val(vvp_cobject*cobj, size_t pid, const string&val, size_t idx)
{
      (void)idx;
      cobj->set_string(pid, val);
}

static void set_val(vvp_vinterface*vif, size_t pid, const string&val, size_t idx)
{
      (void)idx;
      vif->set_string(pid, val);
}

static void set_val(vvp_cobject*cobj, size_t pid, const vvp_vector4_t&val, size_t idx)
{
      cobj->set_vec4(pid, val, idx);
}

static void set_val(vvp_vinterface*vif, size_t pid, const vvp_vector4_t&val, size_t idx)
{
      vif->set_vec4(pid, val, idx);
}

template <typename ELEM>
static bool store_prop(vthread_t thr, vvp_code_t cp, unsigned wid=0)
{
      size_t pid = cp->number;
      ELEM val;
      pop_prop_val(thr, val, wid); // Pop the value to store.

      vvp_object_t&obj = thr->peek_object();
      vvp_cobject*cobj = obj.peek<vvp_cobject>();
      vvp_vinterface*vif = obj.peek<vvp_vinterface>();
      bool has_propobj = cobj != 0 || vif != 0;
      prop_trace_log_(thr, "%store/prop/*", pid, 0, obj, has_propobj);
      if (!has_propobj) {
	      /* Object is null or wrong type - skip property store with warning.
	       * This can occur with UVM class instances that haven't been
	       * fully initialized, or when class types are not fully supported. */
	    if (!warned_store_prop_fallback) {
		  cerr << thr->get_fileline()
		       << "Warning: cannot store into null/uninitialized class object"
		       << " (property " << pid << "); skipping further similar stores."
		       << endl;
		  warned_store_prop_fallback = true;
	    }
	    return true;
      }

      if (cobj)
	    set_val(cobj, pid, val);
      else
	    set_val(vif, pid, val);
      notify_mutated_object_root_(thr, obj, thr->peek_object_source_net(0),
                                  thr->peek_object_root(0), "store-prop");

      return true;
}

/*
 * %store/prop/r <id>
 *
 * Pop a real value from the real stack, and store the value into the
 * property of the object references by the top of the stack. Do NOT
 * pop the object stack.
 */
bool of_STORE_PROP_R(vthread_t thr, vvp_code_t cp)
{
      return store_prop<double>(thr, cp);
}

/*
 * %store/prop/str <id>
 *
 * Pop a string value from the string stack, and store the value into
 * the property of the object references by the top of the stack. Do NOT
 * pop the object stack.
 */
bool of_STORE_PROP_STR(vthread_t thr, vvp_code_t cp)
{
      return store_prop<string>(thr, cp);
}

/*
 * %store/prop/v <pid>, <wid>
 *
 * Store vector value into property <id> of cobject in the top of the
 * stack. Do NOT pop the object stack.
 */
bool of_STORE_PROP_V(vthread_t thr, vvp_code_t cp)
{
      return store_prop<vvp_vector4_t>(thr, cp, cp->bit_idx[0]);
}

bool of_STORE_PROP_V_I(vthread_t thr, vvp_code_t cp)
{
      size_t pid = cp->number;
      size_t idx_reg = cp->bit_idx[0];
      unsigned wid = cp->bit_idx[1];
      vvp_vector4_t val;
      pop_prop_val(thr, val, wid);

      assert(idx_reg < vthread_s::WORDS_COUNT);
      size_t idx = thr->words[idx_reg].w_uint;

      vvp_object_t&obj = thr->peek_object();
      vvp_cobject*cobj = obj.peek<vvp_cobject>();
      vvp_vinterface*vif = obj.peek<vvp_vinterface>();
      bool has_propobj = cobj != 0 || vif != 0;
      prop_trace_log_(thr, "%store/prop/v/i", pid, idx, obj, has_propobj);
      if (!has_propobj) {
	    if (!warned_store_prop_fallback) {
		  cerr << thr->get_fileline()
		       << "Warning: cannot store into null/uninitialized class object"
		       << " (property " << pid << ", idx=" << idx << "); skipping further similar stores."
		       << endl;
		  warned_store_prop_fallback = true;
	    }
	    return true;
      }

      if (cobj)
	    set_val(cobj, pid, val, idx);
      else
	    set_val(vif, pid, val, idx);
      notify_mutated_object_root_(thr, obj, thr->peek_object_source_net(0),
                                  thr->peek_object_root(0), "store-prop-idx");
      return true;
}

template <typename ELEM, class QTYPE>
static bool store_qb(vthread_t thr, vvp_code_t cp, unsigned wid=0)
{
      ELEM value;
      vvp_net_t*net = cp->net;
      unsigned max_size = thr->words[cp->bit_idx[0]].w_int;
      pop_value(thr, value, wid); // Pop the value to store.

      vvp_queue*queue = get_queue_object<QTYPE>(thr, net);
      assert(queue);
      queue->push_back(value, max_size);
      notify_mutated_object_signal_(thr, net, "store-qb");
      return true;
}

/*
 * %store/qb/r <var-label>, <max-idx>
 */
bool of_STORE_QB_R(vthread_t thr, vvp_code_t cp)
{
      return store_qb<double, vvp_queue_real>(thr, cp);
}

/*
 * %store/qb/obj <var-label>, <max-idx>
 */
bool of_STORE_QB_OBJ(vthread_t thr, vvp_code_t cp)
{
      return store_qb<vvp_object_t, vvp_queue_object>(thr, cp);
}

/*
 * %store/qb/str <var-label>, <max-idx>
 */
bool of_STORE_QB_STR(vthread_t thr, vvp_code_t cp)
{
      return store_qb<string, vvp_queue_string>(thr, cp);
}

/*
 * %store/qb/v <var-label>, <max-idx>, <wid>
 */
bool of_STORE_QB_V(vthread_t thr, vvp_code_t cp)
{
      return store_qb<vvp_vector4_t, vvp_queue_vec4>(thr, cp, cp->bit_idx[1]);
}

template <typename ELEM, class QTYPE>
static bool store_qo_b(vthread_t thr, unsigned wid=0)
{
      ELEM value;
      pop_value(thr, value, wid);

      vvp_object_t recv, root_obj;
      vvp_net_t*root_net = 0;
      QTYPE*queue = pop_queue_receiver_<QTYPE>(thr, recv, root_net, root_obj);
      if (!queue)
	    return true;

      queue->push_back(value, 0);
      notify_mutated_object_root_(thr, recv, root_net, root_obj, "store-qo-b");
      return true;
}

bool of_STORE_QO_B_R(vthread_t thr, vvp_code_t)
{
      return store_qo_b<double, vvp_queue_real>(thr);
}

bool of_STORE_QO_B_OBJ(vthread_t thr, vvp_code_t)
{
      return store_qo_b<vvp_object_t, vvp_queue_object>(thr);
}

bool of_STORE_QO_B_STR(vthread_t thr, vvp_code_t)
{
      return store_qo_b<string, vvp_queue_string>(thr);
}

bool of_STORE_QO_B_V(vthread_t thr, vvp_code_t cp)
{
      return store_qo_b<vvp_vector4_t, vvp_queue_vec4>(thr, cp->bit_idx[0]);
}

template <typename ELEM, class QTYPE>
static bool store_qdar(vthread_t thr, vvp_code_t cp, unsigned wid=0)
{
      int64_t idx = thr->words[3].w_int;
      ELEM value;
      vvp_net_t*net = cp->net;
      pop_value(thr, value, wid); // Pop the value to store.

      vvp_queue*queue = get_queue_object<QTYPE>(thr, net);
      assert(queue);
      if (idx < 0) {
	    cerr << thr->get_fileline()
	         << "Warning: cannot assign to a negative "
	         << get_queue_type(value)
	         << " index (" << idx << "). ";
	    print_queue_value(value);
	    cerr << " was not added." << endl;
      } else {
	    if (thr->flags[4] != BIT4_0) {
		    /* Compile-progress fallback: undefined queue index.
		     * Skip the write silently to avoid runtime warning spam. */
		  return true;
	    }
	    unsigned max_size = thr->words[cp->bit_idx[0]].w_int;
	    queue->set_word_max(idx, value, max_size);
            notify_mutated_object_signal_(thr, net, "store-qdar");
      }
      return true;
}

/*
 * %store/qdar/r <var>, idx
 */
bool of_STORE_QDAR_R(vthread_t thr, vvp_code_t cp)
{
      return store_qdar<double, vvp_queue_real>(thr, cp);
}

/*
 * %store/qdar/str <var>, idx
 */
bool of_STORE_QDAR_STR(vthread_t thr, vvp_code_t cp)
{
      return store_qdar<string, vvp_queue_string>(thr, cp);
}

/*
 * %store/qdar/v <var>, idx
 */
bool of_STORE_QDAR_V(vthread_t thr, vvp_code_t cp)
{
      return store_qdar<vvp_vector4_t, vvp_queue_vec4>(thr, cp, cp->bit_idx[1]);
}

/*
 * %store/qdar/obj <var>, idx
 * Store an object into a queue element
 * Note: For now, treat as darray since vvp_queue doesn't support objects yet
 */
bool of_STORE_QDAR_OBJ(vthread_t thr, vvp_code_t cp)
{
      int64_t idx = thr->words[3].w_int;
      vvp_object_t value;
      thr->pop_object(value);

      vvp_net_t*net = cp->net;
      vvp_queue*queue = get_queue_object<vvp_queue_object>(thr, net);
      assert(queue);

      if (idx < 0) {
	    cerr << thr->get_fileline()
	         << "Warning: cannot assign to a negative queue<object>"
	         << " index (" << idx << "). Object was not added." << endl;
      } else {
	    if (thr->flags[4] != BIT4_0) {
		    /* Compile-progress fallback: undefined queue<object> index.
		     * Skip the write silently. */
		  return true;
	    }
	    unsigned max_size = thr->words[cp->bit_idx[0]].w_int;
	    queue->set_word_max(idx, value, max_size);
            notify_mutated_object_signal_(thr, net, "store-qdar-obj");
      }
      return true;
}

template <typename ELEM, class QTYPE>
static bool store_qf(vthread_t thr, vvp_code_t cp, unsigned wid=0)
{
      ELEM value;
      vvp_net_t*net = cp->net;
      unsigned max_size = thr->words[cp->bit_idx[0]].w_int;
      pop_value(thr, value, wid); // Pop the value to store.

      vvp_queue*queue = get_queue_object<QTYPE>(thr, net);
      assert(queue);
      queue->push_front(value, max_size);
      notify_mutated_object_signal_(thr, net, "store-qf");
      return true;
}
/*
 * %store/qf/r <var-label>, <max-idx>
 */
bool of_STORE_QF_R(vthread_t thr, vvp_code_t cp)
{
      return store_qf<double, vvp_queue_real>(thr, cp);
}

/*
 * %store/qf/obj <var-label>, <max-idx>
 */
bool of_STORE_QF_OBJ(vthread_t thr, vvp_code_t cp)
{
      return store_qf<vvp_object_t, vvp_queue_object>(thr, cp);
}

/*
 * %store/qf/str <var-label>, <max-idx>
 */
bool of_STORE_QF_STR(vthread_t thr, vvp_code_t cp)
{
      return store_qf<string, vvp_queue_string>(thr, cp);
}

/*
 * %store/qb/v <var-label>, <max-idx>, <wid>
 */
bool of_STORE_QF_V(vthread_t thr, vvp_code_t cp)
{
      return store_qf<vvp_vector4_t, vvp_queue_vec4>(thr, cp, cp->bit_idx[1]);
}

template <typename ELEM, class QTYPE>
static bool store_qo_f(vthread_t thr, unsigned wid=0)
{
      ELEM value;
      pop_value(thr, value, wid);

      vvp_object_t recv, root_obj;
      vvp_net_t*root_net = 0;
      QTYPE*queue = pop_queue_receiver_<QTYPE>(thr, recv, root_net, root_obj);
      if (!queue)
	    return true;

      queue->push_front(value, 0);
      notify_mutated_object_root_(thr, recv, root_net, root_obj, "store-qo-f");
      return true;
}

bool of_STORE_QO_F_R(vthread_t thr, vvp_code_t)
{
      return store_qo_f<double, vvp_queue_real>(thr);
}

bool of_STORE_QO_F_OBJ(vthread_t thr, vvp_code_t)
{
      return store_qo_f<vvp_object_t, vvp_queue_object>(thr);
}

bool of_STORE_QO_F_STR(vthread_t thr, vvp_code_t)
{
      return store_qo_f<string, vvp_queue_string>(thr);
}

bool of_STORE_QO_F_V(vthread_t thr, vvp_code_t cp)
{
      return store_qo_f<vvp_vector4_t, vvp_queue_vec4>(thr, cp->bit_idx[0]);
}

template <typename ELEM, class QTYPE>
static bool store_qobj(vthread_t thr, vvp_code_t cp, unsigned wid=0)
{
// FIXME: Can we actually use wid here?
      (void)wid;
      vvp_net_t*net = cp->net;

      vvp_queue*queue = get_queue_object<QTYPE>(thr, net);
      assert(queue);

      vvp_object_t src;
      thr->pop_object(src);

        // If it is null just clear the queue
      if (src.test_nil())
	    queue->erase_tail(0);
      else {
	    unsigned max_size = thr->words[cp->bit_idx[0]].w_int;
	    queue->copy_elems(src, max_size);
      }
      notify_mutated_object_signal_(thr, net, "store-qobj");

      return true;
}

bool of_STORE_QOBJ_R(vthread_t thr, vvp_code_t cp)
{
      return store_qobj<double, vvp_queue_real>(thr, cp);
}

bool of_STORE_QOBJ_STR(vthread_t thr, vvp_code_t cp)
{
      return store_qobj<string, vvp_queue_string>(thr, cp);
}

bool of_STORE_QOBJ_V(vthread_t thr, vvp_code_t cp)
{
      return store_qobj<vvp_vector4_t, vvp_queue_vec4>(thr, cp, cp->bit_idx[1]);
}

template <typename ELEM, class DST_QTYPE, class SRC_TYPE>
static void append_qobj_elements_(DST_QTYPE*queue, SRC_TYPE*src,
                                  unsigned max_size, unsigned wid=0)
{
      size_t src_size = src->get_size();

      for (size_t idx = 0 ; idx < src_size ; idx += 1) {
            ELEM value;
            dq_default(value, wid);
            src->get_word(idx, value);
            queue->push_back(value, max_size);
      }
}

template <typename ELEM, class QTYPE>
static bool append_qobj(vthread_t thr, vvp_code_t cp, unsigned wid=0)
{
      vvp_net_t*net = cp->net;
      vvp_queue*queue = get_queue_object<QTYPE>(thr, net);
      assert(queue);

      vvp_object_t src;
      thr->pop_object(src);

      if (src.test_nil())
            return true;

      unsigned max_size = thr->words[cp->bit_idx[0]].w_int;
      if (vvp_queue*src_queue = src.peek<vvp_queue>())
            append_qobj_elements_<ELEM, QTYPE, vvp_queue>(
                  static_cast<QTYPE*>(queue), src_queue, max_size, wid);
      else if (vvp_darray*src_darray = src.peek<vvp_darray>())
            append_qobj_elements_<ELEM, QTYPE, vvp_darray>(
                  static_cast<QTYPE*>(queue), src_darray, max_size, wid);
      else
            cerr << thr->get_fileline()
                 << "Warning: cannot append non-collection object to queue." << endl;

      notify_mutated_object_signal_(thr, net, "append-qobj");

      return true;
}

bool of_APPEND_QOBJ_OBJ(vthread_t thr, vvp_code_t cp)
{
      return append_qobj<vvp_object_t, vvp_queue_object>(thr, cp);
}

static void vvp_send(vthread_t thr, vvp_net_ptr_t ptr, const double&val)
{
      vvp_send_real(ptr, val, ensure_write_context_(thr, "store-real"));
}

static void vvp_send(vthread_t thr, vvp_net_ptr_t ptr, const string&val)
{
      static int trace_store_str_enabled = -1;
      if (trace_store_str_enabled < 0) {
            const char*env = getenv("IVL_STORE_STR_TRACE");
            trace_store_str_enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      if (trace_store_str_enabled) {
            const char*scope_name = (thr && thr->parent_scope)
                                  ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
            const char*env = getenv("IVL_STORE_STR_TRACE");
            bool trace_this = true;
            if (env && *env
                && strcmp(env, "1") != 0 && strcmp(env, "ALL") != 0 && strcmp(env, "*") != 0) {
                  trace_this = (scope_name && strstr(scope_name, env));
            }
            if (trace_this) {
                  fprintf(stderr,
                          "trace store_str-pre scope=%s wt=%p rd=%p len=%zu\n",
                          scope_name ? scope_name : "<unknown>",
                          thr ? thr->wt_context : 0, thr ? thr->rd_context : 0,
                          val.size());
            }
      }
      vvp_context_t write_context = ensure_write_context_(thr, "store-string");
      if (trace_store_str_enabled) {
            const char*scope_name = (thr && thr->parent_scope)
                                  ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
            const char*env = getenv("IVL_STORE_STR_TRACE");
            bool trace_this = true;
            if (env && *env
                && strcmp(env, "1") != 0 && strcmp(env, "ALL") != 0 && strcmp(env, "*") != 0) {
                  trace_this = (scope_name && strstr(scope_name, env));
            }
            if (trace_this) {
                  fprintf(stderr,
                          "trace store_str-ctx scope=%s wt=%p rd=%p use=%p len=%zu\n",
                          scope_name ? scope_name : "<unknown>",
                          thr ? thr->wt_context : 0, thr ? thr->rd_context : 0,
                          write_context, val.size());
            }
      }
      vvp_send_string(ptr, val, write_context);
      if (trace_store_str_enabled) {
            const char*scope_name = (thr && thr->parent_scope)
                                  ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
            const char*env = getenv("IVL_STORE_STR_TRACE");
            bool trace_this = true;
            if (env && *env
                && strcmp(env, "1") != 0 && strcmp(env, "ALL") != 0 && strcmp(env, "*") != 0) {
                  trace_this = (scope_name && strstr(scope_name, env));
            }
            if (trace_this) {
                  fprintf(stderr,
                          "trace store_str-post scope=%s wt=%p rd=%p use=%p len=%zu\n",
                          scope_name ? scope_name : "<unknown>",
                          thr ? thr->wt_context : 0, thr ? thr->rd_context : 0,
                          write_context, val.size());
            }
      }
}

template <typename ELEM>
static bool store(vthread_t thr, vvp_code_t cp)
{
      ELEM val;
      pop_value(thr, val, 0);
	/* set the value into port 0 of the destination. */
      vvp_net_ptr_t ptr (cp->net, 0);
      vvp_send(thr, ptr, val);
      return true;
}

bool of_STORE_REAL(vthread_t thr, vvp_code_t cp)
{
      return store<double>(thr, cp);
}

template <typename ELEM>
static bool storea(vthread_t thr, vvp_code_t cp, const char*op)
{
      unsigned idx = cp->bit_idx[0];
      ELEM val;
      pop_value(thr, val, 0);

      if (thr->flags[4] != BIT4_1) {
	    unsigned adr = thr->words[idx].w_int;
	    vvp_array_t array = resolve_runtime_array_(cp, op);
	    if (array)
		  array->set_word(adr, val);
      }

      return true;
}

/*
 * %store/reala <var-label> <index>
 */
bool of_STORE_REALA(vthread_t thr, vvp_code_t cp)
{
      return storea<double>(thr, cp, "%store/reala");
}

bool of_STORE_STR(vthread_t thr, vvp_code_t cp)
{
      return store<string>(thr, cp);
}

/*
 * %store/stra <array-label> <index>
 */
bool of_STORE_STRA(vthread_t thr, vvp_code_t cp)
{
      return storea<string>(thr, cp, "%store/stra");
}

/*
 * %store/vec4 <var-label>, <offset>, <wid>
 *
 * <offset> is the index register that contains the base offset into
 * the destination. If zero, the offset of 0 is used instead of index
 * register zero. The offset value is SIGNED, and can be negative.
 *
 * <wid> is the actual width, an unsigned number.
 *
 * This function tests flag bit 4. If that flag is set, and <offset>
 * is an actual index register (not zero) then this assumes that the
 * calculation of the <offset> contents failed, and the store is
 * aborted.
 *
 * NOTE: This instruction may loose the <wid> argument because it is
 * not consistent with the %store/vec4/<etc> instructions which have
 * no <wid>.
 */
bool of_STORE_VEC4(vthread_t thr, vvp_code_t cp)
{
      vvp_net_ptr_t ptr(cp->net, 0);
      vvp_signal_value*sig = dynamic_cast<vvp_signal_value*> (cp->net->fil);
      unsigned off_index = cp->bit_idx[0];
      unsigned int wid = cp->bit_idx[1];

      int64_t off = off_index ? thr->words[off_index].w_int : 0;
      unsigned int sig_value_size = sig->value_size();

      vvp_vector4_t&val = thr->peek_vec4();
      unsigned val_size = val.size();

      if (val_size < wid) {
	    cerr << thr->get_fileline()
	         << "XXXX Internal error: val.size()=" << val_size
		 << ", expecting >= " << wid << endl;
      }
      assert(val_size >= wid);
      if (val_size > wid) {
	    val.resize(wid);
      }

	// If there is a problem loading the index register, flags-4
	// will be set to 1, and we know here to skip the actual assignment.
      if (off_index!=0 && thr->flags[4] == BIT4_1) {
	    thr->pop_vec4(1);
	    return true;
      }

      if (!resize_rval_vec(val, off, sig_value_size)) {
	    thr->pop_vec4(1);
	    return true;
      }

      vvp_context_t write_context = ensure_write_context_(thr, "store-vec4");
      if (!write_context)
            trace_context_event_("store-vec4-null-wt", thr, 0, 0);

      if (off == 0 && val.size() == sig_value_size)
	    vvp_send_vec4(ptr, val, write_context);
      else
	    vvp_send_vec4_pv(ptr, val, off, sig_value_size, write_context);

      thr->pop_vec4(1);
      return true;
}

/*
 * %store/vec4a <var-label>, <addr>, <offset>
 */
bool of_STORE_VEC4A(vthread_t thr, vvp_code_t cp)
{
      unsigned adr_index = cp->bit_idx[0];
      unsigned off_index = cp->bit_idx[1];

      long adr = adr_index? thr->words[adr_index].w_int : 0;
      int64_t off = off_index ? thr->words[off_index].w_int : 0;

	// Suppress action if flags-4 is true.
      if (thr->flags[4] == BIT4_1) {
	    thr->pop_vec4(1);
	    return true;
      }

      vvp_array_t array = resolve_runtime_array_(cp, "%store/vec4a");
      if (!array) {
	    thr->pop_vec4(1);
	    return true;
      }

      vvp_vector4_t &value = thr->peek_vec4();

      if (!resize_rval_vec(value, off, array->get_word_size())) {
	    thr->pop_vec4(1);
	    return true;
      }

      array->set_word(adr, off, value);

      thr->pop_vec4(1);
      return true;
}

/*
 * %sub
 *   pop r;
 *   pop l;
 *   push l-r;
 */
bool of_SUB(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t r = thr->pop_vec4();
      vvp_vector4_t&l = thr->peek_vec4();

      l.sub(r);
      return true;
}

/*
 * %subi <vala>, <valb>, <wid>
 *
 * Pop1 operand, get the other operand from the arguments, and push
 * the result.
 */
bool of_SUBI(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;

      vvp_vector4_t&l = thr->peek_vec4();

	// I expect that most of the bits of an immediate value are
	// going to be zero, so start the result vector with all zero
	// bits. Then we only need to replace the bits that are different.
      vvp_vector4_t r (wid, BIT4_0);
      get_immediate_rval (cp, r);

      l.sub(r);

      return true;

}

bool of_SUB_WR(vthread_t thr, vvp_code_t)
{
      double r = thr->pop_real();
      double l = thr->pop_real();
      thr->push_real(l - r);
      return true;
}

/*
 * %substr <first>, <last>
 * Pop a string, take the substring (SystemVerilog style), and return
 * the result to the stack. This opcode actually works by editing the
 * string in place.
 */
bool of_SUBSTR(vthread_t thr, vvp_code_t cp)
{
      int32_t first = thr->words[cp->bit_idx[0]].w_int;
      int32_t last = thr->words[cp->bit_idx[1]].w_int;
      string&val = thr->peek_str(0);

      if (first < 0 || last < first || last >= (int32_t)val.size()) {
	    val = string("");
	    return true;
      }

      val = val.substr(first, last-first+1);
      return true;
}

/*
 * %substr/vec4 <index>, <wid>
 */
bool of_SUBSTR_VEC4(vthread_t thr, vvp_code_t cp)
{
      unsigned sel_idx = cp->bit_idx[0];
      unsigned wid = cp->bit_idx[1];

      int32_t sel = thr->words[sel_idx].w_int;
      const string&val = thr->peek_str(0);

      assert(wid%8 == 0);

      if (sel < 0 || sel >= (int32_t)val.size()) {
	    vvp_vector4_t res (wid, BIT4_0);
	    thr->push_vec4(res);
	    return true;
      }

      vvp_vector4_t res (wid, BIT4_0);

      assert(wid==8);
      unsigned char tmp = val[sel];
      for (int idx = 0 ; idx < 8 ; idx += 1) {
	    if (tmp & (1<<idx))
		  res.set_bit(idx, BIT4_1);
      }

      thr->push_vec4(res);
      return true;
}

bool of_FILE_LINE(vthread_t thr, vvp_code_t cp)
{
      vpiHandle handle = cp->handle;

	/* When it is available, keep the file/line information in the
	   thread for error/warning messages. */
      thr->set_fileline(vpi_get_str(vpiFile, handle),
                        vpi_get(vpiLineNo, handle));

      if (show_file_line)
	    cerr << thr->get_fileline()
	         << vpi_get_str(_vpiDescription, handle) << endl;

      return true;
}

/*
 * %test_nul <var-label>;
 * Test if the object at the specified variable is nil. If so, write
 * "1" into flags[4], otherwise write "0" into flags[4].
 */
bool of_TEST_NUL(vthread_t thr, vvp_code_t cp)
{
      vvp_net_t*net = cp->net;

      assert(net);
      vvp_fun_signal_object*obj = dynamic_cast<vvp_fun_signal_object*> (net->fun);
      assert(obj);

      bool is_nil = obj->get_object().test_nil();
      if (is_nil)
	    thr->flags[4] = BIT4_1;
      else
	    thr->flags[4] = BIT4_0;

      const char*scope_name = scope_name_or_unknown_(thr->parent_scope);
      if (scope_trace_enabled_("IVL_TEST_NUL_TRACE", scope_name)) {
            fprintf(stderr,
                    "trace test_nul scope=%s net=%p nil=%d flag4=%d\n",
                    scope_name, (void*)net,
                    is_nil ? 1 : 0,
                    thr->flags[4] == BIT4_1 ? 1 : 0);
      }

      return true;
}

bool of_TEST_NUL_A(vthread_t thr, vvp_code_t cp)
{
      unsigned idx = cp->bit_idx[0];
      unsigned adr = thr->words[idx].w_int;
      vvp_object_t word;

	/* If the address is undefined, return true. */
      if (thr->flags[4] == BIT4_1) {
	    thr->flags[4] = BIT4_1;
	    return true;
      }

      vvp_array_t array = resolve_runtime_array_(cp, "%test_nul/a");
      if (!array) {
	    thr->flags[4] = BIT4_1;
	    return true;
      }

      array->get_word_obj(adr, word);
      if (word.test_nil())
	    thr->flags[4] = BIT4_1;
      else
	    thr->flags[4] = BIT4_0;

      return true;
}

bool of_TEST_NUL_OBJ(vthread_t thr, vvp_code_t)
{
      if (thr->peek_object().test_nil())
	    thr->flags[4] = BIT4_1;
      else
	    thr->flags[4] = BIT4_0;
      return true;
}

/*
 * %test_nul/prop <pid>, <idx>
 */
bool of_TEST_NUL_PROP(vthread_t thr, vvp_code_t cp)
{
      unsigned pid = cp->number;
      unsigned idx = cp->bit_idx[0];

      if (idx != 0) {
	    assert(idx < vthread_s::WORDS_COUNT);
	    idx = thr->words[idx].w_uint;
      }

      vvp_object_t&obj = thr->peek_object();
      vvp_cobject*cobj  = obj.peek<vvp_cobject>();
      vvp_vinterface*vif = obj.peek<vvp_vinterface>();
      bool has_propobj = cobj != 0 || vif != 0;
      if (!has_propobj) {
	    thr->flags[4] = obj.test_nil() ? BIT4_1 : BIT4_0;
	    if (!obj.test_nil()) {
		  static bool warned = false;
		  if (!warned) {
			cerr << thr->get_fileline()
			     << "Warning: %test_nul/prop on unsupported object handle"
			     << " (pid=" << pid << ", idx=" << idx
			     << ", pc=" << (void*)cp << "); using receiver-null test fallback." << endl;
			warned = true;
		  }
	    }
	    return true;
      }

      vvp_object_t val;
      if (cobj)
	    cobj->get_object(pid, val, idx);
      else
	    vif->get_object(pid, val, idx);

      if (val.test_nil())
	    thr->flags[4] = BIT4_1;
      else
	    thr->flags[4] = BIT4_0;

      return true;
}

bool of_VPI_CALL(vthread_t thr, vvp_code_t cp)
{
      string tf_name_storage;
      string thr_scope_storage;
      string call_scope_storage;
      const char*tf_name = 0;
      const char*thr_scope = 0;
      const char*call_scope = 0;
      const char*next_op = "<nullpc>";
      bool trace = false;

      if (vpi_call_trace_enabled_()) {
            if (cp->handle) {
                  const char*name = vpi_get_str(vpiName, cp->handle);
                  if (name) {
                        tf_name_storage = name;
                        tf_name = tf_name_storage.c_str();
                  }
            }
            if (thr && thr->parent_scope) {
                  const char*name = vpi_get_str(vpiFullName, thr->parent_scope);
                  if (name) {
                        thr_scope_storage = name;
                        thr_scope = thr_scope_storage.c_str();
                  }
            }
            if (cp->handle) {
                  vpiHandle scope = vpi_handle(vpiScope, cp->handle);
                  if (scope) {
                        const char*name = vpi_get_str(vpiFullName, scope);
                        if (name) {
                              call_scope_storage = name;
                              call_scope = call_scope_storage.c_str();
                        }
                  }
            }
            if (thr && thr->pc)
                  next_op = vvp_opcode_mnemonic(thr->pc->opcode);
            trace = vpi_call_trace_match_(thr_scope, tf_name, call_scope);
      }

      vpip_execute_vpi_call(thr, cp->handle);

      if (trace) {
            fprintf(stderr,
                    "trace vpi-call: scope=%s tf=%s call_scope=%s stopped=%d finished=%d next_op=%s pc=%p\n",
                    thr_scope ? thr_scope : "<unknown>",
                    tf_name ? tf_name : "<unnamed>",
                    call_scope ? call_scope : "<unknown>",
                    schedule_stopped() ? 1 : 0,
                    schedule_finished() ? 1 : 0,
                    next_op,
                    thr ? (void*)thr->pc : 0);
            fflush(stderr);
      }

      if (schedule_stopped()) {
	    if (! schedule_finished())
		  schedule_vthread(thr, 0, false);

            if (trace) {
                  fprintf(stderr,
                          "trace vpi-call-pause: scope=%s tf=%s call_scope=%s next_op=%s pc=%p\n",
                          thr_scope ? thr_scope : "<unknown>",
                          tf_name ? tf_name : "<unnamed>",
                          call_scope ? call_scope : "<unknown>",
                          next_op,
                          thr ? (void*)thr->pc : 0);
                  fflush(stderr);
            }

	    return false;
      }

      if (trace && schedule_finished()) {
            fprintf(stderr,
                    "trace vpi-call-finish: scope=%s tf=%s call_scope=%s next_op=%s pc=%p\n",
                    thr_scope ? thr_scope : "<unknown>",
                    tf_name ? tf_name : "<unnamed>",
                    call_scope ? call_scope : "<unknown>",
                    next_op,
                    thr ? (void*)thr->pc : 0);
            fflush(stderr);
      }

      return schedule_finished()? false : true;
}

/* %wait <label>;
 * Implement the wait by locating the vvp_net_T for the event, and
 * adding this thread to the threads list for the event. The some
 * argument is the  reference to the functor to wait for. This must be
 * an event object of some sort.
 */
bool of_WAIT(vthread_t thr, vvp_code_t cp)
{
      if (thr->i_am_in_function) {
            static bool warned = false;
            if (!warned) {
                  const char*scope_name = thr && thr->parent_scope
                                        ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
                  fprintf(stderr,
                          "Warning: %%wait reached from function thread; promoting thread to schedulable wait"
                          " (scope=%s pc=%p; further similar warnings suppressed)\n",
                          scope_name ? scope_name : "<unknown>",
                          (void*)cp);
                  warned = true;
            }
            thr->i_am_in_function = 0;
      }
      assert(! thr->waiting_for_event);
      thr->waiting_for_event = 1;

	/* Add this thread to the list in the event. */
      waitable_hooks_s*ep = dynamic_cast<waitable_hooks_s*> (cp->net->fun);
      assert(ep);
      thr->wait_next = ep->add_waiting_thread(thr);

	/* Return false to suspend this thread. */
      return false;
}

/*
 * Implement the %wait/fork (SystemVerilog) instruction by suspending
 * the current thread until all the detached children have finished.
 */
bool of_WAIT_FORK(vthread_t thr, vvp_code_t)
{
	/* If a %wait/fork is being executed then the parent thread
	 * cannot be waiting in a join or already waiting. */
      if (thr->i_am_in_function) {
            static bool warned = false;
            if (!warned) {
                  const char*scope_name = thr && thr->parent_scope
                                        ? vpi_get_str(vpiFullName, thr->parent_scope) : 0;
                  fprintf(stderr,
                          "Warning: %%wait/fork reached from function thread; promoting thread to schedulable wait"
                          " (scope=%s; further similar warnings suppressed)\n",
                          scope_name ? scope_name : "<unknown>");
                  warned = true;
            }
            thr->i_am_in_function = 0;
      }
      assert(! thr->i_am_joining);
      assert(! thr->i_am_waiting);

	/* There should be no active children when waiting. */
      assert(thr->children.empty());

	/* If there are no detached children then there is nothing to
	 * wait for. */
      if (thr->detached_children.empty()) return true;

	/* Flag that this process is waiting for the detached children
	 * to finish and suspend it. */
      thr->i_am_waiting = 1;
      return false;
}

/*
 * %wait/vif/posedge <M>
 * Pop a vvp_vinterface object from the object stack (loaded by
 * %load/obj + %prop/obj N, 0), get or create a vvp_fun_edge_sa
 * subscribed to the M-th signal of the interface, add this thread
 * to its wait list, and suspend until posedge fires.
 */
bool of_WAIT_VIF_POSEDGE(vthread_t thr, vvp_code_t cp)
{
      vvp_object_t obj;
      thr->pop_object(obj);
      vvp_vinterface*vif = obj.peek<vvp_vinterface>();
      if (!vif) {
	    vvp_cobject*cobj = obj.peek<vvp_cobject>();
	    fprintf(stderr, "%%wait/vif/posedge: object is not a virtual interface"
	            " (nil=%d, cobject=%p, raw=%p)\n",
	            (int)obj.test_nil(), (void*)cobj, (void*)obj.peek<vvp_object>());
	    assert(vif);
      }

      vvp_fun_edge_sa*edge = vif->get_posedge_functor(cp->number);

      thr->waiting_for_event = 1;
      thr->wait_next = edge->add_waiting_thread(thr);
      return false;
}

bool of_WAIT_VIF_NEGEDGE(vthread_t thr, vvp_code_t cp)
{
      vvp_object_t obj;
      thr->pop_object(obj);
      vvp_vinterface*vif = obj.peek<vvp_vinterface>();
      if (!vif) {
	    fprintf(stderr, "%%wait/vif/negedge: object is not a virtual interface\n");
	    assert(vif);
      }

      vvp_fun_edge_sa*edge = vif->get_negedge_functor(cp->number);

      thr->waiting_for_event = 1;
      thr->wait_next = edge->add_waiting_thread(thr);
      return false;
}

bool of_WAIT_VIF_ANYEDGE(vthread_t thr, vvp_code_t cp)
{
      vvp_object_t obj;
      thr->pop_object(obj);
      vvp_vinterface*vif = obj.peek<vvp_vinterface>();
      if (!vif) {
	    fprintf(stderr, "%%wait/vif/anyedge: object is not a virtual interface\n");
	    assert(vif);
      }

      vvp_fun_edge_sa*edge = vif->get_anyedge_functor(cp->number);

      thr->waiting_for_event = 1;
      thr->wait_next = edge->add_waiting_thread(thr);
      return false;
}

/*
 * %xnor
 */
bool of_XNOR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t valr = thr->pop_vec4();
      vvp_vector4_t&vall = thr->peek_vec4();
      assert(vall.size() == valr.size());
      unsigned wid = vall.size();

      for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {

	    vvp_bit4_t lb = vall.value(idx);
	    vvp_bit4_t rb = valr.value(idx);
	    vall.set_bit(idx, ~(lb ^ rb));
      }

      return true;
}

/*
 * %xor
 */
bool of_XOR(vthread_t thr, vvp_code_t)
{
      vvp_vector4_t valr = thr->pop_vec4();
      vvp_vector4_t&vall = thr->peek_vec4();
      assert(vall.size() == valr.size());
      unsigned wid = vall.size();

      for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {

	    vvp_bit4_t lb = vall.value(idx);
	    vvp_bit4_t rb = valr.value(idx);
	    vall.set_bit(idx, lb ^ rb);
      }

      return true;
}


bool of_ZOMBIE(vthread_t thr, vvp_code_t)
{
      thr->pc = codespace_null();
      if ((thr->parent == 0) && (thr->children.empty())) {
	    if (thr->delay_delete) {
		  if (!thr->delete_pending) {
			thr->delete_pending = 1;
			schedule_del_thr(thr);
		  }
	    }
	    else
		  vthread_delete(thr);
      }
      return false;
}

/*
 * This is a phantom opcode used to call user defined functions. It
 * is used in code generated by the .ufunc statement. It contains a
 * pointer to the executable code of the function and a pointer to
 * a ufunc_core object that has all the port information about the
 * function.
 */
static bool do_exec_ufunc(vthread_t thr, vvp_code_t cp, vthread_t child)
{
      __vpiScope*child_scope = cp->ufunc_core_ptr->func_scope();
      assert(child_scope);
      __vpiScope*ctx_scope = resolve_context_scope(child_scope);

      assert(child_scope->get_type_code() == vpiFunction);
      assert(thr->children.empty());


        /* We can take a number of shortcuts because we know that a
           continuous assignment can only occur in a static scope. */
      assert(thr->wt_context == 0);
      assert(thr->rd_context == 0);

        /* If an automatic function, allocate a context for this call. */
      vvp_context_t child_context = 0;
      if (child_scope->is_automatic()) {
            child_context = vthread_alloc_context(ctx_scope);
            thr->wt_context = child_context;
            thr->rd_context = child_context;
      }

      child->wt_context = child_context;
      child->rd_context = child_context;

	/* Copy all the inputs to the ufunc object to the port
	   variables of the function. This copies all the values
	   atomically. */
      cp->ufunc_core_ptr->assign_bits_to_ports(child_context);
      child->delay_delete = 1;

      child->parent = thr;
      thr->children.insert(child);
	// This should be the only child
      assert(thr->children.size()==1);

      child->is_scheduled = 1;
      child->i_am_in_function = 1;
      vthread_run(child);
      running_thread = thr;

      if (child->i_have_ended) {
	    do_join(thr, child);
            return true;
      } else {
	    thr->i_am_joining = 1;
	    return false;
      }
}

bool of_EXEC_UFUNC_REAL(vthread_t thr, vvp_code_t cp)
{
      __vpiScope*child_scope = cp->ufunc_core_ptr->func_scope();
      assert(child_scope);

	/* Create a temporary thread and run it immediately. */
      vthread_t child = vthread_new(cp->cptr, child_scope);
      thr->push_real(0.0);
      child->args_real.push_back(0);

      return do_exec_ufunc(thr, cp, child);
}

bool of_EXEC_UFUNC_VEC4(vthread_t thr, vvp_code_t cp)
{
      __vpiScope*child_scope = cp->ufunc_core_ptr->func_scope();
      assert(child_scope);

      vpiScopeFunction*scope_func = dynamic_cast<vpiScopeFunction*>(child_scope);
      assert(scope_func);

	/* Create a temporary thread and run it immediately. */
      vthread_t child = vthread_new(cp->cptr, child_scope);
      thr->push_vec4(vvp_vector4_t(scope_func->get_func_width(), scope_func->get_func_init_val()));
      child->args_vec4.push_back(0);

      return do_exec_ufunc(thr, cp, child);
}

/*
 * This is a phantom opcode used to harvest the result of calling a user
 * defined function. It is used in code generated by the .ufunc statement.
 */
bool of_REAP_UFUNC(vthread_t thr, vvp_code_t cp)
{
      __vpiScope*child_scope = cp->ufunc_core_ptr->func_scope();
      assert(child_scope);
      __vpiScope*ctx_scope = resolve_context_scope(child_scope);

	/* Copy the output from the result variable to the output
	   ports of the .ufunc device. */
      cp->ufunc_core_ptr->finish_thread();

        /* If an automatic function, free the context for this call. */
      if (child_scope->is_automatic()) {
            vthread_free_context(thr->rd_context, ctx_scope);
            thr->wt_context = 0;
            thr->rd_context = 0;
      }

      return true;
}

/* ================================================================
 * Free functions to access vthread_s object stack from external
 * translation units (e.g. vvp_mailbox.cc).
 * ================================================================ */

void vthread_push_obj_item(struct vthread_s*thr, const vvp_object_t&obj)
{
      thr->push_object(obj);
}

void vthread_pop_obj_item(struct vthread_s*thr, vvp_object_t&obj)
{
      thr->pop_object(obj);
}

/* ================================================================
 * Mailbox opcodes
 * ================================================================ */

/*
 * %mbx/new <bound>
 * Create a new vvp_mailbox with the given bound (0 = unbounded) and
 * push it as an object onto the obj stack.
 */
bool of_MBX_NEW(vthread_t thr, vvp_code_t cp)
{
      size_t bound = cp->number;
      vvp_object_t mbx(new vvp_mailbox(bound));
      thr->push_object(mbx);
      return true;
}

/*
 * %mbx/put
 * Stack (top->bottom): item, mailbox
 * Pop both. If mailbox is full, suspend thread (item stored in waiter).
 * If not full, put item into mailbox immediately.
 */
bool of_MBX_PUT(vthread_t thr, vvp_code_t)
{
      vvp_object_t item_obj;
      thr->pop_object(item_obj);
      vvp_object_t mbx_obj;
      thr->pop_object(mbx_obj);

      vvp_mailbox*mbx = mbx_obj.peek<vvp_mailbox>();
      if (!mbx) return true; /* null mailbox: silently ignore */

      bool done = mbx->put(thr, item_obj);
      if (!done) return false; /* thread suspended */
      return true;
}

/*
 * %mbx/get
 * Stack (top->bottom): mailbox
 * Pop mailbox. If empty, suspend thread; when resumed the item will
 * have been pushed onto the obj stack by resume_get_waiters_().
 * If not empty, get item and push it onto the obj stack.
 */
bool of_MBX_GET(vthread_t thr, vvp_code_t)
{
      vvp_object_t mbx_obj;
      thr->pop_object(mbx_obj);

      vvp_mailbox*mbx = mbx_obj.peek<vvp_mailbox>();
      if (!mbx) {
	    thr->push_object(vvp_object_t()); /* null item */
	    return true;
      }

      vvp_object_t item;
      bool done = mbx->get(thr, item);
      if (!done) return false; /* thread suspended */
      thr->push_object(item);
      return true;
}

/*
 * %mbx/peek
 * Stack (top->bottom): mailbox
 * Pop mailbox. If empty, suspend thread; when resumed the item will
 * have been pushed onto the obj stack by resume_get_waiters_().
 * If not empty, peek at front item and push it (mailbox unchanged).
 */
bool of_MBX_PEEK(vthread_t thr, vvp_code_t)
{
      vvp_object_t mbx_obj;
      thr->pop_object(mbx_obj);

      vvp_mailbox*mbx = mbx_obj.peek<vvp_mailbox>();
      if (!mbx) {
	    thr->push_object(vvp_object_t()); /* null item */
	    return true;
      }

      vvp_object_t item;
      bool done = mbx->peek(thr, item);
      if (!done) return false; /* thread suspended */
      thr->push_object(item);
      return true;
}

/*
 * %mbx/try_put
 * Stack (top->bottom): item, mailbox
 * Non-blocking put. Push result (1=success, 0=full) onto vec4 stack.
 */
bool of_MBX_TRY_PUT(vthread_t thr, vvp_code_t)
{
      vvp_object_t item_obj;
      thr->pop_object(item_obj);
      vvp_object_t mbx_obj;
      thr->pop_object(mbx_obj);

      vvp_mailbox*mbx = mbx_obj.peek<vvp_mailbox>();
      bool ok = mbx ? mbx->try_put(item_obj) : false;
      vvp_vector4_t res(1, ok ? BIT4_1 : BIT4_0);
      thr->push_vec4(res);
      return true;
}

/*
 * %mbx/try_get
 * Stack (top->bottom): mailbox
 * Non-blocking get. If successful, push item onto obj stack; push
 * result (1=got item, 0=empty) onto vec4 stack.
 * If empty, push null onto obj stack and push 0 onto vec4 stack.
 */
bool of_MBX_TRY_GET(vthread_t thr, vvp_code_t)
{
      vvp_object_t mbx_obj;
      thr->pop_object(mbx_obj);

      vvp_mailbox*mbx = mbx_obj.peek<vvp_mailbox>();
      vvp_object_t item;
      bool ok = mbx ? mbx->try_get(item) : false;
      thr->push_object(ok ? item : vvp_object_t());
      vvp_vector4_t res(1, ok ? BIT4_1 : BIT4_0);
      thr->push_vec4(res);
      return true;
}

/*
 * %mbx/try_peek
 * Stack (top->bottom): mailbox
 * Non-blocking peek. If successful, push item onto obj stack; push
 * result (1=item present, 0=empty) onto vec4 stack.
 */
bool of_MBX_TRY_PEEK(vthread_t thr, vvp_code_t)
{
      vvp_object_t mbx_obj;
      thr->pop_object(mbx_obj);

      vvp_mailbox*mbx = mbx_obj.peek<vvp_mailbox>();
      vvp_object_t item;
      bool ok = mbx ? mbx->try_peek(item) : false;
      thr->push_object(ok ? item : vvp_object_t());
      vvp_vector4_t res(1, ok ? BIT4_1 : BIT4_0);
      thr->push_vec4(res);
      return true;
}

/*
 * %mbx/num
 * Stack (top->bottom): mailbox
 * Pop mailbox. Push item count onto vec4 stack as a 32-bit integer.
 */
bool of_MBX_NUM(vthread_t thr, vvp_code_t)
{
      vvp_object_t mbx_obj;
      thr->pop_object(mbx_obj);

      vvp_mailbox*mbx = mbx_obj.peek<vvp_mailbox>();
      unsigned long cnt = mbx ? (unsigned long)mbx->num() : 0UL;
      vvp_vector4_t res(32);
      for (unsigned idx = 0; idx < 32; ++idx)
	    res.set_bit(idx, (cnt >> idx) & 1 ? BIT4_1 : BIT4_0);
      thr->push_vec4(res);
      return true;
}

/* ================================================================
 * Semaphore opcodes
 * ================================================================ */

/*
 * %sem/new <initial_count>
 * Create a new vvp_semaphore with the given initial key count and
 * push it as an object onto the obj stack.
 */
bool of_SEM_NEW(vthread_t thr, vvp_code_t cp)
{
      size_t cnt = cp->number;
      vvp_object_t sem(new vvp_semaphore(cnt));
      thr->push_object(sem);
      return true;
}

/*
 * %sem/get
 * Stack (obj top->bottom): semaphore
 * Stack (vec4 top): N (number of keys to acquire)
 * Pop semaphore from obj stack, N from vec4 stack.
 * Block thread until N keys available.
 */
bool of_SEM_GET(vthread_t thr, vvp_code_t)
{
      /* Read N from vec4 stack top, compute integer value */
      unsigned long nval = 0;
      {
	    const vvp_vector4_t& nv = thr->peek_vec4(0);
	    unsigned nbits = nv.size() < 32 ? nv.size() : 32;
	    for (unsigned i = 0; i < nbits; ++i)
		  if (nv.value(i) == BIT4_1) nval |= (1UL << i);
      }
      thr->pop_vec4(1);

      vvp_object_t sem_obj;
      thr->pop_object(sem_obj);

      vvp_semaphore*sem = sem_obj.peek<vvp_semaphore>();
      if (!sem) return true; /* null semaphore: ignore */

      bool done = sem->get(thr, nval ? nval : 1);
      if (!done) return false; /* thread suspended */
      return true;
}

/*
 * %sem/put
 * Stack (obj top->bottom): semaphore
 * Stack (vec4 top): N (number of keys to release)
 * Pop both; add N keys to semaphore.
 */
bool of_SEM_PUT(vthread_t thr, vvp_code_t)
{
      unsigned long nval = 0;
      {
	    const vvp_vector4_t& nv = thr->peek_vec4(0);
	    unsigned nbits = nv.size() < 32 ? nv.size() : 32;
	    for (unsigned i = 0; i < nbits; ++i)
		  if (nv.value(i) == BIT4_1) nval |= (1UL << i);
      }
      thr->pop_vec4(1);

      vvp_object_t sem_obj;
      thr->pop_object(sem_obj);

      vvp_semaphore*sem = sem_obj.peek<vvp_semaphore>();
      if (sem) sem->put(nval ? nval : 1);
      return true;
}

/*
 * %sem/try_get
 * Stack (obj top->bottom): semaphore
 * Stack (vec4 top): N
 * Non-blocking try. Pop both; push result (1=success, 0=fail) onto vec4 stack.
 */
bool of_SEM_TRY_GET(vthread_t thr, vvp_code_t)
{
      unsigned long nval = 0;
      {
	    const vvp_vector4_t& nv = thr->peek_vec4(0);
	    unsigned nbits = nv.size() < 32 ? nv.size() : 32;
	    for (unsigned i = 0; i < nbits; ++i)
		  if (nv.value(i) == BIT4_1) nval |= (1UL << i);
      }
      thr->pop_vec4(1);

      vvp_object_t sem_obj;
      thr->pop_object(sem_obj);

      vvp_semaphore*sem = sem_obj.peek<vvp_semaphore>();
      bool ok = sem ? sem->try_get(nval ? nval : 1) : false;
      vvp_vector4_t res(1, ok ? BIT4_1 : BIT4_0);
      thr->push_vec4(res);
      return true;
}

/* ================================================================
 * Boxing/unboxing opcodes for non-class mailbox items
 * ================================================================ */

/*
 * %box/vec4 <width>
 * Pop a <width>-bit vec4 from the vec4 stack, wrap it in a
 * vvp_boxed_vec4 object, and push the object onto the obj stack.
 */
bool of_BOX_VEC4(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;
      vvp_vector4_t v(wid);
      const vvp_vector4_t& top = thr->peek_vec4(0);
      unsigned bits = top.size() < wid ? top.size() : wid;
      for (unsigned i = 0; i < bits; ++i)
	    v.set_bit(i, top.value(i));
      thr->pop_vec4(1);
      vvp_object_t box(new vvp_boxed_vec4(v));
      thr->push_object(box);
      return true;
}

/*
 * %unbox/vec4 <width>
 * Pop an object from the obj stack.  If it is a vvp_boxed_vec4,
 * extract its vec4 value and push <width> bits onto the vec4 stack.
 * If not (e.g. null), push a zero vec4.
 */
bool of_UNBOX_VEC4(vthread_t thr, vvp_code_t cp)
{
      unsigned wid = cp->number;
      vvp_object_t obj;
      thr->pop_object(obj);
      vvp_vector4_t res(wid, BIT4_0);
      if (vvp_boxed_vec4*box = obj.peek<vvp_boxed_vec4>()) {
	    const vvp_vector4_t& v = box->get_value();
	    unsigned bits = v.size() < wid ? v.size() : wid;
	    for (unsigned i = 0; i < bits; ++i)
		  res.set_bit(i, v.value(i));
      }
      thr->push_vec4(res);
      return true;
}
