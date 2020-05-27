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
+ (AuthorizationRef)Get {
    if (authorizationRef == nil) {
        AuthorizationItem gencitem = {"system.privilege.admin", 0, NULL, 0};
        AuthorizationRights gencright = {1, &gencitem};
        int flags = kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed;
        OSStatus status = AuthorizationCreate(&gencright, kAuthorizationEmptyEnvironment, (AuthorizationFlags) flags, &authorizationRef);

        if (status != errAuthorizationSuccess) {
            NSLog(@"Copy Rights Unsuccessful: %d", status);
            authorizationRef = nil;
        }
    }
    return authorizationRef;
}

+ (BOOL) runProcessAsAdministrator:(NSString*)binPath
                     withArguments:(NSArray *)arguments
                            output:(NSString **)output
                  errorDescription:(NSString **)errorDescription {

    NSString * allArgs = [arguments componentsJoinedByString:@" "];
    NSString * fullScript = [NSString stringWithFormat:@"%@ %@", binPath, allArgs];

    NSDictionary *errorInfo = [NSDictionary new];
    NSString *script =  [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", fullScript];

    NSAppleScript *appleScript = [[NSAppleScript new] initWithSource:script];
    NSAppleEventDescriptor * eventResult = [appleScript executeAndReturnError:&errorInfo];

    // Check errorInfo
    if (! eventResult)
    {
        // Describe common errors
        *errorDescription = nil;
        if ([errorInfo valueForKey:NSAppleScriptErrorNumber])
        {
            NSNumber * errorNumber = (NSNumber *)[errorInfo valueForKey:NSAppleScriptErrorNumber];
            if ([errorNumber intValue] == -128)
                *errorDescription = @"The administrator password is required to do this.";
        }

        // Set error message from provided message
        if (*errorDescription == nil)
        {
            if ([errorInfo valueForKey:NSAppleScriptErrorMessage])
                *errorDescription =  (NSString *)[errorInfo valueForKey:NSAppleScriptErrorMessage];
        }

        return NO;
    }
    else
    {
        // Set output to the AppleScript's output
        *output = [eventResult stringValue];

        return YES;
    }
}

+ (BOOL)runTaskAsAdmin:(NSString *)path andArgs:(NSArray *)args {

    if ([self Get] == nil) {
        return NO;
    }

    FILE *myCommunicationsPipe = NULL;

    int count = (int) [args count];

    char *myArguments[count + 1];

    for (int i = 0; i < [args count]; i++) {
        myArguments[i] = (char *) [(NSString *) [args objectAtIndex:i] UTF8String];
    }
    myArguments[count] = NULL;

    OSStatus resultStatus = AuthorizationExecuteWithPrivileges([self Get],
        [path UTF8String], kAuthorizationFlagDefaults, myArguments,
        &myCommunicationsPipe);

    if (resultStatus != errAuthorizationSuccess)
        NSLog(@"Error: %d", resultStatus);

    return YES;
}
@end
