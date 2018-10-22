// Copyright 2018 Yuya Nishihara <yuya@tcha.org>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

use futures::Future;
use futures::future::IntoFuture;
use std::io;
use std::os::unix::io::AsRawFd;
use std::os::unix::process::ExitStatusExt;
use std::process::{Command, Stdio};
use tokio;
use tokio_process::{ChildStdin, CommandExt};

use super::message::CommandSpec;
use super::procutil;

/// Callback to process shell command requests received from server.
pub trait SystemHandler: Sized {
    type PagerStdin: AsRawFd;
    type SpawnPagerResult: IntoFuture<Item = (Self, Self::PagerStdin), Error = io::Error>;
    type RunSystemResult: IntoFuture<Item = (Self, i32), Error = io::Error>;

    /// Handles pager command request.
    ///
    /// Returns the pipe to be attached to the server if the pager is spawned.
    fn spawn_pager(self, spec: CommandSpec) -> Self::SpawnPagerResult;

    /// Handles system command request.
    ///
    /// Returns command exit code (positive) or signal number (negative).
    fn run_system(self, spec: CommandSpec) -> Self::RunSystemResult;
}

/// Default cHg implementation to process requests received from server.
pub struct ChgUiHandler {
}

impl ChgUiHandler {
    pub fn new() -> ChgUiHandler {
        ChgUiHandler {}
    }
}

impl SystemHandler for ChgUiHandler {
    type PagerStdin = ChildStdin;
    type SpawnPagerResult = io::Result<(Self, Self::PagerStdin)>;
    type RunSystemResult = Box<dyn Future<Item = (Self, i32), Error = io::Error> + Send>;

    fn spawn_pager(self, spec: CommandSpec) -> Self::SpawnPagerResult {
        let mut pager = new_shell_command(&spec)
            .stdin(Stdio::piped())
            .spawn_async()?;
        let pin = pager.stdin().take().unwrap();
        procutil::set_blocking_fd(pin.as_raw_fd())?;
        // TODO: if pager exits, notify the server with SIGPIPE immediately.
        // otherwise the server won't get SIGPIPE if it does not write
        // anything. (issue5278)
        // kill(peerpid, SIGPIPE);
        tokio::spawn(pager.map(|_| ()).map_err(|_| ()));  // just ignore errors
        Ok((self, pin))
    }

    fn run_system(self, spec: CommandSpec) -> Self::RunSystemResult {
        let fut = new_shell_command(&spec)
            .spawn_async()
            .into_future()
            .flatten()
            .map(|status| {
                let code = status.code().or_else(|| status.signal().map(|n| -n))
                    .expect("either exit code or signal should be set");
                (self, code)
            });
        Box::new(fut)
    }
}

fn new_shell_command(spec: &CommandSpec) -> Command {
    let mut builder = Command::new("/bin/sh");
    builder
        .arg("-c")
        .arg(&spec.command)
        .current_dir(&spec.current_dir)
        .env_clear()
        .envs(spec.envs.iter().cloned());
    builder
 }
