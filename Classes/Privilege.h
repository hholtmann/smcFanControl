//
//  Privilege.h
//  smcFanControl
//
//  Created by Don Johnny on 2020/5/25.
//

#ifndef Privilege_h
#define Privilege_h

#import <Security/Authorization.h>

@interface Privilege : NSObject
+ (AuthorizationRef)Get;

+ (BOOL)runTaskAsAdmin:(NSString *)path andArgs:(NSArray *)args;
@end

#endif /* Privilege_h */
