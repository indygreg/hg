// Copyright 2011, 2018 Yuya Nishihara <yuya@tcha.org>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

//! Utility for locating command-server process.

use std::env;
use std::ffi::{OsStr, OsString};
use std::fs::{self, DirBuilder};
use std::io;
use std::os::unix::ffi::{OsStrExt, OsStringExt};
use std::os::unix::fs::{DirBuilderExt, MetadataExt};
use std::path::{Path, PathBuf};
use std::process;
use std::time::Duration;

use super::procutil;

/// Helper to connect to and spawn a server process.
#[derive(Clone, Debug)]
pub struct Locator {
    hg_command: OsString,
    current_dir: PathBuf,
    env_vars: Vec<(OsString, OsString)>,
    process_id: u32,
    base_sock_path: PathBuf,
    timeout: Duration,
}

impl Locator {
    /// Creates locator capturing the current process environment.
    ///
    /// If no `$CHGSOCKNAME` is specified, the socket directory will be
    /// created as necessary.
    pub fn prepare_from_env() -> io::Result<Locator> {
        Ok(Locator {
            hg_command: default_hg_command(),
            current_dir: env::current_dir()?,
            env_vars: env::vars_os().collect(),
            process_id: process::id(),
            base_sock_path: prepare_server_socket_path()?,
            timeout: default_timeout(),
        })
    }

    /// Temporary socket path for this client process.
    fn temp_sock_path(&self) -> PathBuf {
        let src = self.base_sock_path.as_os_str().as_bytes();
        let mut buf = Vec::with_capacity(src.len() + 6);
        buf.extend_from_slice(src);
        buf.extend_from_slice(format!(".{}", self.process_id).as_bytes());
        OsString::from_vec(buf).into()
    }
}

/// Determines the server socket to connect to.
///
/// If no `$CHGSOCKNAME` is specified, the socket directory will be created
/// as necessary.
pub fn prepare_server_socket_path() -> io::Result<PathBuf> {
    if let Some(s) = env::var_os("CHGSOCKNAME") {
        Ok(PathBuf::from(s))
    } else {
        let mut path = default_server_socket_dir();
        create_secure_dir(&path)?;
        path.push("server");
        Ok(path)
    }
}

/// Determines the default server socket path as follows.
///
/// 1. `$XDG_RUNTIME_DIR/chg`
/// 2. `$TMPDIR/chg$UID`
/// 3. `/tmp/chg$UID`
pub fn default_server_socket_dir() -> PathBuf {
    // XDG_RUNTIME_DIR should be ignored if it has an insufficient permission.
    // https://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html
    if let Some(Ok(s)) = env::var_os("XDG_RUNTIME_DIR").map(check_secure_dir) {
        let mut path = PathBuf::from(s);
        path.push("chg");
        path
    } else {
        let mut path = env::temp_dir();
        path.push(format!("chg{}", procutil::get_effective_uid()));
        path
    }
}

/// Determines the default hg command.
pub fn default_hg_command() -> OsString {
    // TODO: maybe allow embedding the path at compile time (or load from hgrc)
    env::var_os("CHGHG").or(env::var_os("HG")).unwrap_or(OsStr::new("hg").to_owned())
}

fn default_timeout() -> Duration {
    let secs = env::var("CHGTIMEOUT").ok().and_then(|s| s.parse().ok()).unwrap_or(60);
    Duration::from_secs(secs)
}

/// Creates a directory which the other users cannot access to.
///
/// If the directory already exists, tests its permission.
fn create_secure_dir<P>(path: P) -> io::Result<()>
    where P: AsRef<Path>,
{
    DirBuilder::new().mode(0o700).create(path.as_ref()).or_else(|err| {
        if err.kind() == io::ErrorKind::AlreadyExists {
            check_secure_dir(path).map(|_| ())
        } else {
            Err(err)
        }
    })
}

fn check_secure_dir<P>(path: P) -> io::Result<P>
    where P: AsRef<Path>,
{
    let a = fs::symlink_metadata(path.as_ref())?;
    if a.is_dir() && a.uid() == procutil::get_effective_uid() && (a.mode() & 0o777) == 0o700 {
        Ok(path)
    } else {
        Err(io::Error::new(io::ErrorKind::Other, "insecure directory"))
    }
}
