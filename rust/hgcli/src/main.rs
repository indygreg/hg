// main.rs -- Main routines for `hg` program
//
// Copyright 2017 Gregory Szorc <gregory.szorc@gmail.com>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

extern crate libc;
extern crate cpython;
extern crate python27_sys;

use cpython::{NoArgs, ObjectProtocol, PyModule, PyResult, Python};
use libc::{c_char, c_int};

use std::env;
use std::path::PathBuf;
use std::ffi::{CString, OsStr};
#[cfg(target_family = "unix")]
use std::os::unix::ffi::{OsStrExt, OsStringExt};

#[derive(Debug)]
struct Environment {
    _exe: PathBuf,
    python_exe: PathBuf,
    python_home: PathBuf,
    mercurial_modules: PathBuf,
}

/// Run Mercurial locally from a source distribution or checkout.
///
/// hg is <srcdir>/rust/target/<target>/hg
/// Python interpreter is detected by build script.
/// Python home is relative to Python interpreter.
/// Mercurial files are relative to hg binary, which is relative to source root.
#[cfg(feature = "localdev")]
fn get_environment() -> Environment {
    let exe = env::current_exe().unwrap();

    let mut mercurial_modules = exe.clone();
    mercurial_modules.pop(); // /rust/target/<target>
    mercurial_modules.pop(); // /rust/target
    mercurial_modules.pop(); // /rust
    mercurial_modules.pop(); // /

    let python_exe: &'static str = env!("PYTHON_INTERPRETER");
    let python_exe = PathBuf::from(python_exe);

    let mut python_home = python_exe.clone();
    python_home.pop();

    // On Windows, python2.7.exe exists at the root directory of the Python
    // install. Everywhere else, the Python install root is one level up.
    if !python_exe.ends_with("python2.7.exe") {
        python_home.pop();
    }

    Environment {
        _exe: exe.clone(),
        python_exe: python_exe,
        python_home: python_home,
        mercurial_modules: mercurial_modules.to_path_buf(),
    }
}

// On UNIX, platform string is just bytes and should not contain NUL.
#[cfg(target_family = "unix")]
fn cstring_from_os<T: AsRef<OsStr>>(s: T) -> CString {
    CString::new(s.as_ref().as_bytes()).unwrap()
}

// TODO convert to ANSI characters?
#[cfg(target_family = "windows")]
fn cstring_from_os<T: AsRef<OsStr>>(s: T) -> CString {
    CString::new(s.as_ref().to_str().unwrap()).unwrap()
}

// On UNIX, argv starts as an array of char*. So it is easy to convert
// to C strings.
#[cfg(target_family = "unix")]
fn args_to_cstrings() -> Vec<CString> {
    env::args_os()
        .map(|a| CString::new(a.into_vec()).unwrap())
        .collect()
}

// TODO Windows support is incomplete. We should either use env::args_os()
// (or call into GetCommandLineW() + CommandLinetoArgvW()), convert these to
// PyUnicode instances, and pass these into Python/Mercurial outside the
// standard PySys_SetArgvEx() mechanism. This will allow us to preserve the
// raw bytes (since PySys_SetArgvEx() is based on char* and can drop wchar
// data.
//
// For now, we use env::args(). This will choke on invalid UTF-8 arguments.
// But it is better than nothing.
#[cfg(target_family = "windows")]
fn args_to_cstrings() -> Vec<CString> {
    env::args().map(|a| CString::new(a).unwrap()).collect()
}

fn set_python_home(env: &Environment) {
    let raw = cstring_from_os(&env.python_home).into_raw();
    unsafe {
        python27_sys::Py_SetPythonHome(raw);
    }
}

fn update_encoding(_py: Python, _sys_mod: &PyModule) {
    // Call sys.setdefaultencoding("undefined") if HGUNICODEPEDANTRY is set.
    let pedantry = env::var("HGUNICODEPEDANTRY").is_ok();

    if pedantry {
        // site.py removes the sys.setdefaultencoding attribute. So we need
        // to reload the module to get a handle on it. This is a lesser
        // used feature and we'll support this later.
        // TODO support this
        panic!("HGUNICODEPEDANTRY is not yet supported");
    }
}

fn update_modules_path(env: &Environment, py: Python, sys_mod: &PyModule) {
    let sys_path = sys_mod.get(py, "path").unwrap();
    sys_path
        .call_method(py, "insert", (0, env.mercurial_modules.to_str()), None)
        .expect("failed to update sys.path to location of Mercurial modules");
}

fn run() -> Result<(), i32> {
    let env = get_environment();

    //println!("{:?}", env);

    // Tell Python where it is installed.
    set_python_home(&env);

    // Set program name. The backing memory needs to live for the duration of the
    // interpreter.
    //
    // TODO consider storing this in a static or associating with lifetime of
    // the Python interpreter.
    //
    // Yes, we use the path to the Python interpreter not argv[0] here. The
    // reason is because Python uses the given path to find the location of
    // Python files. Apparently we could define our own ``Py_GetPath()``
    // implementation. But this may require statically linking Python, which is
    // not desirable.
    let program_name = cstring_from_os(&env.python_exe).as_ptr();
    unsafe {
        python27_sys::Py_SetProgramName(program_name as *mut i8);
    }

    unsafe {
        python27_sys::Py_Initialize();
    }

    // https://docs.python.org/2/c-api/init.html#c.PySys_SetArgvEx has important
    // usage information about PySys_SetArgvEx:
    //
    // * It says the first argument should be the script that is being executed.
    //   If not a script, it can be empty. We are definitely not a script.
    //   However, parts of Mercurial do look at sys.argv[0]. So we need to set
    //   something here.
    //
    // * When embedding Python, we should use ``PySys_SetArgvEx()`` and set
    //   ``updatepath=0`` for security reasons. Essentially, Python's default
    //   logic will treat an empty argv[0] in a manner that could result in
    //   sys.path picking up directories it shouldn't and this could lead to
    //   loading untrusted modules.

    // env::args() will panic if it sees a non-UTF-8 byte sequence. And
    // Mercurial supports arbitrary encodings of input data. So we need to
    // use OS-specific mechanisms to get the raw bytes without UTF-8
    // interference.
    let args = args_to_cstrings();
    let argv: Vec<*const c_char> = args.iter().map(|a| a.as_ptr()).collect();

    unsafe {
        python27_sys::PySys_SetArgvEx(args.len() as c_int, argv.as_ptr() as *mut *mut i8, 0);
    }

    let result;
    {
        // These need to be dropped before we call Py_Finalize(). Hence the
        // block.
        let gil = Python::acquire_gil();
        let py = gil.python();

        // Mercurial code could call sys.exit(), which will call exit()
        // itself. So this may not return.
        // TODO this may cause issues on Windows due to the CRT mismatch.
        // Investigate if we can intercept sys.exit() or SystemExit() to
        // ensure we handle process exit.
        result = match run_py(&env, py) {
            // Print unhandled exceptions and exit code 255, as this is what
            // `python` does.
            Err(err) => {
                err.print(py);
                Err(255)
            }
            Ok(()) => Ok(()),
        };
    }

    unsafe {
        python27_sys::Py_Finalize();
    }

    result
}

fn run_py(env: &Environment, py: Python) -> PyResult<()> {
    let sys_mod = py.import("sys").unwrap();

    update_encoding(py, &sys_mod);
    update_modules_path(&env, py, &sys_mod);

    // TODO consider a better error message on failure to import.
    let demand_mod = py.import("hgdemandimport")?;
    demand_mod.call(py, "enable", NoArgs, None)?;

    let dispatch_mod = py.import("mercurial.dispatch")?;
    dispatch_mod.call(py, "run", NoArgs, None)?;

    Ok(())
}

fn main() {
    let exit_code = match run() {
        Err(err) => err,
        Ok(()) => 0,
    };

    std::process::exit(exit_code);
}
