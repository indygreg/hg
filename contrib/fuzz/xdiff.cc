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

#include "fuzzutil.h"

extern "C" {

int hunk_consumer(long a1, long a2, long b1, long b2, void *priv)
{
	// TODO: probably also test returning -1 from this when things break?
	return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size)
{
	auto maybe_inputs = SplitInputs(Data, Size);
	if (!maybe_inputs) {
		return 0;
	}
	auto inputs = std::move(maybe_inputs.value());
	mmfile_t a, b;

	a.ptr = inputs.left.get();
	a.size = inputs.left_size;
	b.ptr = inputs.right.get();
	b.size = inputs.right_size;
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
