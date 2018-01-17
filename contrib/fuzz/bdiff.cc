/*
 * bdiff.cc - fuzzer harness for bdiff.c
 *
 * Copyright 2018, Google Inc.
 *
 * This software may be used and distributed according to the terms of
 * the GNU General Public License, incorporated herein by reference.
 */
#include <stdlib.h>

extern "C" {
#include "bdiff.h"

int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size)
{
	if (!Size) {
		return 0;
	}
	// figure out a random point in [0, Size] to split our input.
	size_t split = Data[0] / 255.0 * Size;

	// left input to diff is data[1:split]
	const uint8_t *left = Data + 1;
	// which has len split-1
	size_t left_size = split - 1;
	// right starts at the next byte after left ends
	const uint8_t *right = left + left_size;
	size_t right_size = Size - split;

	struct bdiff_line *a, *b;
	int an = bdiff_splitlines((const char *)left, split - 1, &a);
	int bn = bdiff_splitlines((const char *)right, right_size, &b);
	struct bdiff_hunk l;
	bdiff_diff(a, an, b, bn, &l);
	free(a);
	free(b);
	bdiff_freehunks(l.next);
	return 0; // Non-zero return values are reserved for future use.
}

#ifdef HG_FUZZER_INCLUDE_MAIN
int main(int argc, char **argv)
{
	const char data[] = "asdf";
	return LLVMFuzzerTestOneInput((const uint8_t *)data, 4);
}
#endif

} // extern "C"
