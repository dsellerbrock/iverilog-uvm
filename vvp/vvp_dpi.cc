/*
 * DPI (Direct Programming Interface) library loading and symbol lookup
 * for Icarus Verilog VVP runtime.
 */
# include  "config.h"
# include  "vvp_dpi.h"
# include  "ivl_dlfcn.h"
# include  <cstdio>
# include  <cstring>
# include  <vector>
# include  <map>
# include  <string>

using namespace std;

static vector<ivl_dll_t> dpi_libs;
static map<string,void*> dpi_sym_cache;

void vvp_dpi_load_lib(const char*path)
{
      ivl_dll_t dll = ivl_dlopen(path, true);
      if (dll == 0) {
	    fprintf(stderr, "DPI: failed to load '%s': %s\n", path, dlerror());
	    return;
      }
      dpi_libs.push_back(dll);
}

void* vvp_dpi_find_symbol(const char*name)
{
      auto it = dpi_sym_cache.find(name);
      if (it != dpi_sym_cache.end())
	    return it->second;

      for (ivl_dll_t dll : dpi_libs) {
	    void*sym = ivl_dlsym(dll, name);
	    if (sym) {
		  dpi_sym_cache[name] = sym;
		  return sym;
	    }
      }
      return 0;
}
