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

# include  "compile.h"
# include  "codes.h"
# include  "vvp_vpi_callback.h"
# include  "vpi_priv.h"
# include  "class_type.h"
# include  "udp.h"
# include  "symbols.h"
# include  "statistics.h"
# include  "schedule.h"
# include  "vthread.h"
# include  "vvp_net_sig.h"
# include  "config.h"
# include  <map>
# include  <utility>
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <vector>
# include  <cerrno>
# include  <climits>
# include  <cstring>
# include  <cstdlib>
# include  <cassert>
# include  "ivl_alloc.h"
# include  "array_common.h"

#ifndef vpiProcess
# define vpiProcess 99
#endif

using namespace std;

static vector<vpiHandle> vpip_root_table;

static vpiHandle make_subset_iterator_(int type_code, const vector<vpiHandle>&table);

vpiHandle vpip_make_root_iterator(int type_code)
{
      return make_subset_iterator_(type_code, vpip_root_table);
}

void vpip_make_root_iterator(__vpiHandle**&table, unsigned&ntable)
{
      table = &vpip_root_table[0];
      ntable = vpip_root_table.size();
}

#ifdef CHECK_WITH_VALGRIND
void port_delete(__vpiHandle*handle);
void port_bit_delete(__vpiHandle*handle);

/* Class definitions need to be cleaned up at the end. */
static class_type **class_list = 0;
static unsigned class_list_count = 0;

static void delete_sub_scopes(__vpiScope *scope)
{
      for (unsigned idx = 0; idx < scope->intern.size(); idx += 1) {
	    vpiHandle item = (scope->intern)[idx];
	    if (item->is_typedef_typespec()) {
		  delete item;
		  continue;
	    }
	    __vpiScope*lscope = static_cast<__vpiScope*>(item);
	    switch(item->get_type_code()) {
		case vpiFunction:
		case vpiTask:
		  contexts_delete(lscope);
		  // fallthrough
		case vpiModule:
		case vpiGenScope:
		case vpiNamedBegin:
		case vpiNamedFork:
		case vpiClassTypespec:
		  delete_sub_scopes(lscope);
		  vthreads_delete(lscope);
		  delete item;
		  break;
		case vpiMemory:
		case vpiNetArray:
		  memory_delete(item);
		  break;
		case vpiModPath:
		    /* The destination ModPath is cleaned up later. */
		  delete item;
		  break;
		case vpiInterModPath:
		case vpiTchk:
		  delete item;
		  break;
		case vpiNamedEvent:
		  named_event_delete(item);
		  break;
		case vpiNet:
		case vpiReg:
		case vpiIntegerVar:
		case vpiLongIntVar:
		case vpiShortIntVar:
		case vpiIntVar:
		case vpiByteVar:
		case vpiBitVar:
		  signal_delete(item);
		  break;
		case vpiParameter:
		  parameter_delete(item);
		  break;
		case vpiTypeParameter:
		  vpip_type_parameter_delete(item);
		  break;
		case vpiRealVar:
		  real_delete(item);
		  break;
		case vpiEnumTypespec:
		  enum_delete(item);
		  break;
		case vpiPort:
		  port_delete(item);
		  break;
		case vpiPortBit:
		  port_bit_delete(item);
		  break;
		case vpiStringVar:
		  string_delete(item);
		  break;
		case VPI_IODECL_TYPE:
		case vpiParamAssign:
		case vpiContAssign:
		case vpiDefParam:
		  delete item;
		  break;
		case vpiClassVar:
		case vpiVirtualInterfaceVar:
		  class_delete(item);
		  break;
		case vpiArrayVar:
		  array_delete(item);
		  break;
		case vpiPrimitive:
		  delete item;
		  break;
		case vpiBegin:
		case vpiAssignment:
		case vpiContAssign:
		case vpiDeassign:
		case vpiDoWhile:
		case vpiEventStmt:
		case vpiFork:
		case vpiForce:
		case vpiIfElse:
		case vpiForInitStmt:
		case vpiForIncStmt:
		case vpiNullStmt:
		case vpiOrderedWait:
		case vpiWaitFork:
		case vpiDisableFork:
		case vpiBreak:
		case vpiContinue:
		case vpiReturnStmt:
		case vpiRelease:
		case vpiAssignStmt:
		case vpiCase:
		case vpiDelayControl:
		case vpiDisable:
		case vpiEventControl:
		case vpiForever:
		case vpiIf:
		case vpiRepeat:
		case vpiSysTaskCall:
		case vpiTaskCall:
		case vpiWait:
		case vpiWhile:
		  delete item;
		  break;
		default:
		  fprintf(stderr, "Need support for type: %d\n",
		          item->get_type_code());
		  assert(0);
		  break;
	    }
      }
      scope->intern.clear();
	for (size_t idx = 0; idx < scope->statement_nodes.size(); idx += 1)
	      delete scope->statement_nodes[idx];
	scope->statement_nodes.clear();

	/* Save any class definitions to clean up later. */
      map<std::string, class_type*>::iterator citer;
      for (citer = scope->classes.begin();
           citer != scope->classes.end(); ++ citer ) {
	    class_list_count += 1;
	    class_list = static_cast<class_type **>
	                 (realloc(class_list,
	                  class_list_count*sizeof(class_type **)));
	    class_list[class_list_count-1] = citer->second;
      }
}

void root_table_delete(void)
{
      for (unsigned idx = 0; idx < vpip_root_table.size(); idx += 1) {
	    __vpiScope *scope = static_cast<__vpiScope *>
	          (vpip_root_table[idx]);
	    vthreads_delete(scope);
	    delete_sub_scopes(scope);
	    delete scope;
      }
      vpip_root_table.clear();

	/* Clean up all the class definitions. */
      for (unsigned idx = 0; idx < class_list_count; idx += 1) {
            class_def_delete(class_list[idx]);
      }
      free(class_list);
      class_list = 0;
      class_list_count = 0;
}
#endif

static void construct_scope_fullname(__vpiScope*ref, char*buf)
{
      if (ref->scope) {
	    construct_scope_fullname(ref->scope, buf);
	      // Add a "." separator, unless this is for a package
	    if (ref->scope->get_type_code() != vpiPackage) {
		  strcat(buf, ".");
	    }
      }

      strcat(buf, ref->scope_name());
	// For a package, add a "::" to the end
      if (ref->get_type_code() == vpiPackage) strcat(buf, "::");
}

static const char* scope_get_type(int code)
{
      switch (code) {
          case vpiModule:
            return "vpiModule";
          case vpiGenScope:
            return "vpiGenScope";
          case vpiFunction:
            return "vpiFunction";
          case vpiTask:
            return "vpiTask";
          case vpiNamedBegin:
            return "vpiNamedBegin";
          case vpiFor:
            return "vpiFor";
          case vpiForeachStmt:
            return "vpiForeachStmt";
          case vpiNamedFork:
            return "vpiNamedFork";
          default:
            fprintf(stderr, "VPI error: invalid scope type code %d.\n", code);
            return NULL;
      }
}

static char* scope_get_str(int code, vpiHandle obj)
{
      __vpiScope*ref = dynamic_cast<__vpiScope*>(obj);
      assert(ref);

      char buf[4096];  // XXX is a fixed buffer size really reliable?
      const char *p=0;
      switch (code) {
	  case vpiDefFile:
	    p = file_names[ref->def_file_idx];
	    break;

	  case vpiFile:
	    p = file_names[ref->file_idx];
	    break;

	  case vpiFullName:
	    buf[0] = 0;
	    construct_scope_fullname(ref, buf);
	    p = buf;
	    break;

	  case vpiName:
	    p = ref->scope_name();
	    break;

	  case vpiDefName:
	    p = ref->scope_def_name();
	    break;

	  case vpiDPICIdentifier:
	    p = ref->dpi_c_identifier;
	    if (!p) return NULL;
	    break;

	  case vpiType:
	    p = scope_get_type(code);
	    break;

	  default:
	    fprintf(stderr, "VPI error: invalid scope string code %d.\n", code);
	    return NULL;
      }
      return simple_set_rbuf_str(p);
}

static vpiHandle scope_get_handle(int code, vpiHandle obj)
{
      __vpiScope*rfp = dynamic_cast<__vpiScope*>(obj);
      assert(rfp);

      switch (code) {
	  case vpiStmt:
	    if (rfp->get_type_code() == vpiTask
		|| rfp->get_type_code() == vpiFunction)
		  return rfp->statement_root;
	    return 0;
	  case vpiIndex:
	    if (rfp->get_type_code() == vpiModule &&
	        rfp->has_module_array_index_)
		  return &rfp->module_array_index_;
	    return 0;

	  case vpiScope:
	    return rfp->scope;

	  case vpiModule:
	    return rfp->scope;

	  case vpiInstance:
	    return rfp->scope;
      }

      return 0;
}

class __vpiPrimitive;

class __vpiPrimitiveTerm : public __vpiHandle {
    public:
      __vpiPrimitiveTerm(__vpiPrimitive *primitive, int direction,
			 unsigned index, vpiHandle expression)
	      : primitive_(primitive), direction_(direction), index_(index),
		expression_(expression) { }
      int get_type_code(void) const override { return vpiPrimTerm; }
      int vpi_get(int code) override
      {
	    switch (code) {
		case vpiDirection: return direction_;
		case vpiTermIndex: return static_cast<int>(index_);
		case vpiSize:
		    return expression_ ? ::vpi_get(vpiSize, expression_) : 0;
		default: return __vpiHandle::vpi_get(code);
	    }
      }
      void vpi_get_value(p_vpi_value value) override
      {
	    if (expression_) expression_->vpi_get_value(value);
      }
      vpiHandle vpi_handle(int code) override;
      __vpiPrimitive *primitive() const { return primitive_; }
      vpiHandle expression() const { return expression_; }
    private:
      __vpiPrimitive *primitive_;
      int direction_;
      unsigned index_;
      vpiHandle expression_;
};

class __vpiPrimitive : public __vpiHandle {
    public:
      __vpiPrimitive(__vpiScope *scope, const char *name, int prim_type,
		     unsigned input_count, int strength0, int strength1,
		     vpiHandle udp_definition)
	      : scope_(scope), name_(vpip_name_string(name)),
		prim_type_(prim_type), input_count_(input_count),
		strength0_(strength0), strength1_(strength1),
		udp_definition_(udp_definition) { }
      ~__vpiPrimitive() override
      {
	    for (std::vector<vpiHandle>::iterator cur = terms_.begin();
		 cur != terms_.end(); ++cur)
		  delete *cur;
      }
      int get_type_code(void) const override { return vpiPrimitive; }
      int vpi_get(int code) override
      {
	    switch (code) {
		case vpiSize: return static_cast<int>(input_count_);
		case vpiPrimType: return prim_type_;
		case vpiStrength0:
		    return strength0_ ? strength0_ : vpiUndefined;
		case vpiStrength1:
		    return strength1_ ? strength1_ : vpiUndefined;
		default: return __vpiHandle::vpi_get(code);
	    }
      }
      char *vpi_get_str(int code) override
      {
	    if (code == vpiName || code == vpiFullName)
		  return generic_get_str(code, scope_, name_, NULL);
	    return __vpiHandle::vpi_get_str(code);
      }
      void vpi_get_value(p_vpi_value value) override
      {
	    if (!terms_.empty()) terms_[0]->vpi_get_value(value);
      }
      vpiHandle vpi_handle(int code) override
      {
	    switch (code) {
		case vpiScope:
		case vpiParent: return scope_;
		case vpiUdpDefn: return udp_definition_;
		default: return __vpiHandle::vpi_handle(code);
	    }
      }
      vpiHandle vpi_iterate(int code) override
      {
	    if (code != vpiPrimTerm || terms_.empty()) return 0;
	    vpiHandle *args = static_cast<vpiHandle*>(
		  calloc(terms_.size(), sizeof(vpiHandle)));
	    for (size_t idx = 0; idx < terms_.size(); idx += 1)
		  args[idx] = terms_[idx];
	    return vpip_make_iterator(terms_.size(), args, true);
      }
      bool add_term(int direction, unsigned index, vpiHandle expression)
      {
	    if (index > 1024U*1024U) return false;
	    if (terms_.size() <= index)
		  terms_.resize(index + 1, 0);
	    if (terms_[index]) return false;
	    terms_[index] = new __vpiPrimitiveTerm(this, direction, index,
						  expression);
	    return true;
      }
      __vpiScope *scope() const { return scope_; }
    private:
      __vpiScope *scope_;
      const char *name_;
      int prim_type_;
      unsigned input_count_;
      int strength0_;
      int strength1_;
      vpiHandle udp_definition_;
      std::vector<vpiHandle> terms_;
};

class __vpiPrimitiveTermResolve : public resolv_list_s {
    public:
	  __vpiPrimitiveTermResolve(char *label, __vpiPrimitive *primitive,
				    int direction, unsigned index, unsigned width)
		  : resolv_list_s(label), primitive_(primitive), direction_(direction),
		    index_(index), width_(width) { }
	  bool resolve(bool mes) override
	  {
		vpiHandle expression = 0;
		if (*label()) {
		      vvp_net_t *node = vvp_net_lookup(label());
		      if (!node) node = create_constant_node(label());
		      if (!node) {
			    if (!mes) return false;
			    yyerror(".vpi_primterm references an unknown expression");
			    compile_errors += 1;
			    return true;
		      }
		      if (width_ == 0) {
			    if (!mes) return false;
			    yyerror(".vpi_primterm has zero width");
			    compile_errors += 1;
			    return true;
		      }
		      char term_name[80];
		      snprintf(term_name, sizeof term_name, "$ivl_primterm_%p_%u",
			       static_cast<void*>(primitive_), index_);
		      expression = vpip_make_net4(primitive_->scope(), term_name,
					   static_cast<int>(width_-1), 0, false,
					   node);
		}
		if (!primitive_->add_term(direction_, index_, expression)) {
		      if (!mes) return false;
		      yyerror("duplicate .vpi_primterm index");
		      compile_errors += 1;
		}
		return true;
	  }
    private:
	  __vpiPrimitive *primitive_;
	  int direction_;
	  unsigned index_;
	  unsigned width_;
};

vpiHandle __vpiPrimitiveTerm::vpi_handle(int code)
{
      switch (code) {
	  case vpiExpr: return expression_;
	  case vpiParent:
	  case vpiPrimitive: return primitive_;
	  case vpiScope: return primitive_->scope();
	  default: return __vpiHandle::vpi_handle(code);
      }
}

void compile_vpi_primitive(char *label, char *name, long prim_type,
			   long input_count, long strength0, long strength1,
			   char *udp_name)
{
      vpiHandle udp_definition = 0;
      if (!label || !name || !udp_name || prim_type < 1 || prim_type > 28
	  || input_count < 0 || input_count > 1024L*1024L) {
	    yyerror("invalid .vpi_primitive metadata");
	    compile_errors += 1;
	    free(label);
	    delete[] name;
	    delete[] udp_name;
	    return;
      }
      if (*udp_name) {
	    vvp_udp_s *definition = udp_find_name(udp_name);
	    if (!definition) {
		  yyerror(".vpi_primitive references an unknown UDP definition");
		  compile_errors += 1;
	    } else {
		  udp_definition = vpip_get_udp_handle(definition);
	    }
      }
      __vpiPrimitive *primitive = new __vpiPrimitive(
	    vpip_peek_current_scope(), name, static_cast<int>(prim_type),
	    static_cast<unsigned>(input_count), static_cast<int>(strength0),
	    static_cast<int>(strength1), udp_definition);
      compile_vpi_symbol(label, primitive);
      vpip_attach_to_current_scope(primitive);
      free(label);
      delete[] name;
      delete[] udp_name;
}

void compile_vpi_primitive_term(char *primitive_label, long direction,
				long term_index, long width,
				char *expression_label)
{
      __vpiPrimitive *primitive = primitive_label
	    ? dynamic_cast<__vpiPrimitive*>(vvp_lookup_handle(primitive_label))
	    : 0;
      bool valid = primitive && expression_label
	    && primitive->scope() == vpip_peek_current_scope()
	    && (direction == vpiInput || direction == vpiOutput
		|| direction == vpiInout)
	    && term_index >= 0 && term_index <= 1024L*1024L
	    && width >= 0 && width <= 1024L*1024L;
	  if (!valid) {
	    yyerror("invalid .vpi_primterm metadata");
	    compile_errors += 1;
	  } else {
	    char *resolve_label = strdup(expression_label);
	    resolv_submit(new __vpiPrimitiveTermResolve(resolve_label, primitive,
						       static_cast<int>(direction),
						       static_cast<unsigned>(term_index),
						       static_cast<unsigned>(width)));
      }
      free(primitive_label);
      delete[] expression_label;
}

__vpiStmtNode::__vpiStmtNode(int type, const char*name, __vpiScope*scope, int blocking)
: scope_(scope), type_(type), blocking_(blocking), name_(vpip_name_string(name)), parent_(0)
{ }

int __vpiStmtNode::get_type_code(void) const
{ return type_; }

int __vpiStmtNode::vpi_get(int code)
{
      if (code == vpiBlocking && type_ == vpiEventStmt && blocking_ >= 0)
            return blocking_;
      return __vpiHandle::vpi_get(code);
}

char* __vpiStmtNode::vpi_get_str(int code)
{
      if (code == vpiName && name_ && *name_)
	    return const_cast<char*>(name_);
      return __vpiHandle::vpi_get_str(code);
}

vpiHandle __vpiStmtNode::vpi_handle(int code)
{
      if (code == vpiParent) return parent_;
      if (code == vpiScope) return scope_;
      return __vpiHandle::vpi_handle(code);
}

vpiHandle __vpiStmtNode::vpi_iterate(int code)
{
      if (code != vpiStmt || children_.empty()) return 0;
      vpiHandle*args = static_cast<vpiHandle*>(
	    calloc(children_.size(), sizeof(vpiHandle)));
      for (size_t idx = 0; idx < children_.size(); idx += 1)
	    args[idx] = children_[idx];
      return vpip_make_iterator(children_.size(), args, true);
}

void __vpiStmtNode::add_child(__vpiStmtNode*child)
{ children_.push_back(child); child->parent_ = this; }

/* compares vpiType's considering object classes */
static int compare_types(int code, int type, bool is_typedef = false)
{
	/* NOTE: The Verilog VPI does not for any object support
	   vpiScope as an iterator parameter, so it is used here as a
	   means to scan everything in the *current* scope. */
      if (code == vpiScope)
	    return 1;

      if (code == vpiTypedef)
	    return is_typedef;

      if ((code == VPI_IODECL_TYPE || code == vpiIODecl)
	  && (type == VPI_IODECL_TYPE || type == vpiIODecl))
	    return 1;

      if (code == type)
	    return 1;

      // SystemVerilog variable arrays use vpiRegArray for iteration,
      // while the current array handle implementation reports vpiMemory.
      if (code == vpiRegArray && type == vpiMemory)
	    return 1;

      if ( code == vpiInternalScope &&
	     (type == vpiModule ||
	     type == vpiGenScope ||
	     type == vpiFunction ||
	     type == vpiTask ||
	     type == vpiNamedBegin ||
	     type == vpiFor ||
	     type == vpiForeachStmt ||
	     type == vpiNamedFork ||
	     type == vpiClassTypespec ||
	     // M12: interface instances are traversable scopes.
	     type == vpiInterface) )
	    return 1;

      if ( code == vpiInstance &&
	    (type == vpiModule ||
	     type == vpiProgram ||
	     type == vpiInterface ||
	     type == vpiPackage) )
	    return 1;

      if ( code == vpiVariables &&
	     (type == vpiLogicVar    ||
	      type == vpiMemory      ||
	      type == vpiIntegerVar  ||
	      type == vpiBitVar      ||
	      type == vpiByteVar     ||
	      type == vpiShortIntVar ||
	      type == vpiIntVar      ||
	      type == vpiLongIntVar  ||
	      type == vpiTimeVar     ||
	      type == vpiRealVar     ||
	      // M12: SystemVerilog variable objects are variables too.
	      type == vpiStringVar   ||
	      type == vpiClassVar    ||
	      type == vpiVirtualInterfaceVar ||
	      type == vpiEnumVar     ||
	      type == vpiStructVar   ||
	      type == vpiUnionVar    ||
	      type == vpiPackedArrayVar ||
	      type == vpiArrayVar))
	    return 1;

      return 0;
}

static vpiHandle make_subset_iterator_(int type_code, const vector<vpiHandle>&table)
{
      unsigned mcnt = 0, ncnt = 0;
      vpiHandle*args;

	// A net array also reports vpiMemory; it is not a variable.
      const auto is_net_memory = [](vpiHandle item) {
	    return item->get_vpi_type_code() == vpiMemory && is_net_array(item);
      };
      const auto is_vif_array_word = [](vpiHandle item) {
	    struct __vpiArrayWord*word = array_var_word_from_handle(item);
	    if (!word) return false;
	    __vpiArray*array = dynamic_cast<__vpiArray*>(word->get_parent());
	    return array && array->is_virtual_interface_array();
      };

      for (unsigned idx = 0; idx < table.size(); idx += 1)
	    if (compare_types(type_code, table[idx]->get_vpi_type_code(),
			      table[idx]->is_typedef_typespec())
		&& !(type_code == vpiVariables
		     && (is_vif_array_word(table[idx])
			 || is_net_memory(table[idx]))))
		  mcnt += 1;

      if (mcnt == 0)
	    return 0;

      args = static_cast<vpiHandle*>(calloc(mcnt, sizeof(vpiHandle)));
      for (unsigned idx = 0; idx < table.size(); idx += 1)
	    if (compare_types(type_code, table[idx]->get_vpi_type_code(),
			      table[idx]->is_typedef_typespec())
		&& !(type_code == vpiVariables
		     && (is_vif_array_word(table[idx])
			 || is_net_memory(table[idx]))))
		  args[ncnt++] = table[idx];

      assert(ncnt == mcnt);

      return vpip_make_iterator(mcnt, args, true);
}

class __vpiProcess : public __vpiHandle {
    public:
      explicit __vpiProcess(__vpiScope*scope) : scope_(scope) { }
      explicit __vpiProcess(vthread_t thread)
      : scope_(vthread_scope(thread)) { }
      int get_type_code(void) const override { return vpiProcess; }

      char* vpi_get_str(int code) override
      {
            if (code == vpiFullName)
                  return scope_->vpi_get_str(vpiFullName);
            return __vpiHandle::vpi_get_str(code);
      }

    private:
      __vpiScope*scope_;
};

vpiHandle vpip_make_process_handle(vthread_t thread)
{
      return new __vpiProcess(thread);
}

/*
 * This function implements the vpi_iterate method for vpiModule and
 * similar objects. The vpi_iterate allows the user to iterate over
 * things that are contained in the scope object, by generating an
 * iterator for the requested set of items.
 */
static vpiHandle module_iter(int code, vpiHandle obj)
{
      __vpiScope*ref = dynamic_cast<__vpiScope*>(obj);
      assert(ref);

      if (code == vpiImport) {
            vector<vpiHandle> items;
            for (const auto&import : ref->imports) {
                  vpiHandle imported = 0;
                  for (vpiHandle root : vpip_root_table) {
                        __vpiScope*package = dynamic_cast<__vpiScope*>(root);
                        if (!package || package->get_type_code() != vpiPackage)
                              continue;
                        const char*package_name = package->vpi_get_str(vpiName);
                        if (!package_name || strcmp(package_name, import.first) != 0)
                              continue;
                        for (vpiHandle item : package->intern) {
                              const char*item_name = item->vpi_get_str(vpiName);
                              if (item_name && strcmp(item_name, import.second) == 0) {
                                    imported = item;
                                    break;
                              }
                        }
                        break;
                  }
                  if (imported) items.push_back(imported);
            }
            if (items.empty()) return 0;
            vpiHandle*args = static_cast<vpiHandle*>(
                  calloc(items.size(), sizeof(vpiHandle)));
            for (unsigned idx = 0; idx < items.size(); idx += 1)
                  args[idx] = items[idx];
            return vpip_make_iterator(items.size(), args, true);
      }

      if (code == vpiVirtualInterfaceVar) {
	    vector<vpiHandle> items;
	    set<vpiHandle> seen;
	    for (unsigned idx = 0; idx < ref->intern.size(); idx += 1) {
		  vpiHandle item = ref->intern[idx];
		  if (item->get_type_code() == vpiVirtualInterfaceVar) {
			if (seen.insert(item).second) items.push_back(item);
			continue;
		  }
		  __vpiArray*array = dynamic_cast<__vpiArray*>(item);
		  if (!array || !array->is_virtual_interface_array()) continue;
		  vpiHandle iter = vpi_iterate(vpiMemoryWord, array);
		  vpiHandle word;
		  while (iter && (word = vpi_scan(iter)))
			if (seen.insert(word).second) items.push_back(word);
	    }
	    if (items.empty()) return 0;
	    vpiHandle*args = static_cast<vpiHandle*>(
		  calloc(items.size(), sizeof(vpiHandle)));
	    for (unsigned idx = 0; idx < items.size(); idx += 1)
		  args[idx] = items[idx];
	    return vpip_make_iterator(items.size(), args, true);
      }

      if (code == vpiProcess) {
            if (ref->threads.empty()) return 0;

            vpiHandle*args = static_cast<vpiHandle*>(
                  calloc(ref->threads.size(), sizeof(vpiHandle)));
            unsigned idx = 0;
            for (set<vthread_t>::const_iterator cur = ref->threads.begin();
                 cur != ref->threads.end(); ++cur)
                  args[idx++] = new __vpiProcess(ref);

            return vpip_make_iterator(idx, args, true);
      }

      return make_subset_iterator_(code, ref->intern);
}

class __vpiParamAssign : public __vpiHandle {
    public:
      __vpiParamAssign(__vpiScope*scope, vpiHandle lhs, vpiHandle rhs)
      : scope_(scope), lhs_(lhs), rhs_(rhs) { }
      ~__vpiParamAssign() override { delete rhs_; }
      int get_type_code(void) const override { return vpiParamAssign; }
      vpiHandle vpi_handle(int code) override
      {
	    switch (code) {
		case vpiLhs: return lhs_;
		case vpiRhs: return rhs_;
		case vpiParent:
		case vpiScope: return scope_;
		default: return __vpiHandle::vpi_handle(code);
	    }
      }
    private:
      __vpiScope*scope_;
      vpiHandle lhs_;
      vpiHandle rhs_;
};

/* A def param object (IEEE 1800-2023 37.28): the defparam statement of
   this scope, with the parameter it assigns and its r-value. */
class __vpiDefParam : public __vpiHandle {
    public:
      __vpiDefParam(__vpiScope*scope, unsigned file_idx, unsigned lineno,
		    unsigned argc, vpiHandle*argv)
      : scope_(scope), param_(0), file_idx_(file_idx), lineno_(lineno),
	argc_(argc), argv_(argv) { }
      int get_type_code(void) const override { return vpiDefParam; }
      int vpi_get(int code) override
      {
	    return code == vpiLineNo ? (int)lineno_ : vpiUndefined;
      }
      char*vpi_get_str(int code) override
      {
	    if (code == vpiFile && file_idx_ < file_names.size())
		  return simple_set_rbuf_str(file_names[file_idx_]);
	    return 0;
      }
      vpiHandle vpi_handle(int code) override
      {
	    switch (code) {
		case vpiLhs: return param_;
		case vpiRhs: return argc_ ? argv_[argc_-1] : 0;
		case vpiParent:
		case vpiScope:
		case vpiModule: return scope_;
		default: return 0;
	    }
      }

      __vpiScope*scope_;
	/* Resolved after construction, in place. */
      vpiHandle param_;
    private:
      unsigned file_idx_, lineno_;
      unsigned argc_;
      vpiHandle*argv_;
};

void compile_vpi_defparam(char*param, long file_idx, long lineno,
			  unsigned argc, vpiHandle*argv)
{
      __vpiDefParam*obj = new __vpiDefParam(vpip_peek_current_scope(),
					    (unsigned)file_idx,
					    (unsigned)lineno, argc, argv);
      compile_vpi_lookup(&obj->param_, param);
      vpip_attach_to_current_scope(obj);
}

vpiHandle vpip_make_param_assign(__vpiScope*scope, vpiHandle lhs,
				 vpiHandle rhs)
{
      if (!scope || !lhs || !rhs)
	    return 0;
      return new __vpiParamAssign(scope, lhs, rhs);
}

static vpiHandle find_signal_by_net_(__vpiScope*scope, vvp_net_t*net)
{
      for (size_t idx = 0; idx < scope->intern.size(); idx += 1) {
	    vpiHandle item = scope->intern[idx];
	    __vpiSignal*signal = dynamic_cast<__vpiSignal*>(item);
	    if (signal && signal->node == net) return signal;
	    __vpiScope*child = dynamic_cast<__vpiScope*>(item);
	    if (child) {
		  vpiHandle found = find_signal_by_net_(child, net);
		  if (found) return found;
	    }
      }
      return 0;
}

vpiHandle vpip_find_signal_by_net(vvp_net_t*net)
{
      if (!net) return 0;
      for (size_t idx = 0; idx < vpip_root_table.size(); idx += 1) {
	    __vpiScope*root = dynamic_cast<__vpiScope*>(vpip_root_table[idx]);
	    if (root) {
		  vpiHandle found = find_signal_by_net_(root, net);
		  if (found) return found;
	    }
      }
      return 0;
}

class __vpiTypedefTypespec : public __vpiHandle {
    public:
      __vpiTypedefTypespec(int type, const char*name, const char*defname,
			   const char*modport, bool parent = false)
	      : type_(type), name_(name ? vpip_name_string(name) : 0),
		defname_(defname ? vpip_name_string(defname) : 0),
		modport_(modport ? vpip_name_string(modport) : 0),
		parent_(parent) { }
      int get_type_code(void) const override { return type_; }
      bool is_typedef_typespec(void) const override { return true; }
      int vpi_get(int code) override
      {
	    if (type_ == vpiInterfaceTypespec && code == vpiIsModPort)
		  return modport_ && *modport_;
	    return __vpiHandle::vpi_get(code);
      }
      char* vpi_get_str(int code) override
      {
	    if (code == vpiName) return parent_ ? 0 : const_cast<char*>(name_);
	    if (code == vpiDefName && type_ == vpiInterfaceTypespec)
		  return const_cast<char*>(modport_ && *modport_
			  ? modport_ : defname_);
	    return __vpiHandle::vpi_get_str(code);
      }
      vpiHandle vpi_handle(int code) override
      {
	    if (type_ == vpiInterfaceTypespec && code == vpiParent && modport_
		&& *modport_ && !parent_)
		  return new __vpiTypedefTypespec(type_, 0, defname_, 0, true);
	    return __vpiHandle::vpi_handle(code);
      }
    private:
      int type_;
      const char*name_;
      const char*defname_;
      const char*modport_;
      bool parent_;
};

void compile_typedef(char*name, long type, char*defname, char*modport)
{
      __vpiScope*scope = vpip_peek_current_scope();
      assert(scope);
      __vpiTypedefTypespec*obj = new __vpiTypedefTypespec(
	    static_cast<int>(type), name, defname, modport);
      vpip_attach_to_current_scope(obj);
      delete[] name;
      delete[] defname;
      delete[] modport;
}

class __vpiNettypeDecl : public __vpiHandle {
    public:
      __vpiNettypeDecl(__vpiScope*scope, const char*name,
                       const char*alias, const char*with)
      : scope_(scope), name_(vpip_name_string(name)),
        alias_(vpip_name_string(alias)), with_(vpip_name_string(with)) { }
      int get_type_code(void) const override { return vpiNettypeDecl; }
      char* vpi_get_str(int code) override
      {
            if (code == vpiName) return const_cast<char*>(name_);
            return __vpiHandle::vpi_get_str(code);
      }
      vpiHandle vpi_handle(int code) override
      {
            if (code == vpiNetTypedefAlias && alias_ && *alias_) {
                  for (size_t idx = 0; idx < scope_->intern.size(); ++idx) {
                        vpiHandle item = scope_->intern[idx];
                        if (item->get_type_code() == vpiNettypeDecl
                            && strcmp(item->vpi_get_str(vpiName), alias_) == 0)
                              return item;
                  }
            }
            if (code == vpiWith && with_ && *with_) {
                  std::string path = scope_->vpi_get_str(vpiFullName);
                  if (!path.empty()) path += ".";
                  path += with_;
                  return vpi_handle_by_name(
                        reinterpret_cast<PLI_BYTE8*>(const_cast<char*>(path.c_str())),
                        0);
            }
            return __vpiHandle::vpi_handle(code);
      }
    private:
      __vpiScope*scope_;
      const char*name_;
      const char*alias_;
      const char*with_;
};

void compile_nettype_decl(char*name, char*alias, char*with)
{
      __vpiScope*scope = vpip_peek_current_scope();
      assert(scope);
      __vpiNettypeDecl*obj = new __vpiNettypeDecl(scope, name, alias, with);
      vpip_attach_to_current_scope(obj);
      delete[] name;
      delete[] alias;
      delete[] with;
}

void compile_vpi_import(char*package, char*name)
{
      __vpiScope*scope = vpip_peek_current_scope();
      assert(scope);
      scope->imports.push_back(std::make_pair(vpip_name_string(package),
                                              vpip_name_string(name)));
      delete[] package;
      delete[] name;
}

/* Task/function formal declarations are distinct VPI objects from their
   storage signals. Their expression is resolved from the signal label after
   VVP linking, which also lets a ref formal expose its activation's binding. */
class __vpiIODecl : public __vpiHandle {
    public:
      __vpiIODecl(__vpiScope*parent, int direction, const char*name)
      : parent_(parent), direction_(direction), name_(vpip_name_string(name)),
        expr_(0) { }

      int get_type_code(void) const override { return VPI_IODECL_TYPE; }
      int vpi_get(int code) override
      {
            if (code == vpiDirection) {
                  if (direction_ == VPI_REF_DIRECTION) return direction_;
                  if (expr_ && expr_->get_type_code() == vpiVirtualInterfaceVar)
                        return vpiUndefined;
                  return direction_;
            }
            if (expr_ && (code == vpiSize || code == vpiSigned
                          || code == vpiScalar || code == vpiVector))
                  return expr_->vpi_get(code);
            return vpiUndefined;
      }

      char* vpi_get_str(int code) override
      {
            if (code == vpiName || code == vpiFullName)
                  return generic_get_str(code, parent_, name_, 0);
            if (expr_ && code == vpiFile)
                  return expr_->vpi_get_str(code);
            return 0;
      }

      vpiHandle vpi_handle(int code) override
      {
            if (code == vpiParent || code == vpiScope) return parent_;
            if (code == vpiExpr && expr_)
                  return direction_ == VPI_REF_DIRECTION
                        ? vpip_wrap_refobj(expr_) : expr_;
            if (expr_ && (code == vpiTypespec || code == vpiLeftRange
                          || code == vpiRightRange))
                  return expr_->vpi_handle(code);
            return 0;
      }

      vpiHandle vpi_iterate(int code) override
      {
            return expr_ && code == vpiRange ? expr_->vpi_iterate(code) : 0;
      }

      vpiHandle& expression_slot() { return expr_; }

    private:
      __vpiScope*parent_;
      int direction_;
      const char*name_;
      vpiHandle expr_;
};

void compile_io_decl(long direction, char*name, char*formal)
{
      __vpiScope*scope = vpip_peek_current_scope();
      if (!scope || (direction != vpiInput && direction != vpiOutput
                     && direction != vpiInout
                     && direction != VPI_REF_DIRECTION)) {
            yyerror("invalid .iodecl direction");
            compile_errors += 1;
            delete[] name;
            free(formal);
            return;
      }

      __vpiIODecl*decl = new __vpiIODecl(scope, (int)direction, name);
      compile_vpi_lookup(&decl->expression_slot(), formal);
      vpip_attach_to_current_scope(decl);
      delete[] name;
}


__vpiScope::__vpiScope(const char*nam, const char*tnam, bool auto_flag)
: is_automatic_(auto_flag)
{
      statement_root = 0;
      name_ = vpip_name_string(nam);
      tname_ = vpip_name_string(tnam? tnam : "");
      has_module_array_index_ = false;
      const char *open = strrchr(name_, '[');
      if (open && open[1] != 0) {
	    char *end;
	    long index = strtol(open + 1, &end, 10);
	    if (end != open + 1 && end[0] == ']' && end[1] == 0 &&
	        index >= INT_MIN && index <= INT_MAX) {
		  module_array_index_.set_value(index);
		  has_module_array_index_ = true;
	    }
      }
}

int __vpiScope::vpi_get(int code)
{
      switch (code) {
	  case vpiVisibility:
	    if ((get_type_code() == vpiFunction || get_type_code() == vpiTask)
		&& (!scope || scope->get_type_code() != vpiClassTypespec))
		  return vpiPublicVis;
	    return vpiUndefined;

	  case vpiIndex:
	    if (get_type_code() == vpiModule && has_module_array_index_)
		  return module_array_index_.get_value();
	    return vpiUndefined;

	  case vpiCellInstance:
	    return is_cell? 1 : 0;

	  case vpiDefLineNo:
	    return def_lineno;

	  case vpiLineNo:
	    return lineno;

	  case vpiTimeUnit:
	    return time_units;

	  case vpiTimePrecision:
	    return time_precision;

	  case vpiTopModule:
	    return 0x0 == scope;

          case vpiAutomatic:
	    return is_automatic_? 1 : 0;

	  case vpiJoinType:
	    return join_type;

	  case vpiAccessType:
	    return access_type;

	  case vpiDPIPure:
	    return dpi_cstr == vpiUndefined ? vpiUndefined : dpi_pure;

	  case vpiDPIContext:
	    return dpi_cstr == vpiUndefined ? vpiUndefined : dpi_context;

	  case vpiDPICStr:
	    return dpi_cstr;
      }

      return vpiUndefined;
}


char*__vpiScope::vpi_get_str(int code)
{ return scope_get_str(code, this); }

vpiHandle __vpiScope::vpi_handle(int code)
{ return scope_get_handle(code, this); }

vpiHandle __vpiScope::vpi_iterate(int code)
{ return module_iter(code, this); }

__vpiFunctionReturn::__vpiFunctionReturn(__vpiScope*scope, int func_type,
                                         unsigned width, bool is_2state)
: scope_(scope), type_code_(vpiReg), width_(width), signed_(false)
{
      switch (func_type) {
          case vpiIntFunc:
            type_code_ = vpiIntVar;
            width_ = 32;
            signed_ = true;
            break;
          case vpiRealFunc:
            type_code_ = vpiRealVar;
            width_ = 0;
            break;
          case vpiTimeFunc:
            type_code_ = vpiTimeVar;
            width_ = 64;
            break;
          case vpiSizedSignedFunc:
            signed_ = true;
            type_code_ = is_2state ? vpiBitVar : vpiReg;
            break;
          case vpiSizedFunc:
            type_code_ = is_2state ? vpiBitVar : vpiReg;
            break;
          default:
            /* String and user-defined returns use vpiOtherFunc in the
               runtime scope descriptor. Their dedicated type metadata is
               not currently emitted by the compiler. */
            type_code_ = vpiStringVar;
            width_ = 0;
            break;
      }
}

int __vpiFunctionReturn::vpi_get(int code)
{
      switch (code) {
          case vpiSigned: return signed_;
          case vpiSize: return static_cast<int>(width_);
          case vpiAutomatic: return scope_->vpi_get(vpiAutomatic);
          default: return vpiUndefined;
      }
}

char* __vpiFunctionReturn::vpi_get_str(int code)
{
      return generic_get_str(code, scope_, scope_->scope_name(), NULL);
}

vpiHandle __vpiFunctionReturn::vpi_handle(int code)
{
      if (code == vpiScope || code == vpiParent) return scope_;
      return __vpiHandle::vpi_handle(code);
}


class vpiScopeModule  : public __vpiScope {
    public:
      inline vpiScopeModule(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam,false) { }
      int get_type_code(void) const override { return vpiModule; }
};

/* Program-block instance scope (IEEE 1800-2017 clause 24): threads
   whose scope chain includes one of these schedule in the Reactive
   region set. */
class vpiScopeProgram  : public __vpiScope {
    public:
      inline vpiScopeProgram(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam,false), index_(vpiUndefined), index_handle_(0)
      {
            const char* open = strrchr(nam, '[');
            if (open && nam[strlen(nam) - 1] == ']') {
                  char* end;
                  errno = 0;
                  long value = strtol(open + 1, &end, 10);
                  if (errno == 0 && end == nam + strlen(nam) - 1 &&
                      value >= INT_MIN && value <= INT_MAX) {
                        index_ = value;
                        index_handle_ = new __vpiDecConst(index_);
                  }
            }
      }
      int get_type_code(void) const override { return vpiProgram; }
      int vpi_get(int code) override
      {
            if (code == vpiIndex) return index_;
            return __vpiScope::vpi_get(code);
      }
      vpiHandle vpi_handle(int code) override
      {
            if (code == vpiIndex) return index_handle_;
            return __vpiScope::vpi_handle(code);
      }
    private:
      int index_;
      vpiHandle index_handle_;
};

struct vpiScopePackage  : public __vpiScope {
      inline vpiScopePackage(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam) { }
      int get_type_code(void) const override { return vpiPackage; }
};

struct vpiScopeTask  : public __vpiScope {
      inline vpiScopeTask(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam) { }
      int get_type_code(void) const override { return vpiTask; }
};

struct vpiScopeTaskAuto  : public __vpiScope {
      inline vpiScopeTaskAuto(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam,true) {  }
      int get_type_code(void) const override { return vpiTask; }
};

struct vpiScopeBegin  : public __vpiScope {
      inline vpiScopeBegin(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam,false) { }
      int get_type_code(void) const override { return vpiNamedBegin; }
};

class vpiScopeBeginAuto  : public __vpiScope {
    public:
      inline vpiScopeBeginAuto(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam,true) {  }
      int get_type_code(void) const override { return vpiNamedBegin; }
};

class vpiScopeLoop : public __vpiScope {
    public:
      vpiScopeLoop(const char*nam, const char*tnam, bool auto_flag,
                   bool shares_parent, int type_code)
      : __vpiScope(nam, tnam, auto_flag), type_code_(type_code)
      { if (shares_parent) set_shares_parent_frame(); }

      int get_type_code(void) const override { return type_code_; }
      int vpi_get(int code) override
      {
            if (code == vpiLocalVarDecls)
                  return type_code_ == vpiFor ? 1 : 0;
            return __vpiScope::vpi_get(code);
      }

    private:
      int type_code_;
};

struct vpiScopeGenerate  : public __vpiScope {
      inline vpiScopeGenerate(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam) { }
      int get_type_code(void) const override { return vpiGenScope; }
};

struct vpiScopeFork  : public __vpiScope {
      inline vpiScopeFork(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam,false) { }
      int get_type_code(void) const override { return vpiNamedFork; }
};

class vpiScopeForkAuto  : public __vpiScope {
    public:
      inline vpiScopeForkAuto(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam,true) {  }
      int get_type_code(void) const override { return vpiNamedFork; }
};

struct vpiScopeClass  : public __vpiScope {
      inline vpiScopeClass(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam) { }
      int get_type_code(void) const override { return vpiClassTypespec; }
      vpiHandle vpi_handle(int code) override
      {
	    if (code == vpiClassDefn && scope) {
		  std::map<std::string,class_type*>::const_iterator defn =
			scope->classes.find(scope_name());
		  if (defn != scope->classes.end())
			return defn->second;
	    }
	    return __vpiScope::vpi_handle(code);
      }
};

/* M12: interface instance scope (IEEE 1800-2017 clause 25). */
struct vpiScopeInterface  : public __vpiScope {
      inline vpiScopeInterface(const char*nam, const char*tnam)
      : __vpiScope(nam,tnam,false), index_(0), has_index_(false)
      {
	    /* Interface array elements are emitted with their elaborated index
	       appended to the scope name (for example, "bus[3]"). */
	    const char*open = strrchr(nam, '[');
	    if (open && nam[strlen(nam)-1] == ']') {
		  char*end;
		  errno = 0;
		  long value = strtol(open + 1, &end, 10);
		  if (!errno && end == nam + strlen(nam) - 1 &&
		      value >= INT_MIN && value <= INT_MAX) {
			index_.set_value((int)value);
			has_index_ = true;
		  }
	    }
      }
      int get_type_code(void) const override { return vpiInterface; }
      int vpi_get(int code) override
      {
	    if (code == vpiIndex && has_index_)
		  return index_.get_value();
	    return __vpiScope::vpi_get(code);
      }
      vpiHandle vpi_handle(int code) override
      {
	    if (code == vpiIndex && has_index_)
		  return &index_;
	    return __vpiScope::vpi_handle(code);
      }

    private:
      __vpiDecConst index_;
      bool has_index_;
};

/* M12: a modport declaration of an interface. M12-6 adds the port
   list: vpi_iterate(vpiIODecl) yields one handle per modport port
   with its declared direction (vpi_get(vpiDirection)). */
class __vpiModport;

class __vpiModportIO : public __vpiHandle {
    public:
      __vpiModportIO(__vpiModport*parent, const std::string&name, int dir)
      : parent_(parent), name_(name), dir_(dir) { }

      int get_type_code(void) const override { return vpiIODecl; }

      int vpi_get(int code) override
      {
	    switch (code) {
		case vpiDirection: return dir_;
		default: return vpiUndefined;
	    }
      }

      char* vpi_get_str(int code) override;

      vpiHandle vpi_handle(int code) override;

    private:
      __vpiModport*parent_;
      std::string name_;
      int dir_;
};

class __vpiModport : public __vpiHandle {
    public:
      __vpiModport(__vpiScope*scope, const char*name)
      : scope_(scope), name_(name) { }

      int get_type_code(void) const override { return vpiModport; }

      int vpi_get(int code) override
      {
	    switch (code) {
		case vpiLineNo: return 0;
		case vpiSize: return (int)ports_.size();
		default: return vpiUndefined;
	    }
      }

      char* vpi_get_str(int code) override
      { return generic_get_str(code, scope_, name_, NULL); }

      vpiHandle vpi_handle(int code) override
      {
	    if (code == vpiScope || code == vpiParent
		|| code == vpiInterface || code == vpiModule)
		  return scope_;
	    return 0;
      }

      vpiHandle vpi_iterate(int code) override
      {
	    if (code != vpiIODecl || ports_.empty())
		  return 0;
	    vpiHandle*args = (vpiHandle*)malloc(ports_.size() * sizeof(vpiHandle));
	    for (size_t idx = 0 ; idx < ports_.size() ; idx += 1)
		  args[idx] = ports_[idx];
	    return vpip_make_iterator((unsigned)ports_.size(), args, true);
      }

      void add_port(const std::string&pname, int dir)
      { ports_.push_back(new __vpiModportIO(this, pname, dir)); }

      const char*name() const { return name_; }

    private:
      __vpiScope*scope_;
      const char*name_;
      std::vector<__vpiModportIO*> ports_;
};

char* __vpiModportIO::vpi_get_str(int code)
{
      switch (code) {
	  case vpiName: {
		char*rbuf = (char*)need_result_buf(name_.size()+1, RBUF_STR);
		strcpy(rbuf, name_.c_str());
		return rbuf;
	  }
	  case vpiFullName: {
		char*pn = parent_->vpi_get_str(vpiFullName);
		std::string full = std::string(pn ? pn : "?") + "." + name_;
		char*rbuf = (char*)need_result_buf(full.size()+1, RBUF_STR);
		strcpy(rbuf, full.c_str());
		return rbuf;
	  }
	  default:
	    return 0;
      }
}

vpiHandle __vpiModportIO::vpi_handle(int code)
{
      if (code == vpiParent || code == vpiScope)
	    return parent_;
      return 0;
}

/*
 * The current_scope is a compile time concept. As the vvp source is
 * compiled, items that have scope are placed in the current
 * scope. The ".scope" directives select the scope that is current.
 */
static __vpiScope*current_scope = 0;

/* M12: a covergroup TYPE handle for VPI introspection. Wraps the
   registered class_type; vpi_get_value returns the type coverage
   (the merged per-item weighted percentage, as a real). */
class __vpiCovergroup : public __vpiHandle {
    public:
      explicit __vpiCovergroup(const class_type*defn) : defn_(defn) { }

      int get_type_code(void) const override { return vpiCovergroup; }

      int vpi_get(int code) override
      {
	    switch (code) {
		case vpiSize:
		  return (int)defn_->covgrp_bin_count();
		default:
		  return vpiUndefined;
	    }
      }

      char* vpi_get_str(int code) override
      {
	    std::string full = defn_->scope_path() + "." + defn_->class_name();
	    const std::string&use = (code == vpiFullName) ? full
				  : defn_->class_name();
	    if (code != vpiName && code != vpiFullName)
		  return 0;
	    char*rbuf = (char*)need_result_buf(use.size()+1, RBUF_STR);
	    strcpy(rbuf, use.c_str());
	    return rbuf;
      }

      void vpi_get_value(p_vpi_value val) override
      {
	    if (val->format == vpiObjTypeVal)
		  val->format = vpiRealVal;
	    if (val->format == vpiRealVal) {
		  val->value.real = defn_->type_coverage();
		  return;
	    }
	    if (val->format == vpiIntVal) {
		  val->value.integer = (PLI_INT32)defn_->type_coverage();
		  return;
	    }
	    val->format = vpiSuppressVal;
      }

    private:
      const class_type*defn_;
};

/* M12: root iterator over all covergroup types in the design. */
vpiHandle vpip_make_covergroup_iterator(void)
{
      const std::vector<const class_type*>&reg = class_type::covgrp_registry();
      if (reg.empty())
	    return 0;
      vpiHandle*args = (vpiHandle*)malloc(reg.size() * sizeof(vpiHandle));
      for (size_t idx = 0 ; idx < reg.size() ; idx += 1)
	    args[idx] = new __vpiCovergroup(reg[idx]);
      return vpip_make_iterator(reg.size(), args, true);
}

/* M12B: a concurrent-assertion object handle (IEEE 1800-2017 clause 40).
   The synthesized checkers register themselves at time 0 through
   $ivl_register_assertion, so vpi_iterate(vpiAssertion, scope) and
   vpi_iterate(vpiAssertion, 0) return real identities carrying the
   assertion's name, file, line, and scope. */
static int assertion_cb_total = 0;

class __vpiAssertionCallback : public __vpiCallback {
    public:
      __vpiAssertionCallback(int reason, vpi_assertion_cb_func cb,
                             char* user_data)
      : reason_(reason), cb_(cb), user_data_(user_data) { }

      PLI_INT32 remove() override
      {
            if (active_) {
                  active_ = false;
                  assert(assertion_cb_total > 0);
                  assertion_cb_total -= 1;
            }
            return 1;
      }

      bool active(void) const { return active_; }
      int reason(void) const { return reason_; }
      PLI_INT32 call(p_vpi_time time, vpiHandle assertion,
                     p_vpi_attempt_info info)
      {
            if (!active_) return 0;
            return cb_(reason_, time, assertion, info,
                       (PLI_BYTE8*)user_data_);
      }

    private:
      int reason_;
      vpi_assertion_cb_func cb_;
      char* user_data_;
      bool active_ = true;
};

struct assert_cb_t {
      __vpiAssertionCallback* callback;
};

/* IEEE 1800-2023 39.4.2: an expression matched (or failed) in a step,
   with its source reference. The checkers keep only the boolean's source
   text, so the handle answers vpiDecompile, vpiFile and vpiLineNo. */
class __vpiAssertionStepExpr : public __vpiHandle {
    public:
      __vpiAssertionStepExpr(const std::string&file, int line,
			     const std::string&text)
      : file_(file), line_(line), text_(text) { }
      int get_type_code(void) const override { return vpiOperation; }
      int vpi_get(int code) override
      {
	    return code == vpiLineNo ? line_ : vpiUndefined;
      }
      char* vpi_get_str(int code) override
      {
	    const std::string*use = code == vpiFile ? &file_
				  : code == 54 /* vpiDecompile */ ? &text_ : 0;
	    if (!use) return 0;
	    char*rbuf = (char*)need_result_buf(use->size()+1, RBUF_STR);
	    strcpy(rbuf, use->c_str());
	    return rbuf;
      }
    private:
      std::string file_;
      int line_;
      std::string text_;
};

/* IEEE 1800-2023 39.4.2 per-assertion control callback reasons, with their
   Annex M values; sv_vpi_user.h does not name them yet (#883). */
enum {
      cbAssertionEnablePassAction_ = 645, cbAssertionEnableFailAction_ = 646,
      cbAssertionDisablePassAction_ = 647, cbAssertionDisableFailAction_ = 648,
      cbAssertionEnableNonvacuousAction_ = 649,
      cbAssertionDisableVacuousAction_ = 650,
      cbAssertionLock_ = 661, cbAssertionUnlock_ = 662
};

class __vpiAssertion : public __vpiHandle {
    public:
      __vpiAssertion(int idx, const char*nam, const char*file, int line,
		     __vpiScope*scope, int depth_arg, int flags,
		     int assertion_kind)
      : idx_(idx), name_(nam?nam:""), file_(file?file:""), line_(line),
	scope_(scope),
	  // M12-2: depth_arg is the fixed start->accept edge count (>=1)
	  // or 0 (variable/unknown). The attempt's real tick latency is
	  // depth_arg-1; latency_ < 0 disables start-time recovery.
	latency_(depth_arg >= 1 ? depth_arg - 1 : -1),
	  // M12-1: bit0 = a FAILURE report can only come from an attempt
	  // that ran the full latency (implications). A plain sequence
	  // also fails an attempt that dies at its FIRST step, whose
	  // start is the failing tick itself.
	fail_full_latency_((flags & 1) != 0),
	assertion_type_(assertion_kind == 4 ? vpiAssume
			: assertion_kind == 2 ? vpiCover : vpiAssert),
	ctl_dir_(assertion_kind == 4 || assertion_kind == 2 ? assertion_kind : 1)
      {
	      // 39.4.2: bit1 = the checker reports steps per attempt; bits 8+
	      // carry the largest clock age a step report names.
	    steps_ok_ = (flags & 2) != 0;
	    step_depth_ = steps_ok_ ? (flags >> 8) : -1;
      }

      __vpiAssertion(unsigned long source_id, __vpiScope*scope,
		     int deferred_type, const char*file, int line,
		     bool is_final)
	: idx_(-1), name_(""), file_(file ? file : ""), line_(line),
	  scope_(scope), latency_(-1), fail_full_latency_(false),
	  deferred_source_id_(source_id), deferred_type_(deferred_type),
	  ctl_type_(is_final ? 8 : 4), ctl_dir_(immediate_dir_(deferred_type)) { }

      __vpiAssertion(const char*name, const char*file, int line,
		     __vpiScope*scope, int immediate_type)
	: idx_(-1), name_(name ? name : ""), file_(file ? file : ""),
	  line_(line), scope_(scope), latency_(-1),
	  fail_full_latency_(false), immediate_type_(immediate_type),
	  ctl_type_(2), ctl_dir_(immediate_dir_(immediate_type)) { }

      static int immediate_dir_(int type)
	{
	    return type == vpiImmediateCover ? 2
		 : type == vpiImmediateAssume ? 4 : 1;
	}

      int get_type_code(void) const override { return vpiAssertion; }

      int vpi_get(int code) override
      {
	    if (code == vpiAssertAttemptCovered) return attempts_;
	    if (code == vpiAssertSuccessCovered) return successes_;
	    if (code == vpiType && immediate_type_ != vpiUndefined)
		  return immediate_type_;
	    if (code == vpiType && deferred_source_id_)
		  return deferred_type_;
	    if (code == vpiType)
		  return assertion_type_;
	    if (code == vpiLineNo) return line_;
	    return vpiUndefined;
      }

      char* vpi_get_str(int code) override
      {
	    const std::string*use = 0;
	    std::string full;
	    if (code == vpiName || code == vpiDefName) {
		  use = &name_;
	    } else if (code == vpiFullName) {
	  if (deferred_source_id_) {
			char*scope_name = scope_ ? scope_->vpi_get_str(vpiFullName) : 0;
			full = scope_name ? scope_name : "";
		  } else {
			  /* The scope's full name, not its leaf name: an
			     assertion in u of top is top.u.x, not u.x. */
			full = (scope_ ? std::string(scope_->vpi_get_str(vpiFullName))
					 + "." : "") + name_;
		  }
		  use = &full;
	    } else if (code == vpiFile) {
		  use = &file_;
	    } else {
		  return 0;
	    }
	    char*rbuf = (char*)need_result_buf(use->size()+1, RBUF_STR);
	    strcpy(rbuf, use->c_str());
	    return rbuf;
      }

      vpiHandle vpi_handle(int code) override
      {
	    if (code == vpiScope || code == vpiInstance)
		  return scope_;
	    return 0;
      }

      bool reset_deferred(void)
	{
	    if (!deferred_source_id_) return false;
	    /* Reset clears assertion evaluation state and pending reports. Keep the
	       independent enable/disable control status; an explicit enable is
	       required after a VPI disable. */
	    vpip_cancel_deferred_assertion(deferred_source_id_, scope_);
	    fire(cbAssertionReset);
	    return true;
	}

      bool is_deferred(void) const { return deferred_source_id_ != 0; }
      bool is_concurrent(void) const { return idx_ >= 0; }

	/* 39.5.1: a vpi_control action operation has "no effect on any
	   existing attempts". The concurrent lowerings do not yet track
	   when an attempt started, so the change also reaches attempts in
	   progress; say so once per assertion. */
      void note_vpi_action_control(int operation)
	{
	    if (vpi_action_noted_) return;
	    vpi_action_noted_ = true;
	    vpi_printf("SVA note: vpi_control(%d) also changes the action "
		       "control of attempts of %s that are already in "
		       "progress; IEEE 1800-2023 39.5.1 exempts them, but this "
		       "assertion's lowering does not track when an attempt "
		       "started.\n", operation,
		       std::string(scope_ ? scope_->vpi_get_str(vpiFullName)
				   : "").append(".").append(name_).c_str());
	}

	/* IEEE 1800-2023 16.14.6: a procedural concurrent assertion starts
	   an attempt only for an instance its procedure queued and the
	   Observed region matured. */
      void set_proc_id(int pid, bool each)
	{ proc_id_ = pid; proc_each_ = each; }
	/* 16.14.6.1: each instance keeps the values it saved when queued. */
      void proc_matured(const std::vector<vvp_vector4_t>&saved)
	{ proc_matured_ += 1; proc_saved_.push_back(saved); }
	/* Saved value j of the idx-th instance taken at the last clock. */
      const vvp_vector4_t* taken_value(PLI_INT32 idx, PLI_INT32 j) const
	{
	    if (idx < 0 || (size_t)idx >= proc_taken_.size()) return 0;
	    const std::vector<vvp_vector4_t>&v = proc_taken_[idx];
	    if (j < 0 || (size_t)j >= v.size()) return 0;
	    return &v[j];
	}
	/* The checker takes every matured instance at its leading clock.
	   Under $assertoff they start no attempt and are discarded (default
	   pending a ruling: 20.11 Off "No new attempts will be started"). */
      PLI_INT32 take_matured(void)
	{
	    PLI_INT32 n = proc_matured_;
	    proc_matured_ = 0;
	    proc_taken_.swap(proc_saved_);
	    proc_saved_.clear();
	    if (!enabled_) { proc_taken_.clear(); return 0; }
	    if (n > 1 && !proc_each_ && !proc_multi_noted_) {
		  proc_multi_noted_ = true;
		  vpi_printf("SVA note: %d pending instances of procedural "
			     "assertion %s matured for one clock; this "
			     "assertion's lowering starts one attempt for "
			     "them.\n", (int)n,
			     std::string(scope_ ? scope_->vpi_get_str(vpiFullName)
					 : "").append(".").append(name_).c_str());
	    }
	    return n;
	}

	/* IEEE 1800-2023 20.11: a rule selects this assertion by its
	   assertion_type (Table 20-6) and directive_type (Table 20-7)
	   bits, then by the hierarchical selector. A selector names either
	   the assertion itself or a scope; scope levels count module
	   instances, as for $dumpvars (21.7.1.2). */
      bool control_selected(int atype, int dtype, const char*selector,
			    int levels) const
	{
	    if (!(atype & ctl_type_) || !(dtype & ctl_dir_)) return false;
	    if (!selector) return true;
	    if (!name_.empty() && scope_
		&& std::string(scope_->vpi_get_str(vpiFullName)) + "." + name_
		   == selector)
		  return true;
	    return vpip_deferred_assert_scope_matches(scope_, selector, levels);
	}

	/* Apply one control_type (Table 20-5), or one of the 39.5.1 system
	   controls vpiAssertionSysReset (12) and vpiAssertionSysEnd (13).
	   Lock and Unlock always apply; every other control skips a locked
	   assertion. Reset restores the initial state, lock included; after
	   End nothing applies. Callbacks keep the
	   reasons each assertion kind reported before 20.11 control existed:
	   concurrent assertions report enable changes and kill/reset,
	   deferred ones report enable changes and reset (fired by the
	   caller once every selected report is flushed), immediate ones none.
	   Returns true when a deferred assertion was killed. */
      bool apply_control(int ctl, bool callbacks)
	{
	    if (ended_) return false;
	    if (ctl == 12 || ctl == 13) {
		  bool killed;
		  locked_ = false;
		  killed = apply_control(5, callbacks);
		    /* 39.5.1: the initial state; "By default, stepping is
		       disabled for all assertions" (39.5.2). */
		  step_ctl_.clear();
		  serial_start_.clear();
		  if (ctl == 13) {
			ended_ = true;
			fail_action_ = pass_nonvacuous_ = pass_vacuous_ = false;
			remove_callbacks(false);
		  } else {
			enabled_ = true;
			fail_action_ = pass_nonvacuous_ = pass_vacuous_ = true;
			remove_callbacks(true);
		  }
		  return killed;
	    }
	    bool notify = callbacks && (idx_ >= 0 || deferred_source_id_);
	    if (ctl == 1 || ctl == 2) {
		  bool was_locked = locked_;
		  locked_ = ctl == 1;
		  if (notify && was_locked != locked_)
			fire(locked_ ? cbAssertionLock_ : cbAssertionUnlock_);
		  return false;
	    }
	    if (locked_) return false;
	    bool was = enabled_;
	    bool was_fail = fail_action_, was_pass = pass_nonvacuous_,
		 was_vac = pass_vacuous_;
	    switch (ctl) {
		case 3:
		case 4:
		  enabled_ = ctl == 3;
		  if (notify && was != enabled_)
			fire(enabled_ ? cbAssertionEnable : cbAssertionDisable);
		  return false;
		case 5:
		  enabled_ = false;
		  kill_generation_ += 1;
		    /* 20.11 Kill flushes the pending procedural instances;
		       matured ones still waiting for their clock are
		       discarded too (default pending a ruling). */
		  if (proc_id_) {
			proc_matured_ = 0;
			proc_saved_.clear();
			vpip_cancel_proc_asserts(proc_id_, scope_);
		  }
		  if (notify && was) fire(cbAssertionDisable);
		  if (deferred_source_id_) {
			vpip_cancel_deferred_assertion(deferred_source_id_, scope_);
			return true;
		  }
		  if (notify) {
			fire(cbAssertionKill);
			fire(cbAssertionReset);
		  }
		  return false;
		case 6:  pass_nonvacuous_ = pass_vacuous_ = true;  break;
		case 7:  pass_nonvacuous_ = pass_vacuous_ = false; break;
		case 8:  fail_action_ = true;  break;
		case 9:  fail_action_ = false; break;
		case 10: pass_nonvacuous_ = true; break;
		case 11: pass_vacuous_ = false; break;
		default: return false;
	    }
	      /* 39.4.2 per-assertion action callbacks, on a change. */
	    if (notify && (was_fail != fail_action_ || was_pass != pass_nonvacuous_
			   || was_vac != pass_vacuous_)) {
		  static const int reason[] = {
			cbAssertionEnablePassAction_, cbAssertionDisablePassAction_,
			cbAssertionEnableFailAction_, cbAssertionDisableFailAction_,
			cbAssertionEnableNonvacuousAction_,
			cbAssertionDisableVacuousAction_ };
		  fire(reason[ctl - 6]);
	    }
	    return false;
	}

	/* 39.5.1: Reset removes the step callbacks, End removes them all. */
      void remove_callbacks(bool steps_only)
	{
	    for (size_t i = 0 ; i < cbs_.size() ; i += 1) {
		  int reason = cbs_[i].callback->reason();
		  if (!steps_only || reason == cbAssertionStepSuccess
		      || reason == cbAssertionStepFailure)
			cbs_[i].callback->remove();
	    }
	}

      PLI_INT32 control_state(int what) const
	{
	    switch (what) {
		case vpipAssertStateEnabled:        return enabled_;
		case vpipAssertStateKillGeneration: return (PLI_INT32)kill_generation_;
		case vpipAssertStateFailAction:     return fail_action_;
		case vpipAssertStatePassAction:     return pass_nonvacuous_;
		case vpipAssertStateVacuousAction:  return pass_vacuous_;
		default: return -1;
	    }
	}

	/* A probe that stands for an assertion whose registration has not
	   run yet: it has the kind's assertion_type bit and matches every
	   directive. */
      void make_control_probe(int type_bit)
	{
	    ctl_type_ = type_bit;
	    ctl_dir_ = 7;
	}

      void report_control_reset(void)
	{
	    if (deferred_source_id_) fire(cbAssertionReset);
	}

      vpiHandle add_cb(int reason, vpi_assertion_cb_func cb, char*data)
      {
            __vpiAssertionCallback*callback =
                  new __vpiAssertionCallback(reason, cb, data);
            assert_cb_t c;
            c.callback = callback;
	    cbs_.push_back(c);
            return callback;
      }

      void report_immediate_cover(bool success)
      {
	    attempts_ += 1;
	    if (success) successes_ += 1;
      }

      void report_immediate_assertion(bool success)
      {
	    attempts_ += 1;
	    fire(success ? cbAssertionSuccess : cbAssertionFailure);
      }

      bool report_deferred_cover_failure(void)
      {
	    if (!deferred_source_id_ || deferred_type_ != vpiImmediateCover)
		  return false;
	    attempts_ += 1;
	    return true;
      }

	/* Record every sampled checker clock, even when assertion control
	   suppresses a new start. Ages then index real raw simulation times
	   instead of assuming a fixed clock period or a gapless START ring. */
      void clock_tick()
      {
	    int depth = latency_ > step_depth_ ? latency_ : step_depth_;
	    if (depth < 0) return;
	    clocks_.push_back(schedule_simtime());
	    while ((int)clocks_.size() > depth + 1)
		  clocks_.erase(clocks_.begin());
      }

	/* IEEE 1800-2023 39.5.2 with the 2026-11-12 ruling (SVA Q7): an
	   EnableStep/DisableStep names an attempt by its start time and
	   applies when issued before that attempt starts, or during its own
	   cbAssertionStart callback; later it has no effect. step_ctl_ maps
	   start time -> whether that attempt has started. */
      PLI_INT32 step_control(vvp_time64_t start, bool enable)
      {
	    if (!steps_ok_) {
		  if (!steps_refused_)
			vpi_printf("sorry: %s:%d: per-attempt step callbacks are "
				   "not supported for this assertion form; "
				   "vpiAssertionEnableStep has no effect.\n",
				   file_.c_str(), line_);
		  steps_refused_ = true;
		  return 0;
	    }
	    vvp_time64_t now = schedule_simtime();
	    bool open = start > now
		  || (start == now && (in_start_ || start_now_ != now));
	    if (!open) return 0;
	    if (enable)
		  step_ctl_[start] = (start == now && in_start_);
	    else
		  step_ctl_.erase(start);
	    return 1;
      }

      int serial(void) const { return attempts_; }

      void step_row(int row, int reason, int from, int to, int n,
		    const char*const*files, const PLI_INT32*lines,
		    const char*const*texts)
      {
	    if (row < 1) return;
	    if ((size_t)row > step_rows_.size()) step_rows_.resize(row);
	    step_row_t&r = step_rows_[row-1];
	    r.reason = reason;
	    r.from = from;
	    r.to = to;
	    for (int i = 0 ; i < n ; i += 1)
		  r.exprs.push_back(expr_handle_(files[i], lines[i], texts[i]));
      }

      void step(int row, int age, int serial)
      {
	    if (step_ctl_.empty() || row < 1
		|| (size_t)row > step_rows_.size()) return;
	    step_row_t&r = step_rows_[row-1];
	    vvp_time64_t start_raw;
	    if (serial > 0) {
		  std::map<int,vvp_time64_t>::const_iterator it =
			serial_start_.find(serial);
		  if (it == serial_start_.end()) return;
		  start_raw = it->second;
	    } else if (age >= 0 && (size_t)age < clocks_.size()) {
		  start_raw = clocks_[clocks_.size() - 1 - age];
	    } else {
		  return;
	    }
	    std::map<vvp_time64_t,bool>::const_iterator on =
		  step_ctl_.find(start_raw);
	    if (on == step_ctl_.end() || !on->second) return;
	    deliver_(r.reason, start_raw, r.from, r.to, r.exprs);
      }

	/* The automaton checker's description, for nfa_step(). */
      void nfa(int nstates, int start, int accept, int nguards,
	       const char*const*files, const PLI_INT32*lines,
	       const char*const*texts, int nwords, const PLI_INT32*words)
      {
	    nfa_.nstates = nstates;
	    nfa_.start = start;
	    nfa_.accept = accept;
	    nfa_.guards.clear();
	    for (int g = 0 ; g < nguards ; g += 1)
		  nfa_.guards.push_back(expr_handle_(files[g], lines[g], texts[g]));
	    nfa_.edges.clear();
	    for (int w = 0 ; w + 2 < nwords ; ) {
		  nfa_edge_t e;
		  e.from = words[w++];
		  e.to = words[w++];
		  int n = words[w++];
		  for (int i = 0 ; i < n && w < nwords ; i += 1)
			e.guards.push_back(words[w++]);
		  nfa_.edges.push_back(e);
	    }
      }

	/* IEEE 1800-2023 39.4.2, one tick of the automaton slot holding the
	   attempt named by `serial': pre/nx are its state bits before and
	   after the tick, gv the guard values (binary strings, bit 0 last),
	   ob whether an implication's antecedent completed. A live attempt
	   reports one taken edge: into accept first, else from the lowest
	   state id. A dying one reports its lowest active state's first
	   guarded edge, ending with the guard that failed; an implication
	   whose antecedent died ends vacuously (a success into state 1).
	   State ids: start 0, accept 1, state j otherwise j+2. */
      void nfa_step(int serial, const char*pre, const char*nx,
		    const char*gv, bool ob)
      {
	    if (step_ctl_.empty()) return;
	    std::map<int,vvp_time64_t>::const_iterator it =
		  serial_start_.find(serial);
	    if (it == serial_start_.end()) return;
	    std::map<vvp_time64_t,bool>::const_iterator on =
		  step_ctl_.find(it->second);
	    if (on == step_ctl_.end() || !on->second) return;
	    auto bit = [](const char*v, int j) {
		  int len = (int)strlen(v);
		  return j < len && v[len-1-j] == '1';
	    };
	    auto id = [&](int j) {
		  return j == nfa_.start ? 0 : j == nfa_.accept ? 1 : j + 2;
	    };
	    auto exprs = [&](const nfa_edge_t&e, size_t n) {
		  std::vector<vpiHandle> r;
		  for (size_t i = 0 ; i < n && i < e.guards.size() ; i += 1)
			r.push_back(nfa_.guards[e.guards[i]]);
		  return r;
	    };
	    bool alive = false;
	    for (int j = 0 ; j < nfa_.nstates ; j += 1) alive |= bit(nx, j);
	    if (alive) {
		  const nfa_edge_t*best = 0;
		  for (const nfa_edge_t&e : nfa_.edges) {
			bool taken = bit(pre, e.from) && bit(nx, e.to);
			for (int g : e.guards) taken = taken && bit(gv, g);
			if (!taken) continue;
			if (!best
			    || (e.to == nfa_.accept && best->to != nfa_.accept)
			    || ((e.to == nfa_.accept) == (best->to == nfa_.accept)
				&& id(e.from) < id(best->from)))
			      best = &e;
		  }
		  if (best)
			deliver_(cbAssertionStepSuccess, it->second, id(best->from),
				 id(best->to), exprs(*best, best->guards.size()));
		  return;
	    }
	    int from = -1;
	    for (int j = 0 ; j < nfa_.nstates ; j += 1)
		  if (bit(pre, j) && (from < 0 || id(j) < id(from))) from = j;
	    if (from < 0) return;
	    const nfa_edge_t*first = 0;
	    for (const nfa_edge_t&e : nfa_.edges)
		  if (e.from == from
		      && (!first || (first->guards.empty() && !e.guards.empty())))
			first = &e;
	    size_t n = 0;
	    if (first) {
		  n = first->guards.size();
		  for (size_t i = 0 ; i < first->guards.size() ; i += 1)
			if (!bit(gv, first->guards[i])) {
			      n = i + 1;
			      break;
			}
	    }
	    deliver_(ob ? cbAssertionStepFailure : cbAssertionStepSuccess,
		     it->second, id(from), !ob || !first ? 1 : id(first->to),
		     first ? exprs(*first, n) : std::vector<vpiHandle>());
      }

    private:
      void deliver_(int reason, vvp_time64_t start_raw, int from, int to,
		    const std::vector<vpiHandle>&exprs)
      {
	    s_vpi_assertion_step_info stepinfo;
	    stepinfo.matched_expression_count = (PLI_INT32)exprs.size();
	    stepinfo.matched_exprs = exprs.empty() ? 0
				   : const_cast<vpiHandle*>(&exprs[0]);
	    stepinfo.stateFrom = from;
	    stepinfo.stateTo = to;
	    s_vpi_attempt_info info;
	    info.detail.step = &stepinfo;
	    info.attemptStartTime.type = vpiSimTime;
	    vpip_time_to_timestruct(&info.attemptStartTime, start_raw);
	    info.attemptStartTime.real = 0.0;
	    s_vpi_time t;
	    t.type = vpiSimTime;
	    vpip_time_to_timestruct(&t, schedule_simtime());
	    t.real = 0.0;
	    for (size_t i = 0 ; i < cbs_.size() ; i += 1)
		  if (cbs_[i].callback->reason() == reason
		      && cbs_[i].callback->active())
			cbs_[i].callback->call(&t, this, &info);
      }

      vpiHandle expr_handle_(const char*file_arg, int line, const char*text)
      {
	    std::string file = file_arg && file_arg[0] ? file_arg : file_;
	    vpiHandle&h = step_exprs_[file + ":" + std::to_string(line)
				      + ":" + text];
	    if (!h) h = new __vpiAssertionStepExpr(file, line, text);
	    return h;
      }

    public:

	/* Bookkeeping around one attempt's cbAssertionStart dispatch: forget
	   requests for start times that passed without a start, mark this
	   start time's request as started, and name the attempt by serial
	   for checkers that cannot recover its start from a clock age. */
      void fire(int reason, int age = -1)
      {
	    if (reason == cbAssertionStepSuccess
		|| reason == cbAssertionStepFailure)
		  return;  // steps go through step() only, per attempt
	    if (reason != cbAssertionStart) {
		  fire_(reason, age);
		  return;
	    }
	    vvp_time64_t now = schedule_simtime();
	    for (std::map<vvp_time64_t,bool>::iterator it = step_ctl_.begin();
		 it != step_ctl_.end() && it->first <= now ; ) {
		  if (it->first == now) it->second = true;
		  if (it->first < now && !it->second) step_ctl_.erase(it++);
		  else ++it;
	    }
	    start_now_ = now;
	    in_start_ = true;
	    fire_(reason, age);
	    in_start_ = false;
	    if (step_ctl_.count(now)) serial_start_[attempts_] = now;
      }

	/* Fire every registered callback whose reason matches. age < 0 keeps
	   the established two-argument report behavior for other checkers. */
      void fire_(int reason, int age)
      {
	      /* A passing deferred immediate cover is reported only after its
	         result survives the assertion report queue. A failing cover's
	         matured evaluation is counted separately without a failure event. */
	      if (deferred_source_id_ && deferred_type_ == vpiImmediateCover
	          && reason == cbAssertionSuccess)
		    attempts_ += 1;
	    if (reason == cbAssertionStart) attempts_ += 1;
	    else if (reason == cbAssertionSuccess) successes_ += 1;
	    if (cbs_.empty()) return;
	    /* Control and action-state events are not associated with a
	       particular assertion attempt. IEEE 1800-2017/2023 39.4.2
	       requires a NULL attempt-info pointer for these reasons. */
	    bool no_attempt_info = false;
	    switch (reason) {
	      case cbAssertionDisable:
	      case cbAssertionEnable:
	      case cbAssertionReset:
	      case cbAssertionKill:
	      case cbAssertionLock_:
	      case cbAssertionUnlock_:
	      case cbAssertionEnablePassAction_:
	      case cbAssertionEnableFailAction_:
	      case cbAssertionDisablePassAction_:
	      case cbAssertionDisableFailAction_:
	      case cbAssertionEnableNonvacuousAction_:
	      case cbAssertionDisableVacuousAction_:
		  no_attempt_info = true;
		  break;
	      default:
		  break;
	    }
	    vvp_time64_t now_raw = schedule_simtime();
	    s_vpi_time t;
	    t.type = vpiSimTime;
	    vpip_time_to_timestruct(&t, now_raw);
	    t.real = 0.0;

	      /* M12-2: recover a completing attempt's real start time.
		 For a fixed-latency automaton every attempt takes
		 exactly latency_ ticks, so the START-time ring (kept to
		 the last latency_+1 launch times) has the completing
		 attempt's start at its front. START launches now, so its
		 attemptStartTime is now. Variable/unknown latency
		 (latency_ < 0) reports now, which is exact for same-tick
		 assertions. */
	    vvp_time64_t start_raw = now_raw;
	    if (age >= 0) {
		  if ((size_t)age < clocks_.size())
			start_raw = clocks_[clocks_.size() - 1 - age];
		  else {
			vpi_printf("SVA internal error: missing clock for assertion "
				   "attempt age %d.\n", age);
			return;
		  }
	    } else if (reason == cbAssertionStart) {
		  if (latency_ >= 0) {
			starts_.push_back(now_raw);
			while ((int)starts_.size() > latency_ + 1)
			      starts_.erase(starts_.begin());
		  }
	    } else if ((reason == cbAssertionSuccess
			|| (reason == cbAssertionFailure && fail_full_latency_))
		       && latency_ >= 0
		       && (int)starts_.size() == latency_ + 1) {
		    // An accept always consumes the full latency, so the
		    // ring front is this attempt's launch. A failure only
		    // does when the checker guarantees it (an early death
		    // would otherwise be attributed to an older start).
		  start_raw = starts_.front();
	    }
	    s_vpi_time st;
	    st.type = vpiSimTime;
	    vpip_time_to_timestruct(&st, start_raw);
	    st.real = 0.0;

	    s_vpi_attempt_info info;
	    info.detail.failExpr = 0;
	    info.attemptStartTime = st;
	    for (size_t i = 0 ; i < cbs_.size() ; i += 1) {
		  if (cbs_[i].callback->reason() == reason
		      && cbs_[i].callback->active())
		  cbs_[i].callback->call(&t, this,
				 no_attempt_info ? 0 : &info);
	    }
      }

    private:
      int idx_;
      std::string name_;
      std::string file_;
      int line_;
      __vpiScope*scope_;
      std::vector<assert_cb_t> cbs_;
      int attempts_ = 0;
      int successes_ = 0;
      int latency_;                    // M12-2: fixed tick latency, or -1
      bool fail_full_latency_;         // M12-1: failures run full latency
      int assertion_type_ = vpiAssert;
      unsigned long deferred_source_id_ = 0;
      int deferred_type_ = vpiUndefined;
      int immediate_type_ = vpiUndefined;
	/* IEEE 1800-2023 20.11 control state. */
      int ctl_type_ = 1;                 // Table 20-6 assertion_type bit
      int ctl_dir_ = 1;                  // Table 20-7 directive_type bit
      int proc_id_ = 0;
      PLI_INT32 proc_matured_ = 0;
      bool proc_each_ = false;
      bool proc_multi_noted_ = false;
      std::vector< std::vector<vvp_vector4_t> > proc_saved_;
      std::vector< std::vector<vvp_vector4_t> > proc_taken_;
      bool locked_ = false;
      bool ended_ = false;
      bool vpi_action_noted_ = false;
      bool enabled_ = true;
      unsigned kill_generation_ = 0;
      bool fail_action_ = true;
      bool pass_nonvacuous_ = true;
      bool pass_vacuous_ = true;
      std::vector<vvp_time64_t> starts_;  // M12-2: recent attempt starts
      std::vector<vvp_time64_t> clocks_;  // Raw sampled times, including off gaps
	/* 39.5.2 per-attempt stepping. ponytail: entries for started
	   attempts are kept for the run; they are bounded by the number of
	   EnableStep calls, not by simulation length. */
      bool steps_ok_ = false;
      bool steps_refused_ = false;
      int step_depth_ = -1;
      bool in_start_ = false;
      vvp_time64_t start_now_ = ~(vvp_time64_t)0;
      std::map<vvp_time64_t,bool> step_ctl_;
      std::map<int,vvp_time64_t> serial_start_;
      std::map<std::string,vpiHandle> step_exprs_;
      struct step_row_t {
	    int reason = 0, from = 0, to = 0;
	    std::vector<vpiHandle> exprs;
      };
      std::vector<step_row_t> step_rows_;
      struct nfa_edge_t {
	    int from = 0, to = 0;
	    std::vector<int> guards;
      };
      struct {
	    int nstates = 0, start = 0, accept = 0;
	    std::vector<vpiHandle> guards;
	    std::vector<nfa_edge_t> edges;
      } nfa_;
};

static std::vector<__vpiAssertion*> assertion_registry;
static std::map<std::pair<__vpiScope*,int>, __vpiAssertion*> assertion_by_key;
static std::map<std::pair<__vpiScope*,unsigned long>, __vpiAssertion*>
      deferred_assertion_by_key;
static std::map<std::pair<__vpiScope*,int>, __vpiAssertion*>
      immediate_cover_by_key;
static std::map<std::pair<__vpiScope*,int>, __vpiAssertion*>
      immediate_assertion_by_key;
static bool selector_path_prefix_(const char*path, const char*prefix)
{
      size_t len;
      if (!path || !prefix) return false;
      len = strlen(prefix);
      return strncmp(path, prefix, len) == 0
	    && (path[len] == 0 || path[len] == '.');
}

static bool scope_is_hierarchy_level_(const __vpiScope*scope)
{
      return scope->is_cell || scope->get_type_code() == vpiModule;
}

bool vpip_deferred_assert_scope_matches(__vpiScope*scope,
				       const char*selector,
				       int levels)
{
      __vpiScope*cur;
      __vpiScope*selected_module = 0;
      int depth = 0;
      const char*full;
      if (!selector) return true;
      if (!scope) return false;
      full = scope->vpi_get_str(vpiFullName);
      if (!selector_path_prefix_(full, selector)) return false;
      if (levels == 0) return true;

      /* Find the deepest module/cell scope that contains the selector. A
	 named block, task, or process in the path does not consume a level. */
      for (cur = scope; cur; cur = cur->scope) {
	    const char*cur_name;
	    if (!scope_is_hierarchy_level_(cur)) continue;
	    cur_name = cur->vpi_get_str(vpiFullName);
	    if (selector_path_prefix_(selector, cur_name)) {
		  selected_module = cur;
		  break;
	    }
      }
      if (!selected_module) return false;

      for (cur = scope; cur; cur = cur->scope) {
	    if (scope_is_hierarchy_level_(cur)) depth += 1;
	    if (cur == selected_module) break;
      }
      return cur == selected_module && depth <= levels;
}

static void replay_assertion_control_(__vpiAssertion*obj);

void vpip_register_assertion(PLI_INT32 idx, const char*name, const char*file,
			     PLI_INT32 line, vpiHandle scope, PLI_INT32 depth_arg,
			     PLI_INT32 flags, PLI_INT32 assertion_kind)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      __vpiAssertion*obj = new __vpiAssertion((int)idx, name, file, (int)line,
					      sc, (int)depth_arg, (int)flags,
					      (int)assertion_kind);
      assertion_registry.push_back(obj);
      replay_assertion_control_(obj);
      if (sc) {
	    vpip_attach_to_scope(sc, obj);
	    assertion_by_key[std::make_pair(sc, (int)idx)] = obj;
      }
}

void vpip_register_deferred_assertion(unsigned long source_id,
				     unsigned assertion_kind,
				     unsigned file_idx,
				     unsigned line,
				     vpiHandle scope,
				     bool is_final)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      int deferred_type;
      if (!source_id || !sc || !line || file_idx >= file_names.size())
	    return;
      /* assertion_kind is the IEEE assertion-control selector retained by
	 the front end: assert=1, cover=2, assume=4. */
      switch (assertion_kind) {
	    case 1: deferred_type = vpiImmediateAssert; break;
	    case 2: deferred_type = vpiImmediateCover; break;
	    case 4: deferred_type = vpiImmediateAssume; break;
	    default: return;
      }
      std::pair<__vpiScope*,unsigned long>key(sc, source_id);
      if (deferred_assertion_by_key.find(key) != deferred_assertion_by_key.end())
	    return;
      __vpiAssertion*obj = new __vpiAssertion(source_id, sc, deferred_type,
						      file_names[file_idx],
						      line, is_final);
      assertion_registry.push_back(obj);
      replay_assertion_control_(obj);
      deferred_assertion_by_key[key] = obj;
      vpip_attach_to_scope(sc, obj);
}

void vpip_register_immediate_cover(PLI_INT32 source_id, const char*name,
				   const char*file, PLI_INT32 line,
				   vpiHandle scope)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!source_id || !sc || !line) return;
      std::pair<__vpiScope*,int>key(sc, (int)source_id);
      if (immediate_cover_by_key.find(key) != immediate_cover_by_key.end())
	    return;
      __vpiAssertion*obj = new __vpiAssertion(name, file, line, sc,
						      vpiImmediateCover);
      assertion_registry.push_back(obj);
      replay_assertion_control_(obj);
      immediate_cover_by_key[key] = obj;
      vpip_attach_to_scope(sc, obj);
}

void vpip_report_immediate_cover(PLI_INT32 source_id, PLI_INT32 success,
				 vpiHandle scope)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return;
      std::map<std::pair<__vpiScope*,int>, __vpiAssertion*>::iterator it =
	    immediate_cover_by_key.find(std::make_pair(sc, (int)source_id));
      if (it != immediate_cover_by_key.end())
	    it->second->report_immediate_cover(success != 0);
}

void vpip_register_immediate_assertion(PLI_INT32 source_id, const char*name,
				      const char*file, PLI_INT32 line,
				      PLI_INT32 assertion_kind,
				      vpiHandle scope)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      int immediate_type;
      if (source_id <= 0 || !sc || !line) return;
      switch (assertion_kind) {
	    case 1: immediate_type = vpiImmediateAssert; break;
	    case 4: immediate_type = vpiImmediateAssume; break;
	    default: return;
      }
      std::pair<__vpiScope*,int>key(sc, (int)source_id);
      if (immediate_assertion_by_key.find(key)
	  != immediate_assertion_by_key.end())
	    return;
      __vpiAssertion*obj = new __vpiAssertion(name, file, line, sc,
						     immediate_type);
      assertion_registry.push_back(obj);
      replay_assertion_control_(obj);
      immediate_assertion_by_key[key] = obj;
      vpip_attach_to_scope(sc, obj);
}

void vpip_report_immediate_assertion(PLI_INT32 source_id, PLI_INT32 success,
				     vpiHandle scope)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return;
      while (sc) {
	    std::map<std::pair<__vpiScope*,int>, __vpiAssertion*>::iterator it =
		  immediate_assertion_by_key.find(
			std::make_pair(sc, (int)source_id));
	    if (it != immediate_assertion_by_key.end()) {
		  it->second->report_immediate_assertion(success != 0);
		  return;
	    }
	    sc = sc->scope;
      }
}

/* IEEE 1800-2023 20.11 assertion control. Every request is kept as a
   chronological rule, so an assertion that registers after a time-zero
   control call (its registration runs in an initial process) still sees it. */
struct assert_ctl_rule_t {
      bool all;
      std::string selector;
      int levels;
      int ctl;
      int atype;
      int dtype;
};
static std::vector<assert_ctl_rule_t> assert_ctl_rules;
static const size_t assert_ctl_rule_limit = 4096;

static void replay_assertion_control_(__vpiAssertion*obj)
{
      for (size_t i = 0 ; i < assert_ctl_rules.size() ; i += 1) {
	    const assert_ctl_rule_t&r = assert_ctl_rules[i];
	    if (obj->control_selected(r.atype, r.dtype,
				      r.all ? 0 : r.selector.c_str(), r.levels))
		  obj->apply_control(r.ctl, false);
      }
}

PLI_INT32 vpip_assertion_control(PLI_INT32 ctl, PLI_INT32 atype,
				 PLI_INT32 dtype, PLI_INT32 levels,
				 const char*const*selectors, PLI_INT32 nsel)
{
      size_t first = assert_ctl_rules.size();
      if (ctl < 1 || ctl > 13) return 0;
      for (PLI_INT32 i = 0 ; i < (nsel > 0 ? nsel : 1) ; i += 1) {
	    if (assert_ctl_rules.size() >= assert_ctl_rule_limit) {
		  vpi_printf("SVA runtime error: assertion-control history "
			     "exceeded %zu entries; the control request was not "
			     "applied.\n", assert_ctl_rule_limit);
		  break;
	    }
	    assert_ctl_rule_t r;
	    r.all = nsel <= 0;
	    r.selector = r.all ? "" : selectors[i];
	    r.levels = levels;
	    r.ctl = ctl;
	    r.atype = atype;
	    r.dtype = dtype;
	    assert_ctl_rules.push_back(r);

	      /* Deferred assertions first, as before: every enable change,
		 then every flush and its reset callback, in the order of
		 deferred_assertion_by_key that their callbacks always used. */
	    std::vector<__vpiAssertion*> killed;
	    for (auto cur = deferred_assertion_by_key.begin() ;
		 cur != deferred_assertion_by_key.end() ; ++cur) {
		  __vpiAssertion*obj = cur->second;
		  if (obj->control_selected(atype, dtype,
					    r.all ? 0 : r.selector.c_str(),
					    levels)
		      && obj->apply_control(ctl, true))
			killed.push_back(obj);
	    }
	    for (size_t j = 0 ; j < killed.size() ; j += 1)
		  killed[j]->fire(cbAssertionReset);
      }
      for (size_t i = first ; i < assert_ctl_rules.size() ; i += 1) {
	    const assert_ctl_rule_t&r = assert_ctl_rules[i];
	    for (size_t j = 0 ; j < assertion_registry.size() ; j += 1) {
		  __vpiAssertion*obj = assertion_registry[j];
		  if (!obj->is_deferred()
		      && obj->control_selected(atype, dtype,
					       r.all ? 0 : r.selector.c_str(),
					       levels))
			obj->apply_control(ctl, true);
	    }
      }
      return assert_ctl_rules.size() > first;
}

PLI_INT32 vpip_assertion_sys_control(PLI_INT32 operation, vpiHandle scope)
{
      int ctl;
      switch (operation) {
	  case vpiAssertionSysLock:   ctl = 1;  break;
	  case vpiAssertionSysUnlock: ctl = 2;  break;
	  case vpiAssertionSysOn:     ctl = 3;  break;
	  case vpiAssertionSysOff:    ctl = 4;  break;
	  case vpiAssertionSysKill:   ctl = 5;  break;
	  case vpiAssertionSysReset:  ctl = 12; break;
	  case vpiAssertionSysEnd:    ctl = 13; break;
	  case vpiAssertionSysEnablePassAction:       ctl = 6;  break;
	  case vpiAssertionSysDisablePassAction:      ctl = 7;  break;
	  case vpiAssertionSysEnableFailAction:       ctl = 8;  break;
	  case vpiAssertionSysDisableFailAction:      ctl = 9;  break;
	  case vpiAssertionSysEnableNonvacuousAction: ctl = 10; break;
	  case vpiAssertionSysDisableVacuousAction:   ctl = 11; break;
	  default: return 0;
      }
      if (scope && !dynamic_cast<__vpiScope*>(scope)) {
	    vpi_printf("VPI error: vpi_control(%d) needs a scope handle or "
		       "NULL.\n", (int)operation);
	    return 0;
      }
      const char*selector = scope ? scope->vpi_get_str(vpiFullName) : 0;
      std::string copy = selector ? selector : "";
      const char*sel = copy.c_str();
      if (ctl >= 6 && ctl <= 11) {
	    for (size_t j = 0 ; j < assertion_registry.size() ; j += 1) {
		  __vpiAssertion*obj = assertion_registry[j];
		  if (obj->is_concurrent()
		      && obj->control_selected(255, 7, selector ? sel : 0, 0))
			obj->note_vpi_action_control(operation);
	    }
      }
      PLI_INT32 rc = vpip_assertion_control(ctl, 255, 7, 0,
					    selector ? &sel : 0,
					    selector ? 1 : 0);
	/* 39.4.1: the matching assertion system callback (standard reason
	   values; sv_vpi_user.h does not name them yet). */
      static const struct { int op, reason; } sys_reasons[] = {
	    { vpiAssertionSysLock, 659 },   { vpiAssertionSysUnlock, 660 },
	    { vpiAssertionSysOn, 616 },     { vpiAssertionSysOff, 617 },
	    { vpiAssertionSysKill, 631 },   { vpiAssertionSysReset, 619 },
	    { vpiAssertionSysEnd, 618 },
	    { vpiAssertionSysEnablePassAction, 651 },
	    { vpiAssertionSysEnableFailAction, 652 },
	    { vpiAssertionSysDisablePassAction, 653 },
	    { vpiAssertionSysDisableFailAction, 654 },
	    { vpiAssertionSysEnableNonvacuousAction, 655 },
	    { vpiAssertionSysDisableVacuousAction, 656 },
      };
      for (size_t i = 0 ; i < sizeof sys_reasons / sizeof *sys_reasons ; i += 1)
	    if (sys_reasons[i].op == operation)
		  vpip_fire_assertion_sys_cb(sys_reasons[i].reason);
      return rc;
}

template <class Key> static __vpiAssertion* find_assertion_up_(
      const std::map<std::pair<__vpiScope*,Key>, __vpiAssertion*>&map,
      __vpiScope*sc, Key id, bool walk_up)
{
      for ( ; sc ; sc = walk_up ? sc->scope : 0) {
	    auto it = map.find(std::make_pair(sc, id));
	    if (it != map.end()) return it->second;
      }
      return 0;
}

/* Procedural concurrent assertions by (checker scope, procedural id). */
static std::map<std::pair<__vpiScope*,int>, __vpiAssertion*>
      proc_assertion_by_key;

void vpip_register_proc_assertion(PLI_INT32 idx, PLI_INT32 pid,
				  PLI_INT32 each, vpiHandle scope)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc || pid <= 0) return;
      auto it = assertion_by_key.find(std::make_pair(sc, (int)idx));
      if (it == assertion_by_key.end()) return;
      it->second->set_proc_id((int)pid, each != 0);
      proc_assertion_by_key[std::make_pair(sc, (int)pid)] = it->second;
}

bool vpip_proc_assert_may_queue(PLI_INT32 pid, __vpiScope*scope)
{
      __vpiAssertion*obj = find_assertion_up_(proc_assertion_by_key, scope,
					      (int)pid, true);
      return !obj || obj->control_state(vpipAssertStateEnabled) != 0;
}

void vpip_proc_assert_matured(PLI_INT32 pid, __vpiScope*scope,
			      const std::vector<vvp_vector4_t>&saved)
{
      __vpiAssertion*obj = find_assertion_up_(proc_assertion_by_key, scope,
					      (int)pid, true);
      if (obj) obj->proc_matured(saved);
}

/* $ivl_sva_proc_cap(pid, idx, j, dest): the checker loads saved value j of
   the idx-th instance it took into dest before starting its attempt. */
void vpip_proc_assert_cap(vpiHandle callh)
{
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      if (!argv) return;
      PLI_INT32 n[3] = { 0, 0, 0 };
      for (unsigned k = 0 ; k < 3 ; k += 1) {
	    vpiHandle arg = vpi_scan(argv);
	    if (!arg) return;
	    s_vpi_value v;
	    v.format = vpiIntVal;
	    vpi_get_value(arg, &v);
	    n[k] = v.value.integer;
      }
      vpiHandle dest = vpi_scan(argv);
      if (!dest) return;
      vpi_free_object(argv);
      __vpiScope*scope = dynamic_cast<__vpiScope*>(vpi_handle(vpiScope, callh));
      __vpiAssertion*obj = find_assertion_up_(proc_assertion_by_key, scope,
					      (int)n[0], true);
      const vvp_vector4_t*val = obj ? obj->taken_value(n[1], n[2]) : 0;
      if (!val) return;
      unsigned wid = vpi_get(vpiSize, dest);
      s_vpi_value out;
      out.format = vpiVectorVal;
      vpip_vec4_get_value(*val, wid, false, &out);
      vpi_put_value(dest, &out, 0, vpiNoDelay);
}

PLI_INT32 vpip_assertion_state(vpiHandle scope, PLI_INT32 space,
			       PLI_INT32 id, PLI_INT32 what)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      __vpiAssertion*obj = 0;
      int type_bit = 1;
      if (space == vpipAssertSpaceProcedural) {
	    obj = find_assertion_up_(proc_assertion_by_key, sc, (int)id, true);
	    if (what == vpipAssertStateTakeMatured)
		  return obj ? obj->take_matured() : 0;
	    return obj ? obj->control_state(what) : 1;
      }
      switch (space) {
	  case vpipAssertSpaceConcurrent:
	    obj = find_assertion_up_(assertion_by_key, sc, (int)id, false);
	    break;
	  case vpipAssertSpaceImmediate:
	    obj = find_assertion_up_(immediate_assertion_by_key, sc, (int)id, true);
	    type_bit = 2;
	    break;
	  case vpipAssertSpaceDeferred:
	    obj = find_assertion_up_(deferred_assertion_by_key, sc,
				     (unsigned long)id, true);
	    type_bit = 4 | 8;
	    break;
	  case vpipAssertSpaceImmediateCover:
	    obj = find_assertion_up_(immediate_cover_by_key, sc, (int)id, true);
	    type_bit = 2;
	    break;
	  default:
	    return -1;
      }
      if (obj) return obj->control_state(what);

	/* Not registered yet: fold the rule history over a probe in the
	   calling scope. */
      __vpiAssertion probe("", "", 0, sc, vpiUndefined);
      probe.make_control_probe(type_bit);
      replay_assertion_control_(&probe);
      return probe.control_state(what);
}

/* A matured deferred report runs its pass or fail action only when the
   assertion's action control allows it (20.11). The report itself and its
   callbacks are statistics and stay unconditional. */
bool vpip_deferred_action_enabled(unsigned long source_id, __vpiScope*scope,
				  unsigned result)
{
      __vpiAssertion*obj = find_assertion_up_(deferred_assertion_by_key, scope,
					      source_id, true);
      if (!obj) return true;
      return obj->control_state(result == 2 ? vpipAssertStateFailAction
					    : vpipAssertStatePassAction) != 0;
}

PLI_INT32 vpip_reset_deferred_assertion(vpiHandle assertion)
{
      __vpiAssertion*obj = dynamic_cast<__vpiAssertion*>(assertion);
      return obj && obj->reset_deferred();
}

void vpip_deferred_assertion_report(unsigned long source_id,
                                    PLI_INT32 reason, vpiHandle scope)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return;
      std::map<std::pair<__vpiScope*,unsigned long>, __vpiAssertion*>::iterator it =
	    deferred_assertion_by_key.find(std::make_pair(sc, source_id));
      if (it == deferred_assertion_by_key.end()) return;
      if (reason == cbAssertionFailure
	  && it->second->report_deferred_cover_failure())
	    return;
      it->second->fire((int)reason);
}

/* M12B-cb: fire success/failure callbacks for the (scope, idx) assertion. */
void vpip_assertion_report(PLI_INT32 idx, PLI_INT32 reason, vpiHandle scope)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return;
      std::map<std::pair<__vpiScope*,int>, __vpiAssertion*>::iterator it =
	    assertion_by_key.find(std::make_pair(sc, (int)idx));
      if (it != assertion_by_key.end())
	    it->second->fire((int)reason);
}

void vpip_assertion_clock(PLI_INT32 idx, vpiHandle scope)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return;
      auto it = assertion_by_key.find(std::make_pair(sc, (int)idx));
      if (it != assertion_by_key.end()) it->second->clock_tick();
}

void vpip_assertion_report_age(PLI_INT32 idx, PLI_INT32 reason,
                               vpiHandle scope, PLI_INT32 age)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return;
      auto it = assertion_by_key.find(std::make_pair(sc, (int)idx));
      if (it != assertion_by_key.end()) it->second->fire((int)reason, (int)age);
}

void vpip_assertion_step_row(PLI_INT32 idx, vpiHandle scope, PLI_INT32 row,
			     PLI_INT32 reason, PLI_INT32 from, PLI_INT32 to,
			     PLI_INT32 n, const char*const*files,
			     const PLI_INT32*lines, const char*const*texts)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return;
      auto it = assertion_by_key.find(std::make_pair(sc, (int)idx));
      if (it != assertion_by_key.end())
	    it->second->step_row(row, reason, from, to, n, files, lines, texts);
}

void vpip_assertion_step(PLI_INT32 idx, vpiHandle scope, PLI_INT32 row,
			 PLI_INT32 age, PLI_INT32 serial)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return;
      auto it = assertion_by_key.find(std::make_pair(sc, (int)idx));
      if (it != assertion_by_key.end()) it->second->step(row, age, serial);
}

void vpip_assertion_nfa(PLI_INT32 idx, vpiHandle scope, PLI_INT32 nstates,
			PLI_INT32 start, PLI_INT32 accept, PLI_INT32 nguards,
			const char*const*files, const PLI_INT32*lines,
			const char*const*texts, PLI_INT32 nwords,
			const PLI_INT32*words)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return;
      auto it = assertion_by_key.find(std::make_pair(sc, (int)idx));
      if (it != assertion_by_key.end())
	    it->second->nfa(nstates, start, accept, nguards, files, lines, texts,
			    nwords, words);
}

void vpip_assertion_nfa_step(PLI_INT32 idx, vpiHandle scope, PLI_INT32 serial,
			     const char*pre, const char*nx, const char*guards,
			     PLI_INT32 ob)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return;
      auto it = assertion_by_key.find(std::make_pair(sc, (int)idx));
      if (it != assertion_by_key.end())
	    it->second->nfa_step(serial, pre, nx, guards, ob != 0);
}

PLI_INT32 vpip_assertion_serial(PLI_INT32 idx, vpiHandle scope)
{
      __vpiScope*sc = dynamic_cast<__vpiScope*>(scope);
      if (!sc) return 0;
      auto it = assertion_by_key.find(std::make_pair(sc, (int)idx));
      return it != assertion_by_key.end() ? it->second->serial() : 0;
}

PLI_INT32 vpip_assertion_step_control(vpiHandle assertion,
				      const s_vpi_time*start, bool enable,
				      PLI_INT32 mode)
{
      __vpiAssertion*obj = dynamic_cast<__vpiAssertion*>(assertion);
      if (!obj || !start || mode != vpiAssertionClockSteps) {
	    vpi_printf("ERROR: vpi_control(%s) needs a concurrent assertion "
		       "handle, an attempt start time and "
		       "vpiAssertionClockSteps.\n",
		       enable ? "vpiAssertionEnableStep"
			      : "vpiAssertionDisableStep");
	    return 0;
      }
      vvp_time64_t t;
      if (start->type == vpiSimTime) {
	    t = vpip_timestruct_to_time(start);
      } else {
	    vpi_printf("ERROR: vpi_control(%s) takes a vpiSimTime attempt "
		       "start time.\n",
		       enable ? "vpiAssertionEnableStep"
			      : "vpiAssertionDisableStep");
	    return 0;
      }
      return obj->step_control(t, enable);
}

PLI_INT32 vpip_assertion_cb_active(void)
{
      return assertion_cb_total > 0 ? 1 : 0;
}

/* M12B-rest: fire a reason on every registered assertion. Used by the
   global assertion-control tasks: $assertoff -> cbAssertionDisable,
   $asserton -> cbAssertionEnable, $assertkill -> cbAssertionReset
   (IEEE 1800-2017 40.5.2). */
void vpip_assertion_report_all(PLI_INT32 reason)
{
      for (size_t i = 0 ; i < assertion_registry.size() ; i += 1)
	    assertion_registry[i]->fire((int)reason);
}

vpiHandle vpi_register_assertion_cb(vpiHandle assertion, PLI_INT32 reason,
				    vpi_assertion_cb_func cb_rtn,
				    PLI_BYTE8*user_data)
{
      if (!assertion || !cb_rtn) return 0;
      __vpiAssertion*a = dynamic_cast<__vpiAssertion*>(assertion);
      if (!a) return 0;
      vpiHandle callback = a->add_cb((int)reason, cb_rtn, (char*)user_data);
      assertion_cb_total += 1;
      return callback;
}

/* M12B: root iterator over all registered assertions
   (vpi_iterate(vpiAssertion, 0)). Scope-scoped iteration is served
   directly from the scope's intern list by module_iter. */
vpiHandle vpip_make_assertion_iterator(void)
{
      if (assertion_registry.empty())
	    return 0;
      vpiHandle*args =
	    (vpiHandle*)malloc(assertion_registry.size() * sizeof(vpiHandle));
      for (size_t idx = 0 ; idx < assertion_registry.size() ; idx += 1)
	    args[idx] = assertion_registry[idx];
      return vpip_make_iterator(assertion_registry.size(), args, true);
}

/* M12: attach a modport declaration to the current (interface)
   scope. M12-6: subsequent compile_modport_port calls append the
   directive's (port, direction) pairs to the modport just declared. */
static __vpiModport*last_modport_decl_ = 0;

void compile_modport_decl(char*name)
{
      assert(current_scope);
      const char*use_name = vpip_name_string(name);
      __vpiModport*obj = new __vpiModport(current_scope, use_name);
      vpip_attach_to_current_scope(obj);
      last_modport_decl_ = obj;
      delete[] name;
}

void compile_modport_port(char*name, uint64_t dir)
{
      assert(last_modport_decl_);
      last_modport_decl_->add_port(std::string(name), (int)dir);
      delete[] name;
}

void vpip_attach_to_scope(__vpiScope*scope, vpiHandle obj)
{
      assert(scope);
      scope->intern.push_back(obj);
}

void compile_stmt_node(uint64_t id, uint64_t parent, uint64_t type, char*name, int blocking)
{
      __vpiScope*scope = vpip_peek_current_scope();
      assert(id != 0 && type <= INT_MAX);
      assert(scope);
      __vpiStmtNode*obj = new __vpiStmtNode(static_cast<int>(type), name,
						       scope, blocking);
      assert(scope->statement_node_by_id.find(id)
	     == scope->statement_node_by_id.end());
      if (parent == UINT64_MAX) {
	    /* Hidden task/function entry block: it has an execution handle, but
	       the established vpiStmt relation exposes its only child as root. */
	  } else if (parent == 0) {
	    if ((scope->get_type_code() == vpiTask
		 || scope->get_type_code() == vpiFunction)
		&& scope->statement_root == 0)
		  scope->statement_root = obj;
      } else {
	    std::map<uint64_t, vpiHandle>::iterator par =
		  scope->statement_node_by_id.find(parent);
	    assert(par != scope->statement_node_by_id.end());
	    static_cast<__vpiStmtNode*>(par->second)->add_child(obj);
      }
      scope->statement_node_by_id[id] = obj;
      scope->statement_nodes.push_back(obj);
      delete[] name;
}

void compile_stmt_at(uint64_t id)
{
      __vpiScope*scope = vpip_peek_current_scope();
      __vpiStmtNode*node = 0;
      while (scope) {
	    std::map<uint64_t, vpiHandle>::iterator found =
		  scope->statement_node_by_id.find(id);
	    if (found != scope->statement_node_by_id.end()) {
		  node = dynamic_cast<__vpiStmtNode*>(found->second);
		  break;
	    }
	    scope = scope->scope;
      }
      if (!node) {
	    yyerror("invalid .stmt_at metadata");
	    compile_errors += 1;
	    return;
      }

      vvp_code_t code = codespace_next();
      for (size_t idx = 0; idx < node->code_addresses_.size(); idx += 1)
	    if (node->code_addresses_[idx] == code) return;
      node->code_addresses_.push_back(code);
      vpip_note_statement_code(code, node);
}

/*
 * When the compiler encounters a scope declaration, this function
 * creates and initializes a __vpiScope object with the requested name
 * and within the addressed parent. The label is used as a key in the
 * symbol table and the name is used to construct the actual object.
 */
void
compile_scope_decl(char*label, char*type, char*name, char*tname,
                   char*parent, long file_idx, long lineno,
                   long def_file_idx, long def_lineno, long is_cell)
{
      int join_type = vpiUndefined;
      int access_type = vpiUndefined;
      int dpi_pure = 0;
      int dpi_context = 0;
      int dpi_cstr = vpiUndefined;
      std::string dpi_c_identifier;
      char*dpi = strstr(type, ".dpi");
      if (dpi && strlen(dpi) >= 8 && dpi[7] == '_'
	  && (dpi[4] == '0' || dpi[4] == '1')
	  && (dpi[5] == '0' || dpi[5] == '1')
	  && (dpi[6] == '1' || dpi[6] == '2')) {
	    bool valid_identifier = true;
	    const char*cur = dpi + 8;
	    while (*cur) {
	          unsigned char hi, lo;
	          char upper = *cur++;
	          if (upper >= '0' && upper <= '9') hi = upper - '0';
	          else if (upper >= 'a' && upper <= 'f') hi = upper - 'a' + 10;
	          else { valid_identifier = false; break; }
	          if (!*cur) { valid_identifier = false; break; }
	          char lower = *cur++;
	          if (lower >= '0' && lower <= '9') lo = lower - '0';
	          else if (lower >= 'a' && lower <= 'f') lo = lower - 'a' + 10;
	          else { valid_identifier = false; break; }
	          dpi_c_identifier.push_back((hi << 4) | lo);
	    }
	    if (valid_identifier) {
	          dpi_pure = dpi[4] - '0';
	          dpi_context = dpi[5] - '0';
	          dpi_cstr = dpi[6] - '0';
	          *dpi = 0;
	    } else {
	          dpi_c_identifier.clear();
	    }
      }
      char*join = strstr(type, ".join");
      if (join && join[5] >= '0' && join[5] <= '2') {
	    join_type = join[5] - '0';
	    memmove(join, join + 6, strlen(join + 6) + 1);
      }
      char*access = strstr(type, ".acc");
      if (access && access[4] >= '1' && access[4] <= '4') {
	    access_type = access[4] - '0';
	    memmove(access, access + 5, strlen(access + 5) + 1);
      }
      count_vpi_scopes += 1;
      char vec_type;
      char sign_flag;
      unsigned wid;

        /* A mixed-lifetime static function uses the ordinary static VPI
           function class, with a separate context-owner bit. Canonicalize
           its type spelling before the existing return-type decoder. */
      bool mixed_lifetime_function = false;
      if (strncmp(type, "function.ctx.", 13) == 0) {
	    memmove(type + 8, type + 12, strlen(type + 12) + 1);
	    mixed_lifetime_function = true;
      }

      __vpiScope*scope;
      if (strcmp(type,"module") == 0) {
	    scope = new vpiScopeModule(name, tname);
      } else if ( sscanf(type, "function.vec%c.%c%u", &vec_type, &sign_flag, &wid) == 3 ) {
	    int type_code;
	    if (sign_flag=='s') {
		  type_code = vpiSizedSignedFunc;
	    } else if (sign_flag=='u') {
		  type_code = vpiSizedFunc;
	    } else if (sign_flag=='i') {
		  type_code = vpiIntFunc;
	    } else {
		  assert(0);
		  type_code = vpiSizedFunc;
	    }
	    vvp_bit4_t init_val = vec_type == '4' ? BIT4_X : BIT4_0;
	    scope = new vpiScopeFunction(name, tname, false, type_code, wid, init_val);

      } else if ( sscanf(type, "autofunction.vec%c.%c%u", &vec_type, &sign_flag, &wid) == 3 ) {
	    int type_code;
	    switch (sign_flag) {
		case 's':
		  type_code = vpiSizedSignedFunc;
		  break;
		case 'u':
		  type_code = vpiSizedFunc;
		  break;
		default:
		  assert(0);
		  type_code = vpiSizedFunc;
		  break;
	    }
	    vvp_bit4_t init_val = vec_type == '4' ? BIT4_X : BIT4_0;
	    scope = new vpiScopeFunction(name, tname, true, type_code, wid, init_val);

      } else if (strcmp(type,"function.obj") == 0) {
	    scope = new vpiScopeFunction(name, tname, false, vpiSizedFunc, 0, BIT4_0);
      } else if (strcmp(type,"autofunction.obj") == 0) {
	    scope = new vpiScopeFunction(name, tname, true, vpiSizedFunc, 0, BIT4_0);
      } else if (strcmp(type,"function.real") == 0) {
	    scope = new vpiScopeFunction(name, tname, false, vpiRealFunc, 0, BIT4_0);
      } else if (strcmp(type,"autofunction.real") == 0) {
	    scope = new vpiScopeFunction(name, tname, true, vpiRealFunc, 0, BIT4_0);
      } else if (strcmp(type,"function.str") == 0) {
	    scope = new vpiScopeFunction(name, tname, false, vpiOtherFunc, 0, BIT4_0);
      } else if (strcmp(type,"autofunction.str") == 0) {
	    scope = new vpiScopeFunction(name, tname, true, vpiOtherFunc, 0, BIT4_0);
      } else if (strcmp(type,"function.void") == 0) {
	    scope = new vpiScopeFunction(name, tname, false, vpiOtherFunc, 0, BIT4_0);
      } else if (strcmp(type,"autofunction.void") == 0) {
	    scope = new vpiScopeFunction(name, tname, true, vpiOtherFunc, 0, BIT4_0);
      } else if (strcmp(type,"task") == 0) {
	    scope = new vpiScopeTask(name, tname);
      } else if (strcmp(type,"task.ctx") == 0) {
	    scope = new vpiScopeTask(name, tname);
	    scope->set_owns_automatic_context();
      } else if (strcmp(type,"autotask") == 0) {
	    scope = new vpiScopeTaskAuto(name, tname);
      } else if (strcmp(type,"fork") == 0) {
	    scope = new vpiScopeFork(name, tname);
      } else if (strcmp(type,"fork.ctx") == 0) {
	    scope = new vpiScopeFork(name, tname);
	    scope->set_owns_automatic_context();
      } else if (strcmp(type,"autofork") == 0) {
	    scope = new vpiScopeForkAuto(name, tname);
      } else if (strcmp(type,"autofork.shared") == 0) {
	      /* Automatic fork scope collapsed into the enclosing
	         activation frame: locals ride the frame-owning ancestor
	         scope; no %alloc/%free is emitted for it. */
	    scope = new vpiScopeForkAuto(name, tname);
	    scope->set_shares_parent_frame();
      } else if (strcmp(type,"begin") == 0) {
	    scope = new vpiScopeBegin(name, tname);
      } else if (strcmp(type,"begin.ctx") == 0) {
	    scope = new vpiScopeBegin(name, tname);
	    scope->set_owns_automatic_context();
      } else if (strcmp(type,"autobegin") == 0) {
	    scope = new vpiScopeBeginAuto(name, tname);
      } else if (strcmp(type,"autobegin.shared") == 0) {
	    scope = new vpiScopeBeginAuto(name, tname);
	    scope->set_shares_parent_frame();
      } else if (strcmp(type,"for") == 0 || strcmp(type,"for.ctx") == 0) {
	    scope = new vpiScopeLoop(name, tname, false, false, vpiFor);
	    if (strcmp(type,"for.ctx") == 0)
	          scope->set_owns_automatic_context();
      } else if (strcmp(type,"autofor") == 0
	         || strcmp(type,"autofor.ctx") == 0) {
	    scope = new vpiScopeLoop(name, tname, true, false, vpiFor);
	    if (strcmp(type,"autofor.ctx") == 0)
	          scope->set_owns_automatic_context();
      } else if (strcmp(type,"autofor.shared") == 0) {
	    scope = new vpiScopeLoop(name, tname, true, true, vpiFor);
      } else if (strcmp(type,"foreach") == 0 || strcmp(type,"foreach.ctx") == 0) {
	    scope = new vpiScopeLoop(name, tname, false, false, vpiForeachStmt);
	    if (strcmp(type,"foreach.ctx") == 0)
	          scope->set_owns_automatic_context();
      } else if (strcmp(type,"autoforeach") == 0
	         || strcmp(type,"autoforeach.ctx") == 0) {
	    scope = new vpiScopeLoop(name, tname, true, false, vpiForeachStmt);
	    if (strcmp(type,"autoforeach.ctx") == 0)
	          scope->set_owns_automatic_context();
      } else if (strcmp(type,"autoforeach.shared") == 0) {
	    scope = new vpiScopeLoop(name, tname, true, true, vpiForeachStmt);
      } else if (strcmp(type,"generate") == 0) {
	    scope = new vpiScopeGenerate(name, tname);
      } else if (strcmp(type,"package") == 0) {
	    scope = new vpiScopePackage(name, tname);
      } else if (strcmp(type,"class") == 0) {
	    scope = new vpiScopeClass(name, tname);
      } else if (strcmp(type,"program") == 0) {
	    scope = new vpiScopeProgram(name, tname);
      } else if (strcmp(type,"interface") == 0) {
	    scope = new vpiScopeInterface(name, tname);
      } else {
	    scope = new vpiScopeModule(name, tname);
	    assert(0);
      }

      if (mixed_lifetime_function)
	    scope->set_owns_automatic_context();
      scope->join_type = join_type;
      scope->access_type = access_type;
      scope->dpi_pure = dpi_pure;
      scope->dpi_context = dpi_context;
      scope->dpi_cstr = dpi_cstr;
      if (dpi_cstr != vpiUndefined && !dpi_c_identifier.empty())
	    scope->dpi_c_identifier = vpip_name_string(dpi_c_identifier.c_str());

      scope->file_idx = (unsigned) file_idx;
      scope->lineno  = (unsigned) lineno;
      scope->def_file_idx = (unsigned) def_file_idx;
      scope->def_lineno  = (unsigned) def_lineno;
      scope->item = 0;
      scope->nitem = 0;
      scope->live_contexts = 0;
      scope->free_contexts = 0;

      if (is_cell) scope->is_cell = true;
      else scope->is_cell = false;

      current_scope = scope;

      compile_vpi_symbol(label, scope);

      free(label);
      free(type);
      delete[] name;
      delete[] tname;

      if (parent) {
	    static vpiHandle obj;
	    compile_vpi_lookup(&obj, parent);
	    assert(obj);
	    __vpiScope*sp = dynamic_cast<__vpiScope*>(obj);
	    vpip_attach_to_scope(sp, scope);
	    scope->scope = dynamic_cast<__vpiScope*>(obj);

	      /* Inherit time units and precision from the parent scope. */
	    scope->time_units = sp->time_units;
	    scope->time_precision = sp->time_precision;

      } else {
	    scope->scope = 0x0;

	    vpip_root_table.push_back(scope);

	      /* Root scopes inherit time_units and precision from the
	         system precision. */
	    scope->time_units = vpip_get_time_precision();
	    scope->time_precision = vpip_get_time_precision();
      }
}

void compile_scope_recall(char*symbol)
{
	/* A __vpiScope starts with a __vpiHandle structure so this is
	   a safe cast. We need the (void*) to avoid a dereferenced
	   type punned pointer warning from some gcc compilers. */
      compile_vpi_lookup((vpiHandle*)(void*)&current_scope, symbol);
      assert(current_scope);
}

/*
 * This function handles the ".timescale" directive in the vvp
 * source. It sets in the current scope the specified units value.
 */
void compile_timescale(long units, long precision)
{
      assert(current_scope);
      current_scope->time_units = units;
      current_scope->time_precision = precision;
}

__vpiScope* vpip_peek_current_scope(void)
{
      return current_scope;
}

void vpip_attach_to_current_scope(vpiHandle obj)
{
      vpip_attach_to_scope(current_scope, obj);
}

static bool scope_has_own_automatic_context_(__vpiScope*scope)
{
      if (!(scope && scope->has_automatic_context()))
            return false;

      switch (scope->get_type_code()) {
          case vpiTask:
          case vpiFunction:
            return true;
          case vpiNamedBegin:
          case vpiNamedFork:
              /* The compiler marks automatic begin/fork scopes that are
                 collapsed into the enclosing frame with ".shared" scope
                 types: their statement runs to completion before the
                 parent resumes, so their locals ride the enclosing
                 task/function (or frame-owning fork) frame and no %alloc
                 is emitted for them. Unmarked automatic block scopes own
                 a frame: join_any/join_none forks (detached branches
                 outlive the statement) and blocks with a static parent
                 (no enclosing frame exists to ride). */
            return !scope->shares_parent_frame();
          default:
            return false;
      }
}

__vpiScope* vpip_peek_context_scope(void)
{
      __vpiScope*scope = current_scope;

        /* A context is allocated for each automatic task or function.
           Storage for nested scopes (named blocks) is allocated in
           the parent context. */
      while (!scope_has_own_automatic_context_(scope)
             && scope->scope && scope->scope->has_automatic_context())
            scope = scope->scope;

      return scope;
}

unsigned vpip_add_item_to_context(automatic_hooks_s*item,
                                  __vpiScope*scope)
{
      assert(scope);
      assert(scope->has_automatic_context());

      unsigned idx = scope->nitem++;

      if (scope->item == 0)
	    scope->item = static_cast<automatic_hooks_s**>
	                  (malloc(sizeof(automatic_hooks_s*)));
      else
	    scope->item = static_cast<automatic_hooks_s**>
	                  (realloc(scope->item,
	                   sizeof(automatic_hooks_s*)*scope->nitem));

      scope->item[idx] = item;

        /* Offset the context index by 2 to leave space for the list links. */
      return 2 + idx;
}


vpiPortComponentInfo::vpiPortComponentInfo()
: index(0), width(0), name(0), left(0), right(0), fixture_width(0),
  fixture_base(0), fixture_drivers(0), fixture_ref(0),
  fixture_handle(0), dut_width(0), dut_drivers(0), dut_ref(0),
  dut_handle(0)
{
}

vpiPortComponentInfo::~vpiPortComponentInfo()
{
#ifdef CHECK_WITH_VALGRIND
      /* These private handles are non-owning views of resolver nodes, not
       * enumerated scope signals. Reclaim only the handle storage; their
       * shared nodes are cleaned through the ordinary scope signal. */
      if (fixture_handle) signal_handle_delete(fixture_handle);
      if (dut_handle) signal_handle_delete(dut_handle);
#endif
      delete[] name;
}

vpiPortInfo::vpiPortInfo( __vpiScope *parent,
              unsigned index,
              int vpi_direction,
              int vpi_port_type,
              unsigned width,
              const char *name,
              char* buffer) :
      parent_(parent),
      index_(index),
      direction_(vpi_direction),
      vpi_port_type_(vpi_port_type),
      width_(width),
      name_(name)
{
      if (buffer != nullptr) functor_ref_lookup(&ref_, buffer);
      else ref_ = nullptr;
}

vpiPortInfo::~vpiPortInfo()
{
      for (std::vector<vpiPortComponentInfo*>::iterator cur =
                 evcd_components_.begin(); cur != evcd_components_.end(); ++cur)
            delete *cur;
      delete[] name_;
}

#ifdef CHECK_WITH_VALGRIND
void port_delete(__vpiHandle *handle)
{
      delete dynamic_cast<vpiPortInfo *>(handle);
}
#endif

int vpiPortInfo::vpi_get(int code)
{
      switch( code ) {

        case vpiDirection :
          return direction_;
        case 611: // vpiPortType (IEEE 1800-2017/2023 Annex M)
          return vpi_port_type_;
        case vpiPortIndex :
          return index_;
        case vpiSize :
          return width_;
        case vpiScalar :
          return width_ == 1;
        case vpiVector :
          return width_ > 1;
        default :
          return vpiUndefined;
      }

}


char *vpiPortInfo::vpi_get_str(int code)
{
      switch( code ) {
        case vpiName :
          return simple_set_rbuf_str(name_);
        default :
          return NULL;
      }

}


/* vpiLowConn (IEEE 1800-2023 37.14 detail 4): the module's own signal
   of an ordinary port's name. A null port has none (detail 10). An
   interface or modport port needs a ref obj (detail 5), not built yet. */
vpiHandle vpiPortInfo::low_conn_(void)
{
      if (!name_ || !*name_ || vpi_port_type_ != vpiPort)
	    return 0;
      for (vpiHandle item : parent_->intern) {
	    switch (item->get_type_code()) {
		case vpiNet:
		case vpiReg:
		case vpiIntegerVar:
		case vpiBitVar:
		case vpiByteVar:
		case vpiShortIntVar:
		case vpiIntVar:
		case vpiLongIntVar:
		case vpiRealVar:
		case vpiStringVar:
		case vpiStructVar:
		case vpiEnumVar:
		  {
			const char*name = item->vpi_get_str(vpiName);
			if (name && strcmp(name, name_) == 0)
			      return item;
		  }
		  break;
		default:
		  break;
	    }
      }
      return 0;
}

vpiHandle vpiPortInfo::vpi_handle(int code)
{

      switch (code) {

	  case vpiHighConn:
	    return high_argc_ ? high_argv_[high_argc_-1] : 0;

	  case vpiLowConn:
	    return low_conn_();

          case vpiParent:
          case vpiScope:
          case vpiModule:
            return parent_;
          default :
            break;
      }

      return 0;
}

static vpiHandle portinfo_iterate(int code, vpiHandle ref)
{
      vpiPortInfo*rfp = dynamic_cast<vpiPortInfo*>(ref);
      assert(rfp);
      unsigned width = rfp->get_width();

      switch (code) {
	  case vpiBit: {
	    vpiHandle*args = static_cast<vpiHandle*>(calloc(width, sizeof(vpiHandle*)));

	    for (unsigned i = 0; i<rfp->port_bits_.size(); i++) {
		  args[i] = rfp->port_bits_[i];
	    }

	    return vpip_make_iterator(width, args, true);
	  }
      }
      return 0;
}

vpiHandle vpiPortInfo::vpi_iterate(int code)
{
      return portinfo_iterate(code, this);
}


vpiPortBitInfo::vpiPortBitInfo(vpiPortInfo *parent,
                               unsigned bit) :
      parent_(parent),
      bit_(bit)
{
}

vpiPortBitInfo::~vpiPortBitInfo()
{
}

#ifdef CHECK_WITH_VALGRIND
void port_bit_delete(__vpiHandle *handle)
{
      delete dynamic_cast<vpiPortBitInfo *>(handle);
}
#endif

vpiHandle vpiPortBitInfo::vpi_handle(int code)
{

      switch (code) {
          case vpiParent:
            return parent_;
          default :
            break;
      }

      return 0;
}

int vpiPortBitInfo::vpi_get(int code)
{
      switch( code ) {
        case vpiBit :
          return bit_;
        default :
          break;
      }

      return 0;
}

/* Port info is meta-data to allow vpi queries of the port signature of modules for
 * code-generators etc.  There are no actual nets corresponding to instances of module ports
 * as elaboration directly connects nets connected through module ports.
 */
void compile_vpi_port_conn(long index, long flags, unsigned argc,
			   vpiHandle*argv)
{
      __vpiScope*scope = vpip_peek_current_scope();
      for (vpiHandle item : scope->intern) {
	    vpiPortInfo*port = dynamic_cast<vpiPortInfo*>(item);
	    if (!port || port->get_index() != (unsigned)index) continue;
	    if (flags & 1) {
		  port->high_argc_ = argc;
		  port->high_argv_ = argv;
		  return;
	    }
	    break;
      }
      free(argv);
}

void compile_port_info( unsigned index, int vpi_direction, int vpi_port_type, unsigned width, const char *name, char* buffer )
{
      vpiPortInfo* obj = new vpiPortInfo( vpip_peek_current_scope(),
                                          index, vpi_direction, vpi_port_type,
                                          width, name, buffer );
      vpip_attach_to_current_scope(obj);

	// Create vpiPortBit objects
      for (unsigned i=0; i<width; i++) {
	    vpiPortBitInfo* obj_bit = new vpiPortBitInfo(obj, i);
	    obj->add_port_bit(obj_bit);
	    vpip_attach_to_current_scope(obj_bit);
      }
}

static bool parse_evcd_range(const char *text, int&value)
{
      char *end = 0;
      long parsed;

      if (!text || !*text) return false;
      errno = 0;
      parsed = strtol(text, &end, 10);
      if (errno == ERANGE || end == text || *end ||
          parsed < INT_MIN || parsed > INT_MAX)
            return false;
      value = (int)parsed;
      return true;
}

#define EVCD_METADATA_MAX_RECORDS 4096U
#define EVCD_METADATA_MAX_BITS (4ULL * 1024ULL * 1024ULL)
static unsigned evcd_metadata_records;
static unsigned long long evcd_metadata_bits;

void vpip_reset_port_info_evcd_budget(void)
{
      evcd_metadata_records = 0;
      evcd_metadata_bits = 0;
}

void compile_port_info_evcd(unsigned port_index,
                            unsigned component_index,
                            unsigned width, char *name,
                            char *left_text, char *right_text,
                            unsigned fixture_width,
                            unsigned fixture_base,
                            unsigned fixture_connected,
                            char *fixture,
                            unsigned dut_width,
                            unsigned dut_connected,
                            char *dut)
{
      __vpiScope *scope = vpip_peek_current_scope();
      vpiPortInfo *port = 0;
      vpiPortComponentInfo *component = 0;
      int left = 0, right = 0;
      bool ranges_valid = parse_evcd_range(left_text, left) &&
                          parse_evcd_range(right_text, right);
      unsigned long long range_width = ranges_valid
            ? (unsigned long long)(left >= right
                  ? (long long)left-right : (long long)right-left) + 1
            : 0;

      for (std::vector<__vpiHandle*>::iterator cur = scope->intern.begin();
           cur != scope->intern.end(); ++cur) {
            vpiPortInfo *candidate = dynamic_cast<vpiPortInfo*>(*cur);
            if (candidate && candidate->get_index() == port_index) {
                  port = candidate;
                  break;
            }
      }

      if (!port || !width || width > 1024U*1024U ||
          fixture_width > 1024U*1024U || dut_width > 1024U*1024U ||
          fixture_connected > 1024U*1024U ||
          dut_connected > 1024U*1024U ||
          !name || !*name || !ranges_valid || range_width != width ||
          component_index != port->evcd_components_.size() ||
          component_index >= (unsigned)port->get_width() ||
          (!fixture_width &&
           (fixture_base || fixture_connected || fixture || dut_width ||
            dut_connected || dut)) ||
          (fixture_width &&
           (!fixture || !dut || !dut_width || dut_width != width ||
            fixture_base > fixture_width ||
            width > fixture_width-fixture_base))) {
            yyerror("invalid .port_info/evcd component metadata");
            compile_errors += 1;
            delete[] name;
            delete[] left_text;
            delete[] right_text;
            delete[] fixture;
            delete[] dut;
            return;
      }

      if (evcd_metadata_records >= EVCD_METADATA_MAX_RECORDS ||
          width > EVCD_METADATA_MAX_BITS-evcd_metadata_bits) {
            yyerror(".port_info/evcd metadata exceeds the safe aggregate record/width budget");
            compile_errors += 1;
            delete[] name;
            delete[] left_text;
            delete[] right_text;
            delete[] fixture;
            delete[] dut;
            return;
      }

      component = new vpiPortComponentInfo;
      component->index = component_index;
      component->width = width;
      component->name = name;
      component->left = left;
      component->right = right;
      component->fixture_width = fixture_width;
      component->fixture_base = fixture_base;
      component->fixture_drivers = fixture_connected;
      component->dut_width = dut_width;
      component->dut_drivers = dut_connected;
      if (fixture_width) {
            functor_ref_lookup(&component->fixture_ref, fixture);
            functor_ref_lookup(&component->dut_ref, dut);
      }
      port->add_evcd_component(component);
      evcd_metadata_records += 1;
      evcd_metadata_bits += width;
      delete[] left_text;
      delete[] right_text;
}

extern "C" int vpip_get_port_component(vpiHandle ref, unsigned idx,
                                        const char **name, unsigned *width,
                                        int *left, int *right,
                                        vpiHandle *fixture,
                                        unsigned *fixture_base,
                                        int *fixture_connected,
                                        vpiHandle *dut,
                                        int *dut_connected)
{
      vpiPortInfo *port = dynamic_cast<vpiPortInfo*>(ref);
      vpiPortComponentInfo *component;
      __vpiScope *scope;

      if (!port || idx >= port->evcd_components_.size()) return 0;
      component = port->evcd_components_[idx];
      scope = dynamic_cast<__vpiScope*>(port->vpi_handle(vpiScope));
      assert(scope);

      if (component->fixture_ref && !component->fixture_handle) {
            vvp_signal_value *value = vvp_fil_signal_value(component->fixture_ref->fil);
            if (value && value->value_size())
                  component->fixture_handle = vpip_make_net4(
                        scope, "$ivl_evcd_fixture",
                        (int)value->value_size()-1, 0, false,
                        component->fixture_ref);
      }
      if (component->dut_ref && !component->dut_handle) {
            vvp_signal_value *value = vvp_fil_signal_value(component->dut_ref->fil);
            if (value && value->value_size())
                  component->dut_handle = vpip_make_net4(
                        scope, "$ivl_evcd_dut",
                        (int)value->value_size()-1, 0, false,
                        component->dut_ref);
      }

      if (name) *name = component->name;
      if (width) *width = component->width;
      if (left) *left = component->left;
      if (right) *right = component->right;
      if (fixture) *fixture = component->fixture_handle;
      if (fixture_base) *fixture_base = component->fixture_base;
      if (fixture_connected)
            *fixture_connected = component->fixture_ref &&
                                 !component->fixture_handle ? -1 :
                                 (int)component->fixture_drivers;
      if (dut) *dut = component->dut_handle;
      if (dut_connected)
            *dut_connected = component->dut_ref && !component->dut_handle
                           ? -1 : (int)component->dut_drivers;
      return 1;
}
