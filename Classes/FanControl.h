/*
 *	FanControl
 *
 *	Copyright (c) 2006-2012 Hendrik Holtmann
 *  Portions Copyright (c) 2013 Michael Wilber
 *
 *	FanControl.h - MacBook(Pro) FanControl application
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

#import <Cocoa/Cocoa.h>
#import "NSFileManager+DirectoryLocations.h"
#import "smc.h"
#import "smcWrapper.h"
#import "IOKitSensor.h"
#import "MachineDefaults.h"

#import "Power.h"
#include <mach/mach_port.h>
#include <mach/mach_interface.h>
#include <mach/mach_init.h>

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>
#import "Constants.h"


#define kMenuBarHeight				22


@interface FanControl : NSObject <NSMenuDelegate>

{
    IBOutlet id currentSpeed;
	IBOutlet id currentSpeed1;
	
	IBOutlet id slider1;
	IBOutlet id slider2;
	
	IBOutlet id field1;
	IBOutlet id field2;

	IBOutlet id mainwindow;

	IBOutlet id tabview;

	IBOutlet id applybutton;

	IBOutlet id programinfo;

	IBOutlet id copyright;

	IBOutlet id syncslider;

	IBOutlet id TemperatureController;

	IBOutlet id levelIndicator;

	IBOutlet id newfavoritewindow;

	IBOutlet id newfavorite_title;

	IBOutlet id autochange;


	IBOutlet NSMenu *theMenu;
	
	IBOutlet id faqWindow;

	IBOutlet id faqText;
	
	IBOutlet id sliderCell;
	
	IBOutlet id sync;

	IBOutlet id colorSelector;
		
	NSStatusItem *statusItem;
	
	NSMutableArray* s_menus;
	
	NSTimer *_readTimer;
	
	Power *pw;
	
	IBOutlet id FavoritesController;
	IBOutlet id FanController;
	IBOutlet id DefaultsController;
	
	MachineDefaults *mdefaults;

	NSDictionary *undo_dic;
	 
	NSImage *menu_image;
	NSImage *menu_image_alt;
}

@property (nonatomic, strong ) 	NSMutableDictionary *machineDefaultsDict;


-(void)terminate:(id)sender;

- (IBAction)paypal:(id)sender;
- (IBAction)visitHomepage:(id)sender;

- (IBAction)closePreferences:(id)sender;
- (IBAction)savePreferences:(id)sender;
- (IBAction)updateCheck:(id)sender;
- (IBAction)resetSettings:(id)sender;

- (void)init_statusitem;

//new ones, check old later
- (IBAction)loginItem:(id)sender;
- (IBAction)add_favorite:(id)sender;
- (IBAction)close_favorite:(id)sender;
- (IBAction)save_favorite:(id)sender;
- (IBAction)delete_favorite:(id)sender;
- (IBAction)syncSliders:(id)sender;
- (void)apply_quickselect:(id)sender;
- (void)apply_settings:(id)sender controllerindex:(int)cIndex;
+ (void)setRights;
- (void) syncBinder:(Boolean)bind;
- (IBAction) changeMenu:(id)sender;
- (IBAction)menuSelect:(id)sender;
- (void)menuNeedsUpdate:(NSMenu*)menu;
@end


@interface NSNumber (NumberAdditions)
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *tohex;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSNumber *celsius_fahrenheit;

@end

