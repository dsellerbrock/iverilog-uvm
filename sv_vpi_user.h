#ifndef SV_VPI_USER_H
#define SV_VPI_USER_H
/*
 * Copyright (c) 2010-2021 Stephen Williams (steve@icarus.com)
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

# include  "vpi_user.h"

#if defined(__MINGW32__) || defined (__CYGWIN__)
#  define DLLEXPORT __declspec(dllexport)
#else
#  define DLLEXPORT
#endif

#ifdef __cplusplus
# define EXTERN_C_START extern "C" {
# define EXTERN_C_END }
#else
# define EXTERN_C_START
# define EXTERN_C_END
#endif

#ifndef __GNUC__
# undef  __attribute__
# define __attribute__(x)
#endif

EXTERN_C_START

/********* OBJECT TYPES ***********/
#define vpiPackage          600
#define vpiInterface        601
#define vpiProgram          602
#define vpiModport          603
#define vpiCovergroup       605
#define vpiArrayType        606
#define   vpiStaticArray      1
#define   vpiDynamicArray     2
#define   vpiAssocArray       3
#define   vpiQueueArray       4
#define vpiLongIntVar       610
#define vpiShortIntVar      611
#define vpiIntVar           612
#define vpiByteVar          614
#define vpiLogicVar         vpiReg
#define vpiClassVar         615
#define vpiStringVar        616
#define vpiBitVar           620
#define vpiArrayVar         vpiRegArray

/********* TYPESPECS *************/
#define vpiClassTypespec    630
#define vpiEnumTypespec     633
#define vpiEnumConst        634

#define vpiClassDefn        652

/********* One-to-One ***********/
#define vpiBaseTypespec     703

/********* Many-to-One ***********/
#define vpiMember           742

/********* One-to-One and One-to-Many ***********/
#define vpiInstance         745

/********* Assertion object (IEEE 1800-2017 clause 40) ***********/
#define vpiAssertion        686

/* Assertion callback reasons (IEEE 1800-2017 40.x). cbAssertionSuccess
   and cbAssertionFailure are delivered; the others are accepted by
   vpi_register_assertion_cb but not yet delivered. */
#define cbAssertionStart        606
#define cbAssertionSuccess      607
#define cbAssertionFailure      608
#define cbAssertionStepSuccess  609
#define cbAssertionStepFailure  610
#define cbAssertionDisable      611
#define cbAssertionEnable       612
#define cbAssertionReset        613
#define cbAssertionKill         614

/* Attempt information passed to an assertion callback. The step detail
   is not modeled; failExpr is 0 and attemptStartTime carries the
   current simulation time. */
typedef struct t_vpi_assertion_step_info {
      PLI_INT32 matched_expression_count;
      vpiHandle *matched_exprs;
      PLI_INT32 stateFrom;
      PLI_INT32 stateTo;
} s_vpi_assertion_step_info, *p_vpi_assertion_step_info;

typedef struct t_vpi_attempt_info {
      union {
            vpiHandle failExpr;
            p_vpi_assertion_step_info step;
      } detail;
      s_vpi_time attemptStartTime;
} s_vpi_attempt_info, *p_vpi_attempt_info;

/********* generic object properties ***********/
#define vpiNullConst         11

/********* task/function properties **********/
#define vpiOtherFunc          6

/* Icarus-specific function type to use string as the return type */
#define vpiStringFunc       10
#define vpiSysFuncString    vpiSysFuncString

EXTERN_C_END

#endif /* SV_VPI_USER_H */
