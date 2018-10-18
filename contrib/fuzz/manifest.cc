#include <Python.h>
#include <assert.h>
#include <stdlib.h>
#include <unistd.h>

#include <string>

extern "C" {

/* TODO: use Python 3 for this fuzzing? */
PyMODINIT_FUNC initparsers(void);

static char cpypath[8192] = "\0";

static PyCodeObject *code;
static PyObject *mainmod;
static PyObject *globals;

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv)
{
	const std::string subdir = "/sanpy/lib/python2.7";
	/* HACK ALERT: we need a full Python installation built without
	   pymalloc and with ASAN, so we dump one in
	   $OUT/sanpy/lib/python2.7. This helps us wire that up. */
	std::string selfpath(*argv[0]);
	std::string pypath;
	auto pos = selfpath.rfind("/");
	if (pos == std::string::npos) {
		char wd[8192];
		getcwd(wd, 8192);
		pypath = std::string(wd) + subdir;
	} else {
		pypath = selfpath.substr(0, pos) + subdir;
	}
	strncpy(cpypath, pypath.c_str(), pypath.size());
	setenv("PYTHONPATH", cpypath, 1);
	setenv("PYTHONNOUSERSITE", "1", 1);
	/* prevent Python from looking up users in the fuzz environment */
	setenv("PYTHONUSERBASE", cpypath, 1);
	Py_SetPythonHome(cpypath);
	Py_InitializeEx(0);
	initparsers();
	code = (PyCodeObject *)Py_CompileString(R"py(
from parsers import lazymanifest
try:
  lm = lazymanifest(mdata)
  # iterate the whole thing, which causes the code to fully parse
  # every line in the manifest
  list(lm.iterentries())
  lm[b'xyzzy'] = (b'\0' * 20, 'x')
  # do an insert, text should change
  assert lm.text() != mdata, "insert should change text and didn't: %r %r" % (lm.text(), mdata)
  del lm[b'xyzzy']
  # should be back to the same
  assert lm.text() == mdata, "delete should have restored text but didn't: %r %r" % (lm.text(), mdata)
except Exception as e:
  pass
  # uncomment this print if you're editing this Python code
  # to debug failures.
  # print e
)py",
	                                        "fuzzer", Py_file_input);
	mainmod = PyImport_AddModule("__main__");
	globals = PyModule_GetDict(mainmod);
	return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size)
{
	PyObject *mtext =
	    PyBytes_FromStringAndSize((const char *)Data, (Py_ssize_t)Size);
	PyObject *locals = PyDict_New();
	PyDict_SetItemString(locals, "mdata", mtext);
	PyObject *res = PyEval_EvalCode(code, globals, locals);
	if (!res) {
		PyErr_Print();
	}
	Py_XDECREF(res);
	Py_DECREF(locals);
	Py_DECREF(mtext);
	return 0; // Non-zero return values are reserved for future use.
}
}
