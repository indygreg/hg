// build.rs -- Configure build environment for `hgcli` Rust package.
//
// Copyright 2017 Gregory Szorc <gregory.szorc@gmail.com>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

use std::collections::HashMap;
use std::env;
use std::path::Path;
use std::process::Command;

struct PythonConfig {
    python: String,
    config: HashMap<String, String>,
}

fn get_python_config() -> PythonConfig {
    // The python27-sys crate exports a Cargo variable defining the full
    // path to the interpreter being used.
    let python = env::var("DEP_PYTHON27_PYTHON_INTERPRETER").expect(
        "Missing DEP_PYTHON27_PYTHON_INTERPRETER; bad python27-sys crate?",
    );

    if !Path::new(&python).exists() {
        panic!(
            "Python interpreter {} does not exist; this should never happen",
            python
        );
    }

    // This is a bit hacky but it gets the job done.
    let separator = "SEPARATOR STRING";

    let script = "import sysconfig; \
c = sysconfig.get_config_vars(); \
print('SEPARATOR STRING'.join('%s=%s' % i for i in c.items()))";

    let mut command = Command::new(&python);
    command.arg("-c").arg(script);

    let out = command.output().unwrap();

    if !out.status.success() {
        panic!(
            "python script failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );
    }

    let stdout = String::from_utf8_lossy(&out.stdout);
    let mut m = HashMap::new();

    for entry in stdout.split(separator) {
        let mut parts = entry.splitn(2, "=");
        let key = parts.next().unwrap();
        let value = parts.next().unwrap();
        m.insert(String::from(key), String::from(value));
    }

    PythonConfig {
        python: python,
        config: m,
    }
}

#[cfg(not(target_os = "windows"))]
fn have_shared(config: &PythonConfig) -> bool {
    match config.config.get("Py_ENABLE_SHARED") {
        Some(value) => value == "1",
        None => false,
    }
}

#[cfg(target_os = "windows")]
fn have_shared(config: &PythonConfig) -> bool {
    use std::path::PathBuf;

    // python27.dll should exist next to python2.7.exe.
    let mut dll = PathBuf::from(&config.python);
    dll.pop();
    dll.push("python27.dll");

    return dll.exists();
}

const REQUIRED_CONFIG_FLAGS: [&str; 2] = ["Py_USING_UNICODE", "WITH_THREAD"];

fn main() {
    let config = get_python_config();

    println!("Using Python: {}", config.python);
    println!("cargo:rustc-env=PYTHON_INTERPRETER={}", config.python);

    let prefix = config.config.get("prefix").unwrap();

    println!("Prefix: {}", prefix);

    // TODO Windows builds don't expose these config flags. Figure out another
    // way.
    #[cfg(not(target_os = "windows"))]
    for key in REQUIRED_CONFIG_FLAGS.iter() {
        let result = match config.config.get(*key) {
            Some(value) => value == "1",
            None => false,
        };

        if !result {
            panic!("Detected Python requires feature {}", key);
        }
    }

    // We need a Python shared library.
    if !have_shared(&config) {
        panic!("Detected Python lacks a shared library, which is required");
    }

    let ucs4 = match config.config.get("Py_UNICODE_SIZE") {
        Some(value) => value == "4",
        None => false,
    };

    if !ucs4 {
        #[cfg(not(target_os = "windows"))]
        panic!("Detected Python doesn't support UCS-4 code points");
    }
}
