/*
 * Copyright (c) 2012-2026 Stephen Williams (steve@icarus.com)
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

# include  "class_type.h"
# include  "config.h"
# include  <algorithm>
# include  <cerrno>
# include  <cinttypes>
# include  <climits>
# include  <cstdio>
# include  <cstring>
# include  <fstream>
# include  <iomanip>
# include  <iterator>
# include  <limits>
# include  <map>
# include  <set>
# include  <sstream>
# include  <string>
# include  <utility>
# include  <vector>
#if defined(_WIN32)
# ifndef NOMINMAX
#  define NOMINMAX
# endif
# include  <windows.h>
# include  <process.h>
#else
# include  <unistd.h>
#endif

using namespace std;

static bool covgrp_db_safe_byte_(unsigned char ch)
{
      return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
            || (ch >= '0' && ch <= '9') || ch == '_' || ch == '.'
            || ch == '$' || ch == '[' || ch == ']' || ch == ':';
}

static string covgrp_db_encode_(const string&input)
{
      static const char hex[] = "0123456789ABCDEF";
      string output;
      for (unsigned char ch : input) {
            if (covgrp_db_safe_byte_(ch)) {
                  output.push_back(static_cast<char>(ch));
            } else {
                  output.push_back('%');
                  output.push_back(hex[ch >> 4]);
                  output.push_back(hex[ch & 15]);
            }
      }
      return output;
}

static int covgrp_db_hex_value_(char ch)
{
      if (ch >= '0' && ch <= '9') return ch - '0';
      if (ch >= 'a' && ch <= 'f') return ch - 'a' + 10;
      if (ch >= 'A' && ch <= 'F') return ch - 'A' + 10;
      return -1;
}

static bool covgrp_db_decode_(const string&input, string&output)
{
      output.clear();
      for (size_t idx = 0; idx < input.size(); idx += 1) {
            unsigned char ch = static_cast<unsigned char>(input[idx]);
            if (ch == '%') {
                  if (idx + 2 >= input.size()) return false;
                  int hi = covgrp_db_hex_value_(input[idx + 1]);
                  int lo = covgrp_db_hex_value_(input[idx + 2]);
                  if (hi < 0 || lo < 0) return false;
                  ch = static_cast<unsigned char>((hi << 4) | lo);
                  idx += 2;
                  if (ch == 0) return false;
            } else if (!covgrp_db_safe_byte_(ch)) {
                  return false;
            }
            output.push_back(static_cast<char>(ch));
      }
      return true;
}

static uint64_t covgrp_db_fnv1a_(const string&text)
{
      uint64_t value = UINT64_C(14695981039346656037);
      for (unsigned char ch : text) {
            value ^= ch;
            value *= UINT64_C(1099511628211);
      }
      return value;
}

static string covgrp_db_hex64_(uint64_t value)
{
      ostringstream output;
      output << hex << nouppercase << setw(16) << setfill('0') << value;
      return output.str();
}

static bool covgrp_db_parse_u64_(const string&text, uint64_t&value)
{
      if (text.empty()) return false;
      value = 0;
      for (char ch : text) {
            if (ch < '0' || ch > '9') return false;
            unsigned digit = static_cast<unsigned>(ch - '0');
            if (value > (UINT64_MAX - digit) / 10) return false;
            value = value * 10 + digit;
      }
      return true;
}

static string covgrp_db_u128_(unsigned __int128 value)
{
      string output;
      do {
            output.push_back(static_cast<char>('0' + value % 10));
            value /= 10;
      } while (value != 0);
      reverse(output.begin(), output.end());
      return output;
}

static bool covgrp_db_parse_u128_(const string&text, unsigned __int128&value)
{
      if (text.empty()) return false;
      const unsigned __int128 max_value = ~(unsigned __int128)0;
      value = 0;
      for (char ch : text) {
            if (ch < '0' || ch > '9') return false;
            unsigned digit = static_cast<unsigned>(ch - '0');
            if (value > (max_value - digit) / 10) return false;
            value = value * 10 + digit;
      }
      return true;
}

static unsigned long covgrp_db_pid_()
{
#if defined(_WIN32)
      return static_cast<unsigned long>(GetCurrentProcessId());
#else
      return static_cast<unsigned long>(getpid());
#endif
}

static bool covgrp_db_replace_(const string&source, const string&target)
{
#if defined(_WIN32)
      return MoveFileExA(source.c_str(), target.c_str(),
                         MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
#else
      return rename(source.c_str(), target.c_str()) == 0;
#endif
}

std::string class_type::covgrp_fingerprint_() const
{
      string canonical;
      auto put_string = [&canonical](const string&value) {
	    canonical += to_string(value.size());
	    canonical.push_back(':');
	    canonical += value;
	    canonical.push_back(';');
      };
      auto put_uint = [&canonical](uint64_t value) {
	    canonical += to_string(value);
	    canonical.push_back(';');
      };
      put_string("iverilog-covgrp-db-fingerprint-v1");
      put_string(dispatch_prefix_);
      put_string(scope_path_);
      put_string(class_name_);

      put_uint(covgrp_items_.size());
      for (const cov_item_t&item : covgrp_items_) {
	    put_string(item.name);
	    put_uint(item.is_cross ? 1 : 0);
      }

      put_uint(covgrp_bins_.size());
      for (const cov_bin_t&bin : covgrp_bins_) {
	    put_uint(bin.cp_idx);
	    put_uint(bin.prop_idx);
	    put_uint(bin.lo);
	    put_uint(bin.hi);
	    put_uint(bin.kind);
	    put_uint(bin.tuple);
	    put_uint(bin.item_idx);
	    put_uint(bin.trans_repeat);
	    put_uint(bin.trans_min);
	    put_uint(bin.trans_max);
	    put_uint(bin.trans_alt);
	    put_uint(bin.trans_alt_count);
	    put_uint(bin.trans_family);
	    put_uint(bin.trans_base);
	    put_uint(bin.guard_idx);
	    put_string(bin.prop_idx == COV_NO_PROP
		       ? string() : property_name(bin.prop_idx));
      }

      put_uint(covgrp_dyn_bins_.size());
      for (const cov_dyn_bin_t&bin : covgrp_dyn_bins_) {
	    put_uint(bin.cp_idx);
	    put_uint(bin.item_idx);
	    put_uint(bin.kind);
	    put_uint(bin.family);
	    put_uint(bin.array_size);
	    put_string(bin.name);
	    put_string(bin.lo_ir);
	    put_string(bin.hi_ir);
	    put_uint(bin.value_width);
	    put_uint(bin.value_signed ? 1 : 0);
	    put_uint(bin.guard_idx);
	    put_uint(bin.trans_seq);
	    put_uint(bin.trans_term);
	    put_uint(bin.trans_repeat);
	    put_uint(bin.trans_min);
	    put_uint(bin.trans_max);
      }

      put_uint(covgrp_crosses_.size());
      for (const cov_cross_t&cross : covgrp_crosses_) {
	    put_uint(cross.family);
	    put_uint(cross.item_idx);
	    put_uint(cross.n_dims);
	    put_uint(cross.retain_auto ? 1 : 0);
      }
      put_uint(covgrp_cross_terms_.size());
      for (const cov_cross_term_t&term : covgrp_cross_terms_) {
	    put_uint(term.family);
	    put_uint(term.dim);
	    put_uint(term.term_idx);
	    put_uint(term.kind);
	    put_uint(term.source_id);
	    put_uint(term.source_aux);
      }
      put_uint(covgrp_cross_bins_.size());
      for (const cov_cross_bin_t&bin : covgrp_cross_bins_) {
	    put_uint(bin.family);
	    put_uint(bin.kind);
	    put_uint(bin.target);
	    put_string(bin.name);
	    put_string(bin.select_ir);
      }
      put_uint(covgrp_real_cps_.size());
      for (bool is_real : covgrp_real_cps_)
	    put_uint(is_real ? 1 : 0);

      return covgrp_db_hex64_(covgrp_db_fnv1a_(canonical));
}

bool class_type::covgrp_db_save(const string&path, string&err)
{
      if (path.empty()) {
	    err = "empty database name";
	    return false;
      }

      string body = "IVL_COVDB 1\n";
      uint64_t body_lines = 1;
      auto add_line = [&body, &body_lines](const string&line) {
	    body += line;
	    body.push_back('\n');
	    body_lines += 1;
      };

      for (const class_type*ct : covgrp_registry_) {
	    if (!ct->covgrp_options_.merge_instances) {
		  err = "covergroup " + ct->dispatch_prefix_
			+ " uses merge_instances=0; cumulative database save unsupported";
		  return false;
	    }
	    set<unsigned> dyn_families, cross_families, trans_families;
	    set<unsigned> static_trans_families;
	    for (const cov_dyn_bin_t&bin : ct->covgrp_dyn_bins_) {
		  if ((bin.kind & 7) == 4) trans_families.insert(bin.family);
		  else dyn_families.insert(bin.family);
	    }
	    for (const cov_cross_t&cross : ct->covgrp_crosses_)
		  cross_families.insert(cross.family);
	    for (const cov_bin_t&bin : ct->covgrp_bins_)
		  if ((bin.kind & 7) == 4 && bin.trans_family != COV_NO_FAMILY)
			static_trans_families.insert(bin.trans_family);
	    for (unsigned family : static_trans_families)
		  if (dyn_families.count(family) || trans_families.count(family)) {
			err = "covergroup " + ct->dispatch_prefix_
			      + " reuses a static transition family id for dynamic bins";
			return false;
		  }
	    for (unsigned family : static_trans_families)
		  if (cross_families.count(family)) {
			err = "covergroup " + ct->dispatch_prefix_
			      + " reuses a static transition family id for a cross";
			return false;
		  }
	    for (unsigned family : cross_families)
		  if (dyn_families.count(family) || trans_families.count(family)) {
			err = "covergroup " + ct->dispatch_prefix_
			      + " reuses a cross family id for dynamic bins";
			return false;
		  }

	    auto dyn_meta = [ct](unsigned family) -> const cov_dyn_bin_t* {
		  for (const cov_dyn_bin_t&bin : ct->covgrp_dyn_bins_)
			if (bin.family == family) return &bin;
		  return 0;
	    };

	    ostringstream header;
	    header << "type " << covgrp_db_encode_(ct->dispatch_prefix_)
		   << " fp " << ct->covgrp_fingerprint_()
		   << " merge_instances "
		   << (ct->covgrp_options_.merge_instances ? 1 : 0);
	    add_line(header.str());

	    set<unsigned> props;
	    for (const cov_bin_t&bin : ct->covgrp_bins_)
		  if (bin.prop_idx != COV_NO_PROP)
			props.insert(bin.prop_idx);
	    for (unsigned prop : props) {
		  uint32_t count = ct->type_count(prop);
		  if (count == 0) continue;
		  ostringstream record;
		  record << "prop " << covgrp_db_encode_(ct->property_name(prop))
			 << ' ' << count;
		  add_line(record.str());
	    }

	    for (const auto&entry : ct->covgrp_dyn_type_ranges_) {
		  const cov_dyn_bin_t*meta = dyn_meta(entry.first);
		  if (!meta || !dyn_families.count(entry.first) || meta->array_size != 0) {
			err = "covergroup " + ct->dispatch_prefix_
			      + " has ranges for a non-unsized dynamic family";
			return false;
		  }
		  for (const auto&range : entry.second) {
			ostringstream record;
			record << "range " << entry.first << ' '
			       << range.first << ' ' << range.second;
			add_line(record.str());
		  }
	    }
	    for (const auto&entry : ct->covgrp_dyn_type_totals_) {
		  if (cross_families.count(entry.first)
		      || trans_families.count(entry.first)) continue;
		  const cov_dyn_bin_t*meta = dyn_meta(entry.first);
		  if (!meta || !dyn_families.count(entry.first)) {
			err = "covergroup " + ct->dispatch_prefix_
			      + " has a total for an unknown dynamic family";
			return false;
		  }
		  if (meta->array_size == 0 || entry.second == 0) continue;
		  ostringstream record;
		  record << "total " << entry.first << ' '
			 << covgrp_db_u128_(entry.second);
		  add_line(record.str());
	    }
	    for (const auto&entry : ct->covgrp_dyn_type_counts_) {
		  unsigned family = entry.first.first;
		  uint64_t bin = entry.first.second;
		  uint32_t count = entry.second;
		  if (cross_families.count(family)
		      || trans_families.count(family)) continue;
		  if (static_trans_families.count(family)) {
			if (count != 0) {
			      ostringstream record;
			      record << "sord " << family << ' ' << bin << ' ' << count;
			      add_line(record.str());
			}
			continue;
		  }
		  if (!dyn_families.count(family)) {
			if (count != 0) {
			      err = "covergroup " + ct->dispatch_prefix_
				    + " has a counter for an unknown dynamic family";
			      return false;
			}
			continue;
		  }
		  if (count == 0) continue;
		  ostringstream record;
		  record << "dyn " << family << ' ' << bin << ' ' << count;
		  add_line(record.str());
	    }
	    for (unsigned family : cross_families) {
		  auto found = ct->covgrp_cross_type_.find(family);
		  if (found != ct->covgrp_cross_type_.end()) {
			for (const auto&entry : found->second.bins) {
			      ostringstream record;
			      record << "cross " << family << ' '
				     << entry.first.size();
			      for (const auto&term : entry.first)
				    record << ' ' << term.first << ':' << term.second;
			      record << ' ' << ct->dyn_type_count(family, entry.second);
			      add_line(record.str());
			}
			vector<string> names;
			for (unsigned prop : found->second.named_props)
			      names.push_back(ct->property_name(prop));
			sort(names.begin(), names.end());
			for (const string&name : names) {
			      ostringstream record;
			      record << "cross_named " << family << ' '
				     << covgrp_db_encode_(name);
			      add_line(record.str());
			}
		  }
	    }
	    for (unsigned family : trans_families) {
		  auto found = ct->covgrp_trans_type_bins_.find(family);
		  if (found == ct->covgrp_trans_type_bins_.end()) continue;
		  for (const auto&entry : found->second) {
			ostringstream record;
			record << "trans " << family << ' ' << entry.first.size();
			for (uint64_t value : entry.first) record << ' ' << value;
			record << ' ' << ct->dyn_type_count(family, entry.second);
			add_line(record.str());
		  }
	    }
      }

      ostringstream end;
      end << "END " << body_lines << ' '
	  << covgrp_db_hex64_(covgrp_db_fnv1a_(body)) << '\n';
      string contents = body + end.str();
      string temporary = path + ".tmp." + to_string(covgrp_db_pid_());
      errno = 0;
      ofstream output(temporary.c_str(), ios::out | ios::binary | ios::trunc);
      if (!output) {
	    int saved_errno = errno ? errno : EIO;
	    err = strerror(saved_errno);
	    return false;
      }
      output.write(contents.data(), static_cast<streamsize>(contents.size()));
      output.flush();
      bool write_ok = static_cast<bool>(output);
      output.close();
      write_ok = write_ok && !output.fail();
      if (!write_ok) {
	    int saved_errno = errno ? errno : EIO;
	    remove(temporary.c_str());
	    err = strerror(saved_errno);
	    return false;
      }

      errno = 0;
      if (!covgrp_db_replace_(temporary, path)) {
	    int saved_errno = errno ? errno : EIO;
	    remove(temporary.c_str());
	    err = strerror(saved_errno);
	    return false;
      }
      return true;
}

bool class_type::covgrp_db_load(const string&path, string&err, bool&missing)
{
      missing = false;
      errno = 0;
      ifstream input(path.c_str(), ios::in | ios::binary);
      if (!input) {
	    int saved_errno = errno ? errno : EIO;
	    missing = saved_errno == ENOENT;
	    err = strerror(saved_errno);
	    return false;
      }

      string contents((istreambuf_iterator<char>(input)),
		      istreambuf_iterator<char>());
      if (input.bad()) {
	    err = "failed while reading database";
	    return false;
      }
      if (contents.find('\0') != string::npos) {
	    err = "database contains NUL bytes";
	    return false;
      }
      if (contents.find('\r') != string::npos) {
	    err = "database must use LF line endings";
	    return false;
      }
      if (contents.size() < 2 || contents.back() != '\n') {
	    err = "database is truncated or lacks final newline";
	    return false;
      }

      size_t end_start = contents.rfind('\n', contents.size() - 2);
      if (end_start == string::npos) {
	    err = "database is missing END record";
	    return false;
      }
      end_start += 1;
      string body = contents.substr(0, end_start);
      string end_line = contents.substr(end_start,
					contents.size() - end_start - 1);
      if (body.compare(0, 12, "IVL_COVDB 1\n") != 0) {
	    err = "wrong database magic or version";
	    return false;
      }

      istringstream end_stream(end_line);
      string end_tag, line_count_text, checksum, extra;
      if (!(end_stream >> end_tag >> line_count_text >> checksum)
	  || (end_stream >> extra) || end_tag != "END") {
	    err = "malformed END record";
	    return false;
      }
      uint64_t recorded_lines = 0;
      if (!covgrp_db_parse_u64_(line_count_text, recorded_lines)
	  || recorded_lines != static_cast<uint64_t>(
		count(body.begin(), body.end(), '\n'))) {
	    err = "END record line count mismatch";
	    return false;
      }
      if (checksum != covgrp_db_hex64_(covgrp_db_fnv1a_(body))) {
	    err = "database checksum mismatch";
	    return false;
      }

      struct staged_type_t {
	    const class_type*type;
	    map<unsigned, uint32_t> props;
	    map<unsigned, unsigned __int128> totals;
	    map<unsigned, vector<pair<uint64_t,uint64_t>>> ranges;
	    map<pair<unsigned,uint64_t>, uint32_t> dyn_counts;
	    map<unsigned, map<vector<pair<unsigned,uint64_t>>,uint32_t>> cross_bins;
	    map<unsigned, set<unsigned>> cross_named;
	    map<unsigned, map<vector<uint64_t>,uint32_t>> trans_bins;
	    map<pair<unsigned,uint64_t>, uint32_t> static_trans_counts;
      };
      auto find_dyn_meta = [](const class_type*ct, unsigned family)
	    -> const cov_dyn_bin_t* {
	    for (const cov_dyn_bin_t&bin : ct->covgrp_dyn_bins_)
		  if (bin.family == family) return &bin;
	    return 0;
      };
      auto is_cross_family = [](const class_type*ct, unsigned family) {
	    for (const cov_cross_t&cross : ct->covgrp_crosses_)
		  if (cross.family == family) return true;
	    return false;
      };
      auto is_static_trans_family = [](const class_type*ct, unsigned family) {
	    for (const cov_bin_t&bin : ct->covgrp_bins_)
		  if ((bin.kind & 7) == 4 && bin.trans_family != COV_NO_FAMILY
		      && bin.trans_family == family) return true;
	    return false;
      };
      map<const class_type*,
	  map<unsigned, map<pair<unsigned,unsigned>, const cov_cross_term_t*>>>
	    cross_terms;
      for (const class_type*ct : covgrp_registry_)
	    for (const cov_cross_term_t&term : ct->covgrp_cross_terms_)
		  cross_terms[ct][term.family][make_pair(term.dim, term.term_idx)] = &term;
      auto find_cross_term = [&cross_terms](const class_type*ct,
	    unsigned family, unsigned dim, unsigned term_idx)
	    -> const cov_cross_term_t* {
	    auto type = cross_terms.find(ct);
	    if (type == cross_terms.end()) return 0;
	    auto family_terms = type->second.find(family);
	    if (family_terms == type->second.end()) return 0;
	    auto term = family_terms->second.find(make_pair(dim, term_idx));
	    return term == family_terms->second.end() ? 0 : term->second;
      };
      vector<staged_type_t> staged;
      map<string, size_t> staged_by_prefix;
      size_t current_type = numeric_limits<size_t>::max();
      istringstream body_stream(body);
      string line;
      size_t line_number = 0;
      while (getline(body_stream, line)) {
	    line_number += 1;
	    if (line_number == 1) continue;
	    if (line.empty()) {
		  err = "line " + to_string(line_number) + ": empty record";
		  return false;
	    }
	    istringstream record(line);
	    string tag;
	    record >> tag;
	    if (tag == "type") {
		  string encoded_prefix, fp_tag, fingerprint;
		  string merge_tag, merge_text, trailing;
		  if (!(record >> encoded_prefix >> fp_tag >> fingerprint
			>> merge_tag >> merge_text) || (record >> trailing)
		      || fp_tag != "fp" || merge_tag != "merge_instances") {
			err = "line " + to_string(line_number) + ": malformed type record";
			return false;
		  }
		  string prefix;
		  if (!covgrp_db_decode_(encoded_prefix, prefix)) {
			err = "line " + to_string(line_number) + ": invalid encoded type name";
			return false;
		  }
		  if (staged_by_prefix.find(prefix) != staged_by_prefix.end()) {
			err = "line " + to_string(line_number) + ": duplicate type record";
			return false;
		  }
		  const class_type*ct = 0;
		  for (const class_type*candidate : covgrp_registry_)
			if (candidate->dispatch_prefix_ == prefix) {
			      ct = candidate;
			      break;
			}
		  if (!ct) {
			err = "line " + to_string(line_number)
			      + ": type is not present in the current design";
			return false;
		  }
		  if (ct->covgrp_fingerprint_() != fingerprint) {
			err = "line " + to_string(line_number) + ": covergroup fingerprint mismatch";
			return false;
		  }
		  uint64_t file_merge = 0;
		  if (!covgrp_db_parse_u64_(merge_text, file_merge) || file_merge > 1
		      || file_merge != (ct->covgrp_options_.merge_instances ? 1u : 0u)) {
			err = "line " + to_string(line_number) + ": merge_instances mismatch";
			return false;
		  }
		  if (!ct->covgrp_options_.merge_instances) {
			err = "covergroup " + prefix
			      + " uses merge_instances=0; cumulative database load unsupported";
			return false;
		  }
		  for (const cov_bin_t&bin : ct->covgrp_bins_) {
			if ((bin.kind & 7) != 4 || bin.trans_family == COV_NO_FAMILY)
			      continue;
			if (find_dyn_meta(ct, bin.trans_family)) {
			      err = "covergroup " + prefix
				    + " reuses a static transition family id for dynamic bins";
			      return false;
			}
		  }
		  current_type = staged.size();
		  staged_by_prefix.insert(make_pair(prefix, current_type));
		  staged_type_t entry;
		  entry.type = ct;
		  staged.push_back(entry);
	    } else if (tag == "prop") {
		  string encoded_name, count_text, trailing;
		  if (!(record >> encoded_name >> count_text) || (record >> trailing)
		      || current_type == numeric_limits<size_t>::max()) {
			err = "line " + to_string(line_number) + ": malformed prop record";
			return false;
		  }
		  string name;
		  if (!covgrp_db_decode_(encoded_name, name)) {
			err = "line " + to_string(line_number) + ": invalid encoded property name";
			return false;
		  }
		  uint64_t parsed_count = 0;
		  if (!covgrp_db_parse_u64_(count_text, parsed_count)
		      || parsed_count == 0 || parsed_count > UINT32_MAX) {
			err = "line " + to_string(line_number) + ": invalid counter value";
			return false;
		  }
		  const class_type*ct = staged[current_type].type;
		  unsigned property = COV_NO_PROP;
		  for (const cov_bin_t&bin : ct->covgrp_bins_) {
			if (bin.prop_idx == COV_NO_PROP
			    || ct->property_name(bin.prop_idx) != name)
			      continue;
			if (property != COV_NO_PROP && property != bin.prop_idx) {
			      err = "line " + to_string(line_number)
				    + ": property name is ambiguous";
			      return false;
			}
			property = bin.prop_idx;
		  }
		  if (property == COV_NO_PROP) {
			err = "line " + to_string(line_number)
			      + ": property is not a coverage counter";
			return false;
		  }
		  if (!staged[current_type].props.insert(make_pair(
			  property, static_cast<uint32_t>(parsed_count))).second) {
			err = "line " + to_string(line_number) + ": duplicate property record";
			return false;
		  }
	    } else if (tag == "range") {
		  string family_text, lo_text, hi_text, trailing;
		  if (!(record >> family_text >> lo_text >> hi_text) || (record >> trailing)
		      || current_type == numeric_limits<size_t>::max()) {
			err = "line " + to_string(line_number) + ": malformed range record";
			return false;
		  }
		  uint64_t family64 = 0, lo = 0, hi = 0;
		  if (!covgrp_db_parse_u64_(family_text, family64) || family64 > UINT_MAX
		      || !covgrp_db_parse_u64_(lo_text, lo)
		      || !covgrp_db_parse_u64_(hi_text, hi) || hi < lo) {
			err = "line " + to_string(line_number) + ": invalid range";
			return false;
		  }
		  unsigned family = static_cast<unsigned>(family64);
		  const class_type*ct = staged[current_type].type;
		  const cov_dyn_bin_t*meta = find_dyn_meta(ct, family);
		  if (!meta || meta->array_size != 0 || (meta->kind & 7) == 4) {
			err = "line " + to_string(line_number)
			      + ": range family is not an unsized value family";
			return false;
		  }
	  auto&ranges = staged[current_type].ranges[family];
	  if (!ranges.empty()) {
			uint64_t prev_hi = ranges.back().second;
			if (prev_hi == UINT64_MAX || lo <= prev_hi + 1) {
			      err = "line " + to_string(line_number)
				    + ": ranges overlap, touch, or are out of order";
			      return false;
			}
	  }
	  ranges.push_back(make_pair(lo, hi));
	    } else if (tag == "total") {
		  string family_text, total_text, trailing;
		  if (!(record >> family_text >> total_text) || (record >> trailing)
		      || current_type == numeric_limits<size_t>::max()) {
			err = "line " + to_string(line_number) + ": malformed total record";
			return false;
		  }
		  uint64_t family64 = 0;
		  unsigned __int128 total = 0;
		  if (!covgrp_db_parse_u64_(family_text, family64) || family64 > UINT_MAX
		      || !covgrp_db_parse_u128_(total_text, total) || total == 0) {
			err = "line " + to_string(line_number) + ": invalid total";
			return false;
		  }
		  unsigned family = static_cast<unsigned>(family64);
		  const class_type*ct = staged[current_type].type;
		  const cov_dyn_bin_t*meta = find_dyn_meta(ct, family);
		  if (!meta || meta->array_size == 0 || (meta->kind & 7) == 4
		      || is_cross_family(ct, family)
		      || total > (unsigned __int128)meta->array_size
		      || (meta->array_size == UINT64_MAX && total != 1)) {
			err = "line " + to_string(line_number)
			      + ": total family or value is invalid";
			return false;
		  }
		  if (!staged[current_type].totals.insert(make_pair(family, total)).second) {
			err = "line " + to_string(line_number) + ": duplicate total family";
			return false;
		  }
	    } else if (tag == "dyn") {
		  string family_text, key_text, count_text, trailing;
		  if (!(record >> family_text >> key_text >> count_text) || (record >> trailing)
		      || current_type == numeric_limits<size_t>::max()) {
			err = "line " + to_string(line_number) + ": malformed dyn record";
			return false;
		  }
		  uint64_t family64 = 0, key = 0, parsed_count = 0;
		  if (!covgrp_db_parse_u64_(family_text, family64) || family64 > UINT_MAX
		      || !covgrp_db_parse_u64_(key_text, key)
		      || !covgrp_db_parse_u64_(count_text, parsed_count)
		      || parsed_count == 0 || parsed_count > UINT32_MAX) {
			err = "line " + to_string(line_number) + ": invalid dyn counter";
			return false;
		  }
		  unsigned family = static_cast<unsigned>(family64);
		  const class_type*ct = staged[current_type].type;
		  const cov_dyn_bin_t*meta = find_dyn_meta(ct, family);
		  if (!meta || (meta->kind & 7) == 4 || is_cross_family(ct, family)
		      || (meta->array_size != 0 && key >= meta->array_size)) {
			err = "line " + to_string(line_number)
			      + ": dyn family or key is invalid";
			return false;
		  }
		  if (!staged[current_type].dyn_counts.insert(make_pair(
			  make_pair(family, key), static_cast<uint32_t>(parsed_count))).second) {
			err = "line " + to_string(line_number) + ": duplicate dyn key";
			return false;
		  }
	    } else if (tag == "sord") {
		  string family_text, ordinal_text, count_text, trailing;
		  if (!(record >> family_text >> ordinal_text >> count_text) || (record >> trailing)
		      || current_type == numeric_limits<size_t>::max()) {
			err = "line " + to_string(line_number) + ": malformed sord record";
			return false;
		  }
		  uint64_t family64 = 0, ordinal = 0, parsed_count = 0;
		  if (!covgrp_db_parse_u64_(family_text, family64) || family64 > UINT_MAX
		      || !covgrp_db_parse_u64_(ordinal_text, ordinal)
		      || !covgrp_db_parse_u64_(count_text, parsed_count)
		      || parsed_count == 0 || parsed_count > UINT32_MAX) {
			err = "line " + to_string(line_number) + ": invalid sord counter";
			return false;
		  }
		  unsigned family = static_cast<unsigned>(family64);
		  const class_type*ct = staged[current_type].type;
		  uint64_t total = ct->covgrp_trans_family_size(family);
		  if (!is_static_trans_family(ct, family) || find_dyn_meta(ct, family)
		      || (total != UINT64_MAX && ordinal >= total)) {
			err = "line " + to_string(line_number)
			      + ": sord family or ordinal is invalid";
			return false;
		  }
		  if (!staged[current_type].static_trans_counts.insert(make_pair(
			  make_pair(family, ordinal), static_cast<uint32_t>(parsed_count))).second) {
			err = "line " + to_string(line_number) + ": duplicate sord key";
			return false;
		  }
	    } else if (tag == "cross") {
		  string family_text, n_text;
		  if (!(record >> family_text >> n_text)
		      || current_type == numeric_limits<size_t>::max()) {
			err = "line " + to_string(line_number) + ": malformed cross record";
			return false;
		  }
		  uint64_t family64 = 0, n64 = 0;
		  if (!covgrp_db_parse_u64_(family_text, family64) || family64 > UINT_MAX
		      || !covgrp_db_parse_u64_(n_text, n64)) {
			err = "line " + to_string(line_number) + ": invalid cross key";
			return false;
		  }
		  unsigned family = static_cast<unsigned>(family64);
		  const class_type*ct = staged[current_type].type;
		  const cov_cross_t*meta = 0;
		  for (const cov_cross_t&cross : ct->covgrp_crosses_)
			if (cross.family == family) { meta = &cross; break; }
		  if (!meta || n64 != meta->n_dims) {
			err = "line " + to_string(line_number)
			      + ": cross family or dimension count is invalid";
			return false;
		  }
		  vector<pair<unsigned,uint64_t>> name;
		  for (uint64_t idx = 0; idx < n64; idx += 1) {
			string pair_text;
			if (!(record >> pair_text)) {
			      err = "line " + to_string(line_number) + ": truncated cross key";
			      return false;
			}
			size_t colon = pair_text.find(':');
			if (colon == string::npos || pair_text.find(':', colon + 1) != string::npos) {
			      err = "line " + to_string(line_number) + ": malformed cross term key";
			      return false;
			}
			uint64_t term64 = 0, logical = 0;
			if (!covgrp_db_parse_u64_(pair_text.substr(0, colon), term64)
			    || term64 > UINT_MAX
			    || !covgrp_db_parse_u64_(pair_text.substr(colon + 1), logical)) {
			      err = "line " + to_string(line_number) + ": invalid cross term key";
			      return false;
			}
			if (!find_cross_term(ct, family, static_cast<unsigned>(idx),
				     static_cast<unsigned>(term64))) {
			      err = "line " + to_string(line_number)
				    + ": cross term does not match metadata";
			      return false;
			}
			name.push_back(make_pair(static_cast<unsigned>(term64), logical));
		  }
		  string count_text, trailing;
		  uint64_t parsed_count = 0;
		  if (!(record >> count_text) || (record >> trailing)
		      || !covgrp_db_parse_u64_(count_text, parsed_count)
		      || parsed_count > UINT32_MAX) {
			err = "line " + to_string(line_number) + ": invalid cross count";
			return false;
		  }
		  if (!staged[current_type].cross_bins[family].insert(make_pair(
			  name, static_cast<uint32_t>(parsed_count))).second) {
			err = "line " + to_string(line_number) + ": duplicate cross key";
			return false;
		  }
	    } else if (tag == "cross_named") {
		  string family_text, encoded_name, trailing;
		  if (!(record >> family_text >> encoded_name) || (record >> trailing)
		      || current_type == numeric_limits<size_t>::max()) {
			err = "line " + to_string(line_number) + ": malformed cross_named record";
			return false;
		  }
		  uint64_t family64 = 0;
		  string name;
		  if (!covgrp_db_parse_u64_(family_text, family64) || family64 > UINT_MAX
		      || !covgrp_db_decode_(encoded_name, name)) {
			err = "line " + to_string(line_number) + ": invalid cross_named value";
			return false;
		  }
		  unsigned family = static_cast<unsigned>(family64);
		  const class_type*ct = staged[current_type].type;
		  if (!is_cross_family(ct, family)) {
			err = "line " + to_string(line_number) + ": cross_named family is unknown";
			return false;
		  }
		  unsigned prop = COV_NO_PROP;
		  for (const cov_cross_bin_t&bin : ct->covgrp_cross_bins_)
			if (bin.family == family && bin.target < ct->property_count()
			    && ct->property_name(bin.target) == name) {
			      if (prop != COV_NO_PROP && prop != bin.target) {
				    err = "line " + to_string(line_number)
					  + ": cross_named property is ambiguous";
				    return false;
			      }
			      prop = bin.target;
			}
		  if (prop == COV_NO_PROP) {
			err = "line " + to_string(line_number)
			      + ": cross_named property is not in the cross metadata";
			return false;
		  }
		  if (!staged[current_type].cross_named[family].insert(prop).second) {
			err = "line " + to_string(line_number) + ": duplicate cross_named property";
			return false;
		  }
	    } else if (tag == "trans") {
		  string family_text, n_text;
		  if (!(record >> family_text >> n_text)
		      || current_type == numeric_limits<size_t>::max()) {
			err = "line " + to_string(line_number) + ": malformed trans record";
			return false;
		  }
		  uint64_t family64 = 0, n64 = 0;
		  if (!covgrp_db_parse_u64_(family_text, family64) || family64 > UINT_MAX
		      || !covgrp_db_parse_u64_(n_text, n64) || n64 > 65536) {
			err = "line " + to_string(line_number) + ": invalid trans identity";
			return false;
		  }
		  unsigned family = static_cast<unsigned>(family64);
		  const class_type*ct = staged[current_type].type;
		  const cov_dyn_bin_t*meta = find_dyn_meta(ct, family);
		  if (!meta || (meta->kind & 7) != 4) {
			err = "line " + to_string(line_number) + ": trans family is not dynamic";
			return false;
		  }
		  vector<uint64_t> identity;
		  for (uint64_t idx = 0; idx < n64; idx += 1) {
			string value_text;
			uint64_t value = 0;
			if (!(record >> value_text) || !covgrp_db_parse_u64_(value_text, value)) {
			      err = "line " + to_string(line_number) + ": invalid trans value";
			      return false;
			}
			identity.push_back(value);
		  }
		  string count_text, trailing;
		  uint64_t parsed_count = 0;
		  if (!(record >> count_text) || (record >> trailing)
		      || !covgrp_db_parse_u64_(count_text, parsed_count)
		      || parsed_count > UINT32_MAX) {
			err = "line " + to_string(line_number) + ": invalid trans count";
			return false;
		  }
		  if (!staged[current_type].trans_bins[family].insert(make_pair(
			  identity, static_cast<uint32_t>(parsed_count))).second) {
			err = "line " + to_string(line_number) + ": duplicate trans identity";
			return false;
		  }
	    } else {
		  err = "line " + to_string(line_number) + ": unknown record";
		  return false;
	    }
      }

      auto range_contains = [](const vector<pair<uint64_t,uint64_t>>&ranges,
	    uint64_t value) {
	    auto after = upper_bound(ranges.begin(), ranges.end(), value,
		  [](uint64_t candidate,
		     const pair<uint64_t,uint64_t>&range) {
			return candidate < range.first;
		  });
	    if (after == ranges.begin()) return false;
	    --after;
	    return value <= after->second;
      };
      for (const staged_type_t&entry : staged) {
	    const class_type*ct = entry.type;
	    for (const auto&count : entry.dyn_counts) {
		  unsigned family = count.first.first;
		  uint64_t key = count.first.second;
		  const cov_dyn_bin_t*meta = find_dyn_meta(ct, family);
		  if (!meta) {
			err = "database contains a counter for an unknown dynamic family";
			return false;
		  }
		  if (meta->array_size == 0) {
			auto found = entry.ranges.find(family);
			if (found == entry.ranges.end()
			    || !range_contains(found->second, key)) {
			      err = "database has an unsized value outside its saved ranges";
			      return false;
			}
		  } else {
			auto total = entry.totals.find(family);
			if (total == entry.totals.end()
			    || (unsigned __int128)key >= total->second) {
			      err = "database has a sized index outside its saved total";
			      return false;
			}
		  }
	    }
	    set<unsigned> dyn_families, cross_families, trans_families;
	    set<unsigned> static_trans_families;
	    for (const cov_dyn_bin_t&bin : ct->covgrp_dyn_bins_) {
		  if ((bin.kind & 7) == 4) trans_families.insert(bin.family);
		  else dyn_families.insert(bin.family);
	    }
	    for (const cov_cross_t&cross : ct->covgrp_crosses_)
		  cross_families.insert(cross.family);
	    for (const cov_bin_t&bin : ct->covgrp_bins_)
		  if ((bin.kind & 7) == 4 && bin.trans_family != COV_NO_FAMILY)
			static_trans_families.insert(bin.trans_family);
	    for (unsigned family : static_trans_families)
		  if (dyn_families.count(family) || trans_families.count(family)
		      || cross_families.count(family)) {
			err = "database type has overlapping static and runtime family ids";
			return false;
		  }
	    for (unsigned family : cross_families)
		  if (dyn_families.count(family) || trans_families.count(family)) {
			err = "database type has overlapping cross and dynamic family ids";
			return false;
		  }
	    for (const auto&family : entry.cross_bins) {
		  for (const auto&bin : family.second) {
			for (size_t dim = 0; dim < bin.first.size(); dim += 1) {
			      unsigned term_idx = bin.first[dim].first;
			      uint64_t logical = bin.first[dim].second;
			      const cov_cross_term_t*term = find_cross_term(
				    ct, family.first, static_cast<unsigned>(dim), term_idx);
			      if (!term) {
				    err = "database cross key has no matching term metadata";
				    return false;
			      }
			      bool valid = false;
			      if (term->kind == 0 || term->kind == 2) {
				    valid = logical == 0;
			      } else if (term->kind == 1) {
				    const cov_dyn_bin_t*meta = find_dyn_meta(ct, term->source_id);
				    if (meta && (meta->kind & 7) == 0) {
					  if (meta->array_size == 0) {
						auto ranges = entry.ranges.find(term->source_id);
						valid = ranges != entry.ranges.end()
						      && range_contains(ranges->second, logical);
					  } else {
						auto total = entry.totals.find(term->source_id);
						valid = total != entry.totals.end()
						      && (unsigned __int128)logical < total->second;
					  }
				    }
			      } else if (term->kind == 3) {
				    valid = logical == term->source_aux
					  && logical < ct->covgrp_trans_family_size(
						term->source_id);
			      }
			      if (!valid) {
				    err = "database cross key has an invalid logical bin";
				    return false;
			      }
			}
		  }
	    }

      }

	  auto add_count = [](uint32_t&slot, uint32_t count) {
	    uint64_t sum = static_cast<uint64_t>(slot) + count;
	    slot = static_cast<uint32_t>(min<uint64_t>(sum, UINT32_MAX));
	  };
	  for (staged_type_t&entry : staged) {
	    class_type*ct = const_cast<class_type*>(entry.type);
	    for (const auto&prop : entry.props) {
		  if (ct->type_counts_.size() <= prop.first)
			ct->type_counts_.resize(static_cast<size_t>(prop.first) + 1, 0);
		  add_count(ct->type_counts_[prop.first], prop.second);
	    }
	    for (const auto&total : entry.totals)
		  ct->dyn_type_register_total(total.first, total.second);
	    for (const auto&ranges : entry.ranges)
		  ct->dyn_type_register_ranges(ranges.first, ranges.second);
	    for (const auto&count : entry.dyn_counts)
		  add_count(ct->covgrp_dyn_type_counts_[count.first], count.second);
	    for (const auto&count : entry.static_trans_counts)
		  add_count(ct->covgrp_dyn_type_counts_[count.first], count.second);
	    for (const auto&family : entry.cross_bins)
		  for (const auto&bin : family.second) {
			uint64_t id = ct->cross_type_register_bin(family.first,
							 bin.first);
			add_count(ct->covgrp_dyn_type_counts_[
				  make_pair(family.first, id)], bin.second);
		  }
	    for (const auto&family : entry.cross_named) {
		  vector<unsigned> props(family.second.begin(), family.second.end());
		  ct->cross_type_register_named(family.first, props);
	    }
	    for (const auto&family : entry.trans_bins)
		  for (const auto&bin : family.second) {
			uint64_t id = ct->trans_type_register_bin(family.first,
							  bin.first);
			add_count(ct->covgrp_dyn_type_counts_[
				  make_pair(family.first, id)], bin.second);
		  }
	    ct->covgrp_db_loaded_ = true;
	  }
      return true;
}
