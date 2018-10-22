// Copyright 2018 Yuya Nishihara <yuya@tcha.org>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

//! Functions to run Mercurial command in cHg-aware command server.

use bytes::Bytes;
use futures::future::IntoFuture;
use futures::{Async, Future, Poll};
use std::io;
use std::mem;
use std::os::unix::io::AsRawFd;
use tokio_hglib::{Client, Connection};
use tokio_hglib::codec::ChannelMessage;
use tokio_hglib::protocol::MessageLoop;

use super::attachio::AttachIo;
use super::message::{self, CommandType};
use super::uihandler::SystemHandler;

enum AsyncS<R, S> {
    Ready(R),
    NotReady(S),
    PollAgain(S),
}

enum CommandState<C, H>
    where C: Connection,
          H: SystemHandler,
{
    Running(MessageLoop<C>, H),
    SpawningPager(Client<C>, <H::SpawnPagerResult as IntoFuture>::Future),
    AttachingPager(AttachIo<C, io::Stdin, H::PagerStdin, H::PagerStdin>, H),
    WaitingSystem(Client<C>, <H::RunSystemResult as IntoFuture>::Future),
    Finished,
}

type CommandPoll<C, H> = io::Result<(AsyncS<(Client<C>, H, i32), CommandState<C, H>>)>;

/// Future resolves to `(exit_code, client)`.
#[must_use = "futures do nothing unless polled"]
pub struct ChgRunCommand<C, H>
    where C: Connection,
          H: SystemHandler,
{
    state: CommandState<C, H>,
}

impl<C, H> ChgRunCommand<C, H>
    where C: Connection + AsRawFd,
          H: SystemHandler,
{
    pub fn with_client(client: Client<C>, handler: H, packed_args: Bytes)
                       -> ChgRunCommand<C, H> {
        let msg_loop = MessageLoop::start_with_args(client, b"runcommand", packed_args);
        ChgRunCommand {
            state: CommandState::Running(msg_loop, handler),
        }
    }
}

impl<C, H> Future for ChgRunCommand<C, H>
    where C: Connection + AsRawFd,
          H: SystemHandler,
{
    type Item = (Client<C>, H, i32);
    type Error = io::Error;

    fn poll(&mut self) -> Poll<Self::Item, Self::Error> {
        loop {
            let state = mem::replace(&mut self.state, CommandState::Finished);
            match state.poll()? {
                AsyncS::Ready((client, handler, code)) => {
                    return Ok(Async::Ready((client, handler, code)));
                }
                AsyncS::NotReady(newstate) => {
                    self.state = newstate;
                    return Ok(Async::NotReady);
                }
                AsyncS::PollAgain(newstate) => {
                    self.state = newstate;
                }
            }
        }
    }
}

impl<C, H> CommandState<C, H>
    where C: Connection + AsRawFd,
          H: SystemHandler,
{
    fn poll(self) -> CommandPoll<C, H> {
        match self {
            CommandState::Running(mut msg_loop, handler) => {
                if let Async::Ready((client, msg)) = msg_loop.poll()? {
                    process_message(client, handler, msg)
                } else {
                    Ok(AsyncS::NotReady(CommandState::Running(msg_loop, handler)))
                }
            }
            CommandState::SpawningPager(client, mut fut) => {
                if let Async::Ready((handler, pin)) = fut.poll()? {
                    let fut = AttachIo::with_client(client, io::stdin(), pin, None);
                    Ok(AsyncS::PollAgain(CommandState::AttachingPager(fut, handler)))
                } else {
                    Ok(AsyncS::NotReady(CommandState::SpawningPager(client, fut)))
                }
            }
            CommandState::AttachingPager(mut fut, handler) => {
                if let Async::Ready(client) = fut.poll()? {
                    let msg_loop = MessageLoop::start(client, b"");  // terminator
                    Ok(AsyncS::PollAgain(CommandState::Running(msg_loop, handler)))
                } else {
                    Ok(AsyncS::NotReady(CommandState::AttachingPager(fut, handler)))
                }
            }
            CommandState::WaitingSystem(client, mut fut) => {
                if let Async::Ready((handler, code)) = fut.poll()? {
                    let data = message::pack_result_code(code);
                    let msg_loop = MessageLoop::resume_with_data(client, data);
                    Ok(AsyncS::PollAgain(CommandState::Running(msg_loop, handler)))
                } else {
                    Ok(AsyncS::NotReady(CommandState::WaitingSystem(client, fut)))
                }
            }
            CommandState::Finished => panic!("poll ChgRunCommand after it's done")
        }
    }
}

fn process_message<C, H>(client: Client<C>, handler: H, msg: ChannelMessage) -> CommandPoll<C, H>
    where C: Connection,
          H: SystemHandler,
{
    match msg {
        ChannelMessage::Data(b'r', data) => {
            let code = message::parse_result_code(data)?;
            Ok(AsyncS::Ready((client, handler, code)))
        }
        ChannelMessage::Data(..) => {
            // just ignores data sent to optional channel
            let msg_loop = MessageLoop::resume(client);
            Ok(AsyncS::PollAgain(CommandState::Running(msg_loop, handler)))
        }
        ChannelMessage::InputRequest(..) | ChannelMessage::LineRequest(..) => {
            Err(io::Error::new(io::ErrorKind::InvalidData, "unsupported request"))
        }
        ChannelMessage::SystemRequest(data) => {
            let (cmd_type, cmd_spec) = message::parse_command_spec(data)?;
            match cmd_type {
                CommandType::Pager => {
                    let fut = handler.spawn_pager(cmd_spec).into_future();
                    Ok(AsyncS::PollAgain(CommandState::SpawningPager(client, fut)))
                }
                CommandType::System => {
                    let fut = handler.run_system(cmd_spec).into_future();
                    Ok(AsyncS::PollAgain(CommandState::WaitingSystem(client, fut)))
                }
            }
        }
    }
}
