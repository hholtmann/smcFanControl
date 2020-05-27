//
//  tb-switcher_s.c
//  tb-switcher
//
//  Created by Don Johnny on 2020/5/27.
//

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
#include <arpa/inet.h>
#include<signal.h>
#include "tb-switcher.h"

#undef    sock_errno
#define sock_errno()    errno

int fd_sock;

void handle_sig_before_exit(int sig) {
    printf("Caught signal %d\n", sig);
    close(fd_sock);
    exit(0);
}

int exec_enable_tb(){
    printf("start enable turbo boost.\n");
    char cmd_enable_tb[512];
    sprintf(cmd_enable_tb, "kextunload \"%s\"", MODULE_PATH);
    printf("enable turboot command: %s\n", cmd_enable_tb);
    system(cmd_enable_tb);
    return 0;
}

int exec_disable_tb(){
    printf("start disable turbo boost.\n");
    char cmd_disable_tb[512];
    sprintf(cmd_disable_tb, "kextutil -v \"%s\"", MODULE_PATH);
    printf("enable turboot command: %s\n", cmd_disable_tb);
    system(cmd_disable_tb);
    return 0;
}


int start_server() {
    char buffer[MAX_LEN];

    struct sockaddr_in serv_addr, cli_addr;
    ssize_t len_rc_data;
    socklen_t len_cli_addr;

    // Creating socket file descriptor
    if ((fd_sock = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
        printf("CREATE ERROR = %d\n", sock_errno());
        exit(EXIT_FAILURE);
    }

    memset(&serv_addr, 0, sizeof(serv_addr));
    memset(&cli_addr, 0, sizeof(cli_addr));

    // Filling server information
    serv_addr.sin_family = AF_INET; // IPv4
    inet_pton(AF_INET, SOCK_ADDR, &serv_addr.sin_addr);
    serv_addr.sin_port = htons(SOCK_PORT);

    // Bind the socket with the server address
    if (bind(fd_sock, (const struct sockaddr *) &serv_addr,
        sizeof(serv_addr)) < 0) {
        printf("BIND ERROR = %d\n", sock_errno());
        exit(EXIT_FAILURE);
    }
    printf("LISTEN ON UDP: %s:%i\n", SOCK_ADDR, SOCK_PORT);
    signal(SIGINT, handle_sig_before_exit);
    signal(SIGQUIT, handle_sig_before_exit);

    len_cli_addr = sizeof(cli_addr);

    while(fd_sock >= 0) {
        len_rc_data = recvfrom(fd_sock, (char *) buffer, MAX_LEN,
            MSG_WAITALL, (struct sockaddr *) &cli_addr,
            &len_cli_addr);
        buffer[len_rc_data] = '\0';
        printf("Client CMD: %s", buffer);

        if (strncasecmp(buffer, ENABLE_TB_CMD, strlen(ENABLE_TB_CMD)) == 0){
            exec_enable_tb();
        }else if (strncasecmp(buffer, DISABLE_TB_CMD, strlen(DISABLE_TB_CMD)) == 0){
            exec_disable_tb();
        }
    }
    /*****************************/
    /* Close the socket and exit */
    /*****************************/
    close(fd_sock);

    return 0;
}


