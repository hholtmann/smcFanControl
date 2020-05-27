//
//  NSFileManager+DirectoryLocations.m
//
//  Created by Matt Gallagher on 06 May 2010
//
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software. Permission is granted to anyone to
//  use this software for any purpose, including commercial applications, and to
//  alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source
//     distribution.
//

#import "NSFileManager+DirectoryLocations.h"

enum {
    DirectoryLocationErrorNoPathFound,
    DirectoryLocationErrorFileExistsAtLocation
};

NSString *const DirectoryLocationDomain = @"DirectoryLocationDomain";

@implementation NSFileManager (DirectoryLocations)


/*!  Method to tie together the steps of:
	1) Locate a standard directory by search path and domain mask
    2) Select the first path in the results
 	3) Append a subdirectory to that path
	4) Create the directory and intermediate directories if needed
	5) Handle errors by emitting a proper NSError object

* \pararm searchPathDirectory - the search path passed to NSSearchPathForDirectoriesInDomains
* \pararm domainMask - the domain mask passed to NSSearchPathForDirectoriesInDomains
* \pararm appendComponent - the subdirectory appended
* \pararm errorOut - any error from file operations

* \returns returns the path to the directory (if path found and exists), nil otherwise
*/
- (NSString *)findOrCreateDirectory:(NSSearchPathDirectory)searchPathDirectory
                           inDomain:(NSSearchPathDomainMask)domainMask
                appendPathComponent:(NSString *)appendComponent
                              error:(NSError **)errorOut {
    // Declare an NSError first, so we don't need to check errorOut again and again
    NSError *error;

    if (errorOut) {
        error = *errorOut;
    } else {
        error = nil;
    }

    //
    // Search for the path
    //
    NSArray *paths = NSSearchPathForDirectoriesInDomains(searchPathDirectory, domainMask, YES);

    if ([paths count] == 0) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: NSLocalizedStringFromTable(@"No path found for directory in domain.", @"Errors", nil),
            @"NSSearchPathDirectory": @(searchPathDirectory),
            @"NSSearchPathDomainMask": @(domainMask)};

        error = [NSError errorWithDomain:DirectoryLocationDomain
                                    code:DirectoryLocationErrorNoPathFound
                                userInfo:userInfo];
        return nil;
    }

    //
    // Normally only need the first path returned
    //
    NSString *resolvedPath = paths[0];

    //
    // Append the extra path component
    //
    if (appendComponent) {
        resolvedPath = [resolvedPath stringByAppendingPathComponent:appendComponent];
    }

    //
    // Create the path if it doesn't exist
    //


    if ([self createDirectoryAtPath:resolvedPath withIntermediateDirectories:YES
                         attributes:nil error:&error])
        return resolvedPath;
    else
        return nil;
}


/*! applicationSupportDirectory

* \returns The path to the applicationSupportDirectory (creating it if it doesn't exist).
*/
- (NSString *)applicationSupportDirectory {
    NSString *executableName = [[NSBundle mainBundle] infoDictionary][@"CFBundleExecutable"];

    NSError *error = nil;

    NSString *result = [self findOrCreateDirectory:NSApplicationSupportDirectory
                                          inDomain:NSUserDomainMask
                               appendPathComponent:executableName
                                             error:&error];
    if (!result) {
        NSLog(@"Unable to find or create application support directory:\n%@", error);
    }
    return result;
}

@end
