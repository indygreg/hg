// Copyright 2011, 2018 Yuya Nishihara <yuya@tcha.org>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

//! Utility for locating command-server process.

use std::env;
use std::fs::{self, DirBuilder};
use std::io;
use std::os::unix::fs::{DirBuilderExt, MetadataExt};
use std::path::{Path, PathBuf};

use super::procutil;

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
