// Copyright 2018 Yuya Nishihara <yuya@tcha.org>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

//! Functions to send client-side fds over the command server channel.

use futures::{Async, Future, Poll};
use std::io;
use std::os::unix::io::AsRawFd;
use tokio_hglib::{Client, Connection};
use tokio_hglib::codec::ChannelMessage;
use tokio_hglib::protocol::MessageLoop;

use super::message;
use super::procutil;

/// Future to send client-side fds over the command server channel.
///
/// This works as follows:
/// 1. Client sends "attachio" request.
/// 2. Server sends back 1-byte input request.
/// 3. Client sends fds with 1-byte dummy payload in response.
/// 4. Server returns the number of the fds received.
///
/// If the stderr is omitted, it will be redirected to the stdout. This
/// allows us to attach the pager stdin to both stdout and stderr, and
/// dispose of the client-side handle once attached.
#[must_use = "futures do nothing unless polled"]
pub struct AttachIo<C, I, O, E>
    where C: Connection,
{
    msg_loop: MessageLoop<C>,
    stdin: I,
    stdout: O,
    stderr: Option<E>,
}

impl<C, I, O, E> AttachIo<C, I, O, E>
    where C: Connection + AsRawFd,
          I: AsRawFd,
          O: AsRawFd,
          E: AsRawFd,
{
    pub fn with_client(client: Client<C>, stdin: I, stdout: O, stderr: Option<E>)
                       -> AttachIo<C, I, O, E> {
        let msg_loop = MessageLoop::start(client, b"attachio");
        AttachIo { msg_loop, stdin, stdout, stderr }
    }
}

impl<C, I, O, E> Future for AttachIo<C, I, O, E>
    where C: Connection + AsRawFd,
          I: AsRawFd,
          O: AsRawFd,
          E: AsRawFd,
{
    type Item = Client<C>;
    type Error = io::Error;

    fn poll(&mut self) -> Poll<Self::Item, Self::Error> {
        loop {
            let (client, msg) = try_ready!(self.msg_loop.poll());
            match msg {
                ChannelMessage::Data(b'r', data) => {
                    let fd_cnt = message::parse_result_code(data)?;
                    if fd_cnt == 3 {
                        return Ok(Async::Ready(client));
                    } else {
                        return Err(io::Error::new(io::ErrorKind::InvalidData,
                                                  "unexpected attachio result"));
                    }
                }
                ChannelMessage::Data(..) => {
                    // just ignore data sent to uninteresting (optional) channel
                    self.msg_loop = MessageLoop::resume(client);
                }
                ChannelMessage::InputRequest(1) => {
                    // this may fail with EWOULDBLOCK in theory, but the
                    // payload is quite small, and the send buffer should
                    // be empty so the operation will complete immediately
                    let sock_fd = client.as_raw_fd();
                    let ifd = self.stdin.as_raw_fd();
                    let ofd = self.stdout.as_raw_fd();
                    let efd = self.stderr.as_ref().map_or(ofd, |f| f.as_raw_fd());
                    procutil::send_raw_fds(sock_fd, &[ifd, ofd, efd])?;
                    self.msg_loop = MessageLoop::resume(client);
                }
                ChannelMessage::InputRequest(..) | ChannelMessage::LineRequest(..) |
                ChannelMessage::SystemRequest(..) => {
                    return Err(io::Error::new(io::ErrorKind::InvalidData,
                                              "unsupported request while attaching io"));
                }
            }
        }
    }
}
