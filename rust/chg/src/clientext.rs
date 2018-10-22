// Copyright 2018 Yuya Nishihara <yuya@tcha.org>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

//! cHg extensions to command server client.

use std::ffi::OsStr;
use std::os::unix::ffi::OsStrExt;
use std::os::unix::io::AsRawFd;
use std::path::Path;
use tokio_hglib::{Client, Connection};
use tokio_hglib::protocol::OneShotRequest;

use super::attachio::AttachIo;
use super::message;
use super::runcommand::ChgRunCommand;
use super::uihandler::SystemHandler;

pub trait ChgClientExt<C>
    where C: Connection + AsRawFd,
{
    /// Attaches the client file descriptors to the server.
    fn attach_io<I, O, E>(self, stdin: I, stdout: O, stderr: E) -> AttachIo<C, I, O, E>
        where I: AsRawFd,
              O: AsRawFd,
              E: AsRawFd;

    /// Changes the working directory of the server.
    fn set_current_dir<P>(self, dir: P) -> OneShotRequest<C>
        where P: AsRef<Path>;

    /// Runs the specified Mercurial command with cHg extension.
    fn run_command_chg<I, P, H>(self, handler: H, args: I) -> ChgRunCommand<C, H>
        where I: IntoIterator<Item = P>,
              P: AsRef<OsStr>,
              H: SystemHandler;
}

impl<C> ChgClientExt<C> for Client<C>
    where C: Connection + AsRawFd,
{
    fn attach_io<I, O, E>(self, stdin: I, stdout: O, stderr: E) -> AttachIo<C, I, O, E>
        where I: AsRawFd,
              O: AsRawFd,
              E: AsRawFd,
    {
        AttachIo::with_client(self, stdin, stdout, Some(stderr))
    }

    fn set_current_dir<P>(self, dir: P) -> OneShotRequest<C>
        where P: AsRef<Path>,
    {
        OneShotRequest::start_with_args(self, b"chdir", dir.as_ref().as_os_str().as_bytes())
    }

    fn run_command_chg<I, P, H>(self, handler: H, args: I) -> ChgRunCommand<C, H>
        where I: IntoIterator<Item = P>,
              P: AsRef<OsStr>,
              H: SystemHandler,
    {
        ChgRunCommand::with_client(self, handler, message::pack_args_os(args))
    }
}
