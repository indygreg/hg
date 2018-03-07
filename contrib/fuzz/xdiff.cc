/*
 * xdiff.cc - fuzzer harness for thirdparty/xdiff
 *
 * Copyright 2018, Google Inc.
 *
 * This software may be used and distributed according to the terms of
 * the GNU General Public License, incorporated herein by reference.
 */
#include "thirdparty/xdiff/xdiff.h"
#include <inttypes.h>
#include <stdlib.h>

extern "C" {

int hunk_consumer(long a1, long a2, long b1, long b2, void *priv)
{
	// TODO: probably also test returning -1 from this when things break?
	return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size)
{
	if (!Size) {
		return 0;
	}
	// figure out a random point in [0, Size] to split our input.
	size_t split = Data[0] / 255.0 * Size;

	mmfile_t a, b;

	// `a` input to diff is data[1:split]
	a.ptr = (char *)Data + 1;
	// which has len split-1
	a.size = split - 1;
	// `b` starts at the next byte after `a` ends
	b.ptr = a.ptr + a.size;
	b.size = Size - split;
	xpparam_t xpp = {
	    XDF_INDENT_HEURISTIC, /* flags */
	};
	xdemitconf_t xecfg = {
	    XDL_EMIT_BDIFFHUNK, /* flags */
	    hunk_consumer,      /* hunk_consume_func */
	};
	xdemitcb_t ecb = {
	    NULL, /* priv */
	};
	xdl_diff(&a, &b, &xpp, &xecfg, &ecb);
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
