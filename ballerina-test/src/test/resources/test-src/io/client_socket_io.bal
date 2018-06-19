import ballerina/io;

io:Socket socket;

function openSocketConnection (string host, int port) {
    io:Socket s = new;
    check s.connect(host, port);
    socket = s;
}

function openSocketConnectionWithProps (string host, int port, int localPort) returns io:Socket {
    io:Socket s = new;
    check s.bindAddress(localPort);
    check s.connect(host, port);
    return s;
}

function closeSocket () {
    error? err = socket.close();
}

function write (blob content) returns (int | error) {
    io:ByteChannel channel = socket.channel;
    var result = channel.write(content, 0);
    match result {
        int numberOfBytesWritten => {
            return numberOfBytesWritten;
        }
        error err => {
            return err;
        }
    }
}

function read (int size) returns (blob, int) | error {
    io:ByteChannel channel = socket.channel;
    var result = channel.read(size);
    match result{
        (blob , int)  content => {
            var (bytes, numberOfBytes) = content;
            return (bytes, numberOfBytes);
        }
        error err => {
            return err;
        }
    }
}

function close (io:Socket localSocket) {
    error? err = localSocket.close();
}

function main(string... args) {
    io:Socket s = openSocketConnectionWithProps("localhost", 9999, 33000);
}