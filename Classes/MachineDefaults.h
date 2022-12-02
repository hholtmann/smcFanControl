/*
 *	FanControl
 *
 *	Copyright (c) 2006-2012 Hendrik Holtmann
*
 *	MachineDefaults.m - MacBook(Pro) FanControl application
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
#import "smcWrapper.h"


@interface MachineDefaults : NSObject {
	NSString *machine;
	NSArray *supported_machines;
	Boolean supported;
	int machine_num;
}

+ (NSString *)computerModel;
- (instancetype)init:(NSString*)p_machine ;

@property (NS_NONATOMIC_IOSONLY, getter=get_machine_defaults, readonly, copy) NSDictionary *_machine_defaults;

@end
