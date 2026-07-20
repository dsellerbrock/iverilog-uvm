#ifndef IVL_svdpi_H
#define IVL_svdpi_H
/*
 * svdpi.h — SystemVerilog DPI (IEEE1800-2017 Annex H) subset for
 * Icarus Verilog. Covers the scalar type mappings and the
 * one-dimensional open-array accessors implemented by the vvp
 * runtime. Symbols resolve from the vvp executable when the DPI
 * library is loaded with `vvp -d libfoo.so`.
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Canonical scalar types (H.7.4). */
typedef uint8_t svScalar;
typedef svScalar svBit;
typedef svScalar svLogic;

/* Scalar values (H.7.4). */
#define sv_0 0
#define sv_1 1
#define sv_z 2
#define sv_x 3

/* chandle maps to a 64-bit integer on the SV side of this
 * implementation. */
typedef void* svOpenArrayHandle;

/* Canonical vector representations (H.7.5/H.7.6). A packed array of
 * svBitVecVal is 2-state (one word per 32 bits); svLogicVecVal adds a
 * b (control) word for the Z/X state. */
typedef uint32_t svBitVecVal;
typedef struct t_vpi_vecval svLogicVecVal;

/* Scope handle (H.9). A svScope is an opaque handle to a SystemVerilog
 * instance scope; in this implementation it is a vpiHandle for the
 * scope object. */
typedef void* svScope;

/* Return the active scope: the scope of the imported "context" DPI task
 * or function currently on the C call stack, or the last scope set with
 * svSetScope. */
extern svScope svGetScope(void);

/* Set the active scope, returning the previous one. */
extern svScope svSetScope(svScope scope);

/* Look up a scope by its full hierarchical name (e.g. "top.u1"), or a
 * package scope by name. Returns 0 if not found. */
extern svScope svGetScopeFromName(const char* scopeName);

/* The local (leaf) and full hierarchical names of a scope. */
extern const char* svGetNameFromScope(svScope scope);
extern const char* svGetFullNameFromScope(const svScope scope);

/* Open-array queries (H.12.2). This implementation marshals
 * one-dimensional, zero-based open arrays of 2-state atom types
 * (byte/shortint/int/longint, signed or unsigned) and real. */
extern int  svDimensions(const void*h);
extern int  svSize(const void*h, int dim);      /* dim is 1 */
extern int  svLow(const void*h, int dim);       /* always 0 */
extern int  svHigh(const void*h, int dim);      /* svSize-1 */
extern int  svLeft(const void*h, int dim);
extern int  svRight(const void*h, int dim);
extern int  svIncrement(const void*h, int dim);
extern int  svSizeOfArray(const void*h);        /* total bytes */

/* Element access (H.12.3): returns a pointer directly into
 * simulation storage — writes are immediately visible to the
 * SystemVerilog side. */
extern void* svGetArrElemPtr(const void*h, int indx1, ...);
extern void* svGetArrElemPtr1(const void*h, int indx1);
extern void* svGetArrElemPtr2(const void*h, int indx1, int indx2);
extern void* svGetArrElemPtr3(const void*h, int indx1, int indx2, int indx3);
extern void* svGetArrayPtr(const void*h);

#ifdef __cplusplus
}
#endif

#endif /* IVL_svdpi_H */
