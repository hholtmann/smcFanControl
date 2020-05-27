/*
 *	FanControl
 *
 *	Copyright (c) 2006-2012 Hendrik Holtmann
 *  Portions Copyright (c) 2013 Michael Wilber
 *
 *	FanControl.m - MacBook(Pro) FanControl application
 *
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; either version 2 of the License, or
 *	(at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program; if not, write to the Free Software
 *	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */


#import "FanControl.h"
#import <Sparkle/SUUpdater.h>
#import "Privilege.h"
#import "tb-switcher.h"

@interface FanControl ()
+ (void)copyMachinesIfNecessary;

@property(NS_NONATOMIC_IOSONLY, getter=isInAutoStart, readonly) BOOL inAutoStart;

- (void)setStartAtLogin:(BOOL)enabled;
@end

@implementation FanControl

// Number of fans reported by the hardware.
int g_numFans = 0;

NSUserDefaults *defaults;

#pragma mark **Init-Methods**

+ (void)initialize {

    //avoid Zombies when starting external app
    signal(SIGCHLD, SIG_IGN);

    [FanControl copyMachinesIfNecessary];
    //check owner and suid rights
    [FanControl setRights];

    //talk to smc
    [smcWrapper init];

    //app in foreground for update notifications
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

}

+ (void)copyMachinesIfNecessary {
    NSString *path = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"Machines.plist"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"Machines" ofType:@"plist"] toPath:path error:nil];
    }
}

- (void)upgradeFavorites {
    //upgrade favorites
    NSArray *rfavorites = [FavoritesController arrangedObjects];
    int j;
    int i;
    for (i = 0; i < [rfavorites count]; i++) {
        BOOL selected = NO;
        NSArray *fans = rfavorites[i][PREF_FAN_ARRAY];
        for (j = 0; j < [fans count]; j++) {
            if ([fans[j][PREF_FAN_SHOWMENU] boolValue] == YES) {
                selected = YES;
            }
        }
        if (selected == NO) {
            rfavorites[i][PREF_FAN_ARRAY][0][PREF_FAN_SHOWMENU] = @YES;
        }
    }

}

- (void)awakeFromNib {

    pw = [[Power alloc] init];
    [pw setDelegate:self];
    [pw registerForSleepWakeNotification];
    [pw registerForPowerChange];


    //load defaults

    [DefaultsController setAppliesImmediately:NO];

    mdefaults = [[MachineDefaults alloc] init:nil];

    self.machineDefaultsDict = [[NSMutableDictionary alloc] initWithDictionary:[mdefaults get_machine_defaults]];

    NSMutableArray *favorites = [[NSMutableArray alloc] init];

    NSMutableDictionary *defaultFav = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"Default", PREF_FAN_TITLE,
                                                                                          [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:[[mdefaults get_machine_defaults] objectForKey:@"Fans"]]], PREF_FAN_ARRAY, nil];

    [favorites addObject:defaultFav];


    NSRange range = [[MachineDefaults computerModel] rangeOfString:@"MacBook"];
    if (range.length > 0) {
        //for macbooks add a second default
        NSMutableDictionary *higherFav = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"Higher RPM", PREF_FAN_TITLE,
                                                                                             [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:[[mdefaults get_machine_defaults] objectForKey:@"Fans"]]], PREF_FAN_ARRAY, nil];
        for (NSUInteger i = 0; i < [_machineDefaultsDict[@"Fans"] count]; i++) {

            int min_value = ([[[[_machineDefaultsDict objectForKey:@"Fans"] objectAtIndex:i] objectForKey:PREF_FAN_MINSPEED] intValue]) * 2;
            [[[higherFav objectForKey:PREF_FAN_ARRAY] objectAtIndex:i] setObject:[NSNumber numberWithInt:min_value] forKey:PREF_FAN_SELSPEED];
        }
        [favorites addObject:higherFav];

    }

    //sync option for Macbook Pro's
    NSRange range_mbp = [[MachineDefaults computerModel] rangeOfString:@"MacBookPro"];
    if (range_mbp.length > 0 && [_machineDefaultsDict[@"Fans"] count] == 2) {
        [sync setHidden:NO];
    }

    //load user defaults
    defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @0, PREF_TEMP_UNIT,
            @0, PREF_SELECTION_DEFAULT,
                @NO, PREF_AUTOSTART_ENABLED,
                @NO, PREF_AUTOMATIC_CHANGE,
            @0, PREF_BATTERY_SELECTION,
            @0, PREF_AC_SELECTION,
            @0, PREF_CHARGING_SELECTION,
            @0, PREF_MENU_DISPLAYMODE,
            @"TC0D", PREF_TEMPERATURE_SENSOR,
            @0, PREF_NUMBEROF_LAUNCHES,
                @NO, PREF_DONATIONMESSAGE_DISPLAY,
            [NSArchiver archivedDataWithRootObject:[NSColor blackColor]], PREF_MENU_TEXTCOLOR,
            favorites, PREF_FAVORITES_ARRAY,
                nil]];


    g_numFans = [smcWrapper get_fan_num];
    s_menus = [[NSMutableArray alloc] init];
    int i;
    for (i = 0; i < g_numFans; i++) {
        NSMenuItem *mitem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Fan: %d", i] action:NULL keyEquivalent:@""];
        [mitem setTag:(i + 1) * 10];
        [s_menus insertObject:mitem atIndex:i];
    }

    [FavoritesController bind:@"content"
                     toObject:[NSUserDefaultsController sharedUserDefaultsController]
                  withKeyPath:[@"values." stringByAppendingString:PREF_FAVORITES_ARRAY]
                      options:nil];
    [FavoritesController setEditable:YES];

    // set slider sync - only for MBP
    for (i = 0; i < [[FavoritesController arrangedObjects] count]; i++) {
        if ([[FavoritesController arrangedObjects][i][PREF_FAN_SYNC] boolValue] == YES) {
            [FavoritesController setSelectionIndex:i];
            [self syncBinder:[[FavoritesController arrangedObjects][i][PREF_FAN_SYNC] boolValue]];
        }
    }

    //init statusitem
    [self init_statusitem];


    [programinfo setStringValue:[NSString stringWithFormat:@"%@ %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]
        , [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
    //
    [copyright setStringValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSHumanReadableCopyright"]];


    //power controls only available on portables
    if (range.length > 0) {
        [autochange setEnabled:true];
    } else {
        [autochange setEnabled:false];
    }
    [faqText replaceCharactersInRange:NSMakeRange(0, 0) withRTF:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"F.A.Q" ofType:@"rtf"]]];
    [self apply_settings:nil controllerindex:[[defaults objectForKey:PREF_SELECTION_DEFAULT] intValue]];
    [[[[theMenu itemWithTag:1] submenu] itemAtIndex:[[defaults objectForKey:PREF_SELECTION_DEFAULT] intValue]] setState:NSOnState];
    [[sliderCell dataCell] setControlSize:NSSmallControlSize];
    [self changeMenu:nil];

    //seting toolbar image
    menu_image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"smc" ofType:@"png"]];
    menu_image_alt = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"smcover" ofType:@"png"]];
    if ([menu_image respondsToSelector:@selector(setTemplate:)]) {
        [menu_image setTemplate:YES];
        [menu_image_alt setTemplate:YES];
    }

    //add timer for reading to RunLoop
    _readTimer = [NSTimer scheduledTimerWithTimeInterval:4.0 target:self selector:@selector(readFanData:) userInfo:nil repeats:YES];
    if ([_readTimer respondsToSelector:@selector(setTolerance:)]) {
        [_readTimer setTolerance:2.0];
    }
    [_readTimer fire];

    //autoapply settings if valid
    [self upgradeFavorites];

    //autostart
    [[NSUserDefaults standardUserDefaults] setValue:@([self isInAutoStart]) forKey:PREF_AUTOSTART_ENABLED];
    NSUInteger numLaunches = [[[NSUserDefaults standardUserDefaults] objectForKey:PREF_NUMBEROF_LAUNCHES] integerValue];
    [[NSUserDefaults standardUserDefaults] setObject:@(numLaunches + 1) forKey:PREF_NUMBEROF_LAUNCHES];
    if (numLaunches != 0 && (numLaunches % 3 == 0) && ![[[NSUserDefaults standardUserDefaults] objectForKey:PREF_DONATIONMESSAGE_DISPLAY] boolValue]) {
        [self displayDonationMessage];
    }

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(readFanData:) name:@"AppleInterfaceThemeChangedNotification" object:nil];

}

- (void)displayDonationMessage {
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Consider a donation", nil)
                                     defaultButton:NSLocalizedString(@"Donate over Paypal", nil) alternateButton:NSLocalizedString(@"Never ask me again", nil) otherButton:NSLocalizedString(@"Remind me later", nil)
                         informativeTextWithFormat:NSLocalizedString(@"smcFanControl keeps your Mac cool since 2006.\n\nIf smcFanControl is helfpul for you and you want to support further development, a small donation over Paypal is much appreciated.", nil)];
    NSModalResponse code = [alert runModal];
    if (code == NSAlertDefaultReturn) {
        [self paypal:nil];
        [[NSUserDefaults standardUserDefaults] setObject:@(YES) forKey:PREF_DONATIONMESSAGE_DISPLAY];
    } else if (code == NSAlertAlternateReturn) {
        [[NSUserDefaults standardUserDefaults] setObject:@(YES) forKey:PREF_DONATIONMESSAGE_DISPLAY];
    }
}

- (void)applyTurboBoost:(id)sender {
    NSControlStateValue state = [sender state];
    if (state == NSOffState) {
        [sender setState:NSOnState];
        enable_tb();
    } else {
        [sender setState:NSOffState];
        disable_tb();
    }
}

- (void)init_statusitem {
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:theMenu];

    if ([statusItem respondsToSelector:@selector(button)]) {
        [statusItem.button setTitle:@"smc..."];
    } else {
        [statusItem setEnabled:YES];
        [statusItem setHighlightMode:YES];
        [statusItem setTitle:@"smc..."];
    }
    int i;
    for (i = 0; i < [s_menus count]; i++) {
        [theMenu insertItem:s_menus[i] atIndex:i];
    };

    disable_tb();
    NSMenuItem *fan1Item = [theMenu itemWithTitle:@"Fan: 1"];
    int fan1ItemIdx = [theMenu indexOfItem:fan1Item];
    NSMenuItem *turboBoostItem = [[NSMenuItem alloc]
        initWithTitle:@"Turbo Boost"
               action:@selector(applyTurboBoost:)
        keyEquivalent:@""];
    [turboBoostItem setState:NSOffState];
    [turboBoostItem setEnabled:true];
    [turboBoostItem setTarget:self];
    [theMenu insertItem:turboBoostItem atIndex:fan1ItemIdx + 1];

    // Sign up for menuNeedsUpdate call
    // so that the fan speeds in the menu can be updated
    // only when needed.
    [theMenu setDelegate:self];
}

#pragma mark **Action-Methods**

- (IBAction)loginItem:(id)sender {
    if ([sender state] == NSOnState) {
        [self setStartAtLogin:YES];
    } else {
        [self setStartAtLogin:NO];
    }
}

- (IBAction)add_favorite:(id)sender {
    [[NSApplication sharedApplication] beginSheet:newfavoritewindow
                                   modalForWindow:mainwindow
                                    modalDelegate:nil
                                   didEndSelector:nil
                                      contextInfo:nil];
}

- (IBAction)close_favorite:(id)sender {
    [newfavoritewindow close];
    [[NSApplication sharedApplication] endSheet:newfavoritewindow];
}

- (IBAction)save_favorite:(id)sender {
    MachineDefaults *msdefaults = [[MachineDefaults alloc] init:nil];
    if ([[newfavorite_title stringValue] length] > 0) {
        NSMutableDictionary *toinsert = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[newfavorite_title stringValue], @"Title", [msdefaults get_machine_defaults][@"Fans"], PREF_FAN_ARRAY, nil]; //default as template
        [toinsert setValue:@0 forKey:@"Standard"];
        [FavoritesController addObject:toinsert];
        [newfavoritewindow close];
        [[NSApplication sharedApplication] endSheet:newfavoritewindow];
    }
    [self upgradeFavorites];
}


- (void)check_deletion:(id)combo {
    if ([FavoritesController selectionIndex] == [[defaults objectForKey:combo] intValue]) {
        [defaults setObject:@0 forKey:combo];
    }
}

- (void)deleteAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo; {
    if (returnCode == 0) {
        //delete favorite, but resets presets before
        [self check_deletion:PREF_BATTERY_SELECTION];
        [self check_deletion:PREF_AC_SELECTION];
        [self check_deletion:PREF_CHARGING_SELECTION];
        [FavoritesController removeObjects:[FavoritesController selectedObjects]];
    }
}

- (IBAction)delete_favorite:(id)sender {

    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Delete favorite", nil) defaultButton:NSLocalizedString(@"No", nil) alternateButton:NSLocalizedString(@"Yes", nil) otherButton:nil informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the favorite %@?", nil), [FavoritesController arrangedObjects][[FavoritesController selectionIndex]][@"Title"]]];

    [alert beginSheetModalForWindow:mainwindow modalDelegate:self didEndSelector:@selector(deleteAlertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}


// Called via a timer mechanism. This is where all the temp / RPM reading is done.
//reads fan data and updates the gui
- (void)readFanData:(id)caller {

    int i = 0;

    //on init handling
    if (_machineDefaultsDict == nil) {
        return;
    }

    // Determine what data is actually needed to keep the energy impact
    // as low as possible.
    bool bNeedTemp = false;
    bool bNeedRpm = false;
    const int menuBarSetting = [[defaults objectForKey:PREF_MENU_DISPLAYMODE] intValue];
    switch (menuBarSetting) {
        default:
        case 1:
            bNeedTemp = true;
            bNeedRpm = true;
            break;

        case 2:
            bNeedTemp = true;
            bNeedRpm = true;
            break;

        case 3:
            bNeedTemp = true;
            bNeedRpm = false;
            break;

        case 4:
            bNeedTemp = false;
            bNeedRpm = true;
            break;
    }

    NSString *temp = nil;
    NSString *fan = nil;
    float c_temp = 0.0f;
    int selectedRpm = 0;

    if (bNeedRpm == true) {
        // Read the current fan speed for the desired fan and format text for display in the menubar.
        NSArray *fans = [FavoritesController arrangedObjects][[FavoritesController selectionIndex]][PREF_FAN_ARRAY];
        for (i = 0; i < g_numFans && i < [fans count]; i++) {
            if ([fans[i][PREF_FAN_SHOWMENU] boolValue] == YES) {
                selectedRpm = [smcWrapper get_fan_rpm:i];
                break;
            }
        }

        NSNumberFormatter *nc = [[NSNumberFormatter alloc] init];
        //avoid jumping in menu bar
        [nc setFormat:@"000;000;-000"];

        fan = [NSString stringWithFormat:@"%@rpm", [nc stringForObjectValue:[NSNumber numberWithFloat:selectedRpm]]];
    }

    if (bNeedTemp == true) {
        // Read current temperature and format text for the menubar.
        c_temp = [smcWrapper get_maintemp];

        if ([[defaults objectForKey:PREF_TEMP_UNIT] intValue] == 0) {
            temp = [NSString stringWithFormat:@"%@%CC", @(c_temp), (unsigned short) 0xb0];
        } else {
            NSNumberFormatter *ncf = [[NSNumberFormatter alloc] init];
            [ncf setFormat:@"00;00;-00"];
            temp = [NSString stringWithFormat:@"%@%CF", [ncf stringForObjectValue:[@(c_temp) celsius_fahrenheit]], (unsigned short) 0xb0];
        }
    }

    // Update the temp and/or fan speed text in the menubar.
    NSMutableAttributedString *s_status = nil;
    NSMutableParagraphStyle *paragraphStyle = nil;

    NSColor *menuColor = (NSColor *) [NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:PREF_MENU_TEXTCOLOR]];
    BOOL setColor = NO;
    if (!([[menuColor colorUsingColorSpaceName:
        NSCalibratedWhiteColorSpace] whiteComponent] == 0.0) || ![statusItem respondsToSelector:@selector(button)])
        setColor = YES;


    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];

    if (osxMode && !setColor) {
        menuColor = [NSColor whiteColor];
        setColor = YES;
    }

    switch (menuBarSetting) {
        default:
        case 1: {
            int fsize = 0;
            NSString *add = nil;
            if (menuBarSetting == 0) {
                add = @"\n";
                fsize = 9;
                [statusItem setLength:53];
            } else {
                add = @" ";
                fsize = 11;
                [statusItem setLength:96];
            }

            s_status = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@%@", temp, add, fan]];
            paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
            [paragraphStyle setAlignment:NSLeftTextAlignment];
            [s_status addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Lucida Grande" size:fsize] range:NSMakeRange(0, [s_status length])];
            [s_status addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [s_status length])];

            if (setColor) [s_status addAttribute:NSForegroundColorAttributeName value:menuColor range:NSMakeRange(0, [s_status length])];


            if ([statusItem respondsToSelector:@selector(button)]) {
                [statusItem.button setAttributedTitle:s_status];
                [statusItem.button setImage:nil];
                [statusItem.button setAlternateImage:nil];
            } else {
                [statusItem setAttributedTitle:s_status];
                [statusItem setImage:nil];
                [statusItem setAlternateImage:nil];
            }
            break;
        }

        case 2:
            // TODO: Big waste of energy to update this tooltip every X seconds when the user
            // is unlikely to hover the smcFanControl icon over and over again.
            [statusItem setLength:26];
            if ([statusItem respondsToSelector:@selector(button)]) {
                [statusItem.button setTitle:nil];
                [statusItem.button setToolTip:[NSString stringWithFormat:@"%@\n%@", temp, fan]];
                [statusItem.button setImage:menu_image];
                [statusItem.button setAlternateImage:menu_image_alt];
            } else {
                [statusItem setTitle:nil];
                [statusItem setToolTip:[NSString stringWithFormat:@"%@\n%@", temp, fan]];
                [statusItem setImage:menu_image];
                [statusItem setAlternateImage:menu_image_alt];
            }
            break;

        case 3:
            [statusItem setLength:46];
            s_status = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", temp]];
            [s_status addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Lucida Grande" size:12] range:NSMakeRange(0, [s_status length])];
            if (setColor) [s_status addAttribute:NSForegroundColorAttributeName value:menuColor range:NSMakeRange(0, [s_status length])];
            if ([statusItem respondsToSelector:@selector(button)]) {
                [statusItem.button setAttributedTitle:s_status];
                [statusItem.button setImage:nil];
                [statusItem.button setAlternateImage:nil];
            } else {
                [statusItem setAttributedTitle:s_status];
                [statusItem setImage:nil];
                [statusItem setAlternateImage:nil];
            }
            break;

        case 4:
            [statusItem setLength:65];
            s_status = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", fan]];
            [s_status addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Lucida Grande" size:12] range:NSMakeRange(0, [s_status length])];
            if (setColor) [s_status addAttribute:NSForegroundColorAttributeName value:menuColor range:NSMakeRange(0, [s_status length])];
            if ([statusItem respondsToSelector:@selector(button)]) {
                [statusItem.button setAttributedTitle:s_status];
                [statusItem.button setImage:nil];
                [statusItem.button setAlternateImage:nil];
            } else {
                [statusItem setAttributedTitle:s_status];
                [statusItem setImage:nil];
                [statusItem setAlternateImage:nil];
            }
            break;
    }

}


- (IBAction)savePreferences:(id)sender {
    [(NSUserDefaultsController *) DefaultsController save:sender];
    [defaults setValue:[FavoritesController content] forKey:PREF_FAVORITES_ARRAY];
    [defaults synchronize];
    [mainwindow close];
    [self apply_settings:sender controllerindex:[FavoritesController selectionIndex]];
    undo_dic = [NSDictionary dictionaryWithDictionary:[defaults dictionaryRepresentation]];
}


- (IBAction)closePreferences:(id)sender {
    [mainwindow close];
    [DefaultsController revert:sender];
}


//set the new fan settings

- (void)apply_settings:(id)sender controllerindex:(int)cIndex {
    int i;
    [FanControl setRights];
    [FavoritesController setSelectionIndex:cIndex];

    if ([[MachineDefaults computerModel] rangeOfString:@"MacBookPro15"].location != NSNotFound) {
        for (i = 0; i < [[FavoritesController arrangedObjects][cIndex][PREF_FAN_ARRAY] count]; i++) {
            [smcWrapper setKey_external:[NSString stringWithFormat:@"F%dMd", i] value:@"01"];
            float f_val = [[FanController arrangedObjects][i][PREF_FAN_SELSPEED] floatValue];
            uint8 *vals = (uint8 *) &f_val;
            //NSString str_val = ;
            [smcWrapper setKey_external:[NSString stringWithFormat:@"F%dTg", i] value:[NSString stringWithFormat:@"%02x%02x%02x%02x", vals[0], vals[1], vals[2], vals[3]]];
        }
    } else {
        for (i = 0; i < [[FavoritesController arrangedObjects][cIndex][PREF_FAN_ARRAY] count]; i++) {
            [smcWrapper setKey_external:[NSString stringWithFormat:@"F%dMn", i] value:[[FanController arrangedObjects][i][PREF_FAN_SELSPEED] tohex]];
        }
    }

    NSMenu *submenu = [[NSMenu alloc] init];

    for (i = 0; i < [[FavoritesController arrangedObjects] count]; i++) {
        NSMenuItem *submenuItem = [[NSMenuItem alloc] initWithTitle:[FavoritesController arrangedObjects][i][@"Title"] action:@selector(apply_quickselect:) keyEquivalent:@""];
        [submenuItem setTag:i * 100]; //for later manipulation
        [submenuItem setEnabled:YES];
        [submenuItem setTarget:self];
        [submenuItem setRepresentedObject:[FavoritesController arrangedObjects][i]];
        [submenu addItem:submenuItem];
    }

    [[theMenu itemWithTag:1] setSubmenu:submenu];
    for (i = 0; i < [[[theMenu itemWithTag:1] submenu] numberOfItems]; i++) {
        [[[[theMenu itemWithTag:1] submenu] itemAtIndex:i] setState:NSOffState];
    }
    [[[[theMenu itemWithTag:1] submenu] itemAtIndex:cIndex] setState:NSOnState];
    [defaults setObject:@(cIndex) forKey:PREF_SELECTION_DEFAULT];
    //change active setting display
    [[theMenu itemWithTag:1] setTitle:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Active Setting", nil), [FavoritesController arrangedObjects][[FavoritesController selectionIndex]][PREF_FAN_TITLE]]];
}


- (void)apply_quickselect:(id)sender {
    int i;
    [FanControl setRights];
    //set all others items to off
    for (i = 0; i < [[[theMenu itemWithTag:1] submenu] numberOfItems]; i++) {
        [[[[theMenu itemWithTag:1] submenu] itemAtIndex:i] setState:NSOffState];
    }
    [sender setState:NSOnState];
    [[theMenu itemWithTag:1] setTitle:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Active Setting", nil), [sender title]]];
    [self apply_settings:sender controllerindex:[[[theMenu itemWithTag:1] submenu] indexOfItem:sender]];
}


- (void)terminate:(id)sender {
    //get last active selection
    [defaults synchronize];
    [smcWrapper cleanUp];
    [_readTimer invalidate];
    [pw deregisterForSleepWakeNotification];
    [pw deregisterForPowerChange];
    enable_tb();
    [[NSApplication sharedApplication] terminate:self];
}

- (IBAction)syncSliders:(id)sender {
    if ([sender state]) {
        [self syncBinder:YES];
    } else {
        [self syncBinder:NO];
    }
}


- (IBAction) changeMenu:(id)sender {
    if ([[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:PREF_MENU_DISPLAYMODE] intValue] == 2) {
        [colorSelector setEnabled:NO];
    } else {
        [colorSelector setEnabled:YES];
    }

}

- (IBAction)menuSelect:(id)sender {
    //deactivate all other radio buttons
    int i;
    for (i = 0; i < [[FanController arrangedObjects] count]; i++) {
        if (i != [sender selectedRow]) {
            [[FanController arrangedObjects][i] setValue:@NO forKey:PREF_FAN_SHOWMENU];
        }
    }
}

// Called when user clicks on smcFanControl status bar item
// in the status area of the menubar. The fan speed
// menu items are now only updated here in order to
// reduce the energy impact of -readFanData.
- (void)menuNeedsUpdate:(NSMenu *)menu {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (theMenu == menu) {
            if (_machineDefaultsDict == nil)
                return;

            int i;
            for (i = 0; i < g_numFans; ++i) {
                NSString *fandesc = _machineDefaultsDict[@"Fans"][i][@"Description"];
                [[theMenu itemWithTag:(i + 1) * 10] setTitle:[NSString stringWithFormat:@"%@: %@ rpm", fandesc, [@([smcWrapper get_fan_rpm:i]) stringValue]]];
            }
        }
    });
}


#pragma mark **Helper-Methods**

//just a helper to bringt update-info-window to the front
- (IBAction)updateCheck:(id)sender {
    SUUpdater *updater = [[SUUpdater alloc] init];
    [updater checkForUpdates:sender];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}


- (void)performReset {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSError *error;
    NSString *machinesPath = [[fileManager applicationSupportDirectory] stringByAppendingPathComponent:@"Machines.plist"];
    [fileManager removeItemAtPath:machinesPath error:&error];
    if (error) {
        NSLog(@"Error deleting %@", machinesPath);
    }
    error = nil;
    if ([[MachineDefaults computerModel] rangeOfString:@"MacBookPro15"].location != NSNotFound) {
        for (int i = 0; i < [[FavoritesController arrangedObjects][0][PREF_FAN_ARRAY] count]; i++) {
            [smcWrapper setKey_external:[NSString stringWithFormat:@"F%dMd", i] value:@"00"];
        }
    }

    NSString *domainName = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domainName];


    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Shutdown required", nil)
                                     defaultButton:NSLocalizedString(@"OK", nil) alternateButton:nil otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"Please shutdown your computer now to return to default fan settings.", nil)];
    NSModalResponse code = [alert runModal];
    if (code == NSAlertDefaultReturn) {
        [[NSApplication sharedApplication] terminate:self];
    }
}

- (IBAction)resetSettings:(id)sender {
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Reset Settings", nil)
                                     defaultButton:NSLocalizedString(@"Yes", nil) alternateButton:NSLocalizedString(@"No", nil) otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"Do you want to reset smcFanControl to default settings? Favorites will be deleted and fans will return to default speed.", nil)];
    NSModalResponse code = [alert runModal];
    if (code == NSAlertDefaultReturn) {
        [self performReset];
    } else if (code == NSAlertAlternateReturn) {

    }

}

- (IBAction)visitHomepage:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.eidac.de/products"]];
}


- (IBAction)paypal:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=holtmann%40campus%2dvirtuell%2ede&no_shipping=0&no_note=1&tax=0&currency_code=EUR&bn=PP%2dDonationsBF&charset=UTF%2d8&country=US"]];
}

- (void)syncBinder:(Boolean)bind {
    //in case plist is corrupt, don't bind
    if ([[FanController arrangedObjects] count] > 1) {
        if (bind == YES) {
            [[FanController arrangedObjects][1] bind:PREF_FAN_SELSPEED toObject:[FanController arrangedObjects][0] withKeyPath:PREF_FAN_SELSPEED options:nil];
            [[FanController arrangedObjects][0] bind:PREF_FAN_SELSPEED toObject:[FanController arrangedObjects][1] withKeyPath:PREF_FAN_SELSPEED options:nil];
        } else {
            [[FanController arrangedObjects][1] unbind:PREF_FAN_SELSPEED];
            [[FanController arrangedObjects][0] unbind:PREF_FAN_SELSPEED];
        }
    }
}


#pragma mark **Power Watchdog-Methods**

- (void)systemDidWakeFromSleep:(id)sender {
    [self apply_settings:nil controllerindex:[[defaults objectForKey:PREF_SELECTION_DEFAULT] intValue]];

    if ([[theMenu itemWithTitle:@"Turbo Boost"] state] == NSOnState) {
        enable_tb();
    } else {
        disable_tb();
    }
}


- (void)powerChangeToBattery:(id)sender {

    if ([[defaults objectForKey:@"AutomaticChange"] boolValue] == YES) {
        [self apply_settings:nil controllerindex:[[defaults objectForKey:PREF_BATTERY_SELECTION] intValue]];
    }
}

- (void)powerChangeToAC:(id)sender {
    if ([[defaults objectForKey:@"AutomaticChange"] boolValue] == YES) {
        [self apply_settings:nil controllerindex:[[defaults objectForKey:PREF_AC_SELECTION] intValue]];

    }
}

- (void)powerChangeToACLoading:(id)sender {
    if ([[defaults objectForKey:@"AutomaticChange"] boolValue] == YES) {
        [self apply_settings:nil controllerindex:[[defaults objectForKey:PREF_CHARGING_SELECTION] intValue]];

    }
}


#pragma mark -
#pragma mark Start-at-login control

- (BOOL)isInAutoStart {
    BOOL found = NO;
    LSSharedFileListRef loginItems = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListSessionLoginItems, /*options*/ NULL);
    NSString *path = [[NSBundle mainBundle] bundlePath];
    CFURLRef URLToToggle = (__bridge CFURLRef) [NSURL fileURLWithPath:path];
    //LSSharedFileListItemRef existingItem = NULL;

    UInt32 seed = 0U;
    NSArray *currentLoginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItems, &seed));

    for (id itemObject in currentLoginItems) {
        LSSharedFileListItemRef item = (__bridge LSSharedFileListItemRef) itemObject;

        UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
        CFURLRef URL = NULL;
        OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
        if (err == noErr) {
            Boolean foundIt = CFEqual(URL, URLToToggle);
            CFRelease(URL);

            if (foundIt) {
                //existingItem = item;
                found = YES;
                break;
            }
        }
    }
    return found;
}

- (void)setStartAtLogin:(BOOL)enabled {

    LSSharedFileListRef loginItems = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListSessionLoginItems, /*options*/ NULL);


    NSString *path = [[NSBundle mainBundle] bundlePath];

    OSStatus status;
    CFURLRef URLToToggle = (__bridge CFURLRef) [NSURL fileURLWithPath:path];
    LSSharedFileListItemRef existingItem = NULL;

    UInt32 seed = 0U;
    NSArray *currentLoginItems = CFBridgingRelease(LSSharedFileListCopySnapshot(loginItems, &seed));

    for (id itemObject in currentLoginItems) {
        LSSharedFileListItemRef item = (__bridge LSSharedFileListItemRef) itemObject;

        UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
        CFURLRef URL = NULL;
        OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &URL, /*outRef*/ NULL);
        if (err == noErr) {
            Boolean foundIt = CFEqual(URL, URLToToggle);
            CFRelease(URL);

            if (foundIt) {
                existingItem = item;
                break;
            }
        }
    }

    if (enabled && (existingItem == NULL)) {
        NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:path];
        IconRef icon = NULL;
        FSRef ref;
        Boolean gotRef = CFURLGetFSRef(URLToToggle, &ref);
        if (gotRef) {
            status = GetIconRefFromFileInfo(&ref,
                /*fileNameLength*/ 0, /*fileName*/ NULL,
                kFSCatInfoNone, /*catalogInfo*/ NULL,
                kIconServicesNormalUsageFlag,
                &icon,
                /*outLabel*/ NULL);
            if (status != noErr)
                icon = NULL;
        }

        LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst, (__bridge CFStringRef) displayName, icon, URLToToggle, /*propertiesToSet*/ NULL, /*propertiesToClear*/ NULL);
    } else if (!enabled && (existingItem != NULL))
        LSSharedFileListItemRemove(loginItems, existingItem);
}

#pragma mark **SMC-Binary Owner/Right Check**

+ (void) ensureService {
    NSString *tool = @"/bin/launchctl";
    NSArray *argsArray = @[@"load", @LAUNCH_DAEMON_PLIST_PATH];
    NSString *output;
    NSString *error;

    if([Privilege runProcessAsAdministrator:tool withArguments:argsArray output:&output errorDescription:&error]){
        NSLog(@"output: %@", output);
    }else{
        NSLog(@"error: %@", error);
    }
}

//TODO: It looks like this function is called inefficiently.
//call smc binary with sudo rights and apply
+ (void)setRights {
    NSString *smcPath = [[NSBundle mainBundle] pathForResource:@"smc" ofType:@""];
    NSFileManager *fManger = [NSFileManager defaultManager];
    NSDictionary *fdic = [fManger attributesOfItemAtPath:smcPath error:nil];
    if ([[fdic valueForKey:@"NSFileOwnerAccountName"] isEqualToString:@"root"] &&
        [[fdic valueForKey:@"NSFileGroupOwnerAccountName"] isEqualToString:@"admin"] &&
        ([[fdic valueForKey:@"NSFilePosixPermissions"] intValue] == 3437)) {
        // If the SMC binary has already been modified to run as root, then do nothing.

    } else {
        NSString *tool = @"/usr/sbin/chown";
        NSArray *argsArray = @[@"root:admin", smcPath];
        [Privilege runTaskAsAdmin:tool andArgs:argsArray];

        //second call for suid-bit
        tool = @"/bin/chmod";
        argsArray = @[@"6555", smcPath];
        [Privilege runTaskAsAdmin:tool andArgs:argsArray];
    }

    NSString *modulePath = [[NSBundle mainBundle] pathForResource:@"DisableTurboBoost.64bits" ofType:@"kext"];
    if (![fManger fileExistsAtPath:@MODULE_PATH]) {
        NSString *tool = @"/bin/sh";
        NSArray *argsArray = @[@"-c", [NSString stringWithFormat:@"mkdir -p \"%@\" && cp -Rf \"%@/\" \"%@\"",
            @MODULE_PATH, modulePath, @MODULE_PATH]];
        [Privilege runTaskAsAdmin:tool andArgs:argsArray];
        [self setOwnAndMod:@MODULE_PATH user:@"root" group:@"wheel" mod:@"755"];
    }

    NSString *binPath = [[NSBundle mainBundle] pathForResource:@"tb-switcher" ofType:@""];
    if (![fManger fileExistsAtPath:@TB_SWITCHER_BIN_PATH]) {
        NSString *tool = @"/bin/sh";
        NSArray *argsArray = @[@"-c", [NSString stringWithFormat:@"cp -f \"%@\" \"%@\"",
                                                                 binPath, @TB_SWITCHER_BIN_PATH]];
        [Privilege runTaskAsAdmin:tool andArgs:argsArray];
        [self setOwnAndMod:@TB_SWITCHER_BIN_PATH user:@"root" group:@"wheel" mod:@"755"];
    }

    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"com.tinkernels.tb-switcher" ofType:@"plist"];
    if (![fManger fileExistsAtPath:@LAUNCH_DAEMON_PLIST_PATH]) {
        NSString *tool = @"/bin/sh";
        NSArray *argsArray = @[@"-c", [NSString stringWithFormat:@"cp -f \"%@\" \"%@\"",
            plistPath, @LAUNCH_DAEMON_PLIST_PATH]];
        [Privilege runTaskAsAdmin:tool andArgs:argsArray];

        [self setOwnAndMod:@LAUNCH_DAEMON_PLIST_PATH user:@"root" group:@"wheel" mod:@"644"];
        [self ensureService];
    }
}

+ (void)setOwnAndMod:(NSString *)path user:(NSString *)user group:(NSString *)group mod:(NSString *)mod {
    NSFileManager *fManger = [NSFileManager defaultManager];
    NSDictionary *fdict = [fManger attributesOfItemAtPath:path error:nil];
    if ([[fdict valueForKey:@"NSFileOwnerAccountName"] isEqualToString:user] &&
        [[fdict valueForKey:@"NSFileGroupOwnerAccountName"] isEqualToString:group]) {

    } else {
        NSString *tool = @"/usr/sbin/chown";
        NSArray *argsArray = @[@"-R", [NSString stringWithFormat:@"%@:%@", user, group], path];

        [Privilege runTaskAsAdmin:tool andArgs:argsArray];

        tool = @"/bin/chmod";
        argsArray = @[@"-Rf", mod, path];
        [Privilege runTaskAsAdmin:tool andArgs:argsArray];
    }
}


- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

@end

@implementation NSNumber (NumberAdditions)

- (NSString *)tohex {
    return [NSString stringWithFormat:@"%0.4x", [self intValue] << 2];
}


- (NSNumber *)celsius_fahrenheit {
    float celsius = [self floatValue];
    float fahrenheit = (celsius * 9) / 5 + 32;
    return @(fahrenheit);
}

@end



