//
//  tb-switcher.h
//  smcFanControl
//
//  Created by Don Johnny on 2020/5/27.
//

#ifndef tb_switcher_h
#define tb_switcher_h

#define ENABLE_TB_CMD "ENABLE_TB"
#define DISABLE_TB_CMD "DISABLE_TB"
#define SOCK_PATH "/var/run/tb-switcher.socket"

int start_server(void);

int enable_tb(void);

int disable_tb(void);

#endif /* tb_switcher_h */
