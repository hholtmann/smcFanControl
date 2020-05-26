//
//  main.c
//  tb-switcher
//
//  Created by Don Johnny on 2020/5/27.
//

/************************************************************/
/* This is a datagram socket server sample program for UNIX */
/* domain sockets. This program creates a socket and        */
/* receives data from a client.                             */
/************************************************************/

#include "tb-switcher.h"

#undef    sock_errno
#define sock_errno()    errno

int main() {

    return start_server();

}
