#ifndef IVL_scalar_event_history_H
#define IVL_scalar_event_history_H
/*
 * Copyright (c) 2004-2025 Stephen Williams (steve@icarus.com)
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
#include "vpi_priv.h"
#include "vthread.h"
#include <memory>

// A scalar update from an enclosing activation belongs only to descendants
// of that activation. Static and unrelated notifications retain fanout.
inline __vpiScope* automatic_event_source_scope_(vvp_context_t source,
                                                __vpiScope*target)
{
      if (!source) return 0;
      for (__vpiScope*scope = target; scope; scope = scope->scope)
            if (vthread_context_live_matches_scope(source, scope))
                  return scope;
      return 0;
}

// A recursive caller may have the target child scope on its stack. An
// ancestor notification must select descendants of its source activation,
// never recover a caller's child frame above that activation.
inline vvp_context_t scalar_event_native_context_(vvp_context_t source,
      __vpiScope*source_scope, __vpiScope*target)
{
      return (!source_scope || source_scope == target)
            ? vthread_recover_stacked_context_for_scope(source, target) : nullptr;
}

// Scalar history received before a descendant activation exists must belong
// to its source activation, not a shared functor-wide last-value cache.
struct scalar_event_sample {
      uint64_t stamp;
      vvp_vector4_t vector;
      double real = 0.0;
      std::string string;
      scalar_event_sample(uint64_t n, const vvp_vector4_t&v) : stamp(n), vector(v) {}
      scalar_event_sample(uint64_t n, double v) : stamp(n), real(v) {}
      scalar_event_sample(uint64_t n, const std::string&v) : stamp(n), string(v) {}
};

class scalar_event_history {
      struct slots {
            std::unique_ptr<scalar_event_sample> value[4];
      };
      struct ancestor : automatic_hooks_s {
            __vpiScope*scope;
            unsigned index;
            explicit ancestor(__vpiScope*s) : scope(s)
            { index = vpip_add_item_to_context(this, scope); }
            void alloc_instance(vvp_context_t c) override
            { vvp_set_context_item(c, index, new slots); }
            void reset_instance(vvp_context_t c) override
            {
                  slots*values = static_cast<slots*>(vvp_get_context_item(c, index));
                  for (auto&value : values->value) value.reset();
            }
#ifdef CHECK_WITH_VALGRIND
            void free_instance(vvp_context_t c) override
            { delete static_cast<slots*>(vvp_get_context_item(c, index)); }
#endif
      };
      __vpiScope*scope_;
      std::vector<ancestor*> ancestors_;
      uint64_t sequence_ = 0;
      uint64_t static_stamp_[4] = {};

    public:
      explicit scalar_event_history(__vpiScope*scope) : scope_(scope)
      {
            for (scope = scope->scope; scope; scope = scope->scope)
                  if (scope->has_automatic_context() && !scope->shares_parent_frame())
                        ancestors_.push_back(new ancestor(scope));
      }
      uint64_t next() { return ++sequence_; }
      uint64_t static_stamp(unsigned port) const { return static_stamp_[port]; }
      const scalar_event_sample* previous(vvp_context_t context, unsigned port,
                                           uint64_t stamp) const
      {
            const scalar_event_sample*best = nullptr;
            for (ancestor*item : ancestors_) {
                  vvp_context_t owner = vthread_recover_stacked_context_for_scope(context, item->scope);
                  if (!owner) continue;
                  slots*values = static_cast<slots*>(vvp_get_context_item(owner, item->index));
                  const scalar_event_sample*value = values->value[port].get();
                  if (value && value->stamp > stamp) {
                        best = value;
                        stamp = value->stamp;
                  }
            }
            return best;
      }
      template<class T> void remember(vvp_context_t source, unsigned port,
                                      uint64_t stamp, const T&value)
      {
            for (ancestor*item : ancestors_) {
                  if (!vthread_context_live_matches_scope(source, item->scope)) continue;
                  slots*values = static_cast<slots*>(vvp_get_context_item(source, item->index));
                  auto&old = values->value[port];
                  if (!old || old->stamp < stamp)
                        old.reset(new scalar_event_sample(stamp, value));
                  return;
            }
            // Check ancestors first: recursive callers can contain another
            // instance of the probe scope above the source activation.
            if (vthread_recover_stacked_context_for_scope(source, scope_)) return;
            if (static_stamp_[port] < stamp) static_stamp_[port] = stamp;
      }
};

#endif
