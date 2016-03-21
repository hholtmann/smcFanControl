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

#import "smcWrapper.h"
#import <CommonCrypto/CommonDigest.h>
NSString * const smc_checksum=@"b8e7e0f50c1d837cedd91d9af54b167f";

NSArray *allSensors;

@implementation smcWrapper
	io_connect_t conn;

+(void)init{
	SMCOpen(&conn);
}
+(void)cleanUp{
    SMCClose(conn);
}

+(float)readTempSensors
{
    float retValue;
    SMCVal_t      val;
    NSString *sensor = [[NSUserDefaults standardUserDefaults] objectForKey:@"TSensor"];
    SMCReadKey2((char*)[sensor UTF8String], &val,conn);
    retValue= ((val.bytes[0] * 256 + val.bytes[1]) >> 2)/64;
    allSensors = [NSArray arrayWithObjects:@"TC0D",@"TC0P",@"TCAD",@"TC0H",@"TC0F",@"TCAH",@"TCBH",nil];
    if (retValue<=0 || floor(retValue) == 129 ) { //workaround for some iMac Models
        for (NSString *sensor in allSensors) {
            SMCReadKey2((char*)[sensor UTF8String], &val,conn);
            retValue= ((val.bytes[0] * 256 + val.bytes[1]) >> 2)/64;
            if (retValue>0 && floor(retValue) != 129 ) {
                [[NSUserDefaults standardUserDefaults] setObject:sensor forKey:@"TSensor"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                break;
            }
        }
    }
    return retValue;
}

+(float) get_maintemp{
    float retValue;
    NSRange range_pro=[[MachineDefaults computerModel] rangeOfString:@"MacPro"];
    if (range_pro.length > 0) {
        retValue = [smcWrapper get_mptemp];
        if (retValue<=0 || floor(retValue) == 129 ) {
            retValue = [smcWrapper readTempSensors];
        }
    } else {
        retValue = [smcWrapper readTempSensors];
    }
    return retValue;
}


//temperature-readout for MacPro contributed by Victor Boyer
+(float) get_mptemp{
    UInt32Char_t  keyA;
    UInt32Char_t  keyB;
    SMCVal_t      valA;
    SMCVal_t      valB;
   // kern_return_t resultA;
   // kern_return_t resultB;
    sprintf(keyA, "TCAH");
	SMCReadKey2(keyA, &valA,conn);
    sprintf(keyB, "TCBH");
	SMCReadKey2(keyB, &valB,conn);
    float c_tempA= ((valA.bytes[0] * 256 + valA.bytes[1]) >> 2)/64.0;
    float c_tempB= ((valB.bytes[0] * 256 + valB.bytes[1]) >> 2)/64.0;
    int i_tempA, i_tempB;
    if (c_tempA < c_tempB)
    {
        i_tempB = round(c_tempB);
        return i_tempB;
    }
    else
    {
        i_tempA = round(c_tempA);
        return i_tempA;
    }
}

+(int) get_fan_rpm:(int)fan_number{
	UInt32Char_t  key;
	SMCVal_t      val;
	//kern_return_t result;
	sprintf(key, "F%dAc", fan_number);
	SMCReadKey2(key, &val,conn);
	int running= _strtof(val.bytes, val.dataSize, 2);
	return running;
}	

+(int) get_fan_num{
//	kern_return_t result;
    SMCVal_t      val;
    int           totalFans;
	SMCReadKey2("FNum", &val,conn);
    totalFans = _strtoul((char *)val.bytes, val.dataSize, 10);
	return totalFans;
}

+(NSString*) get_fan_descr:(int)fan_number{
	UInt32Char_t  key;
	char temp;
	SMCVal_t      val;
	//kern_return_t result;
	NSMutableString *desc;
//	desc=[[NSMutableString alloc] initWithFormat:@"Fan #%d: ",fan_number+1];
	desc=[[NSMutableString alloc]init];
	sprintf(key, "F%dID", fan_number);
	SMCReadKey2(key, &val,conn);
	int i;
	for (i = 0; i < val.dataSize; i++) {
		if ((int)val.bytes[i]>32) {
			temp=(unsigned char)val.bytes[i];
			[desc appendFormat:@"%c",temp];
		}
	}	
	return desc;
}	


+(int) get_min_speed:(int)fan_number{
	UInt32Char_t  key;
	SMCVal_t      val;
	//kern_return_t result;
	sprintf(key, "F%dMn", fan_number);
	SMCReadKey2(key, &val,conn);
	int min= _strtof(val.bytes, val.dataSize, 2);
	return min;
}	

+(int) get_max_speed:(int)fan_number{
	UInt32Char_t  key;
	SMCVal_t      val;
	//kern_return_t result;
	sprintf(key, "F%dMx", fan_number);
	SMCReadKey2(key, &val,conn);
	int max= _strtof(val.bytes, val.dataSize, 2);
	return max;
}	


+ (BOOL)validateSMC:(NSString*)path
{
    SecStaticCodeRef ref = NULL;
    
    NSURL * url = [NSURL URLWithString:path];
    
    OSStatus status;
    
    // obtain the cert info from the executable
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)url, kSecCSDefaultFlags, &ref);
    
    if (status != noErr) {
        return false;
    }
    
    @try {
        status = SecStaticCodeCheckValidity(ref, kSecCSDefaultFlags, nil);
        
        if (status != noErr) {
            NSLog(@"Codesign verification failed: Error id = %d",status);
            return false;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Codesign exception %@",exception);
        return false;
    }
    
    return true;
}

+ (NSString*)createCheckSum:(NSString*)path {
    NSData *d=[NSData dataWithContentsOfMappedFile:path];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5((void *)[d bytes], [d length], result);
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    for(int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}

//call smc binary with setuid rights and apply
// The smc binary is given root permissions in FanControl.m with the setRights method.
+(void)setKey_external:(NSString *)key value:(NSString *)value{
	NSString *launchPath = [[NSBundle mainBundle]   pathForResource:@"smc" ofType:@""];
    
   	NSString *checksum=[smcWrapper createCheckSum:launchPath];
    if (![checksum  isEqualToString:smc_checksum]) {
        NSLog(@"smcFanControl: Security Error: smc-binary is not the distributed one");
        return;
    }
    NSArray *argsArray = @[@"-k",key,@"-w",value];
	NSTask *task;
    task = [[NSTask alloc] init];
	[task setLaunchPath: launchPath];
	[task setArguments: argsArray];
	[task launch];
}

@end
