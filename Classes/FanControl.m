/*
 *	FanControl
 *
 *	Copyright (c) 2006-2012 Hendrik Holtmann
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
#import "MachineDefaults.h"
#import <Security/Authorization.h>
#import <Security/AuthorizationDB.h>
#import <Security/AuthorizationTags.h>
#import "SystemVersion.h"

@implementation FanControl

io_connect_t conn;
kern_return_t result;
SMCVal_t      val;
NSUserDefaults *defaults;
Boolean supported=false;
extern char   *optarg;
SMCVal_t val;
OSStatus status;
NSDictionary* machine_defaults;
NSString *authpw;



#pragma mark **Init-Methods**

+(void) initialize {
    
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

+(void)copyMachinesIfNecessary
{
    NSString *path = [[[NSFileManager defaultManager] applicationSupportDirectory] stringByAppendingPathComponent:@"Machines.plist"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"Machines" ofType:@"plist"] toPath:path error:nil];
    }
}

-(void)upgradeFavorites
{
	//upgrade favorites
	NSArray *rfavorites = [FavoritesController arrangedObjects];
	int j;
	int i;
	for (i=0;i<[rfavorites count];i++)
	{
		BOOL selected = NO;
		NSArray *fans = [[rfavorites objectAtIndex:i] objectForKey:@"FanData"];
		for (j=0;j<[fans count];j++) {
			if ([[[fans objectAtIndex:j] objectForKey:@"menu"] boolValue] == YES ) {
				selected = YES;
			}
		}
		if (selected==NO) {
			[[[[rfavorites objectAtIndex:i] objectForKey:@"FanData"] objectAtIndex:0] setObject:[NSNumber numberWithBool:YES] forKey:@"menu"];
		}
	}
	
}

- (NSNumber*)hasNSUserNotification {
    BOOL hasNSUserNotification = (NSClassFromString(@"NSUserNotification") != nil);
    return [NSNumber numberWithBool:hasNSUserNotification];
}

-(void) awakeFromNib {
		
	s_sed = nil;
	pw=[[Power alloc] init];
	[pw setDelegate:self];
	[pw registerForSleepWakeNotification];
	[pw registerForPowerChange];
	
	//load defaults
	
	[DefaultsController setAppliesImmediately:NO];

	mdefaults=[[MachineDefaults alloc] init:nil];

	s_sed=[mdefaults copy_machine_defaults];

	
	NSMutableArray *favorites=[NSMutableArray arrayWithObjects:
							[NSMutableDictionary dictionaryWithObjectsAndKeys:
							@"Default", @"Title",
							[s_sed objectForKey:@"Fans"], @"FanData",nil],nil];
	NSRange range=[[MachineDefaults computerModel] rangeOfString:@"MacBook"];
	if (range.length>0) {
		//for macbooks add a second default
		MachineDefaults *msdefaults=[[MachineDefaults alloc] init:nil];
		NSMutableDictionary *sec_fav=[NSMutableDictionary dictionaryWithObjectsAndKeys:@"Higher RPM", @"Title",
							[[[msdefaults copy_machine_defaults] autorelease] objectForKey:@"Fans"], @"FanData",nil];
		[favorites addObject:sec_fav];	
		int i;					
		for (i=0;i<[[s_sed objectForKey:@"Fans"] count];i++) {
			int min_value=([[[[s_sed objectForKey:@"Fans"] objectAtIndex:i] valueForKey:@"Minspeed"] intValue])*2;
			[[[[favorites objectAtIndex:1] objectForKey:@"FanData"] objectAtIndex:i] setObject:[NSNumber numberWithInt:min_value] forKey:@"selspeed"];

		}
		[msdefaults release];
	}							

	//sync option for Macbook Pro's
	NSRange range_mbp=[[MachineDefaults computerModel] rangeOfString:@"MacBookPro"];
	if (range_mbp.length>0) {
		[sync setHidden:NO];
	}

	
	NSString *feedURL = nil;
	if ([SystemVersion isTiger]) {
		feedURL = @"http://www.eidac.de/smcfancontrol/smcfancontrol_tiger.xml";
	} else {
		feedURL = @"http://www.eidac.de/smcfancontrol/smcfancontrol.xml";
	}
																													
	//load user defaults
	defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:0], @"Unit",
			[NSNumber numberWithInt:0], @"SelDefault",
			[NSNumber numberWithBool:NO], @"AutoStart",
			[NSNumber numberWithBool:NO], @"AutomaticChange",
			[NSNumber numberWithBool:NO], @"NotificationCenter",
			[NSNumber numberWithInt:0],@"selbatt",
			[NSNumber numberWithInt:0],@"selac",
			[NSNumber numberWithInt:0],@"selload",
			[NSNumber numberWithInt:0],@"MenuBar",
			feedURL,@"SUFeedURL",
			[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],@"MenuColor",
			favorites,@"Favorites",
	nil]];
	
	

	
	s_menus=[[NSMutableArray alloc] init];
	[s_menus autorelease];
	int i;
	for(i=0;i<[smcWrapper get_fan_num];i++){
		NSMenuItem *mitem=[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Fan: %d",i] action:NULL keyEquivalent:@""];
		[mitem setTag:(i+1)*10];
		[s_menus insertObject:mitem atIndex:i];
		[mitem release];
	}
	
	[FavoritesController bind:@"content"
             toObject:[NSUserDefaultsController sharedUserDefaultsController]
          withKeyPath:@"values.Favorites"
              options:nil];
	[FavoritesController setEditable:YES];
	
	// set slider sync - only for MBP
	for (i=0;i<[[FavoritesController arrangedObjects] count];i++) {
		if([[[[FavoritesController arrangedObjects] objectAtIndex:i] objectForKey:@"sync"] boolValue]==YES) {
			[FavoritesController setSelectionIndex:i];
			[self syncBinder:[[[[FavoritesController arrangedObjects] objectAtIndex:i] objectForKey:@"sync"] boolValue]];
		}
	}

	//init statusitem
	[self init_statusitem];

	
	[programinfo setStringValue: [NSString stringWithFormat:@"%@ %@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]
	,[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ]];
	//
	[copyright setStringValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSHumanReadableCopyright"]];

	
	//power controls only available on portables
	if (range.length>0) {
		[autochange setEnabled:true];
	} else {
		[autochange setEnabled:false];
	}
	[faqText replaceCharactersInRange:NSMakeRange(0,0) withRTF: [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"F.A.Q" ofType:@"rtf"]]];
	[self apply_settings:nil controllerindex:[[defaults objectForKey:@"SelDefault"] intValue]];
	[[[[theMenu itemWithTag:1] submenu] itemAtIndex:[[defaults objectForKey:@"SelDefault"] intValue]] setState:NSOnState];
	[[sliderCell dataCell] setControlSize:NSSmallControlSize];
	[self changeMenu:nil];
	
	//seting toolbar image
	menu_image=[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"smc" ofType:@"png"]];
	menu_image_alt=[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"smcover" ofType:@"png"]];

	//release MachineDefaults class first call
	//add timer for reading to RunLoop
	_readTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(readFanData:) userInfo:nil repeats:YES];
	[_readTimer fire];
	//autoapply settings if valid
	[self upgradeFavorites];
    
    //autostart
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:[self isInAutoStart]] forKey:@"AutoStart"];
		
}


-(void)init_statusitem{
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength: NSVariableStatusItemLength] retain];
	[statusItem setMenu: theMenu];
	[statusItem setEnabled: YES];
	[statusItem setHighlightMode:YES];
	[statusItem setTitle:@"smc..."];
	int i;
	for(i=0;i<[s_menus count];i++) {
		[theMenu insertItem:[s_menus objectAtIndex:i] atIndex:i];
	};
}

#pragma mark **Action-Methods**
- (IBAction)loginItem:(id)sender{
	if ([sender state]==NSOnState) {
		[self setStartAtLogin:YES];
	} else {
        [self setStartAtLogin:NO];
	}
}

- (IBAction)add_favorite:(id)sender{
	[[NSApplication sharedApplication] beginSheet:newfavoritewindow
								   modalForWindow: mainwindow
									modalDelegate: nil
								   didEndSelector: nil
									  contextInfo: nil];
}

- (IBAction)close_favorite:(id)sender{
	[newfavoritewindow close];
	[[NSApplication sharedApplication] endSheet:newfavoritewindow];
}

- (IBAction)save_favorite:(id)sender{
	MachineDefaults *msdefaults=[[MachineDefaults alloc] init:nil];
	if ([[newfavorite_title stringValue] length]>0) {
		NSMutableDictionary *toinsert=[[NSMutableDictionary alloc] initWithObjectsAndKeys:[newfavorite_title stringValue],@"Title",[[[msdefaults copy_machine_defaults] autorelease] objectForKey:@"Fans"],@"FanData",nil]; //default as template
		[toinsert setValue:[NSNumber numberWithInt:0] forKey:@"Standard"];
		[FavoritesController addObject:toinsert];
		[toinsert release];
		[newfavoritewindow close];
		[[NSApplication sharedApplication] endSheet:newfavoritewindow];
	}
	[msdefaults release];
	[self upgradeFavorites];
}


-(void) check_deletion:(id)combo{
 if ([FavoritesController selectionIndex]==[[defaults objectForKey:combo] intValue]) {
	 [defaults setObject:[NSNumber numberWithInt:0] forKey:combo];
 }
}

- (IBAction)delete_favorite:(id)sender{
	int pressesButton=NSRunCriticalAlertPanelRelativeToWindow(
			NSLocalizedString(@"Delete favorite",nil),
			[NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the favorite %@?",nil), [ [ [FavoritesController arrangedObjects] objectAtIndex:[FavoritesController selectionIndex]] objectForKey:@"Title"] ],
			NSLocalizedString(@"No",nil),
			NSLocalizedString(@"Yes",nil),nil,mainwindow);
	if (pressesButton==0) {
		//delete favorite, but resets presets before
		[self check_deletion:@"selbatt"];
		[self check_deletion:@"selac"];
		[self check_deletion:@"selload"];
		[FavoritesController removeObjects:[FavoritesController selectedObjects]];
	}
}



//reads fan data and updates the gui
-(void) readFanData:(NSTimer*)timer{
	
	NSString *temp;
	NSString *fan;

	
	//on init handling
	if (s_sed==nil) {
		return;
	}
	
	//populate Menu Items with recent Data
	int i;
	for(i=0;i<[smcWrapper get_fan_num];i++){
		NSString *fandesc=[[[s_sed objectForKey:@"Fans"] objectAtIndex:i] objectForKey:@"Description"];
		[[theMenu itemWithTag:(i+1)*10] setTitle:[NSString stringWithFormat:@"%@: %@ rpm",fandesc,[[NSNumber numberWithInt:[smcWrapper get_fan_rpm:i]] stringValue]]];
	}
	
	
	float c_temp=[smcWrapper get_maintemp];
	if ([[defaults objectForKey:@"Unit"] intValue]==0) { 
		temp=[NSString stringWithFormat:@"%@%CC",[NSNumber numberWithFloat:c_temp],(unsigned short)0xb0];
	} else {
		NSNumberFormatter *ncf=[[[NSNumberFormatter alloc] init] autorelease];
		[ncf setFormat:@"00;00;-00"];
		temp=[NSString stringWithFormat:@"%@%CF",[ncf stringForObjectValue:[[NSNumber numberWithFloat:c_temp] celsius_fahrenheit]],(unsigned short)0xb0];
	}	
	NSNumberFormatter *nc=[[[NSNumberFormatter alloc] init] autorelease];
	//avoid jumping in menu bar
	[nc setFormat:@"000;000;-000"];
	
	int selected = 0;
	NSArray *fans = [[[FavoritesController arrangedObjects] objectAtIndex:[FavoritesController selectionIndex]] objectForKey:@"FanData"];
	for (i=0;i<[fans count];i++)
	{
		if ([[[fans objectAtIndex:i] objectForKey:@"menu"] boolValue]==YES) {
			selected = i;
		}
	}
	
	fan=[NSString stringWithFormat:@"%@rpm",[nc stringForObjectValue:[NSNumber numberWithFloat:[smcWrapper get_fan_rpm:selected]]]];

	if ([[defaults objectForKey:@"MenuBar"] intValue]<=1) { 
		NSString *add;
		int fsize;
		if ([[defaults objectForKey:@"MenuBar"] intValue]==0) {
			add=@"\n";
			fsize=9;
			[statusItem setLength:53];
		} else {
			add=@" ";
			fsize=11;
			[statusItem setLength:96];
		}
		NSMutableAttributedString *s_status=[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@%@",temp,add,fan]];
		NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[paragraphStyle setAlignment:NSLeftTextAlignment];
		[s_status addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Lucida Grande" size:fsize] range:NSMakeRange(0,[s_status length])];
		[s_status addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0,[s_status length])];
		[s_status addAttribute:NSForegroundColorAttributeName value:(NSColor*)[NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"MenuColor"]]  range:NSMakeRange(0,[s_status length])];
		[statusItem setAttributedTitle:s_status];
		[statusItem setImage:nil];
		[statusItem setAlternateImage:nil];
		[paragraphStyle release];
		[s_status release];
	}
	
	
	if ([[defaults objectForKey:@"MenuBar"] intValue]==2) {
		[statusItem setLength:26]; 
		[statusItem setTitle:nil];
		[statusItem setToolTip:[NSString stringWithFormat:@"%@\n%@",temp,fan]];
		[statusItem setImage:menu_image];
		[statusItem setAlternateImage:menu_image_alt];
		
	}

	if ([[defaults objectForKey:@"MenuBar"] intValue]==3) { 
		[statusItem setLength:46];
		NSMutableAttributedString *s_status=[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@",temp]];
		[s_status addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Lucida Grande" size:12] range:NSMakeRange(0,[s_status length])];
		[s_status addAttribute:NSForegroundColorAttributeName value:(NSColor*)[NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"MenuColor"]]  range:NSMakeRange(0,[s_status length])];
		[statusItem setAttributedTitle:s_status];
		[statusItem setImage:nil];
		[statusItem setAlternateImage:nil];
		[s_status release];

	}
	if ([[defaults objectForKey:@"MenuBar"] intValue]==4) { 
		[statusItem setLength:65];
		NSMutableAttributedString *s_status=[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@",fan]];
		[s_status addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Lucida Grande" size:12] range:NSMakeRange(0,[s_status length])];
		[s_status addAttribute:NSForegroundColorAttributeName value:(NSColor*)[NSUnarchiver unarchiveObjectWithData:[defaults objectForKey:@"MenuColor"]]  range:NSMakeRange(0,[s_status length])];
		[statusItem setAttributedTitle:s_status];
		[statusItem setImage:nil];
		[statusItem setAlternateImage:nil];
		[s_status release];
		
	}
    
    //--- NOTIFICATION CENTER
    BOOL postEnabled = [[defaults objectForKey:@"NotificationCenter"] boolValue];
    if(postEnabled) {
        [self sendNotificationIfNeeded:fan.doubleValue];
    }
}

- (void)sendNotificationIfNeeded:(double)newFanValue {
    //see if fans changed, have a static var to save old value
    static double _oldFanValue = NSNotFound;
    if(_oldFanValue == NSNotFound) {
        _oldFanValue = newFanValue;
        return;
    }

//    NSLog(@"%f - %f = %f", newFanValue, _oldFanValue, fabs(newFanValue - _oldFanValue));

    //check for change
    static BOOL _needsChangeOfSpeed = YES;
    if(_needsChangeOfSpeed) {
        BOOL changeWasNotBigEnough = fabs(newFanValue - _oldFanValue) < 500;
        if(changeWasNotBigEnough) {
//            NSLog(@"_needsChangeOfSpeed but changeWasNotBigEnough");
            return;
        }
        _needsChangeOfSpeed = NO;
        
        //save
        _oldFanValue = newFanValue;
//        NSLog(@"save");
        return;
    }
    
    //check for stability
    static BOOL _needsStability = YES;
    if(_needsStability) {
        BOOL changeWasTooBig = fabs(newFanValue - _oldFanValue) >= 500;
        if(changeWasTooBig) {
//            NSLog(@"_needsStability but changeWasTooBig");

            //save
            _oldFanValue = newFanValue;
//            NSLog(@"save");
            return;
        }
        _needsStability = NO;
    }
    
    //do notifications IF we want to
//    NSLog(@"Post %d", [[defaults objectForKey:@"NotificationCenter"] boolValue]);
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    NSUserNotification *note = [[NSUserNotification alloc] init];
    note.title = [NSString stringWithFormat:@"Fan at %f RPM", newFanValue];

    [NSApp deactivate]; //we need this because the center often doesnt present |note| when we are active
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];
    
    //save
    _oldFanValue = newFanValue;

    //reset
    _needsChangeOfSpeed = YES;
    _needsStability = YES;
}


- (IBAction)savePreferences:(id)sender{
	[(NSUserDefaultsController *)DefaultsController save:sender];
	[defaults setValue:[FavoritesController content] forKey:@"Favorites"];
	[defaults synchronize];
	[mainwindow close];
	[self apply_settings:sender controllerindex:[FavoritesController selectionIndex]];
	undo_dic=[NSDictionary dictionaryWithDictionary:[defaults dictionaryRepresentation]];
}



- (IBAction)closePreferences:(id)sender{
	[mainwindow close];
	[DefaultsController revert:sender];
}


//set the new fan settings

-(void)apply_settings:(id)sender controllerindex:(int)cIndex{
	int i;
	[FanControl setRights];
	[FavoritesController setSelectionIndex:cIndex];
	for (i=0;i<[[[[FavoritesController arrangedObjects] objectAtIndex:cIndex] objectForKey:@"FanData"] count];i++) {
		[smcWrapper setKey_external:[NSString stringWithFormat:@"F%dMn",i] value:[[[[FanController arrangedObjects] objectAtIndex:i] objectForKey:@"selspeed"] tohex]];
	}
	NSMenu *submenu = [[[NSMenu alloc] init] autorelease];
	
	for(i=0;i<[[FavoritesController arrangedObjects] count];i++){
		NSMenuItem *submenuItem = [[[NSMenuItem alloc] initWithTitle:[[[FavoritesController arrangedObjects] objectAtIndex:i] objectForKey:@"Title"] action:@selector(apply_quickselect:) keyEquivalent:@""] autorelease];
		[submenuItem setTag:i*100]; //for later manipulation
		[submenuItem setEnabled:YES];
		[submenuItem setTarget:self];
		[submenuItem setRepresentedObject:[[FavoritesController arrangedObjects] objectAtIndex:i]];
		[submenu addItem:submenuItem];
	}
	
	[[theMenu itemWithTag:1] setSubmenu:submenu];
	for (i=0;i<[[[theMenu itemWithTag:1] submenu] numberOfItems];i++) {
		[[[[theMenu itemWithTag:1] submenu] itemAtIndex:i] setState:NSOffState];
	}
	[[[[theMenu itemWithTag:1] submenu] itemAtIndex:cIndex] setState:NSOnState];
	[defaults setObject:[NSNumber numberWithInt:cIndex] forKey:@"SelDefault"];
	//change active setting display
	[[theMenu itemWithTag:1] setTitle:[NSString stringWithFormat:@"%@: %@",NSLocalizedString(@"Active Setting",nil),[ [ [FavoritesController arrangedObjects] objectAtIndex:[FavoritesController selectionIndex]] objectForKey:@"Title"] ]];
}



-(void)apply_quickselect:(id)sender{
	int i;
	[FanControl setRights];
	//set all others items to off
	for (i=0;i<[[[theMenu itemWithTag:1] submenu] numberOfItems];i++) {
		[[[[theMenu itemWithTag:1] submenu] itemAtIndex:i] setState:NSOffState];
	}
	[sender setState:NSOnState];
	[[theMenu itemWithTag:1] setTitle:[NSString stringWithFormat:@"%@: %@",NSLocalizedString(@"Active Setting",nil),[sender title]]];
	[self apply_settings:sender controllerindex:[[[theMenu itemWithTag:1] submenu] indexOfItem:sender]];
}

-(void)terminate:(id)sender{
	//get last active selection
	[defaults synchronize];
	SMCClose(conn);
	[_readTimer invalidate];
	[pw deregisterForSleepWakeNotification];
	[pw deregisterForPowerChange];
	[pw release];
	[menu_image release];
	[menu_image_alt release];
	//[mdefaults release];
	//[statusItem release];
	//[s_menus release];
	//[theMenu release];
	[[NSApplication sharedApplication] terminate:self];
}



- (IBAction)syncSliders:(id)sender{
	if ([sender state]) {
		[self syncBinder:YES];
	} else {
		[self syncBinder:NO];
	}
}


- (IBAction) changeMenu:(id)sender{
	if ([[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"MenuBar"] intValue]==2) {
		[colorSelector setEnabled:NO];
	} else {
		[colorSelector setEnabled:YES];
	}

}

- (IBAction)menuSelect:(id)sender{
	//deactivate all other radio buttons
	int i;
	for (i=0;i<[[FanController arrangedObjects] count];i++) {
		if (i!=[sender selectedRow]) {
			[[[FanController arrangedObjects] objectAtIndex:i] setValue:[NSNumber numberWithBool:NO] forKey:@"menu"];
		}	
	}
}	



#pragma mark **Helper-Methods**

//just a helper to bringt update-info-window to the front
- (IBAction)updateCheck:(id)sender{
	[updater checkForUpdates:sender];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
}

- (IBAction)visitHomepage:(id)sender{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.eidac.de/products"]];
}


- (IBAction)paypal:(id)sender{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=holtmann%40campus%2dvirtuell%2ede&no_shipping=0&no_note=1&tax=0&currency_code=EUR&bn=PP%2dDonationsBF&charset=UTF%2d8&country=US"]];
}

-(void) syncBinder:(Boolean)bind{
	//in case plist is corrupt, don't bind
	if ([[FanController arrangedObjects] count]>1 ) {
		if (bind==YES) {
			[[[FanController arrangedObjects] objectAtIndex:1] bind:@"selspeed" toObject:[[FanController arrangedObjects] objectAtIndex:0] withKeyPath:@"selspeed" options:nil];
			[[[FanController arrangedObjects] objectAtIndex:0] bind:@"selspeed" toObject:[[FanController arrangedObjects] objectAtIndex:1] withKeyPath:@"selspeed" options:nil];
		} else {
			[[[FanController arrangedObjects] objectAtIndex:1] unbind:@"selspeed"];
			[[[FanController arrangedObjects] objectAtIndex:0] unbind:@"selspeed"];
		}
	}	
}


#pragma mark **Power Watchdog-Methods**

- (void)systemDidWakeFromSleep:(id)sender{
	[self apply_settings:nil controllerindex:[[defaults objectForKey:@"SelDefault"] intValue]];
}


- (void)powerChangeToBattery:(id)sender{

	if ([[defaults objectForKey:@"AutomaticChange"] boolValue]==YES) {
		[self apply_settings:nil controllerindex:[[defaults objectForKey:@"selbatt"] intValue]];
	}
}

- (void)powerChangeToAC:(id)sender{
	if ([[defaults objectForKey:@"AutomaticChange"] boolValue]==YES) {
		[self apply_settings:nil controllerindex:[[defaults objectForKey:@"selac"] intValue]];

	}
}

- (void)powerChangeToACLoading:(id)sender{
	if ([[defaults objectForKey:@"AutomaticChange"] boolValue]==YES) {
		[self apply_settings:nil controllerindex:[[defaults objectForKey:@"selload"] intValue]];

	}	
}


#pragma mark -
#pragma mark Start-at-login control

- (BOOL)isInAutoStart
{
	BOOL found = NO;
	LSSharedFileListRef loginItems = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListSessionLoginItems, /*options*/ NULL);
	NSString *path = [[NSBundle mainBundle] bundlePath];
	CFURLRef URLToToggle = (CFURLRef)[NSURL fileURLWithPath:path];
	//LSSharedFileListItemRef existingItem = NULL;
	
	UInt32 seed = 0U;
	NSArray *currentLoginItems = [NSMakeCollectable(LSSharedFileListCopySnapshot(loginItems, &seed)) autorelease];
	
	for (id itemObject in currentLoginItems) {
		LSSharedFileListItemRef item = (LSSharedFileListItemRef)itemObject;
		
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

- (void) setStartAtLogin:(BOOL)enabled {
    
	LSSharedFileListRef loginItems = LSSharedFileListCreate(kCFAllocatorDefault, kLSSharedFileListSessionLoginItems, /*options*/ NULL);
    
	
	NSString *path = [[NSBundle mainBundle] bundlePath];
	
	OSStatus status;
	CFURLRef URLToToggle = (CFURLRef)[NSURL fileURLWithPath:path];
	LSSharedFileListItemRef existingItem = NULL;
	
	UInt32 seed = 0U;
	NSArray *currentLoginItems = [NSMakeCollectable(LSSharedFileListCopySnapshot(loginItems, &seed)) autorelease];
	
	for (id itemObject in currentLoginItems) {
		LSSharedFileListItemRef item = (LSSharedFileListItemRef)itemObject;
		
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
		
		LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst, (CFStringRef)displayName, icon, URLToToggle, /*propertiesToSet*/ NULL, /*propertiesToClear*/ NULL);
	} else if (!enabled && (existingItem != NULL))
		LSSharedFileListItemRemove(loginItems, existingItem);
}



#pragma mark **SMC-Binary Owner/Right Check**
//call smc binary with sudo rights and apply
+(void)setRights{
	NSString *smcpath = [[NSBundle mainBundle]   pathForResource:@"smc" ofType:@""];
	NSFileManager *fmanage=[NSFileManager defaultManager];
    NSDictionary *fdic = [fmanage attributesOfItemAtPath:smcpath error:nil];
	if ([[fdic valueForKey:@"NSFileOwnerAccountName"] isEqualToString:@"root"] && [[fdic valueForKey:@"NSFileGroupOwnerAccountName"] isEqualToString:@"admin"] && ([[fdic valueForKey:@"NSFilePosixPermissions"] intValue]==3437)) {
		return;
	 } 
	FILE *commPipe;
	AuthorizationRef authorizationRef;
	AuthorizationItem gencitem = { "system.privilege.admin", 0, NULL, 0 };
	AuthorizationRights gencright = { 1, &gencitem };
	int flags = kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed;
	status = AuthorizationCreate(&gencright,  kAuthorizationEmptyEnvironment, flags, &authorizationRef);
	NSString *tool=@"/usr/sbin/chown";
    NSArray *argsArray = [NSArray arrayWithObjects: @"root:admin",smcpath,nil];
	int i;
	char *args[255];
	for(i = 0;i < [argsArray count];i++){
		args[i] = (char *)[[argsArray objectAtIndex:i]cString];
	}
	args[i] = NULL;
	status=AuthorizationExecuteWithPrivileges(authorizationRef,[tool UTF8String],0,args,&commPipe);
	//second call for suid-bit
	tool=@"/bin/chmod";
	argsArray = [NSArray arrayWithObjects: @"6555",smcpath,nil];
	for(i = 0;i < [argsArray count];i++){
		args[i] = (char *)[[argsArray objectAtIndex:i]cString];
	}
	args[i] = NULL;
	status=AuthorizationExecuteWithPrivileges(authorizationRef,[tool UTF8String],0,args,&commPipe);
}


@end




@implementation NSNumber (NumberAdditions)

- (NSString*) tohex{
	return [NSString stringWithFormat:@"%0.4x",[self intValue]<<2];
}


- (NSNumber*) celsius_fahrenheit{
	float celsius=[self floatValue];
	float fahrenheit=(celsius*9)/5+32;
	return [NSNumber numberWithFloat:fahrenheit];
}

@end



