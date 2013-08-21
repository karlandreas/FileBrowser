//
//  sshConnect.c
//  FileBrowser
//
//  Created by Super User on 20.08.13.
//  Copyright (c) 2013 KAjohansen. All rights reserved.
//

#import "sshConnect.h"

@implementation sshConnect

LIBSSH2_AGENT *agent = NULL;        // agent handle
LIBSSH2_CHANNEL *channel;           // Channel handle
LIBSSH2_SESSION *session = NULL;    // Session handle
int sock = -1;                      // socket handle
long rc;                             // Remote Connect handle
int bytecount = 0;                  // count bytes returned from command execution

static long waitsocket(int socket_fd, LIBSSH2_SESSION *session)
{
    struct timeval timeout;
    fd_set fd;
    fd_set *writefd = NULL;
    fd_set *readfd = NULL;
    int dir;
    
    timeout.tv_sec = 10;
    timeout.tv_usec = 0;
    
    FD_ZERO(&fd);
    
    FD_SET(socket_fd, &fd);
    
    /* now make sure we wait in the correct direction */
    dir = libssh2_session_block_directions(session);
    
    
    if(dir & LIBSSH2_SESSION_BLOCK_INBOUND)
        readfd = &fd;
    
    if(dir & LIBSSH2_SESSION_BLOCK_OUTBOUND)
        writefd = &fd;
    
    rc = select(socket_fd + 1, readfd, writefd, NULL, &timeout);
    
    return rc;
}

long initSSHconnection(const char *username, const char *server_ip)
{
    long rc;
    struct sockaddr_in sin;
    char *userauthlist;
    struct libssh2_agent_publickey *identity, *prev_identity = NULL;
    
    rc = libssh2_init (0);
    
    if (rc != 0) {
        fprintf (stderr, "libssh2 initialization failed (%ld)\n", rc);
        return 1;
    }
    
    /* Ultra basic "connect to port 22 on localhost".  Your code is
     * responsible for creating the socket establishing the connection
     */
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock == -1) {
        fprintf(stderr, "failed to create socket!\n");
        rc = 1;
        go_shutdown();
    }
    
    sin.sin_family = AF_INET;
    sin.sin_port = htons(22);
    sin.sin_addr.s_addr = inet_addr(server_ip);
    if (connect(sock, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in)) != 0) {
        fprintf(stderr, "failed to connect!\n");
        go_shutdown();
    }
    
    /* Create a session instance and start it up. This will trade welcome
     * banners, exchange keys, and setup crypto, compression, and MAC layers
     */
    session = libssh2_session_init();
    
    if (libssh2_session_handshake(session, sock)) {
        
        fprintf(stderr, "Failure establishing SSH session\n");
        return 1;
    }
    
    /* check what authentication methods are available */
    userauthlist = libssh2_userauth_list(session, username, (int)strlen(username));
    
    fprintf(stderr, "Authentication methods: %s\n", userauthlist);
    if (strstr(userauthlist, "publickey") == NULL) {
        fprintf(stderr, "\"publickey\" authentication is not supported\n");
        go_shutdown();
    }
    
    /* Connect to the ssh-agent */
    agent = libssh2_agent_init(session);
    
    if (!agent) {
        fprintf(stderr, "Failure initializing ssh-agent support\n");
        rc = 1;
        go_shutdown();
    }
    if (libssh2_agent_connect(agent)) {
        
        fprintf(stderr, "Failure connecting to ssh-agent\n");
        rc = 1;
        go_shutdown();
    }
    if (libssh2_agent_list_identities(agent)) {
        
        fprintf(stderr, "Failure requesting identities to ssh-agent\n");
        rc = 1;
        go_shutdown();
    }
    while (1) {
        rc = libssh2_agent_get_identity(agent, &identity, prev_identity);
        
        if (rc == 1)
            break;
        if (rc < 0) {
            fprintf(stderr, "Failure obtaining identity from ssh-agent support\n");
            rc = 1;
            go_shutdown();
        }
        if (libssh2_agent_userauth(agent, username, identity)) {
            
            fprintf(stderr, "\tAuthentication with username %s and " "public key %s failed!\n", username, identity->comment);
        } else {
            fprintf(stderr, "\tAuthentication with username %s and " "public key %s succeeded!\n", username, identity->comment);
            break;
        }
        prev_identity = identity;
    }
    if (rc) {
        fprintf(stderr, "Couldn't continue authentication\n");
        go_shutdown();
    }
    
    /* We're authenticated now. */
    
    /* Request a shell */
    if (!(channel = libssh2_channel_open_session(session))) {
        
        fprintf(stderr, "Unable to open a session\n");
        go_shutdown();
    }
    
    /* Some environment variables may be set,
     * It's up to the server which ones it'll allow though
     */
    libssh2_channel_setenv(channel, "FOO", "bar");
    
    
    /* Request a terminal with 'vanilla' terminal emulation
     * See /etc/termcap for more options
     */
    if (libssh2_channel_request_pty(channel, "vanilla")) {
        
        fprintf(stderr, "Failed requesting pty\n");
        drop_shell();
    }
    
    /* Open a SHELL on that pty */
    if (libssh2_channel_shell(channel)) {
        
        fprintf(stderr, "Unable to request shell on allocated pty\n");
        go_shutdown();
    }
    
    /* At this point the shell can be interacted with using
     * libssh2_channel_read()
     * libssh2_channel_read_stderr()
     * libssh2_channel_write()
     * libssh2_channel_write_stderr()
     *
     * Blocking mode may be (en|dis)abled with: libssh2_channel_set_blocking()
     * If the server send EOF, libssh2_channel_eof() will return non-0
     * To send EOF to the server use: libssh2_channel_send_eof()
     * A channel can be closed with: libssh2_channel_close()
     * A channel can be freed with: libssh2_channel_free()
     */
    
    long bytes = 0;
    char buffer[2048];
    bytes = libssh2_channel_read(channel, (char *)&buffer, sizeof(buffer));
    if (bytes > 0) {
        buffer[bytes] = 0;
        printf("Server response:\n %s\n", buffer);
    }
    
    return rc;
}

void go_shutdown() {
    libssh2_agent_disconnect(agent);
    
    libssh2_agent_free(agent);
    
    if(session) {
        libssh2_session_disconnect(session, "Normal Shutdown, Thank you for playing");
        libssh2_session_free(session);
        
    }
    
    if (sock != -1) {
        close(sock);
    }
    fprintf(stderr, "all done!\n");
    libssh2_exit();
}

void drop_shell() {
    if (channel) {
        libssh2_channel_free(channel);
        channel = NULL;
    }
    
    /* Other channel types are supported via:
     * libssh2_scp_send()
     * libssh2_scp_recv()
     * libssh2_channel_direct_tcpip()
     */
    
}

const char * callSSHcommand(const char *command)
{
    /* Exec non-blocking on the remove host */
    while( (channel = libssh2_channel_open_session(session)) == NULL && libssh2_session_last_error(session,NULL,NULL,0) == LIBSSH2_ERROR_EAGAIN )
    {
        waitsocket(sock, session);
    }
    if( channel == NULL )
    {
        fprintf(stderr,"Error\n");
        exit( 1 );
    }
    
    while( (rc = libssh2_channel_exec(channel, command)) == LIBSSH2_ERROR_EAGAIN )
    {
        waitsocket(sock, session);
    }
    if( rc != 0 ) {
        fprintf(stderr,"Error\n");
        exit( 1 );
    }
    char cmd_buffer[0x4000];
    for( ;; )
    {
        /* loop until we block */
        do
        {
            rc = libssh2_channel_read( channel, cmd_buffer, sizeof(cmd_buffer) );
        }
        while( rc > 0 );
        
        /* this is due to blocking that would occur otherwise so we loop on this condition */
        if( rc == LIBSSH2_ERROR_EAGAIN )
        {
            waitsocket(sock, session);
        }
        else
            break;
    }
    const char *callback = cmd_buffer;
    return callback;
}

@end
