//
//  sshConnect.h
//  FileBrowser
//
//  Created by Super User on 20.08.13.
//  Copyright (c) 2013 KAjohansen. All rights reserved.
//
#import <Foundation/Foundation.h>

#include <stdio.h>

#include <libssh2.h>
#include <libssh2_sftp.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <arpa/inet.h>

#include <sys/types.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>

#import <Foundation/Foundation.h>

@interface sshConnect : NSObject

long initSSHconnection(const char *username, const char *server_ip);
const char * callSSHcommand(const char *command);
void go_shutdown();
void drop_shell();

@end
