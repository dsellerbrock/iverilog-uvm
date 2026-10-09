/*
 * Copyright (c) 2001-2013 Stephen Williams (steve@icarus.com)
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

# include  "symbols.h"
# include  <cstring>
# include  <cstdlib>
# include  <cassert>

/*
 * The keys of the symbol table are null terminated strings. Keep them
 * in a string buffer, with the strings separated by a single null,
 * for compact use of memory. This also makes it easy to delete the
 * entire lot of keys, simply by deleting the heaps.
 *
 * The key_strdup() function below allocates the strings from this
 * buffer, possibly making a new buffer if needed.
 */
struct key_strings {
      struct key_strings*next;
      char data[64*1024 - sizeof(struct key_strings*)];
};

char*symbol_table_s::key_strdup_(const char*str)
{
      unsigned len = strlen(str);
      assert( (len+1) <= sizeof str_chunk->data );

      if ( (len+1) > (sizeof str_chunk->data - str_used) ) {
	    key_strings*tmp = new key_strings;
	    tmp->next = str_chunk;
	    str_chunk = tmp;
	    str_used = 0;
      }

      char*res = str_chunk->data + str_used;
      str_used += len + 1;
      strcpy(res, str);
      return res;
}

/*
 * This is a B-Tree data structure, where there are nodes and
 * leaves.
 *
 * Nodes have a bunch of pointers to children. Each child pointer has
 * associated with it a key that is the largest key referenced by that
 * child. So, if the key being searched for has a value <= the first
 * key of a node, then the value is in the first child.
 *
 * leaves have a sorted table of key-value pairs. The search can use a
 * simple binary search to find an item. Each key represents an item.
 */

/*
 * The table is an open-addressed hash table from the key strings to
 * their values. Lookups vastly outnumber insertions while a design loads,
 * and nothing needs the keys in order.
 */
static size_t symbol_key_hash_(const char*key)
{
	// FNV-1a
      size_t hash = static_cast<size_t>(14695981039346656037ULL);
      for (const unsigned char*cp = reinterpret_cast<const unsigned char*>(key)
		 ; *cp ; cp += 1) {
	    hash ^= *cp;
	    hash *= static_cast<size_t>(1099511628211ULL);
      }
      return hash;
}

symbol_table_s::symbol_table_s()
{
      table_size_ = 64;
      table_used_ = 0;
      table_ = new entry_s[table_size_];
      for (size_t idx = 0 ; idx < table_size_ ; idx += 1)
	    table_[idx].key = 0;

      str_chunk = new key_strings;
      str_chunk->next = 0;
      str_used = 0;
}

/*
 * Return the slot that holds KEY, or the empty slot where it belongs.
 */
symbol_table_s::entry_s* symbol_table_s::find_slot_(const char*key, size_t hash)
{
      size_t mask = table_size_ - 1;
      size_t idx = hash & mask;
      while (table_[idx].key && (table_[idx].hash != hash
				 || strcmp(table_[idx].key, key) != 0))
	    idx = (idx + 1) & mask;
      return table_ + idx;
}

void symbol_table_s::grow_()
{
      entry_s*old_table = table_;
      size_t old_size = table_size_;

      table_size_ = 2 * old_size;
      table_ = new entry_s[table_size_];
      for (size_t idx = 0 ; idx < table_size_ ; idx += 1)
	    table_[idx].key = 0;

      for (size_t idx = 0 ; idx < old_size ; idx += 1) {
	    if (old_table[idx].key == 0)
		  continue;
	    *find_slot_(old_table[idx].key, old_table[idx].hash) = old_table[idx];
      }
      delete[]old_table;
}

void symbol_table_s::sym_set_value(const char*key, symbol_value_t val)
{
      size_t hash = symbol_key_hash_(key);
      entry_s*slot = find_slot_(key, hash);
      if (slot->key == 0) {
	    slot->key = key_strdup_(key);
	    slot->hash = hash;
	    table_used_ += 1;
	    slot->val = val;
	      /* Keep the table at most half full. */
	    if (2 * table_used_ > table_size_)
		  grow_();
	    return;
      }
      slot->val = val;
}

symbol_value_t symbol_table_s::sym_get_value(const char*key)
{
      size_t hash = symbol_key_hash_(key);
      entry_s*slot = find_slot_(key, hash);
      if (slot->key)
	    return slot->val;

	/* Create the missing key with a zero value, as the table always
	   has, and return that value. */
      symbol_value_t def;
      def.ptr = 0;
      slot->key = key_strdup_(key);
      slot->hash = hash;
      slot->val = def;
      table_used_ += 1;
      if (2 * table_used_ > table_size_)
	    grow_();
      return def;
}

symbol_table_s::~symbol_table_s()
{
      delete[]table_;
      while (str_chunk) {
	    key_strings*tmp = str_chunk;
	    str_chunk = tmp->next;
	    delete tmp;
      }
}
