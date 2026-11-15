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

# include  "config.h"
# include  "compiler.h"
# include  "parse_api.h"
# include  "parse_misc.h"
# include  <algorithm>
# include  <cctype>
# include  <iostream>
# include  <list>
# include  <map>
# include  <vector>
# include  <sys/stat.h>
# include  <unistd.h>

using namespace std;

bool lexor_libmap_mode = false;
bool libmap_sources_parsed = false;

/* 33.3.1.1: an explicit file name beats a wildcarded file name, which
   beats a directory. */
enum spec_class_t { SPEC_FILE = 0, SPEC_WILDCARD = 1, SPEC_DIRECTORY = 2 };

struct path_spec_t {
      perm_string library;
      vector<string> segments;  // absolute path, one entry per directory level
      spec_class_t spec_class;
};

struct include_t {
      string path;
      string where;
      list<perm_string>::iterator position;
};

static vector<path_spec_t> path_specs;
/* Libraries in declaration order. An include statement holds its place
   with a nil entry until the included file has been read (33.3.2: as
   though the included contents appear in place of the include). */
static list<perm_string> declared;
static list<perm_string>::iterator declare_at = declared.end();
static list<include_t> pending_includes;
static vector<perm_string> command_line_order;
static string map_directory;
static int map_errors = 0;

static perm_string work_library()
{
      return lex_strings.make("work");
}

static bool is_absolute(const string&path)
{
      return path[0] == '/'
	  || (isalpha((unsigned char)path[0]) && path[1] == ':');
}

static string current_directory()
{
      char buf[4096];
      return getcwd(buf, sizeof buf)? buf : ".";
}

/*
 * Split a path into its levels, as an absolute path with `.' and `..'
 * resolved by name (links are not followed). A relative path starts at DIR.
 */
static vector<string> split_path(string path, const string&dir)
{
#ifdef __MINGW32__
      replace(path.begin(), path.end(), '\\', '/');
#endif
      if (path.empty() || !is_absolute(path))
	    path = dir + "/" + path;

      vector<string> res;
      for (size_t pos = 0 ; pos <= path.size() ; ) {
	    size_t end = path.find('/', pos);
	    if (end == string::npos) end = path.size();
	    string level = path.substr(pos, end-pos);
	    pos = end + 1;
	    if (level.empty() || level == ".")
		  continue;
	    if (level == "..") {
		  if (!res.empty()) res.pop_back();
		  continue;
	    }
	    res.push_back(level);
      }
      return res;
}

static string join_path(const vector<string>&levels)
{
      string res;
      for (const string&level : levels) {
	    if (!(res.empty() && is_absolute(level)))
		  res += "/";
	    res += level;
      }
      return res.empty()? "/" : res;
}

/* `?' matches one character and `*' any number, within one level. */
static bool match_level(const char*pat, const char*str)
{
      if (*pat == 0)
	    return *str == 0;
      if (*pat == '*')
	    return match_level(pat+1, str) || (*str && match_level(pat, str+1));
      return *str && (*pat == '?' || *pat == *str)
	  && match_level(pat+1, str+1);
}

/* `...' matches any number of directory levels, including none. */
static bool match_path(const vector<string>&pat, size_t pidx,
		       const vector<string>&file, size_t fidx)
{
      if (pidx == pat.size())
	    return fidx == file.size();
      if (pat[pidx] == "...") {
	    for (size_t skip = fidx ; skip <= file.size() ; skip += 1)
		  if (match_path(pat, pidx+1, file, skip))
			return true;
	    return false;
      }
      return fidx < file.size()
	  && match_level(pat[pidx].c_str(), file[fidx].c_str())
	  && match_path(pat, pidx+1, file, fidx+1);
}

static void map_error(const string&where, const string&msg)
{
      cerr << where << ": error: " << msg << endl;
      map_errors += 1;
}

/* Split a statement at white space and commas. A quoted path is one word. */
static vector<string> statement_words(const string&text)
{
      vector<string> res;
      for (size_t pos = 0 ; pos < text.size() ; ) {
	    char ch = text[pos];
	    if (isspace((unsigned char)ch) || ch == ',') {
		  pos += 1;
		  continue;
	    }
	    size_t end;
	    if (ch == '"') {
		  end = text.find('"', pos+1);
		  if (end == string::npos) end = text.size();
		  res.push_back(text.substr(pos+1, end-pos-1));
		  pos = end + 1;
		  continue;
	    }
	    for (end = pos ; end < text.size() ; end += 1)
		  if (isspace((unsigned char)text[end]) || text[end] == ',')
			break;
	    res.push_back(text.substr(pos, end-pos));
	    pos = end;
      }
      return res;
}

void libmap_statement(const struct vlltype&loc, bool is_include,
		      const string&text)
{
      vector<string> words = statement_words(text);
      string where = loc.get_fileline();

      if (is_include) {
	    if (words.size() != 1) {
		  map_error(where, "an include statement names one library "
			    "map file.");
		  return;
	    }
	    include_t inc;
	    inc.path = join_path(split_path(words[0], map_directory));
	    inc.where = where;
	    inc.position = declared.insert(declare_at, perm_string());
	    pending_includes.push_back(inc);
	    return;
      }

      if (words.size() < 2 || words[1] == "-incdir") {
	    map_error(where, "a library declaration needs a library name and "
		      "a file path.");
	    return;
      }

      perm_string library = lex_strings.make(words[0].c_str());
      if (find(declared.begin(), declared.end(), library) == declared.end())
	    declared.insert(declare_at, library);

      for (size_t idx = 1 ; idx < words.size() ; idx += 1) {
	    const string&word = words[idx];
	    if (word == "-incdir") {
		    /* Syntax 33-2 allows -incdir, but the source files are
		       preprocessed before the map is read. */
		  map_error(where, "sorry: -incdir in a library declaration "
			    "is not supported; use the -I command line flag.");
		  return;
	    }
	    path_spec_t spec;
	    spec.library = library;
	    spec.segments = split_path(word, map_directory);
	    if (word.empty()) {
		  map_error(where, "empty file path in a library declaration.");
		  return;
	    }
	    if (word[word.size()-1] == '/'
		|| (!spec.segments.empty() && spec.segments.back() == "...")) {
		    // A path that ends in / includes all the files of the directory.
		  spec.segments.push_back("*");
		  spec.spec_class = SPEC_DIRECTORY;
	    } else if (spec.segments.back().find_first_of("*?") != string::npos) {
		  spec.spec_class = SPEC_WILDCARD;
	    } else {
		  spec.spec_class = SPEC_FILE;
	    }
	    path_specs.push_back(spec);
      }
}

static void load_file(const string&path, const string&where, unsigned depth)
{
      if (depth > 32) {
	    map_error(where, "library map files include each other: " + path);
	    return;
      }

      string save_directory = map_directory;
      vector<string> levels = split_path(path, current_directory());
      if (!levels.empty()) levels.pop_back();
      map_directory = join_path(levels);

      lexor_libmap_mode = true;
      map_errors += pform_parse(path.c_str());
      lexor_libmap_mode = false;

      list<include_t> includes;
      includes.swap(pending_includes);
      list<perm_string>::iterator save_at = declare_at;
      for (const include_t&inc : includes) {
	    declare_at = inc.position;
	    load_file(inc.path, inc.where, depth+1);
	    declared.erase(inc.position);
      }
      declare_at = save_at;
      map_directory = save_directory;
}

int libmap_load(const char*path)
{
      map_errors = 0;
      load_file(path, path, 0);
      return map_errors;
}

void libmap_search(const char*name)
{
      command_line_order.push_back(lex_strings.make(name));
}

/*
 * The search order (33.6.1, 33.8.1): the -L libraries, then the libraries
 * in the order the map files declare them. A `work' that no map file
 * declares comes before the declared libraries, as the modules of the
 * command line source files come before the -y libraries.
 */
static const vector<perm_string>& search_order()
{
      static vector<perm_string> order;
      if (!order.empty())
	    return order;

      perm_string work = work_library();
      bool work_declared
	    = find(declared.begin(), declared.end(), work) != declared.end();
      auto add = [&](perm_string library) {
	    if (find(order.begin(), order.end(), library) == order.end())
		  order.push_back(library);
      };

      for (perm_string library : command_line_order) {
	    if (library == work
		|| find(declared.begin(), declared.end(), library) != declared.end()) {
		  add(library);
		  continue;
	    }
	      /* Not a library: -L also names VPI module directories. */
	    struct stat sb;
	    if (!path_specs.empty()
		&& !(stat(library.str(), &sb) == 0 && S_ISDIR(sb.st_mode)))
		  cerr << "warning: -L " << library << " is neither a library "
		       << "declared in a library map file nor a directory."
		       << endl;
      }
      if (!work_declared)
	    add(work);
      for (perm_string library : declared)
	    add(library);
      return order;
}

bool libmap_before(perm_string a, perm_string b)
{
      for (perm_string library : search_order()) {
	    if (library == a) return true;
	    if (library == b) return false;
      }
      return false;
}

perm_string libmap_file_library(const char*file)
{
      perm_string work = work_library();
      if (path_specs.empty() || file == 0)
	    return work;

      search_order();  // reports a -L that names no library, once
      static map<string,perm_string> cache;
      map<string,perm_string>::const_iterator cur = cache.find(file);
      if (cur != cache.end())
	    return cur->second;

      vector<string> levels = split_path(file, current_directory());
      perm_string library = work;
      perm_string conflict;
      int best = SPEC_DIRECTORY + 1;
      for (const path_spec_t&spec : path_specs) {
	    if (spec.spec_class > best)
		  continue;
	    if (!match_path(spec.segments, 0, levels, 0))
		  continue;
	    if (spec.spec_class < best) {
		  best = spec.spec_class;
		  library = spec.library;
		  conflict = perm_string();
	    } else if (spec.library != library) {
		  conflict = spec.library;
	    }
      }

      if (!conflict.nil()) {
	    cerr << file << ": error: source file matches the path "
		 << "specifications of libraries `" << library << "' and `"
		 << conflict << "'." << endl;
	    error_count += 1;
      }

      cache[file] = library;
      return library;
}

perm_string libmap_cell_key(perm_string library, perm_string cell)
{
      string key = string(library.str()) + "." + cell.str();
      return lex_strings.make(key.c_str());
}
