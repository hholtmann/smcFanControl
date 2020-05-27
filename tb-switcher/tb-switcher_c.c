//
//  tb-switcher_c.c
//  smcFanControl
//
//  Created by Don Johnny on 2020/5/27.
//

/************************************************************/
/* This is a datagram socket client sample program for UNIX */
/* domain sockets. This program creates a socket and sends  */
/* data to a server.                                        */
/************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>

#include "tb-switcher.h"

#undef    sock_errno
#define sock_errno()    errno

int send_cmd(char *cmd) {
    int fd_sock;
    char buffer[MAX_LEN];
    strcpy(buffer, cmd);
    struct sockaddr_in serv_addr;

    // Creating socket file descriptor
    if ((fd_sock = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
        perror("socket creation failed");
        exit(EXIT_FAILURE);
    }

    memset(&serv_addr, 0, sizeof(serv_addr));

    // Filling server information
    serv_addr.sin_family = AF_INET; // IPv4
    inet_pton(AF_INET, SOCK_ADDR, &serv_addr.sin_addr);
    serv_addr.sin_port = htons(SOCK_PORT);

    sendto(fd_sock, (const char *) buffer, strlen(buffer),
        0, (const struct sockaddr *) &serv_addr,
        sizeof(serv_addr));

    close(fd_sock);
    return 0;
}

int enable_tb() {
    send_cmd(ENABLE_TB_CMD);
    return 0;
};

int disable_tb() {
    send_cmd(DISABLE_TB_CMD);
    return 0;
};