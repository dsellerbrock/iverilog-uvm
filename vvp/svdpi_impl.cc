/*
 * svdpi_impl.cc — DPI open-array runtime (IEEE 1800-2017 §H.10)
 *
 * Provides the C-linkage implementations of svSize, svLow, svHigh,
 * svIncrement, svDimensions, svGetArrElemPtr1/2/3, svGetArrayPtr,
 * svSizeOfArray, and the Icarus-specific svdpi_new_array / svdpi_free_array
 * extensions.  All symbols are exported via -rdynamic so DPI shared
 * libraries can resolve them at run time.
 */

# include  "config.h"
# include  <cstdarg>
# include  <cstdlib>
# include  <cstring>
# include  <cassert>

/* Pull in the public header so our definitions match the declarations. */
# include  "../svdpi.h"

/* ------------------------------------------------------------------ */
/* Internal array descriptor                                           */
/* ------------------------------------------------------------------ */

#define SVDPI_MAX_DIMS 4

struct sv_open_array_t {
      void*    data;              /* pointer to first element          */
      size_t   elem_bytes;        /* bytes per element                 */
      unsigned ndims;             /* number of unpacked dimensions     */
      int      left_[SVDPI_MAX_DIMS];  /* left declared bound per dim */
      int      right_[SVDPI_MAX_DIMS]; /* right declared bound per dim */
};

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */

static inline const sv_open_array_t* as_arr(const svOpenArrayHandle h)
{
      return reinterpret_cast<const sv_open_array_t*>(h);
}

/* Compute the flat (0-based) offset from a per-dimension normalised index.
 * norm[d] = (ascending ? idx - low : high - idx) for dimension d.
 * stride[0] is innermost (last dimension in declaration order). */
static size_t flat_offset(const sv_open_array_t* a, const int* idx)
{
      size_t offset = 0;
      size_t stride = 1;

      /* Iterate dimensions from last (innermost) to first. */
      for (int d = (int)a->ndims - 1; d >= 0; d--) {
            int lo = (a->left_[d] <= a->right_[d])
                     ? a->left_[d] : a->right_[d];
            int hi = (a->left_[d] <= a->right_[d])
                     ? a->right_[d] : a->left_[d];
            int asc = (a->left_[d] <= a->right_[d]);
            int norm = asc ? (idx[d] - lo) : (hi - idx[d]);
            if (norm < 0 || norm > (hi - lo)) return (size_t)-1; /* OOB */
            offset += (size_t)norm * stride;
            stride *= (size_t)(hi - lo + 1);
      }
      return offset;
}

/* ================================================================== */
/* Public IEEE 1800-2017 §H.10 API                                    */
/* ================================================================== */

extern "C" int svSizeOfArray(const svOpenArrayHandle h)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a) return 0;

      int total = 1;
      for (unsigned d = 0; d < a->ndims; d++) {
            int lo = (a->left_[d] <= a->right_[d])
                     ? a->left_[d] : a->right_[d];
            int hi = (a->left_[d] <= a->right_[d])
                     ? a->right_[d] : a->left_[d];
            total *= (hi - lo + 1);
      }
      return total * (int)a->elem_bytes;
}

extern "C" void* svGetArrayPtr(const svOpenArrayHandle h)
{
      const sv_open_array_t* a = as_arr(h);
      return a ? a->data : nullptr;
}

extern "C" int svDimensions(const svOpenArrayHandle h)
{
      const sv_open_array_t* a = as_arr(h);
      return a ? (int)a->ndims : 0;
}

extern "C" int svSize(const svOpenArrayHandle h, int dim)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a || dim < 1 || (unsigned)dim > a->ndims) return 0;
      int d = dim - 1;
      int lo = (a->left_[d] <= a->right_[d]) ? a->left_[d] : a->right_[d];
      int hi = (a->left_[d] <= a->right_[d]) ? a->right_[d] : a->left_[d];
      return hi - lo + 1;
}

extern "C" int svLow(const svOpenArrayHandle h, int dim)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a || dim < 1 || (unsigned)dim > a->ndims) return 0;
      int d = dim - 1;
      return (a->left_[d] <= a->right_[d]) ? a->left_[d] : a->right_[d];
}

extern "C" int svHigh(const svOpenArrayHandle h, int dim)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a || dim < 1 || (unsigned)dim > a->ndims) return 0;
      int d = dim - 1;
      return (a->left_[d] <= a->right_[d]) ? a->right_[d] : a->left_[d];
}

extern "C" int svLeft(const svOpenArrayHandle h, int dim)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a || dim < 1 || (unsigned)dim > a->ndims) return 0;
      return a->left_[dim - 1];
}

extern "C" int svRight(const svOpenArrayHandle h, int dim)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a || dim < 1 || (unsigned)dim > a->ndims) return 0;
      return a->right_[dim - 1];
}

extern "C" int svIncrement(const svOpenArrayHandle h, int dim)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a || dim < 1 || (unsigned)dim > a->ndims) return 0;
      int d = dim - 1;
      return (a->left_[d] <= a->right_[d]) ? 1 : -1;
}

extern "C" void* svGetArrElemPtr1(const svOpenArrayHandle h, int i1)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a || a->ndims != 1) return nullptr;
      int idx[1] = { i1 };
      size_t off = flat_offset(a, idx);
      if (off == (size_t)-1) return nullptr;
      return static_cast<char*>(a->data) + off * a->elem_bytes;
}

extern "C" void* svGetArrElemPtr2(const svOpenArrayHandle h, int i1, int i2)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a || a->ndims != 2) return nullptr;
      int idx[2] = { i1, i2 };
      size_t off = flat_offset(a, idx);
      if (off == (size_t)-1) return nullptr;
      return static_cast<char*>(a->data) + off * a->elem_bytes;
}

extern "C" void* svGetArrElemPtr3(const svOpenArrayHandle h,
                                   int i1, int i2, int i3)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a || a->ndims != 3) return nullptr;
      int idx[3] = { i1, i2, i3 };
      size_t off = flat_offset(a, idx);
      if (off == (size_t)-1) return nullptr;
      return static_cast<char*>(a->data) + off * a->elem_bytes;
}

extern "C" void* svGetArrElemPtr(const svOpenArrayHandle h, const int* indices)
{
      const sv_open_array_t* a = as_arr(h);
      if (!a || !indices) return nullptr;
      size_t off = flat_offset(a, indices);
      if (off == (size_t)-1) return nullptr;
      return static_cast<char*>(a->data) + off * a->elem_bytes;
}

/* ================================================================== */
/* Scope stubs  (IEEE 1800-2017 §H.10.1)                              */
/* ================================================================== */

static svScope current_scope_ = nullptr;

extern "C" svScope svGetScope(void)        { return current_scope_; }
extern "C" svScope svSetScope(const svScope s)
{
      svScope old = current_scope_;
      current_scope_ = const_cast<svScope>(s);
      return old;
}
extern "C" const char* svGetNameFromScope(const svScope /*scope*/)
{
      return nullptr;
}
extern "C" svScope svGetScopeFromName(const char* /*pathname*/)
{
      return nullptr;
}
extern "C" int svPutUserData(const svScope /*scope*/,
                              void* /*userKey*/, void* /*userData*/)
{
      return 0;
}
extern "C" void* svGetUserData(const svScope /*scope*/, void* /*userKey*/)
{
      return nullptr;
}

/* ================================================================== */
/* Icarus-specific extensions                                          */
/* ================================================================== */

extern "C" svOpenArrayHandle svdpi_new_array(void* data,
                                              size_t elem_bytes,
                                              unsigned ndims, ...)
{
      if (ndims == 0 || ndims > SVDPI_MAX_DIMS) return nullptr;

      sv_open_array_t* a = new sv_open_array_t;
      a->data       = data;
      a->elem_bytes = elem_bytes;
      a->ndims      = ndims;

      va_list ap;
      va_start(ap, ndims);
      for (unsigned d = 0; d < ndims; d++) {
            a->left_[d]  = va_arg(ap, int);
            a->right_[d] = va_arg(ap, int);
      }
      va_end(ap);

      return static_cast<svOpenArrayHandle>(a);
}

extern "C" void svdpi_free_array(svOpenArrayHandle h)
{
      delete static_cast<sv_open_array_t*>(h);
}
