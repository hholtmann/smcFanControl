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
#define MODULE_PATH "/Library/Application Support/smcFanControl2/DisableTurboBoost.64bits.kext"
#define LAUNCH_DAEMON_PLIST_PATH "/Library/LaunchDaemons/com.tinkernels.tb-switcher.plist"
#define TB_SWITCHER_BIN_PATH "/Library/Application Support/smcFanControl2/tb-switcher"
#define SOCK_ADDR "127.0.0.1"
#define SOCK_PORT 11532
#define MAX_LEN 1024

int start_server(void);

int enable_tb(void);

int disable_tb(void);

#endif /* tb_switcher_h */
