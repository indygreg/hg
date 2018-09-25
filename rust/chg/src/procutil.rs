// Copyright 2018 Yuya Nishihara <yuya@tcha.org>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

//! Low-level utility for signal and process handling.

use libc::{self, c_int, pid_t, size_t, ssize_t};
use std::io;
use std::os::unix::io::RawFd;
use std::sync;

#[link(name = "procutil", kind = "static")]
extern "C" {
    // sendfds.c
    fn sendfds(sockfd: c_int, fds: *const c_int, fdlen: size_t) -> ssize_t;

    // sighandlers.c
    fn setupsignalhandler(pid: pid_t, pgid: pid_t) -> c_int;
    fn restoresignalhandler() -> c_int;
}

/// Returns the effective uid of the current process.
pub fn get_effective_uid() -> u32 {
    unsafe { libc::geteuid() }
}

/// Changes the given fd to blocking mode.
pub fn set_blocking_fd(fd: RawFd) -> io::Result<()> {
    let flags = unsafe { libc::fcntl(fd, libc::F_GETFL) };
    if flags < 0 {
        return Err(io::Error::last_os_error());
    }
    let r = unsafe { libc::fcntl(fd, libc::F_SETFL, flags & !libc::O_NONBLOCK) };
    if r < 0 {
        return Err(io::Error::last_os_error())
    }
    Ok(())
}

/// Sends file descriptors via the given socket.
pub fn send_raw_fds(sock_fd: RawFd, fds: &[RawFd]) -> io::Result<()> {
    let r = unsafe { sendfds(sock_fd, fds.as_ptr(), fds.len() as size_t) };
    if r < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

static SETUP_SIGNAL_HANDLER: sync::Once = sync::Once::new();
static RESTORE_SIGNAL_HANDLER: sync::Once = sync::Once::new();

/// Installs signal handlers to forward signals to the server.
///
/// # Safety
///
/// This touches global states, and thus synchronized as a one-time
/// initialization function.
pub fn setup_signal_handler_once(pid: u32, pgid: Option<u32>) -> io::Result<()> {
    let pid_signed = pid as i32;
    let pgid_signed = pgid.map(|n| n as i32).unwrap_or(0);
    let mut r = 0;
    SETUP_SIGNAL_HANDLER.call_once(|| {
        r = unsafe { setupsignalhandler(pid_signed, pgid_signed) };
    });
    if r < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

/// Restores the original signal handlers.
///
/// # Safety
///
/// This touches global states, and thus synchronized as a one-time
/// initialization function.
pub fn restore_signal_handler_once() -> io::Result<()> {
    let mut r = 0;
    RESTORE_SIGNAL_HANDLER.call_once(|| {
        r = unsafe { restoresignalhandler() };
    });
    if r < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}
