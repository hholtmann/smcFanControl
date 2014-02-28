/*
 *	FanControl
 *
 *	Copyright (c) 2006-2012 Hendrik Holtmann
*
 *	Power.m - MacBook(Pro) FanControl application
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

#import "Power.h"


static CFRunLoopSourceRef powerNotifierRunLoopSource = NULL;

static int lastsource=0;

@implementation Power


void SleepWatcher( void * refCon, io_service_t service, natural_t messageType, void * messageArgument ){
		[(Power *)refCon powerMessageReceived: messageType withArgument: messageArgument];
}



static void powerSourceChanged(void * refCon)
{
	CFTypeRef	powerBlob = IOPSCopyPowerSourcesInfo();
	CFArrayRef	powerSourcesList = IOPSCopyPowerSourcesList(powerBlob);
	unsigned	count = CFArrayGetCount(powerSourcesList);
	unsigned int i;
	for (i = 0U; i < count; ++i) {  //in case we have several powersources
		CFTypeRef		powerSource;
		CFDictionaryRef description;
		powerSource = CFArrayGetValueAtIndex(powerSourcesList, i);
		description = IOPSGetPowerSourceDescription(powerBlob, powerSource);
		//work with NSArray from here
		NSDictionary *n_description = (NSDictionary *)description;
		[(Power *)refCon powerSourceMesssageReceived:n_description];	
	}	
	CFRelease(powerBlob);
	CFRelease(powerSourcesList);
}

- (id)init{
    if (self = [super init]) {
        
    }
	return self;
}


- (void)registerForSleepWakeNotification
{
	root_port = IORegisterForSystemPower(self, &notificationPort, SleepWatcher, &notifier);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notificationPort), kCFRunLoopDefaultMode);
}


- (void)registerForPowerChange
{
	powerNotifierRunLoopSource = IOPSNotificationCreateRunLoopSource(powerSourceChanged,self);
	if (powerNotifierRunLoopSource) {
		CFRunLoopAddSource(CFRunLoopGetCurrent(), powerNotifierRunLoopSource, kCFRunLoopDefaultMode);
	}
}


- (void)deregisterForSleepWakeNotification
{
	CFRunLoopRemoveSource( CFRunLoopGetCurrent(),
                         IONotificationPortGetRunLoopSource(notificationPort),
                         kCFRunLoopCommonModes );
	IODeregisterForSystemPower(&notifier);
	IOServiceClose(root_port);
	IONotificationPortDestroy(notificationPort);
}

- (void)deregisterForPowerChange{
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), powerNotifierRunLoopSource, kCFRunLoopDefaultMode);
	CFRelease(powerNotifierRunLoopSource);
}



- (void)powerMessageReceived:(natural_t)messageType withArgument:(void *) messageArgument
{
	switch (messageType)
	{
		case kIOMessageSystemWillSleep:
			IOAllowPowerChange(root_port, (long)messageArgument);
		break;
		case kIOMessageCanSystemSleep:
			IOAllowPowerChange(root_port, (long)messageArgument);
		break; 
		case kIOMessageSystemHasPoweredOn:
		if ([_delegate respondsToSelector:@selector(systemDidWakeFromSleep:)])
			[_delegate systemDidWakeFromSleep:self];
		else
		{ 
			[NSException raise:NSInternalInconsistencyException	format:@"Delegate doesn't respond to ourDelegate"];
		}
		break;
	}
}

- (void)powerSourceMesssageReceived:(NSDictionary *)n_description{
		if (([[n_description objectForKey:@"Power Source State"] isEqualToString:@"AC Power"] && [[n_description objectForKey:@"Is Charging"] intValue]==1) && lastsource!=1) {
				lastsource=1;
			if ([_delegate respondsToSelector:@selector(powerChangeToACLoading:)])
				[_delegate powerChangeToACLoading:self];
				else
			{ 
				[NSException raise:NSInternalInconsistencyException	format:@"Delegate doesn't respond to ourDelegate"];
			}
		}
		
		
		if (([[n_description objectForKey:@"Power Source State"] isEqualToString:@"AC Power"] && [[n_description objectForKey:@"Is Charging"] intValue]==0) && lastsource!=2) {
				lastsource=2;
			if ([_delegate respondsToSelector:@selector(powerChangeToAC:)])
				[_delegate powerChangeToAC:self];
				else
			{ 
				[NSException raise:NSInternalInconsistencyException	format:@"Delegate doesn't respond to ourDelegate"];
			}
		}
	
		if (([[n_description objectForKey:@"Power Source State"] isEqualToString:@"Battery Power"]) && lastsource!=3) {
			lastsource=3;
			if ([_delegate respondsToSelector:@selector(powerChangeToBattery:)])
				[_delegate powerChangeToBattery:self];
				else
			{ 
				[NSException raise:NSInternalInconsistencyException	format:@"Delegate doesn't respond to ourDelegate"];
			}
		}

} 



- (id)delegate
{
    return _delegate;
}

- (void)setDelegate:(id)new_delegate
{
	
	_delegate = new_delegate;
}

- (void)dealloc
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
    if (_delegate)
        [nc removeObserver:_delegate name:nil object:self];
	
    [super dealloc];
}



@end
