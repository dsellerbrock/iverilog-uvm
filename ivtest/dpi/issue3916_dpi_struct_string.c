/* IEEE 1800-2017/2023 H.7.8 and H.8.10.1. */
#include <string.h>
#include "svdpi.h"

typedef struct {
      char tag;
      const char*text;
      double value;
} item_t;

static item_t*open_items(const svOpenArrayHandle h)
{
      item_t*a = svGetArrayPtr(h);
      if (!a || svDimensions(h) != 1 || svSize(h, 1) != 3
	  || svSizeOfArray(h) != 3 * sizeof(item_t))
	    return 0;
      for (int i = 0; i < 3; i += 1)
	    if (svGetArrElemPtr1(h, i) != &a[i])
		  return 0;
      return a;
}

static int matches(const item_t*item, char tag, const char*text, double value)
{
      return item->tag == tag && item->value == value
	  && item->text && strcmp(item->text, text) == 0;
}

int c_check_items(const svOpenArrayHandle h)
{
      const item_t*a = open_items(h);
      return a && matches(&a[0], 11, "first", 1.25)
	       && matches(&a[1], 22, "", 2.5)
	       && matches(&a[2], 33, "a longer string stored in the third element", 3.75);
}

int c_fill_items(const svOpenArrayHandle h)
{
      item_t*a = open_items(h);
      if (!a) return 0;
      a[0] = (item_t){41, "written by C", 4.5};
      a[1] = (item_t){42, "", 5.5};
      a[2] = (item_t){43, "last output", 6.5};
      return 1;
}

int c_rotate_items(const svOpenArrayHandle h)
{
      item_t*a = open_items(h);
      if (!a) return 0;
      const char*last = a[2].text;
      a[2].text = a[1].text;
      a[1].text = a[0].text;
      a[0].text = last;
      return 1;
}

int c_swap_with_fixed(item_t*s, item_t*a)
{
      if (!matches(s, 51, "scalar", 7.5)
	  || !matches(&a[0], 52, "", 8.5)
	  || !matches(&a[1], 53, "fixed", 9.5))
	    return 0;
      const char*text = s->text;
      s->text = a[1].text;
      a[1].text = text;
      return 1;
}
