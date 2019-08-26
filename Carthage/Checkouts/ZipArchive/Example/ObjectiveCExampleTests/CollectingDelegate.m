//
// Created by chris on 8/1/12.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "CollectingDelegate.h"

@implementation CollectingDelegate

@synthesize files = _files;

- (instancetype)init {
    self = [super init];
    if (self) {
        self.files = [NSMutableArray array];
    }
    return self;
}

- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath unzippedFilePath:(NSString *)unzippedFilePath {
    [self.files addObject:unzippedFilePath];
}

@end
