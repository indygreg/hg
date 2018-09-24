// Copyright 2018 Yuya Nishihara <yuya@tcha.org>
//
// This software may be used and distributed according to the terms of the
// GNU General Public License version 2 or any later version.

//! Utility for parsing and building command-server messages.

use bytes::Bytes;
use std::error;
use std::ffi::{OsStr, OsString};
use std::io;
use std::os::unix::ffi::OsStrExt;

pub use tokio_hglib::message::*;  // re-exports

/// Shell command type requested by the server.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CommandType {
    /// Pager should be spawned.
    Pager,
    /// Shell command should be executed to send back the result code.
    System,
}

/// Shell command requested by the server.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CommandSpec {
    pub command: OsString,
    pub current_dir: OsString,
    pub envs: Vec<(OsString, OsString)>,
}

/// Parses "S" channel request into command type and spec.
pub fn parse_command_spec(data: Bytes) -> io::Result<(CommandType, CommandSpec)> {
    let mut split = data.split(|&c| c == b'\0');
    let ctype = parse_command_type(split.next().ok_or(new_parse_error("missing type"))?)?;
    let command = split.next().ok_or(new_parse_error("missing command"))?;
    let current_dir = split.next().ok_or(new_parse_error("missing current dir"))?;

    let mut envs = Vec::new();
    for l in split {
        let mut s = l.splitn(2, |&c| c == b'=');
        let k = s.next().unwrap();
        let v = s.next().ok_or(new_parse_error("malformed env"))?;
        envs.push((OsStr::from_bytes(k).to_owned(), OsStr::from_bytes(v).to_owned()));
    }

    let spec = CommandSpec {
        command: OsStr::from_bytes(command).to_owned(),
        current_dir: OsStr::from_bytes(current_dir).to_owned(),
        envs: envs,
    };
    Ok((ctype, spec))
}

fn parse_command_type(value: &[u8]) -> io::Result<CommandType> {
    match value {
        b"pager" => Ok(CommandType::Pager),
        b"system" => Ok(CommandType::System),
        _ => Err(new_parse_error(format!("unknown command type: {}", decode_latin1(value)))),
    }
}

fn decode_latin1<S>(s: S) -> String
    where S: AsRef<[u8]>,
{
    s.as_ref().iter().map(|&c| c as char).collect()
}

fn new_parse_error<E>(error: E) -> io::Error
    where E: Into<Box<error::Error + Send + Sync>>,
{
    io::Error::new(io::ErrorKind::InvalidData, error)
}

#[cfg(test)]
mod tests {
    use std::os::unix::ffi::OsStringExt;
    use super::*;

    #[test]
    fn parse_command_spec_good() {
        let src = [b"pager".as_ref(),
                   b"less -FRX".as_ref(),
                   b"/tmp".as_ref(),
                   b"LANG=C".as_ref(),
                   b"HGPLAIN=".as_ref()].join(&0);
        let spec = CommandSpec {
            command: os_string_from(b"less -FRX"),
            current_dir: os_string_from(b"/tmp"),
            envs: vec![(os_string_from(b"LANG"), os_string_from(b"C")),
                       (os_string_from(b"HGPLAIN"), os_string_from(b""))],
        };
        assert_eq!(parse_command_spec(Bytes::from(src)).unwrap(), (CommandType::Pager, spec));
    }

    #[test]
    fn parse_command_spec_too_short() {
        assert!(parse_command_spec(Bytes::from_static(b"")).is_err());
        assert!(parse_command_spec(Bytes::from_static(b"pager")).is_err());
        assert!(parse_command_spec(Bytes::from_static(b"pager\0less")).is_err());
    }

    #[test]
    fn parse_command_spec_malformed_env() {
        assert!(parse_command_spec(Bytes::from_static(b"pager\0less\0/tmp\0HOME")).is_err());
    }

    #[test]
    fn parse_command_spec_unknown_type() {
        assert!(parse_command_spec(Bytes::from_static(b"paper\0less")).is_err());
    }

    fn os_string_from(s: &[u8]) -> OsString {
        OsString::from_vec(s.to_vec())
    }
}
