// Связь между запусками wosd. Сокет в абстрактном пространстве имён: ядро
// убирает его вместе с процессом, протухших файлов после падения не бывает,
// а bind() атомарен — окно поднимает ровно один процесс. Чужих пользователей
// отсекаем по SO_PEERCRED в обе стороны.

use std::io::{self, Read, Write};
use std::os::linux::net::SocketAddrExt;
use std::os::unix::net::{SocketAddr, UnixListener, UnixStream};
use std::time::Duration;

use rustix::net::sockopt::socket_peercred;
use rustix::process::getuid;

use crate::control::Level;

pub const ACK: &[u8] = b"k";
pub const TIMEOUT: Duration = Duration::from_millis(300);

fn addr() -> io::Result<SocketAddr> {
    SocketAddr::from_abstract_name(format!("wosd-{}", getuid().as_raw()))
}

pub fn same_user(stream: &UnixStream) -> bool {
    socket_peercred(stream).is_ok_and(|cred| cred.uid == getuid())
}

// Ok(None) — окно уже показывает другой процесс
pub fn bind() -> io::Result<Option<UnixListener>> {
    match UnixListener::bind_addr(&addr()?) {
        Ok(listener) => Ok(Some(listener)),
        Err(e) if e.kind() == io::ErrorKind::AddrInUse => Ok(None),
        Err(e) => Err(e),
    }
}

// Ошибка — окно как раз закрывается, можно пробовать стать им самим
pub fn send(level: &Level) -> io::Result<()> {
    let mut stream = UnixStream::connect_addr(&addr()?)?;
    if !same_user(&stream) {
        return Err(io::Error::other("сокет wosd занят другим пользователем"));
    }
    stream.set_read_timeout(Some(TIMEOUT))?;
    stream.write_all(level.encode().as_bytes())?;
    let mut ack = [0u8; 1];
    stream.read_exact(&mut ack)?;
    Ok(())
}
