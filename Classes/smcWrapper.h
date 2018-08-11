/*
 *	FanControl
 *
 *	Copyright (c) 2006-2012 Hendrik Holtmann
 *  Portions Copyright (c) 2013 Michael Wilber
 *
 *	smcWrapper.m - MacBook(Pro) FanControl application
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
#import "smc.h"
#import "MachineDefaults.h"
#import "Constants.h"

@interface smcWrapper : NSObject {
}

+(void) cleanUp;

+(int) get_fan_rpm:(int)fan_number;
+(float) get_maintemp;
+(float) get_mptemp;
+(int) get_fan_num;
+(int) get_min_speed:(int)fan_number;
+(int) get_max_speed:(int)fan_number;
+(void)setKey_external:(NSString *)key value:(NSString *)value;
+(NSString*) get_fan_descr:(int)fan_number;

@end
