/*
 *	FanControl
 *
 *	Copyright (c) 2006 Hendrik Holtmann
*
 *	Power.h - MacBook(Pro) FanControl application
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
#include <IOKit/IOKitLib.h>
#include <IOKit/ps/IOPSKeys.h>
#include <IOKit/ps/IOPowerSources.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>


@interface Power : NSObject {
	
	io_connect_t root_port;
	io_object_t notifier;
	IONotificationPortRef notificationPort;
	id _delegate;
	
}

- (id)init;

- (id)delegate;
- (void)setDelegate:(id)new_delegate;

- (void)registerForSleepWakeNotification;
- (void)deregisterForSleepWakeNotification;

- (void)registerForPowerChange;
- (void)deregisterForPowerChange;

//internal
- (void)powerMessageReceived:(natural_t)messageType withArgument:(void *) messageArgument;
- (void)powerSourceMesssageReceived:(NSDictionary *)n_description;


@end


//delegate Prototypes 
@interface NSObject (PowerDelegate)

- (void)systemDidWakeFromSleep:(id)sender;

- (void)powerChangeToBattery:(id)sender;

- (void)powerChangeToAC:(id)sender;

- (void)powerChangeToACLoading:(id)sender;

@end
