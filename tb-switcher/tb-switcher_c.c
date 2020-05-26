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
#include <errno.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include "tb-switcher.h"

#undef    sock_errno
#define sock_errno()    errno

int client() {
    int client_socket;
    ssize_t rc;
    struct sockaddr_un remote;
    char buf[256];
    memset(&remote, 0, sizeof(struct sockaddr_un));

    /****************************************/
    /* Create a UNIX domain datagram socket */
    /****************************************/
    client_socket = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (client_socket == -1) {
        printf("SOCKET ERROR = %d\n", sock_errno());
        exit(1);
    }

    /***************************************/
    /* Set up the UNIX sockaddr structure  */
    /* by using AF_UNIX for the family and */
    /* giving it a filepath to send to.    */
    /***************************************/
    remote.sun_family = AF_UNIX;
    strcpy(remote.sun_path, SOCK_PATH);

    /***************************************/
    /* Copy the data to be sent to the     */
    /* buffer and send it to the server.   */
    /***************************************/
    strcpy(buf, "DATA");
    printf("Sending data...\n");
    rc = sendto(client_socket, buf, strlen(buf), 0, (struct sockaddr *) &remote, sizeof(remote));
    if (rc == -1) {
        printf("SENDTO ERROR = %d\n", sock_errno());
        close(client_socket);
        exit(1);
    } else {
        printf("Data sent!\n");
    }

    /*****************************/
    /* Close the socket and exit */
    /*****************************/
    rc = close(client_socket);

    return 0;
}

int enable_tb() {
    return 0;
};

int disable_tb() {
    return 0;
};