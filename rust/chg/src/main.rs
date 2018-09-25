// Copyright 2018 Yuya Nishihara <yuya@tcha.org>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

extern crate chg;
extern crate futures;
extern crate tokio;
extern crate tokio_hglib;

use chg::{ChgClientExt, ChgUiHandler};
use chg::locator;
use chg::procutil;
use futures::sync::oneshot;
use std::env;
use std::io;
use std::process;
use tokio::prelude::*;
use tokio_hglib::UnixClient;

fn main() {
    let code = run().unwrap_or_else(|err| {
        eprintln!("chg: abort: {}", err);
        255
    });
    process::exit(code);
}

fn run() -> io::Result<i32> {
    let current_dir = env::current_dir()?;
    let sock_path = locator::prepare_server_socket_path()?;
    let handler = ChgUiHandler::new();
    let (result_tx, result_rx) = oneshot::channel();
    let fut = UnixClient::connect(sock_path)
        .and_then(|client| {
            client.set_current_dir(current_dir)
        })
        .and_then(|client| {
            client.attach_io(io::stdin(), io::stdout(), io::stderr())
        })
        .and_then(|client| {
            let pid = client.server_spec().process_id.unwrap();
            let pgid = client.server_spec().process_group_id;
            procutil::setup_signal_handler_once(pid, pgid)?;
            Ok(client)
        })
        .and_then(|client| {
            client.run_command_chg(handler, env::args_os().skip(1))
        })
        .map(|(_client, _handler, code)| {
            procutil::restore_signal_handler_once()?;
            Ok(code)
        })
        .or_else(|err| Ok(Err(err)))  // pass back error to caller
        .map(|res| result_tx.send(res).unwrap());
    tokio::run(fut);
    result_rx.wait().unwrap_or(Err(io::Error::new(io::ErrorKind::Other,
                                                  "no exit code set")))
}
