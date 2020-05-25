//
//  Privilege.m
//  smcFanControl
//
//  Created by Don Johnny on 2020/5/25.
//

#import <Foundation/Foundation.h>
#import "Privilege.h"
#import <AppKit/AppKit.h>

static AuthorizationRef authorizationRef = nil;

@implementation Privilege
+(AuthorizationRef) Get{
    if (authorizationRef == nil){
        AuthorizationItem gencitem = { "system.privilege.admin", 0, NULL, 0 };
        AuthorizationRights gencright = { 1, &gencitem };
        int flags = kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed;
        OSStatus status = AuthorizationCreate(&gencright,  kAuthorizationEmptyEnvironment, flags, &authorizationRef);
        
        if (status != errAuthorizationSuccess){
            NSLog(@"Copy Rights Unsuccessful: %d", status);
            authorizationRef = nil;
        }
    }
    return authorizationRef;
}

+(BOOL) runTaskAsAdmin:(NSString *) path andArgs:(NSArray *) args {
    
    if ([self Get] == nil) {
        return NO;
    }
    
    FILE *myCommunicationsPipe = NULL;
    
    int count = (int)[args count];
    
    char *myArguments[count+1];
    
    for (int i=0; i<[args count]; i++) {
        myArguments[i] = (char *)[(NSString *)[args objectAtIndex:i] UTF8String];
    }
    myArguments[count] = NULL;
    
    OSStatus resultStatus = AuthorizationExecuteWithPrivileges ([self Get],
                                                                [path UTF8String], kAuthorizationFlagDefaults, myArguments,
                                                                &myCommunicationsPipe);
    
    if (resultStatus != errAuthorizationSuccess)
        NSLog(@"Error: %d", resultStatus);
    
    return YES;
}
@end
