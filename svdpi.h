#ifndef SVDPI_H
#define SVDPI_H
/*
 * Copyright (c) 2026 Stephen Williams (steve@icarus.com)
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

/*
 * DPI (Direct Programming Interface) open-array surface.
 * Implements IEEE 1800-2017 Annex H.10.
 */

#include <stdint.h>
#include <stddef.h>

#if defined(__MINGW32__) || defined (__CYGWIN__)
#  define SVDPI_EXPORT __declspec(dllexport)
#else
#  define SVDPI_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/* Basic 2-state and 4-state scalar types  (IEEE 1800-2017 §H.7)      */
/* ------------------------------------------------------------------ */

typedef unsigned char  svBit;    /* 0 or 1 */
typedef unsigned char  svLogic;  /* 0=0, 1=1, 2=X, 3=Z */
typedef uint8_t        svByte;
typedef uint16_t       svShortInt;
typedef int32_t        svInt;
typedef int64_t        svLongInt;

/* Canonical 4-state bit constants */
#define sv_0  ((svLogic)0)
#define sv_1  ((svLogic)1)
#define sv_x  ((svLogic)2)
#define sv_z  ((svLogic)3)

/* ------------------------------------------------------------------ */
/* Packed bit-vector chunk types (IEEE 1800-2017 §H.8)                */
/* ------------------------------------------------------------------ */

typedef uint32_t svBitVec32;

typedef struct {
      svBitVec32 aval;   /* 0/1 value bits */
      svBitVec32 bval;   /* X/Z control bits */
} svLogicVec32;

/* Packed bit-array accessor helpers */
#define svGetBitselBit(s, i)    (((s)[(i)/32] >> ((i)%32)) & 1u)
#define svPutBitselBit(s, i, v) \
      ((s)[(i)/32] = ((s)[(i)/32] & ~(1u<<((i)%32))) | (((v)&1u)<<((i)%32)))

#define svGetBitselLogic(s, i)  \
      ((svLogic)((((s)[(i)/32].aval >> ((i)%32)) & 1u) | \
                 ((((s)[(i)/32].bval >> ((i)%32)) & 1u) << 1)))

/* ------------------------------------------------------------------ */
/* Open-array handle  (IEEE 1800-2017 §H.10)                          */
/* ------------------------------------------------------------------ */

/* Opaque handle; the simulator creates it before calling a DPI       */
/* function that has open-array formal parameters.                    */
typedef void* svOpenArrayHandle;

/* ------------------------------------------------------------------ */
/* Scope handle  (IEEE 1800-2017 §H.10.1)                             */
/* ------------------------------------------------------------------ */

typedef void* svScope;

/* ------------------------------------------------------------------ */
/* chandle (opaque C pointer passed through SV)                        */
/* ------------------------------------------------------------------ */

typedef void* chandle;

/* ================================================================== */
/* Open-array API functions (IEEE 1800-2017 §H.10.3)                  */
/* ================================================================== */

/* Total size in bytes of the packed element storage area */
extern SVDPI_EXPORT int svSizeOfArray(const svOpenArrayHandle h);

/* Pointer to the first element of the packed storage area */
extern SVDPI_EXPORT void* svGetArrayPtr(const svOpenArrayHandle h);

/* Number of unpacked dimensions */
extern SVDPI_EXPORT int svDimensions(const svOpenArrayHandle h);

/* Element count of unpacked dimension dim (1-based) */
extern SVDPI_EXPORT int svSize(const svOpenArrayHandle h, int dim);

/* Low index of unpacked dimension dim (min of left, right) */
extern SVDPI_EXPORT int svLow(const svOpenArrayHandle h, int dim);

/* High index of unpacked dimension dim (max of left, right) */
extern SVDPI_EXPORT int svHigh(const svOpenArrayHandle h, int dim);

/* Left (first declared) index of unpacked dimension dim */
extern SVDPI_EXPORT int svLeft(const svOpenArrayHandle h, int dim);

/* Right (last declared) index of unpacked dimension dim */
extern SVDPI_EXPORT int svRight(const svOpenArrayHandle h, int dim);

/* Increment direction: +1 (ascending) or -1 (descending) */
extern SVDPI_EXPORT int svIncrement(const svOpenArrayHandle h, int dim);

/* Element pointer: 1-D index */
extern SVDPI_EXPORT void* svGetArrElemPtr1(const svOpenArrayHandle h,
                                            int i1);
/* Element pointer: 2-D index */
extern SVDPI_EXPORT void* svGetArrElemPtr2(const svOpenArrayHandle h,
                                            int i1, int i2);
/* Element pointer: 3-D index */
extern SVDPI_EXPORT void* svGetArrElemPtr3(const svOpenArrayHandle h,
                                            int i1, int i2, int i3);

/* Element pointer: N-D index array (length must equal svDimensions(h)) */
extern SVDPI_EXPORT void* svGetArrElemPtr(const svOpenArrayHandle h,
                                           const int* indices);

/* ================================================================== */
/* Scope API functions (IEEE 1800-2017 §H.10.1)                       */
/* ================================================================== */

extern SVDPI_EXPORT svScope svGetScope(void);
extern SVDPI_EXPORT svScope svSetScope(const svScope scope);
extern SVDPI_EXPORT const char* svGetNameFromScope(const svScope scope);
extern SVDPI_EXPORT svScope svGetScopeFromName(const char* pathname);
extern SVDPI_EXPORT int svPutUserData(const svScope scope,
                                       void* userKey, void* userData);
extern SVDPI_EXPORT void* svGetUserData(const svScope scope,
                                         void* userKey);

/* ================================================================== */
/* Icarus-specific extensions (not part of IEEE standard)             */
/* These allow C-side code to construct an svOpenArrayHandle over a   */
/* plain C array for unit-testing the API functions.                  */
/* ================================================================== */

/*
 * Create a new svOpenArrayHandle over C array 'data'.
 * elem_bytes: sizeof each element.
 * ndims: number of unpacked dimensions (max 4).
 * Remaining arguments are pairs (left, right) for each dimension,
 * in dimension order (dim 1 first).
 * The caller is responsible for ensuring 'data' lives at least as
 * long as the handle.
 */
extern SVDPI_EXPORT svOpenArrayHandle svdpi_new_array(void* data,
                                                       size_t elem_bytes,
                                                       unsigned ndims, ...);

/* Release a handle created by svdpi_new_array. */
extern SVDPI_EXPORT void svdpi_free_array(svOpenArrayHandle h);

#ifdef __cplusplus
}
#endif

#endif /* SVDPI_H */
