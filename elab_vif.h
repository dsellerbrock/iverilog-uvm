#ifndef IVL_elab_vif_H
#define IVL_elab_vif_H
/*
 * Copyright (c) 2026 Icarus Verilog contributors
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 */

# include <vector>
# include "pform_types.h"

class Design;
class LineInfo;
class NetESFunc;
class NetExpr;
class NetFuncDef;
class NetScope;
class netclass_t;

/* Resolve the declaration signature and concrete run-time candidates for an
 * interface function. A declaration-only signature may be returned when the
 * design contains no concrete interface instance; it is never included in
 * candidates. */
extern const NetFuncDef* resolve_interface_function_signature(
		Design*des, NetScope*caller_scope,
		const netclass_t*interface_type, perm_string method_name,
		std::vector<NetScope*>*candidates,
		bool&recognized, bool&hard_error);

/* Build the receiver/key/argument-row payload used by the VVP target for a
 * function call through a virtual interface. If recognized is true, this
 * function consumes receiver whether it succeeds or reports an error. */
extern NetESFunc* elaborate_dynamic_interface_function_call(
		const LineInfo&loc, Design*des, NetScope*caller_scope,
		const netclass_t*interface_type, perm_string method_name,
		NetExpr*receiver, const std::vector<named_pexpr_t>&parms,
		bool&recognized, bool&hard_error);

#endif
